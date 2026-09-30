import 'package:flutter/foundation.dart';

import '../../../core/db/database.dart';
import 'goal_math.dart';
import 'growth_days.dart';
import 'growth_streaks.dart';
import 'growth_units.dart';

/// A learning goal with its logs and where it stands today.
@immutable
class GrowthGoal {
  GrowthGoal({required this.row, required this.logs, required this.stats, required this.streak})
    : unit = GrowthUnit.parse(row.unit);

  /// Builds the goal from its row and its logs (any order).
  factory GrowthGoal.of(LearningGoalRow row, Iterable<GoalLogRow> logs, {required DateTime today}) {
    final sorted = logs.toList()..sort(compareLogsNewestFirst);
    final stats = GoalMath.compute(
      initial: row.initial,
      target: row.target,
      entries: [for (final l in sorted) GoalEntry(amount: l.amount, at: l.at)],
      created: row.createdAt,
      deadline: row.deadline,
      active: row.active,
      today: today,
    );
    return GrowthGoal(
      row: row,
      logs: sorted,
      stats: stats,
      streak: GrowthStreaks.of(sorted.map((l) => l.at), today: today),
    );
  }

  final LearningGoalRow row;
  final GrowthUnit unit;

  /// Newest first.
  final List<GoalLogRow> logs;
  final GoalStats stats;
  final GrowthStreak streak;

  String get id => row.id;
  String get name => row.name;
  int? get color => row.color;
  GoalStatus get status => stats.status;

  /// The one-tap chips of the log sheet and the goal page.
  List<double> get quickAmounts => unit.quickAmounts(row.target);

  /// What a one-tap log adds: the amount entered last, else the first chip.
  double get usualAmount {
    GoalLogRow? last;
    for (final l in logs) {
      if (last == null || l.createdAt.isAfter(last.createdAt)) last = l;
    }
    if (last != null && last.amount > 0) return last.amount;
    return quickAmounts.first;
  }

  /// Amount logged on [day].
  double loggedOn(DateTime day) =>
      logs.where((l) => GrowthDays.sameDay(l.at, day)).fold<double>(0, (s, l) => s + l.amount);

  /// The running total right after each log (by log id).
  Map<String, double> runningTotals() {
    final chrono = logs.reversed.toList();
    var run = row.initial;
    return {for (final l in chrono) l.id: run += l.amount};
  }

  static int compareLogsNewestFirst(GoalLogRow a, GoalLogRow b) {
    final c = b.at.compareTo(a.at);
    return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
  }
}

/// All goals together: sections, the shared streak and what needs attention.
@immutable
class GrowthOverview {
  const GrowthOverview({required this.goals, required this.streak, required this.today});

  static GrowthOverview of(List<LearningGoalRow> rows, List<GoalLogRow> logs, {required DateTime today}) {
    final byGoal = <String, List<GoalLogRow>>{};
    for (final l in logs) {
      (byGoal[l.goalId] ??= []).add(l);
    }
    final ids = {for (final r in rows) r.id};
    return GrowthOverview(
      goals: [for (final r in rows) GrowthGoal.of(r, byGoal[r.id] ?? const [], today: today)],
      streak: GrowthStreaks.of([
        for (final l in logs)
          if (ids.contains(l.goalId)) l.at,
      ], today: today),
      today: GrowthDays.dateOnly(today),
    );
  }

  /// Every goal in the user's order.
  final List<GrowthGoal> goals;

  /// Days with any log on any goal.
  final GrowthStreak streak;
  final DateTime today;

  bool get isEmpty => goals.isEmpty;

  List<GrowthGoal> get active => [
    for (final g in goals)
      if (g.status == GoalStatus.active) g,
  ];

  List<GrowthGoal> get completed => [
    for (final g in goals)
      if (g.status == GoalStatus.completed) g,
  ];

  List<GrowthGoal> get paused => [
    for (final g in goals)
      if (g.status == GoalStatus.paused) g,
  ];

  GrowthGoal? byId(String id) {
    for (final g in goals) {
      if (g.id == id) return g;
    }
    return null;
  }

  /// Mean progress of the goals not paused by the user (as the orbit's
  /// Growth planet counts it); null when there are none.
  double? get averageProgress {
    final counted = [
      for (final g in goals)
        if (g.row.active && g.row.target > 0) g.stats.progress,
    ];
    if (counted.isEmpty) return null;
    return counted.reduce((a, b) => a + b) / counted.length;
  }

  /// Goals with something logged today.
  int get loggedTodayCount => goals.where((g) => g.streak.loggedToday).length;

  /// Active goals, most urgent first (overdue, behind, not started, on
  /// track, open-ended, ahead); the user's order breaks ties.
  List<GrowthGoal> focus({int? limit}) {
    final list = active.indexed.toList()
      ..sort((a, b) {
        final c = urgency(a.$2.stats.pace).compareTo(urgency(b.$2.stats.pace));
        return c != 0 ? c : a.$1.compareTo(b.$1);
      });
    final ordered = [for (final e in list) e.$2];
    return limit == null || ordered.length <= limit ? ordered : ordered.sublist(0, limit);
  }

  static int urgency(GoalPace pace) => switch (pace) {
    GoalPace.overdue => 0,
    GoalPace.behind => 1,
    GoalPace.notStarted => 2,
    GoalPace.onTrack => 3,
    GoalPace.noDeadline => 4,
    GoalPace.ahead => 5,
    GoalPace.paused => 6,
    GoalPace.completed => 7,
  };
}
