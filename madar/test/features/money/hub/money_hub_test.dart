// The Money world's page is the hub of the user's money: the net worth in
// the base currency (wallets + jars + owed to you − you owe, a currency
// without a rate named with "Set rates"), one tap to an expense, income or
// transfer, the wallets (the ledger's summary), this month's plan (the
// budget's status), the dues and savings (bills and debts due soon, the
// jars' rings) and the tools – in both languages, every part opening its
// screen as a route. A Neglect Radar link to a debt opens its sheet once the
// world has landed. The hub's small decisions are pure.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/open.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/money/budget/budget.dart';
import 'package:madar/features/money/goals/goals.dart';
import 'package:madar/features/money/hub/money_hub.dart';
import 'package:madar/features/money/hub/money_hub_logic.dart';
import 'package:madar/features/money/hub/money_links.dart';
import 'package:madar/features/money/ledger/ledger.dart';
import 'package:madar/features/orbit/presentation/planet/planet_page.dart';
import 'package:madar/features/settings/money_settings_section.dart';

import '../../../helpers/test_app.dart';
import '../../lock/lock_test_utils.dart';
import 'money_hub_seed.dart';

Future<void> _frames(WidgetTester tester, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<TestApp> _moneyPage(
  WidgetTester tester, {
  String lang = 'en',
  Future<void> Function(MadarDatabase db)? seed,
  String? location,
}) async {
  final app = await pumpMadarApp(
    tester,
    settings: AppSettings(onboarded: true, languageCode: lang),
    initialLocation: location ?? AppRoutes.planetOf('money'),
    now: moneyHubNow,
    beforePump: seed ?? seedMoneyFresh,
    overrides: LockFixture.empty().overrides,
    settle: false,
  );
  await _frames(tester, 60);
  await settleApp(tester);
  return app;
}

final Finder _sheetFinder = find.descendant(of: find.byType(PlanetModulePage), matching: find.byType(Scrollable)).first;

/// Scrolls the planet page's sheet until [finder] is built and visible.
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 250, scrollable: _sheetFinder);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

/// A tool tile of the grid, by its semantics ("title. hint").
Finder _tool(String title) => find.bySemanticsLabel(RegExp('^${RegExp.escape(title)}\\. '));

String _netWorthText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('money-net-worth'))).data!;

void main() {
  group('pure', () {
    late MadarDatabase db;
    late Repositories repos;
    setUp(() async {
      db = await openInMemoryMadarDatabase();
      repos = Repositories(db);
    });
    tearDown(() => db.close());

    Future<MoneyNetWorth> worth() async {
      final book = await LedgerService(repos).book();
      final goals = GoalsSnapshot.build(
        today: moneyHubNow,
        jars: await repos.jars.getAll(),
        deposits: await repos.jarDeposits.getAll(),
        debts: await repos.debts.getAll(),
        debtPayments: await repos.debtPayments.getAll(),
        currencies: await repos.currencies.getAll(),
      );
      return MoneyNetWorth.of(book, goals);
    }

    test('net worth: wallets + jars + owed to you − you owe, exact in the base currency', () async {
      expect((await worth()).isEmpty, isTrue, reason: 'a fresh install');
      await seedMoneyHub(db);
      final w = await worth();
      expect(w.base, 'JOD');
      // Cash 300 − 120 − 75 lent; bank 1 500 − 130 + 500 − 300 into the
      // jar; 20 000 EGP × 0.0145 = 290.
      expect(w.walletsMilli, 105000 + 1570000 + 290000);
      expect(w.jarsMilli, 300000);
      expect(w.owedToMeMilli, 75000);
      expect(w.iOweMilli, 150000);
      expect(w.totalMilli, 2190000);
      expect((w.walletCount, w.jarCount, w.openDebtCount), (3, 1, 2));
      expect(w.missingRates, isEmpty);
      final s = w.shares;
      expect(s.wallets + s.jars + s.owed, closeTo(1, 1e-9));
      expect(s.jars, closeTo(300 / 2340, 1e-9));

      // A wallet in a currency with no rate is left out and named.
      await LedgerService(repos).addWallet(name: 'Travel card', currency: 'EUR', openingMilli: 100000);
      final missing = await worth();
      expect(missing.missingRates, {'EUR'});
      expect(missing.totalMilli, 2190000);

      // A repaid debt no longer counts.
      final goals = GoalsService(repos, clock: () => moneyHubNow);
      final debt = (await repos.debts.getAll()).firstWhere((d) => d.person == 'Khaled');
      await goals.addDebtPayment(debt.id, amountMilli: 150000);
      expect((await worth()).iOweMilli, 0);
    });

    test('an overdrawn wallet total takes no room in the strip', () {
      const w = MoneyNetWorth(base: 'JOD', walletsMilli: -5000, jarsMilli: 1000, walletCount: 1, jarCount: 1);
      expect(w.totalMilli, -4000);
      expect(w.shares, (wallets: 0.0, jars: 1.0, owed: 0.0));
      expect(const MoneyNetWorth(base: 'JOD').shares, (wallets: 0.0, jars: 0.0, owed: 0.0));
    });

    test('Money records lead to their screen or sheet', () {
      expect(MoneyLinks.targetOf('debts', 'd1'), const MoneyDebtTarget('d1'));
      expect(MoneyLinks.targetOf('debts', null), const MoneyRouteTarget('/goals?tab=debts'));
      expect(MoneyLinks.targetOf('obligations', 'o1'), const MoneyObligationTarget('o1'));
      expect(MoneyLinks.targetOf('obligations', ''), const MoneyRouteTarget('/goals?tab=obligations'));
      expect(MoneyLinks.targetOf('jars', 'j1'), const MoneyRouteTarget('/goals/jar/j1'));
      expect(MoneyLinks.targetOf('jars', null), const MoneyRouteTarget('/goals'));
      expect(MoneyLinks.targetOf('budget_items', 'b1'), const MoneyRouteTarget('/budget?tab=spending'));
      expect(MoneyLinks.targetOf('wallets', 'w1'), const MoneyRouteTarget('/ledger/wallet/w1'));
      expect(MoneyLinks.targetOf('transactions', null), const MoneyRouteTarget('/ledger'));
      expect(MoneyLinks.targetOf('currencies', null), const MoneyRouteTarget('/ledger/currencies'));
      expect(MoneyLinks.targetOf('medications', 'm1'), isNull);
      expect(MoneyLinks.targetOf(null, null), isNull);
    });

    test('the stored week start is read tolerantly', () {
      expect(MoneySettings.weekStartOf(DateTime.sunday), DateTime.sunday);
      expect(MoneySettings.weekStartOf(1.0), DateTime.monday);
      expect(MoneySettings.weekStartOf(null), DateTime.saturday);
      expect(MoneySettings.weekStartOf(0), DateTime.saturday);
      expect(MoneySettings.weekStartOf(6.5), DateTime.saturday);
      expect(MoneySettings.weekStartOf('7'), DateTime.saturday);
    });

    test('Settings › Money summaries, in both languages', () {
      final en = lookupL10n(const Locale('en'));
      final ar = lookupL10n(const Locale('ar'));
      const enFmt = MadarFormatter(languageCode: 'en');
      const arFmt = MadarFormatter();
      const reminders = GoalsReminderSettings();
      expect(MoneySettingsSummary.reminders(en, enFmt, reminders), '1 day before and on the day · at 9:00 AM');
      expect(MoneySettingsSummary.reminders(ar, arFmt, reminders), startsWith('قبل يوم وفي يومه · الساعة'));
      expect(
        MoneySettingsSummary.reminders(en, enFmt, reminders.copyWith(leadDays: 0)),
        'On the due day · at 9:00 AM',
      );
      expect(
        MoneySettingsSummary.reminders(en, enFmt, reminders.copyWith(leadDays: 3, onDueDay: false)),
        '3 days before · at 9:00 AM',
      );
      expect(MoneySettingsSummary.reminders(en, enFmt, reminders.copyWith(enabled: false)), 'Off');
      expect(MoneySettingsSummary.reminders(en, enFmt, reminders.copyWith(leadDays: 0, onDueDay: false)), 'Off');
      const currencies = [
        LedgerCurrency(code: 'USD', rateToBase: 0.709),
        LedgerCurrency(code: 'JOD', isBase: true),
      ];
      expect(MoneySettingsSummary.currencies(en, enFmt, currencies), '\u2068JOD\u2069 · 2 currencies');
      expect(MoneySettingsSummary.currencies(ar, arFmt, currencies), '\u2068JOD\u2069 · عملتان');
    });
  });

  for (final lang in ['ar', 'en']) {
    testWidgets('$lang fresh install: a calm hub whose tools lead to routes', (tester) async {
      final app = await _moneyPage(tester, lang: lang);
      final l = lookupL10n(Locale(lang));
      expect(find.byType(MoneyHub), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.byType(MoneyHub))),
        lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      );
      expect(find.text(l.moneyHubNetWorthTitle), findsOneWidget);
      expect(find.text(l.moneyHubNetWorthEmpty), findsOneWidget);
      expect(find.byType(MoneyQuickAddRow), findsOneWidget);
      await _reveal(tester, find.byType(WalletsSummaryCard));
      expect(find.text(l.ledgerSummaryEmpty), findsOneWidget);
      await _reveal(tester, find.byType(BudgetStatusCard));
      await _reveal(tester, find.byType(UpcomingDuesCard));
      await _reveal(tester, find.byType(JarsCard));
      await _reveal(tester, find.byType(MoneyTools));

      final tools = <(String, String)>[
        (l.moneyHubToolLedger, AppRoutes.ledger),
        (l.moneyHubToolTransactions, AppRoutes.transactions),
        (l.moneyHubToolBudget, AppRoutes.budget),
        (l.moneyHubToolJars, AppRoutes.goals),
        (l.moneyHubToolDebts, '/goals?tab=debts'),
        (l.moneyHubToolBills, '/goals?tab=obligations'),
      ];
      for (final (title, location) in tools) {
        app.sound.played.clear();
        await tester.tap(_tool(title));
        await settleApp(tester);
        expect(app.router.state.uri.toString(), location, reason: title);
        expect(app.sound.played, contains(Sfx.navigate));
        await tester.binding.handlePopRoute();
        await settleApp(tester);
        expect(find.byType(MoneyHub), findsOneWidget);
      }
      await tester.pump(const Duration(seconds: 6));
    });
  }

  testWidgets('en lived in: the net worth and its parts, then the four movements in order', (tester) async {
    final app = await _moneyPage(tester, seed: seedMoneyHub);
    final l = lookupL10n(const Locale('en'));
    expect(_netWorthText(tester), '2,190.000\u00A0\u2068JOD\u2069');
    final card = find.byType(MoneyNetWorthCard);
    expect(find.descendant(of: card, matching: find.text('1,965.000\u00A0\u2068JOD\u2069')), findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('300.000\u00A0\u2068JOD\u2069')), findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('75.000\u00A0\u2068JOD\u2069')), findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('-150.000\u00A0\u2068JOD\u2069')), findsOneWidget);
    expect(find.descendant(of: card, matching: find.text(l.ledgerFixRates)), findsNothing);

    double y(Finder f) => tester.getTopLeft(f).dy;
    expect(y(card), lessThan(y(find.byType(MoneyQuickAddRow))));
    await _reveal(tester, find.byType(WalletsSummaryCard));
    expect(find.descendant(of: find.byType(WalletsSummaryCard), matching: find.text('Bank')), findsOneWidget);
    await _reveal(tester, find.byType(BudgetStatusCard));
    expect(y(find.byType(WalletsSummaryCard)), lessThan(y(find.byType(BudgetStatusCard))));
    await _reveal(tester, find.byType(UpcomingDuesCard));
    final dues = find.byType(UpcomingDuesCard);
    expect(find.descendant(of: dues, matching: find.textContaining('Internet')), findsWidgets);
    expect(find.descendant(of: dues, matching: find.textContaining('Khaled')), findsWidgets);
    await _reveal(tester, find.byType(JarsCard));
    expect(find.descendant(of: find.byType(JarsCard), matching: find.text('Family trip')), findsOneWidget);

    // The plan card opens this month's spending (a plan exists).
    await _reveal(tester, find.byType(BudgetStatusCard));
    await tester.tap(find.byType(BudgetStatusCard));
    await settleApp(tester);
    expect(app.router.state.uri.toString(), AppRoutes.budgetOf(tab: 'spending'));
    await tester.binding.handlePopRoute();
    await settleApp(tester);

    // The wallets card opens the ledger.
    await _reveal(tester, find.byType(WalletsSummaryCard));
    await tester.tap(find.descendant(of: find.byType(WalletsSummaryCard), matching: find.text('Bank')));
    await settleApp(tester);
    expect(app.router.state.uri.toString(), AppRoutes.ledger);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('ar lived in: the net worth in Arabic digits, the parts in the reading direction', (tester) async {
    await _moneyPage(tester, lang: 'ar', seed: (db) => seedMoneyHub(db, arabic: true));
    final text = _netWorthText(tester);
    expect(text, startsWith('٢٬١٩٠٫٠٠٠'));
    expect(text, contains('د.أ'));
    final l = lookupL10n(const Locale('ar'));
    final wallets = find.text(l.moneyHubPartWallets);
    final jars = find.text(l.moneyHubPartJars);
    // Two by two: wallets at the start (right), jars beside it.
    expect(tester.getTopRight(wallets).dx, greaterThan(tester.getTopRight(jars).dx));
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('"Currencies" and a missing rate lead to the rates', (tester) async {
    final app = await _moneyPage(
      tester,
      seed: (db) async {
        await seedMoneyHub(db);
        await LedgerService(Repositories(db)).addWallet(name: 'Travel card', currency: 'EUR', openingMilli: 100000);
      },
    );
    final l = lookupL10n(const Locale('en'));
    final card = find.byType(MoneyNetWorthCard);
    expect(find.descendant(of: card, matching: find.textContaining('EUR', findRichText: true)), findsWidgets);
    await tester.tap(find.descendant(of: card, matching: find.text(l.ledgerFixRates)));
    await settleApp(tester);
    expect(app.router.state.uri.toString(), AppRoutes.currencies);
    await tester.binding.handlePopRoute();
    await settleApp(tester);
    await tester.tap(find.descendant(of: card, matching: find.text(l.moneyHubRatesAction)));
    await settleApp(tester);
    expect(app.router.state.uri.toString(), AppRoutes.currencies);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('one tap opens the entry sheet on its kind', (tester) async {
    final app = await _moneyPage(tester, seed: seedMoneyHub);
    final l = lookupL10n(const Locale('en'));
    for (final (hint, kind) in [
      (l.moneyHubAddExpenseHint, TxKind.expense),
      (l.moneyHubAddIncomeHint, TxKind.income),
      (l.moneyHubAddTransferHint, TxKind.transfer),
    ]) {
      app.sound.played.clear();
      await tester.tap(find.bySemanticsLabel(hint));
      await settleApp(tester);
      final sheet = tester.widget<TransactionSheet>(find.byType(TransactionSheet));
      expect(sheet.kind, kind);
      expect(app.sound.played, contains(Sfx.sheetOpen));
      await tester.binding.handlePopRoute();
      await settleApp(tester);
      expect(find.byType(TransactionSheet), findsNothing);
    }
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('a radar link to an overdue debt opens its sheet once the world has landed', (tester) async {
    late MoneyHubIds ids;
    final app = await _moneyPage(tester, seed: (db) async => ids = await seedMoneyHub(db), location: AppRoutes.home);
    app.router.go(AppRoutes.planetOf('money', item: 'debts:${ids.debtIOwe}'));
    await _frames(tester, 60);
    await settleApp(tester);
    expect(find.byType(PlanetModulePage), findsOneWidget);
    expect(find.byType(DebtSheet), findsOneWidget);
    expect(find.descendant(of: find.byType(DebtSheet), matching: find.text('Khaled')), findsWidgets);
    // Closing it leaves the Money page.
    await tester.binding.handlePopRoute();
    await settleApp(tester);
    expect(find.byType(DebtSheet), findsNothing);
    expect(find.byType(MoneyHub), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('Settings lists the Money group', (tester) async {
    await pumpMadarApp(
      tester,
      settings: const AppSettings(onboarded: true, languageCode: 'en'),
      initialLocation: AppRoutes.settings,
      overrides: LockFixture.empty().overrides,
    );
    await tester.scrollUntilVisible(find.byType(MoneySettingsSection), 300, scrollable: find.byType(Scrollable).first);
    expect(find.byType(MoneySettingsSection), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });
}
