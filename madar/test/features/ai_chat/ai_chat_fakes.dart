// Fakes for the AI chat: a scripted HTTP transport (SSE bodies, errors,
// hangs, cancel), a scripted AiProvider and helpers that build SSE text in
// each service's format.
import 'dart:async';
import 'dart:convert';

import 'package:madar/features/ai_chat/ai_chat.dart';

/// A scripted response of [FakeTransport].
class FakeReply {
  FakeReply.sse(List<String> chunks, {this.status = 200, this.headers = const {}, this.hang = false, this.chunkDelay})
    : body = chunks,
      error = null,
      controller = null;

  FakeReply.json(Object json, {this.status = 200, this.headers = const {}})
    : body = [jsonEncode(json)],
      hang = false,
      chunkDelay = null,
      error = null,
      controller = null;

  /// The transport throws [error] instead of answering.
  FakeReply.fail(Object this.error)
    : status = 0,
      headers = const {},
      body = const [],
      hang = false,
      chunkDelay = null,
      controller = null;

  /// The body is fed by the test through [controller].
  FakeReply.live({this.status = 200})
    : headers = const {},
      body = const [],
      hang = false,
      chunkDelay = null,
      error = null,
      controller = StreamController<List<int>>();

  final int status;
  final Map<String, String> headers;
  final List<String> body;

  /// Keep the body open after the chunks (never ends by itself).
  final bool hang;
  final Duration? chunkDelay;
  final Object? error;
  final StreamController<List<int>>? controller;
}

/// Records every request; answers from a queue.
class FakeTransport implements AiTransport {
  FakeTransport([Iterable<FakeReply> replies = const []]) : queue = [...replies];

  final List<FakeReply> queue;
  final List<AiHttpRequest> requests = [];
  final List<AiCancelToken?> tokens = [];

  /// Set when a response body subscription was cancelled.
  int bodiesCancelled = 0;

  @override
  Future<AiHttpResponse> send(AiHttpRequest request, {AiCancelToken? cancel}) async {
    requests.add(request);
    tokens.add(cancel);
    if (queue.isEmpty) throw StateError('FakeTransport: no reply queued for ${request.method} ${request.url}');
    final r = queue.removeAt(0);
    if (r.error != null) throw r.error!;
    final Stream<List<int>> body;
    if (r.controller != null) {
      r.controller!.onCancel = () => bodiesCancelled++;
      body = r.controller!.stream;
    } else {
      final c = StreamController<List<int>>();
      c.onCancel = () => bodiesCancelled++;
      () async {
        for (final chunk in r.body) {
          if (c.isClosed) return;
          if (r.chunkDelay != null) await Future<void>.delayed(r.chunkDelay!);
          if (!c.isClosed) c.add(utf8.encode(chunk));
        }
        if (!r.hang && !c.isClosed) await c.close();
      }();
      body = c.stream;
    }
    return AiHttpResponse(statusCode: r.status, headers: r.headers, body: body);
  }
}

/// Anthropic SSE text for a reply made of [deltas].
String anthropicSse(List<String> deltas, {String stopReason = 'end_turn', bool thinking = false}) {
  final b = StringBuffer()
    ..write('event: message_start\n')
    ..write(
      'data: {"type":"message_start","message":{"id":"msg_1","type":"message","role":"assistant","content":[],'
      '"model":"claude-sonnet-5-5","stop_reason":null,"usage":{"input_tokens":25,"output_tokens":1}}}\n\n',
    );
  var index = 0;
  if (thinking) {
    b
      ..write(
        'event: content_block_start\ndata: {"type":"content_block_start","index":0,"content_block":{"type":"thinking","thinking":""}}\n\n',
      )
      ..write(
        'event: content_block_delta\ndata: {"type":"content_block_delta","index":0,"delta":{"type":"thinking_delta","thinking":"secret plan"}}\n\n',
      )
      ..write('event: content_block_stop\ndata: {"type":"content_block_stop","index":0}\n\n');
    index = 1;
  }
  b
    ..write('event: content_block_start\n')
    ..write('data: {"type":"content_block_start","index":$index,"content_block":{"type":"text","text":""}}\n\n')
    ..write('event: ping\ndata: {"type": "ping"}\n\n');
  for (final d in deltas) {
    b
      ..write('event: content_block_delta\n')
      ..write(
        'data: ${jsonEncode({
          'type': 'content_block_delta',
          'index': index,
          'delta': {'type': 'text_delta', 'text': d},
        })}\n\n',
      );
  }
  b
    ..write('event: content_block_stop\ndata: {"type":"content_block_stop","index":$index}\n\n')
    ..write(
      'event: message_delta\ndata: {"type":"message_delta","delta":{"stop_reason":"$stopReason","stop_sequence":null},'
      '"usage":{"output_tokens":15}}\n\n',
    )
    ..write('event: message_stop\ndata: {"type":"message_stop"}\n\n');
  return b.toString();
}

/// OpenAI Chat Completions SSE text for a reply made of [deltas].
String openAiSse(List<String> deltas, {String finish = 'stop', bool done = true}) {
  final b = StringBuffer();
  Map<String, Object?> chunk(Map<String, Object?> delta, {String? finishReason}) => {
    'id': 'chatcmpl-1',
    'object': 'chat.completion.chunk',
    'created': 1790000000,
    'model': 'gpt-6.1-sol',
    'choices': [
      {'index': 0, 'delta': delta, 'finish_reason': finishReason},
    ],
  };
  b.write('data: ${jsonEncode(chunk({'role': 'assistant', 'content': ''}))}\n\n');
  for (final d in deltas) {
    b.write('data: ${jsonEncode(chunk({'content': d}))}\n\n');
  }
  b.write('data: ${jsonEncode(chunk({}, finishReason: finish))}\n\n');
  b.write(
    'data: ${jsonEncode({
      'id': 'chatcmpl-1',
      'object': 'chat.completion.chunk',
      'choices': <Object>[],
      'usage': {'prompt_tokens': 30, 'completion_tokens': 12, 'total_tokens': 42},
    })}\n\n',
  );
  if (done) b.write('data: [DONE]\n\n');
  return b.toString();
}

/// Splits [s] into chunks of [size] characters (to cross event boundaries).
List<String> chunked(String s, int size) => [
  for (var i = 0; i < s.length; i += size) s.substring(i, i + size > s.length ? s.length : i + size),
];

/// A scripted provider: each call gets the next script (a list of events,
/// or a live controller the test feeds).
class FakeAiProvider implements AiProvider {
  FakeAiProvider(this.id);

  @override
  final AiProviderId id;

  final List<AiRequest> requests = [];
  final List<String> keysUsed = [];
  final List<Object> scripts = [];
  final List<StreamController<AiStreamEvent>> live = [];
  int modelCalls = 0;
  int testCalls = 0;
  List<AiModelInfo> models = const [AiModelInfo('claude-sonnet-5-5', displayName: 'Claude Sonnet 5.5')];
  AiException? testError;

  /// Queues a reply: `List<AiStreamEvent>`, an [AiException] (thrown after
  /// [List] events) or `'live'` (a controller the test feeds).
  void script(Object s) => scripts.add(s);

  void reply(String text, {AiStopReason reason = AiStopReason.endTurn}) =>
      script(<AiStreamEvent>[AiTextDelta(text), AiStreamDone(reason: reason)]);

  @override
  AiHttpRequest chatRequest(AiRequest request, {required String apiKey}) => id == AiProviderId.anthropic
      ? AnthropicProvider(FakeTransport()).chatRequest(request, apiKey: apiKey)
      : OpenAiProvider(FakeTransport()).chatRequest(request, apiKey: apiKey);

  @override
  Stream<AiStreamEvent> streamChat(AiRequest request, {required String apiKey, AiCancelToken? cancel}) {
    requests.add(request);
    keysUsed.add(apiKey);
    final s = scripts.isEmpty ? <AiStreamEvent>[const AiTextDelta('ok'), const AiStreamDone()] : scripts.removeAt(0);
    if (s == 'live') {
      final c = StreamController<AiStreamEvent>();
      live.add(c);
      return c.stream;
    }
    if (s is AiException) return Stream.error(s);
    return Stream.fromIterable(s as List<AiStreamEvent>);
  }

  @override
  Future<List<AiModelInfo>> listModels({required String apiKey, AiCancelToken? cancel}) async {
    modelCalls++;
    return models;
  }

  @override
  Future<void> testKey(String apiKey, {AiCancelToken? cancel}) async {
    testCalls++;
    if (testError != null) throw testError!;
  }
}

/// Both services faked.
(AiProviderRegistry, FakeAiProvider, FakeAiProvider) fakeRegistry() {
  final a = FakeAiProvider(AiProviderId.anthropic);
  final o = FakeAiProvider(AiProviderId.openai);
  return (AiProviderRegistry({AiProviderId.anthropic: a, AiProviderId.openai: o}), a, o);
}

const String testAnthropicKey = 'sk-ant-api03-TESTKEY0123456789abcdefghijWXYZ';
const String testOpenAiKey = 'sk-proj-TESTKEY9876543210zyxwvutsrqpQRST';
