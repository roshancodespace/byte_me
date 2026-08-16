---
sidebar_position: 1
id: getting-started
slug: /getting-started
title: Getting Started
---

# Getting Started

**Byte Me** is a unified downloading ecosystem. Whether you are downloading a simple 1MB image or a massive 4K encrypted HLS video stream, you interact with the exact same unified API. 

You do **not** need to worry about memory exhaustion, thread blocking, or UI stutter. The global orchestrator handles everything on a background isolate.

## Installation

Add the packages to your `pubspec.yaml`:

```yaml
dependencies:
  # The unified orchestrator
  byte_me:
    git:
      url: https://github.com/roshancodespace/byte_me.git
      path: packages/byte_me
      
  # Optional: Include this ONLY if you need to download HLS (.m3u8) videos
  byte_me_hls:
    git:
      url: https://github.com/roshancodespace/byte_me.git
      path: packages/byte_me_hls
```

## The "One-Stop" Quick Start

You only need to interact with **one** class: the `DownloadManager`. 

```dart
import 'package:byte_me/byte_me.dart';
import 'package:byte_me_hls/byte_me_hls.dart'; // unlocks addHlsVideo()
import 'dart:io';

void main() async {
  // 1. Initialize the manager on a background Isolate!
  // This automatically protects your UI thread.
  final manager = DownloadManager.isolated(
    maxConcurrentJobs: 3, // Only 3 active downloads at a time. The rest are queued!
  );

  // 2. Queue a standard file download
  manager.addFile(
    DownloadRequest(
      id: 'pdf_1',
      url: Uri.parse('https://example.com/massive_book.pdf'),
      destination: File('/app/book.pdf'),
    )
  );

  // 3. Queue an HLS video download
  manager.addHlsVideo(
    id: 'movie_1',
    m3u8Url: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
    savePath: '/app/movie.mp4',
    maxConcurrentSegments: 5,
  );
}
```

That's it. You don't need to learn multiple packages. The `DownloadManager` handles standard files and complex HLS streams simultaneously through the exact same queue!
