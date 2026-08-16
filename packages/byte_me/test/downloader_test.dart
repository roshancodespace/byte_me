import 'package:byte_me/byte_me.dart';
import 'package:flutter_test/flutter_test.dart';
import 'test_utils.dart';

void main() {
  test('Downloads bunny.mp4 ', () async {
    final manager = DownloadManager.isolated(maxConcurrentJobs: 2);

    final request = DownloadRequest(
      id: 'sample_mp4_001',
      url: Uri.parse('https://samplelib.com/mp4/sample-10s-2160p.mp4'),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (X11; Linux x86_64; rv:129.0) Gecko/20100101 Firefox/129.0',
      },
      destination: getDumpFile('bunny.mp4'),
    );

    print('Enqueueing task...');
    final task = manager.addFile(request);

    task.progressStream.listen((progress) {
      print(
        'Downloading: ${progress.formattedPercentage} at ${progress.formattedSpeed}',
      );
    });

    task.statusStream.listen((status) {
      print('Task Status Changed: ${status.name}');
    });

    await task.statusStream.firstWhere(
      (s) =>
          s == DownloadStatus.completed ||
          s == DownloadStatus.failed ||
          s == DownloadStatus.cancelled,
    );

    print('Done!');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
