import 'dart:async';
import 'dart:io';

import '../download_task.dart';
import '../models.dart';

/// Low-level single-file download with resume, retry, and progress reporting.
///
/// Operates entirely with async I/O — no isolates needed for network/disk.
class DownloadEngine {
  final HttpClient _client;

  DownloadEngine(this._client);

  /// Downloads a single file. Updates [task] status and progress throughout.
  ///
  /// Completes normally whether the download succeeds, fails, or is cancelled.
  /// The final state is always reflected in [task.status].
  Future<void> execute(
    DownloadTask task, {
    required Uri url,
    required String savePath,
    Map<String, String>? headers,
    RetryConfig retry = const RetryConfig(),
  }) async {
    int attempts = 0;
    final stopwatch = Stopwatch()..start();
    int lastEmitMs = 0;

    while (true) {
      if (task.status == DownloadStatus.cancelled) return;
      attempts++;
      task.updateStatus(DownloadStatus.downloading);

      try {
        // Detect existing file for range-based resume
        final file = File(savePath);
        int existingBytes = 0;
        final reqHeaders = Map<String, String>.from(headers ?? {});

        if (file.existsSync()) {
          existingBytes = file.lengthSync();
          if (existingBytes > 0) {
            reqHeaders['Range'] = 'bytes=$existingBytes-';
          }
        } else {
          // Ensure parent directory exists
          await file.parent.create(recursive: true);
        }

        final request = await _client.getUrl(url);
        reqHeaders.forEach((k, v) => request.headers.set(k, v));
        final response = await request.close();

        // 416 = Range Not Satisfiable → file is already complete
        if (response.statusCode == 416) {
          await response.drain<void>();
          task.updateProgress(
            DownloadProgress(
              receivedBytes: existingBytes,
              totalBytes: existingBytes,
              elapsed: Duration.zero,
              bytesPerSecond: 0,
            ),
          );
          task.updateStatus(DownloadStatus.completed);
          return;
        }

        // Permanent errors — never retry
        if (response.statusCode == 404 ||
            response.statusCode == 401 ||
            response.statusCode == 403) {
          await response.drain<void>();
          throw _PermanentError('HTTP ${response.statusCode}');
        }

        // Other client/server errors — may retry
        if (response.statusCode >= 400) {
          await response.drain<void>();
          throw Exception('HTTP ${response.statusCode}');
        }

        final isResuming = response.statusCode == 206;
        int received = isResuming ? existingBytes : 0;
        final contentLength = response.contentLength == -1
            ? null
            : response.contentLength;
        final total = contentLength != null
            ? (isResuming ? contentLength + existingBytes : contentLength)
            : null;

        final sink = file.openWrite(
          mode: isResuming ? FileMode.append : FileMode.write,
        );

        task.attachCancelCallback(() => request.abort());

        try {
          await for (final chunk in response) {
            if (task.status == DownloadStatus.cancelled ||
                task.status == DownloadStatus.paused) {
              break;
            }

            sink.add(chunk);
            received += chunk.length;

            // Throttle progress emission to every 100ms
            final elapsedMs = stopwatch.elapsedMilliseconds;
            if (elapsedMs - lastEmitMs >= 100) {
              lastEmitMs = elapsedMs;
              final sessionBytes = received - (isResuming ? existingBytes : 0);
              final speed = elapsedMs > 0
                  ? (sessionBytes / elapsedMs) * 1000
                  : 0.0;

              task.updateProgress(
                DownloadProgress(
                  receivedBytes: received,
                  totalBytes: total,
                  elapsed: Duration(milliseconds: elapsedMs),
                  bytesPerSecond: speed,
                ),
              );
            }
          }

          await sink.flush();
          await sink.close();

          // User-initiated stop — file is preserved for later resume
          if (task.status == DownloadStatus.cancelled ||
              task.status == DownloadStatus.paused) {
            return;
          }

          // Final 100% progress
          task.updateProgress(
            DownloadProgress(
              receivedBytes: received,
              totalBytes: total ?? received,
              elapsed: stopwatch.elapsed,
              bytesPerSecond: 0,
            ),
          );
          task.updateStatus(DownloadStatus.completed);
          return;
        } catch (e) {
          await sink.close();
          if (task.status == DownloadStatus.cancelled ||
              task.status == DownloadStatus.paused) {
            return;
          }
          rethrow;
        }
      } catch (e) {
        if (task.status == DownloadStatus.cancelled) return;

        // Permanent errors and retry exhaustion → fail
        if (e is _PermanentError || attempts > retry.maxRetries) {
          task.updateStatus(DownloadStatus.failed);
          return;
        }

        // Exponential backoff before next attempt
        await Future.delayed(retry.delayFor(attempts));
      }
    }
  }
}

/// Marker for HTTP errors that should never be retried.
class _PermanentError implements Exception {
  final String message;
  _PermanentError(this.message);
  @override
  String toString() => '_PermanentError: $message';
}
