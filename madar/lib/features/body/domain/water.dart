import 'package:flutter/foundation.dart';

import 'body_clock.dart';

/// One glass (a plain copy of a `water_logs` row).
@immutable
class WaterEntry {
  const WaterEntry({required this.id, required this.at, required this.ml});

  final String id;
  final DateTime at;
  final int ml;
}

/// Water arithmetic: totals per local calendar day and the daily target.
abstract final class WaterMath {
  /// Key/value key of the daily target in ml (a JSON number); the orbit's
  /// Body planet reads it too.
  static const String targetKey = 'body.waterTargetMl';
  static const int defaultTarget = 2500;
  static const int minTarget = 250;
  static const int maxTarget = 10000;

  /// One-tap amounts.
  static const List<int> quick = [250, 500];
  static const int minAmount = 10;
  static const int maxAmount = 3000;

  /// A stored target, or the default when missing / invalid.
  static int targetOf(Object? stored) {
    if (stored is num && stored >= minTarget && stored <= maxTarget) return stored.round();
    return defaultTarget;
  }

  /// Total ml per local day (`BodyDays.key`).
  static Map<String, int> totalsByDay(Iterable<WaterEntry> entries, {BodyWallClock clock = const LocalBodyWallClock()}) {
    final out = <String, int>{};
    for (final e in entries) {
      final k = BodyDays.key(clock.dayOf(e.at));
      out[k] = (out[k] ?? 0) + e.ml;
    }
    return out;
  }

  /// Total ml on the local calendar [day].
  static int totalOn(Iterable<WaterEntry> entries, DateTime day, {BodyWallClock clock = const LocalBodyWallClock()}) {
    var sum = 0;
    for (final e in entries) {
      if (BodyDays.same(clock.dayOf(e.at), day)) sum += e.ml;
    }
    return sum;
  }

  /// The [days] days ending on [today], oldest first, with their totals
  /// (0 for days without water).
  static List<({DateTime day, int ml})> lastDays(
    Iterable<WaterEntry> entries,
    DateTime today, {
    int days = 7,
    BodyWallClock clock = const LocalBodyWallClock(),
  }) {
    final totals = totalsByDay(entries, clock: clock);
    final t = BodyDays.of(today);
    return [
      for (var i = days - 1; i >= 0; i--)
        (day: BodyDays.add(t, -i), ml: totals[BodyDays.key(BodyDays.add(t, -i))] ?? 0),
    ];
  }

  /// Consecutive days meeting [target] ending today (or yesterday while
  /// today is not met yet).
  static int streak(
    Iterable<WaterEntry> entries,
    DateTime today,
    int target, {
    BodyWallClock clock = const LocalBodyWallClock(),
  }) {
    if (target <= 0) return 0;
    final totals = totalsByDay(entries, clock: clock);
    bool met(DateTime d) => (totals[BodyDays.key(d)] ?? 0) >= target;
    final t = BodyDays.of(today);
    var day = met(t) ? t : BodyDays.add(t, -1);
    var n = 0;
    while (met(day)) {
      n++;
      day = BodyDays.add(day, -1);
    }
    return n;
  }

  /// 0‥1 (capped) share of [target].
  static double progress(int total, int target) => target <= 0 ? 0 : (total / target).clamp(0.0, 1.0);
}
