import 'dart:async';
import 'dart:isolate';

import 'download_engine.dart';
import '../models/download_progress.dart';
import '../models/download_request.dart';
import '../models/download_result.dart';
import '../models/download_status.dart';
import '../models/download_task.dart';
import '../transport/download_transport.dart';

class IsolatedDownloadEngine implements DownloadEngine {
  final DownloadTransport Function() transportBuilder;

  IsolatedDownloadEngine(this.transportBuilder);

  @override
  Future<DownloadResult> executeTask(DownloadTask task) async {
    final receivePort = ReceivePort();
    
    // Spawn the background isolate
    await Isolate.spawn(
      _isolateMain,
      {
        'sendPort': receivePort.sendPort,
        'request': task.request,
        'transportBuilder': transportBuilder,
      },
    );

    SendPort? commandPort;
    final completer = Completer<DownloadResult>();

    // Wire up UI cancellation to the background isolate
    task.attachCancelStrategy(() {
      if (task.status == DownloadStatus.paused) {
         commandPort?.send('pause');
      } else if (task.status == DownloadStatus.cancelled) {
         commandPort?.send('cancel');
      }
    });

    // Listen to messages from the isolate
    receivePort.listen((message) {
      if (message is SendPort) {
        commandPort = message;
      } else if (message is DownloadProgress) {
        task.updateProgress(message);
      } else if (message is DownloadStatus) {
        task.updateStatus(message);
      } else if (message is DownloadResult) {
        completer.complete(message);
        receivePort.close();
      }
    });

    return completer.future;
  }

  // The actual background process
  static void _isolateMain(Map<String, dynamic> args) async {
    final sendPort = args['sendPort'] as SendPort;
    final request = args['request'] as DownloadRequest;
    final transportBuilder = args['transportBuilder'] as DownloadTransport Function();

    // Give the main thread a way to send us cancel/pause commands
    final commandPort = ReceivePort();
    sendPort.send(commandPort.sendPort);

    // Build the actual engine inside this isolate
    final engine = DownloadEngine(transportBuilder());
    final task = DownloadTask(request: request);

    commandPort.listen((command) {
      if (command == 'cancel') task.cancel();
      if (command == 'pause') task.pause();
    });

    // Proxy events back to the UI thread
    task.progressStream.listen((p) => sendPort.send(p));
    task.statusStream.listen((s) => sendPort.send(s));

    // Run the heavy network + IOSink write
    final result = await engine.executeTask(task);
    
    sendPort.send(result);
    commandPort.close();
  }
}
