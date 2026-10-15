// Digit-style audit: every string laid out on the app's screens follows the
// user's digit preference – Arabic-Indic (٠١٢…) in Arabic by default, Western
// in English by default, and either one when chosen explicitly in either
// language. A number typed into a string, a `'$n'` interpolation or an
// intl pattern that bypasses MadarFormatter shows up here.
import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/interaction/interaction.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/home/widgets/task_actions.dart';
import 'package:madar/features/onboarding/onboarding_screen.dart';
import 'package:madar/features/orbit/data/orbit_repository.dart';
import 'package:madar/features/settings/settings_screen.dart';

import '../../features/orbit/data/orbit_fixtures.dart';
import '../../features/orbit/presentation/orbit_scene_fixtures.dart';
import '../../helpers/test_app.dart';
import 'text_scan.dart';

/// The Digits picker names both scripts on purpose ("Western 123",
/// "Arabic-Indic ١٢٣").
Set<String> _bothScriptsOnPurpose(L10n l) => {
  '${l.settingsDigitsWestern} 123',
  '${l.settingsDigitsArabicIndic} ${Digits.toArabicIndic('123')}',
};

typedef _Case = ({String lang, DigitStyle digits, RegExp forbidden, String name});

final List<_Case> _cases = [
  (lang: 'ar', digits: DigitStyle.auto, forbidden: westernDigit, name: 'Arabic, automatic → Arabic-Indic'),
  (lang: 'ar', digits: DigitStyle.western, forbidden: easternDigit, name: 'Arabic, Western chosen'),
  (lang: 'en', digits: DigitStyle.auto, forbidden: easternDigit, name: 'English, automatic → Western'),
  (lang: 'en', digits: DigitStyle.arabicIndic, forbidden: westernDigit, name: 'English, Arabic-Indic chosen'),
];

Future<void> _seed(MadarDatabase db, String lang) async {
  final r = Repositories(db);
  await OrbitRepository(r).setPrayerSettings(hostPrayerSettings());
  await seedLivedIn(r, now: testNow, thriving: false, arabic: lang == 'ar');
}

/// Quranic text keeps the mushaf's own ayah numbers (Arabic-Indic inside
/// the end-of-ayah sign ۝), whatever the interface digits are.
bool _quranic(String s) => s.contains('\u06DD');

void _expectNoForbiddenDigits(WidgetTester tester, _Case c, String screen) {
  final allowed = _bothScriptsOnPurpose(lookupL10n(Locale(c.lang)));
  final offenders = [
    for (final s in paintedStrings(tester))
      if (c.forbidden.hasMatch(s) && !allowed.contains(s) && !_quranic(s)) s,
  ];
  expect(offenders, isEmpty, reason: '$screen – ${c.name}');
}

void main() {
  for (final c in _cases) {
    group(c.name, () {
      for (final (screen, location) in [
        ('settings', '/settings'),
        ('appearance', '/settings/appearance'),
        ('sound', '/settings/sound'),
        ('licenses', '/settings/licenses'),
        ('import', '/import'),
        ('home', '/'),
        ('planet page', '/planet/faith'),
        // Phase 2 pages, routed.
        ('prayer times', '/prayer-times'),
        ('prayer settings', '/settings/prayer'),
        ('prayer tracker', '/prayer-tracker'),
        ('tracker history', '/prayer-tracker?tab=history'),
        ('adhkar', '/adhkar'),
        ('adhkar reader', '/adhkar/morning'),
        ('tasbeeh', '/adhkar/tasbeeh'),
        ('adhan settings', '/settings/adhan'),
        ('security', '/settings/security'),
        // Phase 3 pages, routed.
        ('quran', '/quran'),
        ('quran reader', '/quran/read?ayah=2:255'),
        ('quran search', '/quran/search'),
        ('wird', '/wird'),
        ('hifz', '/hifz'),
        ('qibla', '/qibla'),
        ('quran settings', '/settings/quran'),
        ('recitation settings', '/settings/recitation'),
        ('reminders', '/settings/reminders'),
      ]) {
        testWidgets(screen, (tester) async {
          await pumpMadarApp(
            tester,
            settings: AppSettings(onboarded: true, languageCode: c.lang, digits: c.digits),
            initialLocation: location,
            settle: false,
            beforePump: (db) => _seed(db, c.lang),
          );
          await pumpFrames(tester);
          _expectNoForbiddenDigits(tester, c, screen);
        });
      }

      for (final sheet in ['edit sheet', 'move sheet', 'reminder sheet', 'undo toast']) {
        testWidgets(sheet, (tester) async {
          late MadarDatabase db;
          await pumpMadarApp(
            tester,
            settings: AppSettings(onboarded: true, languageCode: c.lang, digits: c.digits),
            initialLocation: '/settings',
            settle: false,
            beforePump: (d) async {
              db = d;
              await d
                  .into(d.tasks)
                  .insert(
                    TasksCompanion.insert(
                      title: 'Call',
                      window: const Value(PrayerWindow.asr),
                      date: Value(DateTime(testNow.year, testNow.month, testNow.day + 3)),
                    ),
                  );
            },
          );
          await pumpFrames(tester);
          final task = (await tester.runAsync(() => db.select(db.tasks).getSingle()))!;
          final element = tester.element(find.byType(SettingsScreen));
          final actions = TaskActions(element as WidgetRef, element);
          switch (sheet) {
            case 'edit sheet':
              unawaited(actions.edit(task));
            case 'move sheet':
              unawaited(actions.move(task));
            case 'reminder sheet':
              unawaited(actions.setReminder(task));
            default:
              unawaited(showUndoToast(element, UndoableAction(label: 'x', undo: () async {})));
          }
          await pumpFrames(tester);
          if (sheet != 'undo toast') expect(find.byType(InteractionSheetFrame), findsOneWidget);
          // The sheet really shows numbers (dates, times, the countdown) …
          final expected = identical(c.forbidden, westernDigit) ? easternDigit : westernDigit;
          expect(paintedStrings(tester).where(expected.hasMatch), isNotEmpty, reason: sheet);
          // … and every one of them in the chosen digits.
          _expectNoForbiddenDigits(tester, c, sheet);
          // Close whatever opened (the toast times out by itself).
          await tester.pump(const Duration(seconds: 20));
        });
      }

      testWidgets('onboarding (every step)', (tester) async {
        await pumpMadarApp(
          tester,
          settings: AppSettings(languageCode: c.lang, digits: c.digits),
          settle: false,
        );
        await pumpFrames(tester);
        final l = lookupL10n(Locale(c.lang));
        for (var step = 0; step < OnboardingScreen.stepCount; step++) {
          _expectNoForbiddenDigits(tester, c, 'onboarding step ${step + 1}');
          if (step < OnboardingScreen.stepCount - 1) {
            await tester.tap(find.text(step == 0 ? l.onboardingBegin : l.actionContinue));
            await pumpFrames(tester);
          }
        }
      });
    });
  }
}
