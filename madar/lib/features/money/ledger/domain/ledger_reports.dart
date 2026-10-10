/// Spending breakdowns and income-vs-expense trends in the base currency
/// (pure Dart, exact: each figure is an exact sum rounded once).
///
/// Periods reuse [BudgetWindow] from the budget math so the ledger's "this
/// month / this week" is the budget's.
library;

import 'package:meta/meta.dart';

import '../../../../core/domain/budget_math.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/domain/money.dart';
import 'ledger_math.dart';
import 'ledger_models.dart';

/// Money flowing in and out over some set of entries, in the base currency.
/// Transfers and adjustments are movements, not income or spending.
@immutable
class LedgerFlow {
  const LedgerFlow({this.incomeMilli = 0, this.expenseMilli = 0, this.count = 0, this.missingRates = const {}});

  final int incomeMilli;
  final int expenseMilli;

  /// Entries counted (all kinds).
  final int count;
  final Set<String> missingRates;

  int get netMilli => incomeMilli - expenseMilli;
}

/// One slice of a spending breakdown.
@immutable
class SpendSlice {
  const SpendSlice({required this.id, required this.baseMilli, this.share = 0});

  /// Budget item or wallet id; null = no budget item ("unassigned").
  final String? id;
  final int baseMilli;

  /// Fraction of the breakdown's total (0..1) – for display only.
  final double share;

  @override
  String toString() => 'SpendSlice($id $baseMilli)';
}

@immutable
class SpendBreakdown {
  const SpendBreakdown({required this.slices, required this.totalMilli, this.missingRates = const {}});

  static const empty = SpendBreakdown(slices: [], totalMilli: 0);

  /// Largest first.
  final List<SpendSlice> slices;
  final int totalMilli;
  final Set<String> missingRates;

  bool get isEmpty => totalMilli == 0;
}

/// Income and expenses of one period.
@immutable
class TrendBucket {
  const TrendBucket({required this.window, required this.incomeMilli, required this.expenseMilli});

  final BudgetWindow window;
  final int incomeMilli;
  final int expenseMilli;

  int get netMilli => incomeMilli - expenseMilli;
}

/// Which wallets a report looks at.
typedef WalletPredicate = bool Function(String walletId);

abstract final class LedgerReports {
  /// Income / expenses of [txs] converted with [rates] ([walletCurrency]
  /// gives each wallet's currency).
  static LedgerFlow flow(
    Iterable<LedgerTx> txs, {
    required Map<String, String> walletCurrency,
    required LedgerRates rates,
  }) {
    final income = BaseSum(rates), expense = BaseSum(rates);
    var count = 0;
    for (final tx in txs) {
      count++;
      final code = walletCurrency[tx.walletId] ?? rates.base;
      if (tx.kind == TxKind.income) income.add(tx.amountMilli.abs(), code);
      if (tx.kind == TxKind.expense) expense.add(tx.amountMilli.abs(), code);
    }
    return LedgerFlow(
      incomeMilli: income.milli,
      expenseMilli: expense.milli,
      count: count,
      missingRates: {...income.missing, ...expense.missing},
    );
  }

  /// Expenses in [window] per top-level budget item (children roll up into
  /// their root, following [budget]'s tree); entries without an item – or
  /// pointing at a deleted one – form the `id: null` slice.
  static SpendBreakdown spendingByBudgetItem(
    Iterable<LedgerTx> txs,
    BudgetWindow window, {
    required Map<String, String> walletCurrency,
    required LedgerRates rates,
    BudgetMath? budget,
    WalletPredicate? wallets,
  }) {
    final sums = <String?, BaseSum>{};
    final missing = <String>{};
    for (final tx in txs) {
      if (tx.kind != TxKind.expense || !window.contains(tx.date)) continue;
      if (wallets != null && !wallets(tx.walletId)) continue;
      final root = rootOf(budget, tx.budgetItemId);
      sums.putIfAbsent(root, () => BaseSum(rates)).add(tx.amountMilli.abs(), walletCurrency[tx.walletId] ?? rates.base);
    }
    return _breakdown(sums, missing);
  }

  /// Expenses in [window] per wallet.
  static SpendBreakdown spendingByWallet(
    Iterable<LedgerTx> txs,
    BudgetWindow window, {
    required Map<String, String> walletCurrency,
    required LedgerRates rates,
    WalletPredicate? wallets,
  }) {
    final sums = <String?, BaseSum>{};
    for (final tx in txs) {
      if (tx.kind != TxKind.expense || !window.contains(tx.date)) continue;
      if (wallets != null && !wallets(tx.walletId)) continue;
      sums
          .putIfAbsent(tx.walletId, () => BaseSum(rates))
          .add(tx.amountMilli.abs(), walletCurrency[tx.walletId] ?? rates.base);
    }
    return _breakdown(sums, <String>{});
  }

  static SpendBreakdown _breakdown(Map<String?, BaseSum> sums, Set<String> missing) {
    var total = Rational.zero;
    for (final s in sums.values) {
      total += s.exact;
      missing.addAll(s.missing);
    }
    final totalMilli = total.roundHalfUp();
    final slices =
        [
          for (final e in sums.entries)
            if (e.value.milli != 0)
              SpendSlice(
                id: e.key,
                baseMilli: e.value.milli,
                share: total.isZero ? 0 : (e.value.exact / total).toDouble(),
              ),
        ]..sort((a, b) {
          final c = b.baseMilli.compareTo(a.baseMilli);
          if (c != 0) return c;
          // Unassigned last among equals, then by id for stability.
          if (a.id == null) return 1;
          if (b.id == null) return -1;
          return a.id!.compareTo(b.id!);
        });
    return SpendBreakdown(
      slices: List.unmodifiable(slices),
      totalMilli: totalMilli,
      missingRates: Set.unmodifiable(missing),
    );
  }

  /// The top-level ancestor of [itemId] in [budget] (null when unknown).
  static String? rootOf(BudgetMath? budget, String? itemId) {
    if (itemId == null || budget == null) return null;
    var r = budget[itemId];
    if (r == null) return null;
    var guard = 0;
    while (r!.parentId != null && guard++ < 64) {
      final p = budget[r.parentId!];
      if (p == null) break;
      r = p;
    }
    return r.node.id;
  }

  /// [window] moved by [steps] periods (negative = back in time).
  static BudgetWindow shift(BudgetWindow window, int steps, {int weekStart = DateTime.saturday}) {
    final s = window.start;
    return switch (window.period) {
      BudgetPeriod.monthly => BudgetWindow.month(DateTime(s.year, s.month + steps)),
      BudgetPeriod.weekly => BudgetWindow.week(DateTime(s.year, s.month, s.day + 7 * steps), weekStart: weekStart),
    };
  }

  /// The window of [period] containing [day].
  static BudgetWindow windowOf(DateTime day, BudgetPeriod period, {int weekStart = DateTime.saturday}) =>
      period == BudgetPeriod.monthly ? BudgetWindow.month(day) : BudgetWindow.week(day, weekStart: weekStart);

  /// Income and expenses of the [count] periods ending with the one
  /// containing [anchor], oldest first.
  static List<TrendBucket> trend(
    Iterable<LedgerTx> txs, {
    required DateTime anchor,
    required Map<String, String> walletCurrency,
    required LedgerRates rates,
    BudgetPeriod period = BudgetPeriod.monthly,
    int count = 6,
    int weekStart = DateTime.saturday,
    WalletPredicate? wallets,
  }) {
    final last = windowOf(anchor, period, weekStart: weekStart);
    final windows = [for (var i = count - 1; i >= 0; i--) shift(last, -i, weekStart: weekStart)];
    final income = [for (final _ in windows) BaseSum(rates)];
    final expense = [for (final _ in windows) BaseSum(rates)];
    for (final tx in txs) {
      if (tx.kind != TxKind.income && tx.kind != TxKind.expense) continue;
      if (wallets != null && !wallets(tx.walletId)) continue;
      final i = windows.indexWhere((w) => w.contains(tx.date));
      if (i < 0) continue;
      (tx.kind == TxKind.income ? income : expense)[i].add(
        tx.amountMilli.abs(),
        walletCurrency[tx.walletId] ?? rates.base,
      );
    }
    return [
      for (var i = 0; i < windows.length; i++)
        TrendBucket(window: windows[i], incomeMilli: income[i].milli, expenseMilli: expense[i].milli),
    ];
  }

  /// Entries whose day falls in [window].
  static Iterable<LedgerTx> inWindow(Iterable<LedgerTx> txs, BudgetWindow window) =>
      txs.where((tx) => window.contains(LedgerMath.dayOf(tx.date)));
}
