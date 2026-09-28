/// A cohesive, high-performance download engine for Dart/Flutter.
///
/// Supports HTTP file downloads, HLS streaming with AES decryption, and
/// pluggable remuxing (built-in TS concat, MKV, or custom).
///
/// ```dart
/// import 'package:byte_me/byte_me.dart';
///
/// final downloader = ByteMe(maxConcurrentDownloads: 3);
///
/// // Simple file download
/// final task = downloader.download(
///   id: 'file-1',
///   url: Uri.parse('https://example.com/video.mp4'),
///   savePath: '/downloads/video.mp4',
/// );
///
/// task.progressStream.listen((p) => print(p.formattedPercent));
///
/// // HLS download with MKV remuxing
/// final hlsTask = downloader.downloadHls(
///   id: 'hls-1',
///   url: Uri.parse('https://example.com/stream.m3u8'),
///   savePath: '/downloads/stream.mkv',
///   remuxer: MkvRemuxer(),
/// );
///
/// downloader.dispose();
/// ```
library;

// Core types
export 'src/models.dart';
export 'src/download_task.dart';

// Main API
export 'src/downloader.dart';

// Remuxer (for custom implementations)
export 'src/remux/remuxer.dart';
export 'src/remux/concat_remuxer.dart';
export 'src/remux/mkv/mkv_remuxer.dart';
export 'src/remux/mkv/subtitles/subtitle_track.dart';
