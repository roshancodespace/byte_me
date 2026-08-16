# Byte Me Core

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

> **⚠️ IMPORTANT**: `byte_me_core` is the low-level networking engine for the Byte Me ecosystem. **For 99% of applications, you should install the [byte_me](../byte_me) package instead!** 

`byte_me_core` handles the raw networking, file I/O, byte stream parsing, pausing/resuming byte streams, and exponential backoff retries. It provides the foundational tools required to build complex download jobs.

---

## Features

- **Raw Network Power**: Efficient byte stream processing for downloading any HTTP asset.
- **Resumability**: HTTP Range requests are supported out of the box. Pause and resume large files effortlessly.
- **Automatic Retries & Exponential Backoff**: Transient network errors are caught, and the engine automatically retries failed chunks safely.
- **Isolate Offloading**: `IsolatedDownloadEngine` moves all heavy file I/O and networking to a background thread to keep your UI buttery smooth.
- **Transport Agnostic**: Use our built-in `DartHttpTransport` (via the `http` package), or write an adapter for `dio` or raw sockets by implementing `DownloadTransport`.

## Installation

You typically shouldn't install this directly unless you are building a custom plugin. Install `byte_me` instead.

```yaml
dependencies:
  byte_me_core:
    git:
      url: https://github.com/roshancodespace/byte_me.git
      path: packages/byte_me_core
```

## Core Architecture

- **`DownloadEngine`**: The worker. It handles the actual HTTP requests, file I/O, throttling, and retries.
- **`DownloadRequest`**: A simple data class containing the URL, destination File, HTTP headers, and retry logic.
- **`DownloadTask`**: The low-level byte task wrapping a request. It emits progress and status changes.
- **`DownloadProgress`**: Contains stats like `receivedBytes`, `totalBytes`, `networkSpeed`, `formattedPercentage`, and `formattedSpeed`.

## Usage Guide (Low Level)

If you are building a custom plugin (like `byte_me_hls`) and need to access the bare-metal engine:

```dart
import 'package:byte_me_core/byte_me_core.dart';
import 'dart:io';

// 1. Create a background engine
final engine = IsolatedDownloadEngine(() => DartHttpTransport());

// 2. Define the exact HTTP request
final request = DownloadRequest(
  id: 'chunk_1',
  url: Uri.parse('https://example.com/file.zip'),
  destination: File('/path/file.zip'),
  retryConfig: RetryConfig(maxRetries: 3),
);

// 3. Create a low-level task
final task = DownloadTask(request: request);

// Listen to raw byte progress
task.progressStream.listen((progress) {
  print('Progress: ${progress.formattedPercentage} at ${progress.formattedSpeed}');
});

// 4. Execute the task directly on the engine
await engine.executeTask(task);
```

## Custom Transports

Want to use `dio` instead of the standard `http` package? Just implement the `DownloadTransport` interface!

```dart
class DioTransport implements DownloadTransport {
  @override
  Future<DownloadResponse> open(DownloadRequest request) async {
    // Implement your Dio logic here and return a DownloadResponse stream!
  }
}
```
