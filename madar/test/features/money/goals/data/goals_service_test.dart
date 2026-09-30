import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/import/import.dart';
import 'package:madar/features/money/goals/goals.dart';

/// Tuesday 29 Sep 2026, 20:15 – a fixed clock.
final _now = DateTime(2026, 9, 29, 20, 15);
DateTime d(int y, int m, int day) => DateTime(y, m, day);

class _Env {
  _Env(this.db) : repos = Repositories(db);

  final MadarDatabase db;
  final Repositories repos;
  DateTime now = _now;
  late final GoalsService service = GoalsService(repos, clock: () => now);

  Future<GoalsSnapshot> snapshot() async => GoalsSnapshot.build(
    today: now,
    jars: await repos.jars.getAll(),
    deposits: await repos.jarDeposits.getAll(),
    debts: await repos.debts.getAll(),
    debtPayments: await repos.debtPayments.getAll(),
    obligations: await repos.obligations.getAll(),
    obligationPayments: await repos.obligationPayments.getAll(),
    currencies: await repos.currencies.getAll(),
    wallets: await repos.wallets.getAll(),
    budgetItems: await repos.budgetItems.getAll(),
  );

  /// Wallet balance the way the ledger and the Money planet compute it:
  /// opening + income − expense − transfers out + signed adjustments.
  Future<int> balance(String walletId) async {
    final w = await repos.wallets.byId(walletId);
    var b = w!.openingMilli;
    for (final t in await repos.transactions.getAll(where: (t) => t.walletId.equals(walletId))) {
      b += switch (t.kind) {
        TxKind.income || TxKind.adjustment => t.amountMilli,
        TxKind.expense || TxKind.transfer => -t.amountMilli,
      };
    }
    return b;
  }

  Future<String> wallet(String name, String currency, {int opening = 0}) async => (await repos.wallets.insert(
    WalletsCompanion.insert(name: name, currency: currency, openingMilli: Value(opening)),
  )).id;
}

Future<_Env> _open() async {
  final db = MadarDatabase(
    DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    seed: const SeedOptions(languageCode: 'en'),
  );
  await db.customSelect('SELECT 1').get();
  addTearDown(db.close);
  return _Env(db);
}

void main() {
  group('fresh install', () {
    test('starts empty apart from the seeded currencies', () async {
      final env = await _open();
      final snap = await env.snapshot();
      expect(snap.isEmpty, isTrue);
      expect(snap.rates.base, 'JOD');
      expect(snap.rates.codes, containsAll(['JOD', 'USD', 'SYP', 'EGP', 'LYD']));
      expect(snap.dues(), isEmpty);
      expect(snap.debtTotals.openCount, 0);
      expect(snap.obligationTotals.monthlyBaseMilli, 0);
      expect(await env.repos.activity.since(DateTime(2000)), isEmpty);
    });
  });

  group('jars', () {
    test('deposit from a wallet writes a linked adjustment and logs money.jar', () async {
      final env = await _open();
      final wallet = await env.wallet('Cash', 'JOD', opening: 500000);
      final jar = await env.service.addJar(
        JarDraft(name: 'Travel', targetMilli: 800000, currency: 'JOD', deadline: d(2027, 6, 1)),
      );
      final r = await env.service.moveJarMoney(jar.id, amountMilli: 120000, walletId: wallet, note: 'first');
      expect(r.reachedNow, isFalse);
      expect(r.transactionId, GoalsService.jarTxId(r.depositId));
      final tx = await env.repos.transactions.byId(r.transactionId!);
      expect(tx!.kind, TxKind.adjustment);
      expect(tx.amountMilli, -120000);
      expect(tx.tags, ['jar']);
      expect(tx.note, 'first');
      expect(await env.balance(wallet), 380000);
      final activity = await env.repos.activity.since(DateTime(2000), planetKey: 'money');
      expect(activity.single.kind, GoalsService.kindJar);
      expect(activity.single.refId, r.depositId);

      final snap = await env.snapshot();
      final view = snap.jar(jar.id)!;
      expect(view.plan.savedMilli, 120000);
      // 680 over 8 whole months (Sep 29 → May 29 ≤ Jun 1) = 85.000.
      expect(view.plan.requiredPerMonthMilli, 85000);
      expect(snap.jarsSavedBaseMilli, 120000);

      await r.undo();
      expect(await env.repos.jarDeposits.count(), 0);
      expect(await env.repos.transactions.count(), 0);
      expect(await env.balance(wallet), 500000);
      expect(await env.repos.activity.since(DateTime(2000)), isEmpty);
    });

    test('a withdrawal into a wallet of another currency converts at the manual rate', () async {
      final env = await _open();
      final usd = await env.wallet('Dollars', 'USD');
      final jar = await env.service.addJar(const JarDraft(name: 'Emergency', targetMilli: 300000, currency: 'JOD'));
      await env.service.moveJarMoney(jar.id, amountMilli: 200000);
      final r = await env.service.moveJarMoney(jar.id, amountMilli: 70900, withdraw: true, walletId: usd);
      final tx = await env.repos.transactions.byId(r.transactionId!);
      // 70.900 JOD at 0.709 JOD per USD = 100.00 USD into the wallet.
      expect(tx!.amountMilli, 100000);
      expect(await env.balance(usd), 100000);
      final move = await env.repos.jarDeposits.byId(r.depositId);
      expect(move!.amountMilli, -70900);
      expect(move.walletId, usd);
      expect((await env.snapshot()).jar(jar.id)!.plan.savedMilli, 129100);
    });

    test('reaching the target is reported once', () async {
      final env = await _open();
      final jar = await env.service.addJar(const JarDraft(name: 'Gift', targetMilli: 50000, currency: 'JOD'));
      expect((await env.service.moveJarMoney(jar.id, amountMilli: 30000)).reachedNow, isFalse);
      expect((await env.service.moveJarMoney(jar.id, amountMilli: 20000)).reachedNow, isTrue);
      expect((await env.service.moveJarMoney(jar.id, amountMilli: 1000)).reachedNow, isFalse);
      expect((await env.snapshot()).jar(jar.id)!.plan.pace, JarPace.reached);
    });

    test('archive, reorder, delete with undo of movements and transactions', () async {
      final env = await _open();
      final wallet = await env.wallet('Cash', 'JOD', opening: 100000);
      final a = await env.service.addJar(const JarDraft(name: 'A', targetMilli: 1000, currency: 'JOD'));
      final b = await env.service.addJar(const JarDraft(name: 'B', targetMilli: 1000, currency: 'JOD'));
      await env.service.reorderJars([b.id, a.id]);
      expect([for (final j in (await env.snapshot()).jars) j.jar.name], ['B', 'A']);

      final undoArchive = await env.service.setJarArchived(a.id, true);
      var snap = await env.snapshot();
      expect(snap.jars.map((j) => j.id), [b.id]);
      expect(snap.archivedJars.single.id, a.id);
      await undoArchive();
      expect((await env.snapshot()).archivedJars, isEmpty);

      await env.service.moveJarMoney(b.id, amountMilli: 400, walletId: wallet);
      await env.service.moveJarMoney(b.id, amountMilli: 100);
      final undo = await env.service.deleteJar(b.id);
      expect(await env.repos.jars.byId(b.id), isNull);
      expect(await env.repos.jarDeposits.count(), 0);
      expect(await env.repos.transactions.count(), 0);
      expect(await env.balance(wallet), 100000);
      await undo!();
      snap = await env.snapshot();
      expect(snap.jar(b.id)!.plan.savedMilli, 500);
      expect(await env.balance(wallet), 99600);
      expect(await env.repos.activity.since(DateTime(2000)), hasLength(2));
    });

    test('deleting one movement removes its transaction; undo restores both', () async {
      final env = await _open();
      final wallet = await env.wallet('Cash', 'JOD', opening: 10000);
      final jar = await env.service.addJar(const JarDraft(name: 'A', targetMilli: 9000, currency: 'JOD'));
      final r = await env.service.moveJarMoney(jar.id, amountMilli: 2000, walletId: wallet);
      final undo = await env.service.deleteJarMovement(r.depositId);
      expect(await env.balance(wallet), 10000);
      await undo!();
      expect(await env.balance(wallet), 8000);
      expect((await env.snapshot()).jar(jar.id)!.plan.savedMilli, 2000);
    });
  });

  group('debts', () {
    test('partial payments, paid off, and the wallet side', () async {
      final env = await _open();
      final wallet = await env.wallet('Cash', 'JOD', opening: 1000000);
      final debt = await env.service.addDebt(
        DebtDraft(
          direction: DebtDirection.iOwe,
          person: 'Supplier',
          amountMilli: 300000,
          currency: 'JOD',
          dueDate: d(2026, 10, 5),
        ),
      );
      final p1 = await env.service.addDebtPayment(debt.id, amountMilli: 100000, walletId: wallet);
      expect(p1.paidOff, isFalse);
      expect(await env.balance(wallet), 900000);
      var view = (await env.snapshot()).debt(debt.id)!;
      expect(view.state.remainingMilli, 200000);
      expect(view.state.dueState, DueState.soon);

      final p2 = await env.service.addDebtPayment(debt.id, amountMilli: 200000);
      expect(p2.paidOff, isTrue);
      final snap = await env.snapshot();
      view = snap.debt(debt.id)!;
      expect(view.state.settled, isTrue);
      expect(view.debt.settledAt, isNull, reason: 'paid in full needs no settled_at');
      expect(snap.settledDebts.single.id, debt.id);
      expect(snap.debtTotals.openCount, 0);

      await p2.undo();
      expect((await env.snapshot()).debt(debt.id)!.state.remainingMilli, 200000);
      final kinds = [for (final a in await env.repos.activity.since(DateTime(2000))) a.kind];
      expect(kinds, [GoalsService.kindDebt]);
    });

    test('money owed to me comes back into the wallet', () async {
      final env = await _open();
      final wallet = await env.wallet('Bank', 'USD');
      final debt = await env.service.addDebt(
        const DebtDraft(direction: DebtDirection.owedToMe, person: 'A friend', amountMilli: 50000, currency: 'USD'),
      );
      final r = await env.service.addDebtPayment(debt.id, amountMilli: 20000, walletId: wallet);
      final tx = await env.repos.transactions.byId(r.transactionId!);
      expect(tx!.kind, TxKind.adjustment);
      expect(tx.amountMilli, 20000);
      expect(tx.tags, ['debt']);
      expect(await env.balance(wallet), 20000);
    });

    test('settle writes settled_at with undo; reopen clears it', () async {
      final env = await _open();
      final debt = await env.service.addDebt(
        const DebtDraft(direction: DebtDirection.iOwe, person: 'Uncle', amountMilli: 100000, currency: 'JOD'),
      );
      await env.service.addDebtPayment(debt.id, amountMilli: 30000);
      final undo = await env.service.settleDebt(debt.id);
      var view = (await env.snapshot()).debt(debt.id)!;
      expect(view.debt.settledAt, _now);
      expect(view.state.writtenOffMilli, 70000);
      expect([
        for (final a in await env.repos.activity.since(DateTime(2000))) a.kind,
      ], containsAll([GoalsService.kindDebt, GoalsService.kindDebtSettled]));
      await undo();
      view = (await env.snapshot()).debt(debt.id)!;
      expect(view.debt.settledAt, isNull);
      expect(view.state.remainingMilli, 70000);
      expect([for (final a in await env.repos.activity.since(DateTime(2000))) a.kind], [GoalsService.kindDebt]);

      await env.service.settleDebt(debt.id);
      final undoReopen = await env.service.reopenDebt(debt.id);
      expect((await env.snapshot()).debt(debt.id)!.state.settled, isFalse);
      await undoReopen();
      expect((await env.snapshot()).debt(debt.id)!.state.settled, isTrue);
    });

    test('totals per direction in the base currency', () async {
      final env = await _open();
      Future<void> add(DebtDirection dir, int milli, String cur) => env.service.addDebt(
        DebtDraft(direction: dir, person: 'P', amountMilli: milli, currency: cur, dueDate: d(2026, 9, 1)),
      );
      await add(DebtDirection.iOwe, 100000, 'JOD');
      await add(DebtDirection.iOwe, 100000, 'USD');
      await add(DebtDirection.owedToMe, 1000000, 'EGP');
      final t = (await env.snapshot()).debtTotals;
      // Seeded generic rates: USD 0.709, EGP 0.0145.
      expect(t.iOweBaseMilli, 170900);
      expect(t.owedToMeBaseMilli, 14500);
      expect(t.netBaseMilli, 14500 - 170900);
      expect(t.overdueCount, 3);
    });

    test('delete cascades payments and their transactions, with undo', () async {
      final env = await _open();
      final wallet = await env.wallet('Cash', 'JOD', opening: 10000);
      final debt = await env.service.addDebt(
        const DebtDraft(direction: DebtDirection.iOwe, person: 'X', amountMilli: 5000, currency: 'JOD'),
      );
      await env.service.addDebtPayment(debt.id, amountMilli: 1000, walletId: wallet);
      final undo = await env.service.deleteDebt(debt.id);
      expect(await env.repos.debtPayments.count(), 0);
      expect(await env.balance(wallet), 10000);
      await undo!();
      expect((await env.snapshot()).debt(debt.id)!.state.paidMilli, 1000);
      expect(await env.balance(wallet), 9000);
    });

    test('a debt opened through a wallet moves its balance; repaid, it nets to zero', () async {
      final env = await _open();
      final cash = await env.wallet('Cash', 'JOD', opening: 500000);
      final lent = await env.service.addDebt(
        DebtDraft(
          direction: DebtDirection.owedToMe,
          person: 'A friend',
          amountMilli: 100000,
          currency: 'JOD',
          walletId: cash,
        ),
      );
      final opening = await env.repos.transactions.byId(GoalsService.debtOpenTxId(lent.id));
      expect(opening!.kind, TxKind.adjustment);
      expect(opening.amountMilli, -100000);
      expect(opening.tags, ['debt']);
      expect(opening.date, d(2026, 9, 29));
      expect(await env.balance(cash), 400000);
      expect(await env.service.debtWalletOf(lent.id), cash);
      await env.service.addDebtPayment(lent.id, amountMilli: 100000, walletId: cash);
      expect(await env.balance(cash), 500000, reason: 'lent 100, repaid 100');

      // Borrowing in dollars into the JOD wallet converts at the manual rate.
      final borrowed = await env.service.addDebt(
        DebtDraft(direction: DebtDirection.iOwe, person: 'Bank', amountMilli: 100000, currency: 'USD', walletId: cash),
      );
      expect(await env.balance(cash), 570900);

      // Editing keeps the transaction in step; clearing the wallet removes it.
      await env.service.updateDebt(
        borrowed.id,
        DebtDraft(direction: DebtDirection.iOwe, person: 'Bank', amountMilli: 200000, currency: 'USD', walletId: cash),
      );
      expect(await env.balance(cash), 641800);
      await env.service.updateDebt(
        borrowed.id,
        const DebtDraft(direction: DebtDirection.iOwe, person: 'Bank', amountMilli: 200000, currency: 'USD'),
      );
      expect(await env.balance(cash), 500000);
      expect(await env.service.debtWalletOf(borrowed.id), isNull);

      // Deleting the debt removes its opening transaction too; undo restores it.
      final undo = await env.service.deleteDebt(lent.id);
      expect(await env.balance(cash), 500000);
      expect(await env.repos.transactions.byId(GoalsService.debtOpenTxId(lent.id)), isNull);
      await undo!();
      expect(await env.balance(cash), 500000);
      expect(await env.service.debtWalletOf(lent.id), cash);
    });
  });

  group('obligations', () {
    test('Paid records a payment and an expense on the wallet and budget item, and advances the date', () async {
      final env = await _open();
      final usd = await env.wallet('Card', 'USD', opening: 1000000);
      final item = await env.repos.budgetItems.insert(BudgetItemsCompanion.insert(name: 'Bills'));
      final ob = await env.service.addObligation(
        ObligationDraft(
          name: 'Rent',
          amountMilli: 150000,
          currency: 'JOD',
          frequency: Recurrence.monthly,
          nextDue: d(2026, 1, 31),
          walletId: usd,
          budgetItemId: item.id,
        ),
      );
      env.now = DateTime(2026, 1, 30, 10);
      final r = await env.service.payObligation(ob.id);
      expect(r.step.paidDue, d(2026, 1, 31));
      expect(r.step.nextDue, d(2026, 2, 28));
      final pay = await env.repos.obligationPayments.byId(r.paymentId);
      expect(pay!.dueDate, d(2026, 1, 31));
      expect(pay.amountMilli, 150000);
      expect(pay.transactionId, GoalsService.obligationTxId(r.paymentId));
      final tx = await env.repos.transactions.byId(pay.transactionId!);
      expect(tx!.kind, TxKind.expense);
      expect(tx.walletId, usd);
      expect(tx.budgetItemId, item.id);
      // 150 JOD at 0.709 JOD per USD = 211.565 USD (exact, half-up).
      expect(tx.amountMilli, 211566);
      expect(tx.date, d(2026, 1, 30));
      expect(tx.tags, ['obligation']);
      expect((await env.repos.obligations.byId(ob.id))!.nextDue, d(2026, 2, 28));

      // Paying February returns to the 31st in March.
      env.now = DateTime(2026, 2, 27);
      final r2 = await env.service.payObligation(ob.id);
      expect(r2.step.nextDue, d(2026, 3, 31));

      await r2.undo();
      expect((await env.repos.obligations.byId(ob.id))!.nextDue, d(2026, 2, 28));
      expect(await env.repos.obligationPayments.count(), 1);
      expect(await env.repos.transactions.count(), 1);
      final kinds = [for (final a in await env.repos.activity.since(DateTime(2000))) a.kind];
      expect(kinds, [GoalsService.kindObligation]);
    });

    test('without a wallet only the payment is recorded; skip leaves a zero entry', () async {
      final env = await _open();
      final ob = await env.service.addObligation(
        ObligationDraft(
          name: 'Allowance',
          amountMilli: 5000,
          currency: 'JOD',
          frequency: Recurrence.weekly,
          nextDue: d(2026, 9, 26),
        ),
      );
      final r = await env.service.payObligation(ob.id);
      expect(r.transactionId, isNull);
      expect(r.step.nextDue, d(2026, 10, 3));
      final s = await env.service.skipObligation(ob.id);
      expect(s.step.nextDue, d(2026, 10, 10));
      final snap = await env.snapshot();
      final view = snap.obligation(ob.id)!;
      expect(view.payments.map(ObligationView.isSkip), [true, false]);
      expect(view.paidCount, 1);
      expect(await env.repos.transactions.count(), 0);
      // 5/week × 4 weeks per month (the default).
      expect(snap.obligationTotals.monthlyBaseMilli, 20000);
      await s.undo();
      expect((await env.repos.obligations.byId(ob.id))!.nextDue, d(2026, 10, 3));
    });

    test('an overridden amount, wallet and day', () async {
      final env = await _open();
      final wallet = await env.wallet('Cash', 'JOD', opening: 100000);
      final ob = await env.service.addObligation(
        ObligationDraft(
          name: 'Internet',
          amountMilli: 25000,
          currency: 'JOD',
          frequency: Recurrence.monthly,
          nextDue: d(2026, 9, 12),
        ),
      );
      final r = await env.service.payObligation(ob.id, amountMilli: 27500, walletId: wallet, paidOn: d(2026, 9, 14));
      final tx = await env.repos.transactions.byId(r.transactionId!);
      expect(tx!.amountMilli, 27500);
      expect(tx.date, d(2026, 9, 14));
      expect(await env.balance(wallet), 72500);
    });

    test('deleting the latest history entry moves the due date back; older ones do not', () async {
      final env = await _open();
      final ob = await env.service.addObligation(
        ObligationDraft(
          name: 'Gym',
          amountMilli: 30000,
          currency: 'JOD',
          frequency: Recurrence.monthly,
          nextDue: d(2026, 1, 31),
        ),
      );
      final first = await env.service.payObligation(ob.id);
      final second = await env.service.payObligation(ob.id);
      expect((await env.repos.obligations.byId(ob.id))!.nextDue, d(2026, 3, 31));
      final undoOld = await env.service.deleteObligationPayment(first.paymentId);
      expect((await env.repos.obligations.byId(ob.id))!.nextDue, d(2026, 3, 31));
      await undoOld!();
      final undoLatest = await env.service.deleteObligationPayment(second.paymentId);
      expect((await env.repos.obligations.byId(ob.id))!.nextDue, d(2026, 2, 28));
      await undoLatest!();
      expect((await env.repos.obligations.byId(ob.id))!.nextDue, d(2026, 3, 31));
      expect(await env.repos.obligationPayments.count(), 2);
    });

    test('pause, delete with undo (expenses stay in the ledger)', () async {
      final env = await _open();
      final wallet = await env.wallet('Cash', 'JOD', opening: 100000);
      final ob = await env.service.addObligation(
        ObligationDraft(
          name: 'Phone',
          amountMilli: 10000,
          currency: 'JOD',
          frequency: Recurrence.monthly,
          nextDue: d(2026, 9, 20),
          walletId: wallet,
        ),
      );
      final undoPause = await env.service.setObligationActive(ob.id, false);
      var snap = await env.snapshot();
      expect(snap.pausedObligations.single.id, ob.id);
      expect(snap.obligationTotals.activeCount, 0);
      await undoPause();
      snap = await env.snapshot();
      expect(snap.obligations.single.state.overdue, isTrue);
      expect(snap.dues().single.id, ob.id);

      await env.service.payObligation(ob.id);
      final undo = await env.service.deleteObligation(ob.id);
      expect(await env.repos.obligationPayments.count(), 0);
      expect(await env.repos.transactions.count(), 1);
      await undo!();
      expect(await env.repos.obligationPayments.count(), 1);
    });
  });

  group('snapshot', () {
    test('upcoming dues mix obligations and dated debts, soonest first', () async {
      final env = await _open();
      await env.service.addObligation(
        ObligationDraft(
          name: 'Rent',
          amountMilli: 1,
          currency: 'JOD',
          frequency: Recurrence.monthly,
          nextDue: d(2026, 10, 1),
        ),
      );
      await env.service.addObligation(
        ObligationDraft(
          name: 'Far',
          amountMilli: 1,
          currency: 'JOD',
          frequency: Recurrence.yearly,
          nextDue: d(2027, 1, 1),
        ),
      );
      await env.service.addDebt(
        DebtDraft(
          direction: DebtDirection.iOwe,
          person: 'Late',
          amountMilli: 1,
          currency: 'JOD',
          dueDate: d(2026, 9, 25),
        ),
      );
      await env.service.addDebt(
        const DebtDraft(direction: DebtDirection.owedToMe, person: 'Undated', amountMilli: 1, currency: 'JOD'),
      );
      final dues = (await env.snapshot()).dues();
      expect([for (final e in dues) e.title], ['Late', 'Rent']);
      expect(dues.first.state, DueState.overdue);
      final items = (await env.snapshot()).dueItems;
      expect(items, hasLength(3));
    });

    test('imported jars, debts and obligations read back correctly', () async {
      final env = await _open();
      const json = '''
{"data": {"money": {
  "wallets": [{"id": "w1", "name": "Cash", "currency": "JOD", "balance": 100}],
  "savings": [{"id": "j1", "name": "Travel fund", "target": 800, "saved": 120, "deadline": "2027-06-01"}],
  "debts": [{"id": "d1", "person": "A friend", "direction": "owed to me", "amount": 40, "due": "2026-10-01"},
            {"id": "d2", "person": "Shop", "direction": "i owe", "amount": 15, "currency": "USD", "paid": true}],
  "bills": [{"id": "o1", "name": "Internet", "amount": 25, "frequency": "monthly", "dayOfMonth": 12, "wallet": "w1"}]
}}}''';
      final importer = PrototypeImporter(labels: ImportLabels.forLanguage('en'));
      final plan = importer.analyze(json, now: DateTime(2026, 9, 6));
      await importer.commit(env.db, plan);
      final snap = await env.snapshot();
      final jar = snap.jars.single;
      expect(jar.jar.name, 'Travel fund');
      expect(jar.plan.savedMilli, 120000);
      expect(jar.plan.targetMilli, 800000);
      expect(jar.plan.deadline, d(2027, 6, 1));
      final friend = snap.openDebts.single;
      expect(friend.debt.person, 'A friend');
      expect(friend.debt.direction, DebtDirection.owedToMe);
      expect(friend.state.remainingMilli, 40000);
      expect(snap.settledDebts.single.debt.person, 'Shop');
      final internet = snap.obligations.single;
      expect(internet.state.nextDue, d(2026, 9, 12));
      expect(internet.state.overdue, isTrue);
      expect(internet.obligation.walletId, isNotNull);
      final r = await env.service.payObligation(internet.id);
      expect(r.step.nextDue, d(2026, 10, 12));
      expect((await env.repos.transactions.byId(r.transactionId!))!.amountMilli, 25000);
    });
  });
}
