import 'dart:async';

import 'models.dart';

/// An observable handle to a running, queued, or completed download.
///
/// Consumers observe [statusStream] and [progressStream], and control the
/// download via [pause], [resume], and [cancel].
///
/// Instances are created by [ByteMe] and should not be constructed directly.
class DownloadTask {
  /// Unique identifier for this task.
  final String id;

  DownloadStatus _status = DownloadStatus.queued;
  DownloadProgress _progress = DownloadProgress.zero;

  final _statusCtrl = StreamController<DownloadStatus>.broadcast();
  final _progressCtrl = StreamController<DownloadProgress>.broadcast();

  void Function()? _onCancel;
  void Function()? _onResume;

  DownloadTask({required this.id});

  // ---------------------------------------------------------------------------
  // Public observation API
  // ---------------------------------------------------------------------------

  /// Current status.
  DownloadStatus get status => _status;

  /// Current progress snapshot.
  DownloadProgress get progress => _progress;

  /// Stream of status changes.
  Stream<DownloadStatus> get statusStream => _statusCtrl.stream;

  /// Stream of progress updates (throttled by the engine).
  Stream<DownloadProgress> get progressStream => _progressCtrl.stream;

  // ---------------------------------------------------------------------------
  // Public control API
  // ---------------------------------------------------------------------------

  /// Pauses the download. The partial file is preserved for later resumption.
  void pause() {
    if (_status != DownloadStatus.downloading &&
        _status != DownloadStatus.queued) {
      return;
    }
    updateStatus(DownloadStatus.paused);
    _onCancel?.call(); // Abort the active connection
  }

  /// Resumes a paused download. No-op if not paused.
  void resume() {
    if (_status != DownloadStatus.paused) return;
    updateStatus(DownloadStatus.queued);
    _onResume?.call();
  }

  /// Cancels the download permanently.
  void cancel() {
    if (_status == DownloadStatus.completed ||
        _status == DownloadStatus.cancelled) {
      return;
    }
    updateStatus(DownloadStatus.cancelled);
    _onCancel?.call();
  }

  // ---------------------------------------------------------------------------
  // Engine-internal API (public due to Dart's library-level privacy)
  // ---------------------------------------------------------------------------

  /// Updates the status and notifies listeners.
  void updateStatus(DownloadStatus s) {
    if (_status == s) return;
    _status = s;
    if (!_statusCtrl.isClosed) _statusCtrl.add(s);
  }

  /// Updates the progress snapshot and notifies listeners.
  void updateProgress(DownloadProgress p) {
    _progress = p;
    if (!_progressCtrl.isClosed) _progressCtrl.add(p);
  }

  /// Registers a callback invoked when the user pauses or cancels.
  void attachCancelCallback(void Function() cb) => _onCancel = cb;

  /// Registers a callback invoked when the user resumes.
  void attachResumeCallback(void Function() cb) => _onResume = cb;

  /// Closes the stream controllers. Called when the task is removed.
  void dispose() {
    _statusCtrl.close();
    _progressCtrl.close();
  }
}
