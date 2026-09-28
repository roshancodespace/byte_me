# Downloading Standard Files

While `byte_me` shines with HLS streams, it is also a robust, concurrent engine for standard HTTP file downloads.

Use `download()` to fetch `.mp4` video files, `.zip` archives, images, or any other direct URL.

## Basic Usage

The `download` method returns a `DownloadTask` which you can use to monitor progress, cancel, or pause the operation.

```dart
import 'package:byte_me/byte_me.dart';

// Assuming you've instantiated the ByteMe engine:
// final downloader = ByteMe(maxConcurrentDownloads: 3);

final job = downloader.download(
  id: 'unique-job-id-123',
  url: Uri.parse('https://example.com/large_video.mp4'),
  savePath: '/local/storage/path/large_video.mp4',
);
```

### Understanding the Parameters

- **`id`**: A unique `String` identifier for the job. If you attempt to start a download with an ID that is already running, the engine will safely ignore the duplicate request and return the existing active `DownloadTask`.
- **`url`**: The direct `Uri` of the file to download.
- **`savePath`**: The absolute path on the local file system where the file should be saved. `byte_me` will automatically create any missing parent directories.
- **`headers`** *(optional)*: A map of HTTP headers to pass along (e.g. for authentication or User-Agent spoofing).

## Tracking Progress

The `DownloadTask` provides a reactive `progressStream` that emits `DownloadProgress` objects in real-time. This is perfect for driving progress bars in your UI.

```dart
job.progressStream.listen((progress) {
  print('Percent complete: ${progress.percent.toStringAsFixed(1)}%');
  print('Bytes received: ${progress.receivedBytes} / ${progress.totalBytes}');
  print('Speed: ${(progress.bytesPerSecond / 1024 / 1024).toStringAsFixed(2)} MB/s');
});
```

> [!NOTE]
> `totalBytes` will be `null` if the remote server does not provide a `Content-Length` header. Always check for null before using it to calculate a percentage. The `percent` property gracefully handles this by returning `0.0`.

## Handling Lifecycle Events

You can observe the overall lifecycle of the task via the `statusStream`. 

```dart
job.statusStream.listen((status) {
  switch (status) {
    case DownloadStatus.pending:
      print('Waiting in the queue...');
      break;
    case DownloadStatus.running:
      print('Downloading actively!');
      break;
    case DownloadStatus.completed:
      print('Download finished successfully.');
      break;
    case DownloadStatus.failed:
      print('Download encountered an error.');
      break;
    case DownloadStatus.cancelled:
      print('User cancelled the download.');
      break;
  }
});
```

## Cancelling a Task

If the user navigates away or explicitly cancels the operation, you can halt the download instantly:

```dart
// Stops the download and cleans up any partially downloaded temporary data.
job.cancel();
```
