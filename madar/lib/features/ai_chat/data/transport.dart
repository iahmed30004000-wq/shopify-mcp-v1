/// The only way the AI chat reaches the network: one HTTPS request per
/// explicit user action, over `dart:io` [HttpClient]. Nothing here logs
/// requests, headers or bodies.
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
/// closed as soon as the body is read or the request cancelled).
class IoAiTransport implements AiTransport {
  IoAiTransport({HttpClient Function()? createClient, this.connectTimeout = const Duration(seconds: 20)})
    : _createClient = createClient ?? HttpClient.new;

  final HttpClient Function() _createClient;
  final Duration connectTimeout;

  @override
  Future<AiHttpResponse> send(AiHttpRequest request, {AiCancelToken? cancel}) async {
    if (cancel?.isCancelled ?? false) throw const AiCancelledException();
    final client = _createClient()
      ..connectionTimeout = connectTimeout
      ..idleTimeout = const Duration(seconds: 10)
      ..userAgent = 'Madar';
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
      request.headers.forEach(req.headers.set);
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
