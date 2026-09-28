# Isolates & Performance

When building `byte_me`, the primary architectural goal was to ensure the Flutter UI remains absolutely pristine at 60 or 120 FPS, regardless of how aggressively the engine is downloading or parsing media.

Dart's single-threaded event loop means that if you perform heavy synchronous work—like cryptographic decryption or video file parsing—the UI will freeze until that work completes.

## Strategic Background Processing

`byte_me` leverages Dart `Isolate`s precisely at the points of highest CPU contention. 

Instead of spawning long-lived, complex background isolates that require complicated message passing, `byte_me` heavily utilizes `Isolate.run()` to offload expensive pure functions ephemerally.

### 1. AES-128 Decryption
HLS streams often protect their `.ts` segments using AES-128 encryption. Each 2-6 second segment can be several megabytes in size. Decrypting these chunks synchronously would cause noticeable micro-stutters in a Flutter app.

In `byte_me`, every downloaded encrypted chunk is passed to:
```dart
await Isolate.run(() => _decryptChunk(ciphertext, key, iv));
```
This isolates the cryptography workload entirely from the main UI thread.

### 2. MKV Remuxing
The `MkvRemuxer` is computationally intensive. It must:
1. Parse dozens or hundreds of `.ts` files.
2. Demux them to extract raw H.264 NAL units and AAC ADTS frames.
3. Parse Sequence Parameter Sets (SPS) and Picture Parameter Sets (PPS).
4. Organize frames by their Presentation Timestamp (PTS).
5. Interleave subtitles.
6. Write heavily nested Matroska/EBML blocks to disk.

All of this happens inside a single `Isolate.run()` closure at the very end of an HLS download. You can happily route animations and page transitions while `byte_me` builds a massive MKV file in the background.

## Network Concurrency

For networking, `byte_me` relies heavily on `dart:io`'s `HttpClient`. By reusing a single client, connections to the same CDN are automatically kept alive and pooled, massively reducing TLS handshake overhead.

The concurrency limit (`maxConcurrentDownloads`) orchestrates how many active network sockets are open simultaneously. The task queue ensures that if a user queues up 10 episodes, `byte_me` only actively hammers the disk and network for 3 of them at a time, preventing memory exhaustion and preserving network stability.
