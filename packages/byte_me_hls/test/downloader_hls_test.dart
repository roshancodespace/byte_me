import 'package:byte_me/byte_me.dart';
import 'package:byte_me_hls/byte_me_hls.dart';
import 'package:test/test.dart';
import 'test_utils.dart';

void main() {
  test('Downloads a HLS file', () async {
    final manager = DownloadManager.isolated(maxConcurrentJobs: 1);
    final destFile = getDumpFile('hls_sample.mp4');

    print('Starting HLS Download...');

    final job = manager.addHlsVideo(
      id: 'hls_test_1',
      m3u8Url:
          'https://devstreaming-cdn.apple.com/videos/streaming/examples/adv_dv_atmos/main.m3u8',
      savePath: destFile.path,
      maxConcurrentSegments: 10,
    );

    job.progressStream.listen((progress) {
      print(
        'HLS Downloading: ${progress.formattedPercentage}, Speed: ${progress.formattedSpeed}, Segments: ${progress.receivedBytes}/${progress.totalBytes}',
      );
    });

    await job.statusStream.firstWhere(
      (s) =>
          s == DownloadStatus.completed ||
          s == DownloadStatus.failed ||
          s == DownloadStatus.cancelled,
    );

    print('HLS Download complete: ${destFile.path}');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
