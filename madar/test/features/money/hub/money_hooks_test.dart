// The money packages wired together in the app:
// * an entry the goals package booked into a wallet (a jar movement, a debt
//   payment, a debt lent from a wallet, a bill paid) leads back to its jar,
//   debt or bill – and stays protected in the ledger (no edit, move or
//   delete of one half);
// * in the full app a tap on such a row opens the jar (a route) or the
//   debt (its sheet);
// * the ledger's transaction sheet picks its budget item with the budget
//   package's tree picker, and the pick is saved on the entry;
// * the home quick-add writes through the ledger (`money.tx`), so the
//   ledger, the budget and the Money world all see it.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/open.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/interaction/quick_add/parser.dart';
import 'package:madar/core/interaction/quick_add/quick_add_handler.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/money/budget/budget.dart';
import 'package:madar/features/money/goals/goals.dart';
import 'package:madar/features/money/hub/money_links.dart';
import 'package:madar/features/money/ledger/ledger.dart';
import 'package:madar/features/money/ledger/presentation/widgets/tx_tile.dart';

import '../../../helpers/test_app.dart';
import '../../lock/lock_test_utils.dart';
import 'money_hub_seed.dart';

Future<void> _writes(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 200));
  }
  await settleApp(tester);
}

void main() {
  group('linked entries', () {
    late MadarDatabase db;
    late Repositories repos;
    late MoneyHubIds ids;
    late GoalsService goals;
    late LedgerService ledger;
    setUp(() async {
      db = await openInMemoryMadarDatabase();
      repos = Repositories(db);
      ids = await seedMoneyHub(db);
      goals = GoalsService(repos, clock: () => moneyHubNow);
      ledger = LedgerService(repos, clock: () => moneyHubNow);
    });
    tearDown(() => db.close());

    Future<LedgerTx> entry(bool Function(LedgerTx tx) where) async => (await ledger.book()).transactions.firstWhere(where);

    test('lead back to their jar, debt or bill', () async {
      final jarTx = await entry((t) => t.id.startsWith(LedgerLinks.jarPrefix));
      expect(await MoneyLinks.linkedTarget(repos, jarTx, LedgerLink.jar), MoneyRouteTarget(AppRoutes.jarOf(ids.jar)));

      final opening = await entry((t) => t.id.startsWith(LedgerLinks.debtOpenPrefix));
      expect(LedgerLinks.of(opening), LedgerLink.debt);
      expect(await MoneyLinks.linkedTarget(repos, opening, LedgerLink.debt), MoneyDebtTarget(ids.debtOwed));

      await goals.addDebtPayment(ids.debtOwed, amountMilli: 25000, walletId: ids.cash);
      final repaid = await entry((t) => t.id.startsWith(LedgerLinks.debtPrefix));
      expect(await MoneyLinks.linkedTarget(repos, repaid, LedgerLink.debt), MoneyDebtTarget(ids.debtOwed));

      await goals.payObligation(ids.internet);
      final bill = await entry((t) => t.id.startsWith(LedgerLinks.obligationPrefix));
      expect(
        await MoneyLinks.linkedTarget(repos, bill, LedgerLink.obligation),
        MoneyObligationTarget(ids.internet),
      );
      // "Paid" moved the bill on by a month.
      expect((await repos.obligations.byId(ids.internet))!.nextDue, DateTime(2026, 11, 1));

      // The other half gone: its tab.
      final move = (await repos.jarDeposits.getAll()).single;
      await repos.jarDeposits.delete(move.id);
      expect(await MoneyLinks.linkedTarget(repos, jarTx, LedgerLink.jar), const MoneyRouteTarget('/goals'));
      final plain = LedgerTx(id: 'plain', walletId: 'w', kind: TxKind.expense, amountMilli: 1, date: moneyHubNow);
      expect(await MoneyLinks.linkedTarget(repos, plain, LedgerLink.jar), isNull);
    });

    test('stay protected in the ledger – a debt lent from a wallet too', () async {
      final opening = await entry((t) => t.id.startsWith(LedgerLinks.debtOpenPrefix));
      final jarTx = await entry((t) => t.id.startsWith(LedgerLinks.jarPrefix));
      for (final tx in [opening, jarTx]) {
        await expectLater(
          ledger.update(
            tx.id,
            TxWrite(walletId: tx.walletId, kind: tx.kind, amountMilli: 1, date: moneyHubNow),
          ),
          throwsA(isA<LedgerLinkedEntryException>()),
        );
        await expectLater(ledger.delete(tx.id), throwsA(isA<LedgerLinkedEntryException>()));
        expect(await ledger.move(tx.id, ids.egypt, await ledger.book()), isNull);
      }
      // The pair is intact: the lent money still left the cash wallet.
      final book = await ledger.book();
      expect(book.balances[ids.cash], 300000 - 120000 - 75000);
    });
  });

  testWidgets('in the ledger a jar entry opens the jar, a lent-money entry the debt', (tester) async {
    late MoneyHubIds ids;
    final app = await pumpMadarApp(
      tester,
      settings: const AppSettings(onboarded: true, languageCode: 'en'),
      now: moneyHubNow,
      overrides: LockFixture.empty().overrides,
      beforePump: (db) async => ids = await seedMoneyHub(db),
    );
    app.router.go(AppRoutes.walletOf(ids.bank));
    await settleApp(tester);
    final jarRow = find.byWidgetPredicate((w) => w is TxTile && w.tx.id.startsWith(LedgerLinks.jarPrefix));
    await tester.scrollUntilVisible(jarRow, 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(jarRow);
    await _writes(tester);
    expect(app.router.state.uri.toString(), AppRoutes.jarOf(ids.jar));
    expect(find.byType(JarScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await settleApp(tester);
    expect(app.router.state.uri.toString(), AppRoutes.walletOf(ids.bank));

    app.router.go(AppRoutes.walletOf(ids.cash));
    await settleApp(tester);
    final lent = find.byWidgetPredicate((w) => w is TxTile && w.tx.id.startsWith(LedgerLinks.debtOpenPrefix));
    await tester.scrollUntilVisible(lent, 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(lent);
    await _writes(tester);
    expect(find.byType(DebtSheet), findsOneWidget);
    expect(tester.widget<DebtSheet>(find.byType(DebtSheet)).debtId, ids.debtOwed);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets("the transaction sheet picks its budget item with the budget's tree picker", (tester) async {
    late MoneyHubIds ids;
    final app = await pumpMadarApp(
      tester,
      settings: const AppSettings(onboarded: true, languageCode: 'en'),
      now: moneyHubNow,
      initialLocation: AppRoutes.ledger,
      overrides: LockFixture.empty().overrides,
      beforePump: (db) async => ids = await seedMoneyHub(db),
    );
    unawaited(showTransactionSheet(tester.element(find.byType(MoneyLedgerScreen)), walletId: ids.cash));
    await settleApp(tester);
    expect(find.byType(TransactionSheet), findsOneWidget);
    // Amount 12.5 on the keypad.
    for (final key in ['1', '2', '.', '5']) {
      await tester.tap(find.descendant(of: find.byType(TransactionSheet), matching: find.text(key)).last);
      await tester.pump(const Duration(milliseconds: 50));
    }
    final field = find.text(lookupL10n(const Locale('en')).ledgerChooseItem);
    await tester.scrollUntilVisible(field, 150, scrollable: find.byType(Scrollable).last);
    await tester.tap(field);
    await settleApp(tester);
    expect(find.byType(BudgetPicker), findsOneWidget, reason: "the budget package's picker");
    await tester.tap(find.descendant(of: find.byType(BudgetPicker), matching: find.text('Car fuel')));
    await settleApp(tester);
    expect(find.byType(BudgetPicker), findsNothing);
    expect(find.descendant(of: find.byType(TransactionSheet), matching: find.text('Car fuel')), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(TransactionSheet), matching: find.text('Save')).last);
    await _writes(tester);
    final rows = (await tester.runAsync(() => Repositories(app.db).transactions.getAll()))!;
    final saved = rows.where((r) => r.amountMilli == 12500).single;
    expect(saved.budgetItemId, ids.fuel);
    expect(saved.walletId, ids.cash);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('the home quick-add writes through the ledger (money.tx)', (tester) async {
    final app = await pumpMadarApp(
      tester,
      settings: const AppSettings(onboarded: true, languageCode: 'en'),
      now: moneyHubNow,
      overrides: LockFixture.empty().overrides,
      beforePump: seedMoneyHub,
    );
    final handler = app.container.read(quickAddHandlerProvider)!;
    final handled = Completer<bool>();
    unawaited(handler.handle(QuickAddParser.parse('spent 7 JOD coffee', now: moneyHubNow)).then(handled.complete));
    await _writes(tester);
    expect(await handled.future, isTrue);
    final repos = Repositories(app.db);
    final tx = (await tester.runAsync(() => repos.transactions.getAll()))!.where((t) => t.note == 'coffee').single;
    expect((tx.kind, tx.amountMilli), (TxKind.expense, 7000));
    final activity = (await tester.runAsync(() => repos.activity.since(DateTime(2026, 9, 29), planetKey: 'money')))!;
    expect(activity.where((a) => a.refId == tx.id).single.kind, LedgerService.activityKind);
    await tester.pump(const Duration(seconds: 6));
  });
}
