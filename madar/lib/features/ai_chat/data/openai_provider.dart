/// OpenAI's Chat Completions API (https://api.openai.com/v1/chat/completions)
/// with server-sent-event streaming.
library;

import 'dart:convert';

import '../domain/ai_models.dart';
import 'ai_provider.dart';
import 'sse.dart';
import 'transport.dart';

class OpenAiProvider extends HttpAiProvider {
  OpenAiProvider(super.transport, {super.responseTimeout, super.idleTimeout, Uri? baseUrl})
    : baseUrl = baseUrl ?? Uri.parse('https://api.openai.com');

  final Uri baseUrl;

  @override
  AiProviderId get id => AiProviderId.openai;

  @override
  AiHttpRequest chatRequest(AiRequest request, {required String apiKey}) {
    final body = <String, Object?>{
      'model': request.model,
      'messages': [
        {'role': 'system', 'content': request.system},
        for (final m in request.messages) {'role': m.role.name, 'content': m.text},
      ],
      'stream': true,
      'stream_options': {'include_usage': true},
      'max_completion_tokens': request.maxTokens,
      if (request.temperature != null) 'temperature': request.temperature,
    };
    return AiHttpRequest(
      method: 'POST',
      url: baseUrl.resolve('/v1/chat/completions'),
      headers: {'authorization': 'Bearer $apiKey', 'content-type': 'application/json', 'accept': 'text/event-stream'},
      body: jsonEncode(body),
    );
  }

  @override
  AiHttpRequest modelsRequest(String apiKey, {int? limit}) =>
      AiHttpRequest(method: 'GET', url: baseUrl.resolve('/v1/models'), headers: {'authorization': 'Bearer $apiKey'});

  /// Model ids that can't chat (audio, images, embeddings …).
  static final RegExp _notChat = RegExp(
    r'(audio|realtime|tts|transcribe|whisper|image|dall-e|embedding|moderation|search|instruct|computer-use|sora|babbage|davinci)',
  );
  static final RegExp _chatFamily = RegExp(r'^(gpt-|chatgpt-|o\d)');

  /// Whether [id] looks like a chat model.
  static bool isChatModel(String id) => _chatFamily.hasMatch(id) && !_notChat.hasMatch(id);

  @override
  List<AiModelInfo> parseModels(Object? json) {
    final data = json is Map ? json['data'] : null;
    if (data is! List) throw const AiException(AiErrorKind.badResponse);
    final list = <AiModelInfo>[
      for (final m in data)
        if (m is Map && m['id'] is String && isChatModel(m['id'] as String))
          AiModelInfo(
            m['id'] as String,
            createdAt: m['created'] is num
                ? DateTime.fromMillisecondsSinceEpoch((m['created'] as num).toInt() * 1000, isUtc: true)
                : null,
          ),
    ];
    list.sort((a, b) {
      final c = (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0));
      return c != 0 ? c : a.id.compareTo(b.id);
    });
    return list;
  }

  @override
  AiErrorBody errorBody(Object? json) {
    final error = json is Map ? json['error'] : null;
    if (error is! Map) return (type: null, code: null, message: null);
    final type = error['type'], code = error['code'], message = error['message'];
    return (
      type: type is String ? type : null,
      code: code is String ? code : null,
      message: message is String ? message : null,
    );
  }

  @override
  Iterable<AiStreamEvent> onEvent(SseEvent event, AiStreamState state) sync* {
    if (event.data.trim() == '[DONE]') {
      yield AiStreamDone(
        reason: state.stopReason ?? AiStopReason.endTurn,
        inputTokens: state.inputTokens,
        outputTokens: state.outputTokens,
      );
      return;
    }
    final json = HttpAiProvider.jsonOf(event);
    if (json == null) return;
    if (json['error'] is Map) throw mapStreamError(errorBody(json));
    final usage = json['usage'];
    if (usage is Map) {
      if (usage['prompt_tokens'] is num) state.inputTokens = (usage['prompt_tokens'] as num).toInt();
      if (usage['completion_tokens'] is num) state.outputTokens = (usage['completion_tokens'] as num).toInt();
    }
    final choices = json['choices'];
    if (choices is! List || choices.isEmpty || choices.first is! Map) return;
    final choice = choices.first as Map;
    final delta = choice['delta'];
    if (delta is Map) {
      final content = delta['content'];
      if (content is String && content.isNotEmpty) yield AiTextDelta(content);
      final refusal = delta['refusal'];
      if (refusal is String && refusal.isNotEmpty) {
        state.stopReason = AiStopReason.refusal;
        yield AiTextDelta(refusal);
      }
    }
    final finish = choice['finish_reason'];
    if (finish is String) {
      state.stopReason = state.stopReason == AiStopReason.refusal ? AiStopReason.refusal : stopReasonOf(finish);
    }
  }

  static AiStopReason stopReasonOf(String reason) => switch (reason) {
    'stop' => AiStopReason.endTurn,
    'length' => AiStopReason.maxTokens,
    'content_filter' => AiStopReason.contentFilter,
    _ => AiStopReason.other,
  };
}
