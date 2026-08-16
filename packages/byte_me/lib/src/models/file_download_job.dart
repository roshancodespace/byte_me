import 'dart:async';
import 'package:byte_me_core/byte_me_core.dart';
import 'download_job.dart';

/// A concrete [DownloadJob] that manages the downloading of a single file
/// by delegating to the low-level [DownloadEngine] from `byte_me_core`.
class FileDownloadJob implements DownloadJob {
  final DownloadTask _internalTask;
  final DownloadEngine _engine;

  FileDownloadJob({
    required DownloadRequest request,
    required DownloadEngine engine,
  })  : _internalTask = DownloadTask(request: request),
        _engine = engine;

  @override
  String get id => _internalTask.id;

  @override
  DownloadStatus get status => _internalTask.status;

  @override
  DownloadProgress get progress => _internalTask.progress;

  @override
  Stream<DownloadStatus> get statusStream => _internalTask.statusStream;

  @override
  Stream<DownloadProgress> get progressStream => _internalTask.progressStream;

  @override
  void pause() {
    _internalTask.pause();
  }

  @override
  void resume() {
    // Note: To resume properly, we need to let the engine run again.
    // However, if the orchestrator (DownloadManager) controls resume,
    // it will call `execute()` again! So we just update status here.
    _internalTask.updateStatus(DownloadStatus.queued);
  }

  @override
  void cancel() {
    _internalTask.cancel();
  }

  @override
  Future<void> execute() async {
    // Engine handles the heavy lifting, networking, and byte writing
    await _engine.executeTask(_internalTask);
  }
}
