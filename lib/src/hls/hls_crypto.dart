import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';

/// AES-128-CBC decryption for HLS segments.
class HlsCrypto {
  /// Decrypts [data] using AES-128-CBC with [key] and [iv].
  ///
  /// If [iv] is null, derives it from the [mediaSequence] as per the HLS spec
  /// (big-endian 128-bit representation of the sequence number).
  static Uint8List decrypt(
    Uint8List data,
    Uint8List key,
    Uint8List? iv,
    int mediaSequence,
  ) {
    final effectiveIV = iv ?? sequenceToIV(mediaSequence);
    try {
      // Try with PKCS7 padding first (standard)
      final encrypter = Encrypter(
        AES(Key(key), mode: AESMode.cbc, padding: 'PKCS7'),
      );
      return Uint8List.fromList(
        encrypter.decryptBytes(Encrypted(data), iv: IV(effectiveIV)),
      );
    } catch (_) {
      // Fallback: some streams use no padding
      final encrypter = Encrypter(
        AES(Key(key), mode: AESMode.cbc, padding: null),
      );
      return Uint8List.fromList(
        encrypter.decryptBytes(Encrypted(data), iv: IV(effectiveIV)),
      );
    }
  }

  /// Converts a media sequence number to a 128-bit IV (big-endian).
  ///
  /// Per the HLS spec, when no IV is explicitly provided, the IV is the
  /// big-endian representation of the media sequence number as a 128-bit
  /// unsigned integer.
  static Uint8List sequenceToIV(int seq) {
    final iv = Uint8List(16);
    int s = seq < 0 ? 0 : seq;
    for (int i = 15; i >= 0; i--) {
      iv[i] = s & 0xFF;
      s >>= 8;
    }
    return iv;
  }
}
