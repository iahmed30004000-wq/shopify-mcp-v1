// Settings › AI › Privacy opens with an honest notice: what the chat sends
// out of the phone (what he types, and the summary he approves), to whom
// (the service whose key he entered), and the fix that is coming (the
// model on the phone itself). It is a notice only – it changes nothing, so
// the keys, the service choice and the chat behave exactly as before.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/ai_chat/ai_chat.dart';

import 'ai_chat_harness.dart';

Future<L10n> _l10n(String lang) => L10n.delegate.load(Locale(lang));

void main() {
  for (final lang in ['ar', 'en']) {
    testWidgets('[$lang] the privacy notice names what goes out, to whom, and the fix', (tester) async {
      usePhone(tester);
      final l = await _l10n(lang);
      final (app, _) = await buildAiApp(tester, home: const AiSettingsScreen(), locale: Locale(lang));
      await tester.pumpWidget(app);
      await settleAsync(tester);
      await frames(tester, 12);

      final card = find.byKey(AiSettingsScreen.outsideNotice);
      expect(card, findsOneWidget);
      await tester.ensureVisible(card);
      await frames(tester, 6);

      // ⚠️ what leaves the phone, and to whom.
      expect(find.text(l.aiChatPrivacyOutsideTitle), findsOneWidget);
      expect(find.text(l.aiChatPrivacyOutsideBody), findsOneWidget);
      expect(l.aiChatPrivacyOutsideBody, contains('Anthropic'));
      expect(l.aiChatPrivacyOutsideBody, contains('OpenAI'));
      // 🔧 the fix that is coming.
      expect(find.text(l.aiChatPrivacyOutsideFix), findsOneWidget);

      // Nothing about the chat changed: no key is saved, both services
      // still say so, and the screen gained no new setting.
      expect(find.text(l.aiChatKeyNotSet), findsNWidgets(AiProviderId.values.length));
      expect(find.byKey(AiSettingsScreen.temperatureSwitch), findsOneWidget);
    });

    testWidgets('[$lang] the notice stays readable at text scale 1.3', (tester) async {
      usePhone(tester);
      final l = await _l10n(lang);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final (app, _) = await buildAiApp(tester, home: const AiSettingsScreen(), locale: Locale(lang));
      await tester.pumpWidget(app);
      await settleAsync(tester);
      await frames(tester, 12);
      await tester.ensureVisible(find.byKey(AiSettingsScreen.outsideNotice));
      await frames(tester, 6);
      expect(find.text(l.aiChatPrivacyOutsideBody), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
