import 'dart:async';
import 'dart:io';

import '../models/download_error.dart';
import '../models/download_progress.dart';
import '../models/download_request.dart';
import '../models/download_result.dart';
import '../models/download_status.dart';
import '../models/download_task.dart';
import '../transport/download_transport.dart';

class DownloadEngine {
  final DownloadTransport _transport;

  DownloadEngine(this._transport);

  Future<DownloadResult> executeTask(DownloadTask task) async {
    int attempts = 0;
    final maxRetries = task.request.retryConfig.maxRetries;

    final stopwatch = Stopwatch()..start();
    int lastEmittedMilliseconds = 0;

    // Detect existing file and prepare Range header
    final file = task.request.destination;
    int existingBytes = 0;

    final requestHeaders = Map<String, String>.from(task.request.headers ?? {});

    if (file.existsSync()) {
      existingBytes = file.lengthSync();
      if (existingBytes > 0) {
        requestHeaders['Range'] = 'bytes=$existingBytes-';
      }
    }

    final outboundRequest = DownloadRequest(
      id: task.request.id,
      url: task.request.url,
      destination: task.request.destination,
      headers: requestHeaders,
    );

    while (true) {
      attempts++;
      task.updateStatus(DownloadStatus.downloading);

      try {
        final response = await _transport.open(outboundRequest);

        // Handle Status Codes
        if (response.statusCode == 404 ||
            response.statusCode == 401 ||
            response.statusCode == 403) {
          throw Exception('Permanent HTTP Error: ${response.statusCode}');
        } else if (response.statusCode == 416) {
          task.updateProgress(
            DownloadProgress(
              receivedBytes: existingBytes,
              totalBytes: existingBytes,
              elapsedTime: Duration.zero,
              networkSpeed: 0,
            ),
          );
          task.updateStatus(DownloadStatus.completed);
          return DownloadResult.success(file);
        } else if (response.statusCode >= 400) {
          throw Exception('Trancient HTTP Error: ${response.statusCode}');
        }

        // Determine if we are appending or starting over
        final isResuming = response.statusCode == 206;
        int receivedBytes = isResuming ? existingBytes : 0;

        final totalBytes = response.contentLength != null
            ? (isResuming
                  ? response.contentLength! + existingBytes
                  : response.contentLength)
            : null;

        final fileMode = isResuming ? FileMode.append : FileMode.write;
        final sink = file.openWrite(mode: fileMode);

        // Wire up the cancellation strategy to the task
        task.attachCancelStrategy(() async {
          response.abort();
        });

        try {
          await for (final chunk in response.byteStream) {
            if (task.status == DownloadStatus.cancelled ||
                task.status == DownloadStatus.paused) {
              break;
            }

            // Write to disk
            sink.add(chunk);
            receivedBytes += chunk.length;

            // Throttled Progress Calculation
            final elapsed = stopwatch.elapsedMilliseconds;
            if (elapsed - lastEmittedMilliseconds >= 100) {
              lastEmittedMilliseconds = elapsed;

              final sessionBytes =
                  receivedBytes - (isResuming ? existingBytes : 0);
              final speed = (sessionBytes / elapsed) * 1000;

              task.updateProgress(
                DownloadProgress(
                  receivedBytes: receivedBytes,
                  totalBytes: totalBytes,
                  elapsedTime: Duration(milliseconds: elapsed),
                  networkSpeed: speed,
                ),
              );
            }
          }

          // Stream finished or loop broken
          stopwatch.stop();
          await sink.flush();
          await sink.close();

          if (task.status == DownloadStatus.cancelled ||
              task.status == DownloadStatus.paused) {
            // If we broke out of the loop intentionally, return failure (but keep the file!)
            return DownloadResult.failure(
              const DownloadError(message: 'Task stopped by user'),
            );
          }

          // Final 100% completion update
          task.updateProgress(
            DownloadProgress(
              receivedBytes: receivedBytes,
              totalBytes: totalBytes,
              elapsedTime: Duration(
                milliseconds: stopwatch.elapsedMilliseconds,
              ),
              networkSpeed: 0,
            ),
          );

          task.updateStatus(DownloadStatus.completed);
          return DownloadResult.success(task.request.destination);
        } catch (e, st) {
          stopwatch.stop();
          await sink.close();

          if (task.status == DownloadStatus.cancelled ||
              task.status == DownloadStatus.paused) {
            return DownloadResult.failure(
              const DownloadError(message: 'Task stopped by user'),
            );
          }

          task.updateStatus(DownloadStatus.failed);
          return DownloadResult.failure(
            DownloadError(message: e.toString(), exception: e, stackTrace: st),
          );
        }
      } catch (e, st) {
        // Did the user cancel? If so, NEVER retry.
        if (task.status == DownloadStatus.cancelled) {
          return DownloadResult.failure(
            const DownloadError(message: 'Cancelled by user'),
          );
        }

        // Is this a permanent error or have we run out of retries?
        final isPermanentError = e.toString().contains('Permanent');
        if (isPermanentError || attempts > maxRetries) {
          task.updateStatus(DownloadStatus.failed);
          return DownloadResult.failure(
            DownloadError(message: e.toString(), exception: e, stackTrace: st),
          );
        }

        // We are going to retry! Wait using Exponential Backoff
        final delay = task.request.retryConfig.calculateDelay(attempts);
        await Future.delayed(delay);
      }
    }
  }
}
