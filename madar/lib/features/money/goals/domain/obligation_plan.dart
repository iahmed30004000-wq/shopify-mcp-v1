/// Recurring obligations: what "Paid" and "Skip" do to the next due date,
/// due states, overdue periods and the monthly cost of all commitments
/// (pure Dart, exact).
library;

import 'package:meta/meta.dart';

import '../../../../core/domain/budget_math.dart' show BudgetSettings;
import '../../../../core/domain/enums.dart';
import '../../../../core/domain/money.dart';
import 'due_dates.dart';
import 'goals_rates.dart';

/// The result of paying (or skipping) the current period.
@immutable
class ObligationStep {
  const ObligationStep({required this.paidDue, required this.nextDue, this.anchorDay});

  /// The due date being paid or skipped (the old `next_due`).
  final DateTime paidDue;

  /// The new `next_due`.
  final DateTime nextDue;

  /// The day of month the schedule is anchored to (null for weekly).
  final int? anchorDay;
}

/// The state of one obligation on a given day.
@immutable
class ObligationState {
  const ObligationState._({
    required this.rule,
    required this.nextDue,
    required this.anchorDay,
    required this.active,
    required this.dueState,
    required this.daysToDue,
    required this.periodsDue,
  });

  /// [history] holds the due dates already paid or skipped (any order); it
  /// recovers the month-day anchor that clamping may have hidden.
  factory ObligationState.compute({
    required Recurrence frequency,
    required int interval,
    required DateTime nextDue,
    required DateTime today,
    bool active = true,
    Iterable<DateTime> history = const [],
    int soonDays = 7,
  }) {
    final rule = RecurrenceRule(frequency, interval);
    final due = CalendarDays.of(nextDue);
    final day = CalendarDays.of(today);
    final anchor = rule.anchorDayFor(due, history);
    final periods = due.isAfter(day) ? 0 : rule.occurrences(due, day, anchorDay: anchor, max: 999).length;
    return ObligationState._(
      rule: rule,
      nextDue: due,
      anchorDay: anchor,
      active: active,
      dueState: active ? dueStateOf(due, day, soonDays: soonDays) : DueState.none,
      daysToDue: CalendarDays.between(day, due),
      periodsDue: periods,
    );
  }

  final RecurrenceRule rule;
  final DateTime nextDue;
  final int? anchorDay;
  final bool active;

  /// [DueState.none] while paused.
  final DueState dueState;

  /// Calendar days to [nextDue] (negative when overdue).
  final int daysToDue;

  /// Periods due and unpaid up to today (1 on the due day, 2 when a whole
  /// further period has also come due …; 0 before the due date).
  final int periodsDue;

  bool get overdue => dueState == DueState.overdue;

  /// "Paid" / "Skip": the current period moves to the history and the next
  /// due date follows the rule (month ends clamped, the anchor kept).
  ObligationStep advance() => ObligationStep(
    paidDue: nextDue,
    nextDue: rule.next(nextDue, anchorDay: anchorDay),
    anchorDay: anchorDay,
  );

  /// The next [count] due dates, starting with [nextDue].
  List<DateTime> upcoming(int count) => rule.upcoming(nextDue, count, anchorDay: anchorDay);
}

/// Cost of obligations per month and their due counts.
@immutable
class ObligationTotals {
  const ObligationTotals({
    required this.baseCurrency,
    required this.monthlyBaseMilli,
    required this.activeCount,
    required this.overdueCount,
    required this.dueSoonCount,
    required this.missingRates,
  });

  /// Sums the monthly share of every active obligation in [items]
  /// (amount, currency, state) in the base currency.
  factory ObligationTotals.of(
    Iterable<(int amountMilli, String currency, ObligationState state)> items,
    GoalsRates rates, {
    num weeksPerMonth = BudgetSettings.defaultWeeksPerMonth,
  }) {
    var monthly = Rational.zero;
    var active = 0, overdue = 0, soon = 0;
    final missing = <String>{};
    for (final (amount, currency, state) in items) {
      if (!state.active) continue;
      active++;
      if (!rates.hasRate(currency)) missing.add(currency.toUpperCase());
      monthly +=
          monthlyShare(amount, state.rule, weeksPerMonth: weeksPerMonth) * (rates.rateOf(currency) ?? Rational.one);
      if (state.overdue) overdue++;
      if (state.dueState == DueState.today || state.dueState == DueState.soon) soon++;
    }
    return ObligationTotals(
      baseCurrency: rates.base,
      monthlyBaseMilli: monthly.roundHalfUp(),
      activeCount: active,
      overdueCount: overdue,
      dueSoonCount: soon,
      missingRates: Set.unmodifiable(missing),
    );
  }

  final String baseCurrency;

  /// What all active obligations cost per month (weekly ones × the
  /// weeks-per-month setting, yearly ones ÷ 12), base currency.
  final int monthlyBaseMilli;
  final int activeCount;
  final int overdueCount;
  final int dueSoonCount;
  final Set<String> missingRates;

  /// The exact monthly share of [amountMilli] recurring by [rule]:
  /// weekly × weeks-per-month ÷ interval, monthly ÷ interval, yearly ÷ 12 ×
  /// interval (in the obligation's own currency).
  static Rational monthlyShare(int amountMilli, RecurrenceRule rule, {num weeksPerMonth = 4}) {
    final a = Rational.fromInt(amountMilli);
    final wpm = weeksPerMonth <= 0
        ? Rational.fromNum(BudgetSettings.defaultWeeksPerMonth)
        : Rational.fromNum(weeksPerMonth);
    return switch (rule.frequency) {
      Recurrence.weekly => a * wpm / Rational.fromInt(rule.interval),
      Recurrence.monthly => a / Rational.fromInt(rule.interval),
      Recurrence.yearly => a / Rational.fromInt(12 * rule.interval),
    };
  }
}
