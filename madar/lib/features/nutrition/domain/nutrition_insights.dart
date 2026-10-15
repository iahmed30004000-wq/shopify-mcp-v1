/// Local observations over his own data: what he ate and when, against his
/// pain, his mood, his sleep, his water and his fasts.
///
/// The honesty rules this file is built on:
/// * **Counts, not causes.** An observation says "on the 3 worst pain days,
///   «مقلي» appears on 3 of them, and on 11 of the other 24 days". It never
///   says one caused the other, and the wording the UI uses must stay as
///   plain as that.
/// * **Nothing below the minimum.** With fewer than
///   [NutritionInsights.minDays] days that have food entries in the window,
///   [NutritionInsights.compute] returns an empty list; ask
///   [NutritionInsights.readiness] to tell the user how far off he is.
/// * **His own markers only.** The markers are his own tags plus "ate late"
///   (a time he can change); nothing is categorised by us.
library;

import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../../body/domain/body_clock.dart';
import '../../search/domain/search_text.dart';
import 'food_library.dart';
import 'food_log.dart';

/// What an observation is measured against. `lowerIsWorse` says which end of
/// the scale counts as a bad day.
enum NutritionMetric {
  /// The day's highest pain score (`pain_entries`).
  pain(lowerIsWorse: false),

  /// The day's average mood (`mood_entries`, 1‥5).
  mood(lowerIsWorse: true),

  /// Hours slept as he logged them (`mood_entries.sleepHours`).
  sleep(lowerIsWorse: true),

  /// Millilitres of water that day (`water_logs`).
  water(lowerIsWorse: true),

  /// Hours fasted that day (`fasting_sessions`, by the day they ended).
  fasting(lowerIsWorse: true);

  const NutritionMetric({required this.lowerIsWorse});

  /// Whether a *lower* number is the worse day.
  final bool lowerIsWorse;
}

/// A food-side marker of a day: one of his tags, or "ate late".
@immutable
class NutritionMarker {
  const NutritionMarker.tag(String tag) : key = 'tag:$tag', label = tag, isLate = false;
  const NutritionMarker.lateMeal(this.label) : key = lateKey, isLate = true;

  /// The key of the "ate late" marker.
  static const String lateKey = 'late';

  /// Key of a tag marker: `tag:` + the tag folded for search.
  static String tagKey(String tag) => 'tag:${SearchText.fold(tag)}';

  /// Stable identity ([tagKey], [lateKey]).
  final String key;

  /// What to show: his tag, or the label the caller gave "ate late".
  final String label;
  final bool isLate;

  @override
  bool operator ==(Object other) => other is NutritionMarker && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'NutritionMarker($key)';
}

/// One day of his, reduced to what the observations need.
@immutable
class NutritionDay {
  const NutritionDay({required this.day, required this.markers, required this.metrics, required this.entries});

  final DateTime day;

  /// The markers true on that day.
  final Set<String> markers;

  /// The day's value per metric (absent when he logged nothing for it).
  final Map<NutritionMetric, double> metrics;

  /// How many food entries the day holds.
  final int entries;

  bool get hasFood => entries > 0;

  @override
  String toString() => 'NutritionDay(${BodyDays.key(day)}, ${markers.length} markers, ${metrics.length} metrics)';
}

/// "On the [worstDays] worst days for [metric], [marker] happened on
/// [inWorst] of them; on the other [otherDays] days it happened on
/// [inOther]."
@immutable
class WorstDaysOverlap {
  const WorstDaysOverlap({
    required this.metric,
    required this.marker,
    required this.worstDays,
    required this.inWorst,
    required this.otherDays,
    required this.inOther,
    required this.windowDays,
    required this.daysCompared,
  });

  final NutritionMetric metric;
  final NutritionMarker marker;

  /// How many days were taken as "the worst" (the k of the top-k).
  final int worstDays;

  /// On how many of them the marker happened.
  final int inWorst;
  final int otherDays;
  final int inOther;

  /// The window the comparison looked at, in days.
  final int windowDays;

  /// Days that had both a value for the metric and food logged.
  final int daysCompared;

  /// Share on the worst days (0‥1).
  double get worstShare => worstDays == 0 ? 0 : inWorst / worstDays;

  /// Share on the other days (0‥1).
  double get otherShare => otherDays == 0 ? 0 : inOther / otherDays;

  /// How much more often it happened on the worst days (may be negative).
  double get gap => worstShare - otherShare;

  @override
  String toString() =>
      'WorstDaysOverlap(${metric.name}: ${marker.key} $inWorst/$worstDays vs $inOther/$otherDays, $windowDays d)';
}

/// "On the [daysWith] days with [marker] your average [metric] was
/// [meanWith]; on the [daysWithout] days without it, [meanWithout]."
@immutable
class MarkerDayMeans {
  const MarkerDayMeans({
    required this.metric,
    required this.marker,
    required this.daysWith,
    required this.meanWith,
    required this.daysWithout,
    required this.meanWithout,
    required this.windowDays,
  });

  final NutritionMetric metric;
  final NutritionMarker marker;
  final int daysWith;
  final double meanWith;
  final int daysWithout;
  final double meanWithout;
  final int windowDays;

  /// meanWith − meanWithout.
  double get diff => meanWith - meanWithout;

  /// How big the difference is, regardless of direction.
  double get size => diff.abs();

  @override
  String toString() =>
      'MarkerDayMeans(${metric.name}: ${marker.key} ${meanWith.toStringAsFixed(1)} vs '
      '${meanWithout.toStringAsFixed(1)}, $daysWith/$daysWithout days)';
}

/// Everything the insights found, plus how much data they rest on.
@immutable
class NutritionInsightSet {
  const NutritionInsightSet({
    required this.readiness,
    this.overlaps = const [],
    this.means = const [],
  });

  static const NutritionInsightSet empty = NutritionInsightSet(readiness: NutritionReadiness(daysLogged: 0, daysNeeded: NutritionInsights.minDays));

  final NutritionReadiness readiness;

  /// "The worst days" observations, clearest gap first.
  final List<WorstDaysOverlap> overlaps;

  /// "With vs without" averages, biggest difference first.
  final List<MarkerDayMeans> means;

  bool get isEmpty => overlaps.isEmpty && means.isEmpty;

  @override
  String toString() => 'NutritionInsightSet(${overlaps.length} overlaps, ${means.length} means, $readiness)';
}

/// How far his data is from the first observation.
@immutable
class NutritionReadiness {
  const NutritionReadiness({required this.daysLogged, required this.daysNeeded});

  /// Days in the window with at least one food entry.
  final int daysLogged;

  /// Days needed before anything is said at all.
  final int daysNeeded;

  bool get ready => daysLogged >= daysNeeded;
  int get daysLeft => ready ? 0 : daysNeeded - daysLogged;
  double get progress => daysNeeded == 0 ? 1 : (daysLogged / daysNeeded).clamp(0.0, 1.0);

  @override
  String toString() => 'NutritionReadiness($daysLogged/$daysNeeded)';
}

/// A pain score he logged (a plain copy of a `pain_entries` row).
@immutable
class PainPoint {
  const PainPoint(this.at, this.score);
  final DateTime at;
  final int score;
}

/// A check-in he logged (a plain copy of a `mood_entries` row).
@immutable
class MoodPoint {
  const MoodPoint(this.at, {this.mood, this.sleepHours});
  final DateTime at;
  final int? mood;
  final double? sleepHours;
}

/// A glass of water (a plain copy of a `water_logs` row).
@immutable
class WaterPoint {
  const WaterPoint(this.at, this.ml);
  final DateTime at;
  final int ml;
}

/// A finished fast (a plain copy of a `fasting_sessions` row); it counts on
/// the day it ended.
@immutable
class FastPoint {
  const FastPoint(this.start, this.end);
  final DateTime start;
  final DateTime? end;
}

/// The other planets' numbers the observations need, as the service reads
/// them (see `NutritionService.metricsSince`).
typedef NutritionMetrics = ({
  List<PainPoint> pains,
  List<MoodPoint> moods,
  List<WaterPoint> waters,
  List<FastPoint> fasts,
});

/// The correlation helpers. All pure; they only ever count and average.
abstract final class NutritionInsights {
  /// How far back the observations look.
  static const int windowDays = 60;

  /// Days with food logged that the window needs before anything is said.
  static const int minDays = 10;

  /// A marker is only looked at once it happened on this many days, and it
  /// must also be absent on that many.
  static const int minMarkerDays = 3;

  /// How many days count as "the worst days".
  static const int worstCount = 3;

  /// A "with vs without" line needs at least this difference to be shown
  /// (in the metric's own unit).
  static const Map<NutritionMetric, double> minDiff = {
    NutritionMetric.pain: 1,
    NutritionMetric.mood: 0.5,
    NutritionMetric.sleep: 0.5,
    NutritionMetric.water: 250,
    NutritionMetric.fasting: 1,
  };

  /// A marker must stand out on the worst days by this much to be reported.
  static const double minGap = 0.25;

  static const int maxPerKind = 5;

  /// "Ate late" means an entry at or after this wall-clock minute (21:00).
  static const int lateFromMinutes = 21 * 60;

  /// Days with food logged in the window before [today] against [minDays].
  /// Call it for the empty state: "بعد ٤ أيام بسجّل أكل وبصير أقدر أحكي".
  static NutritionReadiness readiness({
    required Iterable<FoodEntry> entries,
    required DateTime today,
    int window = windowDays,
    BodyWallClock clock = const LocalBodyWallClock(),
  }) => NutritionReadiness(
    daysLogged: FoodLogStats.daysLogged(entries, today: today, windowDays: window, clock: clock),
    daysNeeded: minDays,
  );

  /// The days of the window, newest last, each with its markers and metrics.
  ///
  /// [lateLabel] is what "ate late" should read as in the UI (pass a
  /// localised string; the domain holds no text of its own).
  static List<NutritionDay> buildDays({
    required Iterable<FoodEntry> entries,
    required DateTime today,
    Map<String, Food> foodsById = const {},
    Iterable<PainPoint> pains = const [],
    Iterable<MoodPoint> moods = const [],
    Iterable<WaterPoint> waters = const [],
    Iterable<FastPoint> fasts = const [],
    int window = windowDays,
    int lateFrom = lateFromMinutes,
    BodyWallClock clock = const LocalBodyWallClock(),
  }) {
    final to = BodyDays.of(today);
    final from = BodyDays.add(to, -(window - 1));
    bool inWindow(DateTime at) {
      final d = clock.dayOf(at);
      return !d.isBefore(from) && !d.isAfter(to);
    }

    final markers = <String, Set<String>>{};
    final counts = <String, int>{};
    for (final e in entries) {
      if (!inWindow(e.at)) continue;
      final key = BodyDays.key(clock.dayOf(e.at));
      counts[key] = (counts[key] ?? 0) + 1;
      final set = markers.putIfAbsent(key, () => <String>{});
      for (final tag in FoodLogStats.tagsFor(e, food: foodsById[e.foodId])) {
        final folded = SearchText.fold(tag);
        if (folded.isNotEmpty) set.add('tag:$folded');
      }
      if (e.minuteOfDay >= lateFrom) set.add(NutritionMarker.lateKey);
    }

    final painMax = <String, double>{};
    for (final p in pains) {
      if (!inWindow(p.at)) continue;
      final key = BodyDays.key(clock.dayOf(p.at));
      final v = p.score.toDouble();
      painMax[key] = math.max(painMax[key] ?? v, v);
    }
    final moodSum = <String, (double, int)>{};
    final sleepSum = <String, (double, int)>{};
    for (final m in moods) {
      if (!inWindow(m.at)) continue;
      final key = BodyDays.key(clock.dayOf(m.at));
      final mood = m.mood;
      if (mood != null) {
        final prev = moodSum[key] ?? (0.0, 0);
        moodSum[key] = (prev.$1 + mood, prev.$2 + 1);
      }
      final sleep = m.sleepHours;
      if (sleep != null) {
        final prev = sleepSum[key] ?? (0.0, 0);
        sleepSum[key] = (prev.$1 + sleep, prev.$2 + 1);
      }
    }
    final waterSum = <String, double>{};
    for (final w in waters) {
      if (!inWindow(w.at)) continue;
      final key = BodyDays.key(clock.dayOf(w.at));
      waterSum[key] = (waterSum[key] ?? 0) + w.ml;
    }
    final fastSum = <String, double>{};
    for (final f in fasts) {
      final end = f.end;
      if (end == null || !inWindow(end)) continue;
      final key = BodyDays.key(clock.dayOf(end));
      final hours = end.difference(f.start).inMinutes / 60;
      fastSum[key] = (fastSum[key] ?? 0) + hours;
    }

    final out = <NutritionDay>[];
    for (var day = from; !day.isAfter(to); day = BodyDays.add(day, 1)) {
      final key = BodyDays.key(day);
      final metrics = <NutritionMetric, double>{};
      if (painMax.containsKey(key)) metrics[NutritionMetric.pain] = painMax[key]!;
      final mood = moodSum[key];
      if (mood != null && mood.$2 > 0) metrics[NutritionMetric.mood] = mood.$1 / mood.$2;
      final sleep = sleepSum[key];
      if (sleep != null && sleep.$2 > 0) metrics[NutritionMetric.sleep] = sleep.$1 / sleep.$2;
      if (waterSum.containsKey(key)) metrics[NutritionMetric.water] = waterSum[key]!;
      if (fastSum.containsKey(key)) metrics[NutritionMetric.fasting] = fastSum[key]!;
      out.add(
        NutritionDay(
          day: day,
          markers: markers[key] ?? const <String>{},
          metrics: metrics,
          entries: counts[key] ?? 0,
        ),
      );
    }
    return out;
  }

  /// Everything the data honestly supports, or an empty set with a
  /// [NutritionReadiness] when it does not support anything yet.
  ///
  /// [markerLabels] maps a marker key (`tag:<folded tag>`, `late`) to the
  /// words to show; missing keys fall back to the folded tag itself, so the
  /// UI can pass only «متأخر» for `late`.
  static NutritionInsightSet compute({
    required Iterable<FoodEntry> entries,
    required DateTime today,
    Map<String, Food> foodsById = const {},
    Iterable<PainPoint> pains = const [],
    Iterable<MoodPoint> moods = const [],
    Iterable<WaterPoint> waters = const [],
    Iterable<FastPoint> fasts = const [],
    Map<String, String> markerLabels = const {},
    int window = windowDays,
    int lateFrom = lateFromMinutes,
    BodyWallClock clock = const LocalBodyWallClock(),
  }) {
    final ready = readiness(entries: entries, today: today, window: window, clock: clock);
    if (!ready.ready) return NutritionInsightSet(readiness: ready);
    final days = buildDays(
      entries: entries,
      today: today,
      foodsById: foodsById,
      pains: pains,
      moods: moods,
      waters: waters,
      fasts: fasts,
      window: window,
      lateFrom: lateFrom,
      clock: clock,
    );
    final set = fromDays(days, markerLabels: markerLabels, window: window);
    return NutritionInsightSet(readiness: ready, overlaps: set.overlaps, means: set.means);
  }

  /// [compute] over days already built (the shape every test uses).
  static NutritionInsightSet fromDays(
    List<NutritionDay> days, {
    Map<String, String> markerLabels = const {},
    int window = windowDays,
  }) {
    final withFood = [
      for (final d in days)
        if (d.hasFood) d,
    ];
    final readinessOf = NutritionReadiness(daysLogged: withFood.length, daysNeeded: minDays);
    if (withFood.length < minDays) return NutritionInsightSet(readiness: readinessOf);

    final markerKeys = <String, int>{};
    for (final d in withFood) {
      for (final m in d.markers) {
        markerKeys[m] = (markerKeys[m] ?? 0) + 1;
      }
    }
    final markers = [
      for (final MapEntry(:key, :value) in markerKeys.entries)
        if (value >= minMarkerDays && withFood.length - value >= minMarkerDays) key,
    ]..sort();

    final overlaps = <WorstDaysOverlap>[];
    final means = <MarkerDayMeans>[];
    for (final metric in NutritionMetric.values) {
      final rated = [
        for (final d in withFood)
          if (d.metrics.containsKey(metric)) d,
      ];
      if (rated.length < minDays) continue;
      final sorted = rated.toList()
        ..sort((a, b) {
          final va = a.metrics[metric]!, vb = b.metrics[metric]!;
          return metric.lowerIsWorse ? va.compareTo(vb) : vb.compareTo(va);
        });
      final k = math.min(worstCount, sorted.length - minMarkerDays);
      final worst = k > 0 ? sorted.sublist(0, k) : const <NutritionDay>[];
      final rest = k > 0 ? sorted.sublist(k) : sorted;

      for (final marker in markers) {
        if (worst.isNotEmpty) {
          final inWorst = worst.where((d) => d.markers.contains(marker)).length;
          final inOther = rest.where((d) => d.markers.contains(marker)).length;
          final overlap = WorstDaysOverlap(
            metric: metric,
            marker: _marker(marker, markerLabels),
            worstDays: worst.length,
            inWorst: inWorst,
            otherDays: rest.length,
            inOther: inOther,
            windowDays: window,
            daysCompared: rated.length,
          );
          if (overlap.gap >= minGap && inWorst > 0) overlaps.add(overlap);
        }
        final with_ = [
          for (final d in rated)
            if (d.markers.contains(marker)) d.metrics[metric]!,
        ];
        final without = [
          for (final d in rated)
            if (!d.markers.contains(marker)) d.metrics[metric]!,
        ];
        if (with_.length < minMarkerDays || without.length < minMarkerDays) continue;
        final mw = _mean(with_), mo = _mean(without);
        if ((mw - mo).abs() < (minDiff[metric] ?? 0)) continue;
        means.add(
          MarkerDayMeans(
            metric: metric,
            marker: _marker(marker, markerLabels),
            daysWith: with_.length,
            meanWith: mw,
            daysWithout: without.length,
            meanWithout: mo,
            windowDays: window,
          ),
        );
      }
    }
    overlaps.sort((a, b) {
      final byGap = b.gap.compareTo(a.gap);
      return byGap != 0 ? byGap : b.inWorst.compareTo(a.inWorst);
    });
    means.sort((a, b) => b.size.compareTo(a.size));
    return NutritionInsightSet(
      readiness: readinessOf,
      overlaps: overlaps.length <= maxPerKind ? overlaps : overlaps.sublist(0, maxPerKind),
      means: means.length <= maxPerKind ? means : means.sublist(0, maxPerKind),
    );
  }

  static NutritionMarker _marker(String key, Map<String, String> labels) {
    final label = labels[key];
    if (key == NutritionMarker.lateKey) return NutritionMarker.lateMeal(label ?? NutritionMarker.lateKey);
    return NutritionMarker.tag(label ?? key.substring('tag:'.length));
  }

  /// The labels [compute] needs: every tag of his foods and entries in the
  /// spelling he uses, keyed by marker key, plus [lateLabel] for "ate late"
  /// (pass a localised string).
  static Map<String, String> markerLabelsFor({
    Iterable<Food> foods = const [],
    Iterable<FoodEntry> entries = const [],
    required String lateLabel,
  }) {
    final out = <String, String>{NutritionMarker.lateKey: lateLabel};
    for (final tag in [...FoodLookup.tagsOf(foods), for (final e in entries) ...e.tags]) {
      final key = NutritionMarker.tagKey(tag);
      if (key == 'tag:') continue;
      out.putIfAbsent(key, () => tag.trim());
    }
    return out;
  }

  static double _mean(List<double> v) => v.fold<double>(0, (a, b) => a + b) / v.length;
}
