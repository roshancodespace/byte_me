# byte_me

`byte_me` is a highly cohesive, high-performance download engine tailored for Dart and Flutter applications. It is purpose-built to handle complex downloading scenarios—such as encrypted HLS (HTTP Live Streaming) playlists—with zero external dependencies (no FFmpeg required).

## Features

- **Concurrent Downloading:** Automatically pools HTTP connections and handles multi-part downloads using `dart:io`.
- **HLS Native Support:** Parses M3U8 playlists, resolves segment URIs, and handles AES-128 decryption.
- **Background Isolates:** Offloads heavily CPU-bound tasks—like decryption and remuxing—to isolates to keep your Flutter UI 100% jank-free.
- **Genuine Remuxing:** Provides an in-house MPEG-TS demuxer that extracts raw H.264 video and AAC audio frames, multiplexing them directly into a standard Matroska (`.mkv`) container.
- **Subtitle Injection:** Seamlessly interleaves external `.srt` subtitle files directly into the generated MKV video file.

## Getting Started

Initialize the engine:

```dart
import 'package:byte_me/byte_me.dart';

final downloader = ByteMe(maxConcurrentDownloads: 3);
```

### Simple File Download

```dart
final job = downloader.download(
  id: 'job-1',
  url: Uri.parse('https://example.com/file.zip'),
  savePath: '/downloads/file.zip',
);

job.progressStream.listen((progress) {
  print('Progress: ${progress.percent}%');
});
```

### HLS Stream Download with MKV Remuxing and Subtitles

```dart
final job = downloader.downloadHls(
  id: 'hls-1',
  url: Uri.parse('https://example.com/playlist.m3u8'),
  savePath: '/downloads/video.mkv',
  remuxer: MkvRemuxer(
    subtitles: [
      SubtitleTrack(
        file: File('/downloads/english.srt'),
        language: 'eng',
        title: 'English',
      ),
    ],
  ),
);

job.statusStream.listen((status) {
  if (status == DownloadStatus.completed) {
    print('MKV video successfully saved and remuxed!');
  }
});
```

## Documentation

Full developer documentation (powered by VitePress) is available in the `docs/` folder.
To run the documentation locally:

```bash
cd docs
pnpm install
pnpm docs:dev
```
