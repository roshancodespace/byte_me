# Adding Subtitles

One of the superpowers of the `MkvRemuxer` is its ability to natively inject external subtitle files directly into the Matroska container.

When you multiplex subtitles into the MKV file, they are stored as standard `S_TEXT/UTF8` tracks. Modern media players (like VLC, MPV, or Flutter's `media_kit`) will automatically detect them, allowing the user to toggle them on/off seamlessly.

## Injecting SRT Subtitles

To add subtitles, pass a list of `SubtitleTrack` configurations to the `MkvRemuxer` when starting your download.

`byte_me` features a built-in `.srt` parser. It will automatically parse your `.srt` files, extract the timecodes, and accurately interleave the subtitle payloads into the MKV `BlockGroups` alongside the video and audio frames based on their Presentation Timestamps (PTS).

```dart
import 'dart:io';
import 'package:byte_me/byte_me.dart';

// Assuming you've already downloaded or generated these SRT files locally:
final engSub = File('/path/to/english.srt');
final jpnSub = File('/path/to/japanese.srt');

final job = downloader.downloadHls(
  id: 'hls-with-subs',
  url: Uri.parse('https://example.com/playlist.m3u8'),
  savePath: '/downloads/output.mkv',
  remuxer: MkvRemuxer(
    subtitles: [
      SubtitleTrack(
        file: engSub,
        language: 'eng',        // Optional: ISO 639-2 language code
        title: 'English (US)',  // Optional: Track title displayed in player
      ),
      SubtitleTrack(
        file: jpnSub,
        language: 'jpn',
        title: 'Japanese',
      ),
    ],
  ),
);
```

### Important Notes

1. **Local Files Required:** The `SubtitleTrack` expects a local `File`. If your subtitles are hosted at remote URLs, you must download them locally yourself *before* passing them into the `MkvRemuxer`.
2. **Supported Formats:** Currently, only SubRip Text (`.srt`) files are supported by the internal parser. 
3. **Timecode Accuracy:** The subtitle interleaving relies on the accuracy of the `.srt` timecodes mapping correctly to the video stream's PTS. If your subtitles are desynced from the video source, they will remain desynced in the output file.
