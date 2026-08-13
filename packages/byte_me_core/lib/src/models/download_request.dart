import 'dart:io';

import 'retry_config.dart';

/// Represents a unique request to download a file from a remote server.
/// 
/// This class is immutable. To start a download, pass this request into 
/// a [DownloadTask] and enqueue it in the [DownloadManager].
class DownloadRequest {
  /// A unique identifier for this request. Used for resuming and tracking.
  final String id;

  /// The remote HTTP/HTTPS URL of the target file.
  final Uri url;

  /// The local file system path where the bytes will be written.
  final File destination;

  /// Optional HTTP headers to include with the request (e.g., Authorization).
  final Map<String, String>? headers;

  /// Defines the behavior for handling temporary network failures.
  final RetryConfig retryConfig;

  const DownloadRequest({
    required this.id,
    required this.url,
    required this.destination,
    this.headers,
    this.retryConfig = const RetryConfig(),
  });
}
