/// Everything the goals screens show, computed once from the database rows
/// (pure: rows in, views out).
library;

import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../../../../core/db/database.dart';
import '../../../../core/domain/budget_math.dart' show BudgetSettings;
import '../../../../core/domain/money.dart';
import 'debt_ledger.dart';
import 'due_dates.dart';
import 'due_reminders.dart';
import 'goals_rates.dart';
import 'jar_plan.dart';
import 'obligation_plan.dart';

/// Default look-ahead for "due soon".
const int goalsSoonDays = 7;

/// A jar with its movements (newest first) and plan.
@immutable
class JarView {
  const JarView({required this.jar, required this.movements, required this.plan});

  final JarRow jar;
  final List<JarDepositRow> movements;
  final JarPlan plan;

  String get id => jar.id;
}

/// A debt with its payments (newest first) and state.
@immutable
class DebtView {
  const DebtView({required this.debt, required this.payments, required this.state});

  final DebtRow debt;
  final List<DebtPaymentRow> payments;
  final DebtState state;

  String get id => debt.id;
}

/// An obligation with its payment history (newest first) and state.
@immutable
class ObligationView {
  const ObligationView({required this.obligation, required this.payments, required this.state});

  final ObligationRow obligation;
  final List<ObligationPaymentRow> payments;
  final ObligationState state;

  String get id => obligation.id;

  /// A skipped period is stored as a zero payment without a transaction.
  static bool isSkip(ObligationPaymentRow p) => p.amountMilli == 0 && p.transactionId == null;

  /// Periods paid (skips excluded).
  int get paidCount => payments.where((p) => !isSkip(p)).length;
}

/// One line of the "upcoming dues" list.
@immutable
class DueEntry {
  const DueEntry.obligation(ObligationView this.obligation) : debt = null;
  const DueEntry.debt(DebtView this.debt) : obligation = null;

  final ObligationView? obligation;
  final DebtView? debt;

  DueReminderKind get kind => obligation != null ? DueReminderKind.obligation : DueReminderKind.debt;
  String get id => obligation?.id ?? debt!.id;
  String get title => obligation?.obligation.name ?? debt!.debt.person;
  DateTime get due => obligation?.state.nextDue ?? debt!.state.dueDate!;
  DueState get state => obligation?.state.dueState ?? debt!.state.dueState;
  int get amountMilli => obligation?.obligation.amountMilli ?? debt!.state.remainingMilli;
  String get currency => obligation?.obligation.currency ?? debt!.debt.currency;
}

/// The goals package's view of the database on one day.
@immutable
class GoalsSnapshot {
  const GoalsSnapshot._({
    required this.today,
    required this.rates,
    required this.weeksPerMonth,
    required this.jars,
    required this.archivedJars,
    required this.openDebts,
    required this.settledDebts,
    required this.obligations,
    required this.pausedObligations,
    required this.debtTotals,
    required this.obligationTotals,
    required this.wallets,
    required this.budgetItems,
  });

  factory GoalsSnapshot.build({
    required DateTime today,
    List<JarRow> jars = const [],
    List<JarDepositRow> deposits = const [],
    List<DebtRow> debts = const [],
    List<DebtPaymentRow> debtPayments = const [],
    List<ObligationRow> obligations = const [],
    List<ObligationPaymentRow> obligationPayments = const [],
    List<CurrencyRow> currencies = const [],
    List<WalletRow> wallets = const [],
    List<BudgetItemRow> budgetItems = const [],
    num weeksPerMonth = BudgetSettings.defaultWeeksPerMonth,
    int soonDays = goalsSoonDays,
  }) {
    final day = CalendarDays.of(today);
    final rates = ratesFromCurrencyRows(currencies);

    int newestFirst(DateTime a, DateTime b, DateTime ca, DateTime cb) {
      final c = b.compareTo(a);
      return c != 0 ? c : cb.compareTo(ca);
    }

    final depositsByJar = groupBy<JarDepositRow, String>(deposits, (d) => d.jarId);
    final jarViews = <JarView>[];
    final archived = <JarView>[];
    for (final j in jars) {
      final moves = [...?depositsByJar[j.id]]..sort((a, b) => newestFirst(a.date, b.date, a.createdAt, b.createdAt));
      final view = JarView(
        jar: j,
        movements: List.unmodifiable(moves),
        plan: JarPlan.compute(
          targetMilli: j.targetMilli,
          currency: j.currency,
          movements: [for (final m in moves) JarMovement(m.amountMilli, m.date)],
          today: day,
          rates: rates,
          start: j.createdAt,
          deadline: j.deadline,
        ),
      );
      (j.archived ? archived : jarViews).add(view);
    }

    final paymentsByDebt = groupBy<DebtPaymentRow, String>(debtPayments, (p) => p.debtId);
    final open = <DebtView>[];
    final settled = <DebtView>[];
    for (final d in debts) {
      final pays = [...?paymentsByDebt[d.id]]..sort((a, b) => newestFirst(a.date, b.date, a.createdAt, b.createdAt));
      final view = DebtView(
        debt: d,
        payments: List.unmodifiable(pays),
        state: DebtState.compute(
          direction: d.direction,
          currency: d.currency,
          amountMilli: d.amountMilli,
          payments: [for (final p in pays) DebtPaymentIn(p.amountMilli, p.date)],
          today: day,
          settledAt: d.settledAt,
          dueDate: d.dueDate,
          soonDays: soonDays,
        ),
      );
      (view.state.settled ? settled : open).add(view);
    }
    final order = {for (var i = 0; i < debts.length; i++) debts[i].id: i};
    open.sort((a, b) {
      final ad = a.state.dueDate, bd = b.state.dueDate;
      if (ad != null && bd != null && ad != bd) return ad.compareTo(bd);
      if ((ad == null) != (bd == null)) return ad == null ? 1 : -1;
      return order[a.id]!.compareTo(order[b.id]!);
    });
    settled.sort((a, b) {
      final ad = a.state.settledOn ?? a.debt.updatedAt, bd = b.state.settledOn ?? b.debt.updatedAt;
      return bd.compareTo(ad);
    });

    final paymentsByOb = groupBy<ObligationPaymentRow, String>(obligationPayments, (p) => p.obligationId);
    final active = <ObligationView>[];
    final paused = <ObligationView>[];
    for (final o in obligations) {
      final pays = [...?paymentsByOb[o.id]]..sort((a, b) => newestFirst(a.dueDate, b.dueDate, a.paidAt, b.paidAt));
      final view = ObligationView(
        obligation: o,
        payments: List.unmodifiable(pays),
        state: ObligationState.compute(
          frequency: o.frequency,
          interval: o.interval,
          nextDue: o.nextDue,
          today: day,
          active: o.active,
          history: [for (final p in pays) p.dueDate],
          soonDays: soonDays,
        ),
      );
      (o.active ? active : paused).add(view);
    }
    final obOrder = {for (var i = 0; i < obligations.length; i++) obligations[i].id: i};
    active.sort((a, b) {
      final c = a.state.nextDue.compareTo(b.state.nextDue);
      return c != 0 ? c : obOrder[a.id]!.compareTo(obOrder[b.id]!);
    });

    return GoalsSnapshot._(
      today: day,
      rates: rates,
      weeksPerMonth: weeksPerMonth,
      jars: List.unmodifiable(jarViews),
      archivedJars: List.unmodifiable(archived),
      openDebts: List.unmodifiable(open),
      settledDebts: List.unmodifiable(settled),
      obligations: List.unmodifiable(active),
      pausedObligations: List.unmodifiable(paused),
      debtTotals: DebtTotals.of([for (final d in open) d.state], rates),
      obligationTotals: ObligationTotals.of(
        [for (final o in active) (o.obligation.amountMilli, o.obligation.currency, o.state)],
        rates,
        weeksPerMonth: weeksPerMonth,
      ),
      wallets: Map.unmodifiable({for (final w in wallets) w.id: w}),
      budgetItems: Map.unmodifiable({for (final b in budgetItems) b.id: b}),
    );
  }

  /// An empty snapshot (nothing loaded yet / fresh install).
  factory GoalsSnapshot.empty(DateTime today) => GoalsSnapshot.build(today: today);

  final DateTime today;
  final GoalsRates rates;
  final num weeksPerMonth;

  /// Active jars in the user's order.
  final List<JarView> jars;
  final List<JarView> archivedJars;

  /// Open debts: soonest due first, then undated ones in the user's order.
  final List<DebtView> openDebts;

  /// Settled debts, most recently settled first.
  final List<DebtView> settledDebts;

  /// Active obligations, soonest due first.
  final List<ObligationView> obligations;
  final List<ObligationView> pausedObligations;

  final DebtTotals debtTotals;
  final ObligationTotals obligationTotals;

  /// Wallets and budget items by id (names for pickers and rows).
  final Map<String, WalletRow> wallets;
  final Map<String, BudgetItemRow> budgetItems;

  bool get isEmpty =>
      jars.isEmpty &&
      archivedJars.isEmpty &&
      openDebts.isEmpty &&
      settledDebts.isEmpty &&
      obligations.isEmpty &&
      pausedObligations.isEmpty;

  JarView? jar(String id) => [...jars, ...archivedJars].firstWhereOrNull((j) => j.id == id);
  DebtView? debt(String id) => [...openDebts, ...settledDebts].firstWhereOrNull((d) => d.id == id);
  ObligationView? obligation(String id) => [...obligations, ...pausedObligations].firstWhereOrNull((o) => o.id == id);

  /// Saved in all active jars, base currency (negative balances count 0).
  int get jarsSavedBaseMilli => jars
      .fold(Rational.zero, (a, j) => a + rates.toBaseExact(math.max(0, j.plan.savedMilli), j.jar.currency))
      .roundHalfUp();

  /// Targets of all active jars, base currency.
  int get jarsTargetBaseMilli =>
      jars.fold(Rational.zero, (a, j) => a + rates.toBaseExact(j.plan.targetMilli, j.jar.currency)).roundHalfUp();

  /// What all active jars with a deadline need this month, base currency.
  int get jarsMonthlyNeedBaseMilli => jars
      .fold(Rational.zero, (a, j) => a + rates.toBaseExact(j.plan.requiredPerMonthMilli ?? 0, j.jar.currency))
      .roundHalfUp();

  /// Overall jar progress (0..1), by base value.
  double get jarsProgress {
    final t = jarsTargetBaseMilli;
    if (t <= 0) return 0;
    final saved = jars
        .fold(
          Rational.zero,
          (a, j) => a + rates.toBaseExact(math.min(j.plan.targetMilli, math.max(0, j.plan.savedMilli)), j.jar.currency),
        )
        .roundHalfUp();
    return (saved / t).clamp(0.0, 1.0);
  }

  /// Obligations and open debts that are overdue or due within
  /// [withinDays], overdue first, then by date.
  List<DueEntry> dues({int withinDays = 14}) {
    final horizon = CalendarDays.addDays(today, withinDays);
    final out = <DueEntry>[
      for (final o in obligations)
        if (!o.state.nextDue.isAfter(horizon)) DueEntry.obligation(o),
      for (final d in openDebts)
        if (d.state.dueDate != null && !d.state.dueDate!.isAfter(horizon)) DueEntry.debt(d),
    ];
    out.sort((a, b) {
      final c = a.due.compareTo(b.due);
      if (c != 0) return c;
      return a.kind.index.compareTo(b.kind.index);
    });
    return out;
  }

  /// Everything with a future (or today's) due date, for reminders.
  List<DueItem> get dueItems => [
    for (final o in obligations) DueItem(kind: DueReminderKind.obligation, refId: o.id, due: o.state.nextDue),
    for (final d in openDebts)
      if (d.state.dueDate != null) DueItem(kind: DueReminderKind.debt, refId: d.id, due: d.state.dueDate!),
  ];
}

/// The `currencies` table as [GoalsRates] (base = the row marked base, else
/// the first row, else JOD).
GoalsRates ratesFromCurrencyRows(Iterable<CurrencyRow> rows) {
  final list = rows.toList();
  final base = list.firstWhereOrNull((c) => c.isBase)?.code ?? list.firstOrNull?.code ?? 'JOD';
  return GoalsRates(
    base: base,
    currencies: [
      for (final c in list)
        GoalsCurrency(
          code: c.code,
          rateToBase: c.isBase ? 1 : c.rateToBase,
          decimals: c.decimals,
          symbol: c.symbol,
          isBase: c.isBase,
        ),
    ],
  );
}
