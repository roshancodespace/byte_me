import 'dart:convert';
import 'dart:io';

/// Information about a subtitle track to be muxed.
class SubtitleTrack {
  /// The subtitle file (e.g. .srt).
  final File? file;

  /// The subtitle URL (to be downloaded before parsing).
  final String? url;

  /// Optional ISO 639-2 language code (e.g. "eng", "jpn").
  final String? language;

  /// Optional human-readable title.
  final String? title;

  /// Optional headers (e.g., Referer) required to download the subtitle URL.
  final Map<String, String>? headers;

  const SubtitleTrack({
    this.file,
    this.url,
    this.language,
    this.title,
    this.headers,
  }) : assert(file != null || url != null, 'Must provide either file or url');
}

/// A parsed subtitle frame.
class SubtitleFrame {
  /// Start time in milliseconds.
  final int startTimeMs;

  /// Duration in milliseconds.
  final int durationMs;

  /// The raw UTF-8 encoded text payload.
  final List<int> data;

  const SubtitleFrame({
    required this.startTimeMs,
    required this.durationMs,
    required this.data,
  });
}

class SrtParser {
  static Future<List<SubtitleFrame>> parse(SubtitleTrack track) async {
    String text;
    if (track.file != null) {
      if (!await track.file!.exists()) return [];
      text = await track.file!.readAsString();
    } else if (track.url != null) {
      final request = await HttpClient().getUrl(Uri.parse(track.url!));
      if (track.headers != null) {
        track.headers!.forEach((key, value) {
          request.headers.add(key, value);
        });
      }
      final response = await request.close();
      if (response.statusCode != 200) {
        print(
          'Failed to download subtitle from \${track.url}: HTTP \${response.statusCode}',
        );
        return [];
      }
      text = await response.transform(utf8.decoder).join();

      // If it's an HLS playlist, fetch and concatenate all segments
      if (text.trim().startsWith('#EXTM3U')) {
        final lines = text.split(RegExp(r'\n'));
        final buffer = StringBuffer();
        for (final line in lines) {
          final l = line.trim();
          if (l.isNotEmpty && !l.startsWith('#')) {
            // It's a URL
            final segUri = Uri.parse(track.url!).resolve(l);
            final segReq = await HttpClient().getUrl(segUri);
            if (track.headers != null) {
              track.headers!.forEach((key, value) {
                segReq.headers.add(key, value);
              });
            }
            final segRes = await segReq.close();
            if (segRes.statusCode == 200) {
              buffer.write(await segRes.transform(utf8.decoder).join());
              buffer.write('\n\n');
            }
          }
        }
        text = buffer.toString();
      }
    } else {
      return [];
    }

    final frames = <SubtitleFrame>[];

    // SRT/VTT blocks are separated by blank lines.
    // Handles \r\n and \n
    final blocks = text.trim().split(RegExp(r'\n\s*\n'));

    for (final block in blocks) {
      final lines = block
          .split(RegExp(r'\n'))
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      if (lines.length < 2) continue;

      int timeLineIndex = -1;
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].contains('-->')) {
          timeLineIndex = i;
          break;
        }
      }

      if (timeLineIndex == -1) continue;

      final timeParts = lines[timeLineIndex].split('-->');
      if (timeParts.length != 2) continue;

      final startMs = _parseTimecode(timeParts[0].trim());
      final endMs = _parseTimecode(timeParts[1].trim());
      if (startMs == null || endMs == null || endMs < startMs) continue;

      // Lines after timeLine: The text
      if (timeLineIndex + 1 >= lines.length) continue;
      final textLines = lines.sublist(timeLineIndex + 1).join('\n');

      frames.add(
        SubtitleFrame(
          startTimeMs: startMs,
          durationMs: endMs - startMs,
          data: utf8.encode(textLines),
        ),
      );
    }

    return frames;
  }

  static int? _parseTimecode(String timeStr) {
    // Format: HH:MM:SS,MMM or HH:MM:SS.MMM or MM:SS.MMM
    final match = RegExp(
      r'^(?:(\d{2,}):)?(\d{2}):(\d{2})[,.](\d{3})$',
    ).firstMatch(timeStr);
    if (match == null) return null;

    final hours = match.group(1) != null ? int.parse(match.group(1)!) : 0;
    final minutes = int.parse(match.group(2)!);
    final seconds = int.parse(match.group(3)!);
    final millis = int.parse(match.group(4)!);

    return (hours * 3600000) + (minutes * 60000) + (seconds * 1000) + millis;
  }
}
