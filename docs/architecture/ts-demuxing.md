# TS Demuxing

One of the standout features of `byte_me` is the custom MPEG-TS (Transport Stream) demuxer written entirely in Dart (`TsDemuxer`).

This document provides a technical overview of how `byte_me` parses `.ts` fragments to enable genuine Matroska remuxing.

## The MPEG-TS Format

MPEG-TS is a legacy broadcast format. It wraps video and audio streams in tiny 188-byte packets, designed to be highly resilient to packet loss over the airwaves. This makes it a popular format for HTTP Live Streaming (HLS), where streams are chopped into small, downloadable files.

However, saving a raw `.ts` file to disk creates a poor playback experience. Because the file is just a dumb sequence of 188-byte packets, there is no central index. If a user tries to skip to the middle of the video, the media player has to blindly guess the byte offset, which often causes stuttering, gray screens, or complete playback failure.

## How `TsDemuxer` Works

To fix this, `byte_me` unpacks the `.ts` stream to get to the underlying raw video frames. 

1. **Packet Parsing:** The demuxer scans the file, looking for the `0x47` sync byte that marks the start of every 188-byte packet.
2. **PSI/PMT Extraction:** It finds the Program Association Table (PAT) and Program Map Table (PMT) to identify which Packet Identifiers (PIDs) belong to the video and audio streams.
3. **PES Assembly:** It extracts the Packetized Elementary Stream (PES) payloads. Since a single video frame is much larger than 188 bytes, it spans across dozens of packets. The demuxer correctly handles the `payload_unit_start_indicator` to reassemble these chunks into complete frames.
4. **Timestamp Extraction:** During PES assembly, it extracts the Presentation Timestamp (PTS) and Decoding Timestamp (DTS). This is crucial for keeping the video and audio perfectly in sync during remuxing.
5. **Format Conversion:** 
   - Broadcast H.264 video streams use **Annex B** formatting (streams of bytes separated by `0x00000001` start codes).
   - Matroska (MKV) requires **AVCC** formatting (where frames are prefixed by their 4-byte length).
   - The `TsDemuxer` natively parses the NAL units, extracts the Sequence Parameter Sets (SPS) and Picture Parameter Sets (PPS) required for the MKV codec headers, and converts the video frames from Annex B to AVCC on the fly.

By extracting the pure H.264 and AAC streams, the `MkvRemuxer` can reconstruct the video file exactly how modern media players expect it, complete with keyframe indices (`Clusters`) that allow for instant, precise scrubbing.
