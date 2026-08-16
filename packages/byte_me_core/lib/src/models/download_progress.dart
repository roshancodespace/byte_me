/// Represents the real-time progress and statistics of a running download.
class DownloadProgress {
  /// The total number of bytes received and written to disk so far.
  final int receivedBytes;

  /// The expected total size of the file in bytes.
  ///
  /// This can be `null` if the server does not return a `Content-Length` header.
  final int? totalBytes;

  /// The amount of time that has passed since the download started or resumed.
  final Duration elapsedTime;

  /// The current estimated network speed in bytes per second.
  final double networkSpeed;
  const DownloadProgress({
    this.totalBytes,
    required this.receivedBytes,
    required this.elapsedTime,
    required this.networkSpeed,
  });

  /// Calculates the percentage (0.0 - 1.0). Returns 0.0 if size is unknown
  double get percentage {
    if (totalBytes == null || totalBytes == 0) return 0.0;
    return receivedBytes / totalBytes!;
  }

  /// Estimates remaining time. Returns null if total size or speed is 0.
  Duration? get estimatedTimeRemaining {
    if (totalBytes == null || networkSpeed <= 0) return null;
    final remainingBytes = totalBytes! - receivedBytes;
    final secondsRemaining = remainingBytes / networkSpeed;
    return Duration(seconds: secondsRemaining.toInt());
  }

  /// Returns a human-readable percentage string (e.g., "45.2%").
  String get formattedPercentage {
    return '${(percentage * 100).toStringAsFixed(1)}%';
  }

  /// Returns a human-readable network speed string (e.g., "1.2 MB/s").
  String get formattedSpeed {
    if (networkSpeed > 1024 * 1024) {
      return '${(networkSpeed / (1024 * 1024)).toStringAsFixed(2)} MB/s';
    } else if (networkSpeed > 1024) {
      return '${(networkSpeed / 1024).toStringAsFixed(2)} KB/s';
    } else {
      return '${networkSpeed.toStringAsFixed(0)} B/s';
    }
  }
}
