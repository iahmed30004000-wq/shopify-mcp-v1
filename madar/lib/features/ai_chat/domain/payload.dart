/// Builds the exact request of the next AI call from a conversation – the
/// same object feeds the "will send" strip, the "What will be sent" view
/// and the call itself, so what the user sees is what goes out. Pure Dart.
library;

import 'package:meta/meta.dart';

import '../../data/domain/ai_summary.dart' show AiSummary;
import 'ai_models.dart';
import 'ai_settings.dart';
import 'conversation.dart';
import 'system_prompt.dart';

/// The next call, ready to review.
@immutable
class AiPayload {
  const AiPayload({required this.request, required this.historyCount, required this.omittedCount});

  final AiRequest request;

  /// Messages that go out (the new one included).
  final int historyCount;

  /// Older messages left out to keep the request small.
  final int omittedCount;

  /// Rough size of everything that goes out.
  int get approxTokens {
    var n = AiSummary.estimateTokens(request.system);
    for (final m in request.messages) {
      n += AiSummary.estimateTokens(m.text) + 4;
    }
    return n;
  }
}

abstract final class AiPayloadBuilder {
  /// Most past messages sent with a new one.
  static const int maxHistoryMessages = 30;

  /// Rough token budget of the past messages (the context is extra).
  static const int historyTokenBudget = 24000;

  /// The request for the next call.
  ///
  /// With [pendingText] it is a new user message; without it, the reply to
  /// the conversation's last user message is (re)generated – any assistant
  /// messages after it are left out.
  static AiPayload build({
    required Conversation conversation,
    required AiSettings settings,
    required String languageCode,
    String? pendingText,
  }) {
    final turns = <AiTurn>[];
    final source = conversation.messages.where((m) => m.isHistory).toList();
    if (pendingText == null) {
      // Regenerate / retry: drop everything after the last user message.
      final lastUser = source.lastIndexWhere((m) => m.isUser);
      if (lastUser >= 0) source.removeRange(lastUser + 1, source.length);
    }
    for (final m in source) {
      _add(turns, AiTurn(m.role, m.text));
    }
    if (pendingText != null && pendingText.trim().isNotEmpty) {
      _add(turns, AiTurn(ChatRole.user, pendingText.trim()));
    }

    // Keep the newest turns within the limits; always start with the user.
    var start = turns.length;
    var budget = historyTokenBudget;
    while (start > 0 && turns.length - start < maxHistoryMessages) {
      final cost = AiSummary.estimateTokens(turns[start - 1].text) + 4;
      if (start < turns.length && cost > budget) break;
      budget -= cost;
      start--;
    }
    while (start < turns.length && turns[start].role != ChatRole.user) {
      start++;
    }
    final kept = turns.sublist(start);
    final provider = settings.provider;
    return AiPayload(
      request: AiRequest(
        provider: provider,
        model: settings.modelFor(provider),
        system: AiSystemPrompt.build(languageCode: languageCode, context: conversation.context),
        messages: List.unmodifiable(kept),
        maxTokens: settings.maxTokens,
        temperature: settings.temperature,
      ),
      historyCount: kept.length,
      omittedCount: start,
    );
  }

  /// Consecutive turns of one role are merged (both services expect
  /// alternating turns).
  static void _add(List<AiTurn> turns, AiTurn t) {
    if (turns.isNotEmpty && turns.last.role == t.role) {
      turns[turns.length - 1] = AiTurn(t.role, '${turns.last.text}\n\n${t.text}');
    } else {
      turns.add(t);
    }
  }
}
