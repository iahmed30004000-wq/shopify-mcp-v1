/// Savings-jar arithmetic (pure Dart, exact integer milli-units).
///
/// * **Saved** is the signed sum of the jar's movements (deposits positive,
///   withdrawals negative – the `jar_deposits` convention).
/// * **Required per month** spreads what is left over the whole calendar
///   months remaining before the deadline (at least one), rounded **up** to
///   the currency's minor unit so following the plan always reaches the
///   target. The weekly figure does the same over whole weeks.
/// * **Pace** compares progress with a straight line from the jar's start
///   to its deadline.
/// * **ETA** projects the average saving rate since the first deposit.
library;

import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../../../../core/domain/money.dart';
import 'due_dates.dart';
import 'goals_rates.dart';

/// One deposit (positive) or withdrawal (negative) of a jar.
@immutable
class JarMovement {
  const JarMovement(this.amountMilli, this.date);

  final int amountMilli;
  final DateTime date;
}

/// Where a jar stands against its deadline.
enum JarPace {
  /// Target reached.
  reached,

  /// Keeping up with (or ahead of) a straight line to the deadline.
  onTrack,

  /// Behind the straight line.
  behind,

  /// Deadline passed before reaching the target.
  overdue,

  /// No deadline (or no target) to measure against.
  open,
}

/// Progress, requirement and pace of one jar.
@immutable
class JarPlan {
  const JarPlan._({
    required this.targetMilli,
    required this.savedMilli,
    required this.currency,
    required this.pace,
    this.deadline,
    this.daysLeft,
    this.monthsLeft,
    this.requiredPerMonthMilli,
    this.requiredPerWeekMilli,
    this.expectedProgress,
    this.eta,
  });

  /// Computes the plan of a jar on [today].
  ///
  /// [start] is when saving began (the jar's creation day); the pace line
  /// runs from the earlier of [start] and the first movement to [deadline].
  factory JarPlan.compute({
    required int targetMilli,
    required String currency,
    required Iterable<JarMovement> movements,
    required DateTime today,
    required GoalsRates rates,
    DateTime? start,
    DateTime? deadline,
  }) {
    final day = CalendarDays.of(today);
    final list = movements.toList();
    final saved = list.fold<int>(0, (a, m) => a + m.amountMilli);
    final int target = math.max(0, targetMilli);
    final int remaining = math.max(0, target - math.max(0, saved));
    final reached = target > 0 && remaining == 0;

    DateTime? first;
    for (final m in list) {
      final d = CalendarDays.of(m.date);
      if (first == null || d.isBefore(first)) first = d;
    }
    var origin = start == null ? null : CalendarDays.of(start);
    if (first != null && (origin == null || first.isBefore(origin))) origin = first;

    final due = deadline == null ? null : CalendarDays.of(deadline);
    int? daysLeft, monthsLeft, perMonth, perWeek;
    double? expected;
    var pace = JarPace.open;
    if (reached) {
      pace = JarPace.reached;
    }
    if (due != null) {
      daysLeft = CalendarDays.between(day, due);
      if (!reached && target > 0) {
        if (daysLeft < 0) {
          pace = JarPace.overdue;
          perMonth = remaining;
          perWeek = remaining;
          monthsLeft = 0;
        } else {
          monthsLeft = math.max(1, CalendarDays.monthsBetween(day, due));
          final weeks = math.max(1, daysLeft ~/ 7);
          perMonth = rates.ceilToMinor(Rational.fromInt(remaining, monthsLeft), currency);
          perWeek = rates.ceilToMinor(Rational.fromInt(remaining, weeks), currency);
        }
      }
      if (origin != null) {
        final total = CalendarDays.between(origin, due);
        if (total > 0) {
          expected = (CalendarDays.between(origin, day) / total).clamp(0.0, 1.0);
        } else {
          expected = 1;
        }
        if (!reached && pace != JarPace.overdue && target > 0) {
          final progress = math.max(0, saved) / target;
          // A little slack (2 % of the target) so a plan followed to the
          // fils does not flicker between "on track" and "behind".
          pace = progress + 0.02 >= expected ? JarPace.onTrack : JarPace.behind;
        }
      }
    }

    DateTime? eta;
    if (!reached && target > 0 && saved > 0 && first != null) {
      final elapsed = math.max(30, CalendarDays.between(first, day));
      final days = (remaining * elapsed / saved).ceil();
      if (days <= 365 * 50) eta = CalendarDays.addDays(day, days);
    }

    return JarPlan._(
      targetMilli: target,
      savedMilli: saved,
      currency: currency,
      pace: pace,
      deadline: due,
      daysLeft: daysLeft,
      monthsLeft: monthsLeft,
      requiredPerMonthMilli: perMonth,
      requiredPerWeekMilli: perWeek,
      expectedProgress: expected,
      eta: eta,
    );
  }

  final int targetMilli;

  /// Signed sum of the movements (may be negative after over-withdrawing).
  final int savedMilli;
  final String currency;
  final JarPace pace;
  final DateTime? deadline;

  /// Calendar days to the deadline (negative once it has passed).
  final int? daysLeft;

  /// Whole calendar months the requirement is spread over (≥ 1 before the
  /// deadline, 0 after it).
  final int? monthsLeft;

  /// Needed each month to reach the target by the deadline (the whole
  /// remainder once it has passed); null when reached or without deadline.
  final int? requiredPerMonthMilli;

  /// The same per week.
  final int? requiredPerWeekMilli;

  /// Where a straight line from the start to the deadline says the jar
  /// should be today (0..1); null without deadline.
  final double? expectedProgress;

  /// When the target is reached at the average rate saved so far.
  final DateTime? eta;

  /// What is still missing (never negative).
  int get remainingMilli => math.max(0, targetMilli - math.max(0, savedMilli));

  /// Saved beyond the target.
  int get surplusMilli => math.max(0, savedMilli - targetMilli);

  bool get reached => pace == JarPace.reached;

  /// Progress 0..1 (a jar without target shows full once anything is saved).
  double get progress {
    if (targetMilli <= 0) return savedMilli > 0 ? 1 : 0;
    return (savedMilli / targetMilli).clamp(0.0, 1.0);
  }

  /// Progress without the upper clamp (1.25 = 125 %).
  double get rawProgress => targetMilli <= 0 ? progress : math.max(0, savedMilli) / targetMilli;

  /// The cumulative balance after each day with movements, oldest first
  /// (for the trajectory chart).
  static List<(DateTime, int)> series(Iterable<JarMovement> movements) {
    final byDay = <DateTime, int>{};
    for (final m in movements) {
      final d = CalendarDays.of(m.date);
      byDay[d] = (byDay[d] ?? 0) + m.amountMilli;
    }
    final days = byDay.keys.toList()..sort();
    var running = 0;
    return [for (final d in days) (d, running += byDay[d]!)];
  }
}
