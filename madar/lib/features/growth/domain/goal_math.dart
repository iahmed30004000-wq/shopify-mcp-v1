import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'growth_days.dart';

/// One logged amount of progress (the domain's view of a `GoalLogRow`).
@immutable
class GoalEntry {
  const GoalEntry({required this.amount, required this.at});

  final double amount;
  final DateTime at;
}

/// Where a goal stands.
enum GoalStatus { active, paused, completed }

/// How a goal is doing against its deadline (or without one).
enum GoalPace {
  /// The target is reached (possibly passed).
  completed,

  /// Paused by the user: no judgement.
  paused,

  /// Nothing logged yet.
  notStarted,

  /// In progress, no deadline to judge against.
  noDeadline,

  /// The recent pace finishes well before the deadline.
  ahead,

  /// The recent pace finishes by the deadline.
  onTrack,

  /// The recent pace would finish after the deadline.
  behind,

  /// The deadline has passed and the target is not reached.
  overdue,
}

/// A goal's progress, pace and projection on a given day. Build it with
/// [GoalMath.compute].
///
/// * Progress = the starting value + everything logged; the fraction is
///   measured against the target (like the orbit's growth score).
/// * Needed pace = what is left ÷ the days left, today included.
/// * Actual pace = what was logged over the last [paceWindow] days (fewer
///   when the goal is younger) ÷ those days.
/// * Projected finish = the day the actual pace reaches the target, today
///   counted as the first day.
@immutable
class GoalStats {
  const GoalStats({
    required this.initial,
    required this.target,
    required this.logged,
    required this.start,
    required this.today,
    required this.deadline,
    required this.active,
    required this.logCount,
    required this.elapsedDays,
    required this.daysLeft,
    required this.paceWindow,
    required this.actualPerDay,
    required this.neededPerDay,
    required this.expectedNow,
    required this.projectedFinish,
    required this.completedOn,
    required this.pace,
  });

  /// The value the goal started from.
  final double initial;
  final double target;

  /// Sum of every logged amount.
  final double logged;

  /// First day of the goal: its creation day, or an earlier back-dated log.
  final DateTime start;
  final DateTime today;
  final DateTime? deadline;
  final bool active;
  final int logCount;

  /// Days from [start] to [today], both included (at least 1).
  final int elapsedDays;

  /// Days left until the end of the deadline day, today included (0 once it
  /// has passed); null without a deadline.
  final int? daysLeft;

  /// Days the actual pace is measured over.
  final int paceWindow;
  final double actualPerDay;

  /// Null without a deadline, once completed, or once overdue.
  final double? neededPerDay;

  /// Where a straight line from the starting value to the target would be
  /// at the start of today; null without a deadline.
  final double? expectedNow;

  /// Null when completed, with no recent pace, or more than ten years out.
  final DateTime? projectedFinish;

  /// The day the running total first reached the target.
  final DateTime? completedOn;
  final GoalPace pace;

  double get current => initial + logged;

  /// Raw fraction of the target (above 1 when exceeded).
  double get fraction => target > 0 ? current / target : 1;

  /// [fraction] clamped to 0…1 (rings and bars).
  double get progress => fraction.clamp(0.0, 1.0);
  double get remaining => math.max(0, target - current);

  /// How far past the target (0 until reached).
  double get overshoot => math.max(0, current - target);
  bool get completed => pace == GoalPace.completed;

  GoalStatus get status => completed
      ? GoalStatus.completed
      : active
      ? GoalStatus.active
      : GoalStatus.paused;

  double? get neededPerWeek => neededPerDay == null ? null : neededPerDay! * 7;
  double get actualPerWeek => actualPerDay * 7;

  /// Actual ÷ needed pace (null without a needed pace).
  double? get paceRatio {
    final n = neededPerDay;
    if (n == null || n <= 0) return null;
    return actualPerDay / n;
  }

  /// Days the projection lands after (+) or before (−) the deadline.
  int? get projectedSlip {
    final p = projectedFinish, d = deadline;
    return p == null || d == null ? null : GrowthDays.between(d, p);
  }

  /// Current value minus the straight-line plan (negative = behind plan).
  double? get vsPlan => expectedNow == null ? null : current - expectedNow!;

  /// Days past the deadline (0 before or on it).
  int get daysOverdue {
    final d = deadline;
    return d == null ? 0 : math.max(0, GrowthDays.between(d, today));
  }
}

abstract final class GoalMath {
  /// Days the actual pace looks back over.
  static const int paceWindowDays = 14;

  /// Actual ÷ needed pace from which a goal counts as ahead.
  static const double aheadRatio = 1.25;

  /// Projections further out than this are dropped.
  static const int horizonDays = 3650;
  static const double eps = 1e-9;

  static GoalStats compute({
    required double initial,
    required double target,
    required Iterable<GoalEntry> entries,
    required DateTime created,
    required DateTime today,
    DateTime? deadline,
    bool active = true,
    int window = paceWindowDays,
  }) {
    final day = GrowthDays.dateOnly(today);
    final sorted = entries.toList()..sort((a, b) => a.at.compareTo(b.at));
    var start = GrowthDays.dateOnly(created);
    if (sorted.isNotEmpty && sorted.first.at.isBefore(start)) start = GrowthDays.dateOnly(sorted.first.at);
    if (start.isAfter(day)) start = day;

    final logged = sorted.fold<double>(0, (s, e) => s + e.amount);
    final current = initial + logged;
    final reached = target <= 0 || current >= target - eps;

    DateTime? completedOn;
    if (reached) {
      if (initial >= target - eps) {
        completedOn = start;
      } else {
        var run = initial;
        for (final e in sorted) {
          run += e.amount;
          if (run >= target - eps) {
            completedOn = GrowthDays.dateOnly(e.at);
            break;
          }
        }
        completedOn ??= day;
      }
    }

    final elapsed = GrowthDays.between(start, day) + 1;
    final span = math.max(1, math.min(window, elapsed));
    final windowStart = GrowthDays.add(day, -(span - 1));
    var recent = 0.0;
    for (final e in sorted) {
      final d = GrowthDays.dateOnly(e.at);
      if (!d.isBefore(windowStart) && !d.isAfter(day)) recent += e.amount;
    }
    final actualPerDay = math.max(0.0, recent / span);
    final remaining = math.max(0.0, target - current);

    int? daysLeft;
    double? needed;
    double? expected;
    final dl = deadline == null ? null : GrowthDays.dateOnly(deadline);
    if (dl != null) {
      daysLeft = math.max(0, GrowthDays.between(day, dl) + 1);
      if (!reached && daysLeft > 0) needed = remaining / daysLeft;
      final planDays = GrowthDays.between(start, dl) + 1;
      final share = planDays <= 0 ? 1.0 : ((elapsed - 1) / planDays).clamp(0.0, 1.0);
      expected = initial + (target - initial) * share;
    }

    DateTime? projected;
    if (!reached && actualPerDay > eps) {
      final k = math.max(1, (remaining / actualPerDay - eps).ceil());
      if (k <= horizonDays) projected = GrowthDays.add(day, k - 1);
    }

    final GoalPace pace;
    if (reached) {
      pace = GoalPace.completed;
    } else if (!active) {
      pace = GoalPace.paused;
    } else if (daysLeft == 0) {
      pace = GoalPace.overdue;
    } else if (sorted.isEmpty) {
      pace = GoalPace.notStarted;
    } else if (needed == null) {
      pace = GoalPace.noDeadline;
    } else {
      final ratio = actualPerDay / needed;
      pace = ratio >= aheadRatio
          ? GoalPace.ahead
          : ratio >= 1 - eps
          ? GoalPace.onTrack
          : GoalPace.behind;
    }

    return GoalStats(
      initial: initial,
      target: target,
      logged: logged,
      start: start,
      today: day,
      deadline: dl,
      active: active,
      logCount: sorted.length,
      elapsedDays: elapsed,
      daysLeft: daysLeft,
      paceWindow: span,
      actualPerDay: actualPerDay,
      neededPerDay: needed,
      expectedNow: expected,
      projectedFinish: projected,
      completedOn: completedOn,
      pace: pace,
    );
  }

  /// Whether adding [added] to [before] reaches a [target] not yet reached
  /// (the moment to celebrate).
  static bool crossesTarget({required double before, required double added, required double target}) =>
      target > 0 && before < target - eps && before + added >= target - eps;
}
