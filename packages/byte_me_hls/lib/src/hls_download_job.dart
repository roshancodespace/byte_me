import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:byte_me/byte_me.dart';
import 'package:byte_me_hls/src/m3u8_parser.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// A top-level [DownloadJob] specialized in handling HLS (HTTP Live Streaming) streams.
///
/// This job parses m3u8 playlists, downloads individual segments concurrently
/// using an internal [DownloadManager], and stitches them together.
class HlsDownloadJob implements DownloadJob {
  @override
  final String id;

  final String m3u8Url;
  final String savePath;
  final bool stitch;
  final Map<String, String>? headers;
  final int maxConcurrentSegments;

  final DownloadEngine _segmentEngine;
  late final DownloadManager _internalManager;

  DownloadStatus _status = DownloadStatus.queued;
  DownloadProgress _progress = const DownloadProgress(
    receivedBytes: 0,
    elapsedTime: Duration.zero,
    networkSpeed: 0,
  );

  final _statusController = StreamController<DownloadStatus>.broadcast();
  final _progressController = StreamController<DownloadProgress>.broadcast();

  bool _isPaused = false;
  bool _isCancelled = false;
  Completer<void>? _resumeCompleter;
  final Set<FileDownloadJob> _activeTasks = {};

  HlsDownloadJob({
    required this.id,
    required this.m3u8Url,
    required this.savePath,
    required DownloadEngine segmentEngine,
    this.stitch = true,
    this.headers,
    this.maxConcurrentSegments = 5,
  }) : _segmentEngine = segmentEngine {
    _internalManager = DownloadManager(
      defaultEngine: _segmentEngine,
      maxConcurrentJobs: maxConcurrentSegments,
    );
  }

  @override
  DownloadStatus get status => _status;

  @override
  DownloadProgress get progress => _progress;

  @override
  Stream<DownloadStatus> get statusStream => _statusController.stream;

  @override
  Stream<DownloadProgress> get progressStream => _progressController.stream;

  void _updateStatus(DownloadStatus newStatus) {
    if (_status == newStatus) return;
    _status = newStatus;
    _statusController.add(_status);
  }

  void _updateProgress(DownloadProgress newProgress) {
    _progress = newProgress;
    _progressController.add(_progress);
  }

  @override
  void pause() {
    if (_isPaused || _isCancelled) return;
    _isPaused = true;
    _updateStatus(DownloadStatus.paused);
    _resumeCompleter = Completer<void>();
    for (final task in _activeTasks) {
      _internalManager.pause(task.id);
    }
  }

  @override
  void resume() {
    if (!_isPaused || _isCancelled) return;
    _isPaused = false;
    _updateStatus(DownloadStatus.downloading);
    for (final task in _activeTasks) {
      _internalManager.resume(task.id);
    }
    _resumeCompleter?.complete();
    _resumeCompleter = null;
  }

  @override
  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    _updateStatus(DownloadStatus.cancelled);
    for (final task in _activeTasks) {
      _internalManager.cancel(task.id);
    }
    if (_isPaused) {
      _resumeCompleter?.complete();
    }
  }

  @override
  Future<void> execute() async {
    _updateStatus(DownloadStatus.downloading);

    final targetDir = stitch
        ? Directory(
            '${p.dirname(savePath)}/.temp_hls_${DateTime.now().millisecondsSinceEpoch}',
          )
        : Directory(savePath);

    await targetDir.create(recursive: true);

    try {
      final client = http.Client();
      final segments = await M3u8Parser.parse(m3u8Url, headers ?? {}, client);
      client.close();

      if (segments.isEmpty) throw Exception("Empty playlist");

      int completedSegments = 0;
      final iterator = segments.indexed.iterator;

      final stopwatch = Stopwatch()..start();
      int totalBytesReceived = 0;
      int lastBytesReceived = 0;
      int lastSpeedUpdateMs = 0;
      double currentSpeed = 0.0;

      void emitProgress() {
        final nowMs = stopwatch.elapsedMilliseconds;
        final timeDiff = nowMs - lastSpeedUpdateMs;

        if (timeDiff > 500) {
          final bytesDiff = totalBytesReceived - lastBytesReceived;
          currentSpeed = (bytesDiff / timeDiff) * 1000;
          lastBytesReceived = totalBytesReceived;
          lastSpeedUpdateMs = nowMs;
        }

        // HLS specific progress trick: we use percentage to represent segments
        // and keep standard fields so it conforms to the interface.
        final percentage = completedSegments / segments.length;

        _updateProgress(
          DownloadProgress(
            receivedBytes: totalBytesReceived,
            totalBytes:
                (totalBytesReceived / (percentage == 0 ? 0.01 : percentage))
                    .round(),
            elapsedTime: Duration(milliseconds: nowMs),
            networkSpeed: currentSpeed,
          ),
        );
      }

      Future<void> worker() async {
        while (iterator.moveNext()) {
          if (_isCancelled) break;

          if (_isPaused && _resumeCompleter != null) {
            await _resumeCompleter!.future;
          }

          if (_isCancelled) break;

          final i = iterator.current.$1; // $1 = key = index
          final segment = iterator.current.$2; // $2 = value = HlsSegment
          final segmentFile = File(p.join(targetDir.path, 'segment_$i.ts'));

          final request = DownloadRequest(
            id: 'hls_seg_${id}_$i',
            url: Uri.parse(segment.url),
            destination: segmentFile,
            headers: headers,
          );

          final task = FileDownloadJob(
            request: request,
            engine: _segmentEngine,
          );
          _activeTasks.add(task);

          int previousBytes = 0;
          task.progressStream.listen((prog) {
            final diff = prog.receivedBytes - previousBytes;
            totalBytesReceived += diff;
            previousBytes = prog.receivedBytes;
            emitProgress();
          });

          _internalManager.enqueue(task);

          // Wait for this specific task to finish
          final finalStatus = await task.statusStream.firstWhere(
            (s) =>
                s == DownloadStatus.completed ||
                s == DownloadStatus.failed ||
                s == DownloadStatus.cancelled,
          );

          _activeTasks.remove(task);

          if (finalStatus == DownloadStatus.cancelled || _isCancelled) {
            break;
          }

          if (finalStatus != DownloadStatus.completed) {
            throw Exception("Segment $i failed with status: $finalStatus");
          }

          completedSegments++;
          emitProgress();
        }
      }

      final workerCount = _internalManager.maxConcurrentJobs;
      final workers = List.generate(workerCount, (_) => worker());

      // Wait for all workers to finish the entire playlist
      await Future.wait(workers);

      if (_isCancelled) {
        throw Exception("HLS Download cancelled by user");
      }

      // Decrypt and Stitch/Output
      if (stitch) {
        await _stitchSegments(segments, targetDir, savePath);
      } else {
        await _decryptSegmentsInPlace(segments, targetDir);

        // Generate a segments.txt for easy FFmpeg concatenation:
        // ffmpeg -f concat -safe 0 -i segments.txt -c copy output.mp4
        final txtFile = File(p.join(targetDir.path, 'segments.txt'));
        final buffer = StringBuffer();
        for (int i = 0; i < segments.length; i++) {
          buffer.writeln("file 'segment_$i.ts'");
        }
        await txtFile.writeAsString(buffer.toString());
      }

      _updateStatus(DownloadStatus.completed);
    } catch (e) {
      if (!_isCancelled) {
        _updateStatus(DownloadStatus.failed);
        rethrow;
      }
    } finally {
      for (final task in _activeTasks) {
        _internalManager.cancel(task.id);
      }
      _activeTasks.clear();

      if ((stitch || _isCancelled) && targetDir.existsSync()) {
        await targetDir.delete(recursive: true);
      }
    }
  }

  Future<void> _stitchSegments(
    List<HlsSegment> segments,
    Directory tempDir,
    String savePath,
  ) async {
    await Isolate.run(() async {
      final finalFile = File(savePath);
      final sink = finalFile.openWrite();

      for (int i = 0; i < segments.length; i++) {
        final segment = segments[i];
        final file = File(p.join(tempDir.path, 'segment_$i.ts'));

        if (!file.existsSync()) {
          throw Exception("Missing segment $i during stitching");
        }

        // Read the raw (potentially encrypted) bytes downloaded by the core engine
        final bytes = await file.readAsBytes();

        // Decrypt using our M3u8Parser logic, or pass through if unencrypted
        final processedBytes = segment.key != null
            ? M3u8Parser.decrypt(bytes, segment.key!, segment.iv, segment.seq)
            : bytes;

        sink.add(processedBytes);
      }

      await sink.flush();
      await sink.close();
    });
  }

  Future<void> _decryptSegmentsInPlace(
    List<HlsSegment> segments,
    Directory targetDir,
  ) async {
    await Isolate.run(() async {
      for (int i = 0; i < segments.length; i++) {
        final segment = segments[i];
        if (segment.key == null) continue;

        final file = File(p.join(targetDir.path, 'segment_$i.ts'));
        if (!file.existsSync()) continue;

        final bytes = await file.readAsBytes();
        final decryptedBytes = M3u8Parser.decrypt(
          bytes,
          segment.key!,
          segment.iv,
          segment.seq,
        );

        await file.writeAsBytes(decryptedBytes, flush: true);
      }
    });
  }
}
