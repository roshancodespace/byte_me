---
sidebar_position: 2
id: standard-downloads
title: Standard Downloads
---

# Standard File Downloads

When you enqueue a standard file (like a PDF, ZIP, or Image) into the `DownloadManager`, it returns a `DownloadJob` instance.

This instance is your remote control and status monitor. 

## Listening to Progress

Instead of calculating percentages and speeds manually in your UI code, the `DownloadJob` provides heavily optimized UI getters directly.

```dart
final job = manager.addFile(
  DownloadRequest(
    id: 'my_file',
    url: Uri.parse('https://example.com/file.zip'),
    destination: File('/path/to/file.zip'),
  )
);

// Stream progress directly into a Flutter StreamBuilder!
job.progressStream.listen((progress) {
  
  if (progress.status == DownloadStatus.downloading) {
    // Look how clean this is for your UI!
    print(progress.formattedPercentage); // e.g., "45.2%"
    print(progress.formattedSpeed);      // e.g., "2.4 MB/s"
    print(progress.progress);            // e.g., 0.452 (For LinearProgressIndicator)
  }

  if (progress.status == DownloadStatus.completed) {
    print('Download finished!');
  }
});
```

## Global Control (Pause, Resume, Cancel)

You don't need to keep the `job` object around to control it. Because `DownloadManager` acts as a global orchestrator, you can control any job from anywhere in your app using its `id`.

```dart
// ⏸️ Pause the download. 
// Behind the scenes: Byte Me gracefully closes the HTTP stream and disk handles.
await manager.pause('my_file');

// ▶️ Resume the download.
// Behind the scenes: Byte Me inspects the file on disk, extracts the exact byte size, 
// and issues an HTTP `Range: bytes=50000-` request to resume instantly without wasting data!
await manager.resume('my_file');

// 🛑 Cancel the download.
// Behind the scenes: Removes the job from the queue and cleans up the partial file.
await manager.cancel('my_file');
```

By relying on the global manager, your UI architecture becomes incredibly clean. A "Pause" button in your Flutter widget simply fires `manager.pause(id)` and walks away. The `progressStream` will automatically emit the new `DownloadStatus.paused` state!
