import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// A parsed HLS segment with optional encryption info.
class HlsSegment {
  /// Absolute URL of the segment.
  final String url;

  /// AES-128 key bytes, if encrypted.
  final Uint8List? key;

  /// Explicit initialization vector, if provided.
  final Uint8List? iv;

  /// Media sequence number (used to derive IV when none is explicit).
  final int seq;

  const HlsSegment(this.url, this.key, this.iv, this.seq);
}

/// Parses M3U8 playlists into a list of [HlsSegment]s.
///
/// Handles master playlists (follows the first variant), media playlists,
/// `#EXT-X-KEY` (AES-128), `#EXT-X-MAP`, and `#EXT-X-MEDIA-SEQUENCE`.
class M3u8Parser {
  /// Parses an M3U8 from [url] and returns the segment list.
  ///
  /// For master playlists, recursively follows the first variant.
  static Future<List<HlsSegment>> parse(
    String url,
    Map<String, String> headers,
    HttpClient client,
  ) async {
    final content = await _fetchText(url, headers, client);
    if (content == null) throw Exception('Failed to load m3u8: $url');
    return parseContent(content, Uri.parse(url), headers, client);
  }

  /// Parses M3U8 content directly (useful for testing).
  static Future<List<HlsSegment>> parseContent(
    String content,
    Uri baseUri,
    Map<String, String> headers,
    HttpClient client,
  ) async {
    final lines = LineSplitter.split(content).toList();
    final segments = <HlsSegment>[];

    // Master playlist detection → recurse into first variant
    if (lines.any((l) => l.contains('#EXT-X-STREAM-INF'))) {
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].startsWith('#EXT-X-STREAM-INF') && i + 1 < lines.length) {
          final next = lines[i + 1].trim();
          if (next.isNotEmpty && !next.startsWith('#')) {
            return parse(_resolveUrl(baseUri, next), headers, client);
          }
        }
      }
    }

    Uint8List? key;
    Uint8List? iv;
    int mediaSeq = 0;
    int segmentCount = 0;

    for (final line in lines) {
      final trim = line.trim();
      if (trim.isEmpty) continue;

      if (trim.startsWith('#EXT-X-MEDIA-SEQUENCE:')) {
        mediaSeq = int.tryParse(trim.split(':').last) ?? 0;
      } else if (trim.startsWith('#EXT-X-MAP')) {
        final mapUri = RegExp(r'URI="([^"]+)"').firstMatch(trim)?.group(1);
        if (mapUri != null) {
          segments.add(HlsSegment(_resolveUrl(baseUri, mapUri), key, iv, -1));
        }
      } else if (trim.startsWith('#EXT-X-KEY')) {
        final method =
            RegExp(r'METHOD=([^,]+)').firstMatch(trim)?.group(1) ?? '';

        if (method == 'NONE') {
          key = null;
          iv = null;
        } else if (method == 'AES-128') {
          final keyUri = RegExp(r'URI="([^"]+)"').firstMatch(trim)?.group(1);
          final ivHex = RegExp(
            r'IV=(?:0x)?([0-9A-Fa-f]+)',
            caseSensitive: false,
          ).firstMatch(trim)?.group(1);

          if (keyUri != null) {
            key = await _fetchBytes(
              _resolveUrl(baseUri, keyUri),
              headers,
              client,
            );
            if (key == null) {
              throw Exception('Failed to fetch decryption key');
            }
          }
          iv = ivHex != null ? _hexToBytes(ivHex) : null;
        }
      } else if (!trim.startsWith('#')) {
        segments.add(
          HlsSegment(
            _resolveUrl(baseUri, trim),
            key,
            iv,
            mediaSeq + segmentCount,
          ),
        );
        segmentCount++;
      }
    }

    return segments;
  }

  // ---------------------------------------------------------------------------
  // URL resolution
  // ---------------------------------------------------------------------------

  static String _resolveUrl(Uri baseUri, String url) {
    final parsed = Uri.parse(url);
    if (parsed.hasScheme) return url;
    final resolved = baseUri.resolve(url);
    // Preserve query parameters from the base URL (auth tokens, etc.)
    if (baseUri.hasQuery && !parsed.hasQuery) {
      return resolved.replace(query: baseUri.query).toString();
    }
    return resolved.toString();
  }

  // ---------------------------------------------------------------------------
  // HTTP helpers (simple, with basic retry)
  // ---------------------------------------------------------------------------

  static Future<String?> _fetchText(
    String url,
    Map<String, String> headers,
    HttpClient client,
  ) async {
    final bytes = await _fetchBytes(url, headers, client);
    return bytes != null ? utf8.decode(bytes) : null;
  }

  static Future<Uint8List?> _fetchBytes(
    String url,
    Map<String, String> headers,
    HttpClient client,
  ) async {
    for (int i = 0; i < 3; i++) {
      try {
        final request = await client.getUrl(Uri.parse(url));
        headers.forEach((k, v) => request.headers.set(k, v));
        final response = await request.close();
        if (response.statusCode == 200) {
          final chunks = <List<int>>[];
          await for (final chunk in response) {
            chunks.add(chunk);
          }
          final totalLength = chunks.fold<int>(0, (s, c) => s + c.length);
          final result = Uint8List(totalLength);
          int offset = 0;
          for (final chunk in chunks) {
            result.setRange(offset, offset + chunk.length, chunk);
            offset += chunk.length;
          }
          return result;
        }
        await response.drain<void>();
      } catch (_) {
        if (i < 2) await Future.delayed(const Duration(seconds: 1));
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Byte utilities
  // ---------------------------------------------------------------------------

  static Uint8List _hexToBytes(String hex) {
    hex = hex.padLeft(32, '0');
    return Uint8List.fromList(
      List.generate(
        16,
        (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16),
      ),
    );
  }
}
