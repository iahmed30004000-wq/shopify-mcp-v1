// The owner's own switch: "let the AI chat send outside".
//
// He asked, on the night of 2026-10-15, that anything leaving the phone be
// off by default. So this is its own stored setting (`aiChat.settings`,
// `outside`), off on a fresh install, and while it is off the AI chat may
// make no request at all – not Send, not Regenerate, not "Test key", not
// "Refresh models". Every way into the chat says so in his own words and
// offers him the switch instead of silently doing nothing.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/encryption.dart';
import 'package:madar/core/db/repositories/key_value_repository.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/ai_chat/ai_chat.dart';
import 'package:madar/features/ai_chat/presentation/ai_labels.dart';
import 'package:madar/features/ai_chat/presentation/chat_controller.dart';
import 'package:madar/features/ai_chat/presentation/widgets/composer.dart';
import 'package:madar/features/ai_chat/presentation/widgets/setup_card.dart';
import 'package:madar/features/ai_chat/presentation/widgets/will_send_strip.dart';

import 'ai_chat_fakes.dart';
import 'ai_chat_harness.dart';

const _keys = {'madar.ai.anthropic.apiKey.v1': testAnthropicKey};

Future<L10n> _l10n(String lang) => L10n.delegate.load(Locale(lang));

/// `ensureVisible` can park a control under the frosted app bar, where a
/// tap lands on the header instead. Nudge the list until it is really
/// pressable.
Future<Finder> _pressable(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await frames(tester, 6);
  for (var i = 0; i < 8 && target.hitTestable().evaluate().isEmpty; i++) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 80));
    await frames(tester, 4);
  }
  expect(target.hitTestable(), findsOneWidget, reason: 'the control never cleared the header');
  return target.hitTestable();
}

void main() {
  for (final lang in ['ar', 'en']) {
    group('[$lang]', () {
      testWidgets('settings: off on a fresh install, and turning it on is stored', (tester) async {
        usePhone(tester);
        final l = await _l10n(lang);
        final (app, env) = await buildAiApp(
          tester,
          home: const AiSettingsScreen(),
          locale: Locale(lang),
          keys: _keys,
          outsideAllowed: false,
        );
        await tester.pumpWidget(app);
        await settleAsync(tester);
        await frames(tester, 12);

        // The switch is there, off, and says plainly what off means.
        final sw = find.byKey(AiSettingsScreen.outsideSwitch);
        expect(sw, findsOneWidget);
        expect(find.text(l.aiChatOutsideSwitch), findsOneWidget);
        expect(find.text(l.aiChatOutsideOff), findsOneWidget);
        expect(find.text(l.aiChatOutsideOn), findsNothing);
        expect(
          await tester.runAsync(() => KeyValueRepository(env.db).getJson(AiSettings.storageKey)),
          isNull,
          reason: 'a fresh install has no row at all, and that reads as off',
        );

        // The ⚠️ card keeps everything it said and gains the one new line.
        await tester.ensureVisible(find.byKey(AiSettingsScreen.outsideNotice));
        await frames(tester, 6);
        expect(find.text(l.aiChatPrivacyOutsideTitle), findsOneWidget);
        expect(find.text(l.aiChatPrivacyOutsideBody), findsOneWidget);
        expect(find.text(l.aiChatPrivacyOutsideSwitch), findsOneWidget);
        expect(find.text(l.aiChatPrivacyOutsideFix), findsOneWidget, reason: 'the on-device model line stays');

        // He turns it on himself.
        await tester.tap(await _pressable(tester, find.byKey(AiSettingsScreen.outsideSwitch)));
        await settleAsync(tester, rounds: 4);
        await frames(tester, 8);
        final stored = await tester.runAsync(() => KeyValueRepository(env.db).getJson(AiSettings.storageKey));
        expect(AiSettings.fromJson(stored).outsideAllowed, isTrue);
        expect(find.text(l.aiChatOutsideOn), findsOneWidget);
        expect(env.anthropic.requests, isEmpty, reason: 'turning it on calls nobody');
      });

      testWidgets('chat: the off panel instead of the chat, and Send says so and sends nothing', (tester) async {
        usePhone(tester);
        final l = await _l10n(lang);
        final (app, env) = await buildAiApp(
          tester,
          home: const AiChatScreen(initialDraft: 'سؤال من شريط الإضافة السريعة'),
          locale: Locale(lang),
          keys: _keys,
          outsideAllowed: false,
        );
        await tester.pumpWidget(app);
        await settleAsync(tester);
        await frames(tester, 12);

        expect(find.byType(AiOffCard), findsOneWidget);
        expect(find.text(l.aiChatOffTitle), findsOneWidget);
        expect(find.text(l.aiChatOffBody), findsOneWidget);
        expect(find.byType(AiKeySetupCard), findsNothing, reason: 'a key is saved; the switch is the reason');
        expect(find.byType(WillSendStrip), findsNothing, reason: 'nothing will be sent, so nothing to preview');
        // The handed-over draft is kept, not thrown away.
        expect(
          tester.widget<TextField>(find.byKey(ChatComposer.fieldKey)).controller!.text,
          'سؤال من شريط الإضافة السريعة',
        );

        await tester.tap(find.byKey(ChatComposer.sendKey));
        await settleAsync(tester, rounds: 4);
        await frames(tester, 10);
        expect(find.text(l.aiChatOffSendNotice), findsOneWidget);
        expect(env.anthropic.requests, isEmpty);
        expect(env.picker.calls, isEmpty, reason: 'it never even asks which sections to share');
        expect(
          tester.widget<TextField>(find.byKey(ChatComposer.fieldKey)).controller!.text,
          'سؤال من شريط الإضافة السريعة',
          reason: 'his question stays where he can still use it',
        );

        // The panel's button takes him to the switch.
        await tester.tap(find.byKey(AiOffCard.actionKey));
        await settleAsync(tester, rounds: 4);
        await frames(tester, 12);
        expect(find.byType(AiSettingsScreen), findsOneWidget);
        expect(find.byKey(AiSettingsScreen.outsideSwitch), findsOneWidget);
      });

      testWidgets('the "Ask about …" card says it is off before he taps', (tester) async {
        usePhone(tester);
        final l = await _l10n(lang);
        final (app, env) = await buildAiApp(
          tester,
          locale: Locale(lang),
          keys: _keys,
          outsideAllowed: false,
          home: const Scaffold(
            body: Center(
              child: AskAiEntry(area: 'money', prompt: 'كيف ميزانيتي؟'),
            ),
          ),
        );
        await tester.pumpWidget(app);
        await settleAsync(tester);
        await frames(tester, 8);
        expect(find.text(l.aiChatOffEntrySubtitle), findsOneWidget);
        expect(find.text(l.aiChatAskAiSubtitle), findsNothing);

        await tester.tap(find.byType(AskAiEntry));
        await settleAsync(tester);
        await frames(tester, 12);
        expect(find.byType(AiOffCard), findsOneWidget, reason: 'the card never opens a chat that does nothing');
        expect(env.anthropic.requests, isEmpty);
      });

      testWidgets('the off panel holds together at text scale 1.3', (tester) async {
        usePhone(tester);
        final l = await _l10n(lang);
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final (app, _) = await buildAiApp(
          tester,
          home: const AiChatScreen(),
          locale: Locale(lang),
          keys: _keys,
          outsideAllowed: false,
        );
        await tester.pumpWidget(app);
        await settleAsync(tester);
        await frames(tester, 12);
        expect(find.text(l.aiChatOffBody), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }

  group('the gate', () {
    test('while the switch is off no request is handed to the network at all', () async {
      final inner = FakeTransport([FakeReply.json({'ok': true})]);
      var allowed = false;
      final gate = AiOutsideGate(inner, () => allowed);
      final request = AiHttpRequest(method: 'GET', url: Uri.parse('https://api.anthropic.com/v1/models'));

      expect(() => gate.send(request), throwsA(isA<AiOutsideOffException>()));
      expect(inner.requests, isEmpty, reason: 'not even a DNS lookup');

      allowed = true;
      expect((await gate.send(request)).statusCode, 200);
      expect(inner.requests, hasLength(1));
    });

    test('"Test key" and "Refresh models" are refused too, with a message he can act on', () async {
      final inner = FakeTransport([FakeReply.json({'data': <Object>[]})]);
      final provider = AnthropicProvider(AiOutsideGate(inner, () => false));
      await expectLater(
        provider.listModels(apiKey: testAnthropicKey),
        throwsA(isA<AiException>().having((e) => e.kind, 'kind', AiErrorKind.outsideOff)),
      );
      await expectLater(provider.testKey(testAnthropicKey), throwsA(isA<AiException>()));
      expect(inner.requests, isEmpty);
      final l = await _l10n('ar');
      expect(
        l.aiError(AiErrorKind.outsideOff, provider: AiProviderId.anthropic, model: 'claude-sonnet-5-5'),
        l.aiChatErrorOutsideOff,
      );
      expect(aiErrorWantsSettings(AiErrorKind.outsideOff), isTrue, reason: 'the fix is one tap away');
    });
  });

  group('the setting itself', () {
    test('a fresh install, an old row and a damaged one all read as off', () {
      expect(const AiSettings().outsideAllowed, isFalse);
      expect(AiSettings.fromJson(null).outsideAllowed, isFalse);
      expect(AiSettings.fromJson(<String, Object?>{'provider': 'openai'}).outsideAllowed, isFalse);
      expect(AiSettings.fromJson(<String, Object?>{'outside': 'yes'}).outsideAllowed, isFalse);
      expect(AiSettings.fromJson(<String, Object?>{'outside': true}).outsideAllowed, isTrue);
      // It is part of the stored settings, so it goes into his backup.
      const on = AiSettings(outsideAllowed: true);
      expect(on.toJson()['outside'], isTrue);
      expect(AiSettings.fromJson(on.toJson()), on);
      expect(on.copyWith(outsideAllowed: false), const AiSettings());
      expect(const AiSettings() == on, isFalse);
    });
  });

  group('the controller', () {
    test('Send and Regenerate refuse while the switch is off', () async {
      final db = aiTestDatabase();
      await db.customSelect('SELECT 1').get();
      addTearDown(db.close);
      final (registry, anthropic, _) = fakeRegistry();
      var n = 0;
      final c = ChatController(
        store: ConversationStore(db),
        providers: registry,
        keys: AiKeyStore(MemorySecretStore({AiKeyStore.storageKey(AiProviderId.anthropic): testAnthropicKey})),
        clock: () => aiTestNow,
        newId: () => 'id-${n++}',
      );
      await c.load();
      c.setContext(const ChatContext.none());

      expect(c.blockFor('hi', hasKey: true, allowed: false), SendBlock.off);
      expect(
        c.blockFor('hi', hasKey: false, allowed: false),
        SendBlock.off,
        reason: 'the switch is the honest reason, not the key',
      );
      expect(await c.send('hi', settings: const AiSettings(), languageCode: 'ar'), isFalse);
      expect(await c.regenerate(settings: const AiSettings(), languageCode: 'ar'), isFalse);
      expect(anthropic.requests, isEmpty);
      expect(c.conversation.messages, isEmpty, reason: 'nothing was even written down');

      // With his switch on, the same tap goes through.
      expect(await c.send('hi', settings: const AiSettings(outsideAllowed: true), languageCode: 'ar'), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(anthropic.requests, hasLength(1));
      c.dispose();
    });
  });
}
