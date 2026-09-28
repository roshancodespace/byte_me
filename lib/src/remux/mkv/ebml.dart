import 'dart:typed_data';

/// EBML (Extensible Binary Meta Language) encoding utilities for Matroska/MKV.
class Ebml {
  // ---------------------------------------------------------------------------
  // Matroska Element IDs
  // ---------------------------------------------------------------------------
  static const ebmlHeader = 0x1A45DFA3;
  static const ebmlVersion = 0x4286;
  static const ebmlReadVersion = 0x42F7;
  static const ebmlMaxIdLength = 0x42F2;
  static const ebmlMaxSizeLength = 0x42F3;
  static const docType = 0x4282;
  static const docTypeVersion = 0x4287;
  static const docTypeReadVersion = 0x4285;

  static const segment = 0x18538067;
  static const segmentInfo = 0x1549A966;
  static const timecodeScale = 0x2AD7B1;
  static const muxingApp = 0x4D80;
  static const writingApp = 0x5741;
  static const segmentDuration = 0x4489;

  static const tracks = 0x1654AE6B;
  static const trackEntry = 0xAE;
  static const trackNumber = 0xD7;
  static const trackUid = 0x73C5;
  static const trackType = 0x83;
  static const flagLacing = 0x9C;
  static const codecId = 0x86;
  static const codecPrivate = 0x63A2;
  static const defaultDuration = 0x23E383;

  static const video = 0xE0;
  static const pixelWidth = 0xB0;
  static const pixelHeight = 0xBA;

  static const audio = 0xE1;
  static const samplingFrequency = 0xB5;
  static const channels = 0x9F;
  static const bitDepth = 0x6264;

  static const cluster = 0x1F43B675;
  static const clusterTimecode = 0xE7;
  static const simpleBlock = 0xA3;
  static const blockGroup = 0xA0;
  static const block = 0xA1;
  static const blockDuration = 0x9B;

  // Track elements
  static const language = 0x22B59C;
  static const name = 0x536E;

  // Track types
  static const trackTypeVideo = 1;
  static const trackTypeAudio = 2;
  static const trackTypeSubtitle = 17;

  // ---------------------------------------------------------------------------
  // EBML variable-length integer encoding
  // ---------------------------------------------------------------------------

  /// Encodes an element ID as raw bytes.
  static Uint8List encodeId(int id) {
    if (id <= 0xFF) return Uint8List.fromList([id]);
    if (id <= 0xFFFF) return _uint16BE(id);
    if (id <= 0xFFFFFF) return _uint24BE(id);
    return _uint32BE(id);
  }

  /// Encodes a data size as an EBML VINT.
  static Uint8List encodeSize(int size) {
    if (size < 0x7F) {
      return Uint8List.fromList([size | 0x80]);
    } else if (size < 0x3FFF) {
      return Uint8List.fromList([((size >> 8) & 0x3F) | 0x40, size & 0xFF]);
    } else if (size < 0x1FFFFF) {
      return Uint8List.fromList([
        ((size >> 16) & 0x1F) | 0x20,
        (size >> 8) & 0xFF,
        size & 0xFF,
      ]);
    } else if (size < 0x0FFFFFFF) {
      return Uint8List.fromList([
        ((size >> 24) & 0x0F) | 0x10,
        (size >> 16) & 0xFF,
        (size >> 8) & 0xFF,
        size & 0xFF,
      ]);
    } else {
      // 8-byte VINT for large sizes
      return Uint8List.fromList([
        0x01,
        0x00,
        0x00,
        0x00,
        (size >> 24) & 0xFF,
        (size >> 16) & 0xFF,
        (size >> 8) & 0xFF,
        size & 0xFF,
      ]);
    }
  }

  /// Returns an "unknown size" VINT marker (all data bits set).
  static Uint8List unknownSize() {
    return Uint8List.fromList([0x01, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]);
  }

  // ---------------------------------------------------------------------------
  // Element builders
  // ---------------------------------------------------------------------------

  /// Builds a complete element: ID + Size + Data.
  static Uint8List element(int id, Uint8List data) {
    final idBytes = encodeId(id);
    final sizeBytes = encodeSize(data.length);
    final result = Uint8List(idBytes.length + sizeBytes.length + data.length);
    int offset = 0;
    result.setRange(offset, offset + idBytes.length, idBytes);
    offset += idBytes.length;
    result.setRange(offset, offset + sizeBytes.length, sizeBytes);
    offset += sizeBytes.length;
    result.setRange(offset, offset + data.length, data);
    return result;
  }

  /// Builds a container element header (ID + Size), without the child data.
  static Uint8List containerHeader(int id, int contentSize) {
    final idBytes = encodeId(id);
    final sizeBytes = encodeSize(contentSize);
    final result = Uint8List(idBytes.length + sizeBytes.length);
    result.setRange(0, idBytes.length, idBytes);
    result.setRange(idBytes.length, result.length, sizeBytes);
    return result;
  }

  /// Builds a container element header with unknown size (for streaming).
  static Uint8List containerHeaderUnknown(int id) {
    final idBytes = encodeId(id);
    final sizeBytes = unknownSize();
    final result = Uint8List(idBytes.length + sizeBytes.length);
    result.setRange(0, idBytes.length, idBytes);
    result.setRange(idBytes.length, result.length, sizeBytes);
    return result;
  }

  /// Encodes an unsigned integer element.
  static Uint8List uintElement(int id, int value) {
    return element(id, _encodeUint(value));
  }

  /// Encodes a UTF-8 string element.
  static Uint8List stringElement(int id, String value) {
    return element(id, Uint8List.fromList(value.codeUnits));
  }

  /// Encodes a 64-bit IEEE 754 float element.
  static Uint8List floatElement(int id, double value) {
    final data = ByteData(8)..setFloat64(0, value, Endian.big);
    return element(id, Uint8List.view(data.buffer));
  }

  // ---------------------------------------------------------------------------
  // Numeric encoding helpers
  // ---------------------------------------------------------------------------

  static Uint8List _encodeUint(int value) {
    if (value <= 0xFF) return Uint8List.fromList([value]);
    if (value <= 0xFFFF) return _uint16BE(value);
    if (value <= 0xFFFFFF) return _uint24BE(value);
    if (value <= 0xFFFFFFFF) return _uint32BE(value);
    // 8-byte for large values
    final data = ByteData(8)..setInt64(0, value, Endian.big);
    return Uint8List.view(data.buffer);
  }

  static Uint8List _uint16BE(int v) =>
      Uint8List.fromList([(v >> 8) & 0xFF, v & 0xFF]);

  static Uint8List _uint24BE(int v) =>
      Uint8List.fromList([(v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF]);

  static Uint8List _uint32BE(int v) => Uint8List.fromList([
    (v >> 24) & 0xFF,
    (v >> 16) & 0xFF,
    (v >> 8) & 0xFF,
    v & 0xFF,
  ]);

  /// Encodes a track number as a VINT for SimpleBlock headers.
  static Uint8List encodeTrackNumber(int track) {
    if (track <= 0x7E) return Uint8List.fromList([track | 0x80]);
    if (track <= 0x3FFE) {
      return Uint8List.fromList([((track >> 8) & 0x3F) | 0x40, track & 0xFF]);
    }
    throw ArgumentError('Track number too large: $track');
  }
}
