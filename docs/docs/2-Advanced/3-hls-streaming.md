---
sidebar_position: 3
id: hls-streaming
title: HLS Streaming
---

# Downloading HLS Videos

If you've ever tried to download an `.m3u8` HTTP Live Stream manually, you know it's a nightmare. You must parse the manifest, download hundreds of small `.ts` segments, decrypt them using AES-128 keys, and stitch them perfectly together.

The `byte_me_hls` plugin handles this entire lifecycle for you while remaining fully integrated with the global orchestrator queue.

## Usage Example

Because the HLS package extends the orchestrator, you don't create a separate manager. You just use the `.addHlsVideo()` method!

```dart
import 'package:byte_me/byte_me.dart';
import 'package:byte_me_hls/byte_me_hls.dart'; // Unlocks the extension!

final manager = DownloadManager.isolated(maxConcurrentJobs: 3);

final hlsJob = manager.addHlsVideo(
  id: 'movie_1',
  m3u8Url: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
  savePath: '/path/to/save/movie.mp4',
  
  // Magic: This video will spawn 5 internal sub-connections to fetch 
  // its segments extremely quickly!
  maxConcurrentSegments: 5, 
);

// The progress stream is completely unified! 
// It calculates the total segments and bytes so you can use the exact same UI as a standard file.
hlsJob.progressStream.listen((progress) {
  print('Progress: ${progress.formattedPercentage}');
});
```

## Behind the Scenes

Let's look at exactly what `addHlsVideo` is doing under the hood, and why it's so powerful.

### 1. Global Queue Integration
When you call `addHlsVideo`, it takes up exactly **1 slot** in your global `DownloadManager` queue. If your manager is set to `maxConcurrentJobs: 3`, and you enqueue 4 HLS videos, the 4th video will sit perfectly dormant until one of the first 3 finishes.

### 2. Internal Segment Sub-Queues
Once the global manager allows the HLS video to start, the plugin reads the `.m3u8` file. Let's say it finds 500 `.ts` video segments. 

Instead of dumping 500 jobs into your main app queue (which would freeze other downloads), it spawns an **internal segment queue**. The `maxConcurrentSegments: 5` parameter tells it to actively download 5 segments at a time. As one segment finishes, it grabs the next one out of the 500.

### 3. On-The-Fly Decryption
If the playlist contains an AES-128 encryption key (`EXT-X-KEY`), the plugin safely extracts the key over the network. 

As segments arrive, they are piped through a decryptor algorithm *in memory* on the background isolate, meaning the raw, decrypted bytes are safely flushed to disk without you ever seeing a corrupted file.

### 4. Zero-UI Stutter
Because you initialized the manager with `DownloadManager.isolated()`, this massive operation of networking, AES-128 math decryption, and chunked disk writing happens on a completely separate thread. Your Flutter UI thread remains untouched, keeping your app locked at 60/120 FPS.
