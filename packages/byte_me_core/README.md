# Byte Me Core

[![pub package](https://img.shields.io/pub/v/byte_me_core.svg)](https://pub.dev/packages/byte_me_core)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

The foundational, high-performance download engine for the Byte Me ecosystem. 

`byte_me_core` is designed to be a robust, concurrency-aware downloading framework for Dart and Flutter. It provides the essential building blocks—queuing, background task execution, pausing/resuming, and dynamic transport layers—so you don't have to rewrite boilerplate networking logic.

---

## Table of Contents
- [Features](#features)
- [Installation](#installation)
- [Core Architecture](#core-architecture)
- [Usage Guide](#usage-guide)
  - [Initialization](#initialization)
  - [Creating Requests](#creating-requests)
  - [Lifecycle & Concurrency](#lifecycle--concurrency)
  - [Progress Tracking](#progress-tracking)
- [Custom Transports](#custom-transports)

---

## Features

- **Strict Concurrency Control**: Limit active downloads to protect memory and bandwidth. The `DownloadManager` handles the queue automatically.
- **Resumability**: HTTP Range requests are supported out of the box. Pause and resume large files effortlessly.
- **Automatic Retries & Exponential Backoff**: Transient network errors are caught, and the engine automatically retries failed chunks safely.
- **Detailed Progress Stream**: Real-time updates on downloaded bytes, total bytes, elapsed time, and live network speed.
- **Transport Agnostic**: Use our built-in `DartHttpTransport` (via the `http` package), or write an adapter for `dio` or raw sockets by implementing `DownloadTransport`.

## Installation

Add `byte_me_core` to your `pubspec.yaml`:

```yaml
dependencies:
  byte_me_core: ^1.0.0
```

## Core Architecture

- **`DownloadEngine`**: The worker. It handles the actual HTTP requests, file I/O, throttling, and retries.
- **`DownloadManager`**: The orchestrator. It holds a queue of pending tasks and feeds them to the Engine based on your `maxConcurrentDownloads` limit.
- **`DownloadTask`**: The wrapper for a specific download job. It provides `Stream`s for progress and status updates.

## Usage Guide

### Initialization

Always start by creating a transport, passing it to an engine, and wrapping it in a manager.

```dart
import 'package:byte_me_core/byte_me_core.dart';

final transport = DartHttpTransport();
final engine = DownloadEngine(transport);

// Allow 3 files to download simultaneously. Any others will queue up.
final manager = DownloadManager(
  engine: engine, 
  maxConcurrentDownloads: 3, 
);
```

### Creating Requests

A request defines *what* to download and *where* to put it.

```dart
import 'dart:io';

final request = DownloadRequest(
  id: 'my_unique_download_1',
  url: Uri.parse('https://example.com/huge_file.zip'),
  destination: File('/path/to/save/file.zip'),
  headers: {
    'Authorization': 'Bearer YOUR_TOKEN',
  },
  // You can also customize retries here!
  retryConfig: RetryConfig(maxRetries: 5, baseDelay: Duration(seconds: 2)),
);
```

### Lifecycle & Concurrency

Once you enqueue a task, you can pause, resume, or cancel it dynamically by its ID.

```dart
final task = DownloadTask(request: request);
manager.enqueue(task);

// Later on...
manager.pause('my_unique_download_1');
manager.resume('my_unique_download_1');
manager.cancel('my_unique_download_1');
```

### Progress Tracking

Listen to the task's streams to update your UI.

```dart
task.progressStream.listen((progress) {
  print('Percent: ${(progress.percentage * 100).toStringAsFixed(1)}%');
  print('Speed: ${progress.networkSpeed} bytes/sec');
  print('Downloaded: ${progress.receivedBytes} / ${progress.totalBytes}');
});

task.statusStream.listen((status) {
  if (status == DownloadStatus.completed) {
    print('Download Finished!');
  } else if (status == DownloadStatus.failed) {
    print('Download Failed!');
  }
});
```

## Custom Transports

Want to use `dio` instead of the standard `http` package? Just implement the `DownloadTransport` interface!

```dart
class DioTransport implements DownloadTransport {
  @override
  Future<DownloadResponse> open(DownloadRequest request) async {
    // Implement your Dio logic here and return a DownloadResponse stream!
  }
}
```
