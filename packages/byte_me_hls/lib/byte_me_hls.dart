library;

export 'src/hls_download_job.dart';
export 'src/hls_progress.dart';

import 'package:byte_me/byte_me.dart';
import 'src/hls_download_job.dart';

extension HlsDownloadManagerExt on DownloadManager {
  /// Adds an HLS stream [HlsDownloadJob] to the global queue.
  HlsDownloadJob addHlsVideo({
    required String id,
    required String m3u8Url,
    required String savePath,
    bool stitch = true,
    int maxConcurrentSegments = 5,
    Map<String, String>? headers,
  }) {
    final job = HlsDownloadJob(
      id: id,
      m3u8Url: m3u8Url,
      savePath: savePath,
      segmentEngine: defaultEngine, // Natively use the core default engine for segments
      stitch: stitch,
      headers: headers,
      maxConcurrentSegments: maxConcurrentSegments,
    );
    enqueue(job);
    return job;
  }
}
