import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import '../remuxer.dart';
import 'ebml.dart';
import 'subtitles/subtitle_track.dart';
import 'ts_demuxer.dart';

/// Remuxes MPEG-TS segments into a Matroska (MKV) container.
///
/// Performs genuine remuxing — copies encoded streams without re-encoding.
///
/// Supports:
/// - H.264/AVC video
/// - AAC audio
///
/// Known limitations:
/// - H.265/HEVC not yet supported (use [ConcatRemuxer] as fallback)
/// - SRT subtitles (multiplexed as S_TEXT/UTF8)
/// - No seeking index (Cues element) — playback works but seeking may be slow
/// - Video resolution extracted from SPS is not implemented; some players
///   may not display resolution metadata
class MkvRemuxer implements Remuxer {
  final List<SubtitleTrack> subtitles;

  const MkvRemuxer({this.subtitles = const []});

  @override
  Future<void> remux(List<File> segments, String outputPath) async {
    // Run the CPU-intensive demux+mux work in a background isolate
    await Isolate.run(() => _remuxSync(segments, outputPath, subtitles));
  }

  static Future<void> _remuxSync(
    List<File> segments,
    String outputPath,
    List<SubtitleTrack> subtitles,
  ) async {
    // Phase 1: Demux all segments to collect frames and codec info
    final allVideoFrames = <EsFrame>[];
    final allAudioFrames = <EsFrame>[];
    Uint8List? sps;
    Uint8List? pps;
    AacConfig? aacConfig;

    for (final segment in segments) {
      if (!segment.existsSync()) continue;
      final data = await segment.readAsBytes();
      final result = TsDemuxer.demux(data);

      allVideoFrames.addAll(result.videoFrames);
      allAudioFrames.addAll(result.audioFrames);
      sps ??= result.sps;
      pps ??= result.pps;
      aacConfig ??= result.aacConfig;
    }

    if (allVideoFrames.isEmpty && allAudioFrames.isEmpty) {
      throw StateError('No media frames found in segments');
    }

    final parsedSubtitles = <int, List<SubtitleFrame>>{};
    int nextTrackNum = (sps != null ? 1 : 0) + (aacConfig != null ? 1 : 0) + 1;
    final subtitleConfigs = <int, SubtitleTrack>{};

    for (final track in subtitles) {
      final frames = await SrtParser.parse(track);
      if (frames.isNotEmpty) {
        parsedSubtitles[nextTrackNum] = frames;
        subtitleConfigs[nextTrackNum] = track;
        nextTrackNum++;
      }
    }

    // Phase 2: Write MKV
    final output = File(outputPath);
    final sink = output.openWrite();

    try {
      // EBML Header
      sink.add(_buildEbmlHeader());

      // Segment (unknown size — avoids seeking back to patch)
      sink.add(Ebml.containerHeaderUnknown(Ebml.segment));

      // Segment Info
      sink.add(_buildSegmentInfo());

      // Tracks
      sink.add(_buildTracks(sps, pps, aacConfig, subtitleConfigs));

      // Clusters
      _writeClusters(sink, allVideoFrames, allAudioFrames, parsedSubtitles);

      await sink.flush();
    } finally {
      await sink.close();
    }
  }

  static Uint8List _buildEbmlHeader() {
    final content = _concat([
      Ebml.uintElement(Ebml.ebmlVersion, 1),
      Ebml.uintElement(Ebml.ebmlReadVersion, 1),
      Ebml.uintElement(Ebml.ebmlMaxIdLength, 4),
      Ebml.uintElement(Ebml.ebmlMaxSizeLength, 8),
      Ebml.stringElement(Ebml.docType, 'matroska'),
      Ebml.uintElement(Ebml.docTypeVersion, 4),
      Ebml.uintElement(Ebml.docTypeReadVersion, 2),
    ]);
    return Ebml.element(Ebml.ebmlHeader, content);
  }

  static Uint8List _buildSegmentInfo() {
    final content = _concat([
      // TimecodeScale: 1,000,000 ns = 1ms per cluster timecode tick
      Ebml.uintElement(Ebml.timecodeScale, 1000000),
      Ebml.stringElement(Ebml.muxingApp, 'byte_me'),
      Ebml.stringElement(Ebml.writingApp, 'byte_me'),
    ]);
    return Ebml.element(Ebml.segmentInfo, content);
  }

  static Uint8List _buildTracks(
    Uint8List? sps,
    Uint8List? pps,
    AacConfig? aacConfig,
    Map<int, SubtitleTrack> subtitleConfigs,
  ) {
    final trackEntries = <Uint8List>[];
    int trackNum = 0;

    // Video track
    if (sps != null && pps != null) {
      trackNum++;
      final codecPrivate = _buildAvcConfig(sps, pps);

      final videoInfo = Ebml.element(
        Ebml.video,
        _concat([
          // Resolution not available from simple SPS parsing;
          // players will infer from the bitstream.
          Ebml.uintElement(Ebml.pixelWidth, 1920), // placeholder
          Ebml.uintElement(Ebml.pixelHeight, 1080), // placeholder
        ]),
      );

      trackEntries.add(
        Ebml.element(
          Ebml.trackEntry,
          _concat([
            Ebml.uintElement(Ebml.trackNumber, trackNum),
            Ebml.uintElement(Ebml.trackUid, trackNum),
            Ebml.uintElement(Ebml.trackType, Ebml.trackTypeVideo),
            Ebml.uintElement(Ebml.flagLacing, 0),
            Ebml.stringElement(Ebml.codecId, 'V_MPEG4/ISO/AVC'),
            Ebml.element(Ebml.codecPrivate, codecPrivate),
            videoInfo,
          ]),
        ),
      );
    }

    // Audio track
    if (aacConfig != null) {
      trackNum++;
      final audioInfo = Ebml.element(
        Ebml.audio,
        _concat([
          Ebml.floatElement(
            Ebml.samplingFrequency,
            aacConfig.sampleRate.toDouble(),
          ),
          Ebml.uintElement(Ebml.channels, aacConfig.channelConfiguration),
        ]),
      );

      trackEntries.add(
        Ebml.element(
          Ebml.trackEntry,
          _concat([
            Ebml.uintElement(Ebml.trackNumber, trackNum),
            Ebml.uintElement(Ebml.trackUid, trackNum),
            Ebml.uintElement(Ebml.trackType, Ebml.trackTypeAudio),
            Ebml.uintElement(Ebml.flagLacing, 0),
            Ebml.stringElement(Ebml.codecId, 'A_AAC'),
            Ebml.element(Ebml.codecPrivate, aacConfig.audioSpecificConfig),
            audioInfo,
          ]),
        ),
      );
    }

    // Subtitle tracks
    for (final entry in subtitleConfigs.entries) {
      final tNum = entry.key;
      final config = entry.value;

      final trackElements = <Uint8List>[
        Ebml.uintElement(Ebml.trackNumber, tNum),
        Ebml.uintElement(Ebml.trackUid, tNum),
        Ebml.uintElement(Ebml.trackType, Ebml.trackTypeSubtitle),
        Ebml.uintElement(Ebml.flagLacing, 0),
        Ebml.stringElement(Ebml.codecId, 'S_TEXT/UTF8'),
      ];

      if (config.language != null) {
        trackElements.add(Ebml.stringElement(Ebml.language, config.language!));
      }
      if (config.title != null) {
        trackElements.add(Ebml.stringElement(Ebml.name, config.title!));
      }

      trackEntries.add(Ebml.element(Ebml.trackEntry, _concat(trackElements)));
    }

    return Ebml.element(Ebml.tracks, _concat(trackEntries));
  }

  /// Builds the AVCDecoderConfigurationRecord for the CodecPrivate.
  static Uint8List _buildAvcConfig(Uint8List sps, Uint8List pps) {
    final config = BytesBuilder(copy: false);
    config.addByte(1); // configurationVersion
    config.addByte(sps.length > 1 ? sps[1] : 66); // AVCProfileIndication
    config.addByte(sps.length > 2 ? sps[2] : 0); // profile_compatibility
    config.addByte(sps.length > 3 ? sps[3] : 30); // AVCLevelIndication
    config.addByte(0xFF); // lengthSizeMinusOne = 3 (4-byte prefix) | reserved
    config.addByte(0xE1); // numSPS = 1 | reserved
    config.addByte((sps.length >> 8) & 0xFF);
    config.addByte(sps.length & 0xFF);
    config.add(sps);
    config.addByte(1); // numPPS
    config.addByte((pps.length >> 8) & 0xFF);
    config.addByte(pps.length & 0xFF);
    config.add(pps);
    return config.toBytes();
  }

  /// Writes clusters with SimpleBlocks. New cluster at each keyframe.
  static void _writeClusters(
    IOSink sink,
    List<EsFrame> videoFrames,
    List<EsFrame> audioFrames,
    Map<int, List<SubtitleFrame>> parsedSubtitles,
  ) {
    // Merge and sort all frames by PTS
    final allFrames = <_TaggedFrame>[];
    for (final f in videoFrames) {
      allFrames.add(_TaggedFrame(f, 1, true, null));
    }

    final audioTrackNum = videoFrames.isNotEmpty ? 2 : 1;
    for (final f in audioFrames) {
      allFrames.add(_TaggedFrame(f, audioTrackNum, false, null));
    }

    for (final entry in parsedSubtitles.entries) {
      final trackNum = entry.key;
      for (final sf in entry.value) {
        allFrames.add(_TaggedFrame(null, trackNum, false, sf));
      }
    }

    // Sort by PTS (frames without PTS go after those with PTS)
    allFrames.sort((a, b) {
      final aPts = a.ptsMs ?? 0x7FFFFFFFFFFFFFFF;
      final bPts = b.ptsMs ?? 0x7FFFFFFFFFFFFFFF;
      return aPts.compareTo(bPts);
    });

    if (allFrames.isEmpty) return;

    // Determine base PTS for relative timecodes
    int basePtsMs = 0;
    for (final f in allFrames) {
      if (f.ptsMs != null) {
        basePtsMs = f.ptsMs!;
        break;
      }
    }

    int clusterTimecodeMs = 0;
    BytesBuilder? clusterContent;

    void flushCluster() {
      if (clusterContent == null) return;
      final content = clusterContent!.toBytes();
      sink.add(Ebml.containerHeader(Ebml.cluster, content.length));
      sink.add(content);
      clusterContent = null;
    }

    for (final tagged in allFrames) {
      final frameMs = tagged.ptsMs != null ? (tagged.ptsMs! - basePtsMs) : 0;

      // Start new cluster at keyframes or when relative timecode overflows int16
      final needNewCluster =
          clusterContent == null ||
          (tagged.isVideo && tagged.frame!.isKeyframe) ||
          (frameMs - clusterTimecodeMs > 30000); // ~30s max cluster

      if (needNewCluster) {
        flushCluster();
        clusterTimecodeMs = frameMs;
        clusterContent = BytesBuilder(copy: false);
        clusterContent!.add(
          Ebml.uintElement(Ebml.clusterTimecode, clusterTimecodeMs),
        );
      }

      // Block header: trackNum (VINT) + relative timecode (int16 BE) + flags
      final relativeMs = (frameMs - clusterTimecodeMs).clamp(-32768, 32767);
      final trackVint = Ebml.encodeTrackNumber(tagged.trackNumber);
      final flags = tagged.isVideo && tagged.frame!.isKeyframe ? 0x80 : 0x00;

      final blockHeader = Uint8List(trackVint.length + 3);
      blockHeader.setRange(0, trackVint.length, trackVint);
      blockHeader[trackVint.length] = (relativeMs >> 8) & 0xFF;
      blockHeader[trackVint.length + 1] = relativeMs & 0xFF;
      blockHeader[trackVint.length + 2] = flags;

      final payload = tagged.isSubtitle
          ? tagged.subtitleFrame!.data
          : tagged.frame!.data;
      final blockData = Uint8List(blockHeader.length + payload.length);
      blockData.setRange(0, blockHeader.length, blockHeader);
      blockData.setRange(blockHeader.length, blockData.length, payload);

      if (tagged.isSubtitle) {
        final duration = tagged.subtitleFrame!.durationMs;
        final blockGroupContent = BytesBuilder(copy: false);
        blockGroupContent.add(Ebml.element(Ebml.block, blockData));
        blockGroupContent.add(Ebml.uintElement(Ebml.blockDuration, duration));
        clusterContent!.add(
          Ebml.element(Ebml.blockGroup, blockGroupContent.toBytes()),
        );
      } else {
        clusterContent!.add(Ebml.element(Ebml.simpleBlock, blockData));
      }
    }

    flushCluster();
  }

  static Uint8List _concat(List<Uint8List> parts) {
    int totalLen = 0;
    for (final p in parts) {
      totalLen += p.length;
    }
    final result = Uint8List(totalLen);
    int offset = 0;
    for (final p in parts) {
      result.setRange(offset, offset + p.length, p);
      offset += p.length;
    }
    return result;
  }
}

class _TaggedFrame {
  final EsFrame? frame;
  final SubtitleFrame? subtitleFrame;
  final int trackNumber;
  final bool isVideo;

  _TaggedFrame(this.frame, this.trackNumber, this.isVideo, this.subtitleFrame);

  bool get isSubtitle => subtitleFrame != null;
  int? get ptsMs => isSubtitle ? subtitleFrame!.startTimeMs : frame!.ptsMs;
}
