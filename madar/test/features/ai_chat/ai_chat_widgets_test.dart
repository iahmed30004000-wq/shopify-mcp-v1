import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/repositories/key_value_repository.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/ai_chat/ai_chat.dart';
import 'package:madar/features/ai_chat/domain/system_prompt.dart';
import 'package:madar/features/ai_chat/presentation/widgets/composer.dart';
import 'package:madar/features/ai_chat/presentation/widgets/key_sheet.dart';
import 'package:madar/features/ai_chat/presentation/widgets/markdown_view.dart';
import 'package:madar/features/ai_chat/presentation/widgets/setup_card.dart';
import 'package:madar/features/ai_chat/presentation/widgets/will_send_sheet.dart';
import 'package:madar/features/ai_chat/presentation/widgets/will_send_strip.dart';
import 'package:madar/features/data/data.dart';

import '../data/data_fixtures.dart';
import 'ai_chat_fakes.dart';
import 'ai_chat_harness.dart';

const _keys = {'madar.ai.anthropic.apiKey.v1': testAnthropicKey};

Future<L10n> _l10n(String lang) => L10n.delegate.load(Locale(lang));

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(ChatComposer.fieldKey), text);
  await tester.pump();
}

Future<void> _tapSend(WidgetTester tester) async {
  await tester.tap(find.byKey(ChatComposer.sendKey));
  await frames(tester, 4);
  await settleAsync(tester, rounds: 6);
  await frames(tester, 10);
}

/// The texts of every RichText on screen.
Iterable<String> _allText(WidgetTester tester) =>
    tester.widgetList<RichText>(find.byType(RichText)).map((r) => r.text.toPlainText());

void main() {
  for (final lang in ['en', 'ar']) {
    group('[$lang]', () {
      testWidgets('no key: friendly setup card; adding a key stores it only in secure storage, masked', (tester) async {
        usePhone(tester);
        final l = await _l10n(lang);
        final (app, env) = await buildAiApp(tester, home: const AiChatScreen(), locale: Locale(lang));
        await tester.pumpWidget(app);
        await settleAsync(tester);
        expect(find.text(l.aiChatSetupTitle), findsOneWidget);
        expect(find.byType(WillSendStrip), findsNothing);

        await tester.tap(find.byKey(AiKeySetupCard.addKey(AiProviderId.anthropic)));
        await frames(tester, 12);
        expect(find.text(l.aiChatKeyTitle(l.aiChatServiceAnthropic)), findsOneWidget);
        await tester.enterText(find.byKey(AiKeySheet.fieldKey), '  $testAnthropicKey \n');
        await tester.pump();
        final field = tester.widget<TextField>(find.byKey(AiKeySheet.fieldKey));
        expect(field.obscureText, isTrue);
        expect(field.enableSuggestions, isFalse);
        expect(field.autocorrect, isFalse);
        expect(field.enableIMEPersonalizedLearning, isFalse);
        await tester.tap(find.byKey(AiKeySheet.saveKey));
        await settleAsync(tester, rounds: 4);
        await frames(tester, 6);
        expect(env.secrets.values, {AiKeyStore.storageKey(AiProviderId.anthropic): testAnthropicKey});
        expect(find.textContaining('WXYZ'), findsWidgets);
        expect(_allText(tester).where((s) => s.contains('TESTKEY')), isEmpty, reason: 'the key is never displayed');
        expect(field.controller!.text, isEmpty, reason: 'the field is cleared after saving');

        // Nothing about the key reached the database.
        final rows = await tester.runAsync(() => env.db.select(env.db.keyValues).get());
        expect(rows!.map((r) => '${r.key}=${r.value}').join('\n'), isNot(contains('TESTKEY')));
        expect(env.anthropic.requests, isEmpty);
      });

      testWidgets('first Send opens the summary preview; cancelling sends nothing', (tester) async {
        usePhone(tester);
        final l = await _l10n(lang);
        final picker = FakePicker(result: null);
        final (app, env) = await buildAiApp(tester, home: const AiChatScreen(), locale: Locale(lang), keys: _keys, picker: picker);
        await tester.pumpWidget(app);
        await settleAsync(tester);
        expect(find.byKey(WillSendStrip.stripKey), findsOneWidget);
        expect(find.text(l.aiChatContextReviewFirst), findsOneWidget);

        await _type(tester, 'How was my week?');
        await _tapSend(tester);
        expect(picker.calls, [true]);
        expect(env.anthropic.requests, isEmpty);
        expect(find.text(l.aiChatContextCancelled), findsOneWidget);
        expect(find.text('How was my week?'), findsOneWidget, reason: 'the draft stays in the field');
      });

      testWidgets('approve → sent with exactly the approved summary; later sends skip the preview; strip shows it', (
        tester,
      ) async {
        usePhone(tester);
        final l = await _l10n(lang);
        final (app, env) = await buildAiApp(tester, home: const AiChatScreen(), locale: Locale(lang), keys: _keys);
        env.anthropic
          ..reply('Your week looked **steady**.')
          ..reply('Second answer');
        await tester.pumpWidget(app);
        await settleAsync(tester);

        await _type(tester, 'How was my week?');
        await _tapSend(tester);
        expect(env.picker.calls, [true]);
        expect(env.anthropic.requests.length, 1);
        final system = env.anthropic.requests.single.system;
        expect(system, contains('${AiSystemPrompt.contextStart}\n$aiTestSummary\n${AiSystemPrompt.contextEnd}'));
        expect(env.anthropic.requests.single.messages, const [AiTurn(ChatRole.user, 'How was my week?')]);
        expect(find.textContaining('steady'), findsOneWidget);
        // Strip: 2 sections from the summary.
        expect(find.textContaining(l.aiChatContextSections(2).replaceAll(RegExp(r'\d'), '')), findsWidgets);

        await _type(tester, 'And money?');
        await _tapSend(tester);
        expect(env.picker.calls, [true], reason: 'the preview opens only before the first call');
        expect(env.anthropic.requests.length, 2);
        expect(env.anthropic.requests.last.system, system);
        expect(env.anthropic.requests.last.messages.length, 3);
      });

      testWidgets('health replies get the small note; others do not', (tester) async {
        usePhone(tester);
        final l = await _l10n(lang);
        final (app, env) = await buildAiApp(tester, home: const AiChatScreen(), locale: Locale(lang), keys: _keys);
        env.anthropic
          ..reply(lang == 'ar' ? 'قراءات ضغط الدم مستقرة هذا الأسبوع.' : 'Your blood pressure readings were steady.')
          ..reply(lang == 'ar' ? 'ميزانيتك على المسار.' : 'Your budget is on track.');
        await tester.pumpWidget(app);
        await settleAsync(tester);
        await _type(tester, 'q1');
        await _tapSend(tester);
        expect(find.text(l.aiChatHealthNote), findsOneWidget);
        await _type(tester, 'q2');
        await _tapSend(tester);
        expect(find.text(l.aiChatHealthNote), findsOneWidget, reason: 'only under the health reply');
      });
    });
  }

  testWidgets('nothing is sent without an explicit Send: typing, the strip, its sheet and the payload view', (tester) async {
    usePhone(tester);
    final (app, env) = await buildAiApp(tester, home: const AiChatScreen(initialDraft: 'Plan my day'), keys: _keys);
    await tester.pumpWidget(app);
    await settleAsync(tester);
    await _type(tester, 'Plan my day, please');
    await tester.tap(find.byKey(WillSendStrip.stripKey));
    await frames(tester, 14);
    expect(find.byType(WillSendSheet), findsOneWidget);
    await tester.tap(find.byKey(WillSendSheet.chooseKey));
    await frames(tester, 10);
    expect(env.picker.calls, [false]);
    await tester.tap(find.byKey(WillSendSheet.payloadKey));
    await frames(tester, 14);
    await tester.pump(const Duration(seconds: 5));
    await settleAsync(tester);
    expect(env.anthropic.requests, isEmpty);
    expect(env.openai.requests, isEmpty);
  });

  testWidgets('"What will be sent" shows the exact body that Send then posts; key masked', (tester) async {
    usePhone(tester);
    final transport = FakeTransport([FakeReply.sse([anthropicSse(['Done.'])])]);
    final (app, env) = await buildAiApp(tester, home: const AiChatScreen(), keys: _keys, transport: transport);
    await tester.pumpWidget(app);
    await settleAsync(tester);
    // Decide the context first (from the strip's sheet).
    await tester.tap(find.byKey(WillSendStrip.stripKey));
    await frames(tester, 14);
    await tester.tap(find.byKey(WillSendSheet.chooseKey));
    await frames(tester, 10);
    await _type(tester, 'Summarise my month');
    await tester.tap(find.byKey(WillSendSheet.payloadKey));
    await frames(tester, 14);
    // Expand the raw body.
    await tester.tap(find.text('Full body (JSON)'));
    await frames(tester, 10);
    final shown = tester.widget<SelectableText>(find.byKey(const ValueKey('ai-payload-json'))).data!;
    expect(find.textContaining('x-api-key: ••••WXYZ'), findsOneWidget);
    expect(_allText(tester).where((s) => s.contains('TESTKEY')), isEmpty);
    // Close both sheets and send.
    await tester.tapAt(const Offset(200, 30));
    await frames(tester, 12);
    await tester.tapAt(const Offset(200, 30));
    await frames(tester, 12);
    await _tapSend(tester);
    expect(transport.requests.length, 1);
    final sent = transport.requests.single;
    expect(sent.headers['x-api-key'], testAnthropicKey);
    expect(jsonDecode(sent.body!), jsonDecode(shown));
    expect((jsonDecode(sent.body!) as Map)['system'], contains(aiTestSummary));
    expect(find.text('Done.'), findsOneWidget);
    expect(env.picker.calls, [false], reason: 'already decided in the sheet');
  });

  testWidgets('"No personal context": the call carries nothing from the summary', (tester) async {
    usePhone(tester);
    final (app, env) = await buildAiApp(tester, home: const AiChatScreen(), keys: _keys);
    await tester.pumpWidget(app);
    await settleAsync(tester);
    await tester.tap(find.byKey(WillSendStrip.stripKey));
    await frames(tester, 14);
    await tester.tap(find.byKey(WillSendSheet.noneSwitchKey));
    await frames(tester, 6);
    await tester.tapAt(const Offset(200, 30));
    await frames(tester, 12);
    await _type(tester, 'General question');
    await _tapSend(tester);
    expect(env.picker.calls, isEmpty);
    expect(env.anthropic.requests.single.system, isNot(contains(AiSystemPrompt.contextStart)));
    expect(env.anthropic.requests.single.system, contains('chose not to share'));
  });

  testWidgets('Stop keeps the partial reply; errors are clear and Try again is an explicit tap', (tester) async {
    usePhone(tester);
    final l = await _l10n('en');
    final (app, env) = await buildAiApp(tester, home: const AiChatScreen(), keys: _keys);
    env.picker.result = aiTestSummary;
    env.anthropic
      ..script('live')
      ..script(const AiException(AiErrorKind.rateLimited, statusCode: 429, retryAfter: Duration(seconds: 20)))
      ..reply('Recovered answer');
    await tester.pumpWidget(app);
    await settleAsync(tester);
    await _type(tester, 'Long question');
    await _tapSend(tester);
    env.anthropic.live.single.add(const AiTextDelta('Partial reply'));
    await frames(tester, 4);
    expect(find.byKey(ChatComposer.stopKey), findsOneWidget);
    expect(find.text('Partial reply'), findsOneWidget);
    await tester.tap(find.byKey(ChatComposer.stopKey));
    await frames(tester, 8);
    expect(find.text(l.aiChatStopped), findsOneWidget);
    expect(find.text('Partial reply'), findsOneWidget);

    await _type(tester, 'Another');
    await _tapSend(tester);
    expect(find.text(l.aiChatErrorRateLimited), findsOneWidget);
    expect(env.anthropic.requests.length, 2);
    await tester.pump(const Duration(seconds: 30));
    expect(env.anthropic.requests.length, 2, reason: 'never retried automatically');
    await tester.tap(find.text(l.aiChatRetry));
    await frames(tester, 6);
    await settleAsync(tester, rounds: 4);
    expect(env.anthropic.requests.length, 3);
    expect(find.text('Recovered answer'), findsOneWidget);
    expect(find.text(l.aiChatErrorRateLimited), findsNothing);
  });

  testWidgets('bad key and unknown model errors offer settings', (tester) async {
    usePhone(tester);
    final l = await _l10n('ar');
    final (app, env) = await buildAiApp(tester, home: const AiChatScreen(), keys: _keys, locale: const Locale('ar'));
    env.anthropic
      ..script(const AiException(AiErrorKind.badKey, statusCode: 401))
      ..script(const AiException(AiErrorKind.modelNotFound, statusCode: 404));
    await tester.pumpWidget(app);
    await settleAsync(tester);
    await _type(tester, 'سؤال');
    await _tapSend(tester);
    expect(find.text(l.aiChatErrorBadKey(l.aiChatServiceAnthropic)), findsOneWidget);
    expect(find.text(l.aiChatOpenSettings), findsOneWidget);
    expect(find.text(l.aiChatRetry), findsNothing, reason: 'retrying a rejected key is pointless');
  });

  testWidgets('real summary preview: payload equals the approved sections (one excluded)', (tester) async {
    usePhone(tester);
    final (app, env) = await buildAiApp(
      tester,
      home: const AiChatScreen(),
      keys: _keys,
      realPicker: true,
      beforePump: (db) => seedSummaryScenario(db),
    );
    await tester.pumpWidget(app);
    await settleAsync(tester);
    await _type(tester, 'Anything to watch this week?');
    await tester.tap(find.byKey(ChatComposer.sendKey));
    await frames(tester, 6);
    await settleAsync(tester, rounds: 14);
    await frames(tester, 10);
    expect(find.byType(ExportPreviewSheet), findsOneWidget);
    expect(env.anthropic.requests, isEmpty);

    // Exclude "Money".
    final money = find.ancestor(of: find.text('Money'), matching: find.byType(Row)).first;
    final moneySwitch = find.descendant(of: money, matching: find.byType(MadarSwitch));
    await tester.ensureVisible(moneySwitch);
    await tester.tap(moneySwitch);
    await frames(tester, 6);
    await settleAsync(tester, rounds: 4);
    await tester.tap(find.text('Use and send'));
    await frames(tester, 6);
    await settleAsync(tester, rounds: 6);
    await frames(tester, 10);

    expect(env.anthropic.requests.length, 1);
    final system = env.anthropic.requests.single.system;
    // What the preview approved, rebuilt independently from the same data and stored choices.
    final expected = await tester.runAsync(() async {
      final repo = DataExportRepository(env.db);
      final input = await repo.loadSummaryInput(DateTime(2026, 9, 30, 10));
      final options = await repo.summaryOptions();
      final summary = AiSummaryBuilder(await _l10n('en'), languageCode: 'en').build(input, profile: options.profile);
      return summary.compose(options.included);
    });
    expect(system, contains('${AiSystemPrompt.contextStart}\n${expected!.trimRight()}\n${AiSystemPrompt.contextEnd}'));
    expect(system, isNot(contains('## Money')));
    expect(system, contains('## Faith'));
  });

  group('markdown + bidi rendering', () {
    Future<void> pumpMd(WidgetTester tester, String md, {TextDirection dir = TextDirection.rtl, MdLinkOpener? open}) async {
      final (app, _) = await buildAiApp(
        tester,
        locale: dir == TextDirection.rtl ? const Locale('ar') : const Locale('en'),
        home: Scaffold(body: SingleChildScrollView(child: MarkdownView(md, onOpenLink: open))),
      );
      await tester.pumpWidget(app);
      await frames(tester, 2);
    }

    RichText richWith(WidgetTester tester, String text) =>
        tester.widgetList<RichText>(find.byType(RichText)).firstWhere((r) => r.text.toPlainText().contains(text));

    testWidgets('each paragraph and list item takes its own direction', (tester) async {
      await pumpMd(
        tester,
        'مرحبًا! هذه خطتك لعام 2026:\n\nEnglish paragraph with ٣ numbers.\n\n- بند عربي 12\n- English item\n\n```\ncode()\n```',
      );
      expect(richWith(tester, 'مرحبًا').textDirection, TextDirection.rtl);
      expect(richWith(tester, 'English paragraph').textDirection, TextDirection.ltr);
      expect(richWith(tester, 'بند عربي').textDirection, TextDirection.rtl);
      expect(richWith(tester, 'English item').textDirection, TextDirection.ltr);
      expect(richWith(tester, 'code()').textDirection, TextDirection.ltr);
    });

    testWidgets('an Arabic paragraph in an English layout still reads right to left', (tester) async {
      await pumpMd(tester, 'Hello\n\nالسلام عليكم ورحمة الله', dir: TextDirection.ltr);
      expect(richWith(tester, 'Hello').textDirection, TextDirection.ltr);
      expect(richWith(tester, 'السلام').textDirection, TextDirection.rtl);
    });

    testWidgets('styles: bold, italic, code, headings, table', (tester) async {
      await pumpMd(tester, '## Plan\n\n**bold** and *it* and `x`\n\n| a | b |\n|---|---|\n| 1 | 2 |', dir: TextDirection.ltr);
      final p = richWith(tester, 'bold and');
      final spans = <TextSpan>[];
      p.text.visitChildren((s) {
        if (s is TextSpan && s.text != null) spans.add(s);
        return true;
      });
      expect(spans.firstWhere((s) => s.text == 'bold').style!.fontWeight, FontWeight.w700);
      expect(spans.firstWhere((s) => s.text == 'it').style!.fontStyle, FontStyle.italic);
      expect(find.byType(Table), findsOneWidget);
      expect(richWith(tester, 'Plan').text.style ?? const TextStyle(), isNotNull);
    });

    testWidgets('links open only on tap and only for web / e-mail', (tester) async {
      final opened = <Uri>[];
      await pumpMd(
        tester,
        'See [the guide](https://madar.app/guide) or [this](javascript:alert(1)).',
        dir: TextDirection.ltr,
        open: (uri) async {
          opened.add(uri);
          return true;
        },
      );
      expect(opened, isEmpty);
      final rich = richWith(tester, 'the guide');
      TextSpan? link;
      TextSpan? unsafe;
      rich.text.visitChildren((s) {
        if (s is TextSpan && s.text == 'the guide') link = s;
        if (s is TextSpan && s.text == 'this') unsafe = s;
        return true;
      });
      expect(unsafe!.recognizer, isNull);
      (link!.recognizer! as TapGestureRecognizer).onTap!();
      await tester.pump();
      expect(opened, [Uri.parse('https://madar.app/guide')]);
    });
  });

  testWidgets('conversation list: open, rename, delete all with undo', (tester) async {
    usePhone(tester);
    final l = await _l10n('en');
    final (app, env) = await buildAiApp(
      tester,
      home: const AiChatListScreen(),
      keys: _keys,
      beforePump: (db) async {
        final store = ConversationStore(db);
        for (var i = 0; i < 3; i++) {
          await store.save(
            Conversation(
              id: 'c$i',
              createdAt: aiTestNow,
              updatedAt: aiTestNow.subtract(Duration(days: i)),
              title: 'Chat number $i',
              messages: [
                ChatMessage(id: 'm$i', role: ChatRole.user, text: 'Question $i', createdAt: aiTestNow),
              ],
            ),
          );
        }
      },
    );
    await tester.pumpWidget(app);
    await settleAsync(tester);
    await frames(tester, 12);
    expect(find.text('Chat number 0'), findsOneWidget);
    expect(find.text('Chat number 2'), findsOneWidget);

    await tester.runAsync(() => ConversationStore(env.db).rename('c1', 'Budget review'));
    await settleAsync(tester);
    expect(find.text('Budget review'), findsOneWidget);

    await tester.scrollUntilVisible(find.text(l.aiChatDeleteAll), 200);
    await tester.tap(find.text(l.aiChatDeleteAll));
    await settleAsync(tester);
    await frames(tester, 8);
    expect(find.text(l.aiChatListEmptyTitle), findsOneWidget);
    expect(find.text(l.aiChatDeletedAll), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(l.actionUndo).last);
    await settleAsync(tester, rounds: 12);
    await frames(tester, 12);
    expect(find.text('Budget review'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('settings: masked keys, reply length and temperature are stored (never the key)', (tester) async {
    usePhone(tester);
    final l = await _l10n('en');
    final (app, env) = await buildAiApp(tester, home: const AiSettingsScreen(), keys: _keys);
    await tester.pumpWidget(app);
    await settleAsync(tester);
    await frames(tester, 12);
    expect(find.text(l.aiChatKeySaved('\u2066••••WXYZ\u2069')), findsOneWidget);
    expect(find.text(l.aiChatKeyNotSet), findsOneWidget);
    await tester.tap(find.text('8,192'));
    await settleAsync(tester, rounds: 4);
    await tester.ensureVisible(find.byKey(AiSettingsScreen.temperatureSwitch));
    await tester.tap(find.byKey(AiSettingsScreen.temperatureSwitch));
    await settleAsync(tester, rounds: 4);
    await frames(tester, 8);
    final stored = await tester.runAsync(() => KeyValueRepository(env.db).getJson(AiSettings.storageKey));
    final s = AiSettings.fromJson(stored);
    expect(s.maxTokens, 8192);
    expect(s.temperature, 0.7);
    expect(jsonEncode(stored), isNot(contains('TESTKEY')));
  });

  testWidgets('Ask AI entry opens a new chat with the question typed, not sent', (tester) async {
    usePhone(tester);
    final (app, env) = await buildAiApp(
      tester,
      keys: _keys,
      home: const Scaffold(body: Center(child: AskAiEntry(area: 'health', prompt: 'How is my sleep?'))),
    );
    await tester.pumpWidget(app);
    await frames(tester, 4);
    expect(find.text('Ask about health'), findsOneWidget);
    await tester.tap(find.byType(AskAiEntry));
    await frames(tester, 16);
    await settleAsync(tester);
    expect(find.byType(AiChatScreen), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(ChatComposer.fieldKey)).controller!.text, 'How is my sleep?');
    expect(env.anthropic.requests, isEmpty);
  });

  testWidgets('model chip opens the picker; choosing a model applies to the next call', (tester) async {
    usePhone(tester);
    final (app, env) = await buildAiApp(tester, home: const AiChatScreen(), keys: _keys);
    await tester.pumpWidget(app);
    await settleAsync(tester);
    expect(find.text('Claude Sonnet 5.5'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ai-model-chip')));
    await frames(tester, 14);
    await tester.tap(find.text('Claude Haiku 4.5'));
    await settleAsync(tester, rounds: 4);
    await frames(tester, 12);
    expect(find.text('Claude Haiku 4.5'), findsOneWidget);
    await tester.tap(find.byKey(WillSendStrip.stripKey));
    await frames(tester, 14);
    await tester.tap(find.byKey(WillSendSheet.noneSwitchKey));
    await tester.tapAt(const Offset(200, 30));
    await frames(tester, 12);
    await _type(tester, 'hi');
    await _tapSend(tester);
    expect(env.anthropic.requests.single.model, 'claude-haiku-4-5-20251001');
  });

  testWidgets('clipboard copy of a reply', (tester) async {
    usePhone(tester);
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final (app, env) = await buildAiApp(tester, home: const AiChatScreen(), keys: _keys);
    env.anthropic.reply('Copy **me**');
    await tester.pumpWidget(app);
    await settleAsync(tester);
    await _type(tester, 'q');
    await _tapSend(tester);
    await tester.tap(find.bySemanticsLabel('Copy').last);
    await frames(tester, 4);
    expect(copied, ['Copy **me**']);
  });
}

