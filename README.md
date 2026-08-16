# Byte Me Ecosystem

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Platform-Flutter-02569B?logo=flutter)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Platform-Dart-0175C2?logo=dart)](https://dart.dev/)

A highly scalable, modular, and production-ready downloading ecosystem for Dart and Flutter. 

Unlike standard "fire and forget" HTTP libraries, the **Byte Me** ecosystem is built from the ground up to handle massive files, complex media protocols (like encrypted HLS), and highly concurrent workloads without blocking the UI or crashing due to memory exhaustion. It features a **Global Orchestrator** similar to professional download managers (like 1DM or IDM).

---

## Table of Contents
- [Packages](#packages)
- [Why Byte Me?](#why-byte-me)
- [Installation](#installation)
- [Getting Started](#getting-started)
- [Architecture](#architecture-overview)
- [Contributing](#contributing)

---

## Packages

This monorepo is split into focused, single-responsibility packages. You typically only need to install `byte_me` and optionally `byte_me_hls`.

| Package | Description | Pub |
|---|---|---|
| [`byte_me`](./packages/byte_me) | **The Global Orchestrator**. Use this in your apps! It manages the high-level `DownloadJob` queue and provides zero-boilerplate extensions. |
| [`byte_me_hls`](./packages/byte_me_hls) | **The HLS Plugin**. Instantly adds the `addHlsVideo` capability to the `byte_me` orchestrator to seamlessly handle `.m3u8` playlists and encryption. |
| [`byte_me_core`](./packages/byte_me_core) | **The Bare-Metal Engine**. Handles low-level networking, byte chunking, pause/resume mechanisms, and file I/O. |

## Why Byte Me?

- **Global Concurrency Management**: You define how many high-level jobs run at once (`maxConcurrentJobs`). The orchestrator queues everything else.
- **Strict Memory Management**: Downloads are streamed directly to disk. Even complex HLS videos safely throttle their own internal segments.
- **Isolate Offloading**: Network and disk I/O are fully isolated on background threads, ensuring 60FPS UI performance.
- **Zero Boilerplate API**: Progress, speeds, and formatted strings are completely unified across all download types out of the box.

## Installation

Add the core orchestrator and (optionally) the HLS plugin to your `pubspec.yaml`:

```yaml
dependencies:
  byte_me:
    git:
      url: https://github.com/roshancodespace/byte_me.git
      path: packages/byte_me
      
  # Optional: for HLS video support
  byte_me_hls:
    git:
      url: https://github.com/roshancodespace/byte_me.git
      path: packages/byte_me_hls
```

## Getting Started

Initialize the global orchestrator once for your app, and then queue up anything you want!

```dart
import 'package:byte_me/byte_me.dart';
import 'package:byte_me_hls/byte_me_hls.dart'; // Unlocks addHlsVideo
import 'dart:io';

void main() async {
  // 1. Create the global manager (max 2 active downloads at a time)
  // isolated() offloads all heavy lifting to a background thread!
  final manager = DownloadManager.isolated(maxConcurrentJobs: 2);

  // 2. Queue a standard file
  final fileJob = manager.addFile(
    DownloadRequest(
      id: 'pdf_1',
      url: Uri.parse('https://example.com/large_document.pdf'),
      destination: File('/path/to/save/document.pdf'),
    )
  );

  // 3. Queue an entire HLS Video Stream (Requires byte_me_hls plugin)
  final hlsJob = manager.addHlsVideo(
    id: 'movie_1',
    m3u8Url: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
    savePath: '/path/to/save/my_movie.mp4',
    maxConcurrentSegments: 5, // Uses 5 internal connections just for this video
  );

  // 4. Listen to unified progress on any job
  hlsJob.progressStream.listen((progress) {
    print('Progress: ${progress.formattedPercentage}'); // "45.2%"
    print('Speed: ${progress.formattedSpeed}');       // "1.2 MB/s"
  });

  // 5. Control jobs globally
  manager.pause('movie_1');
  manager.resume('movie_1');
  manager.cancel('pdf_1');
}
```

## Architecture Overview

1. **`byte_me`**: The high-level orchestrator. It manages the queue of `DownloadJob`s.
2. **`byte_me_core`**: The low-level engine. Used internally to handle raw byte streams, HTTP ranges, and exponential backoff.
3. **`byte_me_hls`**: A plugin that provides `HlsDownloadJob`. It automatically parses m3u8 playlists, spawns internal sub-queues for segments, decrypts AES-128 chunks, and stitches them together seamlessly!

## Contributing
We welcome contributions! Please open an issue before submitting a large pull request to discuss the changes you wish to make.
