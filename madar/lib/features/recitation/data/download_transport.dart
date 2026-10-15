import 'dart:async';
import 'dart:io';

/// An HTTP response being received.
class DownloadResponse {
  DownloadResponse({
    required this.statusCode,
    required this.body,
    this.contentLength,
    this.totalLength,
    required this.abort,
  });

  final int statusCode;

  /// Bytes in this response's body (null when unknown).
  final int? contentLength;

  /// Full size of the file (from `Content-Range` on a 206), when known.
  final int? totalLength;
  final Stream<List<int>> body;

  /// Closes the connection without reading the rest.
  final void Function() abort;

  bool get isPartial => statusCode == HttpStatus.partialContent;
}

/// Fetches files for downloads (dart:io HttpClient in the app, a scripted
/// fake in tests).
abstract class DownloadTransport {
  /// GET [uri], asking for bytes from [from] onwards when [from] > 0.
  Future<DownloadResponse> get(Uri uri, {int from = 0});

  void close();
}

/// [DownloadTransport] on dart:io's HttpClient (system proxy and trust
/// store; HTTPS only by construction of the URLs).
class HttpDownloadTransport implements DownloadTransport {
  HttpDownloadTransport({HttpClient? client})
    : _client = client ?? (HttpClient()..connectionTimeout = const Duration(seconds: 20)) {
    _client.userAgent = 'Madar/1 (Quran recitation download)';
  }

  final HttpClient _client;

  @override
  Future<DownloadResponse> get(Uri uri, {int from = 0}) async {
    final request = await _client.getUrl(uri);
    if (from > 0) request.headers.set(HttpHeaders.rangeHeader, 'bytes=$from-');
    final response = await request.close().timeout(const Duration(seconds: 30));
    return DownloadResponse(
      statusCode: response.statusCode,
      contentLength: response.contentLength >= 0 ? response.contentLength : null,
      totalLength: totalFromContentRange(response.headers.value(HttpHeaders.contentRangeHeader)),
      body: response.timeout(const Duration(seconds: 30)),
      abort: () => request.abort(),
    );
  }

  @override
  void close() => _client.close(force: true);

  /// `bytes 100-999/1000` → 1000.
  static int? totalFromContentRange(String? header) {
    if (header == null) return null;
    final slash = header.lastIndexOf('/');
    if (slash < 0) return null;
    return int.tryParse(header.substring(slash + 1).trim());
  }
}
