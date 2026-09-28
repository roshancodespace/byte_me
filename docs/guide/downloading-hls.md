# Downloading HLS Streams

HTTP Live Streaming (HLS) delivers media by breaking a video into dozens or hundreds of small chunks (`.ts` or MPEG-TS segments), listed inside an `.m3u8` playlist.

Downloading HLS natively in Dart used to be a massive headache, often requiring heavy external binaries like FFmpeg. `byte_me` changes this by providing a completely native, isolate-driven pipeline to orchestrate, decrypt, and merge these segments seamlessly.

## Orchestrating the HLS Download

To download an HLS stream, use the `downloadHls()` method. 

```dart
import 'package:byte_me/byte_me.dart';

final job = downloader.downloadHls(
  id: 'hls-episode-1',
  url: Uri.parse('https://example.com/master_playlist.m3u8'),
  savePath: '/local/storage/path/episode_1.ts',
);
```

### What happens under the hood?

When you call `downloadHls`, the engine automatically performs the following steps:

1. **Playlist Parsing:** It fetches the `.m3u8` playlist. If it's a "Master Playlist" containing multiple quality streams, `byte_me` currently defaults to picking the first listed variant.
2. **Concurrent Chunking:** It parses the Media Playlist and schedules concurrent background downloads for all the MPEG-TS segments.
3. **AES-128 Decryption (if applicable):** If the stream is encrypted (indicated by `#EXT-X-KEY`), `byte_me` automatically fetches the decryption key, derives the Initialization Vector (IV) from the media sequence, and decrypts the chunks on the fly using background isolates to prevent UI thread blocking.
4. **Remuxing:** Once all chunks are safely downloaded and decrypted, they are passed to a `Remuxer` to be assembled into the final output file.

## Remuxers: The Assembly Line

By default, if you don't specify a remuxer, `byte_me` uses the `ConcatRemuxer`.

### The `ConcatRemuxer` (Default)

The `ConcatRemuxer` simply concatenates all the raw `.ts` fragments end-to-end into a single massive MPEG-TS file. 

```dart
final job = downloader.downloadHls(
  id: 'hls-concat-job',
  url: Uri.parse('https://example.com/playlist.m3u8'),
  savePath: '/downloads/output.ts', // Notice the .ts extension
  remuxer: const ConcatRemuxer(),    // This is the default if omitted
);
```

**Pros:**
- Extremely fast (just a binary append operation).
- Consumes very little CPU.

**Cons:**
- The resulting `.ts` file doesn't have a global duration or seeking index. 
- Fast-forwarding or scrubbing in media players can be highly inaccurate, laggy, or outright broken.

To solve the seeking and duration issues permanently, `byte_me` provides a vastly superior option: the `MkvRemuxer`. Head over to the [MKV Remuxing](./mkv-remuxing.md) guide to learn more.
