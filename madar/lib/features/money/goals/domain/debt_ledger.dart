/// Debt arithmetic: what is paid, what remains, due states and totals per
/// direction in the base currency (pure Dart, exact).
library;

import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../../../../core/domain/enums.dart';
import '../../../../core/domain/money.dart';
import 'due_dates.dart';
import 'goals_rates.dart';

/// One partial payment of a debt (positive, in the debt's currency).
@immutable
class DebtPaymentIn {
  const DebtPaymentIn(this.amountMilli, this.date);

  final int amountMilli;
  final DateTime date;
}

/// The state of one debt on a given day.
@immutable
class DebtState {
  const DebtState._({
    required this.direction,
    required this.currency,
    required this.amountMilli,
    required this.paidMilli,
    required this.settled,
    required this.settledOn,
    required this.dueDate,
    required this.dueState,
    required this.daysToDue,
    required this.explicitlySettled,
  });

  /// [payments] are the debt's partial payments (their sign is ignored).
  /// A debt is settled when it was marked settled ([settledAt]) or its
  /// payments cover the whole amount – the same rule the Money planet uses.
  factory DebtState.compute({
    required DebtDirection direction,
    required String currency,
    required int amountMilli,
    required Iterable<DebtPaymentIn> payments,
    required DateTime today,
    DateTime? settledAt,
    DateTime? dueDate,
    int soonDays = 7,
  }) {
    final amount = amountMilli.abs();
    var paid = 0;
    DateTime? last;
    for (final p in payments) {
      paid += p.amountMilli.abs();
      final d = CalendarDays.of(p.date);
      if (last == null || d.isAfter(last)) last = d;
    }
    final paidInFull = amount > 0 && paid >= amount;
    final settled = settledAt != null || paidInFull;
    final due = dueDate == null ? null : CalendarDays.of(dueDate);
    final day = CalendarDays.of(today);
    return DebtState._(
      direction: direction,
      currency: currency,
      amountMilli: amount,
      paidMilli: paid,
      settled: settled,
      explicitlySettled: settledAt != null,
      settledOn: settledAt != null ? CalendarDays.of(settledAt) : (paidInFull ? last : null),
      dueDate: due,
      dueState: settled ? DueState.none : dueStateOf(due, day, soonDays: soonDays),
      daysToDue: due == null ? null : CalendarDays.between(day, due),
    );
  }

  final DebtDirection direction;
  final String currency;
  final int amountMilli;
  final int paidMilli;

  /// Marked settled, or paid in full.
  final bool settled;

  /// Marked settled by the user (`settled_at` set).
  final bool explicitlySettled;

  /// The day it was settled (or the day of the last payment when paid in
  /// full without being marked).
  final DateTime? settledOn;
  final DateTime? dueDate;

  /// [DueState.none] once settled.
  final DueState dueState;

  /// Calendar days to the due date (negative once past).
  final int? daysToDue;

  /// Still to pay (0 once settled).
  int get remainingMilli => settled ? 0 : math.max(0, amountMilli - paidMilli);

  /// Not covered by payments, whether or not the debt was closed.
  int get unpaidMilli => math.max(0, amountMilli - paidMilli);

  /// Closed without being paid in full (forgiven / written off).
  int get writtenOffMilli => explicitlySettled ? unpaidMilli : 0;

  /// Paid in excess of the amount.
  int get overpaidMilli => math.max(0, paidMilli - amountMilli);

  /// Repaid share (0..1).
  double get paidRatio => amountMilli <= 0 ? (settled ? 1 : 0) : (paidMilli / amountMilli).clamp(0.0, 1.0);

  bool get overdue => dueState == DueState.overdue;

  /// Whether a payment of [milli] would pay it off.
  bool paysOff(int milli) => !settled && milli.abs() >= math.max(0, amountMilli - paidMilli);
}

/// Open debts per direction, in the base currency.
@immutable
class DebtTotals {
  const DebtTotals({
    required this.baseCurrency,
    required this.iOweBaseMilli,
    required this.owedToMeBaseMilli,
    required this.iOweCount,
    required this.owedToMeCount,
    required this.overdueCount,
    required this.dueSoonCount,
    required this.missingRates,
  });

  /// Sums the remaining amounts of every open debt in [states], converted
  /// exactly at the manual [rates] and rounded once per direction.
  factory DebtTotals.of(Iterable<DebtState> states, GoalsRates rates) {
    var owe = Rational.zero, owed = Rational.zero;
    var oweCount = 0, owedCount = 0, overdue = 0, soon = 0;
    final missing = <String>{};
    for (final s in states) {
      if (s.settled) continue;
      final remaining = s.remainingMilli;
      if (!rates.hasRate(s.currency)) missing.add(s.currency.toUpperCase());
      final base = rates.toBaseExact(remaining, s.currency);
      if (s.direction == DebtDirection.iOwe) {
        owe += base;
        oweCount++;
      } else {
        owed += base;
        owedCount++;
      }
      if (s.overdue) overdue++;
      if (s.dueState == DueState.today || s.dueState == DueState.soon) soon++;
    }
    return DebtTotals(
      baseCurrency: rates.base,
      iOweBaseMilli: owe.roundHalfUp(),
      owedToMeBaseMilli: owed.roundHalfUp(),
      iOweCount: oweCount,
      owedToMeCount: owedCount,
      overdueCount: overdue,
      dueSoonCount: soon,
      missingRates: Set.unmodifiable(missing),
    );
  }

  final String baseCurrency;
  final int iOweBaseMilli;
  final int owedToMeBaseMilli;
  final int iOweCount;
  final int owedToMeCount;
  final int overdueCount;

  /// Open debts due today or within the soon window.
  final int dueSoonCount;

  /// Currencies without a usable rate (counted 1:1).
  final Set<String> missingRates;

  /// Owed to me − I owe (positive = others owe me more).
  int get netBaseMilli => owedToMeBaseMilli - iOweBaseMilli;

  int get openCount => iOweCount + owedToMeCount;
}
