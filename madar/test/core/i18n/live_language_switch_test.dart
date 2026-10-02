// The language switch flips the whole app instantly – no restart, no stale
// strings, no stuck direction – including sheets and toasts already open,
// and the digits and typography that follow the language.
import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/tokens.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/interaction/interaction.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/home/widgets/task_actions.dart';
import 'package:madar/features/onboarding/onboarding_screen.dart';
import 'package:madar/features/settings/appearance_screen.dart';
import 'package:madar/features/settings/settings_screen.dart';

import '../../helpers/test_app.dart';
import 'text_scan.dart';

final _ar = lookupL10n(const Locale('ar'));
final _en = lookupL10n(const Locale('en'));

/// Painted strings that still carry Arabic letters, apart from [allowed]
/// (the language picker names Arabic in Arabic; user data stays as typed).
List<String> _arabicLeft(WidgetTester tester, {Set<String> allowed = const {}}) => [
  for (final s in paintedStrings(tester))
    if (arabicLetter.hasMatch(s) && !allowed.contains(s)) s,
];

/// Painted strings that still carry Latin letters, apart from [allowed].
List<String> _latinLeft(WidgetTester tester, {Set<String> allowed = const {}}) => [
  for (final s in paintedStrings(tester))
    if (latinLetter.hasMatch(s) && !allowed.contains(s)) s,
];

Future<void> _seedTask(MadarDatabase db) => db
    .into(db.tasks)
    .insert(
      TasksCompanion.insert(
        title: 'الاتصال بالوالدة',
        window: const Value(PrayerWindow.asr),
        date: Value(DateTime(testNow.year, testNow.month, testNow.day)),
      ),
    );

void main() {
  testWidgets('Appearance: the language pills flip every string and the direction in one frame', (tester) async {
    final app = await pumpMadarApp(tester, initialLocation: AppRoutes.appearance, settle: false);
    await pumpFrames(tester);
    final screen = find.byType(AppearanceScreen);
    final state = tester.element(screen);
    expect(Directionality.of(state), TextDirection.rtl);
    expect(_latinLeft(tester, allowed: {_ar.settingsLanguageEnglish}), isEmpty);

    await tester.ensureVisible(find.text(_ar.settingsLanguageEnglish));
    await tester.pump();
    await tester.tap(find.text(_ar.settingsLanguageEnglish));
    await tester.pump();

    // One frame later: English, left to right, same screen element.
    expect(app.settings.languageCode, 'en');
    expect(identical(tester.element(screen), state), isTrue);
    expect(Directionality.of(tester.element(screen)), TextDirection.ltr);
    expect(find.text(_en.settingsAppearance), findsWidgets);
    expect(_arabicLeft(tester, allowed: {_en.settingsLanguageArabic}), isEmpty);
    // Western digits (automatic style) at once …
    expect(MadarFormatter.of(tester.element(screen)).formatInt(12345), '12,345');
    expect(
      paintedStrings(tester).where(easternDigit.hasMatch).where((s) => !s.startsWith(_en.settingsDigitsArabicIndic)),
      isEmpty,
    );
    // … and Latin line metrics once the theme's cross-fade has run.
    await pumpFrames(tester, total: const Duration(milliseconds: 800));
    expect(Theme.of(tester.element(screen)).textTheme.bodyMedium!.height, 1.3);

    await tester.tap(find.text(_en.settingsLanguageArabic));
    await tester.pump();
    expect(app.settings.languageCode, 'ar');
    expect(Directionality.of(tester.element(screen)), TextDirection.rtl);
    expect(_latinLeft(tester, allowed: {_ar.settingsLanguageEnglish, '${_ar.settingsDigitsWestern} 123'}), isEmpty);
    expect(MadarFormatter.of(tester.element(screen)).formatInt(12345), '١٢٬٣٤٥');
    await pumpFrames(tester, total: const Duration(milliseconds: 800));
    expect(Theme.of(tester.element(screen)).textTheme.bodyMedium!.height, 1.5);
    await settleApp(tester);
  });

  testWidgets('line metrics follow the language in the same frame (no half-second reflow)', (tester) async {
    await pumpMadarApp(tester, initialLocation: AppRoutes.appearance, settle: false);
    await pumpFrames(tester);
    final screen = find.byType(AppearanceScreen);
    // A section title: its line height comes straight from the theme.
    final title = find.text(_ar.settingsDigits).first;
    await tester.ensureVisible(title);
    await tester.pump();
    final arabicHeight = tester.getSize(title).height;
    await tester.ensureVisible(find.text(_ar.settingsLanguageEnglish));
    await tester.pump();
    await tester.tap(find.text(_ar.settingsLanguageEnglish));
    await tester.pump();
    // The very next frame already lays text out with Latin metrics …
    expect(Theme.of(tester.element(screen)).textTheme.bodyMedium!.height, 1.3);
    final englishTitle = find.text(_en.settingsDigits).first;
    final firstFrame = tester.getSize(englishTitle).height;
    expect(firstFrame, lessThan(arabicHeight));
    // … and nothing moves while the theme's colours settle.
    await pumpFrames(tester, total: const Duration(milliseconds: 800));
    expect(tester.getSize(englishTitle).height, firstFrame);

    await tester.tap(find.text(_en.settingsLanguageArabic));
    await tester.pump();
    expect(Theme.of(tester.element(screen)).textTheme.bodyMedium!.height, 1.5);
    expect(Theme.of(tester.element(screen)).textTheme.labelLarge!.letterSpacing, 0);
    await settleApp(tester);
  });

  testWidgets('Settings hub: no stale string anywhere after a switch from elsewhere', (tester) async {
    final app = await pumpMadarApp(tester, initialLocation: AppRoutes.settings, settle: false);
    await pumpFrames(tester);
    app.updateSettings((s) => s.copyWith(languageCode: 'en'));
    await tester.pump();
    expect(Directionality.of(tester.element(find.byType(SettingsScreen))), TextDirection.ltr);
    expect(_arabicLeft(tester), isEmpty);
    expect(find.text(_en.settingsTitle), findsOneWidget);

    app.updateSettings((s) => s.copyWith(languageCode: 'ar'));
    await tester.pump();
    expect(Directionality.of(tester.element(find.byType(SettingsScreen))), TextDirection.rtl);
    expect(find.text(_en.settingsTitle), findsNothing);
    // Only Arabic strings remain (some name a technical term like JSON).
    expect(paintedStrings(tester).where((s) => latinLetter.hasMatch(s) && !arabicLetter.hasMatch(s)), isEmpty);
    await settleApp(tester);
  });

  testWidgets('an open sheet follows the switch: its strings, direction and digits flip in place', (tester) async {
    final app = await pumpMadarApp(tester, initialLocation: AppRoutes.settings, settle: false, beforePump: _seedTask);
    await pumpFrames(tester);
    final task = (await tester.runAsync(() => app.db.select(app.db.tasks).getSingle()))!;
    final element = tester.element(find.byType(SettingsScreen));
    unawaited(TaskActions(element as WidgetRef, element).setReminder(task));
    await pumpFrames(tester);
    final frame = find.byType(InteractionSheetFrame);
    expect(frame, findsOneWidget);
    expect(find.text(_ar.interactionReminderTitle), findsOneWidget);
    expect(find.text(_ar.actionSave), findsOneWidget);
    final route = ModalRoute.of(tester.element(frame));

    app.updateSettings((s) => s.copyWith(languageCode: 'en'));
    await tester.pump();

    // The same sheet, still open, now English and left to right.
    expect(frame, findsOneWidget);
    expect(identical(ModalRoute.of(tester.element(frame)), route), isTrue);
    expect(Directionality.of(tester.element(frame)), TextDirection.ltr);
    expect(find.text(_en.interactionReminderTitle), findsOneWidget);
    expect(find.text(_en.actionSave), findsOneWidget);
    expect(find.text(_ar.actionSave), findsNothing);
    // Once the summary line's cross-fade has run, nothing Arabic is left.
    await pumpFrames(tester, total: const Duration(milliseconds: 500));
    final inSheet = [
      for (final e in find.descendant(of: frame, matching: find.byType(RichText)).evaluate())
        (e.widget as RichText).text.toPlainText(),
    ];
    expect(inSheet.where(arabicLetter.hasMatch), isEmpty, reason: '$inSheet');
    expect(inSheet.where(easternDigit.hasMatch), isEmpty, reason: '$inSheet');

    // And back.
    app.updateSettings((s) => s.copyWith(languageCode: 'ar'));
    await tester.pump();
    expect(Directionality.of(tester.element(frame)), TextDirection.rtl);
    expect(find.text(_ar.actionSave), findsOneWidget);
    await tester.tap(find.text(_ar.actionCancel));
    await settleApp(tester);
  });

  testWidgets('an open undo toast follows the switch', (tester) async {
    final app = await pumpMadarApp(tester, initialLocation: AppRoutes.settings, settle: false);
    await pumpFrames(tester);
    final element = tester.element(find.byType(SettingsScreen));
    unawaited(showUndoToast(element, UndoableAction(label: _ar.itemDeleted, undo: () async {})));
    await pumpFrames(tester, total: const Duration(milliseconds: 500));
    expect(find.text(_ar.actionUndo), findsOneWidget);

    app.updateSettings((s) => s.copyWith(languageCode: 'en'));
    await tester.pump();
    expect(find.text(_en.actionUndo), findsOneWidget);
    expect(Directionality.of(tester.element(find.text(_en.actionUndo))), TextDirection.ltr);
    // The countdown switched to Western digits.
    expect(paintedStrings(tester).where(easternDigit.hasMatch), isEmpty);
    await tester.pump(const Duration(seconds: 20));
    await settleApp(tester);
  });

  testWidgets('an open sheet follows a theme change too (scrim and glass)', (tester) async {
    final app = await pumpMadarApp(tester, initialLocation: AppRoutes.settings, settle: false, beforePump: _seedTask);
    await pumpFrames(tester);
    final task = (await tester.runAsync(() => app.db.select(app.db.tasks).getSingle()))!;
    final element = tester.element(find.byType(SettingsScreen));
    unawaited(TaskActions(element as WidgetRef, element).setReminder(task));
    await pumpFrames(tester);
    final frame = find.byType(InteractionSheetFrame);

    app.updateSettings((s) => s.copyWith(themeId: MadarThemeId.pearl));
    await pumpFrames(tester);
    expect(tester.element(frame).tokens, MadarPalettes.tokensFor(MadarThemeId.pearl));
    // The barrier's scrim is painted from the live theme, not the one the
    // sheet was opened in.
    final barrier = find.ancestor(of: find.byType(ModalBarrier).last, matching: find.byType(Stack)).first;
    final scrim = tester.widget<ColoredBox>(find.descendant(of: barrier, matching: find.byType(ColoredBox)).first);
    expect(scrim.color.withValues(alpha: 1), MadarPalettes.tokensFor(MadarThemeId.pearl).space0);
    await tester.tap(find.text(_ar.actionCancel));
    await settleApp(tester);
  });

  testWidgets('onboarding: picking English on step 2 flips the page and the step counter at once', (tester) async {
    final app = await pumpMadarApp(tester, settings: const AppSettings(), settle: false);
    await pumpFrames(tester);
    await tester.tap(find.text(_ar.onboardingBegin));
    await pumpFrames(tester);
    final screen = find.byType(OnboardingScreen);
    expect(Directionality.of(tester.element(screen)), TextDirection.rtl);

    await tester.tap(find.text(_ar.settingsLanguageEnglish));
    await tester.pump();
    expect(app.settings.languageCode, 'en');
    expect(Directionality.of(tester.element(screen)), TextDirection.ltr);
    expect(find.text(_en.onboardingStyleTitle), findsOneWidget);
    expect(_arabicLeft(tester, allowed: {_en.settingsLanguageArabic}), isEmpty);
    await settleApp(tester);
  });
}
