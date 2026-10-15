/// Anthropic's Messages API (https://api.anthropic.com/v1/messages) with
/// server-sent-event streaming.
library;

import 'dart:convert';

import '../domain/ai_models.dart';
import 'ai_provider.dart';
import 'sse.dart';
import 'transport.dart';

class AnthropicProvider extends HttpAiProvider {
  AnthropicProvider(super.transport, {super.responseTimeout, super.idleTimeout, Uri? baseUrl})
    : baseUrl = baseUrl ?? Uri.parse('https://api.anthropic.com');

  static const String apiVersion = '2023-06-01';

  final Uri baseUrl;

  @override
  AiProviderId get id => AiProviderId.anthropic;

  Map<String, String> _headers(String apiKey) => {
    'x-api-key': apiKey,
    'anthropic-version': apiVersion,
    'content-type': 'application/json',
  };

  @override
  AiHttpRequest chatRequest(AiRequest request, {required String apiKey}) {
    final body = <String, Object?>{
      'model': request.model,
      'max_tokens': request.maxTokens,
      'system': request.system,
      'messages': [
        for (final m in request.messages) {'role': m.role.name, 'content': m.text},
      ],
      'stream': true,
      if (request.temperature != null) 'temperature': request.temperature,
    };
    return AiHttpRequest(
      method: 'POST',
      url: baseUrl.resolve('/v1/messages'),
      headers: {..._headers(apiKey), 'accept': 'text/event-stream'},
      body: jsonEncode(body),
    );
  }

  @override
  AiHttpRequest modelsRequest(String apiKey, {int? limit}) => AiHttpRequest(
    method: 'GET',
    url: baseUrl.resolve('/v1/models').replace(queryParameters: {'limit': '${limit ?? 100}'}),
    headers: _headers(apiKey)..remove('content-type'),
  );

  @override
  List<AiModelInfo> parseModels(Object? json) {
    final data = json is Map ? json['data'] : null;
    if (data is! List) throw const AiException(AiErrorKind.badResponse);
    return [
      for (final m in data)
        if (m is Map && m['id'] is String)
          AiModelInfo(
            m['id'] as String,
            displayName: m['display_name'] is String ? m['display_name'] as String : null,
            createdAt: m['created_at'] is String ? DateTime.tryParse(m['created_at'] as String) : null,
          ),
    ];
  }

  @override
  AiErrorBody errorBody(Object? json) {
    final error = json is Map ? json['error'] : null;
    if (error is! Map) return (type: null, code: null, message: null);
    final type = error['type'], message = error['message'];
    return (type: type is String ? type : null, code: null, message: message is String ? message : null);
  }

  @override
  Iterable<AiStreamEvent> onEvent(SseEvent event, AiStreamState state) sync* {
    final json = HttpAiProvider.jsonOf(event);
    if (json == null) return;
    final type = json['type'] ?? event.event;
    switch (type) {
      case 'message_start':
        final usage = _map(_map(json['message'])?['usage']);
        state.inputTokens = _int(usage?['input_tokens']) ?? state.inputTokens;
      case 'content_block_delta':
        final delta = _map(json['delta']);
        if (delta?['type'] == 'text_delta') {
          final text = delta?['text'];
          if (text is String && text.isNotEmpty) yield AiTextDelta(text);
        }
      case 'message_delta':
        final delta = _map(json['delta']);
        final reason = delta?['stop_reason'];
        if (reason is String) state.stopReason = stopReasonOf(reason);
        state.outputTokens = _int(_map(json['usage'])?['output_tokens']) ?? state.outputTokens;
      case 'message_stop':
        yield AiStreamDone(
          reason: state.stopReason ?? AiStopReason.endTurn,
          inputTokens: state.inputTokens,
          outputTokens: state.outputTokens,
        );
      case 'error':
        throw mapStreamError(errorBody(json));
      default:
      // ping, content_block_start/stop, thinking deltas, future events.
    }
  }

  static AiStopReason stopReasonOf(String reason) => switch (reason) {
    'end_turn' || 'stop_sequence' => AiStopReason.endTurn,
    'max_tokens' || 'model_context_window_exceeded' => AiStopReason.maxTokens,
    'refusal' => AiStopReason.refusal,
    _ => AiStopReason.other,
  };

  static Map<String, Object?>? _map(Object? v) => v is Map ? v.cast<String, Object?>() : null;

  static int? _int(Object? v) => v is num ? v.toInt() : null;
}
