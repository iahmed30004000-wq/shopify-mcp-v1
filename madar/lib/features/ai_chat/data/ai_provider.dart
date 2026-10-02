/// The provider contract of the AI chat and the shared HTTP + SSE plumbing
/// of the Anthropic and OpenAI implementations: timeouts, cancel, error
/// mapping. No automatic retries – a retry is always the user's tap.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/ai_models.dart';
import 'key_store.dart';
import 'sse.dart';
import 'transport.dart';

/// An AI service reached with the user's own key.
abstract interface class AiProvider {
  AiProviderId get id;

  /// The exact HTTP request [streamChat] sends for [request] (with
  /// [apiKey] in its auth header – pass a masked key for display).
  AiHttpRequest chatRequest(AiRequest request, {required String apiKey});

  /// Streams one reply. Throws [AiException] on failure; ends quietly
  /// (without [AiStreamDone]) when [cancel] fires.
  Stream<AiStreamEvent> streamChat(AiRequest request, {required String apiKey, AiCancelToken? cancel});

  /// The models this key can use (only on the user's "Refresh models").
  Future<List<AiModelInfo>> listModels({required String apiKey, AiCancelToken? cancel});

  /// Checks the key with a free call (only on the user's "Test key").
  Future<void> testKey(String apiKey, {AiCancelToken? cancel});
}

/// Details a provider's error body carries.
typedef AiErrorBody = ({String? type, String? code, String? message});

/// Shared plumbing of the HTTP providers.
abstract class HttpAiProvider implements AiProvider {
  HttpAiProvider(
    this.transport, {
    this.responseTimeout = const Duration(seconds: 60),
    this.idleTimeout = const Duration(seconds: 120),
  });

  final AiTransport transport;

  /// Longest wait for the response headers.
  final Duration responseTimeout;

  /// Longest silence between two stream events (reasoning models can think
  /// for a while; Anthropic sends pings meanwhile).
  final Duration idleTimeout;

  /// The request of "list models".
  AiHttpRequest modelsRequest(String apiKey, {int? limit});

  /// Parses "list models".
  List<AiModelInfo> parseModels(Object? json);

  /// Handles one stream event: returns the events to emit, throws
  /// [AiException] for an error event.
  Iterable<AiStreamEvent> onEvent(SseEvent event, AiStreamState state);

  /// Pulls type / code / message out of an error body.
  AiErrorBody errorBody(Object? json);

  @override
  Stream<AiStreamEvent> streamChat(AiRequest request, {required String apiKey, AiCancelToken? cancel}) {
    // A plain controller (not `async*`), so Stop cancels the connection at
    // once even while the service is silent.
    late final StreamController<AiStreamEvent> out;
    StreamSubscription<SseEvent>? sub;
    var closed = false;
    bool cancelled() => cancel?.isCancelled ?? false;

    void finish([Object? error, StackTrace? stack]) {
      if (closed) return;
      closed = true;
      if (error != null) out.addError(error, stack);
      out.close();
      final s = sub;
      sub = null;
      unawaited(s?.cancel());
    }

    Future<void> start() async {
      final AiHttpResponse resp;
      try {
        resp = await _send(chatRequest(request, apiKey: apiKey), apiKey, cancel);
      } catch (e, st) {
        if (cancelled() || e is AiCancelledException) return finish();
        return finish(mapTransportError(e), st);
      }
      if (closed) {
        // Stopped while connecting.
        unawaited(resp.body.listen(null).cancel());
        return;
      }
      final state = AiStreamState();
      sub = decodeSse(resp.body)
          .timeout(idleTimeout, onTimeout: (sink) => sink.addError(TimeoutException('idle', idleTimeout)))
          .listen(
            (e) {
              if (closed) return;
              if (cancelled()) return finish();
              try {
                for (final ev in onEvent(e, state)) {
                  out.add(ev);
                  if (ev is AiStreamDone) return finish();
                }
              } on AiException catch (x, st) {
                finish(x, st);
              }
            },
            onError: (Object e, StackTrace st) {
              if (cancelled() || e is AiCancelledException) return finish();
              finish(mapTransportError(e), st);
            },
            onDone: () {
              if (closed) return;
              if (cancelled()) return finish();
              // The stream ended without its final event.
              final reason = state.stopReason;
              if (reason != null) {
                out.add(AiStreamDone(reason: reason, inputTokens: state.inputTokens, outputTokens: state.outputTokens));
                return finish();
              }
              finish(const AiException(AiErrorKind.network, detail: 'stream ended early'));
            },
          );
    }

    out = StreamController<AiStreamEvent>(
      onListen: () => unawaited(start()),
      onCancel: () {
        closed = true;
        final s = sub;
        sub = null;
        return s?.cancel();
      },
    );
    return out.stream;
  }

  @override
  Future<List<AiModelInfo>> listModels({required String apiKey, AiCancelToken? cancel}) async {
    final json = await _getJson(modelsRequest(apiKey), apiKey, cancel);
    return parseModels(json);
  }

  @override
  Future<void> testKey(String apiKey, {AiCancelToken? cancel}) async {
    await _getJson(modelsRequest(apiKey, limit: 1), apiKey, cancel);
  }

  Future<Object?> _getJson(AiHttpRequest request, String apiKey, AiCancelToken? cancel) async {
    final resp = await _send(request, apiKey, cancel);
    try {
      final text = await _readText(resp.body, 4 << 20);
      return jsonDecode(text);
    } on AiException {
      rethrow;
    } on FormatException {
      throw const AiException(AiErrorKind.badResponse);
    } catch (e) {
      if (e is AiCancelledException || (cancel?.isCancelled ?? false)) rethrow;
      throw mapTransportError(e);
    }
  }

  /// Sends [request]; a non-2xx answer becomes an [AiException]. A key HTTP
  /// can't carry, or the other service's key, is refused here – nothing
  /// goes out.
  Future<AiHttpResponse> _send(AiHttpRequest request, String apiKey, AiCancelToken? cancel) async {
    if (!AiKeyStore.sendable(id, apiKey)) throw const AiException(AiErrorKind.badKey);
    final AiHttpResponse resp;
    // Our own token, so a timeout also tears the request down.
    final inner = AiCancelToken();
    unawaited(cancel?.whenCancelled.then((_) => inner.cancel()));
    try {
      resp = await transport.send(request, cancel: inner).timeout(responseTimeout);
    } on AiCancelledException {
      rethrow;
    } catch (e) {
      inner.cancel();
      if (cancel?.isCancelled ?? false) throw const AiCancelledException();
      throw mapTransportError(e);
    }
    if (resp.statusCode >= 200 && resp.statusCode < 300) return resp;
    String raw = '';
    try {
      raw = await _readText(resp.body, 64 << 10).timeout(const Duration(seconds: 10));
    } catch (_) {}
    Object? json;
    try {
      json = raw.isEmpty ? null : jsonDecode(raw);
    } catch (_) {}
    throw mapHttpError(resp.statusCode, resp.headers, errorBody(json), apiKey);
  }

  static Future<String> _readText(Stream<List<int>> body, int maxBytes) async {
    final bytes = <int>[];
    await for (final chunk in body) {
      bytes.addAll(chunk);
      if (bytes.length > maxBytes) break;
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// Maps an HTTP error to what the user can act on.
  AiException mapHttpError(int status, Map<String, String> headers, AiErrorBody body, String apiKey) {
    final type = body.type ?? '';
    final code = body.code ?? '';
    final message = body.message ?? '';
    final lower = message.toLowerCase();
    final detail = message.isEmpty ? null : AiRedactor.redact(message, secrets: [apiKey]);
    final retryAfter = _retryAfter(headers['retry-after']);
    AiException ex(AiErrorKind kind) => AiException(kind, statusCode: status, detail: detail, retryAfter: retryAfter);

    if (type == 'overloaded_error' || status == 529 || status == 503) return ex(AiErrorKind.overloaded);
    if (status == 401 || type == 'authentication_error' || code == 'invalid_api_key') return ex(AiErrorKind.badKey);
    if (status == 402 ||
        type == 'billing_error' ||
        code == 'insufficient_quota' ||
        type == 'insufficient_quota' ||
        lower.contains('credit balance') ||
        lower.contains('spend limit') ||
        lower.contains('exceeded your current quota')) {
      return ex(AiErrorKind.quotaExceeded);
    }
    if (status == 429 || type == 'rate_limit_error') return ex(AiErrorKind.rateLimited);
    if (status == 404 || type == 'not_found_error' || code == 'model_not_found') return ex(AiErrorKind.modelNotFound);
    if (status == 403 || type == 'permission_error') return ex(AiErrorKind.forbidden);
    if (status == 413 ||
        code == 'context_length_exceeded' ||
        lower.contains('prompt is too long') ||
        lower.contains('maximum context length') ||
        lower.contains('too many tokens')) {
      return ex(AiErrorKind.contextTooLong);
    }
    if (status == 408 || status == 504 || type == 'timeout_error') return ex(AiErrorKind.timeout);
    if (status >= 500) return ex(AiErrorKind.serverError);
    if (lower.contains('temperature')) return ex(AiErrorKind.temperatureUnsupported);
    if (lower.contains('model') &&
        (lower.contains('does not exist') || lower.contains('not found') || lower.contains('invalid model'))) {
      return ex(AiErrorKind.modelNotFound);
    }
    if (status >= 400) return ex(AiErrorKind.badRequest);
    return ex(AiErrorKind.unknown);
  }

  /// Maps a mid-stream error event (Anthropic `error`, OpenAI `error`).
  AiException mapStreamError(AiErrorBody body) {
    final type = body.type ?? '';
    final status = switch (type) {
      'overloaded_error' => 529,
      'rate_limit_error' || 'rate_limit_exceeded' => 429,
      'authentication_error' => 401,
      'permission_error' => 403,
      'not_found_error' => 404,
      'request_too_large' => 413,
      'timeout_error' => 504,
      'api_error' || 'server_error' => 500,
      _ => 400,
    };
    final mapped = mapHttpError(status, const {}, body, '');
    // A mid-stream "invalid request" is most likely the service failing.
    return mapped.kind == AiErrorKind.badRequest && type.isEmpty
        ? AiException(AiErrorKind.serverError, detail: mapped.detail)
        : mapped;
  }

  static Duration? _retryAfter(String? raw) {
    if (raw == null) return null;
    final s = double.tryParse(raw.trim());
    if (s == null || s < 0 || s > 3600) return null;
    return Duration(milliseconds: (s * 1000).round());
  }

  /// Socket / TLS / timeout / parsing failures.
  static AiException mapTransportError(Object e) => switch (e) {
    AiException() => e,
    TimeoutException() => const AiException(AiErrorKind.timeout),
    AiInvalidHeaderException() => const AiException(AiErrorKind.badKey),
    AiHostNotAllowedException() => const AiException(AiErrorKind.network),
    SocketException() ||
    HandshakeException() ||
    TlsException() ||
    HttpException() ||
    OSError() => const AiException(AiErrorKind.network),
    FormatException() => const AiException(AiErrorKind.badResponse),
    _ => const AiException(AiErrorKind.unknown),
  };

  /// Decodes an event's JSON data (null when it isn't JSON).
  static Map<String, Object?>? jsonOf(SseEvent e) {
    try {
      final v = jsonDecode(e.data);
      return v is Map ? v.cast<String, Object?>() : null;
    } on FormatException {
      return null;
    }
  }
}

/// What a stream has told us so far.
class AiStreamState {
  AiStopReason? stopReason;
  int? inputTokens;
  int? outputTokens;
}
