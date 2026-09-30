/// Conversations and messages of the AI chat, with the bounds that keep
/// the stored history small. Stored as JSON in the encrypted database.
/// Pure Dart.
library;

import 'package:meta/meta.dart';

import '../../data/domain/ai_summary.dart' show SummarySectionId;
import 'ai_models.dart';
import 'markdown.dart';

/// State of a message.
enum MessageStatus {
  /// Finished normally.
  complete,

  /// The reply is still arriving (never stored as such).
  streaming,

  /// The user tapped Stop; the text is what had arrived.
  stopped,

  /// The call failed; see [ChatMessage.error].
  failed,
}

@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
    this.status = MessageStatus.complete,
    this.error,
    this.stopReason,
    this.provider,
    this.model,
  });

  final String id;
  final ChatRole role;
  final String text;
  final DateTime createdAt;
  final MessageStatus status;

  /// Why the reply failed (only the kind is stored, never provider text).
  final AiErrorKind? error;
  final AiStopReason? stopReason;

  /// Which service and model wrote an assistant reply.
  final AiProviderId? provider;
  final String? model;

  bool get isUser => role == ChatRole.user;

  /// Counts as conversation history for the next request.
  bool get isHistory => text.trim().isNotEmpty && status != MessageStatus.failed && status != MessageStatus.streaming;

  ChatMessage copyWith({
    String? text,
    MessageStatus? status,
    AiErrorKind? Function()? error,
    AiStopReason? Function()? stopReason,
  }) => ChatMessage(
    id: id,
    role: role,
    text: text ?? this.text,
    createdAt: createdAt,
    status: status ?? this.status,
    error: error != null ? error() : this.error,
    stopReason: stopReason != null ? stopReason() : this.stopReason,
    provider: provider,
    model: model,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'role': role.name,
    'text': text.length > Conversation.maxMessageChars ? text.substring(0, Conversation.maxMessageChars) : text,
    'at': createdAt.toUtc().toIso8601String(),
    if (status != MessageStatus.complete)
      'status': (status == MessageStatus.streaming ? MessageStatus.stopped : status).name,
    if (error != null) 'error': error!.name,
    if (stopReason != null) 'stop': stopReason!.name,
    if (provider != null) 'provider': provider!.name,
    'model': ?model,
  };

  static ChatMessage? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'], role = json['role'], text = json['text'], at = json['at'];
    if (id is! String || text is! String || at is! String) return null;
    final r = ChatRole.values.where((x) => x.name == role).firstOrNull;
    final created = DateTime.tryParse(at);
    if (r == null || created == null) return null;
    T? byName<T extends Enum>(List<T> values, Object? name) => values.where((x) => x.name == name).firstOrNull;
    final model = json['model'];
    return ChatMessage(
      id: id,
      role: r,
      text: text,
      createdAt: created.toLocal(),
      status: byName(MessageStatus.values, json['status']) ?? MessageStatus.complete,
      error: byName(AiErrorKind.values, json['error']),
      stopReason: byName(AiStopReason.values, json['stop']),
      provider: AiProviderId.tryParse(json['provider']),
      model: model is String ? model : null,
    );
  }
}

/// How the conversation uses the user's Madar summary.
enum ContextMode {
  /// Not decided yet: the first Send opens the summary preview.
  unset,

  /// The approved summary goes out as context.
  personal,

  /// No personal context at all.
  none,
}

/// The personal context of a conversation: the exact Markdown the user
/// approved in the summary preview (or none).
@immutable
class ChatContext {
  const ChatContext({this.mode = ContextMode.unset, this.markdown, this.approvedAt});

  const ChatContext.none({this.approvedAt}) : mode = ContextMode.none, markdown = null;

  const ChatContext.personal(String this.markdown, {this.approvedAt}) : mode = ContextMode.personal;

  final ContextMode mode;

  /// Exactly what the preview returned (sent byte for byte).
  final String? markdown;
  final DateTime? approvedAt;

  /// The user has decided what goes out (a Send may proceed).
  bool get isDecided => mode == ContextMode.none || (mode == ContextMode.personal && (markdown?.isNotEmpty ?? false));

  bool get isPersonal => mode == ContextMode.personal && (markdown?.isNotEmpty ?? false);

  /// The `## ` section headings of [markdown], in order.
  List<String> get sectionTitles => sectionTitlesOf(markdown ?? '');

  static List<String> sectionTitlesOf(String markdown) => [
    for (final line in markdown.split('\n'))
      if (line.startsWith('## ') && line.substring(3).trim().isNotEmpty) line.substring(3).trim(),
  ];

  /// Maps the headings to summary sections using the localised [titles]
  /// (null for a heading that matches none – e.g. after a language switch).
  static List<SummarySectionId?> sectionIdsOf(List<String> headings, Map<SummarySectionId, String> titles) => [
    for (final h in headings) titles.entries.where((e) => e.value == h).map((e) => e.key).firstOrNull,
  ];

  Map<String, Object?> toJson() => {
    'mode': mode.name,
    if (isPersonal) 'markdown': markdown,
    if (approvedAt != null) 'approvedAt': approvedAt!.toUtc().toIso8601String(),
  };

  static ChatContext fromJson(Object? json) {
    if (json is! Map) return const ChatContext();
    final mode = ContextMode.values.where((m) => m.name == json['mode']).firstOrNull ?? ContextMode.unset;
    final md = json['markdown'];
    final at = json['approvedAt'];
    final approved = at is String ? DateTime.tryParse(at)?.toLocal() : null;
    return switch (mode) {
      ContextMode.personal when md is String && md.isNotEmpty => ChatContext.personal(md, approvedAt: approved),
      ContextMode.none => ChatContext.none(approvedAt: approved),
      _ => const ChatContext(),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is ChatContext && other.mode == mode && other.markdown == markdown && other.approvedAt == approvedAt;

  @override
  int get hashCode => Object.hash(mode, markdown, approvedAt);
}

/// A conversation with its (bounded) messages.
@immutable
class Conversation {
  const Conversation({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.title = '',
    this.titleEdited = false,
    this.messages = const [],
    this.context = const ChatContext(),
  });

  /// Most messages kept per conversation (oldest dropped first).
  static const int maxMessages = 120;

  /// Longest stored message text.
  static const int maxMessageChars = 24000;

  /// Longest title.
  static const int maxTitleChars = 80;

  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Empty until the first message (then derived from it) or a rename.
  final String title;
  final bool titleEdited;
  final List<ChatMessage> messages;
  final ChatContext context;

  bool get isEmpty => messages.isEmpty;

  ChatMessage? get lastMessage => messages.isEmpty ? null : messages.last;

  /// A title from the first user message: one line, at most 48 characters.
  static String titleFrom(String text) {
    final line = text.trim().split('\n').first.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (line.length <= 48) return line;
    final cut = line.substring(0, 48);
    final space = cut.lastIndexOf(' ');
    return '${(space > 24 ? cut.substring(0, space) : cut).trimRight()}…';
  }

  static String cleanTitle(String raw) {
    final t = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    return t.length > maxTitleChars ? t.substring(0, maxTitleChars).trimRight() : t;
  }

  Conversation copyWith({
    String? title,
    bool? titleEdited,
    List<ChatMessage>? messages,
    ChatContext? context,
    DateTime? updatedAt,
  }) => Conversation(
    id: id,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    title: title ?? this.title,
    titleEdited: titleEdited ?? this.titleEdited,
    messages: messages ?? this.messages,
    context: context ?? this.context,
  );

  /// Appends [m], keeping at most [maxMessages] (oldest dropped) and
  /// deriving the title from the first user message.
  Conversation append(ChatMessage m, {required DateTime now}) {
    var list = [...messages, m];
    if (list.length > maxMessages) list = list.sublist(list.length - maxMessages);
    final autoTitle = !titleEdited && title.isEmpty && m.isUser ? titleFrom(m.text) : null;
    return copyWith(messages: list, updatedAt: now, title: autoTitle);
  }

  /// Replaces the message with [m.id].
  Conversation replace(ChatMessage m, {DateTime? now}) =>
      copyWith(messages: [for (final x in messages) x.id == m.id ? m : x], updatedAt: now);

  /// Removes the message with [id].
  Conversation remove(String id, {DateTime? now}) => copyWith(
    messages: [
      for (final x in messages)
        if (x.id != id) x,
    ],
    updatedAt: now,
  );

  Map<String, Object?> toJson() {
    final list = messages.length > maxMessages ? messages.sublist(messages.length - maxMessages) : messages;
    return {
      'v': 1,
      'id': id,
      'title': title,
      if (titleEdited) 'titleEdited': true,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'context': context.toJson(),
      'messages': [
        for (final m in list)
          if (m.status != MessageStatus.streaming || m.text.isNotEmpty) m.toJson(),
      ],
    };
  }

  static Conversation? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'], created = json['createdAt'], updated = json['updatedAt'];
    if (id is! String || created is! String || updated is! String) return null;
    final c = DateTime.tryParse(created), u = DateTime.tryParse(updated);
    if (c == null || u == null) return null;
    final raw = json['messages'];
    final msgs = <ChatMessage>[
      if (raw is List)
        for (final m in raw) ?ChatMessage.fromJson(m),
    ];
    final title = json['title'];
    return Conversation(
      id: id,
      createdAt: c.toLocal(),
      updatedAt: u.toLocal(),
      title: title is String ? cleanTitle(title) : '',
      titleEdited: json['titleEdited'] == true,
      messages: msgs.length > maxMessages ? msgs.sublist(msgs.length - maxMessages) : msgs,
      context: ChatContext.fromJson(json['context']),
    );
  }
}

/// A row of the conversation list (kept in a small index so the list never
/// loads every conversation).
@immutable
class ConversationMeta {
  const ConversationMeta({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.messageCount,
    this.preview = '',
  });

  factory ConversationMeta.of(Conversation c) {
    final last = c.lastMessage;
    final text = last == null ? '' : MdParser.plainText(last.text);
    return ConversationMeta(
      id: c.id,
      title: c.title,
      updatedAt: c.updatedAt,
      messageCount: c.messages.length,
      preview: text.length > 120 ? '${text.substring(0, 120)}…' : text,
    );
  }

  final String id;
  final String title;
  final DateTime updatedAt;
  final int messageCount;

  /// Start of the latest message (plain text).
  final String preview;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'count': messageCount,
    'preview': preview,
  };

  static ConversationMeta? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'], updated = json['updatedAt'];
    if (id is! String || updated is! String) return null;
    final u = DateTime.tryParse(updated);
    if (u == null) return null;
    final title = json['title'], count = json['count'], preview = json['preview'];
    return ConversationMeta(
      id: id,
      title: title is String ? title : '',
      updatedAt: u.toLocal(),
      messageCount: count is int ? count : 0,
      preview: preview is String ? preview : '',
    );
  }
}
