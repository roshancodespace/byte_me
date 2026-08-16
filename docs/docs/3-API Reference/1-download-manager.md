---
sidebar_position: 1
id: download-manager
title: DownloadManager API
---

# DownloadManager

The `DownloadManager` is the core class of the Byte Me ecosystem. It acts as the global orchestrator for all download tasks.

## Constructors

### `DownloadManager.isolated()`
Creates a new manager that operates entirely on a background Isolate.
- **Parameters:**
  - `maxConcurrentJobs` (int): The maximum number of root-level jobs allowed to run concurrently. Defaults to 3.

```dart
final manager = DownloadManager.isolated(maxConcurrentJobs: 3);
```

---

## Methods

### `addFile(DownloadRequest request)`
Enqueues a standard file download into the global orchestrator.
- **Returns:** A `FileDownloadJob` instance which exposes a `progressStream`.

### `addHlsVideo({...})` *(Requires `byte_me_hls`)*
Enqueues a complex `.m3u8` video stream, allocating internal segment sub-queues.
- **Parameters:**
  - `id` (String): Unique identifier.
  - `m3u8Url` (String): The URL to the master or media playlist.
  - `savePath` (String): The absolute file path to stitch the final video.
  - `maxConcurrentSegments` (int): How many segments to download in parallel internally.
- **Returns:** An `HlsDownloadJob`.

### `pause(String id)`
Pauses an active download by closing its socket and flushing memory to disk safely.
- **Returns:** `Future<void>`

### `resume(String id)`
Resumes a paused download using HTTP Range requests based on the physical byte size on disk.
- **Returns:** `Future<void>`

### `cancel(String id)`
Completely cancels a download, aborts all network connections, and destroys partial files.
- **Returns:** `Future<void>`
