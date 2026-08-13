/// Represents the current state of a download task.
enum DownloadStatus {
  /// The task is waiting in the download manager queue.
  queued,

  /// The task is actively downloading data.
  downloading,

  /// The task has been paused and can be resumed later.
  paused,

  /// The task successfully downloaded the entire file.
  completed,

  /// The task failed due to a network or file system error.
  failed,

  /// The task was explicitly cancelled by the user.
  cancelled,
}
