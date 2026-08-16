---
sidebar_position: 4
id: advanced-architecture
title: Advanced Architecture
---

# Advanced Architecture & The Core Engine

Most users will never need to leave the global `DownloadManager` orchestrator. However, if you are building complex custom download protocols, understanding the architecture is critical.

## The Separation of Concerns

1. **`byte_me`**: The **Manager**. It knows *how many* jobs are allowed to run, but it knows nothing about HTTP sockets, bytes, or files.
2. **`byte_me_core`**: The **Engine**. It knows exactly how to establish an HTTP connection, negotiate `Range` offsets, stream bytes to disk, and backoff when the network drops. But it knows nothing about concurrency limits or multiple jobs.

By splitting these up, you can build your own custom jobs (like torrents, WebSocket chunking, or custom media protocols) without having to rewrite the core networking stack.

## Building a Custom Job

To build a custom job, you simply implement the `DownloadJob` interface provided by `byte_me`, and internally utilize the `DownloadEngine` provided by `byte_me_core`!

Here is a proper code example of how to wrap the core engine in a custom job:

```dart
import 'package:byte_me/byte_me.dart';
import 'package:byte_me_core/byte_me_core.dart';
import 'dart:async';
import 'dart:io';

/// A custom job that downloads a file, but adds a weird delay for no reason!
class DelayedFileJob implements DownloadJob {
  @override
  final String id;
  final DownloadRequest request;
  
  final _engine = DownloadEngine();
  final _progressController = StreamController<DownloadProgress>.broadcast();

  DelayedFileJob(this.id, this.request);

  @override
  Stream<DownloadProgress> get progressStream => _progressController.stream;

  @override
  Future<void> start() async {
    // We are executing custom logic before relying on the core engine!
    await Future.delayed(Duration(seconds: 5));
    
    // We hand off the heavy lifting to the core engine, passing the
    // progress straight through to the UI!
    await _engine.startDownload(request, onProgress: (progress) {
      _progressController.add(progress);
    });
  }

  @override
  Future<void> pause() async {
    await _engine.pause();
  }

  @override
  Future<void> resume() async {
    await _engine.resume();
  }

  @override
  Future<void> cancel() async {
    await _engine.cancel();
  }
}
```

## Integrating your Custom Job

Once you've built your custom job, you can shove it directly into the global orchestrator!

```dart
final manager = DownloadManager.isolated(maxConcurrentJobs: 3);

// Create your custom job
final customJob = DelayedFileJob(
  'custom_1',
  DownloadRequest(
    id: 'custom_1',
    url: Uri.parse('https://example.com/file.zip'),
    destination: File('/app/file.zip'),
  )
);

// Enqueue it globally! The manager will track it just like an HLS video or standard file.
manager.enqueue(customJob);
```

This modular architecture ensures that `byte_me` is infinitely extensible while maintaining safe concurrency rules.
