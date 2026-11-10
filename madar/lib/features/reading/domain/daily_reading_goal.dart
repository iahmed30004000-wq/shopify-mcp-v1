/// The daily reading goal and its streak (Part 17).
///
/// The goal is counted in pages or in minutes, his choice. A streak is the
/// number of days in a row on which the goal was met. Today does not break it
/// while the day is still open; a skipped day does.
library;

import 'package:meta/meta.dart';

import '../../wird/domain/calendar_days.dart';
import 'reading_session.dart';

enum GoalUnit { pages, minutes }

@immutable
final class DailyReadingGoal {
  const DailyReadingGoal({required this.unit, required this.target, required this.effectiveFrom})
    : assert(target > 0);

  final GoalUnit unit;
  final int target;

  /// The moment he set it; the goal applies from here on.
  final DateTime effectiveFrom;

  bool isMetBy(DailyTotals t) => (unit == GoalUnit.pages ? t.pages : t.minutes) >= target;

  /// 0..1 progress for the day's ring.
  double fractionOf(DailyTotals t) {
    final v = unit == GoalUnit.pages ? t.pages : t.minutes;
    return (v / target).clamp(0.0, 1.0);
  }

  Map<String, Object?> toJson() => {'unit': unit.name, 'target': target, 'effectiveFrom': effectiveFrom.toIso8601String()};

  factory DailyReadingGoal.fromJson(Map<String, Object?> json) => DailyReadingGoal(
    unit: GoalUnit.values.byName(json['unit'] as String),
    target: (json['target'] as num).toInt(),
    effectiveFrom: DateTime.parse(json['effectiveFrom'] as String),
  );

  @override
  bool operator ==(Object other) =>
      other is DailyReadingGoal && other.unit == unit && other.target == target && other.effectiveFrom == effectiveFrom;

  @override
  int get hashCode => Object.hash(unit, target, effectiveFrom);
}

@immutable
final class ReadingStreak {
  const ReadingStreak({required this.current, required this.longest, required this.todayMet});

  /// Days in a row ending today (if today is met) or yesterday.
  final int current;
  final int longest;
  final bool todayMet;
}

final class ReadingGoalCalculator {
  ReadingGoalCalculator({required this.clock});

  /// Injected so midnight and skipped days are testable.
  final DateTime Function() clock;

  /// The goals that were in force at some moment of [day]: the one carried in
  /// from before midnight, and every one set during the day.
  List<DailyReadingGoal> goalsDuring(List<DailyReadingGoal> history, DateTime day) {
    final start = CalendarDays.dateOnly(day);
    final next = CalendarDays.add(start, 1);
    DailyReadingGoal? carried;
    final within = <DailyReadingGoal>[];
    for (final g in history) {
      if (g.effectiveFrom.isBefore(start)) {
        if (carried == null || g.effectiveFrom.isAfter(carried.effectiveFrom)) carried = g;
      } else if (g.effectiveFrom.isBefore(next)) {
        within.add(g);
      }
    }
    within.sort((a, b) => a.effectiveFrom.compareTo(b.effectiveFrom));
    return [?carried, ...within];
  }

  /// Is [day] a day on which the goal was met? When he changed the goal in
  /// the middle of the day, meeting ANY goal that was in force that day
  /// counts: raising the target at noon must not erase what he already read.
  /// A day with no goal in force is never met.
  bool dayMet(List<DailyReadingGoal> history, Map<String, DailyTotals> totals, DateTime day) {
    final t = totals[CalendarDays.key(day)] ?? DailyTotals.zero;
    return goalsDuring(history, day).any((g) => g.isMetBy(t));
  }

  ReadingStreak streak({required List<DailyReadingGoal> history, required Map<String, DailyTotals> totals}) {
    if (history.isEmpty) return const ReadingStreak(current: 0, longest: 0, todayMet: false);
    final today = CalendarDays.dateOnly(clock());
    final firstDay = CalendarDays.dateOnly(history.map((g) => g.effectiveFrom).reduce((a, b) => a.isBefore(b) ? a : b));

    var longest = 0;
    var run = 0;
    for (var d = firstDay; !d.isAfter(today); d = CalendarDays.add(d, 1)) {
      if (dayMet(history, totals, d)) {
        run++;
        if (run > longest) longest = run;
      } else {
        run = 0;
      }
    }
    final todayMet = dayMet(history, totals, today);
    // If today is still open, the streak is judged up to yesterday.
    var cursor = todayMet ? today : CalendarDays.add(today, -1);
    var current = 0;
    while (!cursor.isBefore(firstDay) && dayMet(history, totals, cursor)) {
      current++;
      cursor = CalendarDays.add(cursor, -1);
    }
    return ReadingStreak(current: current, longest: longest, todayMet: todayMet);
  }

  /// Today's progress towards the goal now in force (the latest one), 0..1.
  double todayFraction({required List<DailyReadingGoal> history, required Map<String, DailyTotals> totals}) {
    final goals = goalsDuring(history, clock());
    if (goals.isEmpty) return 0;
    final t = totals[CalendarDays.key(clock())] ?? DailyTotals.zero;
    return goals.last.fractionOf(t);
  }
}
