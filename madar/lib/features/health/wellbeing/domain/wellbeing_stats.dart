import 'package:flutter/foundation.dart';

import 'body_map.dart';
import 'wellbeing_data.dart';

/// One day of the pain chart.
@immutable
class DailyPain {
  const DailyPain({required this.day, required this.max, required this.mean, required this.count});

  final DateTime day;

  /// Highest score logged that day.
  final int max;

  /// Mean of the day's scores.
  final double mean;

  /// Logs that day.
  final int count;
}

/// Everything the pain tab charts for one range.
@immutable
class PainSummary {
  const PainSummary({
    required this.from,
    required this.to,
    required this.days,
    required this.triggers,
    required this.locations,
    required this.heat,
    required this.entries,
  });

  final DateTime from;
  final DateTime to;

  /// Days with at least one log, oldest first.
  final List<DailyPain> days;

  /// Trigger → logs mentioning it, most frequent first.
  final List<(String, int)> triggers;

  /// Location → logs mentioning it, most frequent first.
  final List<(String, int)> locations;

  /// Body-map points merged into hot spots.
  final List<HeatSpot> heat;

  /// Logs in the range.
  final int entries;

  bool get isEmpty => entries == 0;

  /// Mean of the daily highest scores (null without data).
  double? get meanOfDailyMax => days.isEmpty ? null : days.fold<double>(0, (s, d) => s + d.max) / days.length;

  /// Highest score in the range.
  int? get peak => days.isEmpty ? null : days.map((d) => d.max).reduce((a, b) => a > b ? a : b);

  /// Share of the range's days with a log (0–1).
  double coverage(int rangeDays) => rangeDays <= 0 ? 0 : days.length / rangeDays;
}

abstract final class WellbeingStats {
  /// Pain over the [days] calendar days ending with [today].
  static PainSummary pain(Iterable<PainSample> samples, {required DateTime today, required int days}) {
    final to = WbDays.dateOf(today);
    final from = WbDays.add(to, -(days - 1));
    final byDay = <DateTime, List<int>>{};
    final triggers = <String, int>{};
    final locations = <String, int>{};
    final points = <(BodyPoint, int)>[];
    var entries = 0;
    for (final s in samples) {
      final d = WbDays.dateOf(s.at);
      if (d.isBefore(from) || d.isAfter(to)) continue;
      entries++;
      (byDay[d] ??= []).add(s.score);
      for (final t in s.triggers.toSet()) {
        triggers[t] = (triggers[t] ?? 0) + 1;
      }
      for (final l in s.locations.toSet()) {
        locations[l] = (locations[l] ?? 0) + 1;
      }
      for (final p in s.points) {
        points.add((p, s.score));
      }
    }
    final keys = byDay.keys.toList()..sort();
    return PainSummary(
      from: from,
      to: to,
      days: [
        for (final d in keys)
          DailyPain(
            day: d,
            max: byDay[d]!.reduce((a, b) => a > b ? a : b),
            mean: byDay[d]!.fold<int>(0, (a, b) => a + b) / byDay[d]!.length,
            count: byDay[d]!.length,
          ),
      ],
      triggers: _ranked(triggers),
      locations: _ranked(locations),
      heat: BodyHeat.cluster(points),
      entries: entries,
    );
  }

  /// One value per logged day for [metric] over the [days] days ending
  /// [today], oldest first (see [DayRecord.build] for how a day's check-ins
  /// combine).
  static List<MetricPoint> series(
    Iterable<MoodSample> moods,
    WellMetric metric, {
    required DateTime today,
    required int days,
    Iterable<PainSample> pains = const [],
  }) {
    final to = WbDays.dateOf(today);
    final records = DayRecord.build(moods: moods, pains: pains, from: WbDays.add(to, -(days - 1)), to: to);
    return [
      for (final r in records)
        if (r[metric] case final v?) MetricPoint(r.day, v),
    ];
  }

  /// Mean of a series (null when empty).
  static double? mean(List<MetricPoint> s) => s.isEmpty ? null : s.fold<double>(0, (a, p) => a + p.value) / s.length;

  /// Factor tag → check-ins mentioning it, most frequent first.
  static List<(String, int)> factorCounts(Iterable<MoodSample> moods, {required DateTime today, required int days}) {
    final to = WbDays.dateOf(today);
    final from = WbDays.add(to, -(days - 1));
    final counts = <String, int>{};
    for (final m in moods) {
      final d = WbDays.dateOf(m.at);
      if (d.isBefore(from) || d.isAfter(to)) continue;
      for (final f in m.factors.toSet()) {
        counts[f] = (counts[f] ?? 0) + 1;
      }
    }
    return _ranked(counts);
  }

  static List<(String, int)> _ranked(Map<String, int> counts) {
    final list = [for (final e in counts.entries) (e.key, e.value)];
    list.sort((a, b) {
      final c = b.$2.compareTo(a.$2);
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
    return list;
  }
}
