import 'dart:io';

import 'package:byte_me/byte_me.dart';

/// Remuxes MPEG-TS segments into a Matroska (MKV) container using FFmpeg.
///
/// This is highly robust and correctly handles PTS/DTS scaling, B-frames,
/// and subtitle multiplexing without the bugs of manual demuxing.
class FfmpegRemuxer implements Remuxer {
  final List<SubtitleTrack> subtitles;

  const FfmpegRemuxer({this.subtitles = const []});

  @override
  Future<void> remux(List<File> segments, String outputPath) async {
    // 1. Binary concatenate all TS segments into a single .ts file
    final tempTsPath = '$outputPath.temp.ts';
    final tempTsFile = File(tempTsPath);
    final sink = tempTsFile.openWrite();
    for (final segment in segments) {
      if (!segment.existsSync()) continue;
      await sink.addStream(segment.openRead());
    }
    await sink.flush();
    await sink.close();

    final tempSubtitleFiles = <File>[];

    try {
      // Prepare subtitles (download if needed)
      final subtitlePaths = <String>[];
      for (var i = 0; i < subtitles.length; i++) {
        final sub = subtitles[i];
        if (sub.file != null && sub.file!.existsSync()) {
          subtitlePaths.add(sub.file!.path);
        } else if (sub.url != null) {
          try {
            final request = await HttpClient().getUrl(Uri.parse(sub.url!));
            final response = await request.close();
            if (response.statusCode == 200) {
              final tempSub = File('$outputPath.sub$i.srt');
              final subSink = tempSub.openWrite();
              await response.pipe(subSink);
              subtitlePaths.add(tempSub.path);
              tempSubtitleFiles.add(tempSub);
            }
          } catch (e) {
            // Ignore subtitle download failures
          }
        }
      }

      // 2. Build FFmpeg command
      final args = ['-y', '-i', tempTsPath];

      // Add subtitles
      for (final path in subtitlePaths) {
        args.addAll(['-i', path]);
      }

      // Map streams
      args.addAll(['-map', '0:v', '-map', '0:a?']);
      for (var i = 0; i < subtitlePaths.length; i++) {
        args.addAll(['-map', '${i + 1}:0']);
      }

      // Copy codecs
      args.addAll(['-c', 'copy']);

      // Subtitle metadata
      for (var i = 0; i < subtitlePaths.length; i++) {
        final sub = subtitles[i];
        if (sub.language != null) {
          args.addAll(['-metadata:s:s:$i', 'language=${sub.language}']);
        }
        if (sub.title != null) {
          args.addAll(['-metadata:s:s:$i', 'title=${sub.title}']);
        }
      }

      args.add(outputPath);

      // 3. Run FFmpeg
      final result = await Process.run('ffmpeg', args);
      if (result.exitCode != 0) {
        throw Exception('FFmpeg remux failed: ${result.stderr}');
      }
    } finally {
      // Clean up temp files
      if (tempTsFile.existsSync()) {
        tempTsFile.deleteSync();
      }
      for (final f in tempSubtitleFiles) {
        if (f.existsSync()) f.deleteSync();
      }
    }
  }
}
