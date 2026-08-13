import 'package:byte_me_core/byte_me_core.dart';
import 'package:byte_me_hls/src/hls_downloader.dart';
import 'package:test/test.dart';
import 'test_utils.dart';

void main() {
  test('Downloads a HLS file', () async {
    final transport = DartHttpTransport();
    final engine = DownloadEngine(transport);
    final manager = DownloadManager(engine: engine, maxConcurrentDownloads: 10);

    final hlsDownloader = HlsDownloader(manager);
    final destFile = getDumpFile('hls_sample.mp4');

    print('Starting HLS Download...');

    await hlsDownloader.downloadHlsVideo(
      m3u8Url:
          'https://devstreaming-cdn.apple.com/videos/streaming/examples/adv_dv_atmos/main.m3u8',
      savePath: destFile.path,
      onProgress: (progress) {
        print(
          'HLS Downloading: ${progress.formattedPercentage}, Speed: ${progress.formattedSpeed}, Segments: ${progress.completedSegments}/${progress.totalSegments}',
        );
      },
    );

    print('HLS Download complete: ${destFile.path}');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
