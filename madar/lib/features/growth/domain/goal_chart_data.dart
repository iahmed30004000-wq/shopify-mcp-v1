import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'goal_math.dart';
import 'growth_days.dart';

/// A chart point: x in days since the goal's first day (fractional), y in
/// the goal's unit.
@immutable
class ChartXY {
  const ChartXY(this.x, this.y);

  final double x;
  final double y;

  @override
  bool operator ==(Object other) => other is ChartXY && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '($x, $y)';
}

/// Everything the goal chart draws, in chart units (pure; the widget only
/// maps it to fl_chart and mirrors x in right-to-left layouts).
///
/// * [actual] – the running total: the starting value on day one, a point
///   per log, flat to now.
/// * [plan] – a straight line from the starting value to the target at the
///   end of the deadline day (empty without a deadline).
/// * [projection] – from now to where the recent pace meets the target,
///   cut at [projectionReachDays] past the rest of the chart.
/// * [target] – the horizontal target line.
@immutable
class GoalChartData {
  const GoalChartData({
    required this.origin,
    required this.actual,
    required this.plan,
    required this.projection,
    required this.target,
    required this.nowX,
    required this.maxX,
    required this.maxY,
    required this.yInterval,
  });

  /// Day zero (the goal's first day).
  final DateTime origin;
  final List<ChartXY> actual;
  final List<ChartXY> plan;
  final List<ChartXY> projection;
  final double target;
  final double nowX;
  final double maxX;
  final double maxY;
  final double yInterval;

  static const int projectionReachDays = 90;

  /// The calendar day at [x].
  DateTime dateAt(double x) => GrowthDays.add(origin, x.floor());

  /// [x] as laid out: time runs in the reading direction, so in a
  /// right-to-left layout the first day is on the right.
  static double mirror(double x, double maxX, {required bool rtl}) => rtl ? maxX - x : x;

  /// 1, 2, 2.5 or 5 × a power of ten, at least [raw].
  static double niceStep(double raw) {
    if (raw.isNaN || raw <= 0) return 1;
    final exp = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final f = raw / exp;
    final nice = f <= 1 + 1e-9
        ? 1.0
        : f <= 2 + 1e-9
        ? 2.0
        : f <= 2.5 + 1e-9
        ? 2.5
        : f <= 5 + 1e-9
        ? 5.0
        : 10.0;
    return nice * exp;
  }

  static GoalChartData build(
    GoalStats stats,
    Iterable<GoalEntry> entries, {
    required DateTime now,
    int reach = projectionReachDays,
  }) {
    final origin = stats.start;
    double xOf(DateTime t) => math.max(0, GrowthDays.fractional(origin, t));
    final sorted = entries.toList()..sort((a, b) => a.at.compareTo(b.at));

    final nowX = math.max(xOf(now), 0.0);
    var run = stats.initial;
    final actual = <ChartXY>[ChartXY(0, run)];
    for (final e in sorted) {
      run += e.amount;
      actual.add(ChartXY(xOf(e.at), run));
    }
    final lastX = actual.last.x;
    if (nowX > lastX) actual.add(ChartXY(nowX, run));

    final deadline = stats.deadline;
    final deadlineX = deadline == null ? null : (GrowthDays.between(origin, deadline) + 1).toDouble();
    final plan = deadlineX == null || deadlineX <= 0
        ? const <ChartXY>[]
        : [ChartXY(0, stats.initial), ChartXY(deadlineX, stats.target)];

    var maxX = [nowX, lastX, deadlineX ?? 0, 1.0].reduce(math.max);
    var projection = const <ChartXY>[];
    final finish = stats.projectedFinish;
    if (!stats.completed && finish != null) {
      final from = ChartXY(nowX, stats.current);
      final finishX = math.max(nowX + 1e-3, (GrowthDays.between(origin, finish) + 1).toDouble());
      final end = math.min(finishX, maxX + reach);
      final y = from.y + (stats.target - from.y) * ((end - from.x) / (finishX - from.x));
      projection = [from, ChartXY(end, y)];
      maxX = math.max(maxX, end);
    }

    final top = [stats.target, stats.current, run, 1.0].reduce(math.max) * 1.12;
    final interval = niceStep(top / 4);
    return GoalChartData(
      origin: origin,
      actual: actual,
      plan: plan,
      projection: projection,
      target: stats.target,
      nowX: nowX,
      maxX: maxX,
      maxY: top,
      yInterval: interval,
    );
  }
}
