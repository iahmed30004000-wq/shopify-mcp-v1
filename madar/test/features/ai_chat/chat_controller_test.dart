import 'dart:async';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/encryption.dart';
import 'package:madar/features/ai_chat/ai_chat.dart';
import 'package:madar/features/ai_chat/presentation/chat_controller.dart';

import 'ai_chat_fakes.dart';

void main() {
  late MadarDatabase db;
  late ConversationStore store;
  late MemorySecretStore secrets;
  late FakeAiProvider anthropic;
  late AiProviderRegistry registry;
  var n = 0;
  const settings = AiSettings();
  final now = DateTime(2026, 9, 30, 10);

  setUp(() {
    db = MadarDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    store = ConversationStore(db);
    secrets = MemorySecretStore({AiKeyStore.storageKey(AiProviderId.anthropic): testAnthropicKey});
    final r = fakeRegistry();
    registry = r.$1;
    anthropic = r.$2;
    n = 0;
  });
  tearDown(() => db.close());

  ChatController make({String? id}) => ChatController(
    store: store,
    providers: registry,
    keys: AiKeyStore(secrets),
    clock: () => now,
    newId: () => 'id-${n++}',
    conversationId: id,
  );

  Future<void> idle() => Future<void>.delayed(const Duration(milliseconds: 5));

  test('nothing is sent until the context is decided and Send is called', () async {
    final c = make();
    await c.load();
    expect(c.blockFor('', hasKey: true), SendBlock.empty);
    expect(c.blockFor('hi', hasKey: false), SendBlock.noKey);
    expect(c.blockFor('hi', hasKey: true), SendBlock.needsContext);
    expect(await c.send('hi', settings: settings, languageCode: 'en'), isFalse);
    expect(anthropic.requests, isEmpty);
    expect(c.conversation.messages, isEmpty);

    c.setContext(const ChatContext.personal('## Faith\n\n- 5/5'));
    expect(c.blockFor('hi', hasKey: true), isNull);
    // Building the preview or the strip never sends anything.
    c.payloadFor(settings, 'en', draft: 'hi');
    expect(anthropic.requests, isEmpty);

    expect(await c.send('hi', settings: settings, languageCode: 'en'), isTrue);
    await idle();
    expect(anthropic.requests.length, 1);
    expect(anthropic.keysUsed.single, testAnthropicKey);
    expect(anthropic.requests.single.system, contains('## Faith\n\n- 5/5'));
    expect(c.conversation.messages.map((m) => (m.role, m.text, m.status)), [
      (ChatRole.user, 'hi', MessageStatus.complete),
      (ChatRole.assistant, 'ok', MessageStatus.complete),
    ]);
    c.dispose();
  });

  test('no key: Send reports it and sends nothing', () async {
    await secrets.delete(AiKeyStore.storageKey(AiProviderId.anthropic));
    final c = make()..setContext(const ChatContext.none());
    expect(await c.send('hi', settings: settings, languageCode: 'en'), isFalse);
    expect(c.lastError?.kind, AiErrorKind.noKey);
    expect(anthropic.requests, isEmpty);
    c.dispose();
  });

  test('streams into the reply; Stop keeps what arrived; saved as stopped', () async {
    anthropic.script('live');
    final c = make()..setContext(const ChatContext.none());
    await c.send('tell me', settings: settings, languageCode: 'en');
    expect(c.busy, isTrue);
    final live = anthropic.live.single;
    live.add(const AiTextDelta('Hello'));
    await idle();
    live.add(const AiTextDelta(' there'));
    await idle();
    expect(c.conversation.messages.last.text, 'Hello there');
    expect(c.conversation.messages.last.status, MessageStatus.streaming);
    c.stop();
    expect(c.busy, isFalse);
    expect(c.conversation.messages.last.status, MessageStatus.stopped);
    expect(c.conversation.messages.last.text, 'Hello there');
    live.add(const AiTextDelta(' ignored'));
    await idle();
    expect(c.conversation.messages.last.text, 'Hello there');
    await c.flush();
    final stored = await store.load(c.conversation.id);
    expect(stored!.messages.last.status, MessageStatus.stopped);
    expect(stored.messages.last.text, 'Hello there');
    c.dispose();
  });

  test('stopped before anything arrived: the empty reply is dropped', () async {
    anthropic.script('live');
    final c = make()..setContext(const ChatContext.none());
    await c.send('q', settings: settings, languageCode: 'en');
    c.stop();
    expect(c.conversation.messages.single.isUser, isTrue);
    c.dispose();
  });

  test('failure: stored as its kind only; Try again replays the same question', () async {
    anthropic.script(const AiException(AiErrorKind.overloaded, statusCode: 529, detail: 'Overloaded'));
    final c = make()..setContext(const ChatContext.none());
    await c.send('q1', settings: settings, languageCode: 'en');
    await idle();
    final failed = c.conversation.messages.last;
    expect(failed.status, MessageStatus.failed);
    expect(failed.error, AiErrorKind.overloaded);
    expect(c.lastError?.detail, 'Overloaded');
    await c.flush();
    final json = (await store.load(c.conversation.id))!.toJson().toString();
    expect(json, isNot(contains('Overloaded')), reason: 'provider text is never stored');

    anthropic.reply('answer');
    expect(await c.retry(settings: settings, languageCode: 'en'), isTrue);
    await idle();
    expect(anthropic.requests.last.messages, const [AiTurn(ChatRole.user, 'q1')]);
    expect(c.conversation.messages.map((m) => m.text), ['q1', 'answer']);
    c.dispose();
  });

  test('regenerate replaces the last reply and keeps the history', () async {
    anthropic
      ..reply('a1')
      ..reply('a2')
      ..reply('a2 again');
    final c = make()..setContext(const ChatContext.none());
    await c.send('q1', settings: settings, languageCode: 'en');
    await idle();
    await c.send('q2', settings: settings, languageCode: 'en');
    await idle();
    expect(c.canRegenerate, isTrue);
    await c.regenerate(settings: settings, languageCode: 'en');
    await idle();
    expect(anthropic.requests.last.messages, const [
      AiTurn(ChatRole.user, 'q1'),
      AiTurn(ChatRole.assistant, 'a1'),
      AiTurn(ChatRole.user, 'q2'),
    ]);
    expect(c.conversation.messages.map((m) => m.text), ['q1', 'a1', 'q2', 'a2 again']);
    c.dispose();
  });

  test('stop reasons are kept; leaving the screen stops the reply', () async {
    anthropic.reply('long…', reason: AiStopReason.maxTokens);
    final c = make()..setContext(const ChatContext.none());
    await c.send('q', settings: settings, languageCode: 'en');
    await idle();
    expect(c.conversation.messages.last.stopReason, AiStopReason.maxTokens);

    anthropic.script('live');
    await c.send('q2', settings: settings, languageCode: 'en');
    anthropic.live.single.add(const AiTextDelta('partial'));
    await idle();
    final live = anthropic.live.single;
    c.dispose();
    expect(live.hasListener, isFalse, reason: 'the stream subscription is cancelled on dispose');
  });

  test('reopening a stored conversation; "no personal context" toggles back to the approved summary', () async {
    final c = make()..setContext(const ChatContext.personal('## Money\n\n- ok'));
    await c.send('q', settings: settings, languageCode: 'en');
    await idle();
    await c.flush();
    final id = c.conversation.id;
    c.setNoContext(true, now: now);
    expect(c.conversation.context.mode, ContextMode.none);
    c.setNoContext(false, now: now);
    expect(c.conversation.context.markdown, '## Money\n\n- ok');
    c.rename('  Budget   talk ');
    await c.flush();
    c.dispose();

    final again = make(id: id);
    await again.load();
    expect(again.conversation.title, 'Budget talk');
    expect(again.conversation.messages.length, 2);
    expect(again.conversation.context.isPersonal, isTrue);
    again.dispose();

    final gone = make(id: 'nope');
    await gone.load();
    expect(gone.missing, isTrue);
    gone.dispose();
  });

  test('discard: no late save brings a deleted conversation back', () async {
    anthropic.script('live');
    final c = make()..setContext(const ChatContext.none());
    await c.send('q', settings: settings, languageCode: 'en');
    anthropic.live.single.add(const AiTextDelta('x'));
    await idle();
    await c.discard();
    await store.delete(c.conversation.id);
    c.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(await store.index(), isEmpty);
  });
}
