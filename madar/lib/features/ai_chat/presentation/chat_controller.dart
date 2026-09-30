/// One conversation's state and its calls. Every call starts from an
/// explicit user action ([send], [regenerate], [retry]) and only once the
/// user has decided what personal context goes out – nothing here runs on
/// a timer, on load or in the background.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/ai_chat_providers.dart' show AiProviderRegistry;
import '../data/ai_provider.dart';
import '../data/conversation_store.dart';
import '../data/key_store.dart';
import '../data/transport.dart';
import '../domain/ai_models.dart';
import '../domain/ai_settings.dart';
import '../domain/conversation.dart';
import '../domain/payload.dart';

/// Why Send can't go ahead right now.
enum SendBlock {
  /// Nothing to send.
  empty,

  /// A reply is still arriving.
  busy,

  /// No key for the selected service.
  noKey,

  /// The personal context hasn't been reviewed (open the preview first).
  needsContext,
}

class ChatController extends ChangeNotifier {
  ChatController({
    required this.store,
    required this.providers,
    required this.keys,
    required this.clock,
    required this.newId,
    this.conversationId,
  });

  final ConversationStore store;
  final AiProviderRegistry providers;
  final AiKeyStore keys;
  final DateTime Function() clock;
  final String Function() newId;
  /// The stored conversation to open (null = a new chat).
  final String? conversationId;

  Conversation? _conversation;
  bool _loading = true;
  bool _disposed = false;
  bool _missing = false;

  String? _streamingId;
  AiCancelToken? _cancel;
  StreamSubscription<AiStreamEvent>? _sub;
  StringBuffer? _buffer;
  AiException? _lastError;
  Future<void> _saving = Future.value();

  /// The conversation (a fresh, unsaved one for a new chat).
  Conversation get conversation => _conversation ??= _fresh();

  bool get loading => _loading;

  /// The conversation id was given but it no longer exists.
  bool get missing => _missing;

  /// A reply is arriving.
  bool get busy => _streamingId != null;

  /// The message being written, if any.
  String? get streamingId => _streamingId;

  /// The last failure with its (redacted) provider detail – shown, never
  /// stored.
  AiException? get lastError => _lastError;

  Conversation _fresh() {
    final now = clock();
    return Conversation(id: newId(), createdAt: now, updatedAt: now);
  }

  Future<void> load() async {
    final id = conversationId;
    if (id != null) {
      try {
        final c = await store.load(id);
        if (c == null) {
          _missing = true;
        } else {
          _conversation = c;
        }
      } catch (_) {
        _missing = true;
      }
    }
    _loading = false;
    _notify();
  }

  /// Chooses what personal context goes out with this conversation.
  void setContext(ChatContext context) {
    if (conversation.context == context) return;
    if (conversation.context.isPersonal) _previousPersonal = conversation.context;
    _conversation = conversation.copyWith(context: context);
    _persist();
    _notify();
  }

  ChatContext? _previousPersonal;

  /// "No personal context" on / off. Off brings back the summary approved
  /// earlier in this session, else the preview opens at the next Send.
  void setNoContext(bool none, {required DateTime now}) {
    if (none) {
      setContext(ChatContext.none(approvedAt: now));
    } else if (conversation.context.mode == ContextMode.none) {
      setContext(_previousPersonal ?? const ChatContext());
    }
  }

  /// Why Send is blocked right now (null = it may go ahead).
  SendBlock? blockFor(String text, {required bool hasKey}) {
    if (busy) return SendBlock.busy;
    if (text.trim().isEmpty) return SendBlock.empty;
    if (!hasKey) return SendBlock.noKey;
    if (!conversation.context.isDecided) return SendBlock.needsContext;
    return null;
  }

  /// What the next Send would send (for the strip and "What will be sent").
  AiPayload payloadFor(AiSettings settings, String languageCode, {String? draft}) => AiPayloadBuilder.build(
    conversation: conversation,
    settings: settings,
    languageCode: languageCode,
    pendingText: draft,
  );

  /// What Regenerate / Try again would send.
  AiPayload? replayPayload(AiSettings settings, String languageCode) {
    if (!conversation.messages.any((m) => m.isUser && m.isHistory)) return null;
    final p = payloadFor(settings, languageCode);
    return p.request.messages.isEmpty ? null : p;
  }

  /// Whether the last reply can be regenerated.
  bool get canRegenerate {
    if (busy) return false;
    final last = conversation.lastMessage;
    return last != null && !last.isUser && conversation.messages.any((m) => m.isUser && m.isHistory);
  }

  /// Sends [text] – the user tapped Send. Returns false (and sends nothing)
  /// when the context isn't decided, there's no key or a reply is running.
  Future<bool> send(String text, {required AiSettings settings, required String languageCode}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || busy || !conversation.context.isDecided) return false;
    final key = await _key(settings.provider);
    if (key == null) return false;
    final payload = payloadFor(settings, languageCode, draft: trimmed);
    final now = clock();
    _conversation = conversation.append(
      ChatMessage(id: newId(), role: ChatRole.user, text: trimmed, createdAt: now),
      now: now,
    );
    _start(payload.request, key, settings);
    return true;
  }

  /// Writes the last reply again – the user tapped Regenerate.
  Future<bool> regenerate({required AiSettings settings, required String languageCode}) async {
    if (busy || !conversation.context.isDecided) return false;
    final lastUser = conversation.messages.lastIndexWhere((m) => m.isUser && m.isHistory);
    if (lastUser < 0) return false;
    final key = await _key(settings.provider);
    if (key == null) return false;
    // Drop the replies after the last question.
    final kept = conversation.messages.sublist(0, lastUser + 1);
    _conversation = conversation.copyWith(messages: kept, updatedAt: clock());
    final payload = payloadFor(settings, languageCode);
    if (payload.request.messages.isEmpty) return false;
    _start(payload.request, key, settings);
    return true;
  }

  /// Tries a failed reply again – the user tapped Try again.
  Future<bool> retry({required AiSettings settings, required String languageCode}) =>
      regenerate(settings: settings, languageCode: languageCode);

  /// Stops the reply – the user tapped Stop. What arrived is kept.
  void stop() {
    if (!busy) return;
    _cancel?.cancel();
    final sub = _sub;
    _sub = null;
    unawaited(sub?.cancel());
    _finish(MessageStatus.stopped);
  }

  void clearError() {
    if (_lastError == null) return;
    _lastError = null;
    _notify();
  }

  Future<String?> _key(AiProviderId p) async {
    try {
      final key = await keys.read(p);
      if (key != null) return key;
    } catch (_) {}
    _lastError = const AiException(AiErrorKind.noKey);
    _notify();
    return null;
  }

  void _start(AiRequest request, String apiKey, AiSettings settings) {
    _lastError = null;
    final id = newId();
    _streamingId = id;
    _buffer = StringBuffer();
    _conversation = conversation.append(
      ChatMessage(
        id: id,
        role: ChatRole.assistant,
        text: '',
        createdAt: clock(),
        status: MessageStatus.streaming,
        provider: request.provider,
        model: request.model,
      ),
      now: clock(),
    );
    _persist();
    _notify();

    final cancel = _cancel = AiCancelToken();
    final Stream<AiStreamEvent> stream;
    try {
      stream = providers[request.provider].streamChat(request, apiKey: apiKey, cancel: cancel);
    } catch (e) {
      _fail(HttpAiProvider.mapTransportError(e));
      return;
    }
    _sub = stream.listen(
      (event) {
        if (_streamingId != id) return;
        switch (event) {
          case AiTextDelta(:final text):
            _buffer!.write(text);
            _update(id, (m) => m.copyWith(text: _buffer.toString()));
          case AiStreamDone(:final reason):
            _sub = null;
            _finish(MessageStatus.complete, stopReason: reason);
        }
      },
      onError: (Object e, StackTrace _) {
        if (_streamingId != id) return;
        _sub = null;
        if (e is AiCancelledException || cancel.isCancelled) {
          _finish(MessageStatus.stopped);
        } else {
          _fail(e is AiException ? e : HttpAiProvider.mapTransportError(e));
        }
      },
      onDone: () {
        if (_streamingId != id) return;
        _sub = null;
        _finish(cancel.isCancelled ? MessageStatus.stopped : MessageStatus.complete);
      },
      cancelOnError: true,
    );
  }

  void _update(String id, ChatMessage Function(ChatMessage m) change) {
    final m = conversation.messages.where((x) => x.id == id).firstOrNull;
    if (m == null) return;
    _conversation = conversation.replace(change(m));
    _notify();
  }

  void _fail(AiException e) {
    _lastError = e;
    _finish(MessageStatus.failed, error: e.kind);
  }

  void _finish(MessageStatus status, {AiStopReason? stopReason, AiErrorKind? error}) {
    final id = _streamingId;
    if (id == null) return;
    _streamingId = null;
    _cancel = null;
    final text = _buffer?.toString() ?? '';
    _buffer = null;
    final m = conversation.messages.where((x) => x.id == id).firstOrNull;
    if (m != null) {
      if (status == MessageStatus.stopped && text.trim().isEmpty) {
        // Stopped before anything arrived: nothing to keep.
        _conversation = conversation.remove(id, now: clock());
      } else {
        _conversation = conversation.replace(
          m.copyWith(text: text, status: status, error: () => error, stopReason: () => stopReason),
          now: clock(),
        );
      }
    }
    _persist();
    _notify();
  }

  /// Renames the conversation (the user's choice wins over the automatic
  /// title from then on).
  void rename(String title) {
    final clean = Conversation.cleanTitle(title);
    if (clean.isEmpty || clean == conversation.title) return;
    _conversation = conversation.copyWith(title: clean, titleEdited: true);
    _persist();
    _notify();
  }

  bool _discarded = false;

  /// The conversation is being deleted: stop any reply and never save
  /// again (so a late save can't bring it back).
  Future<void> discard() async {
    _discarded = true;
    if (busy) {
      _cancel?.cancel();
      final sub = _sub;
      _sub = null;
      unawaited(sub?.cancel());
      _streamingId = null;
      _buffer = null;
    }
    await _saving;
  }

  void _persist() {
    if (_discarded) return;
    final snapshot = conversation;
    _saving = _saving.then((_) async {
      try {
        await store.save(snapshot);
      } catch (_) {}
    });
  }

  /// Completes when every pending save is written (tests).
  Future<void> flush() => _saving;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    // Leaving the screen stops the reply (never continues in the background).
    stop();
    _disposed = true;
    super.dispose();
  }
}
