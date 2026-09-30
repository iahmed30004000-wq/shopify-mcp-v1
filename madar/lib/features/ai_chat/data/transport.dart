/// The only way the AI chat reaches the network: one HTTPS request per
/// explicit user action, over `dart:io` [HttpClient], and only to the two
/// services' API hosts ([AiHostPolicy]). Nothing here logs requests,
/// headers or bodies, and no exception thrown from here carries them.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';

/// One outgoing request, exactly as it will be sent.
@immutable
class AiHttpRequest {
  const AiHttpRequest({required this.method, required this.url, this.headers = const {}, this.body});

  final String method;
  final Uri url;

  /// Lower-case header names.
  final Map<String, String> headers;

  /// JSON text (null for GET).
  final String? body;
}

/// A response whose body streams in.
class AiHttpResponse {
  AiHttpResponse({required this.statusCode, required this.headers, required this.body});

  final int statusCode;

  /// Lower-case header names.
  final Map<String, String> headers;

  /// Listen once; cancelling the subscription closes the connection.
  final Stream<List<int>> body;
}

/// The user tapped Stop (or left the screen).
class AiCancelledException implements Exception {
  const AiCancelledException();

  @override
  String toString() => 'AiCancelledException';
}

/// The request's address is not one the AI chat may contact (see
/// [AiHostPolicy]). Nothing was sent – not even a DNS lookup.
class AiHostNotAllowedException implements Exception {
  const AiHostNotAllowedException();

  // Deliberately without the URL or headers.
  @override
  String toString() => 'AiHostNotAllowedException';
}

/// A header value (in practice: the key) that HTTP can't carry. Replaces
/// `dart:io`'s FormatException, whose text would contain the whole value.
class AiInvalidHeaderException implements Exception {
  const AiInvalidHeaderException();

  @override
  String toString() => 'AiInvalidHeaderException';
}

/// Where the AI chat may connect: TLS on the default port to
/// api.anthropic.com or api.openai.com – and each service's key only to its
/// own host (an Anthropic `x-api-key` never goes to OpenAI, an OpenAI
/// `authorization` never goes to Anthropic).
abstract final class AiHostPolicy {
  static const String anthropicHost = 'api.anthropic.com';
  static const String openAiHost = 'api.openai.com';

  static bool allowsUrl(Uri url) =>
      url.scheme == 'https' &&
      (url.host == anthropicHost || url.host == openAiHost) &&
      url.port == 443 &&
      url.userInfo.isEmpty &&
      !url.hasFragment;

  /// Whether [request] may go out.
  static bool check(AiHttpRequest request) {
    if (!allowsUrl(request.url)) return false;
    for (final name in request.headers.keys) {
      final n = name.toLowerCase();
      if (n == 'x-api-key' && request.url.host != anthropicHost) return false;
      if (n == 'authorization' && request.url.host != openAiHost) return false;
    }
    return true;
  }
}

/// Cancels an in-flight request.
class AiCancelToken {
  final Completer<void> _done = Completer<void>();

  bool get isCancelled => _done.isCompleted;

  Future<void> get whenCancelled => _done.future;

  void cancel() {
    if (!_done.isCompleted) _done.complete();
  }
}

/// Sends [AiHttpRequest]s. Replaced by a fake in tests.
abstract interface class AiTransport {
  /// Resolves when the response headers arrive. Throws
  /// [AiCancelledException] when [cancel] fires first, and the platform's
  /// socket / TLS / HTTP exceptions when the network fails.
  Future<AiHttpResponse> send(AiHttpRequest request, {AiCancelToken? cancel});
}

/// [AiTransport] over `dart:io` [HttpClient] (a fresh client per request,
/// closed as soon as the body is read or the request cancelled). Refuses
/// every request [AiHostPolicy] doesn't allow, before any connection.
class IoAiTransport implements AiTransport {
  IoAiTransport({HttpClient Function()? createClient, this.connectTimeout = const Duration(seconds: 20)})
    : _createClient = createClient ?? HttpClient.new,
      _allows = AiHostPolicy.check;

  /// Tests only: plain HTTP to a server on this machine (and nothing else).
  @visibleForTesting
  IoAiTransport.loopbackForTesting({HttpClient Function()? createClient, this.connectTimeout = const Duration(seconds: 20)})
    : _createClient = createClient ?? HttpClient.new,
      _allows = _isLoopback;

  static bool _isLoopback(AiHttpRequest r) =>
      r.url.scheme == 'http' && (r.url.host == '127.0.0.1' || r.url.host == 'localhost');

  static final RegExp _headerValue = RegExp(r'^[\x20-\x7E\t]*$');

  final HttpClient Function() _createClient;
  final bool Function(AiHttpRequest request) _allows;
  final Duration connectTimeout;

  @override
  Future<AiHttpResponse> send(AiHttpRequest request, {AiCancelToken? cancel}) async {
    if (cancel?.isCancelled ?? false) throw const AiCancelledException();
    if (!_allows(request)) throw const AiHostNotAllowedException();
    // Checked before connecting; dart:io would reject these too, but with
    // the whole value (the key) in its exception text.
    if (!request.headers.values.every(_headerValue.hasMatch)) throw const AiInvalidHeaderException();
    final client = _createClient()
      ..connectionTimeout = connectTimeout
      ..idleTimeout = const Duration(seconds: 10)
      ..userAgent = 'Madar'
      // Never accept a certificate the platform doesn't trust.
      ..badCertificateCallback = ((cert, host, port) => false);
    var closed = false;
    void closeClient() {
      if (closed) return;
      closed = true;
      client.close(force: true);
    }

    HttpClientRequest? pending;
    final onCancel = cancel?.whenCancelled.then((_) {
      pending?.abort(const AiCancelledException());
      closeClient();
    });
    unawaited(onCancel);
    try {
      final req = pending = await client.openUrl(request.method, request.url);
      if (cancel?.isCancelled ?? false) throw const AiCancelledException();
      req.followRedirects = false;
      try {
        request.headers.forEach(req.headers.set);
      } on FormatException {
        // Its text would carry the value – the key.
        throw const AiInvalidHeaderException();
      }
      final body = request.body;
      if (body != null) {
        final bytes = utf8.encode(body);
        req.contentLength = bytes.length;
        req.add(bytes);
      }
      final resp = await req.close();
      final headers = <String, String>{};
      resp.headers.forEach((name, values) => headers[name.toLowerCase()] = values.join(','));

      StreamSubscription<List<int>>? sub;
      final out = StreamController<List<int>>(
        onPause: () => sub?.pause(),
        onResume: () => sub?.resume(),
        onCancel: () async {
          final s = sub;
          sub = null;
          closeClient();
          await s?.cancel();
        },
      );
      out.onListen = () {
        sub = resp.listen(
          out.add,
          onError: (Object e, StackTrace st) {
            out.addError((cancel?.isCancelled ?? false) ? const AiCancelledException() : e, st);
            closeClient();
            out.close();
          },
          onDone: () {
            closeClient();
            out.close();
          },
          cancelOnError: true,
        );
      };
      return AiHttpResponse(statusCode: resp.statusCode, headers: headers, body: out.stream);
    } catch (e) {
      closeClient();
      if (cancel?.isCancelled ?? false) throw const AiCancelledException();
      rethrow;
    }
  }
}
