import 'dart:async';
import 'dart:io';
import 'package:byte_me_core/byte_me_core.dart';
import 'package:byte_me_hls/byte_me_hls.dart';
import 'package:byte_me_hls/src/m3u8_parser.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// A downloader specialized in handling HLS (HTTP Live Streaming) streams.
///
/// This class parses m3u8 playlists, downloads individual segments concurrently
/// using a provided [DownloadManager], and stitches them together (and decrypts them if necessary)
/// into a single final video file.
class HlsDownloader {
  final DownloadManager _manager;

  bool _isPaused = false;
  Completer<void>? _resumeCompleter;
  final Set<DownloadTask> _activeTasks = {};

  /// Creates a new [HlsDownloader] using the provided [DownloadManager].
  ///
  /// The [DownloadManager] dictates the concurrency limits and handles the actual
  /// network requests for individual HLS segments.
  HlsDownloader(this._manager);

  /// Pauses the current HLS download.
  void pause() {
    if (_isPaused) return;
    _isPaused = true;
    _resumeCompleter = Completer<void>();
    for (final task in _activeTasks) {
      _manager.pause(task.id);
    }
  }

  /// Resumes a paused HLS download.
  void resume() {
    if (!_isPaused) return;
    _isPaused = false;
    for (final task in _activeTasks) {
      _manager.resume(task.id);
    }
    _resumeCompleter?.complete();
    _resumeCompleter = null;
  }

  /// Downloads an HLS stream and stitches it into a single file.
  ///
  /// The [m3u8Url] must point to a valid m3u8 playlist.
  /// The [savePath] is the local file path where the final stitched video will be saved.
  /// Optional [headers] can be provided for HTTP requests (like authentication).
  /// The [onProgress] callback reports the real-time progress including network speed.
  Future<void> downloadHlsVideo({
    required String m3u8Url,
    required String savePath,
    Map<String, String>? headers,
    void Function(HlsProgress progress)? onProgress,
  }) async {
    final tempDir = Directory(
      '${p.dirname(savePath)}/.temp_hls_${DateTime.now().millisecondsSinceEpoch}',
    );
    await tempDir.create(recursive: true);

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
        if (onProgress == null) return;
        final nowMs = stopwatch.elapsedMilliseconds;
        final timeDiff = nowMs - lastSpeedUpdateMs;

        if (timeDiff > 500) {
          final bytesDiff = totalBytesReceived - lastBytesReceived;
          currentSpeed = (bytesDiff / timeDiff) * 1000;
          lastBytesReceived = totalBytesReceived;
          lastSpeedUpdateMs = nowMs;
        }

        onProgress(
          HlsProgress(
            completedSegments: completedSegments,
            totalSegments: segments.length,
            networkSpeed: currentSpeed,
          ),
        );
      }

      Future<void> worker() async {
        while (iterator.moveNext()) {
          if (_isPaused && _resumeCompleter != null) {
            await _resumeCompleter!.future;
          }

          final i = iterator.current.$1; // $1 = key = index
          final segment = iterator.current.$2; // $2 = value = HlsSegment
          final segmentFile = File(p.join(tempDir.path, 'segment_$i.ts'));

          final request = DownloadRequest(
            id: 'hls_seg_${DateTime.now().millisecondsSinceEpoch}_$i',
            url: Uri.parse(segment.url),
            destination: segmentFile,
            headers: headers,
          );

          final task = DownloadTask(request: request);
          _activeTasks.add(task);

          int previousBytes = 0;
          task.progressStream.listen((prog) {
            final diff = prog.receivedBytes - previousBytes;
            totalBytesReceived += diff;
            previousBytes = prog.receivedBytes;
            emitProgress();
          });

          _manager.enqueue(task);

          // Wait for this specific task to finish
          final finalStatus = await task.statusStream.firstWhere(
            (s) =>
                s == DownloadStatus.completed ||
                s == DownloadStatus.failed ||
                s == DownloadStatus.cancelled,
          );

          _activeTasks.remove(task);

          if (finalStatus != DownloadStatus.completed) {
            throw Exception("Segment $i failed with status: $finalStatus");
          }

          completedSegments++;
          emitProgress();
        }
      }

      // Spawn exactly enough workers to keep the DownloadManager fully busy
      final workerCount = _manager.maxConcurrentDownloads;
      final workers = List.generate(workerCount, (_) => worker());

      // Wait for all workers to finish the entire playlist
      await Future.wait(workers);

      // Decrypt (if needed) and Stitch
      await _stitchSegments(segments, tempDir, savePath);
    } finally {
      for (final task in _activeTasks) {
        _manager.cancel(task.id);
      }
      _activeTasks.clear();

      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    }
  }

  Future<void> _stitchSegments(
    List<HlsSegment> segments,
    Directory tempDir,
    String savePath,
  ) async {
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
  }
}
