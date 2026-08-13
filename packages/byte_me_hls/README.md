# Downloader HLS

[![pub package](https://img.shields.io/pub/v/byte_me_hls.svg)](https://pub.dev/packages/byte_me_hls)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

A specialized, high-performance HTTP Live Streaming (HLS) downloader built on top of [`byte_me_core`](../byte_me_core).

Downloading HLS streams can be incredibly complex. `byte_me_hls` takes away the pain by automatically parsing playlists, managing massive concurrent segment downloads efficiently, decrypting protected streams, and stitching everything into a single, cohesive video file.

---

## Features

- **Smart M3U8 Parsing**: Automatically parses both master and media `.m3u8` playlists.
- **Concurrent Segments**: Downloads `.ts` segments concurrently using an async worker pool to maximize bandwidth without blowing up memory.
- **On-the-fly Decryption**: Seamlessly decrypts AES-128 protected segments during the download process.
- **Automatic Stitching**: Combines thousands of scattered video segments into a single, ready-to-play `.mp4` or `.ts` file.
- **Segment-Aware Progress**: Emits rich progress data including completed segments and total network speed.

## Installation

Add `byte_me_hls` to your `pubspec.yaml` (it will automatically include `byte_me_core`):

```yaml
dependencies:
  byte_me_hls:
    path: ../byte_me_hls
```

## Quick Start

### 1. Setup the Engine
Initialize the core download engine.

```dart
import 'package:byte_me_core/byte_me_core.dart';
import 'package:byte_me_hls/byte_me_hls.dart';

final transport = DartHttpTransport();
final engine = DownloadEngine(transport);

// Dictates how many segments can download at the exact same time.
// A concurrency of 4-8 is generally optimal for HLS.
final manager = DownloadManager(engine: engine, maxConcurrentDownloads: 4);
final hlsDownloader = HlsDownloader(manager);
```

### 2. Start the Download
Provide the playlist URL and a destination path. The downloader handles the rest.

```dart
await hlsDownloader.downloadHlsVideo(
  m3u8Url: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
  savePath: '/path/to/save/my_movie.mp4',
  onProgress: (HlsProgress progress) {
    print('''
      HLS Progress: ${progress.formattedPercentage}
      Speed: ${progress.formattedSpeed}
      Segments: ${progress.completedSegments}/${progress.totalSegments}
    ''');
  },
);

print('🎉 Video download and stitching complete!');
```

## Under the Hood

When you call `downloadHlsVideo`, the package:
1. Fetches and parses the `.m3u8` file.
2. Creates a temporary directory.
3. Spawns an efficient worker pool (matching your `maxConcurrentDownloads`) to download segments safely.
4. Checks for and applies AES decryption keys if the stream is protected.
5. Sequentially streams the downloaded bytes into your final `savePath`.
6. Cleans up all temporary segments automatically.
