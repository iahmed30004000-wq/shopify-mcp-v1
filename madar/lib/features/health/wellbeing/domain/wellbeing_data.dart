import 'package:flutter/foundation.dart';

import 'body_map.dart';

/// Calendar-day helpers (local dates; `yyyy-MM-dd` keys as in `habit_logs`).
abstract final class WbDays {
  static DateTime dateOf(DateTime t) => DateTime(t.year, t.month, t.day);

  static String key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime? parse(String key) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(key);
    if (m == null) return null;
    return DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  }

  /// [d] shifted by whole calendar days (DST-safe).
  static DateTime add(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);

  /// Whole calendar days from [a] to [b].
  static int between(DateTime a, DateTime b) =>
      DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

  /// The [days] calendar days ending with [today], oldest first.
  static List<DateTime> window(DateTime today, int days) => [
    for (var i = days - 1; i >= 0; i--) add(dateOf(today), -i),
  ];
}

/// Every number the wellbeing screens chart or correlate.
enum WellMetric {
  /// 1–5 (faces).
  mood,

  /// 0–10.
  stress,

  /// 0–10.
  anxiety,

  /// 0–10.
  energy,

  /// Hours.
  sleep,

  /// Cups.
  caffeine,

  /// 0–10 (the day's highest logged pain).
  pain;

  /// The scale's bounds for charts (sleep and caffeine are open-ended; these
  /// are the chart's default maxima).
  double get min => this == WellMetric.mood ? 1 : 0;
  double get max => switch (this) {
    WellMetric.mood => 5,
    WellMetric.sleep => 12,
    WellMetric.caffeine => 6,
    _ => 10,
  };

  /// Smallest difference in means worth mentioning.
  double get meaningfulDiff => switch (this) {
    WellMetric.mood => 0.5,
    WellMetric.sleep || WellMetric.caffeine => 0.5,
    _ => 1.0,
  };

  bool get isHours => this == WellMetric.sleep;
}

/// A mood & stress check-in (a `mood_entries` row without the database).
@immutable
class MoodSample {
  const MoodSample({
    required this.at,
    this.mood,
    this.stress,
    this.anxiety,
    this.energy,
    this.sleepHours,
    this.caffeineCups,
    this.factors = const [],
  });

  final DateTime at;
  final int? mood;
  final int? stress;
  final int? anxiety;
  final int? energy;
  final double? sleepHours;
  final int? caffeineCups;
  final List<String> factors;

  double? value(WellMetric m) => switch (m) {
    WellMetric.mood => mood?.toDouble(),
    WellMetric.stress => stress?.toDouble(),
    WellMetric.anxiety => anxiety?.toDouble(),
    WellMetric.energy => energy?.toDouble(),
    WellMetric.sleep => sleepHours,
    WellMetric.caffeine => caffeineCups?.toDouble(),
    WellMetric.pain => null,
  };
}

/// A pain log (a `pain_entries` row without the database).
@immutable
class PainSample {
  const PainSample({
    required this.at,
    required this.score,
    this.locations = const [],
    this.triggers = const [],
    this.points = const [],
  });

  final DateTime at;
  final int score;
  final List<String> locations;
  final List<String> triggers;
  final List<BodyPoint> points;
}

/// One day's value of a metric.
@immutable
class MetricPoint {
  const MetricPoint(this.day, this.value);

  final DateTime day;
  final double value;

  @override
  bool operator ==(Object other) => other is MetricPoint && other.day == day && other.value == value;

  @override
  int get hashCode => Object.hash(day, value);

  @override
  String toString() => 'MetricPoint(${WbDays.key(day)}, $value)';
}

/// Everything logged on one calendar day, reduced to one number per metric:
/// the mean of the day's check-ins for mood, stress, anxiety and energy; the
/// largest entry for sleep and caffeine (a later check-in updates the day's
/// running total); the highest pain score of the day.
@immutable
class DayRecord {
  const DayRecord(this.day, this.values);

  final DateTime day;
  final Map<WellMetric, double> values;

  double? operator [](WellMetric m) => values[m];

  /// Folds check-ins and pain logs into one record per day between [from]
  /// and [to] (inclusive), oldest first. Days with nothing logged are left
  /// out.
  static List<DayRecord> build({
    required Iterable<MoodSample> moods,
    required Iterable<PainSample> pains,
    required DateTime from,
    required DateTime to,
  }) {
    final first = WbDays.dateOf(from);
    final last = WbDays.dateOf(to);
    bool inRange(DateTime d) => !d.isBefore(first) && !d.isAfter(last);
    final sums = <DateTime, Map<WellMetric, (double, int)>>{};
    final maxes = <DateTime, Map<WellMetric, double>>{};
    void mean(DateTime d, WellMetric m, double? v) {
      if (v == null || !v.isFinite) return;
      final day = sums.putIfAbsent(d, () => {});
      final (s, n) = day[m] ?? (0.0, 0);
      day[m] = (s + v, n + 1);
    }

    void max(DateTime d, WellMetric m, double? v) {
      if (v == null || !v.isFinite) return;
      final day = maxes.putIfAbsent(d, () => {});
      final prev = day[m];
      if (prev == null || v > prev) day[m] = v;
    }

    for (final s in moods) {
      final d = WbDays.dateOf(s.at);
      if (!inRange(d)) continue;
      for (final m in const [WellMetric.mood, WellMetric.stress, WellMetric.anxiety, WellMetric.energy]) {
        mean(d, m, s.value(m));
      }
      max(d, WellMetric.sleep, s.sleepHours);
      max(d, WellMetric.caffeine, s.caffeineCups?.toDouble());
    }
    for (final p in pains) {
      final d = WbDays.dateOf(p.at);
      if (!inRange(d)) continue;
      max(d, WellMetric.pain, p.score.toDouble());
    }
    final days = {...sums.keys, ...maxes.keys}.toList()..sort();
    return [
      for (final d in days)
        DayRecord(d, {
          for (final e in (sums[d] ?? const <WellMetric, (double, int)>{}).entries) e.key: e.value.$1 / e.value.$2,
          ...?maxes[d],
        }),
    ];
  }
}
