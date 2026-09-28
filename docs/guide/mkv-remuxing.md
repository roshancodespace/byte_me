# MKV Remuxing

When downloading HLS streams, the raw `.ts` (MPEG-TS) fragments lack a cohesive global index, making seeking (fast-forwarding/rewinding) in video players incredibly frustrating or inaccurate. 

To solve this, `byte_me` features a built-in `MkvRemuxer`.

## What is Genuine Remuxing?

The `MkvRemuxer` performs **genuine remuxing**. It completely strips away the raw MPEG-TS transport layer, extracting the underlying H.264 video frames and AAC audio frames. It then recalculates their timestamps and packages them neatly into a highly standardized Matroska (`.mkv`) container. 

Crucially, this is done **without re-encoding**. The actual video and audio quality is preserved exactly as it was broadcast, saving immense amounts of CPU time compared to using tools like FFmpeg.

## Using the MkvRemuxer

To activate this behavior, simply pass an instance of `MkvRemuxer` to your `downloadHls()` call, and change your output extension to `.mkv`.

```dart
import 'package:byte_me/byte_me.dart';

final job = downloader.downloadHls(
  id: 'hls-mkv-job',
  url: Uri.parse('https://example.com/playlist.m3u8'),
  savePath: '/downloads/output.mkv', // Ensure you use .mkv
  remuxer: const MkvRemuxer(),       // Use the Matroska remuxer
);
```

### Performance & Isolates

Demuxing hundreds of transport stream files and rebuilding Matroska clusters is an inherently CPU-heavy task. 

`byte_me` is designed explicitly for Flutter, meaning it guarantees that **the UI thread will never freeze**. The `MkvRemuxer` orchestrates the entire demuxing and Matroska clustering pipeline inside a background `Isolate` (using `Isolate.run`). The main thread remains at a smooth 60/120fps while the background thread chews through the heavy lifting.

> [!WARNING]
> **Codec Support**
> The `MkvRemuxer` currently supports extracting and remuxing **H.264 (AVC)** video and **AAC** audio. If the HLS stream is broadcasting in H.265 (HEVC) or using AC-3 audio, the remuxer may fail to extract the frames. In these rare cases, you should fall back to the `ConcatRemuxer`.

Next, learn how you can use the `MkvRemuxer` to seamlessly [Add Subtitles](./subtitles.md) to your MKV files!
