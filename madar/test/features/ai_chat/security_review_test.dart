// Adversarial privacy / security review of the AI chat. Each test pins a
// problem found in review (and fixed): data sent without a tap, keys going to
// the wrong host or into exception text, deleted chats coming back, links
// that could carry the summary away, and parser edge cases.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/encryption.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/ai_chat/ai_chat.dart';
import 'package:madar/features/ai_chat/data/sse.dart';
import 'package:madar/features/ai_chat/domain/system_prompt.dart';
import 'package:madar/features/ai_chat/presentation/chat_controller.dart';
import 'package:madar/features/ai_chat/presentation/widgets/key_sheet.dart';
import 'package:madar/features/ai_chat/presentation/widgets/markdown_view.dart';
import 'package:madar/features/ai_chat/presentation/widgets/message_bubble.dart';
import 'package:madar/features/data/data/data_repository.dart';
import 'package:madar/features/data/domain/ai_summary.dart';
import 'package:madar/features/data/domain/ai_summary_builder.dart';

import '../data/data_fixtures.dart';
import 'ai_chat_fakes.dart';
import 'ai_chat_harness.dart';

const _anthropicRequest = AiRequest(
  provider: AiProviderId.anthropic,
  model: 'claude-sonnet-5-5',
  system: 'SYSTEM',
  messages: [AiTurn(ChatRole.user, 'Hi')],
  maxTokens: 1024,
);

const _openAiRequest = AiRequest(
  provider: AiProviderId.openai,
  model: 'gpt-6.1-sol',
  system: 'SYSTEM',
  messages: [AiTurn(ChatRole.user, 'Hi')],
  maxTokens: 1024,
);

Future<AiException> _aiError(Future<Object?> f) async {
  try {
    await f;
  } on AiException catch (e) {
    return e;
  }
  fail('expected an AiException');
}

/// Secure storage whose reads wait for [gate] (a slow Keystore).
class _SlowSecrets implements SecretStore {
  _SlowSecrets(this.inner);

  final SecretStore inner;
  Completer<void> gate = Completer<void>();

  @override
  Future<String?> read(String key) async {
    await gate.future;
    return inner.read(key);
  }

  @override
  Future<void> write(String key, String value) => inner.write(key, value);

  @override
  Future<void> delete(String key) => inner.delete(key);

  @override
  Future<void> forceClear() => inner.forceClear();
}

/// An HttpClient that records where it would connect and never does.
HttpClient _recordingClient(List<Uri> attempts) =>
    HttpClient()
      ..connectionFactory = (uri, proxyHost, proxyPort) {
        attempts.add(uri);
        return Future.error(const SocketException('test: no network'));
      };

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('network: TLS, host allow-list, key ↔ host binding', () {
    test('the production transport refuses anything but https to the two API hosts', () async {
      for (final url in [
        'http://api.anthropic.com/v1/messages',
        'https://evil.example/v1/messages',
        'https://api.anthropic.com.evil.example/v1/messages',
        'https://api.openai.com:8443/v1/chat/completions',
        'https://user:pw@api.openai.com/v1/chat/completions',
      ]) {
        final attempts = <Uri>[];
        final transport = IoAiTransport(createClient: () => _recordingClient(attempts));
        Object? error;
        try {
          await transport.send(AiHttpRequest(method: 'GET', url: Uri.parse(url)));
        } catch (e) {
          error = e;
        }
        expect(attempts, isEmpty, reason: '$url must not even be dialled');
        expect(error, isA<AiHostNotAllowedException>(), reason: url);
      }
    });

    test('an Anthropic key never goes to OpenAI and the reverse', () {
      AiHttpRequest req(String url, Map<String, String> headers) =>
          AiHttpRequest(method: 'POST', url: Uri.parse(url), headers: headers);
      expect(AiHostPolicy.check(req('https://api.openai.com/v1/chat/completions', {'x-api-key': 'k'})), isFalse);
      expect(AiHostPolicy.check(req('https://api.anthropic.com/v1/messages', {'authorization': 'Bearer k'})), isFalse);
      expect(AiHostPolicy.check(req('https://api.anthropic.com/v1/messages', {'X-Api-Key': 'k'})), isTrue);
      expect(AiHostPolicy.check(req('https://api.anthropic.com./v1/messages', const {})), isFalse);
      expect(AiHostPolicy.check(req('https://api.anthropic.com/v1/messages#x', const {})), isFalse);
      // What the real providers build passes.
      final a = AnthropicProvider(FakeTransport()).chatRequest(_anthropicRequest, apiKey: testAnthropicKey);
      final o = OpenAiProvider(FakeTransport()).chatRequest(_openAiRequest, apiKey: testOpenAiKey);
      final am = AnthropicProvider(FakeTransport()).modelsRequest(testAnthropicKey);
      final om = OpenAiProvider(FakeTransport()).modelsRequest(testOpenAiKey);
      for (final r in [a, o, am, om]) {
        expect(AiHostPolicy.check(r), isTrue, reason: '${r.url}');
      }
      // The default (production) transport provider uses the policy.
      expect(AiProviderRegistry.http(IoAiTransport())[AiProviderId.anthropic], isA<AnthropicProvider>());
    });

    test('a key of the other service is refused before any request (chat, test key, models)', () async {
      final t = FakeTransport();
      final anthropic = AnthropicProvider(t);
      final openai = OpenAiProvider(t);
      expect((await _aiError(anthropic.streamChat(_anthropicRequest, apiKey: testOpenAiKey).toList())).kind,
          AiErrorKind.badKey);
      expect((await _aiError(openai.streamChat(_openAiRequest, apiKey: testAnthropicKey).toList())).kind,
          AiErrorKind.badKey);
      expect((await _aiError(anthropic.testKey(testOpenAiKey))).kind, AiErrorKind.badKey);
      expect((await _aiError(openai.listModels(apiKey: testAnthropicKey))).kind, AiErrorKind.badKey);
      expect(t.requests, isEmpty, reason: 'nothing was sent to the wrong service');
    });

    test('a key with an invisible or non-ASCII character is refused locally, never echoed', () async {
      final t = FakeTransport();
      const bad = 'sk-ant-api03-SECRETKEYabcdefghijkl\u200f';
      final e = await _aiError(AnthropicProvider(t).streamChat(_anthropicRequest, apiKey: bad).toList());
      expect(e.kind, AiErrorKind.badKey);
      expect(t.requests, isEmpty);
      expect(e.toString(), isNot(contains('SECRETKEY')));
    });

    test('the transport never puts a header value (the key) into exception text', () async {
      final attempts = <Uri>[];
      final transport = IoAiTransport(createClient: () => _recordingClient(attempts));
      Object? error;
      try {
        await transport.send(
          AiHttpRequest(
            method: 'GET',
            url: Uri.parse('https://api.anthropic.com/v1/models'),
            headers: const {'x-api-key': 'sk-ant-api03-SECRETKEY\u0661'},
          ),
        );
      } catch (e) {
        error = e;
      }
      expect(error, isA<AiInvalidHeaderException>());
      expect(error.toString(), isNot(contains('SECRETKEY')));
      expect(attempts, isEmpty, reason: 'refused before connecting');
    });
  });

  group('key store', () {
    test('a pasted key loses invisible direction marks, zero-width spaces and BOMs', () {
      expect(AiKeyStore.clean('\u200e$testAnthropicKey\u200f'), testAnthropicKey);
      expect(AiKeyStore.clean('\ufeff\u200b$testOpenAiKey\u2069'), testOpenAiKey);
      expect(AiKeyStore.clean('\u2066"$testOpenAiKey"\u2069'), testOpenAiKey);
    });

    test('a key with characters no key has is refused', () {
      expect(AiKeyStore.check(AiProviderId.anthropic, 'sk-ant-api03-abcdefghijklmno\u0661'), AiKeyProblem.invalidChars);
      expect(AiKeyStore.check(AiProviderId.anthropic, 'sk-ant-api03-abcdefghijklmnoé'), AiKeyProblem.invalidChars);
      expect(AiKeyStore.check(AiProviderId.openai, testAnthropicKey), AiKeyProblem.wrongProvider);
      expect(AiKeyStore.check(AiProviderId.anthropic, testAnthropicKey), isNull);
    });

    test('a key of the other service is not saved (it would be sent to the wrong company)', () async {
      final secrets = MemorySecretStore();
      final keys = AiKeyStore(secrets);
      await expectLater(keys.save(AiProviderId.anthropic, testOpenAiKey), throwsArgumentError);
      await expectLater(keys.save(AiProviderId.openai, testAnthropicKey), throwsArgumentError);
      expect(secrets.values, isEmpty);
      // The thrown text never carries the key.
      try {
        await keys.save(AiProviderId.anthropic, testOpenAiKey);
      } catch (e) {
        expect(e.toString(), isNot(contains('TESTKEY')));
      }
    });
  });

  group('controller: a call only on an explicit tap, never twice, never after leaving', () {
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

    ChatController make({SecretStore? keys, ConversationStore? on}) => ChatController(
      store: on ?? store,
      providers: registry,
      keys: AiKeyStore(keys ?? secrets),
      clock: () => now,
      newId: () => 'id-${n++}',
    );

    Future<void> idle() => Future<void>.delayed(const Duration(milliseconds: 5));

    test('a double tap on Send sends once', () async {
      anthropic.script('live');
      final c = make()..setContext(const ChatContext.none());
      final results = await Future.wait([
        c.send('hi', settings: settings, languageCode: 'en'),
        c.send('hi', settings: settings, languageCode: 'en'),
      ]);
      expect(results.where((ok) => ok), hasLength(1));
      expect(anthropic.requests, hasLength(1));
      expect(c.conversation.messages.where((m) => m.isUser), hasLength(1));
      c.dispose();
      expect(anthropic.live.every((l) => !l.hasListener), isTrue, reason: 'no orphaned stream keeps running');
    });

    test('a double tap on Regenerate sends once', () async {
      anthropic
        ..reply('a1')
        ..script('live')
        ..script('live');
      final c = make()..setContext(const ChatContext.none());
      await c.send('q', settings: settings, languageCode: 'en');
      await idle();
      await Future.wait([
        c.regenerate(settings: settings, languageCode: 'en'),
        c.regenerate(settings: settings, languageCode: 'en'),
      ]);
      expect(anthropic.requests, hasLength(2), reason: 'the first send plus one regenerate');
      c.dispose();
    });

    test('leaving the screen while the key is being read sends nothing', () async {
      final slow = _SlowSecrets(secrets);
      final c = make(keys: slow)..setContext(const ChatContext.none());
      final sending = c.send('hi', settings: settings, languageCode: 'en');
      c.dispose();
      slow.gate.complete();
      expect(await sending, isFalse);
      await idle();
      expect(anthropic.requests, isEmpty);
    });

    test('"Delete all chats" while a reply streams: nothing comes back, nothing old is re-sent', () async {
      anthropic
        ..script('live')
        ..script('live');
      final c = make()..setContext(const ChatContext.personal('## Health\n\n- private summary'));
      await c.send('secret question', settings: settings, languageCode: 'en');
      final live = anthropic.live.single;
      live.add(const AiTextDelta('partial'));
      await idle();
      await c.flush();
      expect(await store.index(), hasLength(1));

      // Deleted from the list (or AI settings) while this screen is still open.
      await store.deleteAll();
      await idle();
      live
        ..add(const AiTextDelta(' more'))
        ..add(const AiStreamDone());
      await live.close();
      await idle();
      c.rename('late rename');
      await c.flush();
      await idle();
      expect(await store.index(), isEmpty, reason: 'the deleted conversation must not be re-saved');
      expect(await store.load('id-0'), isNull);

      // The next Send starts over: no deleted history, no approved summary.
      expect(c.conversation.messages, isEmpty);
      expect(c.conversation.context.isDecided, isFalse);
      c.dispose();
    });

    test('a late save never brings a deleted conversation back; undo does', () async {
      final c = Conversation(
        id: 'c1',
        createdAt: now,
        updatedAt: now,
        messages: [ChatMessage(id: 'm', role: ChatRole.user, text: 'q', createdAt: now)],
      );
      await store.save(c);
      final removed = await store.delete('c1');
      await store.save(c); // a stale controller's save
      expect(await store.load('c1'), isNull);
      await store.restore([removed!]);
      expect(await store.load('c1'), isNotNull, reason: 'undo restores it');
    });

    test('an error mid-stream keeps a consistent conversation (partial text never re-sent)', () async {
      anthropic
        ..script('live')
        ..reply('fine');
      final c = make()..setContext(const ChatContext.none());
      await c.send('q1', settings: settings, languageCode: 'en');
      final live = anthropic.live.single;
      live.add(const AiTextDelta('half an ans'));
      await idle();
      live.addError(const AiException(AiErrorKind.overloaded, detail: 'Overloaded'));
      await idle();
      expect(c.conversation.messages.last.status, MessageStatus.failed);
      expect(c.conversation.messages.last.text, 'half an ans');
      await c.flush();
      final stored = (await store.load(c.conversation.id))!;
      expect(stored.messages.last.status, MessageStatus.failed);
      expect(jsonEncode(stored.toJson()), isNot(contains('Overloaded')));

      await c.send('q2', settings: settings, languageCode: 'en');
      await idle();
      expect(anthropic.requests.last.messages, const [AiTurn(ChatRole.user, 'q1\n\nq2')]);
      c.dispose();
    });
  });

  group('payload: exactly the approved sections plus the messages', () {
    test('real summary: excluded sections, notes and free text never go out', () async {
      final db = MadarDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await seedSummaryScenario(db);
      final input = await DataExportRepository(db, useIsolate: false).loadSummaryInput(dataTestNow);
      final en = lookupL10n(const Locale('en'));
      final summary = AiSummaryBuilder(en, languageCode: 'en').build(input);
      final approved = summary.compose({SummarySectionId.faith, SummarySectionId.money});

      final conversation = Conversation(
        id: 'c',
        createdAt: dataTestNow,
        updatedAt: dataTestNow,
        context: ChatContext.personal(approved),
        messages: [
          ChatMessage(id: 'u1', role: ChatRole.user, text: 'first question', createdAt: dataTestNow),
          ChatMessage(id: 'a1', role: ChatRole.assistant, text: 'first answer', createdAt: dataTestNow),
        ],
      );
      final payload = AiPayloadBuilder.build(
        conversation: conversation,
        settings: const AiSettings(),
        languageCode: 'en',
        pendingText: 'second question',
      );
      final request = AnthropicProvider(FakeTransport()).chatRequest(payload.request, apiKey: 'k');
      final body = jsonDecode(request.body!) as Map<String, Object?>;
      expect(body.keys.toSet(), {'model', 'max_tokens', 'system', 'messages', 'stream'});
      final system = body['system']! as String;
      expect(system, contains(approved.trimRight()), reason: 'the approved Markdown goes out as approved');
      expect(RegExp(r'^## ', multiLine: true).allMatches(system).length, 2);
      final context = system.substring(
        system.indexOf(AiSystemPrompt.contextStart) + AiSystemPrompt.contextStart.length,
        system.indexOf(AiSystemPrompt.contextEnd),
      );
      expect(context.trim(), approved.trim(), reason: 'nothing added to or dropped from what was approved');
      // Every note / worry / free-text value in the fixtures contains "private".
      expect(context, isNot(contains('private')));
      for (final absent in [
        '## Health',
        '## Travel',
        '## Profile',
        'Metformin',
        'Asthma',
        '0790000001',
        'N1234567',
        'Holder Person',
        'Thoughts',
      ]) {
        expect(request.body, isNot(contains(absent)), reason: absent);
      }
      expect(body['messages'], [
        {'role': 'user', 'content': 'first question'},
        {'role': 'assistant', 'content': 'first answer'},
        {'role': 'user', 'content': 'second question'},
      ]);

      // "No personal context": no summary at all.
      final none = AiPayloadBuilder.build(
        conversation: conversation.copyWith(context: const ChatContext.none()),
        settings: const AiSettings(),
        languageCode: 'en',
      );
      expect(none.request.system, isNot(contains('Madar summary')));
      expect(none.request.system, isNot(contains('## ')));
    });
  });

  group('streaming parser', () {
    List<List<int>> split(List<int> bytes, int size) => [
      for (var i = 0; i < bytes.length; i += size) bytes.sublist(i, i + size > bytes.length ? bytes.length : i + size),
    ];

    Future<String> textOf(AiProvider p, AiRequest r, List<List<int>> chunks) async {
      final reply = FakeReply.live();
      final t = FakeTransport([reply]);
      final provider = p is AnthropicProvider ? AnthropicProvider(t) : OpenAiProvider(t);
      final b = StringBuffer();
      final done = Completer<void>();
      provider
          .streamChat(r, apiKey: p is AnthropicProvider ? testAnthropicKey : testOpenAiKey)
          .listen((e) => e is AiTextDelta ? b.write(e.text) : null, onDone: done.complete, onError: done.completeError);
      await Future<void>.delayed(Duration.zero);
      for (final c in chunks) {
        reply.controller!.add(c);
      }
      await reply.controller!.close();
      await done.future;
      return b.toString();
    }

    test('Arabic split inside multi-byte characters, SSE lines split anywhere (both services)', () async {
      const words = ['السلامُ ', 'عليكم', ' – 2026 ', 'ﷺ', ' 👋🏽'];
      final a = utf8.encode(anthropicSse(words));
      final o = utf8.encode(openAiSse(words));
      for (final size in [1, 2, 3, 5, 7, 13]) {
        expect(await textOf(AnthropicProvider(FakeTransport()), _anthropicRequest, split(a, size)), words.join(),
            reason: 'anthropic, $size-byte chunks');
        expect(await textOf(OpenAiProvider(FakeTransport()), _openAiRequest, split(o, size)), words.join(),
            reason: 'openai, $size-byte chunks');
      }
    });

    test('a byte-order mark before the first event is ignored', () async {
      final events = await decodeSse(Stream.value(utf8.encode('\ufeffevent: a\ndata: x\n\n'))).toList();
      expect(events, const [SseEvent(event: 'a', data: 'x')]);
    });

    test('[DONE] without a space, and an error event after text', () async {
      final t = FakeTransport([
        FakeReply.sse(['data: {"choices":[{"delta":{"content":"hi"},"finish_reason":"stop"}]}\n\ndata:[DONE]\n\n']),
        FakeReply.sse([
          anthropicSse(['part']).split('event: content_block_stop').first,
          'event: error\ndata: {"type":"error","error":{"type":"overloaded_error","message":"Overloaded"}}\n\n',
        ]),
      ]);
      final events = await OpenAiProvider(t).streamChat(_openAiRequest, apiKey: testOpenAiKey).toList();
      expect(events.whereType<AiTextDelta>().single.text, 'hi');
      expect(events.last, isA<AiStreamDone>());
      final got = <String>[];
      final e = await _aiError(
        AnthropicProvider(t)
            .streamChat(_anthropicRequest, apiKey: testAnthropicKey)
            .map((e) => e is AiTextDelta ? got.add(e.text) : null)
            .toList(),
      );
      expect(got, ['part']);
      expect(e.kind, AiErrorKind.overloaded);
    });
  });

  group('screens', () {
    testWidgets('a link in a reply opens only after the user sees where it goes', (tester) async {
      usePhone(tester);
      final opened = <Uri>[];
      final (app, _) = await buildAiApp(
        tester,
        home: Scaffold(
          body: MarkdownView(
            'Details [here](https://evil.example/collect?d=blood+pressure+150).',
            onOpenLink: (uri) async {
              opened.add(uri);
              return true;
            },
          ),
        ),
      );
      await tester.pumpWidget(app);
      await frames(tester, 2);
      TextSpan? link;
      for (final r in tester.widgetList<RichText>(find.byType(RichText))) {
        r.text.visitChildren((s) {
          if (s is TextSpan && s.text == 'here') link = s;
          return true;
        });
      }
      (link!.recognizer! as TapGestureRecognizer).onTap!();
      await frames(tester, 12);
      expect(opened, isEmpty, reason: 'a tap on the label alone must not open a hidden address');
      expect(find.textContaining('evil.example'), findsWidgets, reason: 'the destination is shown first');
      await tester.tap(find.byKey(MarkdownView.openLinkKey));
      await frames(tester, 12);
      expect(opened, [Uri.parse('https://evil.example/collect?d=blood+pressure+150')]);
    });

    testWidgets('Regenerate with an undecided context asks for the summary first (not a silent no-op)',
        (tester) async {
      usePhone(tester);
      final (app, env) = await buildAiApp(
        tester,
        home: const AiChatScreen(conversationId: 'c1'),
        keys: const {'madar.ai.anthropic.apiKey.v1': testAnthropicKey},
        beforePump: (db) => ConversationStore(db).save(
          Conversation(
            id: 'c1',
            createdAt: aiTestNow,
            updatedAt: aiTestNow,
            messages: [
              ChatMessage(id: 'u', role: ChatRole.user, text: 'q', createdAt: aiTestNow),
              ChatMessage(id: 'a', role: ChatRole.assistant, text: 'a', createdAt: aiTestNow),
            ],
          ),
        ),
      );
      await tester.pumpWidget(app);
      await settleAsync(tester);
      await tester.tap(find.byTooltip('Regenerate'));
      await settleAsync(tester, rounds: 4);
      expect(env.picker.calls, [true], reason: 'the summary preview opens');
      expect(env.anthropic.requests, hasLength(1));
      expect(env.anthropic.requests.single.system, contains('## Faith'));
    });

    testWidgets('a key pasted from the clipboard is cleared from it once saved', (tester) async {
      usePhone(tester);
      String? clipboard = '  $testAnthropicKey\n';
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.getData') return {'text': clipboard};
        if (call.method == 'Clipboard.setData') clipboard = (call.arguments as Map)['text'] as String?;
        if (call.method == 'Clipboard.hasStrings') return {'value': clipboard?.isNotEmpty ?? false};
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      final (app, env) = await buildAiApp(tester, home: const AiSettingsScreen());
      await tester.pumpWidget(app);
      await settleAsync(tester);
      await tester.tap(find.byKey(AiSettingsScreen.keyRow(AiProviderId.anthropic)));
      await frames(tester, 12);
      await tester.tap(find.byKey(AiKeySheet.pasteKey));
      await frames(tester, 4);
      await tester.tap(find.byKey(AiKeySheet.saveKey));
      await settleAsync(tester, rounds: 4);
      expect(env.secrets.values.values, [testAnthropicKey]);
      expect(clipboard ?? '', isNot(contains('TESTKEY')), reason: 'the key no longer sits in the clipboard');
    });

    testWidgets('a key of the other service is refused in the key sheet (not saved as a warning)', (tester) async {
      usePhone(tester);
      final (app, env) = await buildAiApp(tester, home: const AiSettingsScreen());
      await tester.pumpWidget(app);
      await settleAsync(tester);
      await tester.tap(find.byKey(AiSettingsScreen.keyRow(AiProviderId.anthropic)));
      await frames(tester, 12);
      await tester.enterText(find.byKey(AiKeySheet.fieldKey), testOpenAiKey);
      await tester.pump();
      await tester.tap(find.byKey(AiKeySheet.saveKey));
      await settleAsync(tester, rounds: 4);
      expect(env.secrets.values, isEmpty);
      expect(find.textContaining('This key belongs to OpenAI, so it wasn’t saved here'), findsOneWidget);
    });

    testWidgets('a failed reply that talks about health still carries the tracking-only note', (tester) async {
      usePhone(tester);
      final (app, _) = await buildAiApp(
        tester,
        home: Scaffold(
          body: MessageBubble(
            message: ChatMessage(
              id: 'a',
              role: ChatRole.assistant,
              text: 'Your blood pressure readings',
              createdAt: aiTestNow,
              status: MessageStatus.failed,
              error: AiErrorKind.network,
            ),
            onRegenerate: () {},
            onOpenSettings: () {},
          ),
        ),
      );
      await tester.pumpWidget(app);
      await frames(tester, 4);
      expect(find.byKey(const ValueKey('ai-health-note')), findsOneWidget);
    });
  });

}
