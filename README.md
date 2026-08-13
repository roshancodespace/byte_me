# Byte Me Ecosystem

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Platform-Flutter-02569B?logo=flutter)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Platform-Dart-0175C2?logo=dart)](https://dart.dev/)
[![Pub Publisher](https://img.shields.io/pub/publisher/byte_me_core)](https://pub.dev/packages/byte_me_core)

A highly scalable, modular, and production-ready downloading ecosystem for Dart and Flutter. 

Unlike standard "fire and forget" HTTP libraries, the **Byte Me** ecosystem is built from the ground up to handle massive files, complex media protocols, and highly concurrent workloads without blocking the UI or crashing due to memory exhaustion.

---

## Table of Contents
- [Packages](#packages)
- [Why Byte Me?](#why-byte-me)
- [Installation](#installation)
- [Getting Started](#getting-started)
  - [Standard Downloads](#standard-downloads-byte_me_core)
  - [HLS Video Streams](#hls-video-streams-byte_me_hls)
- [Architecture](#architecture-overview)
- [Contributing](#contributing)

---

## Packages

This monorepo is split into focused, single-responsibility packages.

| Package | Description | Pub |
|---|---|---|
| [`byte_me_core`](./packages/byte_me_core) | The foundational download engine. Handles concurrency, task queuing, pausing, resuming, and network abstractions. | [![pub package](https://img.shields.io/pub/v/byte_me_core.svg)](https://pub.dev/packages/byte_me_core) |
| [`byte_me_hls`](./packages/byte_me_hls) | A specialized HLS (`.m3u8`) downloader built on the core engine. Handles segment batching, AES-128 decryption, and automatic video stitching. | [![pub package](https://img.shields.io/pub/v/byte_me_hls.svg)](https://pub.dev/packages/byte_me_hls) |

## Why Byte Me?

- **Strict Memory Management**: Downloads are streamed directly to disk. We batch segment downloads so large HLS streams never crash your app.
- **Robust Concurrency**: You dictate exactly how many parallel connections are allowed. The engine queues the rest.
- **Transport Agnostic**: The engine doesn't care if you use `http`, `dio`, or native sockets. Implement `DownloadTransport` and bring your own networking layer.
- **Extensible Plugin System**: The core engine is designed to be built upon, exactly as we did with the HLS package.

## Installation

Add the packages you need to your `pubspec.yaml`:

```yaml
dependencies:
  byte_me_core: ^1.0.0
  byte_me_hls: ^1.0.0
```

## Getting Started

### Standard Downloads (`byte_me_core`)

Perfect for simple files, ZIPs, PDFs, or direct MP4s.

```dart
import 'dart:io';
import 'package:byte_me_core/byte_me_core.dart';

// 1. Initialize the Engine
final transport = DartHttpTransport();
final engine = DownloadEngine(transport);

// 2. Setup the Manager with a strict concurrency limit
final manager = DownloadManager(
  engine: engine, 
  maxConcurrentDownloads: 3, 
);

// 3. Define the Request
final request = DownloadRequest(
  id: 'unique_task_id',
  url: Uri.parse('https://example.com/large_file.zip'),
  destination: File('/path/to/save/file.zip'),
);

final task = DownloadTask(request: request);

// Listen to network speed and progress
task.progressStream.listen((progress) {
  print('Progress: ${(progress.percentage * 100).toStringAsFixed(1)}%');
  print('Speed: ${progress.networkSpeed} bytes/sec');
});

// Enqueue it!
manager.enqueue(task);
```

### HLS Video Streams (`byte_me_hls`)

Perfect for offline video playback and DRM-protected or encrypted streams.

```dart
import 'package:byte_me_core/byte_me_core.dart';
import 'package:byte_me_hls/byte_me_hls.dart';

void main() async {
  final transport = DartHttpTransport();
  final engine = DownloadEngine(transport);
  
  // For HLS, this dictates how many .ts segments download simultaneously
  final manager = DownloadManager(engine: engine, maxConcurrentDownloads: 4);
  final hlsDownloader = HlsDownloader(manager);

  await hlsDownloader.downloadHlsVideo(
    m3u8Url: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
    savePath: '/path/to/save/my_movie.mp4',
    onProgress: (HlsProgress progress) {
      print('HLS Progress: ${progress.formattedPercentage} | Speed: ${progress.formattedSpeed}');
      print('Segments: ${progress.completedSegments}/${progress.totalSegments}');
    },
  );

  print('Video download and stitching complete!');
}
```

## Architecture Overview

```mermaid
flowchart TB
    classDef core fill:#e1f5fe,stroke:#01579b,stroke-width:2px,color:#000
    classDef hls fill:#f3e5f5,stroke:#4a148c,stroke-width:2px,color:#000
    classDef app fill:#e8f5e9,stroke:#1b5e20,stroke-width:2px,color:#000
    classDef io fill:#fff3e0,stroke:#e65100,stroke-width:2px,color:#000

    App([📱 Your Application]):::app

    subgraph ByteMeCore [📦 byte_me_core]
        Manager{DownloadManager}:::core
        Engine[DownloadEngine]:::core
        Transport[[DownloadTransport]]:::core
    end

    subgraph ByteMeHLS [🎞️ byte_me_hls]
        HlsDownloader[HlsDownloader]:::hls
        Parser(M3U8 Parser):::hls
        Decrypter(AES Decrypter):::hls
    end

    Disk[(💾 Local Storage)]:::io

    App ==>|1. Standard Download| Manager
    App ==>|2. HLS Stream| HlsDownloader

    HlsDownloader -->|Parses Playlist| Parser
    HlsDownloader -->|Enqueues Segments| Manager
    HlsDownloader -.->|Decrypts Segments| Decrypter

    Manager -->|Feeds Tasks| Engine
    Engine -->|Opens Connection| Transport
    Transport -->|Streams Bytes| Disk
```

## Contributing
We welcome contributions! Please open an issue before submitting a large pull request to discuss the changes you wish to make.
