import 'dart:typed_data';

/// Demuxes MPEG-TS streams into elementary stream frames with timestamps.
///
/// Supports:
/// - H.264/AVC (stream type 0x1B)
/// - AAC with ADTS framing (stream type 0x0F)
///
/// Parses PAT → PMT → PES packets to extract frames.
class TsDemuxer {
  static const _tsPacketSize = 188;
  static const _syncByte = 0x47;

  /// Demuxes raw TS data and returns an ordered list of elementary stream frames.
  static DemuxResult demux(Uint8List data) {
    final result = DemuxResult();
    final patParser = _PatParser();
    final pmtParser = _PmtParser();
    final pesAssemblers = <int, _PesAssembler>{};

    int offset = 0;

    // Find first sync byte
    while (offset < data.length && data[offset] != _syncByte) {
      offset++;
    }

    while (offset + _tsPacketSize <= data.length) {
      if (data[offset] != _syncByte) {
        offset++;
        continue;
      }

      final packet = Uint8List.sublistView(
        data,
        offset,
        offset + _tsPacketSize,
      );
      offset += _tsPacketSize;

      final pid = ((packet[1] & 0x1F) << 8) | packet[2];
      final payloadStart = (packet[1] & 0x40) != 0;
      final hasAdaptation = (packet[3] & 0x20) != 0;
      final hasPayload = (packet[3] & 0x10) != 0;

      if (!hasPayload) continue;

      int payloadOffset = 4;
      if (hasAdaptation) {
        final adaptLen = packet[4];
        payloadOffset = 5 + adaptLen;
      }
      if (payloadOffset >= _tsPacketSize) continue;

      final payload = Uint8List.sublistView(packet, payloadOffset);

      // PAT (PID 0)
      if (pid == 0) {
        if (payloadStart && payload.isNotEmpty) {
          final pointerField = payload[0];
          patParser.parse(Uint8List.sublistView(payload, 1 + pointerField));
        }
        continue;
      }

      // PMT
      if (patParser.pmtPids.contains(pid)) {
        if (payloadStart && payload.isNotEmpty) {
          final pointerField = payload[0];
          pmtParser.parse(Uint8List.sublistView(payload, 1 + pointerField));
        }
        continue;
      }

      // Elementary stream
      final streamType = pmtParser.streams[pid];
      if (streamType == null) continue;

      final assembler = pesAssemblers.putIfAbsent(
        pid,
        () => _PesAssembler(pid, streamType),
      );

      if (payloadStart) {
        // Flush previous PES packet
        if (assembler.hasData) {
          _flushPes(assembler, result);
        }
        assembler.start(payload);
      } else {
        assembler.append(payload);
      }
    }

    // Flush remaining data
    for (final assembler in pesAssemblers.values) {
      if (assembler.hasData) {
        _flushPes(assembler, result);
      }
    }

    return result;
  }

  static void _flushPes(_PesAssembler assembler, DemuxResult result) {
    final pesData = assembler.build();
    if (pesData.length < 9) return;

    // Parse PES header
    if (pesData[0] != 0 || pesData[1] != 0 || pesData[2] != 1) return;

    final streamId = pesData[3];
    // Skip non-media streams (padding, navigation, etc.)
    if (streamId < 0xC0 && streamId != 0xBD) return;

    final headerDataLen = pesData[8];
    final dataStart = 9 + headerDataLen;
    if (dataStart > pesData.length) return;

    // Extract PTS
    final ptsDtsFlags = (pesData[7] >> 6) & 0x03;
    int? pts;
    if (ptsDtsFlags >= 2 && pesData.length >= 14) {
      pts = _parsePts(pesData, 9);
    }

    final esData = Uint8List.sublistView(pesData, dataStart);
    if (esData.isEmpty) return;

    if (assembler.streamType == 0x1B) {
      // H.264
      _parseH264Nalus(esData, pts, result);
    } else if (assembler.streamType == 0x0F) {
      // AAC ADTS
      _parseAacFrames(esData, pts, result);
    }
  }

  static int _parsePts(Uint8List data, int offset) {
    final b0 = data[offset];
    final b1 = data[offset + 1];
    final b2 = data[offset + 2];
    final b3 = data[offset + 3];
    final b4 = data[offset + 4];

    return ((b0 & 0x0E) << 29) |
        (b1 << 22) |
        ((b2 & 0xFE) << 14) |
        (b3 << 7) |
        ((b4 >> 1) & 0x7F);
  }

  // ---------------------------------------------------------------------------
  // H.264 NAL unit parsing
  // ---------------------------------------------------------------------------

  static void _parseH264Nalus(Uint8List data, int? pts, DemuxResult result) {
    final nalus = _findNalUnits(data);
    bool isKeyframe = false;
    final frameData = <Uint8List>[];

    for (final nalu in nalus) {
      if (nalu.isEmpty) continue;
      final naluType = nalu[0] & 0x1F;

      switch (naluType) {
        case 7: // SPS
          result.sps ??= Uint8List.fromList(nalu);
        case 8: // PPS
          result.pps ??= Uint8List.fromList(nalu);
        case 5: // IDR slice
          isKeyframe = true;
          frameData.add(nalu);
        case 1: // Non-IDR slice
        case 6: // SEI
          frameData.add(nalu);
      }
    }

    if (frameData.isNotEmpty) {
      // Convert to length-prefixed format (4-byte length prefix per NALU)
      final lengthPrefixed = _toLengthPrefixed(frameData);
      result.videoFrames.add(
        EsFrame(data: lengthPrefixed, pts: pts, isKeyframe: isKeyframe),
      );
    }
  }

  /// Finds NAL units using Annex B start codes (0x000001 or 0x00000001).
  static List<Uint8List> _findNalUnits(Uint8List data) {
    final units = <Uint8List>[];
    int i = 0;

    while (i < data.length - 2) {
      // Look for start code: 0x000001 or 0x00000001
      int startCodeLen = 0;
      if (i + 2 < data.length &&
          data[i] == 0 &&
          data[i + 1] == 0 &&
          data[i + 2] == 1) {
        startCodeLen = 3;
      } else if (i + 3 < data.length &&
          data[i] == 0 &&
          data[i + 1] == 0 &&
          data[i + 2] == 0 &&
          data[i + 3] == 1) {
        startCodeLen = 4;
      }

      if (startCodeLen > 0) {
        final naluStart = i + startCodeLen;
        // Find next start code
        int naluEnd = data.length;
        for (int j = naluStart + 1; j < data.length - 2; j++) {
          if (data[j] == 0 && data[j + 1] == 0) {
            if (data[j + 2] == 1 ||
                (j + 3 < data.length && data[j + 2] == 0 && data[j + 3] == 1)) {
              naluEnd = j;
              break;
            }
          }
        }

        if (naluStart < naluEnd) {
          units.add(Uint8List.sublistView(data, naluStart, naluEnd));
        }
        i = naluEnd;
      } else {
        i++;
      }
    }

    return units;
  }

  /// Converts NAL units from Annex B (start codes) to length-prefixed format.
  static Uint8List _toLengthPrefixed(List<Uint8List> nalus) {
    int totalLen = 0;
    for (final nalu in nalus) {
      totalLen += 4 + nalu.length;
    }

    final result = Uint8List(totalLen);
    int offset = 0;
    for (final nalu in nalus) {
      // 4-byte big-endian length prefix
      result[offset] = (nalu.length >> 24) & 0xFF;
      result[offset + 1] = (nalu.length >> 16) & 0xFF;
      result[offset + 2] = (nalu.length >> 8) & 0xFF;
      result[offset + 3] = nalu.length & 0xFF;
      offset += 4;
      result.setRange(offset, offset + nalu.length, nalu);
      offset += nalu.length;
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // AAC ADTS parsing
  // ---------------------------------------------------------------------------

  static void _parseAacFrames(Uint8List data, int? pts, DemuxResult result) {
    int offset = 0;
    bool first = true;

    while (offset + 7 <= data.length) {
      // ADTS sync word: 0xFFF
      if ((data[offset] != 0xFF) || ((data[offset + 1] & 0xF0) != 0xF0)) {
        offset++;
        continue;
      }

      final protectionAbsent = (data[offset + 1] & 0x01) == 1;
      final headerLen = protectionAbsent ? 7 : 9;

      // Frame length (13 bits across bytes 3-5)
      final frameLen =
          ((data[offset + 3] & 0x03) << 11) |
          (data[offset + 4] << 3) |
          ((data[offset + 5] >> 5) & 0x07);

      if (frameLen < headerLen || offset + frameLen > data.length) break;

      // Extract codec config from first frame
      if (result.aacConfig == null) {
        final profile = ((data[offset + 2] >> 6) & 0x03) + 1; // audioObjectType
        final freqIndex = (data[offset + 2] >> 2) & 0x0F;
        final channelConfig =
            ((data[offset + 2] & 0x01) << 2) | ((data[offset + 3] >> 6) & 0x03);

        result.aacConfig = AacConfig(
          audioObjectType: profile,
          samplingFrequencyIndex: freqIndex,
          channelConfiguration: channelConfig,
        );
      }

      // Raw AAC frame (strip ADTS header)
      final rawFrame = Uint8List.sublistView(
        data,
        offset + headerLen,
        offset + frameLen,
      );

      result.audioFrames.add(
        EsFrame(data: rawFrame, pts: first ? pts : null, isKeyframe: false),
      );

      first = false;
      offset += frameLen;
    }
  }
}

// =============================================================================
// Data structures
// =============================================================================

/// Result of demuxing a TS stream.
class DemuxResult {
  /// H.264 video frames (length-prefixed NALUs).
  final List<EsFrame> videoFrames = [];

  /// AAC audio frames (raw, no ADTS header).
  final List<EsFrame> audioFrames = [];

  /// H.264 Sequence Parameter Set.
  Uint8List? sps;

  /// H.264 Picture Parameter Set.
  Uint8List? pps;

  /// AAC configuration extracted from the ADTS header.
  AacConfig? aacConfig;

  /// Extracts video resolution from SPS (simplified — reads from byte offsets).
  (int width, int height)? get videoResolution {
    final sps = this.sps;
    if (sps == null || sps.length < 5) return null;
    // Full SPS parsing is complex (exp-Golomb coding).
    // Return null and let the caller provide dimensions if needed.
    return null;
  }
}

/// A single elementary stream frame.
class EsFrame {
  /// Frame payload (video: length-prefixed NALUs; audio: raw AAC).
  final Uint8List data;

  /// Presentation timestamp in 90kHz clock ticks, if available.
  final int? pts;

  /// Whether this is a keyframe (IDR for H.264).
  final bool isKeyframe;

  const EsFrame({required this.data, this.pts, required this.isKeyframe});

  /// PTS converted to milliseconds.
  int? get ptsMs => pts != null ? (pts! ~/ 90) : null;
}

/// AAC audio configuration from ADTS header.
class AacConfig {
  final int audioObjectType;
  final int samplingFrequencyIndex;
  final int channelConfiguration;

  const AacConfig({
    required this.audioObjectType,
    required this.samplingFrequencyIndex,
    required this.channelConfiguration,
  });

  static const _sampleRates = [
    96000,
    88200,
    64000,
    48000,
    44100,
    32000,
    24000,
    22050,
    16000,
    12000,
    11025,
    8000,
    7350,
  ];

  /// Sampling rate in Hz.
  int get sampleRate => samplingFrequencyIndex < _sampleRates.length
      ? _sampleRates[samplingFrequencyIndex]
      : 44100;

  /// Encodes AudioSpecificConfig (2 bytes for AAC-LC).
  Uint8List get audioSpecificConfig {
    final byte0 =
        ((audioObjectType & 0x1F) << 3) |
        ((samplingFrequencyIndex >> 1) & 0x07);
    final byte1 =
        ((samplingFrequencyIndex & 0x01) << 7) |
        ((channelConfiguration & 0x0F) << 3);
    return Uint8List.fromList([byte0, byte1]);
  }
}

// =============================================================================
// Internal helpers
// =============================================================================

class _PatParser {
  final Set<int> pmtPids = {};

  void parse(Uint8List data) {
    if (data.isEmpty || data[0] != 0x00) return; // table_id must be 0

    final sectionLength = ((data[1] & 0x0F) << 8) | data[2];
    final endOfSection = 3 + sectionLength - 4; // exclude CRC

    int i = 8; // skip to program entries
    while (i + 3 < endOfSection && i + 3 < data.length) {
      final programNum = (data[i] << 8) | data[i + 1];
      final pid = ((data[i + 2] & 0x1F) << 8) | data[i + 3];
      if (programNum != 0) {
        pmtPids.add(pid);
      }
      i += 4;
    }
  }
}

class _PmtParser {
  /// Maps elementary stream PID to stream type.
  final Map<int, int> streams = {};

  void parse(Uint8List data) {
    if (data.isEmpty || data[0] != 0x02) return; // table_id must be 2

    final sectionLength = ((data[1] & 0x0F) << 8) | data[2];
    final endOfSection = 3 + sectionLength - 4; // exclude CRC

    if (data.length < 12) return;

    final programInfoLength = ((data[10] & 0x0F) << 8) | data[11];
    int i = 12 + programInfoLength;

    while (i + 4 < endOfSection && i + 4 < data.length) {
      final streamType = data[i];
      final esPid = ((data[i + 1] & 0x1F) << 8) | data[i + 2];
      final esInfoLength = ((data[i + 3] & 0x0F) << 8) | data[i + 4];

      // Only track supported stream types
      if (streamType == 0x1B || streamType == 0x0F) {
        streams[esPid] = streamType;
      }

      i += 5 + esInfoLength;
    }
  }
}

class _PesAssembler {
  final int pid;
  final int streamType;
  final _chunks = <Uint8List>[];

  _PesAssembler(this.pid, this.streamType);

  bool get hasData => _chunks.isNotEmpty;

  void start(Uint8List data) {
    _chunks.clear();
    _chunks.add(Uint8List.fromList(data));
  }

  void append(Uint8List data) {
    _chunks.add(Uint8List.fromList(data));
  }

  Uint8List build() {
    int totalLen = 0;
    for (final chunk in _chunks) {
      totalLen += chunk.length;
    }
    final result = Uint8List(totalLen);
    int offset = 0;
    for (final chunk in _chunks) {
      result.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    _chunks.clear();
    return result;
  }
}
