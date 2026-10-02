import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'growth_days.dart';

/// Days with any progress logged, as streaks.
@immutable
class GrowthStreak {
  const GrowthStreak({
    required this.current,
    required this.best,
    required this.loggedToday,
    required this.days,
    required this.today,
  });

  static final GrowthStreak empty = GrowthStreak(
    current: 0,
    best: 0,
    loggedToday: false,
    days: const {},
    today: DateTime(2000),
  );

  /// Consecutive days up to today – or up to yesterday while today has no
  /// log yet (the streak is still alive until the day ends).
  final int current;

  /// The longest run ever.
  final int best;
  final bool loggedToday;

  /// Every day with a log ([GrowthDays.key]), up to today.
  final Set<int> days;
  final DateTime today;

  /// Whether the streak lives on only if something is logged today.
  bool get atRisk => current > 0 && !loggedToday;

  bool hasLog(DateTime day) => days.contains(GrowthDays.key(day));

  /// The last [n] days, oldest first: whether each had a log.
  List<bool> lastDays(int n) => [for (var i = n - 1; i >= 0; i--) hasLog(GrowthDays.add(today, -i))];

  /// How many of the last [n] days had a log.
  int activeDaysInLast(int n) => lastDays(n).where((d) => d).length;
}

abstract final class GrowthStreaks {
  /// Streaks of the days in [ats] (log times) as of [today]. Logs dated after
  /// today are ignored.
  static GrowthStreak of(Iterable<DateTime> ats, {required DateTime today}) {
    final day = GrowthDays.dateOnly(today);
    final todayKey = GrowthDays.key(day);
    final keys = <int>{};
    final dates = <DateTime>[];
    for (final at in ats) {
      final d = GrowthDays.dateOnly(at);
      final k = GrowthDays.key(d);
      if (k > todayKey) continue;
      if (keys.add(k)) dates.add(d);
    }
    if (dates.isEmpty) {
      return GrowthStreak(current: 0, best: 0, loggedToday: false, days: const {}, today: day);
    }
    dates.sort();
    var best = 1, run = 1;
    for (var i = 1; i < dates.length; i++) {
      run = GrowthDays.between(dates[i - 1], dates[i]) == 1 ? run + 1 : 1;
      best = math.max(best, run);
    }
    final loggedToday = keys.contains(todayKey);
    var cursor = loggedToday ? day : GrowthDays.add(day, -1);
    var current = 0;
    while (keys.contains(GrowthDays.key(cursor))) {
      current++;
      cursor = GrowthDays.add(cursor, -1);
    }
    return GrowthStreak(current: current, best: best, loggedToday: loggedToday, days: keys, today: day);
  }
}
