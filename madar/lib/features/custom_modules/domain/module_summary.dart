/// What a module tile or planet card shows at a glance. Pure Dart.
library;

import '../../../core/domain/enums.dart';
import 'field_values.dart';
import 'module_charts.dart';
import 'module_schema.dart';

class ModuleSummary {
  const ModuleSummary({
    required this.module,
    required this.entryCount,
    required this.todayCount,
    required this.lastEntry,
    required this.openCount,
    required this.doneCount,
    required this.checkedToday,
    required this.todayRating,
    required this.chart,
    required this.sparkline,
  });

  final ModuleDefinition module;
  final int entryCount;

  /// Entries logged today (trackers).
  final int todayCount;
  final DateTime? lastEntry;

  /// List items still open / checked off.
  final int openCount;
  final int doneCount;

  /// A one-tap check-in module already ticked today.
  final bool checkedToday;

  /// A one-tap rating module's latest rating today.
  final int? todayRating;

  /// The module's chart over its configured range (trackers only).
  final ModuleChartData? chart;

  /// The last 7 daily values (trackers).
  final List<double> sparkline;

  String get id => module.id;

  /// Whole days since the last entry (null without entries).
  int? daysSinceLast(DateTime now) {
    final l = lastEntry;
    if (l == null) return null;
    final a = DateTime(l.year, l.month, l.day), b = DateTime(now.year, now.month, now.day);
    return DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
  }

  /// Share of list items done (0 when empty).
  double get listProgress => entryCount == 0 ? 0 : doneCount / entryCount;

  static ModuleSummary build(ModuleDefinition m, List<ModuleEntry> entries, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    bool isToday(DateTime t) => t.year == today.year && t.month == today.month && t.day == today.day;
    DateTime? last;
    var todayCount = 0, done = 0;
    for (final e in entries) {
      if (last == null || e.at.isAfter(last)) last = e.at;
      if (isToday(e.at)) todayCount++;
      if (e.done) done++;
    }
    var checked = false;
    int? rating;
    final quick = m.quickEntry;
    if (quick is QuickCheck) {
      checked = entries.any((e) => isToday(e.at) && FieldValues.checkbox(e.values[quick.fieldId]) == true);
    } else if (quick is QuickRate) {
      final todays = entries.where((e) => isToday(e.at) && FieldValues.rating(e.values[quick.fieldId]) != null).toList()
        ..sort((a, b) => b.at.compareTo(a.at));
      rating = todays.isEmpty ? null : FieldValues.rating(todays.first.values[quick.fieldId]);
    }
    final chart = m.kind == CustomModuleKind.tracker ? ModuleCharts.build(module: m, entries: entries, today: now) : null;
    return ModuleSummary(
      module: m,
      entryCount: entries.length,
      todayCount: todayCount,
      lastEntry: last,
      openCount: entries.length - done,
      doneCount: done,
      checkedToday: checked,
      todayRating: rating,
      chart: chart,
      sparkline: chart == null ? const [] : ModuleCharts.sparkline(chart),
    );
  }
}
