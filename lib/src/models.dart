import 'dart:math';

/// The lifecycle state of a download task.
enum DownloadStatus {
  /// Waiting in the queue for a concurrency slot.
  queued,

  /// Actively transferring data.
  downloading,

  /// Paused by the user; can be resumed.
  paused,

  /// Successfully completed.
  completed,

  /// Failed after exhausting retries.
  failed,

  /// Cancelled by the user.
  cancelled,
}

/// Real-time progress snapshot for a running download.
class DownloadProgress {
  /// Bytes received and written to disk so far.
  final int receivedBytes;

  /// Expected total size in bytes, if known.
  final int? totalBytes;

  /// Time elapsed since the download started or resumed.
  final Duration elapsed;

  /// Current transfer speed in bytes per second.
  final double bytesPerSecond;

  const DownloadProgress({
    required this.receivedBytes,
    this.totalBytes,
    required this.elapsed,
    required this.bytesPerSecond,
  });

  static const zero = DownloadProgress(
    receivedBytes: 0,
    elapsed: Duration.zero,
    bytesPerSecond: 0,
  );

  /// Completion fraction from 0.0 to 1.0. Returns 0.0 if total is unknown.
  double get percent {
    if (totalBytes == null || totalBytes == 0) return 0.0;
    return (receivedBytes / totalBytes!).clamp(0.0, 1.0);
  }

  /// Estimated time remaining, or null if speed or total is unknown.
  Duration? get eta {
    if (totalBytes == null || bytesPerSecond <= 0) return null;
    final remaining = totalBytes! - receivedBytes;
    if (remaining <= 0) return Duration.zero;
    return Duration(seconds: (remaining / bytesPerSecond).round());
  }

  /// Human-readable percentage (e.g. "45.2%").
  String get formattedPercent => '${(percent * 100).toStringAsFixed(1)}%';

  /// Human-readable speed (e.g. "1.25 MB/s").
  String get formattedSpeed {
    if (bytesPerSecond >= 1024 * 1024) {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(2)} MB/s';
    } else if (bytesPerSecond >= 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(2)} KB/s';
    }
    return '${bytesPerSecond.toStringAsFixed(0)} B/s';
  }

  @override
  String toString() =>
      'DownloadProgress($formattedPercent, $formattedSpeed, '
      '$receivedBytes/${totalBytes ?? "?"} bytes)';
}

/// Configuration for retry behavior on transient failures.
class RetryConfig {
  /// Maximum number of retry attempts before giving up.
  final int maxRetries;

  /// Base delay before the first retry.
  final Duration baseDelay;

  /// Whether to randomize the delay to prevent thundering herds.
  final bool useJitter;

  const RetryConfig({
    this.maxRetries = 3,
    this.baseDelay = const Duration(seconds: 1),
    this.useJitter = true,
  });

  /// Calculates the delay for the given 1-based [attempt] number.
  Duration delayFor(int attempt) {
    if (attempt <= 1) return baseDelay;
    final exponential = baseDelay.inMilliseconds * pow(2, attempt - 1);
    if (!useJitter) return Duration(milliseconds: exponential.toInt());
    final jitter = 0.5 + (Random().nextDouble() * 0.5);
    return Duration(milliseconds: (exponential * jitter).toInt());
  }
}
