// Accessibility guidelines on the settings pages and onboarding: 48 dp touch
// targets, a label on every tappable, and large text (up to 1.6×) without
// overflow in either language.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/onboarding/onboarding_screen.dart';

import '../../core/i18n/text_scan.dart';
import '../../helpers/test_app.dart';

const _pages = [
  AppRoutes.settings,
  AppRoutes.appearance,
  AppRoutes.sound,
  AppRoutes.licenses,
  AppRoutes.security,
  AppRoutes.prayerSettings,
  AppRoutes.adhanSettings,
];

void main() {
  for (final lang in ['ar', 'en']) {
    for (final page in _pages) {
      testWidgets('$page ($lang): 48 dp targets and labelled tappables', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpMadarApp(
          tester,
          settings: AppSettings(onboarded: true, languageCode: lang),
          initialLocation: page,
          settle: false,
        );
        await pumpFrames(tester);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });
    }

    for (final scale in [1.3, 1.6]) {
      for (final page in [..._pages, AppRoutes.import]) {
        testWidgets('$page ($lang) at $scale× text: no overflow, scrolled end to end', (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await pumpMadarApp(
            tester,
            settings: AppSettings(onboarded: true, languageCode: lang),
            initialLocation: page,
            settle: false,
          );
          await pumpFrames(tester);
          // Layout overflows are reported as exceptions; scroll the whole
          // page so every row gets laid out.
          final scrollable = find.byType(Scrollable);
          if (scrollable.evaluate().isNotEmpty) {
            for (var i = 0; i < 8; i++) {
              await tester.drag(scrollable.first, const Offset(0, -400), warnIfMissed: false);
              await pumpFrames(tester, total: const Duration(milliseconds: 300));
            }
          }
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('onboarding ($lang) at $scale× text: every step fits', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpMadarApp(tester, settings: AppSettings(languageCode: lang), settle: false);
        await pumpFrames(tester);
        final l = lookupL10n(Locale(lang));
        for (var step = 0; step < OnboardingScreen.stepCount - 1; step++) {
          await tester.tap(find.text(step == 0 ? l.onboardingBegin : l.actionContinue));
          await pumpFrames(tester);
          expect(tester.takeException(), isNull, reason: 'step ${step + 2}');
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('onboarding ($lang): 48 dp targets and labelled tappables on every step', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpMadarApp(tester, settings: AppSettings(languageCode: lang), settle: false);
      await pumpFrames(tester);
      final l = lookupL10n(Locale(lang));
      for (var step = 0; step < OnboardingScreen.stepCount; step++) {
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        if (step < OnboardingScreen.stepCount - 1) {
          await tester.tap(find.text(step == 0 ? l.onboardingBegin : l.actionContinue));
          await pumpFrames(tester);
        }
      }
      handle.dispose();
    });
  }
}
