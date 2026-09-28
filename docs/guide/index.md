# Getting Started

`byte_me` is a high-performance download and remuxing engine. It's built specifically for intermediate to advanced Flutter developers who need precise control over complex downloading scenarios, such as encrypted HLS (HTTP Live Streaming) and native TS-to-MKV remuxing, without relying on bloated dependencies like FFmpeg.

This guide will walk you through setting up `byte_me` in your project and initializing the core engine.

## Installation

`byte_me` is **not available on pub.dev** to ensure we can maintain strict quality control and iterate rapidly alongside our core apps. You can include it in your project using one of two methods:

### Method 1: Git Dependency (Recommended)

To pull the package directly from the repository, add the following to your `pubspec.yaml`:

```yaml
dependencies:
  byte_me:
    git:
      url: https://github.com/roshancodespace/ShonenX.git
      path: packages/byte_me
      ref: main
```

### Method 2: Internal Monorepo Package

If you are working inside the ShonenX workspace or a similar monorepo structure where `byte_me` is checked out locally alongside your app, reference it via a relative path:

```yaml
dependencies:
  byte_me:
    path: ../packages/byte_me
```

## Initialization

The central orchestrator for all downloads is the `ByteMe` class. It manages connection pooling, isolates, and concurrency limits across all your tasks.

```dart
import 'package:byte_me/byte_me.dart';

// Create a central downloader instance. 
// You typically want only ONE instance of this in your app.
final downloader = ByteMe(maxConcurrentDownloads: 3);
```

> [!TIP]
> **State Management Integration**
> We recommend providing the `ByteMe` instance globally via your state management solution (e.g. Riverpod `Provider` or GetIt singleton). This ensures connection pooling is reused efficiently across your app.

## Your First Download

The engine exposes two primary methods depending on the type of media you are fetching:

1. **Standard Files:** Use `downloader.download()` for `.mp4`, `.zip`, images, or any standard direct HTTP file.
2. **HLS Playlists:** Use `downloader.downloadHls()` for `.m3u8` streams. This automatically handles downloading segments, AES decryption, and remuxing.

### Next Steps

Now that you have the engine initialized, let's look at how to use it in practice.

- [Downloading Standard Files](./downloading-files.md) - Learn how to orchestrate basic file downloads and track progress.
- [Downloading HLS Streams](./downloading-hls.md) - Learn how to fetch, decrypt, and piece together fragmented HLS streams.
- [MKV Remuxing](./mkv-remuxing.md) - Discover how to convert raw `.ts` fragments into highly seekable Matroska containers.
