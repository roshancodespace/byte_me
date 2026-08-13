/// Represents the real-time progress of an HLS download.
class HlsProgress {
  /// The number of segments that have fully finished downloading.
  final int completedSegments;

  /// The total number of segments in the HLS playlist.
  final int totalSegments;

  /// The estimated overall network speed across all active segment downloads, in bytes per second.
  final double networkSpeed;

  /// Calculates the completion percentage (0.0 to 1.0).
  double get percentage =>
      totalSegments > 0 ? completedSegments / totalSegments : 0.0;

  /// Returns the percentage formatted as a string (e.g. "45.2%").
  String get formattedPercentage => '${(percentage * 100).toStringAsFixed(1)}%';

  /// Returns the network speed formatted in MB/s (e.g. "2.50 MB/s").
  String get formattedSpeed =>
      '${(networkSpeed / (1024 * 1024)).toStringAsFixed(2)} MB/s';

  const HlsProgress({
    required this.completedSegments,
    required this.totalSegments,
    required this.networkSpeed,
  });
}
