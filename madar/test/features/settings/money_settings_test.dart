// Settings › Money, inside the full app: the base currency and rates (the
// currencies screen, as a route), weeks per month (the budget's own sheet,
// saved with undo), the first day of the week (stored once, followed by the
// budget's weekly windows and the ledger's weekly views) and the debts' and
// bills' due reminders (the goals' own sheet) – each row summarising its
// current value, in both languages.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/budget_math.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/interaction/interaction.dart' show EditSheet;
import 'package:madar/core/routing/routes.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/money/budget/budget.dart';
import 'package:madar/features/money/hub/money_hub_logic.dart';
import 'package:madar/features/money/ledger/ledger.dart';
import 'package:madar/features/settings/money_settings_section.dart';

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
);

void main() {
  for (final lang in ['ar', 'en']) {
    testWidgets('$lang: the Money group summarises its four settings', (tester) async {
      await _settings(tester, lang: lang);
      final l = lookupL10n(Locale(lang));
      final section = find.byType(MoneySettingsSection);
      await _show(tester, section);
      expect(find.descendant(of: section, matching: find.text(l.moneyHubSettingsSection)), findsOneWidget);
      expect(find.text(l.moneyHubSettingsCurrencies), findsOneWidget);
      // The seeded currencies: JOD (base), USD, SYP, EGP, LYD.
      expect(find.textContaining(l.moneyHubSettingsCurrencyCount(5, lang == 'ar' ? '٥' : '5')), findsOneWidget);
      expect(find.text(l.moneyHubSettingsWeeks), findsOneWidget);
      expect(find.text(l.moneyHubSettingsWeekStart), findsOneWidget);
      expect(find.text(l.moneyHubWeekSaturday), findsOneWidget);
      expect(find.text(l.moneyHubSettingsReminders), findsOneWidget);
      expect(Directionality.of(tester.element(section)), lang == 'ar' ? TextDirection.rtl : TextDirection.ltr);
      await tester.pump(const Duration(seconds: 6));
    });
  }

  testWidgets('base currency & rates opens the currencies; back returns to Settings', (tester) async {
    final app = await _settings(tester);
    final l = lookupL10n(const Locale('en'));
    await _show(tester, find.text(l.moneyHubSettingsCurrencies));
    await tester.tap(find.text(l.moneyHubSettingsCurrencies));
    await settleApp(tester);
    expect(app.router.state.uri.toString(), AppRoutes.currencies);
    expect(find.byType(CurrenciesScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await settleApp(tester);
    expect(app.location, AppRoutes.settings);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('the week start is stored once and followed by the budget and the ledger', (tester) async {
    final app = await _settings(tester);
    final l = lookupL10n(const Locale('en'));
    expect(app.container.read(budgetWeekStartProvider), DateTime.saturday);
    await _show(tester, find.text(l.moneyHubWeekSunday));
    await tester.tap(find.text(l.moneyHubWeekSunday));
    await _writes(tester);
    final stored = await tester.runAsync(() => Repositories(app.db).keyValues.getJson(MoneySettings.weekStartKey));
    expect(stored, DateTime.sunday);
    expect(app.container.read(budgetWeekStartProvider), DateTime.sunday);
    expect(app.container.read(ledgerWeekStartProvider), DateTime.sunday);
    // The budget's weekly window starts on Sunday now (Sun 27 Sep 2026).
    final window = BudgetWindow.week(testNow, weekStart: app.container.read(budgetWeekStartProvider));
    expect(window.start, DateTime(2026, 9, 27));
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('weeks per month: the budget\'s own sheet, saved with undo', (tester) async {
    final app = await _settings(tester);
    final l = lookupL10n(const Locale('en'));
    await _show(tester, find.text(l.moneyHubSettingsWeeks));
    expect(find.text(l.moneyHubSettingsWeeksSummary('4')), findsOneWidget);
    await tester.tap(find.text(l.moneyHubSettingsWeeks));
    await tester.pumpAndSettle();
    expect(find.byType(BudgetWeeksSheet), findsOneWidget);
    await tester.tap(find.text(l.budgetWeeksCalendar));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(BudgetWeeksSheet), matching: find.text(l.actionSave)));
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text(l.budgetWeeksSaved), findsOneWidget, reason: 'the undo toast');
    final stored = await tester.runAsync(() => Repositories(app.db).keyValues.getJson(BudgetSettings.weeksPerMonthKey));
    expect(stored, isA<num>());
    expect(stored, isNot(4));
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('due reminders: the goals\' sheet; the row follows what was chosen', (tester) async {
    await _settings(tester);
    final l = lookupL10n(const Locale('en'));
    await _show(tester, find.text(l.moneyHubSettingsReminders));
    expect(find.textContaining('1 day before and on the day'), findsOneWidget);
    await tester.tap(find.text(l.moneyHubSettingsReminders));
    await tester.pumpAndSettle();
    expect(find.text(l.goalsRemindersTitle), findsWidgets);
    // Switched off.
    await tester.tap(find.descendant(of: find.byType(EditSheet), matching: find.text(l.goalsRemindersEnabled)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.actionSave).last);
    await _writes(tester);
    expect(find.text(l.moneyHubSettingsRemindersOff), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });
}
