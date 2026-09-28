import 'dart:io';

/// Interface for post-download processing of HLS segments.
///
/// Implementations transform a list of segment files into a single output file.
/// The downloader handles downloading and decryption; the remuxer handles
/// packaging into the desired container format.
///
/// Built-in implementations:
/// - [ConcatRemuxer] — Simple binary concatenation (MPEG-TS passthrough).
/// - [MkvRemuxer] — Remuxes H.264/AAC into a Matroska container.
///
/// Custom implementations can wrap FFmpeg, use platform codecs, etc.
abstract class Remuxer {
  /// Processes [segments] (in order) into a single file at [outputPath].
  ///
  /// The [segments] are already decrypted. The output directory is guaranteed
  /// to exist.
  Future<void> remux(List<File> segments, String outputPath);
}
