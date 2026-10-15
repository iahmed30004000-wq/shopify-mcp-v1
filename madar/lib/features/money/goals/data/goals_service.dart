import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../../../../core/db/database.dart';
import '../../../../core/db/repositories/repositories.dart';
import '../../../../core/domain/budget_math.dart' show BudgetSettings;
import '../../../../core/domain/enums.dart';
import '../domain/debt_ledger.dart';
import '../domain/due_dates.dart';
import '../domain/due_reminders.dart';
import '../domain/goals_rates.dart';
import '../domain/goals_snapshot.dart';
import '../domain/obligation_plan.dart';

/// Reverts one write (restores exactly what it changed).
typedef GoalsUndo = Future<void> Function();

/// Logs an activity on the Money planet. The default writes an
/// `activity_log` row; the app routes it through the orbit's pulse hub so
/// the world flares at once.
typedef GoalsActivityRecorder = Future<void> Function(
  String kind,
  String? refTable,
  String? refId, {
  double? value,
  Map<String, Object?> payload,
});

/// A new or edited savings jar.
class JarDraft {
  const JarDraft({
    required this.name,
    required this.targetMilli,
    required this.currency,
    this.deadline,
    this.color,
    this.icon,
  });

  final String name;
  final int targetMilli;
  final String currency;
  final DateTime? deadline;
  final int? color;
  final String? icon;
}

/// A new or edited debt.
class DebtDraft {
  const DebtDraft({
    required this.direction,
    required this.person,
    required this.amountMilli,
    required this.currency,
    this.dueDate,
    this.note,
    this.walletId,
  });

  final DebtDirection direction;
  final String person;
  final int amountMilli;
  final String currency;
  final DateTime? dueDate;
  final String? note;

  /// The wallet the money went through when the debt was opened – lent
  /// from it, or borrowed into it (see [GoalsService]). On an update, null
  /// removes that wallet transaction.
  final String? walletId;
}

/// A new or edited recurring obligation.
class ObligationDraft {
  const ObligationDraft({
    required this.name,
    required this.amountMilli,
    required this.currency,
    required this.frequency,
    required this.nextDue,
    this.interval = 1,
    this.walletId,
    this.budgetItemId,
    this.note,
  });

  final String name;
  final int amountMilli;
  final String currency;
  final Recurrence frequency;
  final int interval;
  final DateTime nextDue;
  final String? walletId;
  final String? budgetItemId;
  final String? note;
}

/// Result of a jar deposit / withdrawal.
class JarMoveResult {
  const JarMoveResult({required this.depositId, required this.undo, required this.reachedNow, this.transactionId});

  final String depositId;

  /// The matching wallet transaction (null without a wallet).
  final String? transactionId;
  final GoalsUndo undo;

  /// This deposit reached the jar's target.
  final bool reachedNow;
}

/// Result of a debt payment.
class DebtPayResult {
  const DebtPayResult({required this.paymentId, required this.undo, required this.paidOff, this.transactionId});

  final String paymentId;
  final String? transactionId;
  final GoalsUndo undo;

  /// This payment covered what was left.
  final bool paidOff;
}

/// Result of "Paid" / "Skip" on an obligation.
class ObligationPayResult {
  const ObligationPayResult({required this.paymentId, required this.step, required this.undo, this.transactionId});

  final String paymentId;
  final ObligationStep step;
  final String? transactionId;
  final GoalsUndo undo;
}

/// Every write of the goals package: savings jars and their movements,
/// debts and their payments, recurring obligations and their history.
///
/// ### Wallet transactions (documented choice)
/// * A jar deposit taken **from** a wallet, or a withdrawal paid **into**
///   one, writes a jar movement *and* a wallet transaction of kind
///   [TxKind.adjustment] (signed: −amount for a deposit, +amount for a
///   withdrawal), tagged `jar`, with the jar's name as note. Money moved to
///   a jar is neither an expense nor income, so budget spending and income
///   charts stay untouched while the wallet balance follows. Its id is
///   `jar-tx-<movement id>`, which links the pair for undo and deletion.
/// * A debt payment made from / received into a wallet is recorded the same
///   way (tag `debt`, id `debt-tx-<payment id>`): repaying a loan is not
///   spending, receiving one back is not income.
/// * A debt opened through a wallet (money lent from it, or borrowed into
///   it) gets the matching adjustment too (tag `debt`, id
///   `debt-open-tx-<debt id>`: −amount when lending, +amount when
///   borrowing), so lending 100 and being repaid 100 into the same wallet
///   nets to zero. Editing the debt keeps it in step; deleting removes it.
/// * "Paid" on an obligation with a wallet writes an [TxKind.expense] on that
///   wallet and the obligation's budget item (tag `obligation`, id
///   `ob-tx-<payment id>`, also stored in `obligation_payments.transaction_id`).
///
/// Amounts are converted to the wallet's currency at the manual rates when
/// the currencies differ (exact, half-up to the milli).
class GoalsService {
  GoalsService(this.repos, {DateTime Function()? clock, this.recorder}) : clock = clock ?? DateTime.now;

  final Repositories repos;
  final DateTime Function() clock;
  final GoalsActivityRecorder? recorder;

  static const String planetKey = 'money';
  static const String kindJar = 'money.jar';
  static const String kindDebt = 'money.debt';
  static const String kindDebtSettled = 'money.debt.settled';
  static const String kindObligation = 'money.obligation';

  static const String tagJar = 'jar';
  static const String tagDebt = 'debt';
  static const String tagObligation = 'obligation';

  static String jarTxId(String movementId) => 'jar-tx-$movementId';
  static String debtTxId(String paymentId) => 'debt-tx-$paymentId';
  static String debtOpenTxId(String debtId) => 'debt-open-tx-$debtId';
  static String obligationTxId(String paymentId) => 'ob-tx-$paymentId';

  static final KvKey<GoalsReminderSettings> reminderSettingsKey = KvKey.json<GoalsReminderSettings>(
    GoalsReminderSettings.storageKey,
    fromJson: GoalsReminderSettings.fromJson,
    toJson: (s) => s.toJson(),
  );

  static final KvKey<num> weeksPerMonthKey = KvKey.number(BudgetSettings.weeksPerMonthKey);

  MadarDatabase get _db => repos.db;

  DateTime get _today => CalendarDays.of(clock());

  Future<void> _record(
    String kind,
    String? table,
    String? id, {
    double? value,
    Map<String, Object?> payload = const {},
  }) {
    final r = recorder;
    if (r != null) return r(kind, table, id, value: value, payload: payload);
    return repos.activity.log(
      planetKey: planetKey,
      kind: kind,
      refTable: table,
      refId: id,
      at: clock(),
      value: value,
      payload: payload,
    );
  }

  Future<GoalsRates> _rates() async => ratesFromCurrencyRows(await repos.currencies.getAll());

  String? _clean(String? s) {
    final t = s?.trim();
    return t == null || t.isEmpty ? null : t;
  }

  // ============================================================== streams ==

  Stream<List<JarRow>> watchJars() => repos.jars.watchAll();
  Stream<List<JarDepositRow>> watchJarDeposits() => repos.jarDeposits.watchAll();
  Stream<List<DebtRow>> watchDebts() => repos.debts.watchAll();
  Stream<List<DebtPaymentRow>> watchDebtPayments() => repos.debtPayments.watchAll();
  Stream<List<ObligationRow>> watchObligations() => repos.obligations.watchAll();
  Stream<List<ObligationPaymentRow>> watchObligationPayments() => repos.obligationPayments.watchAll();
  Stream<List<WalletRow>> watchWallets() => repos.wallets.watchAll(where: (w) => w.archived.equals(false));
  Stream<List<BudgetItemRow>> watchBudgetItems() => repos.budgetItems.watchAll();
  Stream<List<CurrencyRow>> watchCurrencies() => repos.currencies.watchAll();
  Stream<GoalsReminderSettings> watchReminderSettings() =>
      repos.keyValues.watch(reminderSettingsKey).map((s) => s ?? const GoalsReminderSettings());
  Stream<num> watchWeeksPerMonth() =>
      repos.keyValues.watch(weeksPerMonthKey).map((w) => w == null || w <= 0 ? BudgetSettings.defaultWeeksPerMonth : w);

  Future<void> setReminderSettings(GoalsReminderSettings settings) =>
      repos.keyValues.set(reminderSettingsKey, settings);

  // ================================================================= jars ==

  Future<JarRow> addJar(JarDraft d) => repos.jars.insert(
    JarsCompanion.insert(
      name: d.name.trim(),
      targetMilli: math.max(0, d.targetMilli),
      currency: d.currency.toUpperCase(),
      deadline: Value(d.deadline == null ? null : CalendarDays.of(d.deadline!)),
      color: Value(d.color),
      icon: Value(_clean(d.icon)),
    ),
  );

  Future<void> updateJar(String id, JarDraft d) => repos.jars.update(
    JarsCompanion(
      id: Value(id),
      name: Value(d.name.trim()),
      targetMilli: Value(math.max(0, d.targetMilli)),
      currency: Value(d.currency.toUpperCase()),
      deadline: Value(d.deadline == null ? null : CalendarDays.of(d.deadline!)),
      color: Value(d.color),
      icon: Value(_clean(d.icon)),
    ),
  );

  Future<GoalsUndo> setJarArchived(String id, bool archived) async {
    final row = await repos.jars.byId(id);
    final before = row?.archived ?? !archived;
    await repos.jars.setColumn(id, 'archived', archived, moveToEnd: !archived);
    return () => repos.jars.setColumn(id, 'archived', before);
  }

  Future<void> reorderJars(List<String> ids) => repos.jars.reorder(ids);

  /// Deletes a jar with its movements, their wallet transactions and
  /// activity entries.
  Future<GoalsUndo?> deleteJar(String id) async {
    late final JarRow? jar;
    late final List<JarDepositRow> moves;
    late final List<TransactionRow> txs;
    late final List<ActivityRow> activity;
    await _db.transaction(() async {
      jar = await repos.jars.delete(id);
      moves = await repos.jarDeposits.deleteWhere((t) => t.jarId.equals(id));
      final txIds = [for (final m in moves) jarTxId(m.id)];
      txs = txIds.isEmpty ? const [] : await repos.transactions.deleteWhere((t) => t.id.isIn(txIds));
      activity = [
        for (final m in moves) ...await repos.activity.removeFor(refTable: repos.jarDeposits.tableName, refId: m.id),
      ];
    });
    final deleted = jar;
    if (deleted == null) return null;
    return () => _db.transaction(() async {
      await repos.jars.restore(deleted);
      await repos.jarDeposits.restoreAll(moves);
      await repos.transactions.restoreAll(txs);
      await repos.activityLog.restoreAll(activity);
    });
  }

  /// Puts [amountMilli] (positive, in the jar's currency) into the jar, or
  /// takes it out with [withdraw]. With a [walletId] the money comes from /
  /// goes to that wallet (see the class documentation).
  Future<JarMoveResult> moveJarMoney(
    String jarId, {
    required int amountMilli,
    bool withdraw = false,
    DateTime? date,
    String? walletId,
    String? note,
  }) async {
    final amount = amountMilli.abs();
    if (amount == 0) throw ArgumentError.value(amountMilli, 'amountMilli', 'must not be zero');
    final day = CalendarDays.of(date ?? clock());
    final rates = await _rates();
    late final JarDepositRow move;
    TransactionRow? tx;
    late final bool reachedNow;
    await _db.transaction(() async {
      final jar = await repos.jars.byId(jarId);
      if (jar == null) throw StateError('Unknown jar $jarId');
      final before = await repos.jarDeposits.getAll(where: (t) => t.jarId.equals(jarId));
      final savedBefore = before.fold<int>(0, (a, m) => a + m.amountMilli);
      move = await repos.jarDeposits.insert(
        JarDepositsCompanion.insert(
          jarId: jarId,
          amountMilli: withdraw ? -amount : amount,
          date: day,
          walletId: Value(walletId),
          note: Value(_clean(note)),
        ),
      );
      final savedAfter = savedBefore + move.amountMilli;
      reachedNow = jar.targetMilli > 0 && savedBefore < jar.targetMilli && savedAfter >= jar.targetMilli;
      if (walletId != null) {
        final wallet = await repos.wallets.byId(walletId);
        if (wallet != null) {
          final walletAmount = rates.convertToMinor(amount, jar.currency, wallet.currency);
          tx = await repos.transactions.insert(
            TransactionsCompanion.insert(
              id: Value(jarTxId(move.id)),
              walletId: walletId,
              kind: TxKind.adjustment,
              amountMilli: withdraw ? walletAmount : -walletAmount,
              date: day,
              note: Value(_clean(note) ?? jar.name),
              tags: const Value([tagJar]),
            ),
          );
        }
      }
    });
    await _record(
      kindJar,
      repos.jarDeposits.tableName,
      move.id,
      value: (move.amountMilli / 1000),
      payload: {'jarId': jarId, 'amountMilli': move.amountMilli, 'reached': reachedNow},
    );
    final txId = tx?.id;
    return JarMoveResult(
      depositId: move.id,
      transactionId: txId,
      reachedNow: reachedNow,
      undo: () => _db.transaction(() async {
        await repos.jarDeposits.delete(move.id);
        if (txId != null) await repos.transactions.delete(txId);
        await repos.activity.removeFor(refTable: repos.jarDeposits.tableName, refId: move.id);
      }),
    );
  }

  /// Deletes one jar movement (and its wallet transaction).
  Future<GoalsUndo?> deleteJarMovement(String movementId) =>
      _deleteWithTx(repos.jarDeposits, movementId, jarTxId(movementId));

  // ================================================================ debts ==

  Future<DebtRow> addDebt(DebtDraft d) async {
    final rates = await _rates();
    return _db.transaction(() async {
      final row = await repos.debts.insert(
        DebtsCompanion.insert(
          direction: d.direction,
          person: d.person.trim(),
          amountMilli: d.amountMilli.abs(),
          currency: d.currency.toUpperCase(),
          dueDate: Value(d.dueDate == null ? null : CalendarDays.of(d.dueDate!)),
          note: Value(_clean(d.note)),
        ),
      );
      await _syncDebtOpening(row, d.walletId, rates);
      return row;
    });
  }

  Future<void> updateDebt(String id, DebtDraft d) async {
    final rates = await _rates();
    await _db.transaction(() async {
      await repos.debts.update(
        DebtsCompanion(
          id: Value(id),
          direction: Value(d.direction),
          person: Value(d.person.trim()),
          amountMilli: Value(d.amountMilli.abs()),
          currency: Value(d.currency.toUpperCase()),
          dueDate: Value(d.dueDate == null ? null : CalendarDays.of(d.dueDate!)),
          note: Value(_clean(d.note)),
        ),
      );
      final row = await repos.debts.byId(id);
      if (row != null) await _syncDebtOpening(row, d.walletId, rates);
    });
  }

  /// The wallet a debt's money went through when it was opened (null when
  /// none was chosen, or its transaction was deleted in the ledger).
  Future<String?> debtWalletOf(String debtId) async => (await repos.transactions.byId(debtOpenTxId(debtId)))?.walletId;

  /// Writes, updates or removes the wallet transaction of [debt]'s opening
  /// (see the class documentation).
  Future<void> _syncDebtOpening(DebtRow debt, String? walletId, GoalsRates rates) async {
    final id = debtOpenTxId(debt.id);
    final existing = await repos.transactions.byId(id);
    final wallet = walletId == null ? null : await repos.wallets.byId(walletId);
    if (wallet == null) {
      if (existing != null) await repos.transactions.delete(id);
      return;
    }
    final amount = rates.convertToMinor(debt.amountMilli.abs(), debt.currency, wallet.currency);
    final signed = debt.direction == DebtDirection.iOwe ? amount : -amount;
    if (existing == null) {
      await repos.transactions.insert(
        TransactionsCompanion.insert(
          id: Value(id),
          walletId: wallet.id,
          kind: TxKind.adjustment,
          amountMilli: signed,
          date: _today,
          note: Value(debt.person),
          tags: const Value([tagDebt]),
        ),
      );
    } else {
      await repos.transactions.update(
        TransactionsCompanion(
          id: Value(id),
          walletId: Value(wallet.id),
          amountMilli: Value(signed),
          note: Value(debt.person),
        ),
      );
    }
  }

  Future<void> reorderDebts(List<String> ids) => repos.debts.reorder(ids);

  /// Deletes a debt with its payments, their wallet transactions (and the
  /// opening one) and activity entries.
  Future<GoalsUndo?> deleteDebt(String id) async {
    late final DebtRow? debt;
    late final List<DebtPaymentRow> pays;
    late final List<TransactionRow> txs;
    late final List<ActivityRow> activity;
    await _db.transaction(() async {
      debt = await repos.debts.delete(id);
      pays = await repos.debtPayments.deleteWhere((t) => t.debtId.equals(id));
      final txIds = [debtOpenTxId(id), for (final p in pays) debtTxId(p.id)];
      txs = await repos.transactions.deleteWhere((t) => t.id.isIn(txIds));
      activity = [
        ...await repos.activity.removeFor(refTable: repos.debts.tableName, refId: id),
        for (final p in pays) ...await repos.activity.removeFor(refTable: repos.debtPayments.tableName, refId: p.id),
      ];
    });
    final deleted = debt;
    if (deleted == null) return null;
    return () => _db.transaction(() async {
      await repos.debts.restore(deleted);
      await repos.debtPayments.restoreAll(pays);
      await repos.transactions.restoreAll(txs);
      await repos.activityLog.restoreAll(activity);
    });
  }

  /// Records a partial (or final) payment of [amountMilli] in the debt's
  /// currency. A debt whose payments cover its amount counts as settled
  /// (no `settled_at` is written, so deleting the payment reopens it).
  Future<DebtPayResult> addDebtPayment(
    String debtId, {
    required int amountMilli,
    DateTime? date,
    String? walletId,
    String? note,
  }) async {
    final amount = amountMilli.abs();
    if (amount == 0) throw ArgumentError.value(amountMilli, 'amountMilli', 'must not be zero');
    final day = CalendarDays.of(date ?? clock());
    final rates = await _rates();
    late final DebtPaymentRow pay;
    TransactionRow? tx;
    late final bool paidOff;
    late final DebtRow debt;
    await _db.transaction(() async {
      final row = await repos.debts.byId(debtId);
      if (row == null) throw StateError('Unknown debt $debtId');
      debt = row;
      final before = await repos.debtPayments.getAll(where: (t) => t.debtId.equals(debtId));
      final state = DebtState.compute(
        direction: row.direction,
        currency: row.currency,
        amountMilli: row.amountMilli,
        payments: [for (final p in before) DebtPaymentIn(p.amountMilli, p.date)],
        today: _today,
        settledAt: row.settledAt,
      );
      paidOff = state.paysOff(amount);
      pay = await repos.debtPayments.insert(
        DebtPaymentsCompanion.insert(debtId: debtId, amountMilli: amount, date: day, note: Value(_clean(note))),
      );
      if (walletId != null) {
        final wallet = await repos.wallets.byId(walletId);
        if (wallet != null) {
          final walletAmount = rates.convertToMinor(amount, row.currency, wallet.currency);
          tx = await repos.transactions.insert(
            TransactionsCompanion.insert(
              id: Value(debtTxId(pay.id)),
              walletId: walletId,
              kind: TxKind.adjustment,
              amountMilli: row.direction == DebtDirection.iOwe ? -walletAmount : walletAmount,
              date: day,
              note: Value(_clean(note) ?? row.person),
              tags: const Value([tagDebt]),
            ),
          );
        }
      }
    });
    await _record(
      kindDebt,
      repos.debtPayments.tableName,
      pay.id,
      value: amount / 1000,
      payload: {'debtId': debtId, 'direction': debt.direction.name, 'paidOff': paidOff},
    );
    final txId = tx?.id;
    return DebtPayResult(
      paymentId: pay.id,
      transactionId: txId,
      paidOff: paidOff,
      undo: () => _db.transaction(() async {
        await repos.debtPayments.delete(pay.id);
        if (txId != null) await repos.transactions.delete(txId);
        await repos.activity.removeFor(refTable: repos.debtPayments.tableName, refId: pay.id);
      }),
    );
  }

  /// Deletes one debt payment (and its wallet transaction).
  Future<GoalsUndo?> deleteDebtPayment(String paymentId) =>
      _deleteWithTx(repos.debtPayments, paymentId, debtTxId(paymentId));

  /// Marks a debt settled now (`settled_at`), whatever is left unpaid.
  Future<GoalsUndo> settleDebt(String id) async {
    final row = await repos.debts.byId(id);
    final before = row?.settledAt;
    await repos.debts.setColumn(id, 'settledAt', clock());
    await _record(kindDebtSettled, repos.debts.tableName, id, payload: {'direction': row?.direction.name});
    return () => _db.transaction(() async {
      await repos.debts.setColumn(id, 'settledAt', before);
      await repos.activity.removeFor(refTable: repos.debts.tableName, refId: id, kind: kindDebtSettled);
    });
  }

  /// Clears `settled_at` (a debt still paid in full stays settled).
  Future<GoalsUndo> reopenDebt(String id) async {
    final row = await repos.debts.byId(id);
    final before = row?.settledAt;
    final activity = await _db.transaction(() async {
      await repos.debts.setColumn(id, 'settledAt', null);
      return repos.activity.removeFor(refTable: repos.debts.tableName, refId: id, kind: kindDebtSettled);
    });
    return () => _db.transaction(() async {
      await repos.debts.setColumn(id, 'settledAt', before);
      await repos.activityLog.restoreAll(activity);
    });
  }

  // ========================================================== obligations ==

  Future<ObligationRow> addObligation(ObligationDraft d) => repos.obligations.insert(
    ObligationsCompanion.insert(
      name: d.name.trim(),
      amountMilli: d.amountMilli.abs(),
      currency: d.currency.toUpperCase(),
      walletId: Value(d.walletId),
      budgetItemId: Value(d.budgetItemId),
      frequency: d.frequency,
      interval: Value(math.max(1, d.interval)),
      nextDue: CalendarDays.of(d.nextDue),
      note: Value(_clean(d.note)),
    ),
  );

  Future<void> updateObligation(String id, ObligationDraft d) => repos.obligations.update(
    ObligationsCompanion(
      id: Value(id),
      name: Value(d.name.trim()),
      amountMilli: Value(d.amountMilli.abs()),
      currency: Value(d.currency.toUpperCase()),
      walletId: Value(d.walletId),
      budgetItemId: Value(d.budgetItemId),
      frequency: Value(d.frequency),
      interval: Value(math.max(1, d.interval)),
      nextDue: Value(CalendarDays.of(d.nextDue)),
      note: Value(_clean(d.note)),
    ),
  );

  Future<void> reorderObligations(List<String> ids) => repos.obligations.reorder(ids);

  Future<GoalsUndo> setObligationActive(String id, bool active) async {
    final row = await repos.obligations.byId(id);
    final before = row?.active ?? !active;
    await repos.obligations.setColumn(id, 'active', active);
    return () => repos.obligations.setColumn(id, 'active', before);
  }

  /// Deletes an obligation and its history. Expenses already recorded for
  /// it stay in the ledger (they were real spending).
  Future<GoalsUndo?> deleteObligation(String id) async {
    late final ObligationRow? row;
    late final List<ObligationPaymentRow> pays;
    late final List<ActivityRow> activity;
    await _db.transaction(() async {
      row = await repos.obligations.delete(id);
      pays = await repos.obligationPayments.deleteWhere((t) => t.obligationId.equals(id));
      activity = [
        for (final p in pays)
          ...await repos.activity.removeFor(refTable: repos.obligationPayments.tableName, refId: p.id),
      ];
    });
    final deleted = row;
    if (deleted == null) return null;
    return () => _db.transaction(() async {
      await repos.obligations.restore(deleted);
      await repos.obligationPayments.restoreAll(pays);
      await repos.activityLog.restoreAll(activity);
    });
  }

  Future<ObligationState> _stateOf(ObligationRow o, {String? excludePayment}) async {
    final history = await repos.obligationPayments.getAll(where: (t) => t.obligationId.equals(o.id));
    return ObligationState.compute(
      frequency: o.frequency,
      interval: o.interval,
      nextDue: o.nextDue,
      today: _today,
      active: o.active,
      history: [
        for (final p in history)
          if (p.id != excludePayment) p.dueDate,
      ],
    );
  }

  /// "Paid": records the current period ([ObligationRow.nextDue]) as paid,
  /// writes the expense on the wallet ([walletId] or the obligation's own;
  /// none without either) and budget item, and advances the next due date.
  Future<ObligationPayResult> payObligation(
    String id, {
    int? amountMilli,
    String? walletId,
    DateTime? paidOn,
    bool recordTransaction = true,
  }) => _advanceObligation(
    id,
    skip: false,
    amountMilli: amountMilli,
    walletId: walletId,
    paidOn: paidOn,
    recordTx: recordTransaction,
  );

  /// "Skip": moves past the current period without paying (kept in the
  /// history as a zero payment without transaction).
  Future<ObligationPayResult> skipObligation(String id) => _advanceObligation(id, skip: true, recordTx: false);

  Future<ObligationPayResult> _advanceObligation(
    String id, {
    required bool skip,
    required bool recordTx,
    int? amountMilli,
    String? walletId,
    DateTime? paidOn,
  }) async {
    final rates = await _rates();
    final paymentId = newId();
    late final ObligationStep step;
    String? txId;
    late final ObligationRow ob;
    late final int amount;
    await _db.transaction(() async {
      final row = await repos.obligations.byId(id);
      if (row == null) throw StateError('Unknown obligation $id');
      ob = row;
      step = (await _stateOf(row)).advance();
      amount = skip ? 0 : (amountMilli ?? row.amountMilli).abs();
      final wallet = skip || !recordTx ? null : await repos.wallets.byId(walletId ?? row.walletId ?? '');
      if (wallet != null && amount > 0) {
        final tx = await repos.transactions.insert(
          TransactionsCompanion.insert(
            id: Value(obligationTxId(paymentId)),
            walletId: wallet.id,
            kind: TxKind.expense,
            amountMilli: rates.convertToMinor(amount, row.currency, wallet.currency),
            date: CalendarDays.of(paidOn ?? clock()),
            budgetItemId: Value(row.budgetItemId),
            note: Value(row.name),
            tags: const Value([tagObligation]),
          ),
        );
        txId = tx.id;
      }
      await repos.obligationPayments.insert(
        ObligationPaymentsCompanion.insert(
          id: Value(paymentId),
          obligationId: id,
          dueDate: step.paidDue,
          paidAt: paidOn ?? clock(),
          amountMilli: amount,
          transactionId: Value(txId),
        ),
      );
      await repos.obligations.setColumn(id, 'nextDue', step.nextDue);
    });
    if (!skip) {
      await _record(
        kindObligation,
        repos.obligationPayments.tableName,
        paymentId,
        value: amount / 1000,
        payload: {
          'obligationId': id,
          'due': step.paidDue.toIso8601String(),
          'amountMilli': amount,
          'currency': ob.currency,
        },
      );
    }
    final linkedTx = txId;
    return ObligationPayResult(
      paymentId: paymentId,
      step: step,
      transactionId: linkedTx,
      undo: () => _db.transaction(() async {
        await repos.obligationPayments.delete(paymentId);
        if (linkedTx != null) await repos.transactions.delete(linkedTx);
        await repos.activity.removeFor(refTable: repos.obligationPayments.tableName, refId: paymentId);
        final now = await repos.obligations.byId(id);
        if (now != null && now.nextDue == step.nextDue) {
          await repos.obligations.setColumn(id, 'nextDue', step.paidDue);
        }
      }),
    );
  }

  /// Deletes one history entry (and its expense). Deleting the latest
  /// entry also moves the next due date back to it.
  Future<GoalsUndo?> deleteObligationPayment(String paymentId) async {
    late final ObligationPaymentRow? pay;
    TransactionRow? tx;
    List<ActivityRow> activity = const [];
    DateTime? movedFrom;
    await _db.transaction(() async {
      pay = await repos.obligationPayments.byId(paymentId);
      final p = pay;
      if (p == null) return;
      final ob = await repos.obligations.byId(p.obligationId);
      if (ob != null) {
        final rolledBack = (await _stateOf(ob.copyWith(nextDue: p.dueDate), excludePayment: p.id)).advance();
        final history = await repos.obligationPayments.getAll(where: (t) => t.obligationId.equals(ob.id));
        final latest = history.every((h) => h.id == p.id || !h.dueDate.isAfter(p.dueDate));
        if (latest && rolledBack.nextDue == ob.nextDue) {
          movedFrom = ob.nextDue;
          await repos.obligations.setColumn(ob.id, 'nextDue', p.dueDate);
        }
      }
      await repos.obligationPayments.delete(p.id);
      final txId = p.transactionId;
      if (txId != null) tx = await repos.transactions.delete(txId);
      activity = await repos.activity.removeFor(refTable: repos.obligationPayments.tableName, refId: p.id);
    });
    final deleted = pay;
    if (deleted == null) return null;
    final deletedTx = tx;
    final restoreDue = movedFrom;
    return () => _db.transaction(() async {
      await repos.obligationPayments.restore(deleted);
      if (deletedTx != null) await repos.transactions.restore(deletedTx);
      await repos.activityLog.restoreAll(activity);
      if (restoreDue != null) await repos.obligations.setColumn(deleted.obligationId, 'nextDue', restoreDue);
    });
  }

  // ============================================================== helpers ==

  Future<GoalsUndo?> _deleteWithTx<T extends Table, R extends DataClass>(
    EntityRepository<T, R> repo,
    String id,
    String txId,
  ) async {
    late final R? row;
    TransactionRow? tx;
    late final List<ActivityRow> activity;
    await _db.transaction(() async {
      row = await repo.delete(id);
      tx = await repos.transactions.delete(txId);
      activity = await repos.activity.removeFor(refTable: repo.tableName, refId: id);
    });
    final deleted = row;
    if (deleted == null) return null;
    final deletedTx = tx;
    return () => _db.transaction(() async {
      await repo.restore(deleted);
      if (deletedTx != null) await repos.transactions.restore(deletedTx);
      await repos.activityLog.restoreAll(activity);
    });
  }
}
