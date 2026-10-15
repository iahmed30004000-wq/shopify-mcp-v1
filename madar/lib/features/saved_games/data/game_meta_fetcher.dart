import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../domain/page_meta.dart';
import '../domain/saved_web_game.dart';

/// Reads a game page's title or icon – ONLY when the user taps "Fetch
/// title" / "Site icon" (Madar never goes online by itself). Nothing about
/// the user is sent: no cookies, no referrer, no identifiers.
abstract interface class GameMetaFetcher {
  /// The page's suggested title, or null.
  Future<String?> fetchTitle(Uri page);

  /// The site's icon as a small square PNG (≤ [SavedGamesLimits.maxIconBytes]),
  /// or null.
  Future<Uint8List?> fetchIcon(Uri page);
}

/// Failure reasons are not surfaced: the UI shows one friendly message.
class HttpGameMetaFetcher implements GameMetaFetcher {
  HttpGameMetaFetcher({HttpClient Function()? client, this.timeout = const Duration(seconds: 10)})
    : _client = client ?? HttpClient.new;

  final HttpClient Function() _client;
  final Duration timeout;

  static const int maxPageBytes = 512 * 1024;
  static const int maxIconDownload = 256 * 1024;
  static const int maxRedirects = 5;

  @override
  Future<String?> fetchTitle(Uri page) async {
    final got = await _get(page, maxPageBytes, accept: 'text/html,application/xhtml+xml', partial: true);
    if (got == null) return null;
    return parsePageMeta(_decode(got.$2), got.$1).title;
  }

  @override
  Future<Uint8List?> fetchIcon(Uri page) async {
    final got = await _get(page, maxPageBytes, accept: 'text/html,application/xhtml+xml', partial: true);
    final meta = got == null ? parsePageMeta('', page) : parsePageMeta(_decode(got.$2), got.$1);
    for (final icon in meta.icons.take(4)) {
      final bytes = await _get(icon, maxIconDownload, accept: 'image/png,image/x-icon,image/*;q=0.8');
      if (bytes == null) continue;
      final png = await squareIconPng(bytes.$2);
      if (png != null) return png;
    }
    return null;
  }

  /// GET over https only (every redirect hop too), bounded in size and time.
  /// Returns the final URL and the body.
  Future<(Uri, Uint8List)?> _get(Uri url, int maxBytes, {required String accept, bool partial = false}) async {
    final client = _client()
      ..connectionTimeout = timeout
      ..idleTimeout = const Duration(seconds: 2)
      ..autoUncompress = true
      ..findProxy = HttpClient.findProxyFromEnvironment;
    client.userAgent = 'Madar (+link preview)';
    try {
      var current = url;
      for (var hop = 0; hop <= maxRedirects; hop++) {
        if (current.scheme != 'https' || current.host.isEmpty) return null;
        final request = await client.getUrl(current).timeout(timeout);
        request
          ..followRedirects = false
          ..persistentConnection = false
          ..headers.set(HttpHeaders.acceptHeader, accept);
        final response = await request.close().timeout(timeout);
        if (response.isRedirect) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          await response.drain<void>().catchError((Object _) {});
          if (location == null) return null;
          current = current.resolve(location);
          continue;
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          await response.drain<void>().catchError((Object _) {});
          return null;
        }
        // An oversized icon is refused; a page is still worth its head, so
        // only the first [maxBytes] are read.
        if (!partial && response.contentLength > maxBytes) {
          await response.drain<void>().catchError((Object _) {});
          return null;
        }
        final (body, complete) = await _readBounded(response, maxBytes).timeout(timeout);
        if (!partial && !complete) return null;
        return (current, body);
      }
      return null;
    } on Object {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// At most [maxBytes] of [stream]; whether the whole body fitted.
  static Future<(Uint8List, bool)> _readBounded(Stream<List<int>> stream, int maxBytes) async {
    final out = BytesBuilder(copy: false);
    var complete = true;
    await for (final chunk in stream) {
      final room = maxBytes - out.length;
      if (chunk.length > room) {
        out.add(chunk.sublist(0, room));
        complete = false;
        break;
      }
      out.add(chunk);
    }
    return (out.takeBytes(), complete);
  }

  static String _decode(Uint8List bytes) => utf8.decode(bytes, allowMalformed: true);
}

/// Decodes [bytes] (PNG, ICO, JPEG, GIF, WebP, BMP) and redraws it centred
/// on a transparent [SavedGamesLimits.iconPixels] square PNG. Returns null
/// when it is not a decodable image or the result is too large.
Future<Uint8List?> squareIconPng(Uint8List bytes) async {
  if (bytes.isEmpty) return null;
  ui.Codec? codec;
  ui.Image? source;
  ui.Image? out;
  try {
    codec = await ui.instantiateImageCodec(bytes);
    source = (await codec.getNextFrame()).image;
    if (source.width < 8 || source.height < 8) return null;
    for (final px in const [SavedGamesLimits.iconPixels, 64, 48]) {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final scale = px / (source.width > source.height ? source.width : source.height);
      final w = source.width * scale;
      final h = source.height * scale;
      canvas.drawImageRect(
        source,
        ui.Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
        ui.Rect.fromLTWH((px - w) / 2, (px - h) / 2, w, h),
        ui.Paint()..filterQuality = ui.FilterQuality.medium,
      );
      out?.dispose();
      out = await recorder.endRecording().toImage(px, px);
      final png = await out.toByteData(format: ui.ImageByteFormat.png);
      if (png != null && png.lengthInBytes <= SavedGamesLimits.maxIconBytes) {
        return png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
      }
    }
    return null;
  } on Object {
    return null;
  } finally {
    out?.dispose();
    source?.dispose();
    codec?.dispose();
  }
}
