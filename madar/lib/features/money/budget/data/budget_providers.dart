import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart' show BudgetItemRow, TransactionRow;
import '../../../../core/db/repositories/repositories.dart';
import '../../../../core/domain/budget_math.dart';
import '../../../../core/domain/enums.dart';
import '../../../home/home_providers.dart' show homeClockProvider;
import '../domain/budget_plan.dart';
import '../domain/budget_spending.dart';
import 'budget_repository.dart';

/// The clock of the budget screens (home's clock; override in tests).
final budgetClockProvider = Provider<DateTime Function()>((ref) => ref.watch(homeClockProvider));

/// First day of a budgeting week (Saturday, like the working week in
/// Jordan). Override to change it.
final budgetWeekStartProvider = Provider<int>((ref) => DateTime.saturday);

/// Budget reads and writes with undo.
final budgetRepositoryProvider = Provider<BudgetRepository>(
  (ref) => BudgetRepository(ref.watch(repositoriesProvider), clock: ref.watch(budgetClockProvider)),
);

/// Today (local midnight).
final budgetTodayProvider = Provider.autoDispose<DateTime>((ref) {
  final now = ref.watch(budgetClockProvider)();
  return DateTime(now.year, now.month, now.day);
});

/// Every budget item row, in the user's order.
final budgetItemsProvider = StreamProvider.autoDispose<List<BudgetItemRow>>(
  (ref) => ref.watch(budgetRepositoryProvider).watchItems(),
);

/// Base currency, manual rates, decimals and symbols.
final budgetCurrenciesProvider = StreamProvider.autoDispose<BudgetCurrencies>(
  (ref) => ref.watch(budgetRepositoryProvider).watchCurrencies(),
);

/// Weeks per month (`key_values` `money.budget.weeksPerMonth`, default 4).
final budgetWeeksPerMonthProvider = StreamProvider.autoDispose<num>(
  (ref) => ref.watch(budgetRepositoryProvider).watchWeeksPerMonth(),
);

/// Budget settings (weeks per month, base currency, rates, week start).
final budgetSettingsProvider = Provider.autoDispose<AsyncValue<BudgetSettings>>((ref) {
  final weekStart = ref.watch(budgetWeekStartProvider);
  return _combine(
    ref.watch(budgetCurrenciesProvider),
    ref.watch(budgetWeeksPerMonthProvider),
    (BudgetCurrencies c, num w) => c.settings(weeksPerMonth: w).copyWith(weekStart: weekStart),
  );
});

/// The whole budget, computed exactly.
final budgetMathProvider = Provider.autoDispose<AsyncValue<BudgetMath>>((ref) {
  return _combine(
    ref.watch(budgetItemsProvider),
    ref.watch(budgetSettingsProvider),
    (List<BudgetItemRow> rows, BudgetSettings s) => BudgetMath(rows.map(budgetNodeOf), settings: s),
  );
});

/// The first day whose expenses the budget screens load (a year of
/// history plus the week overlapping it).
DateTime budgetHistoryStart(DateTime today) => DateTime(today.year - 1, today.month, 1 - 7);

/// Expenses of the last year as [BudgetTx] (currency = the wallet's).
final budgetExpensesProvider = Provider.autoDispose<AsyncValue<List<BudgetTx>>>((ref) {
  final since = budgetHistoryStart(ref.watch(budgetTodayProvider));
  return _combine(
    ref.watch(_expenseRowsProvider(since)),
    ref.watch(_walletCurrenciesProvider),
    BudgetRepository.toBudgetTxs,
  );
});

final _expenseRowsProvider = StreamProvider.autoDispose.family<List<TransactionRow>, DateTime>(
  (ref, since) => ref.watch(budgetRepositoryProvider).watchExpenses(since: since),
);

final _walletCurrenciesProvider = StreamProvider.autoDispose<Map<String, String>>(
  (ref) => ref.watch(budgetRepositoryProvider).watchWalletCurrencies(),
);

/// The plan with this month's overspending attached (the Plan tab).
final budgetPlanProvider = Provider.autoDispose<AsyncValue<BudgetPlan>>((ref) {
  final today = ref.watch(budgetTodayProvider);
  return _combine(
    ref.watch(budgetMathProvider),
    ref.watch(budgetExpensesProvider),
    (BudgetMath math, List<BudgetTx> txs) => BudgetPlan(math, report: math.spend(txs, BudgetWindow.month(today))),
  );
});

/// The period the Spending tab shows.
final budgetSpendWindowProvider = NotifierProvider.autoDispose<BudgetSpendWindow, BudgetWindow>(BudgetSpendWindow.new);

class BudgetSpendWindow extends Notifier<BudgetWindow> {
  /// How far back the Spending tab can go (periods).
  static const maxMonthsBack = 12;
  static const maxWeeksBack = 52;

  @override
  BudgetWindow build() =>
      BudgetPeriods.containing(BudgetPeriod.monthly, ref.watch(budgetTodayProvider), weekStart: _weekStart);

  int get _weekStart => ref.read(budgetWeekStartProvider);
  DateTime get _today => ref.read(budgetTodayProvider);

  BudgetWindow get _current => BudgetPeriods.containing(state.period, _today, weekStart: _weekStart);

  /// Shows the current month or week.
  void setPeriod(BudgetPeriod period) {
    if (period == state.period) return;
    state = BudgetPeriods.containing(period, _today, weekStart: _weekStart);
  }

  bool get canGoBack {
    final limit = BudgetPeriods.shift(
      _current,
      -(state.period == BudgetPeriod.weekly ? maxWeeksBack : maxMonthsBack),
      weekStart: _weekStart,
    );
    return state.start.isAfter(limit.start);
  }

  bool get canGoForward => state.start.isBefore(_current.start);

  void previous() {
    if (canGoBack) state = BudgetPeriods.shift(state, -1, weekStart: _weekStart);
  }

  void next() {
    if (canGoForward) state = BudgetPeriods.shift(state, 1, weekStart: _weekStart);
  }

  /// Jumps to [window] (e.g. a bar of the history chart), never past today.
  void show(BudgetWindow window) {
    state = window.start.isAfter(_current.start) ? _current : window;
  }
}

/// Spend vs plan in the selected period, with its history.
final budgetSpendingProvider = Provider.autoDispose<AsyncValue<BudgetSpending>>((ref) {
  final window = ref.watch(budgetSpendWindowProvider);
  final today = ref.watch(budgetTodayProvider);
  final weekStart = ref.watch(budgetWeekStartProvider);
  return _combine(
    ref.watch(budgetMathProvider),
    ref.watch(budgetExpensesProvider),
    (BudgetMath math, List<BudgetTx> txs) => BudgetSpending.build(
      math: math,
      transactions: txs,
      window: window,
      today: today,
      historyCount: window.period == BudgetPeriod.weekly ? 8 : 6,
      weekStart: weekStart,
    ),
  );
});

/// This month at a glance (the Money hub card): spend vs plan and the plan
/// with its warnings.
final budgetStatusProvider = Provider.autoDispose<AsyncValue<({BudgetPlan plan, BudgetSpending month})>>((ref) {
  final today = ref.watch(budgetTodayProvider);
  final weekStart = ref.watch(budgetWeekStartProvider);
  return _combine(ref.watch(budgetMathProvider), ref.watch(budgetExpensesProvider), (
    BudgetMath math,
    List<BudgetTx> txs,
  ) {
    final month = BudgetSpending.build(
      math: math,
      transactions: txs,
      window: BudgetWindow.month(today),
      today: today,
      historyCount: 1,
      weekStart: weekStart,
    );
    return (plan: BudgetPlan(math, report: month.report), month: month);
  });
});

AsyncValue<R> _combine<A, B, R>(AsyncValue<A> a, AsyncValue<B> b, R Function(A a, B b) f) {
  if (a case AsyncError(:final error, :final stackTrace)) return AsyncError<R>(error, stackTrace);
  if (b case AsyncError(:final error, :final stackTrace)) return AsyncError<R>(error, stackTrace);
  if (a.hasValue && b.hasValue) return AsyncData<R>(f(a.requireValue, b.requireValue));
  return AsyncLoading<R>();
}

/// Colours the user (or an import) gave to items, by id (ARGB).
final budgetStoredColorsProvider = Provider.autoDispose<Map<String, int>>((ref) {
  final rows = ref.watch(budgetItemsProvider).value ?? const <BudgetItemRow>[];
  return {
    for (final r in rows)
      if (r.color != null) r.id: r.color!,
  };
});
