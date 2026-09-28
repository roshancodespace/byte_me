---
layout: home

hero:
  name: "byte_me"
  text: "A highly cohesive, isolate-driven downloader and remuxer."
  tagline: "High-performance file downloads and zero-reencoding HLS to MKV remuxing for Dart/Flutter."
  actions:
    - theme: brand
      text: Get Started
      link: /guide/
    - theme: alt
      text: View on GitHub
      link: https://github.com/roshancodespace/ShonenX/tree/main/packages/byte_me

features:
  - title: Isolate-Driven
    details: Heavy tasks like AES-128 decryption and TS/MKV remuxing run seamlessly on background isolates, keeping the UI perfectly smooth.
  - title: Natively Remuxes HLS
    details: Fully supports H.264/AAC extraction and multiplexing directly into standard Matroska (.mkv) containers—no FFmpeg needed!
  - title: Subtitle Injection
    details: Interleave external SRT subtitle tracks effortlessly while downloading, embedding them as perfectly seekable S_TEXT tracks inside the MKV.
---
