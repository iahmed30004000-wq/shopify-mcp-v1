import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'wellbeing_data.dart';

/// Local, on-device observations about the user's own data: comparisons of
/// means between groups of days and same-day correlations. They are neutral
/// descriptions with their numbers – never advice, never a cause.
///
/// Rules (all pure, see `insights_test.dart`):
/// * the window is the last [InsightEngine.windowDays] days (90) – the last
///   30–90 days in practice, as far back as data goes;
/// * a day is one [DayRecord] (check-ins averaged, the day's highest pain);
/// * a **split** compares the mean of an outcome on days that meet a
///   condition ("slept under 6 h") with the other days; it needs at least
///   [InsightEngine.minGroupDays] days in *each* group,
///   [InsightEngine.minTotalDays] in total and a difference of at least the
///   outcome's [WellMetric.meaningfulDiff];
/// * a **correlation** is Pearson's r over days with both values; it needs
///   [InsightEngine.minCorrelationDays] days and |r| ≥
///   [InsightEngine.minAbsR];
/// * a correlation is dropped when a split already describes the same pair;
///   results are ranked by effect size (Cohen's d; r converted with
///   d = 2r/√(1−r²)) and capped.
@immutable
sealed class WellbeingInsight {
  const WellbeingInsight({required this.days});

  /// Days the observation rests on.
  final int days;

  /// Effect size for ranking (larger = clearer).
  double get strength;

  /// The two metrics involved (predictor, outcome) – order-free identity.
  Set<WellMetric> get pair;
}

/// A condition that sorts days into two groups.
@immutable
class SplitCondition {
  const SplitCondition(this.metric, this.threshold, {required this.below});

  final WellMetric metric;
  final double threshold;

  /// True: the condition is "[metric] < threshold"; false: "≥ threshold".
  final bool below;

  bool test(double v) => below ? v < threshold : v >= threshold;

  static const shortSleep = SplitCondition(WellMetric.sleep, 6, below: true);
  static const muchCaffeine = SplitCondition(WellMetric.caffeine, 3, below: false);
  static const highStress = SplitCondition(WellMetric.stress, 7, below: false);

  @override
  bool operator ==(Object other) =>
      other is SplitCondition && other.metric == metric && other.threshold == threshold && other.below == below;

  @override
  int get hashCode => Object.hash(metric, threshold, below);
}

/// "On days when [condition], your average [outcome] was [meanIn] vs
/// [meanOut] on the other days."
@immutable
class SplitInsight extends WellbeingInsight {
  const SplitInsight({
    required this.condition,
    required this.outcome,
    required this.meanIn,
    required this.meanOut,
    required this.daysIn,
    required this.daysOut,
    required this.effect,
  }) : super(days: daysIn + daysOut);

  final SplitCondition condition;
  final WellMetric outcome;
  final double meanIn;
  final double meanOut;
  final int daysIn;
  final int daysOut;

  /// Cohen's d (pooled SD).
  final double effect;

  /// meanIn − meanOut.
  double get diff => meanIn - meanOut;
  bool get higher => diff > 0;

  @override
  double get strength => effect.abs();

  @override
  Set<WellMetric> get pair => {condition.metric, outcome};

  @override
  String toString() =>
      'SplitInsight(${condition.metric.name}${condition.below ? '<' : '≥'}${condition.threshold} → ${outcome.name}: '
      '${meanIn.toStringAsFixed(2)} vs ${meanOut.toStringAsFixed(2)}, $daysIn/$daysOut days, d=${effect.toStringAsFixed(2)})';
}

/// "On days when your [a] was higher, your [b] tended to be higher (lower)."
@immutable
class CorrelationInsight extends WellbeingInsight {
  const CorrelationInsight({required this.a, required this.b, required this.r, required super.days});

  final WellMetric a;
  final WellMetric b;

  /// Pearson's r.
  final double r;

  bool get positive => r > 0;

  @override
  double get strength {
    final rr = r.abs().clamp(0.0, 0.999);
    return 2 * rr / math.sqrt(1 - rr * rr);
  }

  @override
  Set<WellMetric> get pair => {a, b};

  @override
  String toString() => 'CorrelationInsight(${a.name}~${b.name}: r=${r.toStringAsFixed(2)}, $days days)';
}

/// How far the data is from the first observation (for the empty state).
@immutable
class InsightReadiness {
  const InsightReadiness({required this.daysLogged, required this.daysNeeded});

  final int daysLogged;
  final int daysNeeded;

  double get progress => daysNeeded == 0 ? 1 : (daysLogged / daysNeeded).clamp(0.0, 1.0);
}

abstract final class InsightEngine {
  static const int windowDays = 90;
  static const int minGroupDays = 4;
  static const int minTotalDays = 10;
  static const int minCorrelationDays = 10;
  static const double minAbsR = 0.3;
  static const int maxInsights = 5;

  /// The splits tried: condition → outcomes.
  static const List<(SplitCondition, List<WellMetric>)> splits = [
    (
      SplitCondition.shortSleep,
      [WellMetric.stress, WellMetric.anxiety, WellMetric.mood, WellMetric.energy, WellMetric.pain],
    ),
    (SplitCondition.muchCaffeine, [WellMetric.sleep, WellMetric.anxiety, WellMetric.stress]),
    (SplitCondition.highStress, [WellMetric.pain, WellMetric.sleep]),
  ];

  /// The same-day correlations tried.
  static const List<(WellMetric, WellMetric)> correlations = [
    (WellMetric.stress, WellMetric.pain),
    (WellMetric.sleep, WellMetric.pain),
    (WellMetric.sleep, WellMetric.stress),
    (WellMetric.sleep, WellMetric.mood),
    (WellMetric.sleep, WellMetric.energy),
    (WellMetric.caffeine, WellMetric.sleep),
    (WellMetric.anxiety, WellMetric.pain),
    (WellMetric.stress, WellMetric.mood),
  ];

  /// Observations from the check-ins and pain logs of the last [windowDays]
  /// days before [today] (inclusive), strongest first, at most [max].
  static List<WellbeingInsight> compute({
    required Iterable<MoodSample> moods,
    required Iterable<PainSample> pains,
    required DateTime today,
    int max = maxInsights,
  }) {
    final to = WbDays.dateOf(today);
    final records = DayRecord.build(moods: moods, pains: pains, from: WbDays.add(to, -(windowDays - 1)), to: to);
    return fromRecords(records, max: max);
  }

  static List<WellbeingInsight> fromRecords(List<DayRecord> records, {int max = maxInsights}) {
    final found = <WellbeingInsight>[];
    for (final (cond, outcomes) in splits) {
      for (final outcome in outcomes) {
        final s = split(records, cond, outcome);
        if (s != null) found.add(s);
      }
    }
    for (final (a, b) in correlations) {
      if (found.any((f) => f is SplitInsight && f.pair.containsAll({a, b}))) continue;
      final c = correlate(records, a, b);
      if (c != null) found.add(c);
    }
    found.sort((x, y) {
      final c = y.strength.compareTo(x.strength);
      return c != 0 ? c : y.days.compareTo(x.days);
    });
    // One observation per pair of metrics.
    final seen = <String>{};
    final out = <WellbeingInsight>[];
    for (final f in found) {
      final key = (f.pair.map((m) => m.index).toList()..sort()).join('-');
      if (!seen.add(key)) continue;
      out.add(f);
      if (out.length >= max) break;
    }
    return out;
  }

  /// A qualifying comparison of means, or null.
  static SplitInsight? split(List<DayRecord> records, SplitCondition cond, WellMetric outcome) {
    final inGroup = <double>[];
    final outGroup = <double>[];
    for (final r in records) {
      final p = r[cond.metric];
      final o = r[outcome];
      if (p == null || o == null) continue;
      (cond.test(p) ? inGroup : outGroup).add(o);
    }
    if (inGroup.length < minGroupDays || outGroup.length < minGroupDays) return null;
    if (inGroup.length + outGroup.length < minTotalDays) return null;
    final mIn = _mean(inGroup);
    final mOut = _mean(outGroup);
    final diff = mIn - mOut;
    if (diff.abs() < outcome.meaningfulDiff) return null;
    final pooled = math.sqrt(
      ((inGroup.length - 1) * _variance(inGroup, mIn) + (outGroup.length - 1) * _variance(outGroup, mOut)) /
          (inGroup.length + outGroup.length - 2),
    );
    // Identical days within each group: the gap is as clear as it gets.
    final d = pooled < 1e-9 ? diff.sign * 4.0 : diff / pooled;
    return SplitInsight(
      condition: cond,
      outcome: outcome,
      meanIn: mIn,
      meanOut: mOut,
      daysIn: inGroup.length,
      daysOut: outGroup.length,
      effect: d,
    );
  }

  /// A qualifying correlation, or null.
  static CorrelationInsight? correlate(List<DayRecord> records, WellMetric a, WellMetric b) {
    final xs = <double>[];
    final ys = <double>[];
    for (final r in records) {
      final x = r[a];
      final y = r[b];
      if (x == null || y == null) continue;
      xs.add(x);
      ys.add(y);
    }
    if (xs.length < minCorrelationDays) return null;
    final r = pearson(xs, ys);
    if (r == null || r.abs() < minAbsR) return null;
    return CorrelationInsight(a: a, b: b, r: r, days: xs.length);
  }

  /// Pearson's correlation coefficient, or null when either side has no
  /// variance or the lists are shorter than 3.
  static double? pearson(List<double> x, List<double> y) {
    if (x.length != y.length || x.length < 3) return null;
    final mx = _mean(x);
    final my = _mean(y);
    var sxy = 0.0, sxx = 0.0, syy = 0.0;
    for (var i = 0; i < x.length; i++) {
      final dx = x[i] - mx;
      final dy = y[i] - my;
      sxy += dx * dy;
      sxx += dx * dx;
      syy += dy * dy;
    }
    if (sxx < 1e-12 || syy < 1e-12) return null;
    return (sxy / math.sqrt(sxx * syy)).clamp(-1.0, 1.0);
  }

  /// Days with any check-in or pain log in the window, against the days the
  /// first observation needs at the very least.
  static InsightReadiness readiness({
    required Iterable<MoodSample> moods,
    required Iterable<PainSample> pains,
    required DateTime today,
  }) {
    final to = WbDays.dateOf(today);
    final records = DayRecord.build(moods: moods, pains: pains, from: WbDays.add(to, -(windowDays - 1)), to: to);
    return InsightReadiness(daysLogged: records.length, daysNeeded: minTotalDays);
  }

  static double _mean(List<double> v) => v.fold<double>(0, (a, b) => a + b) / v.length;

  static double _variance(List<double> v, double mean) {
    if (v.length < 2) return 0;
    var s = 0.0;
    for (final x in v) {
      s += (x - mean) * (x - mean);
    }
    return s / (v.length - 1);
  }
}
