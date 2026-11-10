import 'package:flutter/foundation.dart';

import 'wellbeing_data.dart';

/// A habit's standing on a given day.
@immutable
class HabitProgress {
  const HabitProgress({
    required this.doneToday,
    required this.streak,
    required this.best,
    required this.last7,
    required this.doneIn30,
  });

  static const empty = HabitProgress(
    doneToday: false,
    streak: 0,
    best: 0,
    last7: [false, false, false, false, false, false, false],
    doneIn30: 0,
  );

  final bool doneToday;

  /// Consecutive done days ending today – or yesterday while today is still
  /// open (a streak is not broken before the day is over).
  final int streak;

  /// Longest run ever recorded.
  final int best;

  /// The last seven days, oldest first (today last).
  final List<bool> last7;

  /// Done days among the last 30 (today included).
  final int doneIn30;
}

abstract final class HabitStreaks {
  /// Progress from the `yyyy-MM-dd` keys of the days the habit was done.
  static HabitProgress of(Set<String> doneDays, {required DateTime today}) {
    final t = WbDays.dateOf(today);
    bool done(DateTime d) => doneDays.contains(WbDays.key(d));
    final doneToday = done(t);
    var streak = 0;
    var d = doneToday ? t : WbDays.add(t, -1);
    while (done(d)) {
      streak++;
      d = WbDays.add(d, -1);
    }
    final parsed = [
      for (final k in doneDays)
        if (WbDays.parse(k) case final day? when !day.isAfter(t)) day,
    ]..sort();
    var best = 0, run = 0;
    DateTime? prev;
    for (final day in parsed) {
      run = (prev != null && WbDays.between(prev, day) == 1) ? run + 1 : 1;
      if (run > best) best = run;
      prev = day;
    }
    var in30 = 0;
    for (var i = 0; i < 30; i++) {
      if (done(WbDays.add(t, -i))) in30++;
    }
    return HabitProgress(
      doneToday: doneToday,
      streak: streak,
      best: best,
      last7: [for (var i = 6; i >= 0; i--) done(WbDays.add(t, -i))],
      doneIn30: in30,
    );
  }
}
