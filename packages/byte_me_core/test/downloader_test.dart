import 'package:byte_me_core/src/engine/download_engine.dart';
import 'package:byte_me_core/src/engine/download_manager.dart';
import 'package:byte_me_core/src/models/download_request.dart';
import 'package:byte_me_core/src/models/download_status.dart';
import 'package:byte_me_core/src/models/download_task.dart';
import 'package:byte_me_core/src/transport/dart_http_transport.dart';
import 'package:test/test.dart';
import 'test_utils.dart';

void main() {
  test('Downloads bunny.mp4 ', () async {
    final transport = DartHttpTransport();
    final engine = DownloadEngine(transport);

    final manager = DownloadManager(engine: engine, maxConcurrentDownloads: 2);

    final request = DownloadRequest(
      id: 'sample_mp4_001',
      url: Uri.parse('https://samplelib.com/mp4/sample-10s-2160p.mp4'),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (X11; Linux x86_64; rv:129.0) Gecko/20100101 Firefox/129.0',
      },
      destination: getDumpFile('bunny.mp4'),
    );

    final task = DownloadTask(request: request);

    task.progressStream.listen((progress) {
      final percent = (progress.percentage * 100).toStringAsFixed(1);
      final speedMb = (progress.networkSpeed / (1024 * 1024)).toStringAsFixed(
        2,
      );
      print('Downloading: $percent% at $speedMb MB/s');
    });

    task.statusStream.listen((status) {
      print('Task Status Changed: ${status.name}');
    });

    print('Enqueueing task...');
    manager.enqueue(task);

    await task.statusStream.firstWhere(
      (s) =>
          s == DownloadStatus.completed ||
          s == DownloadStatus.failed ||
          s == DownloadStatus.cancelled,
    );

    print('Done!');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
