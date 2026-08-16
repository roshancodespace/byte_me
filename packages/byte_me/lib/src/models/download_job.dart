import 'dart:async';
import 'package:byte_me_core/byte_me_core.dart';

/// The universal interface for any high-level download orchestrated by the `byte_me` package.
abstract interface class DownloadJob {
  /// Unique identifier for this job.
  String get id;

  /// Current state of the job.
  DownloadStatus get status;

  /// Current progress, including bytes, speed, etc.
  DownloadProgress get progress;

  /// Stream of status changes.
  Stream<DownloadStatus> get statusStream;

  /// Stream of progress changes.
  Stream<DownloadProgress> get progressStream;

  /// Pauses the job without losing downloaded data.
  void pause();

  /// Resumes a paused job.
  void resume();

  /// Completely cancels the job and optionally cleans up resources.
  void cancel();

  /// Called by the [DownloadManager] to begin executing this job.
  Future<void> execute();
}
