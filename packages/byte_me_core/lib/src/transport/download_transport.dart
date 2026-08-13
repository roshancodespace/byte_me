import '../models/download_request.dart';

/// Standardized representation of an HTTP response from any transport layer.
class DownloadResponse {
  /// The HTTP status code (e.g. 200, 206, 404).
  final int statusCode;

  /// The size of the file/chunk being sent, if provided by the server.
  final int? contentLength;

  /// HTTP headers returned by the server.
  final Map<String, String> headers;

  /// The raw incoming bytes from the network
  final Stream<List<int>> byteStream;

  /// A callback to forcbily terminate the network connection
  final void Function() abort;

  const DownloadResponse({
    required this.statusCode,
    this.contentLength,
    required this.headers,
    required this.byteStream,
    required this.abort,
  });
}

/// An abstraction for the network layer used by the DownloadEngine.
/// 
/// Implementing this interface allows swapping out the default Dart `HttpClient`
/// for something else, like `dio`, `http`, or platform-specific channels.
abstract interface class DownloadTransport {
  /// Opens a connection and returns the response headers and byte stream.
  Future<DownloadResponse> open(DownloadRequest request);
}
