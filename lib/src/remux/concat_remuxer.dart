import 'dart:io';

import 'remuxer.dart';

/// Simple binary concatenation of MPEG-TS segments.
///
/// This is the fastest remuxer — it performs no transcoding or format
/// conversion. The output is a concatenated .ts file (playable by most
/// players despite the extension).
///
/// For proper container wrapping, use [MkvRemuxer] or a custom [Remuxer].
class ConcatRemuxer implements Remuxer {
  const ConcatRemuxer();

  @override
  Future<void> remux(List<File> segments, String outputPath) async {
    final output = File(outputPath);
    final sink = output.openWrite();

    for (final segment in segments) {
      if (!segment.existsSync()) {
        throw StateError('Missing segment: ${segment.path}');
      }
      await sink.addStream(segment.openRead());
    }

    await sink.flush();
    await sink.close();
  }
}
