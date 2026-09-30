// Settings › Life, inside the full app: right after Money, the family's
// reach-out reminders (their own sheet), the daily water target (Body's
// sheet, stored for the orbit), fasting (Body › Fasting), the packing lists
// (Travel › Packing lists) and the user's trackers – each row summarising
// its current value, in both languages, and fitting at 1.3× text.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/interaction/interaction.dart' show SheetButton;
import 'package:madar/core/routing/routes.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/body/body.dart' show BodyScreen, BodyTab;
import 'package:madar/features/custom_modules/custom_modules.dart';
import 'package:madar/features/family/family.dart' show FamilySettings, FamilySettingsSheet;
import 'package:madar/features/settings/life_settings_section.dart';
import 'package:madar/features/settings/money_settings_section.dart';
import 'package:madar/features/travel/travel.dart' show TravelScreen, TravelTab;

import '../../helpers/test_app.dart';
import '../lock/lock_test_utils.dart';

/// Scrolls the settings until [finder] is built, then centres it.
Future<void> _show(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await Scrollable.ensureVisible(tester.element(finder.first), alignment: 0.5);
  await tester.pumpAndSettle();
}

/// Lets database writes started by a tap land.
Future<void> _writes(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}

Future<TestApp> _settings(WidgetTester tester, {String lang = 'en'}) => pumpMadarApp(
  tester,
  settings: AppSettings(onboarded: true, languageCode: lang),
  initialLocation: AppRoutes.settings,
  overrides: LockFixture.empty().overrides,
  beforePump: (db) async {
    final modules = CustomModulesService(Repositories(db));
    for (final name in ['Reading', 'Sleep', 'Groceries']) {
      await modules.createModule(
        ModuleTemplates.build(ModuleTemplateKey.readingLog, (t) => t.name).copyWith(name: name),
      );
    }
  },
);

void main() {
  test('the family summary: the digest and its time, birthdays only, or off', () async {
    await initializeDateFormatting();
    final en = lookupL10n(const Locale('en'));
    final ar = lookupL10n(const Locale('ar'));
    const enFmt = MadarFormatter(languageCode: 'en');
    const arFmt = MadarFormatter();
    expect(LifeSettingsSummary.family(en, enFmt, const FamilySettings()), 'Daily digest at ${enFmt.formatClock(20, 0)}');
    expect(LifeSettingsSummary.family(ar, arFmt, const FamilySettings()), startsWith('ملخّص يومي الساعة'));
    expect(
      LifeSettingsSummary.family(en, enFmt, const FamilySettings(digestEnabled: false)),
      en.lifeHubSettingsFamilyBirthdays,
    );
    expect(
      LifeSettingsSummary.family(en, enFmt, const FamilySettings(digestEnabled: false, birthdaysEnabled: false)),
      en.lifeHubSettingsFamilyOff,
    );
  });

  for (final lang in ['ar', 'en']) {
    testWidgets('$lang: the Life group follows Money and summarises its five settings', (tester) async {
      await _settings(tester, lang: lang);
      final l = lookupL10n(Locale(lang));
      final fmt = MadarFormatter(languageCode: lang);
      final section = find.byType(LifeSettingsSection);
      await _show(tester, section);
      expect(find.descendant(of: section, matching: find.text(l.lifeHubSettingsSection)), findsOneWidget);
      expect(find.descendant(of: section, matching: find.text(l.lifeHubSettingsSectionHint)), findsOneWidget);
      final money = find.byType(MoneySettingsSection);
      expect(money, findsOneWidget, reason: 'Money sits just above');
      expect(tester.getTopLeft(money).dy, lessThan(tester.getTopLeft(section).dy));
      Finder row(String text) => find.descendant(of: section, matching: find.text(text));
      expect(row(l.familyRemindersTitle), findsOneWidget);
      expect(row(l.lifeHubSettingsFamilyOn(fmt.formatClock(20, 0))), findsOneWidget);
      expect(row(l.bodyWaterTargetTitle), findsOneWidget);
      expect(row(l.lifeHubSettingsWaterValue(fmt.formatInt(2500))), findsOneWidget);
      expect(row(l.bodyFastingTitle), findsOneWidget);
      expect(row(l.travelTabTemplates), findsOneWidget);
      expect(row(l.cmodTitle), findsOneWidget);
      expect(row(l.lifeHubSettingsModulesCount(3, fmt.formatInt(3))), findsOneWidget);
      expect(Directionality.of(tester.element(section)), lang == 'ar' ? TextDirection.rtl : TextDirection.ltr);
      await tester.pump(const Duration(seconds: 6));
    });
  }

  testWidgets('reach-out reminders open their own sheet', (tester) async {
    await _settings(tester);
    final l = lookupL10n(const Locale('en'));
    await _show(tester, find.text(l.familyRemindersTitle));
    await tester.tap(find.text(l.familyRemindersTitle));
    await tester.pumpAndSettle();
    expect(find.byType(FamilySettingsSheet), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(FamilySettingsSheet), findsNothing);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('the water target: Body\'s sheet, stored for the orbit', (tester) async {
    final app = await _settings(tester);
    final l = lookupL10n(const Locale('en'));
    await _show(tester, find.text(l.bodyWaterTargetTitle));
    await tester.tap(find.text(l.bodyWaterTargetTitle));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '3000');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SheetButton, l.bodySave));
    await _writes(tester);
    final stored = await tester.runAsync(() => Repositories(app.db).keyValues.getJson('body.waterTargetMl'));
    expect(stored, 3000);
    expect(find.text(l.lifeHubSettingsWaterValue('3,000')), findsOneWidget, reason: 'the row follows');
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('fasting, the packing lists and the trackers open over Settings; back returns', (tester) async {
    final app = await _settings(tester);
    final l = lookupL10n(const Locale('en'));
    for (final (title, location, screen) in [
      (l.bodyFastingTitle, '/body?tab=fasting', BodyScreen),
      (l.travelTabTemplates, '/travel?tab=templates', TravelScreen),
      (l.cmodTitle, AppRoutes.modules, CustomModulesScreen),
    ]) {
      final row = find.descendant(of: find.byType(LifeSettingsSection), matching: find.text(title));
      await _show(tester, row);
      await tester.tap(row);
      await settleApp(tester);
      expect(app.router.state.uri.toString(), location, reason: title);
      expect(find.byType(screen), findsOneWidget);
      await tester.binding.handlePopRoute();
      await settleApp(tester);
      expect(app.location, AppRoutes.settings);
    }
    await _show(tester, find.byType(LifeSettingsSection));
    app.router.go(AppRoutes.bodyOf(tab: 'fasting'));
    await settleApp(tester);
    expect(tester.widget<BodyScreen>(find.byType(BodyScreen)).initialTab, BodyTab.fasting);
    app.router.go(AppRoutes.travelOf(tab: 'templates'));
    await settleApp(tester);
    expect(tester.widget<TravelScreen>(find.byType(TravelScreen)).initialTab, TravelTab.templates);
    await tester.pump(const Duration(seconds: 6));
  });

  for (final lang in ['ar', 'en']) {
    testWidgets('$lang at 1.3× text: the Life group fits', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _settings(tester, lang: lang);
      final section = find.byType(LifeSettingsSection);
      await _show(tester, section);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 6));
    });
  }
}
