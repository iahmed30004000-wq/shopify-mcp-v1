import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/ai_chat/ai_chat.dart';
import 'package:madar/features/ai_chat/data/sse.dart';

import 'ai_chat_fakes.dart';

const _request = AiRequest(
  provider: AiProviderId.anthropic,
  model: 'claude-sonnet-5-5',
  system: 'SYSTEM',
  messages: [AiTurn(ChatRole.user, 'مرحبا'), AiTurn(ChatRole.assistant, 'أهلًا'), AiTurn(ChatRole.user, 'Hi')],
  maxTokens: 2048,
);

AiRequest _openAiRequest({double? temperature}) => AiRequest(
  provider: AiProviderId.openai,
  model: 'gpt-6.1-sol',
  system: 'SYSTEM',
  messages: const [AiTurn(ChatRole.user, 'Hi')],
  maxTokens: 1024,
  temperature: temperature,
);

Future<String> _text(Stream<AiStreamEvent> s) async {
  final b = StringBuffer();
  await for (final e in s) {
    if (e is AiTextDelta) b.write(e.text);
  }
  return b.toString();
}

Future<AiException> _error(Future<Object?> f) async {
  try {
    await f;
  } on AiException catch (e) {
    return e;
  }
  fail('expected an AiException');
}

void main() {
  group('SSE decoding', () {
    Stream<List<int>> bytes(List<List<int>> chunks) => Stream.fromIterable(chunks);

    test('events split anywhere, even inside a multi-byte character', () async {
      final raw = utf8.encode(
        'event: a\ndata: مرحبا\n\n: comment\nevent: b\r\ndata: one\r\ndata: two\r\n\r\ndata: tail',
      );
      for (var size = 1; size <= 7; size++) {
        final chunks = [
          for (var i = 0; i < raw.length; i += size) raw.sublist(i, i + size > raw.length ? raw.length : i + size),
        ];
        final events = await decodeSse(bytes(chunks)).toList();
        expect(events, const [
          SseEvent(event: 'a', data: 'مرحبا'),
          SseEvent(event: 'b', data: 'one\ntwo'),
          SseEvent(data: 'tail'),
        ], reason: 'chunk size $size');
      }
    });

    test('ignores lines without data and resets the event name', () async {
      final events = await decodeSse(bytes([utf8.encode('event: x\n\nid: 7\ndata: {}\n\n')])).toList();
      expect(events, const [SseEvent(data: '{}', id: '7')]);
    });
  });

  group('Anthropic', () {
    test('request: endpoint, headers, body; temperature only when set', () {
      final p = AnthropicProvider(FakeTransport());
      final r = p.chatRequest(_request, apiKey: 'KEY');
      expect(r.method, 'POST');
      expect(r.url.toString(), 'https://api.anthropic.com/v1/messages');
      expect(r.headers['x-api-key'], 'KEY');
      expect(r.headers['anthropic-version'], '2023-06-01');
      expect(r.headers['content-type'], 'application/json');
      final body = jsonDecode(r.body!) as Map;
      expect(body['model'], 'claude-sonnet-5-5');
      expect(body['max_tokens'], 2048);
      expect(body['system'], 'SYSTEM');
      expect(body['stream'], true);
      expect(body.containsKey('temperature'), isFalse);
      expect(body['messages'], [
        {'role': 'user', 'content': 'مرحبا'},
        {'role': 'assistant', 'content': 'أهلًا'},
        {'role': 'user', 'content': 'Hi'},
      ]);
      final withT = AiRequest(
        provider: AiProviderId.anthropic,
        model: 'm',
        system: 's',
        messages: const [AiTurn(ChatRole.user, 'x')],
        maxTokens: 10,
        temperature: 0.3,
      );
      expect((jsonDecode(p.chatRequest(withT, apiKey: 'k').body!) as Map)['temperature'], 0.3);
    });

    test('streams text deltas across chunk boundaries; skips thinking and pings', () async {
      final sse = anthropicSse(['Hello', ' عالم', '!'], thinking: true);
      final t = FakeTransport([FakeReply.sse(chunked(sse, 17))]);
      final events = await AnthropicProvider(t).streamChat(_request, apiKey: 'KEY').toList();
      expect(events.whereType<AiTextDelta>().map((e) => e.text).join(), 'Hello عالم!');
      final done = events.last as AiStreamDone;
      expect(done.reason, AiStopReason.endTurn);
      expect(done.inputTokens, 25);
      expect(done.outputTokens, 15);
    });

    test('stop reasons', () async {
      for (final (raw, reason) in [
        ('max_tokens', AiStopReason.maxTokens),
        ('refusal', AiStopReason.refusal),
        ('pause_turn', AiStopReason.other),
      ]) {
        final t = FakeTransport([
          FakeReply.sse([
            anthropicSse(['x'], stopReason: raw),
          ]),
        ]);
        final events = await AnthropicProvider(t).streamChat(_request, apiKey: 'k').toList();
        expect((events.last as AiStreamDone).reason, reason);
      }
    });

    test('HTTP errors map to what the user can act on', () async {
      Future<AiException> run(int status, Map<String, Object?> body, {Map<String, String> headers = const {}}) =>
          _error(
            AnthropicProvider(FakeTransport([FakeReply.json(body, status: status, headers: headers)]))
                .streamChat(_request, apiKey: 'k')
                .toList(),
          );
      Map<String, Object?> err(String type, String msg) => {
        'type': 'error',
        'error': {'type': type, 'message': msg},
        'request_id': 'req_1',
      };
      expect((await run(401, err('authentication_error', 'invalid x-api-key'))).kind, AiErrorKind.badKey);
      expect((await run(403, err('permission_error', 'no'))).kind, AiErrorKind.forbidden);
      final limited = await run(429, err('rate_limit_error', 'slow down'), headers: {'retry-after': '12'});
      expect(limited.kind, AiErrorKind.rateLimited);
      expect(limited.retryAfter, const Duration(seconds: 12));
      expect(limited.retryable, isTrue);
      expect((await run(529, err('overloaded_error', 'Overloaded'))).kind, AiErrorKind.overloaded);
      expect((await run(500, err('api_error', 'boom'))).kind, AiErrorKind.serverError);
      expect((await run(404, err('not_found_error', 'model: claude-x'))).kind, AiErrorKind.modelNotFound);
      expect(
        (await run(400, err('invalid_request_error', 'temperature is not supported for this model'))).kind,
        AiErrorKind.temperatureUnsupported,
      );
      expect(
        (await run(400, err('invalid_request_error', 'prompt is too long: 250000 tokens > 200000 maximum'))).kind,
        AiErrorKind.contextTooLong,
      );
      expect(
        (await run(
          400,
          err('invalid_request_error', 'Your credit balance is too low to access the Anthropic API'),
        )).kind,
        AiErrorKind.quotaExceeded,
      );
      expect((await run(402, err('billing_error', 'pay'))).kind, AiErrorKind.quotaExceeded);
      final bad = await run(400, err('invalid_request_error', 'messages: roles must alternate'));
      expect(bad.kind, AiErrorKind.badRequest);
      expect(bad.detail, 'messages: roles must alternate');
      expect(bad.retryable, isFalse);
    });

    test('a key echoed in an error message is redacted', () async {
      final e = await _error(
        AnthropicProvider(
          FakeTransport([
            FakeReply.json({
              'type': 'error',
              'error': {'type': 'invalid_request_error', 'message': 'bad key $testAnthropicKey here'},
            }, status: 400),
          ]),
        ).streamChat(_request, apiKey: testAnthropicKey).toList(),
      );
      expect(e.detail, isNot(contains('TESTKEY')));
      expect(e.toString(), isNot(contains('TESTKEY')));
      expect(e.toString(), 'AiException(badRequest, HTTP 400)');
    });

    test('mid-stream error event, early end, network failure and idle timeout', () async {
      final overloaded =
          'event: message_start\ndata: {"type":"message_start","message":{"usage":{"input_tokens":1}}}\n\n'
          'event: content_block_delta\ndata: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hi"}}\n\n'
          'event: error\ndata: {"type": "error", "error": {"type": "overloaded_error", "message": "Overloaded"}}\n\n';
      final received = <String>[];
      final e1 = await _error(
        AnthropicProvider(
          FakeTransport([
            FakeReply.sse([overloaded]),
          ]),
        ).streamChat(_request, apiKey: 'k').map((e) {
          if (e is AiTextDelta) received.add(e.text);
          return e;
        }).toList(),
      );
      expect(e1.kind, AiErrorKind.overloaded);
      expect(received, ['Hi']);

      final cut = anthropicSse(['Hi']).split('event: message_delta').first;
      final e2 = await _error(
        AnthropicProvider(
          FakeTransport([
            FakeReply.sse([cut]),
          ]),
        ).streamChat(_request, apiKey: 'k').toList(),
      );
      expect(e2.kind, AiErrorKind.network);

      final e3 = await _error(
        AnthropicProvider(FakeTransport([FakeReply.fail(const SocketException('Failed host lookup'))]))
            .streamChat(_request, apiKey: 'k')
            .toList(),
      );
      expect(e3.kind, AiErrorKind.network);

      final e4 = await _error(
        AnthropicProvider(
          FakeTransport([
            FakeReply.sse([cut], hang: true),
          ]),
          idleTimeout: const Duration(milliseconds: 60),
        ).streamChat(_request, apiKey: 'k').toList(),
      );
      expect(e4.kind, AiErrorKind.timeout);

      final e5 = await _error(
        AnthropicProvider(
          _NeverTransport(),
          responseTimeout: const Duration(milliseconds: 50),
        ).streamChat(_request, apiKey: 'k').toList(),
      );
      expect(e5.kind, AiErrorKind.timeout);
    });

    test('cancel stops the stream quietly and closes the body', () async {
      final reply = FakeReply.live();
      final t = FakeTransport([reply]);
      final cancel = AiCancelToken();
      final got = <AiStreamEvent>[];
      final done = Completer<void>();
      Object? error;
      final sub = AnthropicProvider(t)
          .streamChat(_request, apiKey: 'k', cancel: cancel)
          .listen(got.add, onError: (Object e) => error = e, onDone: done.complete);
      reply.controller!.add(utf8.encode(anthropicSse(['part']).split('event: content_block_stop').first));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(got.whereType<AiTextDelta>().map((e) => e.text), ['part']);
      cancel.cancel();
      await sub.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(error, isNull);
      expect(t.bodiesCancelled, 1);
      expect(got.whereType<AiStreamDone>(), isEmpty);
    });

    test('list models and test key (GET /v1/models with the same headers)', () async {
      final t = FakeTransport([
        FakeReply.json({
          'data': [
            {
              'id': 'claude-opus-5-5',
              'display_name': 'Claude Opus 5.5',
              'created_at': '2026-09-01T00:00:00Z',
              'type': 'model',
            },
            {'id': 'claude-haiku-4-5-20251001', 'display_name': 'Claude Haiku 4.5', 'type': 'model'},
          ],
          'has_more': false,
        }),
        FakeReply.json({'data': <Object>[]}),
        FakeReply.json({
          'type': 'error',
          'error': {'type': 'authentication_error', 'message': 'invalid x-api-key'},
        }, status: 401),
      ]);
      final p = AnthropicProvider(t);
      final models = await p.listModels(apiKey: 'KEY');
      expect(models.map((m) => m.id), ['claude-opus-5-5', 'claude-haiku-4-5-20251001']);
      expect(models.first.displayName, 'Claude Opus 5.5');
      expect(t.requests.first.method, 'GET');
      expect(t.requests.first.url.path, '/v1/models');
      expect(t.requests.first.headers['x-api-key'], 'KEY');
      await p.testKey('KEY');
      expect(t.requests[1].url.queryParameters['limit'], '1');
      expect((await _error(p.testKey('BAD'))).kind, AiErrorKind.badKey);
    });
  });

  group('OpenAI', () {
    test('request: endpoint, bearer auth, system first, max_completion_tokens', () {
      final r = OpenAiProvider(FakeTransport()).chatRequest(_openAiRequest(), apiKey: 'KEY');
      expect(r.url.toString(), 'https://api.openai.com/v1/chat/completions');
      expect(r.headers['authorization'], 'Bearer KEY');
      final body = jsonDecode(r.body!) as Map;
      expect(body['model'], 'gpt-6.1-sol');
      expect(body['stream'], true);
      expect(body['stream_options'], {'include_usage': true});
      expect(body['max_completion_tokens'], 1024);
      expect(body.containsKey('max_tokens'), isFalse);
      expect(body.containsKey('temperature'), isFalse);
      expect(body['messages'], [
        {'role': 'system', 'content': 'SYSTEM'},
        {'role': 'user', 'content': 'Hi'},
      ]);
      final withT = OpenAiProvider(FakeTransport()).chatRequest(_openAiRequest(temperature: 0.5), apiKey: 'k');
      expect((jsonDecode(withT.body!) as Map)['temperature'], 0.5);
    });

    test('streams deltas, usage chunk and [DONE]', () async {
      final t = FakeTransport([
        FakeReply.sse(chunked(openAiSse(['Sal', 'aam ', '٣']), 11)),
      ]);
      final events = await OpenAiProvider(t).streamChat(_openAiRequest(), apiKey: 'k').toList();
      expect(events.whereType<AiTextDelta>().map((e) => e.text).join(), 'Salaam ٣');
      final done = events.last as AiStreamDone;
      expect(done.reason, AiStopReason.endTurn);
      expect(done.inputTokens, 30);
      expect(done.outputTokens, 12);
    });

    test('length / content filter; a finished stream without [DONE] still completes', () async {
      final t = FakeTransport([
        FakeReply.sse([
          openAiSse(['a'], finish: 'length'),
        ]),
        FakeReply.sse([
          openAiSse(['b'], finish: 'content_filter', done: false),
        ]),
      ]);
      final p = OpenAiProvider(t);
      expect(
        ((await p.streamChat(_openAiRequest(), apiKey: 'k').toList()).last as AiStreamDone).reason,
        AiStopReason.maxTokens,
      );
      expect(
        ((await p.streamChat(_openAiRequest(), apiKey: 'k').toList()).last as AiStreamDone).reason,
        AiStopReason.contentFilter,
      );
    });

    test('errors: bad key, quota vs rate limit, model not found, temperature, mid-stream error', () async {
      Future<AiException> run(int status, Map<String, Object?> error) => _error(
        OpenAiProvider(
          FakeTransport([
            FakeReply.json({'error': error}, status: status),
          ]),
        ).streamChat(_openAiRequest(), apiKey: testOpenAiKey).toList(),
      );
      final bad = await run(401, {
        'message': 'Incorrect API key provided: sk-proj-****QRST. You can find your API key at …',
        'type': 'invalid_request_error',
        'code': 'invalid_api_key',
      });
      expect(bad.kind, AiErrorKind.badKey);
      expect(bad.detail, isNot(contains('sk-proj')));
      expect(
        (await run(429, {'message': 'Rate limit reached', 'type': 'requests', 'code': 'rate_limit_exceeded'})).kind,
        AiErrorKind.rateLimited,
      );
      expect(
        (await run(429, {
          'message': 'You exceeded your current quota',
          'type': 'insufficient_quota',
          'code': 'insufficient_quota',
        })).kind,
        AiErrorKind.quotaExceeded,
      );
      expect(
        (await run(404, {
          'message': 'The model `gpt-9` does not exist',
          'type': 'invalid_request_error',
          'code': 'model_not_found',
        })).kind,
        AiErrorKind.modelNotFound,
      );
      expect(
        (await run(400, {
          'message': "Unsupported value: 'temperature' does not support 0.2 with this model. Only the default (1) value is supported.",
          'type': 'invalid_request_error',
          'param': 'temperature',
          'code': 'unsupported_value',
        })).kind,
        AiErrorKind.temperatureUnsupported,
      );
      expect(
        (await run(400, {
          'message': 'maximum context length is 400000 tokens',
          'code': 'context_length_exceeded',
        })).kind,
        AiErrorKind.contextTooLong,
      );
      expect((await run(503, {'message': 'The engine is currently overloaded'})).kind, AiErrorKind.overloaded);

      final mid = await _error(
        OpenAiProvider(
          FakeTransport([
            FakeReply.sse(['data: {"error": {"message": "The server had an error", "type": "server_error"}}\n\n']),
          ]),
        ).streamChat(_openAiRequest(), apiKey: 'k').toList(),
      );
      expect(mid.kind, AiErrorKind.serverError);
    });

    test('list models keeps chat models only, newest first', () async {
      final t = FakeTransport([
        FakeReply.json({
          'object': 'list',
          'data': [
            {'id': 'gpt-5.6-terra', 'object': 'model', 'created': 1780000000, 'owned_by': 'openai'},
            {'id': 'text-embedding-3-large', 'object': 'model', 'created': 1790000000},
            {'id': 'gpt-6.1-sol', 'object': 'model', 'created': 1790000001},
            {'id': 'gpt-realtime-2.1', 'object': 'model', 'created': 1790000002},
            {'id': 'o4-mini', 'object': 'model', 'created': 1740000000},
            {'id': 'whisper-1', 'object': 'model', 'created': 1690000000},
          ],
        }),
      ]);
      final models = await OpenAiProvider(t).listModels(apiKey: 'k');
      expect(models.map((m) => m.id), ['gpt-6.1-sol', 'gpt-5.6-terra', 'o4-mini']);
      expect(t.requests.single.headers['authorization'], 'Bearer k');
    });
  });

  group('IoAiTransport over a local server (real dart:io HttpClient)', () {
    late HttpServer server;
    late Uri base;
    final seen = <HttpRequest>[];
    final bodies = <String>[];
    late Future<void> Function(HttpRequest r) handler;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      base = Uri.parse('http://${server.address.host}:${server.port}');
      seen.clear();
      bodies.clear();
      server.listen((r) async {
        seen.add(r);
        bodies.add(await utf8.decodeStream(r));
        await handler(r);
      });
    });

    tearDown(() => server.close(force: true));

    test('streams SSE chunk by chunk and sends the exact body and headers', () async {
      handler = (r) async {
        r.response.headers.contentType = ContentType('text', 'event-stream', charset: 'utf-8');
        r.response.bufferOutput = false;
        for (final c in chunked(anthropicSse(['مرحبًا', ' بك', ' 2026']), 23)) {
          r.response.add(utf8.encode(c));
          await r.response.flush();
        }
        await r.response.close();
      };
      final p = AnthropicProvider(IoAiTransport.loopbackForTesting(), baseUrl: base);
      final text = await _text(p.streamChat(_request, apiKey: 'LOCAL-KEY'));
      expect(text, 'مرحبًا بك 2026');
      expect(seen.single.method, 'POST');
      expect(seen.single.uri.path, '/v1/messages');
      expect(seen.single.headers.value('x-api-key'), 'LOCAL-KEY');
      expect(seen.single.headers.value('anthropic-version'), '2023-06-01');
      expect(bodies.single, p.chatRequest(_request, apiKey: 'LOCAL-KEY').body);
    });

    test('error status is read and mapped', () async {
      handler = (r) async {
        r.response.statusCode = 401;
        r.response.write(
          jsonEncode({
            'error': {'message': 'Incorrect API key', 'code': 'invalid_api_key'},
          }),
        );
        await r.response.close();
      };
      final e = await _error(
        OpenAiProvider(IoAiTransport.loopbackForTesting(), baseUrl: base).streamChat(_openAiRequest(), apiKey: 'x').toList(),
      );
      expect(e.kind, AiErrorKind.badKey);
    });

    test('cancel mid-stream closes the connection', () async {
      var stop = false;
      handler = (r) async {
        r.response.headers.contentType = ContentType('text', 'event-stream');
        r.response.bufferOutput = false;
        r.response.add(utf8.encode(anthropicSse(['first']).split('event: content_block_stop').first));
        await r.response.flush();
        // Keep the stream open (as a thinking model would) until the test ends.
        try {
          while (!stop) {
            await Future<void>.delayed(const Duration(milliseconds: 20));
            r.response.add(utf8.encode(': keep-alive\n\n'));
            await r.response.flush();
          }
        } catch (_) {}
      };
      addTearDown(() => stop = true);
      final cancel = AiCancelToken();
      final got = <String>[];
      final sub = AnthropicProvider(IoAiTransport.loopbackForTesting(), baseUrl: base)
          .streamChat(_request, apiKey: 'k', cancel: cancel)
          .listen((e) {
            if (e is AiTextDelta) got.add(e.text);
          });
      while (got.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(server.connectionsInfo().total, 1);
      cancel.cancel();
      await sub.cancel().timeout(const Duration(seconds: 2));
      // The server sees the connection go away.
      final deadline = DateTime.now().add(const Duration(seconds: 8));
      while (server.connectionsInfo().total > 0 && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      stop = true;
      expect(server.connectionsInfo().total, 0);
      expect(got, ['first']);
    });

    test('network off: nothing listening maps to a network error', () async {
      final dead = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = dead.port;
      await dead.close();
      final e = await _error(
        AnthropicProvider(
          IoAiTransport.loopbackForTesting(),
          baseUrl: Uri.parse('http://127.0.0.1:$port'),
        ).streamChat(_request, apiKey: 'k').toList(),
      );
      expect(e.kind, AiErrorKind.network);
      handler = (_) async {};
    });
  });
}

class _NeverTransport implements AiTransport {
  @override
  Future<AiHttpResponse> send(AiHttpRequest request, {AiCancelToken? cancel}) => Completer<AiHttpResponse>().future;
}
