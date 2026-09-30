/// Provider-neutral types of the AI chat: what goes out (an [AiRequest]),
/// what streams back ([AiStreamEvent]) and what can go wrong
/// ([AiException] with an [AiErrorKind]). Pure Dart.
library;

import 'package:meta/meta.dart';

/// The AI services the user can bring their own key for.
enum AiProviderId {
  anthropic,
  openai;

  static AiProviderId? tryParse(Object? name) {
    for (final p in values) {
      if (p.name == name) return p;
    }
    return null;
  }
}

/// Who wrote a chat turn.
enum ChatRole { user, assistant }

/// One turn of the conversation as sent to the model.
@immutable
class AiTurn {
  const AiTurn(this.role, this.text);

  final ChatRole role;
  final String text;

  @override
  bool operator ==(Object other) => other is AiTurn && other.role == role && other.text == text;

  @override
  int get hashCode => Object.hash(role, text);

  @override
  String toString() => 'AiTurn(${role.name}, ${text.length} chars)';
}

/// Everything a provider needs for one streamed reply – and nothing else
/// (the API key travels separately and is never part of this object).
@immutable
class AiRequest {
  const AiRequest({
    required this.provider,
    required this.model,
    required this.system,
    required this.messages,
    required this.maxTokens,
    this.temperature,
  });

  final AiProviderId provider;
  final String model;

  /// Instructions plus the personal context the user approved.
  final String system;

  /// Alternating turns, first and last from the user.
  final List<AiTurn> messages;
  final int maxTokens;

  /// Null = the model's default (newer models accept nothing else).
  final double? temperature;
}

/// Why a reply ended.
enum AiStopReason {
  /// The model finished.
  endTurn,

  /// The reply hit the max-tokens limit.
  maxTokens,

  /// The model declined to answer.
  refusal,

  /// The provider's content filter stopped the reply.
  contentFilter,

  /// Any other reason.
  other,
}

/// An event of a streamed reply.
@immutable
sealed class AiStreamEvent {
  const AiStreamEvent();
}

/// The next piece of reply text.
final class AiTextDelta extends AiStreamEvent {
  const AiTextDelta(this.text);

  final String text;
}

/// The reply is complete.
final class AiStreamDone extends AiStreamEvent {
  const AiStreamDone({this.reason = AiStopReason.endTurn, this.inputTokens, this.outputTokens});

  final AiStopReason reason;
  final int? inputTokens;
  final int? outputTokens;
}

/// What went wrong, in terms the user can act on.
enum AiErrorKind {
  /// No key saved for the provider.
  noKey,

  /// The key was rejected (401).
  badKey,

  /// The key may not use this model / region (403).
  forbidden,

  /// Too many requests right now (429).
  rateLimited,

  /// Out of credit / spend limit / billing problem.
  quotaExceeded,

  /// The service is busy (529 / 503 / overloaded_error).
  overloaded,

  /// The service failed (5xx).
  serverError,

  /// The model id does not exist or is not available to this key.
  modelNotFound,

  /// The model refuses a custom temperature.
  temperatureUnsupported,

  /// The conversation is too long for the model.
  contextTooLong,

  /// Any other rejected request (400).
  badRequest,

  /// No connection / DNS / TLS failure / connection dropped.
  network,

  /// No answer in time.
  timeout,

  /// The service answered with something unreadable.
  badResponse,

  /// Anything else.
  unknown,
}

/// A failed AI call. [detail] is the provider's message with anything that
/// looks like a key removed; it is shown, never stored or logged.
class AiException implements Exception {
  const AiException(this.kind, {this.statusCode, this.detail, this.retryAfter});

  final AiErrorKind kind;
  final int? statusCode;
  final String? detail;

  /// From a `retry-after` header, when the service sent one.
  final Duration? retryAfter;

  /// Worth offering "Try again" (the user still decides).
  bool get retryable => switch (kind) {
    AiErrorKind.rateLimited ||
    AiErrorKind.overloaded ||
    AiErrorKind.serverError ||
    AiErrorKind.network ||
    AiErrorKind.timeout ||
    AiErrorKind.badResponse ||
    AiErrorKind.unknown => true,
    _ => false,
  };

  // Deliberately without [detail]: exception text can reach crash reports.
  @override
  String toString() => 'AiException(${kind.name}${statusCode == null ? '' : ', HTTP $statusCode'})';
}

/// A model offered by a provider's "list models" endpoint.
@immutable
class AiModelInfo {
  const AiModelInfo(this.id, {this.displayName, this.createdAt});

  final String id;
  final String? displayName;
  final DateTime? createdAt;

  Map<String, Object?> toJson() => {
    'id': id,
    if (displayName != null) 'name': displayName,
    if (createdAt != null) 'created': createdAt!.toUtc().toIso8601String(),
  };

  static AiModelInfo? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    if (id is! String || id.isEmpty) return null;
    final name = json['name'];
    final created = json['created'];
    return AiModelInfo(
      id,
      displayName: name is String ? name : null,
      createdAt: created is String ? DateTime.tryParse(created) : null,
    );
  }

  @override
  bool operator ==(Object other) => other is AiModelInfo && other.id == id && other.displayName == displayName;

  @override
  int get hashCode => Object.hash(id, displayName);
}

/// Removes secrets from text that may be shown to the user (provider error
/// messages sometimes echo part of the key).
abstract final class AiRedactor {
  static final RegExp _keyLike = RegExp(r'(sk-[A-Za-z0-9_\-*.]{4,}|[A-Za-z0-9_\-]{40,})');

  static String redact(String text, {Iterable<String> secrets = const []}) {
    var out = text;
    for (final s in secrets) {
      if (s.length >= 4) out = out.replaceAll(s, '••••');
    }
    return out.replaceAll(_keyLike, '••••');
  }
}
