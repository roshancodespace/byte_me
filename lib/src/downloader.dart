import 'dart:collection';
import 'dart:io';

import 'download_task.dart';
import 'engine/download_engine.dart';
import 'hls/hls_downloader.dart';
import 'models.dart';
import 'remux/remuxer.dart';

/// A cohesive download engine for Dart/Flutter.
///
/// Supports HTTP file downloads and HLS streaming with concurrent segments,
/// AES decryption, and pluggable remuxing.
///
/// ```dart
/// final downloader = ByteMe(maxConcurrentDownloads: 3);
///
/// final task = downloader.download(
///   id: 'my-file',
///   url: Uri.parse('https://example.com/file.mp4'),
///   savePath: '/path/to/file.mp4',
/// );
///
/// task.progressStream.listen((p) => print(p.formattedPercent));
/// task.statusStream.listen((s) => print(s));
///
/// // Control
/// task.pause();
/// task.resume();
/// task.cancel();
///
/// // Cleanup
/// downloader.dispose();
/// ```
class ByteMe {
  /// Maximum number of top-level downloads running simultaneously.
  final int maxConcurrentDownloads;

  final HttpClient _httpClient;
  final DownloadEngine _engine;
  final HlsDownloader _hlsDownloader;

  final Map<String, DownloadTask> _tasks = {};
  final Queue<_PendingJob> _queue = Queue();
  int _activeCount = 0;
  bool _disposed = false;

  /// Creates a new download manager.
  ///
  /// The shared [HttpClient] handles connection pooling automatically.
  ByteMe({this.maxConcurrentDownloads = 3})
    : _httpClient = HttpClient(),
      _engine = DownloadEngine(HttpClient()),
      _hlsDownloader = HlsDownloader(HttpClient());

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Downloads a single file via HTTP/HTTPS.
  ///
  /// Returns a [DownloadTask] for observation and control.
  /// Supports range-based resume if the server responds with 206.
  DownloadTask download({
    required String id,
    required Uri url,
    required String savePath,
    Map<String, String>? headers,
    RetryConfig retry = const RetryConfig(),
  }) {
    _assertNotDisposed();

    final task = DownloadTask(id: id);
    _tasks[id] = task;

    _enqueue(task, () async {
      await _engine.execute(
        task,
        url: url,
        savePath: savePath,
        headers: headers,
        retry: retry,
      );
    });

    return task;
  }

  /// Downloads an HLS stream (.m3u8).
  ///
  /// Parses the playlist, downloads segments concurrently, decrypts if needed,
  /// and remuxes into a single output file.
  ///
  /// The [remuxer] controls the output format:
  /// - `null` or [ConcatRemuxer] — concatenated MPEG-TS (default)
  /// - [MkvRemuxer] — Matroska container
  /// - Custom [Remuxer] — your own processing (e.g. FFmpeg)
  DownloadTask downloadHls({
    required String id,
    required Uri url,
    required String savePath,
    Map<String, String>? headers,
    int maxConcurrentSegments = 5,
    Remuxer? remuxer,
    RetryConfig retry = const RetryConfig(),
    int? totalSize,
  }) {
    _assertNotDisposed();

    final task = DownloadTask(id: id);
    _tasks[id] = task;

    _enqueue(task, () async {
      await _hlsDownloader.execute(
        task,
        url: url,
        savePath: savePath,
        headers: headers,
        maxConcurrentSegments: maxConcurrentSegments,
        remuxer: remuxer,
        retry: retry,
        totalSize: totalSize,
      );
    });

    return task;
  }

  /// Pauses a download by [id]. Partial data is preserved.
  void pause(String id) {
    final task = _tasks[id];
    if (task == null) return;

    if (task.status == DownloadStatus.queued) {
      _queue.removeWhere((j) => j.task.id == id);
      task.updateStatus(DownloadStatus.paused);
    } else {
      task.pause();
    }
  }

  /// Resumes a paused download by [id].
  void resume(String id) {
    final task = _tasks[id];
    if (task == null || task.status != DownloadStatus.paused) return;
    task.resume();

    // Re-queue for execution
    final pending = _pendingJobs[id];
    if (pending != null) {
      task.updateStatus(DownloadStatus.queued);
      _queue.add(pending);
      _processQueue();
    }
  }

  /// Cancels a download by [id].
  void cancel(String id) {
    final task = _tasks[id];
    if (task == null) return;

    _queue.removeWhere((j) => j.task.id == id);
    task.cancel();
  }

  /// Retrieves a task by [id], if it exists.
  DownloadTask? getTask(String id) => _tasks[id];

  /// Releases all resources. No further downloads can be started.
  void dispose() {
    _disposed = true;
    _httpClient.close(force: true);
    for (final task in _tasks.values) {
      task.dispose();
    }
    _tasks.clear();
    _queue.clear();
    _pendingJobs.clear();
  }

  // ---------------------------------------------------------------------------
  // Internal queue management
  // ---------------------------------------------------------------------------

  final Map<String, _PendingJob> _pendingJobs = {};

  void _enqueue(DownloadTask task, Future<void> Function() executor) {
    final job = _PendingJob(task, executor);
    _pendingJobs[task.id] = job;
    _queue.add(job);
    _processQueue();
  }

  void _processQueue() {
    while (_activeCount < maxConcurrentDownloads && _queue.isNotEmpty) {
      final job = _queue.removeFirst();
      _activeCount++;
      _executeJob(job);
    }
  }

  Future<void> _executeJob(_PendingJob job) async {
    try {
      await job.executor();
    } finally {
      _activeCount--;
      _pendingJobs.remove(job.task.id);
      _processQueue();
    }
  }

  void _assertNotDisposed() {
    if (_disposed) {
      throw StateError('ByteMe has been disposed');
    }
  }
}

class _PendingJob {
  final DownloadTask task;
  final Future<void> Function() executor;
  _PendingJob(this.task, this.executor);
}
