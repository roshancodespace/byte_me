import 'dart:io';

import '../models/download_request.dart';
import 'download_transport.dart';

/// A default implementation of [DownloadTransport] using the standard `dart:io` `HttpClient`.
class DartHttpTransport implements DownloadTransport {
  final HttpClient _client;

  /// Creates a new [DartHttpTransport].
  ///
  /// You can optionally provide your own [HttpClient] if you need custom
  /// certificates, proxy configurations, or connection timeouts.
  DartHttpTransport({HttpClient? client}) : _client = client ?? HttpClient();

  @override
  Future<DownloadResponse> open(DownloadRequest request) async {
    final httpRequest = await _client.getUrl(request.url);

    request.headers?.forEach((key, value) {
      httpRequest.headers.set(key, value);
    });

    final httpResponse = await httpRequest.close();

    final headers = <String, String>{};
    httpResponse.headers.forEach((name, values) {
      headers[name] = values.join('.');
    });

    return DownloadResponse(
      statusCode: httpResponse.statusCode,
      contentLength: httpResponse.contentLength == -1
          ? null
          : httpResponse.contentLength,
      headers: headers,
      byteStream: httpResponse,
      abort: () => httpRequest.abort(),
    );
  }
}
