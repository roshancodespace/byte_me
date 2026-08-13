# Downloader Core

[![pub package](https://img.shields.io/pub/v/byte_me_core.svg)](https://pub.dev/packages/byte_me_core)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

A robust, highly concurrent, and extensible download engine for Dart and Flutter. 

`byte_me_core` provides the foundational architecture to build powerful downloading experiences. Whether you are downloading simple images, large ZIP files, or complex segmented media (like HLS), this package offers strict concurrency controls, real-time progress tracking, and complete lifecycle management.

---

## Features

- **Concurrency Control**: Limit the maximum number of active downloads to protect memory and network bandwidth.
- **Lifecycle Management**: Safely pause, resume, or cancel active tasks.
- **Detailed Progress**: Listen to real-time streams for percentage, downloaded bytes, and network speed.
- **Transport Agnostic**: Bring your own HTTP client (e.g., `http`, `dio`) by implementing the `DownloadTransport` interface.
- **Highly Modular**: Designed to be the rock-solid base layer for specialized downloaders (see [`byte_me_hls`](../byte_me_hls)).

## Installation

Add `byte_me_core` to your `pubspec.yaml`:

```yaml
dependencies:
  byte_me_core:
    path: ../byte_me_core
```

## Quick Start

### 1. Initialize the Engine
Create your network transport and instantiate the engine and manager.

```dart
import 'package:byte_me_core/byte_me_core.dart';

// Use the default HTTP transport or provide your own implementation
final transport = DartHttpTransport();
final engine = DownloadEngine(transport);

// The DownloadManager handles task queuing and concurrency
final manager = DownloadManager(
  engine: engine, 
  maxConcurrentDownloads: 3, // Only 3 files will download simultaneously
);
```

### 2. Create a Request
Define what you want to download and where it should go.

```dart
import 'dart:io';
import 'package:byte_me_core/byte_me_core.dart';

final request = DownloadRequest(
  id: 'unique_task_id_1',
  url: Uri.parse('https://example.com/large_video.mp4'),
  destination: File('/path/to/save/video.mp4'),
  headers: {
    'Authorization': 'Bearer your-token',
  },
);
```

### 3. Enqueue and Listen
Turn the request into a task, listen to its progress, and hand it to the manager.

```dart
final task = DownloadTask(request: request);

// Listen to network speed and progress
task.progressStream.listen((progress) {
  final percent = (progress.percentage * 100).toStringAsFixed(1);
  final speedMb = (progress.networkSpeed / (1024 * 1024)).toStringAsFixed(2);
  print('Downloading: $percent% | Speed: $speedMb MB/s');
});

// Listen to lifecycle changes
task.statusStream.listen((status) {
  print('Task Status: ${status.name}');
});

// Put the task in the queue!
manager.enqueue(task);
```

## Advanced Usage

### Pausing and Resuming
The `DownloadManager` allows you to interact with tasks in the queue using their unique ID.

```dart
// Pause an active download
manager.pause('unique_task_id_1');

// Resume a paused download
manager.resume('unique_task_id_1');

// Cancel a download completely
manager.cancel('unique_task_id_1');
```
