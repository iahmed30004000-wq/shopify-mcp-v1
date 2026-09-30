import 'dart:convert';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/encryption.dart';
import 'package:madar/features/ai_chat/ai_chat.dart';
import 'package:madar/features/ai_chat/domain/system_prompt.dart';
import 'package:madar/features/ai_chat/presentation/ai_labels.dart';
import 'package:madar/features/data/data.dart' show SummarySectionId;

final _t0 = DateTime(2026, 9, 30, 9);

ChatMessage _msg(String id, ChatRole role, String text, {MessageStatus status = MessageStatus.complete, int minute = 0}) =>
    ChatMessage(id: id, role: role, text: text, createdAt: _t0.add(Duration(minutes: minute)), status: status);

Conversation _conv({List<ChatMessage> messages = const [], ChatContext context = const ChatContext(), String id = 'c1'}) =>
    Conversation(id: id, createdAt: _t0, updatedAt: _t0, messages: messages, context: context);

void main() {
  group('Conversation', () {
    test('keeps at most maxMessages (oldest dropped) and titles itself from the first question', () {
      var c = _conv();
      for (var i = 0; i < Conversation.maxMessages + 15; i++) {
        c = c.append(_msg('m$i', i.isEven ? ChatRole.user : ChatRole.assistant, 'message $i'), now: _t0);
      }
      expect(c.messages.length, Conversation.maxMessages);
      expect(c.messages.first.id, 'm15');
      expect(c.title, 'message 0');
    });

    test('title: one line, at most 48 characters, cut at a word', () {
      expect(Conversation.titleFrom('  كيف أحسّن ميزانيتي\nهذا الشهر؟ '), 'كيف أحسّن ميزانيتي');
      final long = Conversation.titleFrom('Please help me plan a balanced tomorrow with prayer, work and family time');
      expect(long.length, lessThanOrEqualTo(49));
      expect(long, endsWith('…'));
      expect(long, isNot(contains('  ')));
    });

    test('JSON round trip; a streaming message is stored as stopped; long text is capped', () {
      final c = _conv(
        messages: [
          _msg('a', ChatRole.user, 'سؤال'),
          ChatMessage(
            id: 'b',
            role: ChatRole.assistant,
            text: 'x' * (Conversation.maxMessageChars + 50),
            createdAt: _t0,
            status: MessageStatus.streaming,
            provider: AiProviderId.openai,
            model: 'gpt-6.1-sol',
          ),
          ChatMessage(
            id: 'c',
            role: ChatRole.assistant,
            text: '',
            createdAt: _t0,
            status: MessageStatus.failed,
            error: AiErrorKind.rateLimited,
          ),
        ],
        context: ChatContext.personal('## Faith\n\n- x', approvedAt: _t0),
      ).copyWith(title: 'T');
      final back = Conversation.fromJson(jsonDecode(jsonEncode(c.toJson())))!;
      expect(back.title, 'T');
      expect(back.messages.map((m) => m.id), ['a', 'b', 'c']);
      expect(back.messages[1].status, MessageStatus.stopped);
      expect(back.messages[1].text.length, Conversation.maxMessageChars);
      expect(back.messages[1].provider, AiProviderId.openai);
      expect(back.messages[2].error, AiErrorKind.rateLimited);
      expect(back.context.markdown, '## Faith\n\n- x');
      expect(back.context.isPersonal, isTrue);
    });

    test('ChatContext: decided states and section headings', () {
      expect(const ChatContext().isDecided, isFalse);
      expect(const ChatContext.none().isDecided, isTrue);
      expect(const ChatContext.personal('').isDecided, isFalse);
      const md = '# Madar\n\nintro\n\n## Faith\n\n- a\n\n## المال\n\n- b\n### not a section';
      const ctx = ChatContext.personal(md);
      expect(ctx.sectionTitles, ['Faith', 'المال']);
      expect(ChatContext.sectionIdsOf(ctx.sectionTitles, {SummarySectionId.faith: 'Faith', SummarySectionId.money: 'Money'}), [
        SummarySectionId.faith,
        null,
      ]);
      expect(ChatContext.fromJson(ctx.toJson()), ctx);
      expect(ChatContext.fromJson({'mode': 'personal'}), const ChatContext());
    });
  });

  group('Payload', () {
    const settings = AiSettings();

    test('system prompt carries exactly the approved summary; none carries nothing personal', () {
      const md = '# Summary\n\n## Health\n\n- Pain: 3/10 average';
      final p = AiPayloadBuilder.build(
        conversation: _conv(context: const ChatContext.personal(md)),
        settings: settings,
        languageCode: 'ar',
        pendingText: 'كيف حالي؟',
      );
      final system = p.request.system;
      expect(system, contains('${AiSystemPrompt.contextStart}\n$md\n${AiSystemPrompt.contextEnd}'));
      expect(system, contains('If it is unclear, reply in Arabic'));
      expect(system, contains('Never give a medical diagnosis'));
      expect(system, contains('concise'));
      expect(p.request.messages, const [AiTurn(ChatRole.user, 'كيف حالي؟')]);
      expect(p.request.model, 'claude-sonnet-5-5');
      expect(p.request.maxTokens, AiSettings.defaultMaxTokens);
      expect(p.request.temperature, isNull);

      final none = AiPayloadBuilder.build(
        conversation: _conv(context: const ChatContext.none()),
        settings: settings,
        languageCode: 'en',
        pendingText: 'Hi',
      );
      expect(none.request.system, isNot(contains(AiSystemPrompt.contextStart)));
      expect(none.request.system, contains('chose not to share personal context'));
      expect(none.request.system, contains('reply in English'));
    });

    test('history: failed replies left out, same-role turns merged, starts with the user', () {
      final c = _conv(
        messages: [
          _msg('0', ChatRole.assistant, 'orphan greeting'),
          _msg('1', ChatRole.user, 'q1'),
          _msg('2', ChatRole.assistant, '', status: MessageStatus.failed),
          _msg('3', ChatRole.user, 'q2'),
          _msg('4', ChatRole.assistant, 'a2', status: MessageStatus.stopped),
        ],
        context: const ChatContext.none(),
      );
      final p = AiPayloadBuilder.build(conversation: c, settings: settings, languageCode: 'en', pendingText: 'q3');
      expect(p.request.messages, const [
        AiTurn(ChatRole.user, 'q1\n\nq2'),
        AiTurn(ChatRole.assistant, 'a2'),
        AiTurn(ChatRole.user, 'q3'),
      ]);
      expect(p.historyCount, 3);
      expect(p.omittedCount, 1);
      expect(p.approxTokens, greaterThan(0));
    });

    test('regenerate: replies after the last question are dropped', () {
      final c = _conv(
        messages: [
          _msg('1', ChatRole.user, 'q1'),
          _msg('2', ChatRole.assistant, 'a1'),
          _msg('3', ChatRole.user, 'q2'),
          _msg('4', ChatRole.assistant, 'a2'),
        ],
        context: const ChatContext.none(),
      );
      final p = AiPayloadBuilder.build(conversation: c, settings: settings, languageCode: 'en');
      expect(p.request.messages.last, const AiTurn(ChatRole.user, 'q2'));
      expect(p.request.messages.length, 3);
    });

    test('bounded: at most maxHistoryMessages and the token budget', () {
      final many = [
        for (var i = 0; i < 80; i++) _msg('$i', i.isEven ? ChatRole.user : ChatRole.assistant, 'turn $i'),
      ];
      final p = AiPayloadBuilder.build(
        conversation: _conv(messages: many, context: const ChatContext.none()),
        settings: settings,
        languageCode: 'en',
        pendingText: 'last',
      );
      expect(p.request.messages.length, lessThanOrEqualTo(AiPayloadBuilder.maxHistoryMessages));
      expect(p.request.messages.first.role, ChatRole.user);
      expect(p.request.messages.last.text, 'last');
      expect(p.omittedCount, greaterThan(0));

      final huge = [
        _msg('0', ChatRole.user, 'a' * 200000),
        _msg('1', ChatRole.assistant, 'b'),
      ];
      final q = AiPayloadBuilder.build(
        conversation: _conv(messages: huge, context: const ChatContext.none()),
        settings: settings,
        languageCode: 'en',
        pendingText: 'short',
      );
      expect(q.request.messages, const [AiTurn(ChatRole.user, 'short')]);
    });

    test('provider, model, max tokens and temperature follow the settings', () {
      final s = const AiSettings()
          .copyWith(provider: AiProviderId.openai, maxTokens: 8192, temperature: () => 0.4)
          .selectModel(AiProviderId.openai, 'gpt-6-astra');
      final p = AiPayloadBuilder.build(conversation: _conv(context: const ChatContext.none()), settings: s, languageCode: 'en', pendingText: 'x');
      expect(p.request.provider, AiProviderId.openai);
      expect(p.request.model, 'gpt-6-astra');
      expect(p.request.maxTokens, 8192);
      expect(p.request.temperature, 0.4);
    });
  });

  group('AiSettings', () {
    test('defaults, editable list, custom ids, reset, JSON', () {
      const s = AiSettings();
      expect(s.modelsFor(AiProviderId.anthropic), [
        'claude-opus-5-5',
        'claude-sonnet-5-5',
        'claude-haiku-4-5-20251001',
        'claude-fable-5-1',
      ]);
      expect(s.model, 'claude-sonnet-5-5');
      final custom = s.selectModel(AiProviderId.anthropic, '  claude-new-6  ');
      expect(custom.model, 'claude-new-6');
      expect(custom.modelsFor(AiProviderId.anthropic).last, 'claude-new-6');
      expect(s.selectModel(AiProviderId.anthropic, 'bad id!'), s);
      expect(AiSettings.cleanModelId('x' * 121), isNull);
      final removed = custom.removeModel(AiProviderId.anthropic, 'claude-new-6');
      expect(removed.model, 'claude-opus-5-5');
      expect(removed.modelsFor(AiProviderId.anthropic), isNot(contains('claude-new-6')));
      expect(custom.resetModels(AiProviderId.anthropic).model, 'claude-sonnet-5-5');
      final fetched = custom.withFetched(AiProviderId.anthropic, const [AiModelInfo('claude-new-6', displayName: 'Claude New 6')]);
      final back = AiSettings.fromJson(jsonDecode(jsonEncode(fetched.toJson())));
      expect(back, fetched);
      expect(back.displayNameOf(AiProviderId.anthropic, 'claude-new-6'), 'Claude New 6');
      expect(AiSettings.fromJson({'maxTokens': 999999, 'temperature': 3}).maxTokens, AiSettings.defaultMaxTokens);
      expect(AiSettings.fromJson({'temperature': 3}).temperature, 1.0);
      // The list never goes empty.
      var one = const AiSettings();
      for (final m in AiSettings.defaultModels[AiProviderId.openai]!) {
        one = one.removeModel(AiProviderId.openai, m);
      }
      expect(one.modelsFor(AiProviderId.openai).length, 1);
    });

    test('model labels', () {
      expect(aiModelLabel('claude-sonnet-5-5'), 'Claude Sonnet 5.5');
      expect(aiModelLabel('claude-haiku-4-5-20251001'), 'Claude Haiku 4.5');
      expect(aiModelLabel('claude-opus-5'), 'Claude Opus 5');
      expect(aiModelLabel('gpt-6.1-sol'), 'GPT-6.1 Sol');
      expect(aiModelLabel('gpt-5.5'), 'GPT-5.5');
      expect(aiModelLabel('o4-mini'), 'o4-mini');
      expect(aiModelLabel('x', displayName: 'Nice'), 'Nice');
    });
  });

  group('Keys', () {
    test('clean, check, mask', () {
      expect(AiKeyStore.clean('  "sk-ant-abc123456789012345678"\n'), 'sk-ant-abc123456789012345678');
      expect(AiKeyStore.clean('ANTHROPIC_API_KEY=sk-ant-x'), 'sk-ant-x');
      expect(AiKeyStore.clean('Bearer sk-proj-1'), 'sk-proj-1');
      expect(AiKeyStore.check(AiProviderId.anthropic, ''), AiKeyProblem.empty);
      expect(AiKeyStore.check(AiProviderId.anthropic, 'sk-ant-short'), AiKeyProblem.tooShort);
      expect(AiKeyStore.check(AiProviderId.anthropic, 'sk-ant-abc 123456789012345678'), AiKeyProblem.spaces);
      expect(AiKeyStore.check(AiProviderId.anthropic, testKeyOpenAi), AiKeyProblem.wrongProvider);
      expect(AiKeyStore.check(AiProviderId.openai, testKeyAnthropic), AiKeyProblem.wrongProvider);
      expect(AiKeyStore.check(AiProviderId.anthropic, testKeyAnthropic), isNull);
      expect(AiKeyStore.mask(testKeyAnthropic), '••••WXYZ');
      expect(AiKeyStore.hintOf(testKeyAnthropic), 'WXYZ');
    });

    test('stored only in secure storage, under a per-service entry', () async {
      final secrets = MemorySecretStore();
      final store = AiKeyStore(secrets);
      await store.save(AiProviderId.anthropic, '  $testKeyAnthropic\n');
      expect(secrets.values, {AiKeyStore.storageKey(AiProviderId.anthropic): testKeyAnthropic});
      expect(await store.hint(AiProviderId.anthropic), 'WXYZ');
      expect(await store.has(AiProviderId.openai), isFalse);
      await expectLater(store.save(AiProviderId.openai, 'short'), throwsArgumentError);
      try {
        await store.save(AiProviderId.openai, 'short key with spaces that is long enough');
      } on ArgumentError catch (e) {
        expect(e.toString(), isNot(contains('short key')));
      }
      await store.deleteAll();
      expect(secrets.values, isEmpty);
    });
  });

  group('Health mentions', () {
    test('Arabic and English, whole words only', () {
      for (final yes in [
        'Your blood pressure readings look steady.',
        'Ask your doctor about the dose.',
        'راجع طبيبك بخصوص الجرعة.',
        'سجّلت ألمًا في الركبة', // harakat and hamza folded
        'الألم خفّ هذا الأسبوع',
        'تحاليلك الأخيرة',
        'Take 500 mg daily',
      ]) {
        expect(HealthMentions.mentions(yes), isTrue, reason: yes);
      }
      for (final no in [
        'Your budget is on track.',
        'هذا صحيح تمامًا، أحسنت.',
        'Spain is a painting of a place.',
        'العالم مليء بالفرص',
        'تحليل الميزانية يظهر فائضًا',
      ]) {
        expect(HealthMentions.mentions(no), isFalse, reason: no);
      }
    });
  });

  group('ConversationStore', () {
    late MadarDatabase db;
    late ConversationStore store;

    setUp(() async {
      db = MadarDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
      store = ConversationStore(db);
    });
    tearDown(() => db.close());

    Conversation conv(int i) => Conversation(
      id: 'c$i',
      createdAt: _t0,
      updatedAt: _t0.add(Duration(minutes: i)),
      title: 'chat $i',
      messages: [_msg('m$i', ChatRole.user, 'hello $i')],
    );

    test('save, index (newest first), bounded to maxConversations', () async {
      for (var i = 0; i < ConversationStore.maxConversations + 5; i++) {
        await store.save(conv(i));
      }
      final index = await store.index();
      expect(index.length, ConversationStore.maxConversations);
      expect(index.first.id, 'c${ConversationStore.maxConversations + 4}');
      expect(index.last.id, 'c5');
      expect(await store.load('c0'), isNull, reason: 'pruned conversations are deleted');
      final rows = await db.select(db.keyValues).get();
      expect(rows.where((r) => r.key.startsWith(ConversationStore.conversationPrefix)).length, ConversationStore.maxConversations);
      expect(rows.every((r) => ConversationStore.ownsKey(r.key)), isTrue);
      expect(index.first.preview, 'hello ${ConversationStore.maxConversations + 4}');
      expect(index.first.messageCount, 1);
    });

    test('an empty conversation is not stored', () async {
      await store.save(_conv());
      expect(await store.index(), isEmpty);
    });

    test('rename, delete with undo, delete all with undo', () async {
      await store.save(conv(1));
      await store.save(conv(2));
      final renamed = await store.rename('c1', '  My   plan  ');
      expect(renamed!.title, 'My plan');
      expect(renamed.titleEdited, isTrue);
      expect((await store.index()).firstWhere((m) => m.id == 'c1').title, 'My plan');

      final removed = await store.delete('c2');
      expect((await store.index()).map((m) => m.id), ['c1']);
      await store.restore([removed!]);
      expect((await store.index()).map((m) => m.id).toSet(), {'c1', 'c2'});

      final all = await store.deleteAll();
      expect(all.length, 2);
      expect(await store.index(), isEmpty);
      expect((await db.select(db.keyValues).get()).where((r) => ConversationStore.ownsKey(r.key)), isEmpty);
      await store.restore(all);
      expect((await store.index()).length, 2);
      expect((await store.load('c1'))!.title, 'My plan');
    });

    test('watchIndex emits on change', () async {
      final seen = <int>[];
      final sub = store.watchIndex().listen((l) => seen.add(l.length));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await store.save(conv(1));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();
      expect(seen.first, 0);
      expect(seen.last, 1);
    });
  });
}

const testKeyAnthropic = 'sk-ant-api03-TESTKEY0123456789abcdefghijWXYZ';
const testKeyOpenAi = 'sk-proj-TESTKEY9876543210zyxwvutsrqpQRST';
