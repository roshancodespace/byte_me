import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'package:http/http.dart' as http;

class HlsSegment {
  final String url;
  final Uint8List? key;
  final Uint8List? iv;
  final int seq;
  final int fileIndex;

  HlsSegment(this.url, this.key, this.iv, this.seq, this.fileIndex);
}

class M3u8Parser {
  static Future<List<HlsSegment>> parse(
      String url, Map<String, String> headers, http.Client client) async {
    final bytes = await _fetch(url, headers, client);
    if (bytes == null) throw Exception('Failed to load m3u8');

    final lines = LineSplitter.split(utf8.decode(bytes)).toList();
    final baseUri = Uri.parse(url);
    final segments = <HlsSegment>[];

    // Handle Master Playlists (Redirect to the highest quality variant)
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

    Uint8List? key, iv;
    int mediaSeq = 0;
    int fileIndex = 0;
    int segmentCount = 0;

    for (final line in lines) {
      final trim = line.trim();
      if (trim.isEmpty) continue;

      if (trim.startsWith('#EXT-X-MEDIA-SEQUENCE:')) {
        mediaSeq = int.tryParse(trim.split(':').last) ?? 0;
      } else if (trim.startsWith('#EXT-X-MAP')) {
        final mapUri = RegExp(r'URI="([^"]+)"').firstMatch(trim)?.group(1);
        if (mapUri != null) {
          segments
              .add(HlsSegment(_resolveUrl(baseUri, mapUri), key, iv, -1, -1));
        }
      } else if (trim.startsWith('#EXT-X-KEY')) {
        final keyUri = RegExp(r'URI="([^"]+)"').firstMatch(trim)?.group(1);
        final ivHex = RegExp(
          r'IV=(?:0x)?([0-9A-Fa-f]+)',
          caseSensitive: false,
        ).firstMatch(trim)?.group(1);

        if (keyUri != null) {
          key = await _fetch(_resolveUrl(baseUri, keyUri), headers, client);
          if (key == null) throw Exception("Failed to fetch decryption key");
        }
        if (ivHex != null) iv = _hexToBytes(ivHex);
      } else if (!trim.startsWith('#')) {
        segments.add(
          HlsSegment(
            _resolveUrl(baseUri, trim),
            key,
            iv,
            mediaSeq + segmentCount,
            fileIndex,
          ),
        );
        segmentCount++;
        fileIndex++;
      }
    }
    return segments;
  }

  static Uint8List decrypt(
      Uint8List bytes, Uint8List key, Uint8List? iv, int seq) {
    final effectiveIV = iv ?? _seqToIV(seq);
    try {
      final encrypter = Encrypter(
        AES(Key(key), mode: AESMode.cbc, padding: 'PKCS7'),
      );
      return Uint8List.fromList(
        encrypter.decryptBytes(Encrypted(bytes), iv: IV(effectiveIV)),
      );
    } catch (e) {
      final fallbackEncrypter = Encrypter(
        AES(Key(key), mode: AESMode.cbc, padding: null),
      );
      return Uint8List.fromList(
        fallbackEncrypter.decryptBytes(Encrypted(bytes), iv: IV(effectiveIV)),
      );
    }
  }

  static String _resolveUrl(Uri baseUri, String url) {
    final parsed = Uri.parse(url);
    if (parsed.hasScheme) return url;

    final resolved = baseUri.resolve(url);
    if (baseUri.hasQuery && !parsed.hasQuery) {
      return resolved.replace(query: baseUri.query).toString();
    }
    return resolved.toString();
  }

  static Future<Uint8List?> _fetch(
    String url,
    Map<String, String> headers,
    http.Client client,
  ) async {
    for (int i = 0; i < 3; i++) {
      try {
        final res = await client.get(Uri.parse(url), headers: headers);
        if (res.statusCode == 200) return res.bodyBytes;
      } catch (_) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }
    return null;
  }

  static Uint8List _seqToIV(int seq) {
    final iv = Uint8List(16);
    int s = seq < 0 ? 0 : seq;
    for (int i = 15; i >= 0; i--) {
      iv[i] = (s >> (8 * (15 - i))) & 0xFF;
    }
    return iv;
  }

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
