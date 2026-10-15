// Adversarial review of the Money services on a real (in-memory) database:
// what goals write into wallets stays in each wallet's minor unit, debts
// with partial payments, obligations advancing and booking into the budget,
// re-basing through the service, and the hub's net worth adding up.
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/open.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/budget_math.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/domain/money.dart';
import 'package:madar/features/money/budget/budget.dart';
import 'package:madar/features/money/goals/goals.dart';
import 'package:madar/features/money/hub/money_hub_logic.dart';
import 'package:madar/features/money/ledger/ledger.dart';

final _now = DateTime(2026, 9, 29, 13, 10);

Future<(MadarDatabase, Repositories, LedgerService, GoalsService)> _open() async {
  final db = await openInMemoryMadarDatabase();
  addTearDown(db.close);
  final repos = Repositories(db);
  final ledger = LedgerService(repos, clock: () => _now);
  await ledger.setRate('USD', Rational.tryParse('0.709')!);
  await ledger.setRate('EGP', Rational.tryParse('0.0145')!);
  return (db, repos, ledger, GoalsService(repos, clock: () => _now));
}

Future<GoalsSnapshot> _snapshot(Repositories repos) async {
  final db = repos.db;
  return GoalsSnapshot.build(
    today: _now,
    currencies: await repos.currencies.getAll(),
    jars: await repos.jars.getAll(),
    deposits: await repos.jarDeposits.getAll(),
    debts: await repos.debts.getAll(),
    debtPayments: await repos.debtPayments.getAll(),
    obligations: await repos.obligations.getAll(),
    obligationPayments: await repos.obligationPayments.getAll(),
    wallets: await db.select(db.wallets).get(),
    budgetItems: await repos.budgetItems.getAll(),
  );
}

void main() {
  test('money a goal moves through a USD or EGP wallet lands in whole cents', () async {
    final (_, _, ledger, goals) = await _open();
    final usd = await ledger.addWallet(name: 'PayPal', currency: 'USD', openingMilli: 500000);
    final egp = await ledger.addWallet(name: 'Cairo', currency: 'EGP', openingMilli: 0);
    final jar = await goals.addJar(JarDraft(name: 'Trip', targetMilli: 1000000, currency: 'JOD'));
    // 100 JOD = 141.043 72… USD → 141.04 USD leaves the wallet.
    await goals.moveJarMoney(jar.id, amountMilli: 100000, walletId: usd.id);
    // A 25 JOD debt lent from the EGP wallet: 1 724.137 9… → 1 724.14 EGP.
    await goals.addDebt(
      DebtDraft(
        direction: DebtDirection.owedToMe,
        person: 'Samer',
        amountMilli: 25000,
        currency: 'JOD',
        walletId: egp.id,
      ),
    );
    final book = await ledger.book();
    expect(book.balanceOf(usd.id), 500000 - 141040);
    expect(book.balanceOf(egp.id), -1724140);
    for (final tx in book.transactions) {
      expect(tx.amountMilli % 10, 0, reason: '$tx is not a whole number of cents');
    }
  });

  test('a debt repaid in parts settles on the last part; wallet and totals follow', () async {
    final (db, repos, ledger, goals) = await _open();
    final cash = await ledger.addWallet(name: 'Cash', currency: 'JOD', openingMilli: 300000);
    final debt = await goals.addDebt(
      DebtDraft(
        direction: DebtDirection.owedToMe,
        person: 'Samer',
        amountMilli: 75000,
        currency: 'JOD',
        walletId: cash.id,
        dueDate: DateTime(2026, 9, 27),
      ),
    );
    expect((await ledger.book()).balanceOf(cash.id), 225000);
    final first = await goals.addDebtPayment(debt.id, amountMilli: 25000, walletId: cash.id);
    expect(first.paidOff, isFalse);
    var snap = await _snapshot(repos);
    expect(snap.debt(debt.id)!.state.remainingMilli, 50000);
    expect(snap.debt(debt.id)!.state.overdue, isTrue);
    expect(snap.debtTotals.owedToMeBaseMilli, 50000);
    final last = await goals.addDebtPayment(debt.id, amountMilli: 50000, walletId: cash.id);
    expect(last.paidOff, isTrue);
    snap = await _snapshot(repos);
    expect(snap.debt(debt.id)!.state.settled, isTrue);
    expect(snap.debtTotals.openCount, 0);
    // Lent 75 from cash, got 75 back: the wallet is whole again.
    final book = await ledger.book();
    expect(book.balanceOf(cash.id), 300000);
    expect(MoneyNetWorth.of(book, snap).totalMilli, 300000);
    // Undo of the last part reopens it.
    await last.undo();
    snap = await _snapshot(repos);
    expect(snap.debt(debt.id)!.state.settled, isFalse);
    expect(db, isNotNull);
  });

  test('paying a monthly bill books the expense on its budget item and advances the 31st', () async {
    final (_, repos, ledger, goals) = await _open();
    final bank = await ledger.addWallet(name: 'Bank', currency: 'JOD', openingMilli: 1000000);
    final budget = BudgetRepository(repos, clock: () => _now);
    await budget.add(const BudgetNode(id: 'bills', name: 'Bills', amountMilli: 50000));
    final ob = await goals.addObligation(
      ObligationDraft(
        name: 'Rent',
        amountMilli: 40000,
        currency: 'USD',
        frequency: Recurrence.monthly,
        nextDue: DateTime(2026, 8, 31),
        walletId: bank.id,
        budgetItemId: 'bills',
      ),
    );
    final r1 = await goals.payObligation(ob.id);
    expect(r1.step.nextDue, DateTime(2026, 9, 30));
    final r2 = await goals.payObligation(ob.id);
    expect(r2.step.nextDue, DateTime(2026, 10, 31));
    await goals.skipObligation(ob.id);
    expect((await repos.obligations.byId(ob.id))!.nextDue, DateTime(2026, 11, 30));
    final book = await ledger.book();
    // 2 × 40 USD × 0.709 = 2 × 28.360 JOD.
    expect(book.balanceOf(bank.id), 1000000 - 2 * 28360);
    final math = await budget.math();
    final txs = BudgetRepository.toBudgetTxs(await repos.transactions.getAll(), book.walletCurrency);
    final sep = math.spend(txs, BudgetWindow.month(_now));
    expect(sep.byId['bills']!.spentMilli, 2 * 28360);
    // Undo the skip is not needed; undo of a payment moves the date back.
    await r2.undo();
    expect((await repos.obligations.byId(ob.id))!.nextDue, DateTime(2026, 11, 30));
  });

  test('re-basing through the service keeps the net worth (within one milli of the new base)', () async {
    final (_, repos, ledger, goals) = await _open();
    await ledger.addWallet(name: 'Cash', currency: 'JOD', openingMilli: 1234567);
    await ledger.addWallet(name: 'PayPal', currency: 'USD', openingMilli: 999990);
    await ledger.addWallet(name: 'Cairo', currency: 'EGP', openingMilli: 20000000);
    final jar = await goals.addJar(JarDraft(name: 'Trip', targetMilli: 1000000, currency: 'USD'));
    await goals.moveJarMoney(jar.id, amountMilli: 300000);
    await goals.addDebt(
      DebtDraft(direction: DebtDirection.iOwe, person: 'Khaled', amountMilli: 150000, currency: 'EGP'),
    );
    final before = MoneyNetWorth.of(await ledger.book(), await _snapshot(repos));
    await ledger.rebase('USD');
    final after = MoneyNetWorth.of(await ledger.book(), await _snapshot(repos));
    expect(after.base, 'USD');
    final back = Rational.fromInt(after.totalMilli) * Rational.fromNum(0.709);
    expect(
      (back - Rational.fromInt(before.totalMilli)).abs() <= Rational.fromInt(1),
      isTrue,
      reason: '${after.totalMilli} USD × 0.709 vs ${before.totalMilli} JOD',
    );
    await ledger.rebase('JOD');
    final again = MoneyNetWorth.of(await ledger.book(), await _snapshot(repos));
    expect(again.totalMilli, before.totalMilli);
    final usd = (await repos.currencies.byCode('USD'))!;
    expect(usd.rateToBase, 0.709);
  });

  test('re-basing keeps the budget: items in the old base stay in it (200 JOD ≠ 200 USD)', () async {
    final (_, repos, ledger, _) = await _open();
    final budget = BudgetRepository(repos, clock: () => _now);
    // Stored with no currency: "the base currency" (JOD today).
    await budget.add(const BudgetNode(id: 'food', name: 'Home food', amountMilli: 200000));
    await budget.add(const BudgetNode(id: 'ads', name: 'Ads', amountMilli: 100000, currency: 'USD', sortOrder: 1));
    Future<BudgetMath> math() async {
      final c = BudgetCurrencies.fromRows(await repos.currencies.getAll());
      return BudgetMath([for (final r in await repos.budgetItems.getAll()) budgetNodeOf(r)], settings: c.settings());
    }

    expect((await math()).totalMonthlyMilli, 270900);
    final undo = await ledger.rebase('USD');
    final inUsd = await math();
    // 200 JOD + 100 USD = 382.087 USD (200 / 0.709 = 282.087…), not 300 USD.
    expect(inUsd['food']!.monthlyMilli, 282087);
    expect(inUsd.totalMonthlyMilli, 382087);
    expect((await repos.budgetItems.byId('food'))!.currency, 'JOD');
    // Back to JOD: the same plan again.
    await ledger.rebase('JOD');
    expect((await math()).totalMonthlyMilli, 270900);
    // Undo of a re-base puts the rows back as they were.
    await ledger.rebase('USD');
    expect((await math()).totalMonthlyMilli, 382087);
    await undo();
    expect((await repos.currencies.byCode('JOD'))!.isBase, isTrue);
    expect((await repos.budgetItems.byId('food'))!.currency, isNull);
    expect((await math()).totalMonthlyMilli, 270900);
  });

  test('archiving a jar keeps its money in the net worth (its wallet entry stays)', () async {
    final (_, repos, ledger, goals) = await _open();
    final bank = await ledger.addWallet(name: 'Bank', currency: 'JOD', openingMilli: 1000000);
    final jar = await goals.addJar(JarDraft(name: 'Trip', targetMilli: 300000, currency: 'JOD'));
    await goals.moveJarMoney(jar.id, amountMilli: 300000, walletId: bank.id);
    final before = MoneyNetWorth.of(await ledger.book(), await _snapshot(repos));
    expect(before.totalMilli, 1000000);
    await goals.setJarArchived(jar.id, true);
    final book = await ledger.book();
    expect(book.balanceOf(bank.id), 700000, reason: 'the deposit left the wallet and stays out');
    final after = MoneyNetWorth.of(book, await _snapshot(repos));
    expect(after.jarsMilli, 300000);
    expect(after.totalMilli, 1000000, reason: 'archiving is not spending');
    // An empty archived jar adds nothing and is not counted.
    await goals.moveJarMoney(jar.id, amountMilli: 300000, withdraw: true, walletId: bank.id);
    final emptied = MoneyNetWorth.of(await ledger.book(), await _snapshot(repos));
    expect(emptied.totalMilli, 1000000);
    expect(emptied.jarCount, 0);
  });

  test('a currency kept by a jar, debt, bill or budget item cannot be deleted (it would count 1:1)', () async {
    final (_, repos, ledger, goals) = await _open();
    await ledger.saveCurrency(const LedgerCurrency(code: 'EUR', decimals: 2), rate: Rational.tryParse('0.77'));
    final ob = await goals.addObligation(
      ObligationDraft(
        name: 'Hosting',
        amountMilli: 12000,
        currency: 'EUR',
        frequency: Recurrence.monthly,
        nextDue: DateTime(2026, 10, 5),
      ),
    );
    expect(await ledger.watchCurrencyUseElsewhere().first, containsPair('EUR', 1));
    await expectLater(
      ledger.deleteCurrency('EUR'),
      throwsA(isA<CurrencyInUseException>().having((e) => e.elsewhere, 'elsewhere', 1)),
    );
    await goals.deleteObligation(ob.id);
    await BudgetRepository(repos).add(const BudgetNode(id: 'ads', name: 'Ads', amountMilli: 50000, currency: 'EUR'));
    await expectLater(ledger.deleteCurrency('EUR'), throwsA(isA<CurrencyInUseException>()));
    await BudgetRepository(repos).deleteSubtree('ads');
    final undo = await ledger.deleteCurrency('EUR');
    expect(await repos.currencies.byCode('EUR'), isNull);
    await undo();
    expect(await repos.currencies.byCode('EUR'), isNotNull);
  });
}
