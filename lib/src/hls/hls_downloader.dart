import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import '../download_task.dart';
import '../models.dart';
import '../remux/concat_remuxer.dart';
import '../remux/remuxer.dart';
import 'hls_crypto.dart';
import 'm3u8_parser.dart';

/// Orchestrates the full HLS download pipeline:
/// parse playlist → download segments → decrypt → remux.
class HlsDownloader {
  final HttpClient _client;

  HlsDownloader(this._client);

  /// Executes an HLS download. Updates [task] throughout.
  Future<void> execute(
    DownloadTask task, {
    required Uri url,
    required String savePath,
    Map<String, String>? headers,
    int maxConcurrentSegments = 5,
    Remuxer? remuxer,
    RetryConfig retry = const RetryConfig(),
    int? totalSize,
  }) async {
    final effectiveHeaders = headers ?? {};
    final effectiveRemuxer = remuxer ?? const ConcatRemuxer();

    task.updateStatus(DownloadStatus.downloading);

    // Temp directory for segments
    final tempDir = Directory(
      '${p.dirname(savePath)}/.byte_me_hls_${task.id}_${DateTime.now().millisecondsSinceEpoch}',
    );
    await tempDir.create(recursive: true);

    bool cancelled = false;
    Completer<void>? pauseCompleter;

    try {
      // Parse playlist
      final segments = await M3u8Parser.parse(
        url.toString(),
        effectiveHeaders,
        _client,
      );

      if (segments.isEmpty) throw StateError('Empty HLS playlist');

      // Download state
      int completedCount = 0;
      int completedBytes = 0;
      int totalBytesReceived = 0;
      final stopwatch = Stopwatch()..start();
      int lastSpeedUpdateMs = 0;
      int lastBytesForSpeed = 0;
      double currentSpeed = 0;

      void emitProgress() {
        final nowMs = stopwatch.elapsedMilliseconds;

        // Update speed calculation every 500ms
        if (nowMs - lastSpeedUpdateMs > 500) {
          final bytesDiff = totalBytesReceived - lastBytesForSpeed;
          final timeDiff = nowMs - lastSpeedUpdateMs;
          currentSpeed = timeDiff > 0 ? (bytesDiff / timeDiff) * 1000 : 0;
          lastBytesForSpeed = totalBytesReceived;
          lastSpeedUpdateMs = nowMs;
        }

        // Estimate total size
        int estimatedTotal = totalSize ?? 0;
        if (estimatedTotal <= 0 && completedCount > 0) {
          final avgPerSegment = completedBytes / completedCount;
          estimatedTotal = (avgPerSegment * segments.length).round();
        }
        if (estimatedTotal < totalBytesReceived) {
          estimatedTotal = totalBytesReceived;
        }

        task.updateProgress(
          DownloadProgress(
            receivedBytes: totalBytesReceived,
            totalBytes: estimatedTotal > 0 ? estimatedTotal : null,
            elapsed: Duration(milliseconds: nowMs),
            bytesPerSecond: currentSpeed,
          ),
        );
      }

      // Cancel/pause wiring
      task.attachCancelCallback(() {
        cancelled = true;
        pauseCompleter?.complete();
      });

      // Concurrent segment download using worker pool pattern
      final segmentIterator = segments.indexed.iterator;
      final segmentFiles = List<File?>.filled(segments.length, null);

      Future<void> worker() async {
        while (segmentIterator.moveNext()) {
          if (cancelled) return;

          // Handle pause
          if (task.status == DownloadStatus.paused) {
            pauseCompleter = Completer<void>();
            await pauseCompleter!.future;
            pauseCompleter = null;
            if (cancelled) return;
          }

          final (index, segment) = segmentIterator.current;
          final segFile = File(p.join(tempDir.path, 'seg_$index.ts'));

          // Download segment with retries
          bool success = false;
          for (int attempt = 0; attempt <= retry.maxRetries; attempt++) {
            if (cancelled) return;
            try {
              await _downloadSegment(segment.url, segFile, effectiveHeaders, (
                bytes,
              ) {
                totalBytesReceived += bytes;
                emitProgress();
              });
              success = true;
              break;
            } catch (e) {
              if (cancelled) return;
              if (attempt < retry.maxRetries) {
                await Future.delayed(retry.delayFor(attempt + 1));
              }
            }
          }

          if (!success) {
            throw Exception(
              'Segment $index failed after ${retry.maxRetries} retries',
            );
          }

          segmentFiles[index] = segFile;
          completedCount++;
          completedBytes += segFile.lengthSync();
          emitProgress();
        }
      }

      // Launch worker pool
      final workers = List.generate(maxConcurrentSegments, (_) => worker());
      await Future.wait(workers);

      if (cancelled) {
        throw _CancelledException();
      }

      // Pause support for resume wiring
      task.attachResumeCallback(() {
        if (task.status == DownloadStatus.paused) {
          task.updateStatus(DownloadStatus.downloading);
          pauseCompleter?.complete();
        }
      });

      // Decrypt segments in a background isolate
      final validFiles = <File>[];
      for (int i = 0; i < segments.length; i++) {
        final file = segmentFiles[i];
        if (file == null || !file.existsSync()) {
          throw StateError('Missing segment $i after download');
        }
        validFiles.add(file);
      }

      if (segments.any((s) => s.key != null)) {
        await Isolate.run(() async {
          for (int i = 0; i < segments.length; i++) {
            final segment = segments[i];
            if (segment.key == null) continue;

            final file = File(validFiles[i].path);
            if (!file.existsSync()) continue;

            final encrypted = await file.readAsBytes();
            final decrypted = HlsCrypto.decrypt(
              encrypted,
              segment.key!,
              segment.iv,
              segment.seq,
            );
            await file.writeAsBytes(decrypted, flush: true);
          }
        });
      }

      if (cancelled) throw _CancelledException();

      // Ensure output directory exists
      await File(savePath).parent.create(recursive: true);

      // Remux
      await effectiveRemuxer.remux(validFiles, savePath);

      // Final progress
      task.updateProgress(
        DownloadProgress(
          receivedBytes: totalBytesReceived,
          totalBytes: totalBytesReceived,
          elapsed: stopwatch.elapsed,
          bytesPerSecond: 0,
        ),
      );
      task.updateStatus(DownloadStatus.completed);
    } on _CancelledException {
      // Normal cancellation flow — status already set
    } catch (e) {
      if (!cancelled) {
        task.updateStatus(DownloadStatus.failed);
      }
    } finally {
      // Clean up temp directory
      if (tempDir.existsSync()) {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      }
    }
  }

  /// Downloads a single segment file.
  Future<void> _downloadSegment(
    String url,
    File destination,
    Map<String, String> headers,
    void Function(int bytesReceived) onBytesReceived,
  ) async {
    final request = await _client.getUrl(Uri.parse(url));
    headers.forEach((k, v) => request.headers.set(k, v));
    final response = await request.close();

    if (response.statusCode != 200) {
      await response.drain<void>();
      throw Exception('Segment download failed: HTTP ${response.statusCode}');
    }

    final sink = destination.openWrite();
    try {
      await for (final chunk in response) {
        sink.add(chunk);
        onBytesReceived(chunk.length);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
  }
}

class _CancelledException implements Exception {}
