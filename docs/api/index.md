# API Reference

This page provides an overview of the primary classes and methods available in the `byte_me` engine.

## Core Classes

### `ByteMe`
The main orchestrator for all download tasks.

**Constructor:**
```dart
ByteMe({int maxConcurrentDownloads = 3})
```

**Methods:**
- `DownloadTask download({required String id, required Uri url, required String savePath, Map<String, String>? headers})`
  Starts or retrieves a standard file download task.
- `DownloadTask downloadHls({required String id, required Uri url, required String savePath, Remuxer remuxer = const ConcatRemuxer(), Map<String, String>? headers})`
  Starts or retrieves an HLS download task, applying the specified `Remuxer`.

---

### `DownloadTask`
Represents an ongoing or completed download operation.

**Properties:**
- `String get id`: The unique identifier for this task.
- `String get url`: The target URL.
- `String get savePath`: The absolute path where the file is being saved.

**Streams:**
- `Stream<DownloadProgress> get progressStream`: Emits updates on bytes received, total bytes, elapsed time, and download speed.
- `Stream<DownloadStatus> get statusStream`: Emits lifecycle events (`pending`, `running`, `completed`, `failed`, `cancelled`).

**Methods:**
- `void cancel()`: Immediately halts the task and cleans up temporary files.

---

### `Remuxer`
The interface for post-download processing of HLS segments.

**Implementations:**
- `ConcatRemuxer`: Appends `.ts` segments sequentially without demuxing. (Default)
- `MkvRemuxer`: Demuxes `.ts` segments, extracts raw H.264/AAC frames, and remuxes them into a Matroska (`.mkv`) container.

---

### `SubtitleTrack`
Used with `MkvRemuxer` to interleave subtitles into the output MKV file.

**Constructor:**
```dart
const SubtitleTrack({
  required File file, // Currently expects a local .srt file
  String? language,   // ISO 639-2 language code (e.g. 'eng')
  String? title,      // Display name in the media player
})
```
