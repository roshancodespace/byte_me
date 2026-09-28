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

  const SubtitleTrack({this.file, this.url, this.language, this.title})
    : assert(file != null || url != null, 'Must provide either file or url');
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
      final response = await request.close();
      if (response.statusCode != 200) return [];
      text = await response.transform(utf8.decoder).join();
    } else {
      return [];
    }
    final frames = <SubtitleFrame>[];

    // SRT blocks are separated by blank lines.
    // Handles \r\n and \n
    final blocks = text.trim().split(RegExp(r'\n\s*\n'));

    for (final block in blocks) {
      final lines = block
          .split(RegExp(r'\n'))
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      if (lines.length < 3) continue;

      // Line 0: sequence number (ignore)
      // Line 1: 00:00:20,000 --> 00:00:24,400
      final timeStr = lines[1];
      final timeParts = timeStr.split('-->');
      if (timeParts.length != 2) continue;

      final startMs = _parseTimecode(timeParts[0].trim());
      final endMs = _parseTimecode(timeParts[1].trim());
      if (startMs == null || endMs == null || endMs < startMs) continue;

      // Lines 2+: The text
      final textLines = lines.sublist(2).join('\n');

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
    // Format: HH:MM:SS,MMM or HH:MM:SS.MMM
    final match = RegExp(
      r'^(\d{2,}):(\d{2}):(\d{2})[,.](\d{3})$',
    ).firstMatch(timeStr);
    if (match == null) return null;

    final hours = int.parse(match.group(1)!);
    final minutes = int.parse(match.group(2)!);
    final seconds = int.parse(match.group(3)!);
    final millis = int.parse(match.group(4)!);

    return (hours * 3600000) + (minutes * 60000) + (seconds * 1000) + millis;
  }
}
