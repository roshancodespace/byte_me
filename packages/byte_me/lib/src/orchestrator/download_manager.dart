import 'dart:collection';
import 'package:byte_me_core/byte_me_core.dart';
import '../models/download_job.dart';
import '../models/file_download_job.dart';

/// The global orchestrator for all types of download jobs.
///
/// The manager is responsible for queuing top-level jobs (like full HLS videos or single files),
/// limiting concurrent jobs, and providing APIs to pause, resume, or cancel active jobs.
class DownloadManager {
  /// The maximum number of jobs allowed to run at the exact same time.
  final int maxConcurrentJobs;
  
  /// The default low-level engine used for processing file bytes and network streams.
  final DownloadEngine defaultEngine;

  // Internal state
  final Map<String, DownloadJob> _allJobs = {};
  final Queue<DownloadJob> _pendingQueue = Queue<DownloadJob>();
  final List<DownloadJob> _activeJobs = [];

  /// Creates a new [DownloadManager].
  DownloadManager({
    required this.defaultEngine,
    this.maxConcurrentJobs = 3,
  });

  /// Creates a standard [DownloadManager] using [DartHttpTransport] on the main isolate.
  factory DownloadManager.standard({int maxConcurrentJobs = 3}) {
    return DownloadManager(
      defaultEngine: DownloadEngine(DartHttpTransport()),
      maxConcurrentJobs: maxConcurrentJobs,
    );
  }

  /// Creates an isolated [DownloadManager] that completely offloads network and file I/O to a background isolate.
  factory DownloadManager.isolated({int maxConcurrentJobs = 3}) {
    return DownloadManager(
      defaultEngine: IsolatedDownloadEngine(() => DartHttpTransport()),
      maxConcurrentJobs: maxConcurrentJobs,
    );
  }

  /// Adds a standard file [DownloadRequest] to the global queue.
  /// Returns the [FileDownloadJob] that was created.
  FileDownloadJob addFile(DownloadRequest request) {
    final job = FileDownloadJob(request: request, engine: defaultEngine);
    enqueue(job);
    return job;
  }

  /// Adds a [job] to the system and attempts to start it immediately if
  /// concurrency limits allow. Otherwise, it is placed in a pending queue.
  void enqueue(DownloadJob job) {
    if (job.status != DownloadStatus.queued) return;

    _allJobs[job.id] = job;
    _pendingQueue.add(job);

    // Check if we have room to start it immediately
    _processQueue();
  }

  /// Pauses a job by its [jobId], freeing up a concurrent slot for another download.
  void pause(String jobId) {
    final job = _allJobs[jobId];
    if (job == null) return;

    if (job.status == DownloadStatus.queued) {
      _pendingQueue.remove(job);
      // It's up to the job implementation to handle status updates natively,
      // but if it's purely queued, it hasn't executed yet.
      job.pause();
    } else if (job.status == DownloadStatus.downloading) {
      job.pause();
    }
  }

  /// Resumes a paused job by putting it back into the pending queue.
  void resume(String jobId) {
    final job = _allJobs[jobId];
    if (job == null || job.status != DownloadStatus.paused) return;

    job.resume(); // Let the job reset its internal state to queued
    _pendingQueue.add(job);

    _processQueue();
  }

  /// Cancels a job, whether it is pending in the queue or actively downloading.
  void cancel(String jobId) {
    final job = _allJobs[jobId];
    if (job == null) return;

    if (job.status == DownloadStatus.queued) {
      _pendingQueue.remove(job);
    } 
    job.cancel();
  }

  /// The traffic controller. It safely moves jobs from Pending to Active
  void _processQueue() {
    // Keep pulling jobs from the queue as long as we have empty slots
    while (_activeJobs.length < maxConcurrentJobs && _pendingQueue.isNotEmpty) {
      final nextJob = _pendingQueue.removeFirst();

      _activeJobs.add(nextJob);
      _execute(nextJob);
    }
  }

  /// Wraps the job execution so the manager knows when a job is finished.
  Future<void> _execute(DownloadJob job) async {
    try {
      await job.execute();
    } finally {
      _activeJobs.remove(job);
      _processQueue();
    }
  }
}
