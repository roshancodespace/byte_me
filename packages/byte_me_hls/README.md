# Byte Me HLS

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

A specialized, high-performance HTTP Live Streaming (HLS) plugin for the `byte_me` orchestrator ecosystem.

This package abstracts away the immense complexity of downloading HLS streams. It handles playlist parsing, segment extraction, concurrent downloading, on-the-fly decryption, and final video stitching—all fully integrated into the `byte_me` global queue.

---

## Features

- **Global Integration**: Implements the `DownloadJob` interface, meaning your HLS videos share the same global queue, concurrency rules, and status streams as standard file downloads!
- **Master & Media Playlist Parsing**: Intelligently parses `.m3u8` files to find video segments.
- **Concurrent Batching**: Downloads `.ts` segments in parallel async batches using an internal segment queue, without clogging up your top-level `byte_me` video queue!
- **AES-128 Decryption**: Automatically detects encrypted streams, fetches the decryption keys, and decrypts segments on the fly.
- **Automatic File Stitching**: Combines thousands of scattered video segments into a single, cohesive `.mp4` or `.ts` file ready for offline playback.

## Installation

Add both `byte_me` and `byte_me_hls` to your `pubspec.yaml`:

```yaml
dependencies:
  byte_me:
    git:
      url: https://github.com/roshancodespace/byte_me.git
      path: packages/byte_me
  byte_me_hls:
    git:
      url: https://github.com/roshancodespace/byte_me.git
      path: packages/byte_me_hls
```

## How It Works

Downloading an HLS stream is fundamentally different from a standard file download because the video is broken into hundreds or thousands of tiny `.ts` segments. 

If a downloader queues all 1,000 segments into memory at once, the application will crash. `byte_me_hls` solves this by natively integrating with `byte_me`. When an `HlsDownloadJob` begins execution, it spawns its *own* internal sub-queue to safely throttle segment downloads while the top-level queue manages high-level video streams.

## Usage Guide

### Initialization

Because `byte_me_hls` acts as a plugin, it automatically injects an `addHlsVideo` extension method onto the `DownloadManager`!

```dart
import 'package:byte_me/byte_me.dart';
import 'package:byte_me_hls/byte_me_hls.dart'; // Unlocks the extension

// The global orchestrator (allows 2 videos/files to download simultaneously)
final manager = DownloadManager.isolated(maxConcurrentJobs: 2);
```

### Queueing an HLS Video

```dart
// Enqueue the video into the global manager
final hlsJob = manager.addHlsVideo(
  id: 'unique_video_id',
  m3u8Url: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
  savePath: '/path/to/save/offline_movie.mp4',
  
  // This video will internally use 5 connections to download its segments
  maxConcurrentSegments: 5,
  
  // Optional headers for authentication
  headers: {
    'Authorization': 'Bearer YOUR_TOKEN'
  },
);

// Real-time progress updates are completely unified with standard downloads!
hlsJob.progressStream.listen((progress) {
  print('HLS Progress: ${progress.formattedPercentage}');
  print('Speed: ${progress.formattedSpeed}');
  
  // For HLS, totalBytes refers to total segments!
  print('Segments: ${progress.receivedBytes}/${progress.totalBytes}');
});

hlsJob.statusStream.listen((status) {
  if (status == DownloadStatus.completed) {
    print('🎉 Video downloaded, stitched, and ready for playback!');
  }
});
```

### Advanced: Skipping Built-in Remuxing (FFmpeg integration)

If you don't want the package to naively concatenate the segments (e.g., if you want to remux the segments yourself using FFmpeg, bind subtitles, or change the container format), you can set `stitch: false`.

When `stitch: false`, the `savePath` acts as a directory where the decrypted `.ts` segments will be saved. We will also automatically generate a `segments.txt` file ready for FFmpeg.

```dart
final hlsJob = manager.addHlsVideo(
  id: 'unstitched_video',
  m3u8Url: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
  savePath: '/path/to/save/segments_folder', // Treat as directory
  stitch: false,
);

// Wait for completion... then run FFmpeg manually on the generated segments.txt:
// ffmpeg -f concat -safe 0 -i /path/to/save/segments_folder/segments.txt -c copy output.mp4
```

### Pausing, Resuming & Cancelling

You can manage the lifecycle using the global `manager`, or directly on the `hlsJob` instance. All commands safely suspend the internal segment workers without losing downloaded data.

```dart
// Pause the download globally
manager.pause('unique_video_id');

// Resume the download globally
manager.resume('unique_video_id');

// Cancel the download completely
manager.cancel('unique_video_id');
```
