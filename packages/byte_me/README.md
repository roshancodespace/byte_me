# Byte Me

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

**The ultimate, unified download orchestrator for Flutter & Dart.**

`byte_me` is the top-level package of the Byte Me ecosystem. It acts as a powerful orchestrator (a "Global Queue") that can manage and throttle multiple types of downloads at once—from simple files to complex HLS video streams.

If you want a highly scalable, UI-friendly download manager that works like professional downloaders (like 1DM or IDM), you are in the right place!

---

## Features

- **Global Concurrency Queue**: Set a maximum limit of active jobs (e.g. `maxConcurrentJobs: 3`). Add as many downloads as you want, and the manager will safely throttle them.
- **Unified Interface**: Whether you are downloading a 5MB image or a 2GB encrypted HLS video playlist, they both implement the same `DownloadJob` interface and share the same pausing/cancelling/progress API!
- **Zero UI Boilerplate**: `DownloadProgress` comes out of the box with ready-to-display `formattedPercentage` (e.g. `"45.2%"`) and `formattedSpeed` (e.g. `"1.2 MB/s"`).
- **Isolate Offloading**: `DownloadManager.isolated()` automatically offloads all heavy HTTP networking and file I/O to a background thread to keep your UI silky smooth.
- **Extensible Architecture**: Want to download torrents or custom protocols? Just implement `DownloadJob` and drop it into the queue!

## Installation

Add `byte_me` to your `pubspec.yaml`:

```yaml
dependencies:
  byte_me:
    git:
      url: https://github.com/roshancodespace/byte_me.git
      path: packages/byte_me
      
  # Optional: Add the HLS plugin if you want to download m3u8 videos!
  byte_me_hls:
    git:
      url: https://github.com/roshancodespace/byte_me.git
      path: packages/byte_me_hls
```

## Quick Start Guide

### 1. Initialize the Global Orchestrator

Create a single instance of `DownloadManager` for your entire app.

```dart
import 'package:byte_me/byte_me.dart';

// Create a manager that runs in a background isolate.
// Limit it to 3 active jobs at a time to prevent network starvation.
final manager = DownloadManager.isolated(maxConcurrentJobs: 3);
```

### 2. Download Standard Files

Use the built-in `addFile` extension.

```dart
import 'dart:io';

final request = DownloadRequest(
  id: 'unique_file_id',
  url: Uri.parse('https://example.com/huge_file.zip'),
  destination: File('/path/to/save/file.zip'),
);

// Enqueues the file. If 3 jobs are already running, it waits.
final job = manager.addFile(request);
```

### 3. Download HLS Videos (Requires `byte_me_hls` plugin)

If you imported `byte_me_hls`, the manager instantly gains the `addHlsVideo` super-power! 

```dart
import 'package:byte_me_hls/byte_me_hls.dart'; // Unlocks addHlsVideo

final hlsJob = manager.addHlsVideo(
  id: 'unique_video_id',
  m3u8Url: 'https://example.com/playlist.m3u8',
  savePath: '/path/to/save/video.mp4',
  maxConcurrentSegments: 5, // Uses 5 connections internally just for this video!
);
```

### 4. Tracking Progress

Every job exposes clean, ready-to-use Streams.

```dart
job.progressStream.listen((progress) {
  print('Status: ${progress.formattedPercentage}'); // "45.2%"
  print('Speed: ${progress.formattedSpeed}');       // "1.2 MB/s"
});

job.statusStream.listen((status) {
  if (status == DownloadStatus.completed) {
    print('Download Finished!');
  }
});
```

### 5. Controlling Lifecycle

You can control jobs globally using the manager, or locally via the job instance.

```dart
// Pause a job globally (frees up a slot for another queued job!)
manager.pause('unique_file_id');

// Resume it
manager.resume('unique_file_id');

// Cancel it entirely
manager.cancel('unique_video_id');
```

## How It Works Under The Hood

1. **`byte_me`**: The high-level orchestrator. It manages the queue of `DownloadJob`s.
2. **`byte_me_core`**: The low-level engine. Used internally to handle raw byte streams, HTTP ranges, and exponential backoff.
3. **`byte_me_hls`**: A plugin that provides `HlsDownloadJob`. It automatically parses m3u8 playlists, spawns internal sub-queues for segments, decrypts AES-128 chunks, and stitches them together seamlessly!
