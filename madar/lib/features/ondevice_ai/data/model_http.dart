/// The only network code of this feature: ranged GETs of a model file over
/// HTTPS, used by the download manager and by nothing else. Inference (the
/// router, the engines, the guard) never imports this file, and a test scans
/// the folder to keep it so.
///
/// Not exercised against a real host in step A (every catalogue entry is an
/// unverified placeholder): it is small on purpose, and refuses anything that
/// is not HTTPS.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../../reading/data/download_ports.dart';

class IoRangeHttpClient implements RangeHttpClient {
  IoRangeHttpClient({HttpClient Function()? create, this.timeout = const Duration(seconds: 30)})
    : _create = create ?? HttpClient.new;

  final HttpClient Function() _create;
  final Duration timeout;

  static void _requireHttps(Uri url) {
    if (url.scheme != 'https') throw const TransportException('Only HTTPS is allowed', retryable: false);
  }

  static bool _retryable(int status) => status == 408 || status == 429 || status >= 500;

  @override
  Future<HeadInfo> head(Uri url) async {
    _requireHttps(url);
    final client = _create()..connectionTimeout = timeout;
    try {
      final req = await client.openUrl('HEAD', url);
      final res = await req.close().timeout(timeout);
      await res.drain<void>();
      if (res.statusCode != 200) {
        throw TransportException('HEAD ${res.statusCode}', statusCode: res.statusCode, retryable: _retryable(res.statusCode));
      }
      final ranges = res.headers.value('accept-ranges')?.toLowerCase() == 'bytes';
      return HeadInfo(contentLength: res.contentLength, acceptsRanges: ranges);
    } on SocketException catch (e) {
      throw TransportException(e.message);
    } on TimeoutException {
      throw const TransportException('Timed out');
    } on HttpException catch (e) {
      throw TransportException(e.message);
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<Uint8List> getRange(Uri url, int start, int end) async {
    _requireHttps(url);
    final client = _create()..connectionTimeout = timeout;
    try {
      final req = await client.openUrl('GET', url);
      req.headers.set(HttpHeaders.rangeHeader, 'bytes=$start-$end');
      final res = await req.close().timeout(timeout);
      if (res.statusCode != 206) {
        await res.drain<void>();
        throw TransportException('GET ${res.statusCode}', statusCode: res.statusCode, retryable: _retryable(res.statusCode));
      }
      final out = BytesBuilder(copy: false);
      await for (final chunk in res.timeout(timeout)) {
        out.add(chunk);
      }
      return out.takeBytes();
    } on SocketException catch (e) {
      throw TransportException(e.message);
    } on TimeoutException {
      throw const TransportException('Timed out');
    } on HttpException catch (e) {
      throw TransportException(e.message);
    } finally {
      client.close(force: true);
    }
  }
}
