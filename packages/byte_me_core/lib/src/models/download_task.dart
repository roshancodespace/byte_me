import 'dart:async';

import 'download_progress.dart';
import 'download_request.dart';
import 'download_status.dart';

/// Represents an actively tracked download job in the system.
///
/// This class holds the [DownloadRequest] and maintains real-time
/// state including the [status] and [progress] of the download.
class DownloadTask {
  /// The underlying request that defined this download.
  final DownloadRequest request;

  // Internal state
  DownloadStatus _status;
  DownloadProgress _progress;

  // Stream controllers to broadcast state changes
  final _statusController = StreamController<DownloadStatus>.broadcast();
  final _progressController = StreamController<DownloadProgress>.broadcast();

  DownloadTask({required this.request})
    : _status = DownloadStatus.queued,
      _progress = const DownloadProgress(
        receivedBytes: 0,
        elapsedTime: Duration.zero,
        networkSpeed: 0,
      );

  /// The unique identifier for this task (same as the request ID).
  String get id => request.id;

  /// The current state of this task (e.g., queued, downloading, paused).
  DownloadStatus get status => _status;

  /// The current progress, speed, and timing of the download.
  DownloadProgress get progress => _progress;

  /// A stream that emits every time the [status] changes.
  Stream<DownloadStatus> get statusStream => _statusController.stream;

  /// A stream that emits frequently with updated [progress] information.
  Stream<DownloadProgress> get progressStream => _progressController.stream;

  void Function()? _onCancel;

  void attachCancelStrategy(void Function() onCancel) {
    _onCancel = onCancel;
  }

  /// Cancels the task completely.
  ///
  /// The network connection is aborted, and the task status becomes `cancelled`.
  /// This cannot be undone, and the task cannot be resumed.
  void cancel() {
    if (_status == DownloadStatus.completed ||
        _status == DownloadStatus.cancelled) {
      return;
    }

    updateStatus(DownloadStatus.cancelled);
    _onCancel?.call();
  }

  /// Pauses the active download.
  ///
  /// The network connection is gracefully aborted, but the task is kept around
  /// so it can be resumed later from the same byte offset.
  void pause() {
    if (_status != DownloadStatus.downloading &&
        _status != DownloadStatus.queued) {
      return;
    }

    updateStatus(DownloadStatus.paused);
    // This triggers the exact same network response.abort() as cancellation!
    _onCancel?.call();
  }

  void updateStatus(DownloadStatus newStatus) {
    if (_status == newStatus) return;
    _status = newStatus;
    _statusController.add(_status);
  }

  void updateProgress(DownloadProgress newProgress) {
    _progress = newProgress;
    _progressController.add(_progress);
  }

  /// Cleans up resources. Should be called when the task is completely finished
  /// and no longer needs to be tracked.
  void dispose() {
    _statusController.close();
    _progressController.close();
  }
}
