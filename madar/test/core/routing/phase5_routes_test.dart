// Every Phase 5 (money) route builds its screen in Arabic and English inside
// the full app (router, gates, adhan host, app lock), with the app's shared-
// axis transition; the parameters (a wallet, a jar, the budget's and the
// goals' tabs, the transactions' filters) reach the screens; back leaves
// each page; a debt or an obligation named in the goals' location opens its
// sheet; the packages' own links (the ledger's screens, the goals' jar and
// tabs) open as routes; the location helpers and the filter codec are exact.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/motion/transitions.dart';
import 'package:madar/core/routing/money_route_pages.dart';
import 'package:madar/core/routing/router.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/money/budget/budget.dart';
import 'package:madar/features/money/goals/goals.dart';
import 'package:madar/features/money/ledger/ledger.dart';

import '../../features/lock/lock_test_utils.dart';
import '../../helpers/test_app.dart';

void main() {
  group('locations', () {
    test('ids and tabs are encoded; the home tab is the plain path', () {
      expect(AppRoutes.ledger, '/ledger');
      expect(AppRoutes.walletOf('a b/c'), '/ledger/wallet/a%20b%2Fc');
      expect(AppRoutes.transactionsOf(), '/ledger/transactions');
      expect(AppRoutes.transactionsOf(const {}), '/ledger/transactions');
      expect(
        AppRoutes.transactionsOf(const {
          'kind': ['expense', 'income'],
          'q': ['قهوة'],
        }),
        '/ledger/transactions?kind=expense&kind=income&q=%D9%82%D9%87%D9%88%D8%A9',
      );
      expect(AppRoutes.currencies, '/ledger/currencies');
      expect(AppRoutes.budgetOf(), '/budget');
      expect(AppRoutes.budgetOf(tab: 'plan'), '/budget');
      expect(AppRoutes.budgetOf(tab: 'spending'), '/budget?tab=spending');
      expect(AppRoutes.goalsOf(), '/goals');
      expect(AppRoutes.goalsOf(tab: 'jars'), '/goals');
      expect(AppRoutes.goalsOf(tab: 'debts'), '/goals?tab=debts');
      expect(AppRoutes.goalsOf(debt: 'd1'), '/goals?tab=debts&debt=d1');
      expect(AppRoutes.goalsOf(obligation: 'o 1'), '/goals?tab=obligations&obligation=o+1');
      expect(AppRoutes.jarOf('j/1'), '/goals/jar/j%2F1');
    });

    test('unknown tab names fall back; a named debt or obligation implies its tab', () {
      expect(BudgetRoutePage.tabOf('spending'), BudgetTab.spending);
      expect(BudgetRoutePage.tabOf('nope'), BudgetTab.plan);
      expect(GoalsRoutePage.tabOf('obligations'), GoalsTab.obligations);
      expect(GoalsRoutePage.tabOf(null), GoalsTab.jars);
      expect(GoalsRoutePage.tabFor(tab: 'jars', debtId: 'd'), GoalsTab.debts);
      expect(GoalsRoutePage.tabFor(obligationId: 'o'), GoalsTab.obligations);
      expect(GoalsRoutePage.tabFor(tab: 'debts', debtId: ''), GoalsTab.debts);
    });

    test('the transactions\' filters survive the location (unknown values dropped)', () {
      final f = TxFilter(
        walletIds: const {'w1', 'w2'},
        kinds: const {TxKind.income, TxKind.expense},
        budgetItemIds: const {'b1'},
        tags: const {'سفر', 'a,b'},
        from: DateTime(2026, 9, 1, 13),
        to: DateTime(2026, 9, 30),
        walletKind: WalletKind.business,
        query: ' coffee ',
      );
      final q = TxFilterQuery.encode(f);
      expect(q['kind'], ['expense', 'income'], reason: 'in the kinds\' own order');
      expect(q['from'], ['2026-09-01']);
      final location = AppRoutes.transactionsOf(q);
      final back = TxFilterQuery.decode(Uri.parse(location).queryParametersAll);
      expect(back.walletIds, {'w1', 'w2'});
      expect(back.kinds, {TxKind.expense, TxKind.income});
      expect(back.budgetItemIds, {'b1'});
      expect(back.tags, {'سفر', 'a,b'});
      expect(back.from, DateTime(2026, 9, 1));
      expect(back.to, DateTime(2026, 9, 30));
      expect(back.walletKind, WalletKind.business);
      expect(back.query, 'coffee');
      expect(back.unassignedOnly, isFalse);

      expect(TxFilterQuery.encode(TxFilter.none), isEmpty);
      final odd = TxFilterQuery.decode(const {
        'kind': ['expense', 'bribe'],
        'from': ['2026-02-31'],
        'to': ['yesterday'],
        'scope': ['secret'],
        'unassigned': ['1'],
      });
      expect(odd.kinds, {TxKind.expense});
      expect(odd.from, isNull, reason: 'an impossible day is dropped, never rolled over');
      expect(odd.to, isNull);
      expect(odd.walletKind, isNull);
      expect(odd.unassignedOnly, isTrue);
    });
  });

  final routes = <(String, Type)>[
    (AppRoutes.ledger, MoneyLedgerScreen),
    (AppRoutes.walletOf('missing'), WalletScreen),
    (AppRoutes.transactions, TransactionsScreen),
    (
      AppRoutes.transactionsOf(const {
        'kind': ['expense'],
      }),
      TransactionsScreen,
    ),
    (AppRoutes.currencies, CurrenciesScreen),
    (AppRoutes.budget, BudgetScreen),
    (AppRoutes.budgetOf(tab: 'spending'), BudgetScreen),
    (AppRoutes.goals, GoalsScreen),
    (AppRoutes.goalsOf(tab: 'obligations'), GoalsScreen),
    (AppRoutes.jarOf('missing'), JarScreen),
  ];

  for (final lang in ['ar', 'en']) {
    group(lang, () {
      for (final (location, type) in routes) {
        testWidgets('$location builds $type', (tester) async {
          final app = await pumpMadarApp(
            tester,
            settings: AppSettings(onboarded: true, languageCode: lang),
            initialLocation: location,
            overrides: LockFixture.empty().overrides,
          );
          expect(find.byType(type), findsOneWidget);
          expect(tester.takeException(), isNull);
          expect(app.router.state.uri.toString(), location);
          expect(
            Directionality.of(tester.element(find.byType(type))),
            lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          );
          expect(ModalRoute.of(tester.element(find.byType(type)))!.settings, isA<MadarTransitionPage<void>>());
          // Nested below home (or the ledger / the goals): back leaves the page.
          await tester.binding.handlePopRoute();
          await settleApp(tester);
          expect(find.byType(type), findsNothing);
          await tester.pump(const Duration(seconds: 6));
        });
      }
    });
  }

  testWidgets('the parameters reach the screens', (tester) async {
    final app = await pumpMadarApp(
      tester,
      initialLocation: AppRoutes.walletOf('w-7'),
      overrides: LockFixture.empty().overrides,
    );
    expect(tester.widget<WalletScreen>(find.byType(WalletScreen)).walletId, 'w-7');

    app.router.go(
      AppRoutes.transactionsOf(
        TxFilterQuery.encode(
          const TxFilter(walletIds: {'w-7'}, kinds: {TxKind.income}, tags: {'cod'}, query: 'Amman'),
        ),
      ),
    );
    await settleApp(tester);
    final filter = tester.widget<TransactionsScreen>(find.byType(TransactionsScreen)).filter;
    expect(filter.walletIds, {'w-7'});
    expect(filter.kinds, {TxKind.income});
    expect(filter.tags, {'cod'});
    expect(filter.query, 'Amman');

    app.router.go(AppRoutes.budgetOf(tab: 'spending'));
    await settleApp(tester);
    expect(tester.widget<BudgetScreen>(find.byType(BudgetScreen)).initialTab, BudgetTab.spending);

    app.router.go(AppRoutes.goalsOf(tab: 'debts'));
    await settleApp(tester);
    expect(tester.widget<GoalsScreen>(find.byType(GoalsScreen)).initialTab, GoalsTab.debts);

    app.router.go(AppRoutes.jarOf('j-3'));
    await settleApp(tester);
    expect(tester.widget<JarScreen>(find.byType(JarScreen)).jarId, 'j-3');
    // Nested under the goals: back returns there.
    await tester.binding.handlePopRoute();
    await settleApp(tester);
    expect(app.location, AppRoutes.goals);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('a debt or an obligation named in the location opens its sheet over its tab', (tester) async {
    late String debtId, obligationId;
    final app = await pumpMadarApp(
      tester,
      settings: const AppSettings(onboarded: true, languageCode: 'en'),
      initialLocation: AppRoutes.goals,
      overrides: LockFixture.empty().overrides,
      beforePump: (db) async {
        final goals = GoalsService(Repositories(db), clock: () => testNow);
        debtId = (await goals.addDebt(
          const DebtDraft(direction: DebtDirection.iOwe, person: 'Khaled', amountMilli: 120000, currency: 'JOD'),
        )).id;
        obligationId = (await goals.addObligation(
          ObligationDraft(
            name: 'Internet',
            amountMilli: 25000,
            currency: 'JOD',
            frequency: Recurrence.monthly,
            nextDue: DateTime(2026, 10, 1),
          ),
        )).id;
      },
    );
    app.router.go(AppRoutes.goalsOf(debt: debtId));
    await settleApp(tester);
    expect(tester.widget<GoalsScreen>(find.byType(GoalsScreen)).initialTab, GoalsTab.debts);
    expect(find.byType(DebtSheet), findsOneWidget);
    expect(find.text('Khaled'), findsWidgets);
    // Closing the sheet leaves the debts.
    await tester.binding.handlePopRoute();
    await settleApp(tester);
    expect(find.byType(DebtSheet), findsNothing);
    expect(find.byType(GoalsScreen), findsOneWidget);

    app.router.go(AppRoutes.goalsOf(obligation: obligationId));
    await settleApp(tester);
    expect(tester.widget<GoalsScreen>(find.byType(GoalsScreen)).initialTab, GoalsTab.obligations);
    expect(find.byType(ObligationSheet), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('the ledger\'s and the goals\' own links open as routes; back returns', (tester) async {
    final app = await pumpMadarApp(
      tester,
      settings: const AppSettings(onboarded: true, languageCode: 'en'),
      initialLocation: AppRoutes.ledger,
      overrides: LockFixture.empty().overrides,
    );
    final routes = app.container.read(ledgerRoutesProvider);
    expect(routes.budgetPicker, isNotNull, reason: "the budget package's picker");
    expect(routes.linked, isNotNull);
    expect(app.container.read(goalsNavigationProvider), isA<RoutedGoalsNavigation>());

    BuildContext ledger() => tester.element(find.byType(MoneyLedgerScreen));
    routes.currencies!(ledger());
    await settleApp(tester);
    expect(app.router.state.uri.toString(), AppRoutes.currencies);
    expect(find.byType(CurrenciesScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await settleApp(tester);
    expect(app.router.state.uri.toString(), AppRoutes.ledger);

    routes.transactions!(ledger(), const TxFilter(kinds: {TxKind.transfer}));
    await settleApp(tester);
    expect(app.router.state.uri.toString(), '/ledger/transactions?kind=transfer');
    await tester.binding.handlePopRoute();
    await settleApp(tester);

    routes.wallet!(ledger(), 'w1');
    await settleApp(tester);
    expect(app.router.state.uri.toString(), AppRoutes.walletOf('w1'));
    await tester.binding.handlePopRoute();
    await settleApp(tester);

    final nav = app.container.read(goalsNavigationProvider);
    unawaited(nav.openGoals(ledger(), tab: GoalsTab.obligations));
    await settleApp(tester);
    expect(app.router.state.uri.toString(), '/goals?tab=obligations');
    await tester.binding.handlePopRoute();
    await settleApp(tester);
    expect(app.router.state.uri.toString(), AppRoutes.ledger);
    await tester.pump(const Duration(seconds: 6));
  });
}
