# Byte Me HLS

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

A specialized, high-performance HTTP Live Streaming (HLS) downloader for Dart and Flutter. 

Built on top of `byte_me_core`, this package abstracts away the immense complexity of downloading HLS streams. It handles playlist parsing, segment extraction, concurrent downloading, on-the-fly decryption, and final video stitching—all in just a few lines of code.

---

## Table of Contents
- [Features](#features)
- [Installation](#installation)
- [How It Works](#how-it-works)
- [Usage Guide](#usage-guide)
  - [Initialization](#initialization)
  - [Downloading & Progress](#downloading--progress)

---

## Features

- **Master & Media Playlist Parsing**: Intelligently parses `.m3u8` files to find video segments.
- **Concurrent Batching**: Downloads `.ts` segments in parallel async batches. This saturates your network bandwidth without flooding your device's memory.
- **AES-128 Decryption**: Automatically detects encrypted streams, fetches the decryption keys, and decrypts segments on the fly.
- **Automatic File Stitching**: Combines thousands of scattered video segments into a single, cohesive `.mp4` or `.ts` file ready for offline playback.
- **Rich Progress API**: Emits an `HlsProgress` object containing completed segments, total segments, and aggregated network speed across all active batch workers.

## Installation

Add `byte_me_hls` to your `pubspec.yaml` (it automatically depends on `byte_me_core`):

```yaml
dependencies:
  byte_me_hls:
    git:
      url: https://github.com/roshancodespace/byte_me.git
      path: packages/byte_me_hls
```

## How It Works

Downloading an HLS stream is fundamentally different from a standard file download because the video is broken into hundreds or thousands of tiny `.ts` segments. 

If a downloader queues all 1,000 segments into memory at once, the application will crash. `byte_me_hls` solves this by:
1. Parsing the `.m3u8` file to map the segments.
2. Spawning a controlled number of async "workers" (based on your `maxConcurrentDownloads`).
3. Each worker safely grabs a segment, downloads it using `byte_me_core`, and decrypts it to a temporary directory.
4. Once all segments are downloaded, they are sequentially stitched into a single file, and the temporary directory is wiped.

## Usage Guide

### Initialization

Because `byte_me_hls` relies on the core engine, you must initialize `byte_me_core` first.

```dart
import 'package:byte_me_core/byte_me_core.dart';
import 'package:byte_me_hls/byte_me_hls.dart';

// Initialize the core engine
final transport = DartHttpTransport();
final engine = DownloadEngine(transport);

// The concurrency limit here dictates exactly how many HLS segments 
// will be downloaded at the exact same time. 
// We recommend a value between 4 and 8 for optimal HLS performance.
final manager = DownloadManager(engine: engine, maxConcurrentDownloads: 4);

// Initialize the specialized HLS downloader
final hlsDownloader = HlsDownloader(manager);
```

### Downloading & Progress

To download a stream, provide the master playlist URL and the destination file path.

```dart
await hlsDownloader.downloadHlsVideo(
  m3u8Url: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
  savePath: '/path/to/save/offline_movie.mp4',
  
  // Optional headers for authentication (passed to both the playlist and segment requests)
  headers: {
    'Authorization': 'Bearer YOUR_TOKEN'
  },
  
  // Real-time progress updates
  onProgress: (HlsProgress progress) {
    // Easily display progress in your UI
    print('HLS Progress: ${progress.formattedPercentage}');
    print('Segments: ${progress.completedSegments}/${progress.totalSegments}');
    
    // Aggregated speed across all active segment workers
    print('Speed: ${progress.formattedSpeed}');
  },
);

print('🎉 Video downloaded, stitched, and ready for playback!');
```
