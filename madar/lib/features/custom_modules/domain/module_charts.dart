/// Chart data for a module: daily values over 7 / 30 / 90 days, the heat
/// calendar grid and streaks. Pure Dart.
library;

import '../../../core/domain/enums.dart';
import 'field_values.dart';
import 'module_schema.dart';

/// How a day's entries combine into one value.
enum ChartAggregate {
  /// Number of entries (no field chosen).
  count,

  /// Sum of numbers / amounts ("pages read today").
  sum,

  /// Mean of ratings.
  average,

  /// A check-in: 1 when any entry that day is ticked.
  any,
}

/// One calendar day of a chart.
class ChartDay {
  const ChartDay({required this.day, required this.value, required this.entries});

  /// Local midnight.
  final DateTime day;

  /// The day's value; null when nothing was logged.
  final double? value;

  /// Entries logged that day.
  final int entries;

  /// Counts toward a streak.
  bool get active => (value ?? 0) > 0;
}

class ModuleChartData {
  const ModuleChartData({
    required this.config,
    required this.field,
    required this.aggregate,
    required this.days,
    required this.currentStreak,
    required this.bestStreak,
    required this.totalEntries,
  });

  final ModuleChartConfig config;

  /// The plotted field (null = entries per day).
  final ModuleField? field;
  final ChartAggregate aggregate;

  /// [ModuleChartConfig.range] days, oldest first, ending today.
  final List<ChartDay> days;

  /// Consecutive active days up to today (today may still be open: a streak
  /// that ended yesterday is still current).
  final int currentStreak;

  /// Longest run of active days ever.
  final int bestStreak;

  /// Entries in the whole history.
  final int totalEntries;

  int get daysWithData => days.where((d) => d.value != null).length;
  int get activeDays => days.where((d) => d.active).length;
  bool get isEmpty => daysWithData == 0;

  double get maxValue => days.fold<double>(0, (m, d) => (d.value ?? 0) > m ? d.value! : m);
  double get minValue {
    final vs = [
      for (final d in days)
        if (d.value != null) d.value!,
    ];
    if (vs.isEmpty) return 0;
    return vs.reduce((a, b) => a < b ? a : b);
  }

  /// Sum of the daily values in range.
  double get total => days.fold<double>(0, (s, d) => s + (d.value ?? 0));

  /// Mean of the days that have data (null when none).
  double? get average => daysWithData == 0 ? null : total / daysWithData;

  /// 0…1 shade of a day for the heat calendar.
  double intensity(ChartDay d) {
    final max = aggregate == ChartAggregate.average ? (field?.ratingMax.toDouble() ?? maxValue) : maxValue;
    if (d.value == null || max <= 0) return 0;
    return (d.value! / max).clamp(0.0, 1.0);
  }

  /// Share of days in range that are active (check-in rate).
  double get activeRate => days.isEmpty ? 0 : activeDays / days.length;
}

abstract final class ModuleCharts {
  static ChartAggregate aggregateFor(ModuleField? f) => switch (f?.type) {
    null => ChartAggregate.count,
    FieldType.rating => ChartAggregate.average,
    FieldType.checkbox => ChartAggregate.any,
    _ => ChartAggregate.sum,
  };

  static DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

  /// Daily values of [module]'s chart ([config] overrides the stored one)
  /// for the [ModuleChartConfig.range] days ending on [today].
  static ModuleChartData build({
    required ModuleDefinition module,
    required List<ModuleEntry> entries,
    required DateTime today,
    ModuleChartConfig? config,
  }) {
    var c = config ?? module.effectiveChart;
    final field = module.field(c.fieldId);
    if (c.fieldId != null && (field == null || !field.isChartable)) c = c.copyWith(clearField: true);
    final agg = aggregateFor(c.fieldId == null ? null : field);

    // Bucket every entry by calendar day.
    final buckets = <DateTime, List<double>>{};
    final counts = <DateTime, int>{};
    for (final e in entries) {
      final d = dayOf(e.at);
      counts[d] = (counts[d] ?? 0) + 1;
      if (agg == ChartAggregate.count) continue;
      final v = FieldValues.numeric(field!, e.values[field.id]);
      if (v != null) (buckets[d] ??= []).add(v);
    }

    double? valueOf(DateTime d) {
      if (agg == ChartAggregate.count) {
        return counts[d]?.toDouble();
      }
      final vs = buckets[d];
      if (vs == null || vs.isEmpty) return null;
      return switch (agg) {
        ChartAggregate.sum => vs.fold<double>(0, (s, v) => s + v),
        ChartAggregate.average => vs.fold<double>(0, (s, v) => s + v) / vs.length,
        ChartAggregate.any => vs.any((v) => v > 0) ? 1 : 0,
        ChartAggregate.count => vs.length.toDouble(),
      };
    }

    final end = dayOf(today);
    final days = [
      for (var i = c.range - 1; i >= 0; i--)
        () {
          final d = DateTime(end.year, end.month, end.day - i);
          return ChartDay(day: d, value: valueOf(d), entries: counts[d] ?? 0);
        }(),
    ];

    // Streaks over the whole history.
    final activeDays = <DateTime>{
      for (final d in {...counts.keys, ...buckets.keys})
        if ((valueOf(d) ?? 0) > 0) d,
    };
    final (current, best) = streaks(activeDays, end);
    return ModuleChartData(
      config: c,
      field: c.fieldId == null ? null : field,
      aggregate: agg,
      days: days,
      currentStreak: current,
      bestStreak: best,
      totalEntries: entries.length,
    );
  }

  /// (current, best) runs of consecutive [active] days. The current run
  /// ends today, or yesterday when today has nothing yet.
  static (int, int) streaks(Set<DateTime> active, DateTime today) {
    if (active.isEmpty) return (0, 0);
    final days = active.map(dayOf).toSet().toList()..sort();
    var best = 1, run = 1;
    for (var i = 1; i < days.length; i++) {
      final prev = days[i - 1];
      final expected = DateTime(prev.year, prev.month, prev.day + 1);
      run = days[i] == expected ? run + 1 : 1;
      if (run > best) best = run;
    }
    final t = dayOf(today);
    var cursor = active.contains(t) ? t : DateTime(t.year, t.month, t.day - 1);
    var current = 0;
    final set = days.toSet();
    while (set.contains(cursor)) {
      current++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    return (current, best);
  }

  /// The heat calendar: columns of 7 days (weeks starting on
  /// [firstWeekday]), padded with nulls before the first and after the last
  /// day.
  static List<List<ChartDay?>> heatWeeks(List<ChartDay> days, {int firstWeekday = DateTime.saturday}) {
    if (days.isEmpty) return const [];
    final lead = (days.first.day.weekday - firstWeekday + 7) % 7;
    final cells = <ChartDay?>[for (var i = 0; i < lead; i++) null, ...days];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return [for (var i = 0; i < cells.length; i += 7) cells.sublist(i, i + 7)];
  }

  /// Weekday numbers ([DateTime.monday]…) in row order of [heatWeeks].
  static List<int> weekdayOrder({int firstWeekday = DateTime.saturday}) => [
    for (var i = 0; i < 7; i++) (firstWeekday - 1 + i) % 7 + 1,
  ];

  /// A compact "last 7 days" series for tiles and cards (0 for empty days).
  static List<double> sparkline(ModuleChartData data, {int last = 7}) {
    final from = data.days.length > last ? data.days.length - last : 0;
    return [for (final d in data.days.sublist(from)) d.value ?? 0];
  }
}
