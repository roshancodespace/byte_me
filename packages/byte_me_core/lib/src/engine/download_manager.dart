import 'dart:collection';

import 'download_engine.dart';
import '../models/download_status.dart';
import '../models/download_task.dart';

/// Orchestrates the execution, concurrency, and lifecycle of download tasks.
///
/// The manager is responsible for queuing tasks, limiting concurrent downloads,
/// and providing APIs to pause, resume, or cancel active tasks.
class DownloadManager {
  final DownloadEngine _engine;

  /// The maximum number of tasks allowed to run at the exact same time.
  final int maxConcurrentDownloads;

  // Internal state
  final Map<String, DownloadTask> _allTasks = {};
  final Queue<DownloadTask> _pendingQueue = Queue<DownloadTask>();
  final List<DownloadTask> _activeTasks = [];

  /// Creates a new [DownloadManager].
  ///
  /// [engine] handles the actual network operations.
  /// [maxConcurrentDownloads] limits how many tasks can run simultaneously.
  DownloadManager({
    required DownloadEngine engine,
    this.maxConcurrentDownloads = 3,
  }) : _engine = engine;

  /// Adds a [task] to the system and attempts to start it immediately if
  /// concurrency limits allow. Otherwise, it is placed in a pending queue.
  void enqueue(DownloadTask task) {
    if (task.status != DownloadStatus.queued) return;

    _allTasks[task.id] = task;
    _pendingQueue.add(task);

    // Check if we have room to start it immediately
    _processQueue();
  }

  /// Pauses a task by its [taskId], freeing up a concurrent slot for another download.
  void pause(String taskId) {
    final task = _allTasks[taskId];
    if (task == null) return;

    if (task.status == DownloadStatus.queued) {
      // If it's just waiting in the line, pull it out of the queue
      _pendingQueue.remove(task);
      task.updateStatus(DownloadStatus.paused);
    } else if (task.status == DownloadStatus.downloading) {
      // If it's active, task.pause() aborts the network
      task.pause();
    }
  }

  /// Resumes a paused task by putting it back into the pending queue.
  void resume(String taskId) {
    final task = _allTasks[taskId];
    if (task == null || task.status != DownloadStatus.paused) return;

    task.updateStatus(DownloadStatus.queued);
    _pendingQueue.add(task);

    _processQueue();
  }

  /// Cancels a task, whether it is pending in the queue or actively downloading.
  void cancel(String taskId) {
    final task = _allTasks[taskId];
    if (task == null) return;

    if (task.status == DownloadStatus.queued) {
      // If it hasn't started yet, just yank it out of the waiting line
      _pendingQueue.remove(task);
      task.cancel(); // Updates the status to cancelled
    } else if (task.status == DownloadStatus.downloading) {
      // If it's active, the task.cancel() triggers the engine's response.abort()
      task.cancel();
    }
  }

  /// The traffic controller. It safely moves tasks from Pending to Active
  void _processQueue() {
    // Keep pulling tasks from the queue as long as we have empty slots
    while (_activeTasks.length < maxConcurrentDownloads &&
        _pendingQueue.isNotEmpty) {
      final nextTask = _pendingQueue.removeFirst();

      _activeTasks.add(nextTask);
      _execute(nextTask);
    }
  }

  /// Wraps the engine execution so the manager knows when a task is finished.
  Future<void> _execute(DownloadTask task) async {
    await _engine.executeTask(task);

    _activeTasks.remove(task);

    _processQueue();
  }
}
