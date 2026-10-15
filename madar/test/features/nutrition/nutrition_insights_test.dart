import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/nutrition/nutrition.dart';

final _today = DateTime(2026, 10, 10);

FoodEntry _entry(String id, DateTime at, {List<String> tags = const [], String name = 'أكل'}) =>
    FoodEntry(id: id, name: name, at: at, tags: tags);

/// [days] days ending on [_today], one entry each at 13:00, tagged «مقلي» on
/// the days whose index (0 = oldest) is in [friedOn].
List<FoodEntry> _log(int days, {Set<int> friedOn = const {}}) {
  final out = <FoodEntry>[];
  for (var i = 0; i < days; i++) {
    final day = DateTime(2026, 10, 10 - (days - 1 - i));
    out.add(_entry('e$i', DateTime(day.year, day.month, day.day, 13), tags: friedOn.contains(i) ? ['مقلي'] : const []));
  }
  return out;
}

void main() {
  group('the minimum amount of data', () {
    test('below the minimum nothing at all is said, and readiness says how far off he is', () {
      final entries = _log(NutritionInsights.minDays - 1, friedOn: {0, 1, 2});
      final pains = [
        for (var i = 0; i < NutritionInsights.minDays - 1; i++)
          PainPoint(DateTime(2026, 10, 10 - i, 21), i < 3 ? 9 : 2),
      ];
      final set = NutritionInsights.compute(entries: entries, today: _today, pains: pains);
      expect(set.isEmpty, isTrue);
      expect(set.overlaps, isEmpty);
      expect(set.means, isEmpty);
      expect(set.readiness.ready, isFalse);
      expect(set.readiness.daysLogged, NutritionInsights.minDays - 1);
      expect(set.readiness.daysNeeded, NutritionInsights.minDays);
      expect(set.readiness.daysLeft, 1);
    });

    test('no data at all: an empty set, no crash', () {
      final set = NutritionInsights.compute(entries: const [], today: _today);
      expect(set.isEmpty, isTrue);
      expect(set.readiness.daysLogged, 0);
      expect(set.readiness.progress, 0);
    });

    test('readiness counts days with food inside the window only', () {
      final entries = [
        ..._log(4),
        _entry('old', DateTime(2025, 1, 1, 13)),
      ];
      expect(NutritionInsights.readiness(entries: entries, today: _today).daysLogged, 4);
    });
  });

  group('the worst days', () {
    test('"on the 3 worst pain days X happened on 3 of them" comes with both counts', () {
      // 14 days: pain 9 on the three days that carry «مقلي», pain 2 on the rest.
      const fried = {11, 12, 13};
      final entries = _log(14, friedOn: fried);
      final pains = <PainPoint>[];
      for (var i = 0; i < 14; i++) {
        final day = DateTime(2026, 10, 10 - (13 - i));
        pains.add(PainPoint(DateTime(day.year, day.month, day.day, 21), fried.contains(i) ? 9 : 2));
      }
      final set = NutritionInsights.compute(
        entries: entries,
        today: _today,
        pains: pains,
        markerLabels: {NutritionMarker.tagKey('مقلي'): 'مقلي'},
      );
      final overlap = set.overlaps.firstWhere((o) => o.metric == NutritionMetric.pain);
      expect(overlap.marker.label, 'مقلي');
      expect(overlap.worstDays, NutritionInsights.worstCount);
      expect(overlap.inWorst, 3);
      expect(overlap.otherDays, 11);
      expect(overlap.inOther, 0);
      expect(overlap.worstShare, 1);
      expect(overlap.otherShare, 0);
      expect(overlap.windowDays, NutritionInsights.windowDays);
      expect(overlap.daysCompared, 14);

      // The same pair also shows as plain averages, with the day counts.
      final mean = set.means.firstWhere((m) => m.metric == NutritionMetric.pain && m.marker.label == 'مقلي');
      expect(mean.daysWith, 3);
      expect(mean.meanWith, 9);
      expect(mean.daysWithout, 11);
      expect(mean.meanWithout, 2);
      expect(mean.diff, 7);
    });

    test('a marker that is everywhere, or almost nowhere, is not reported', () {
      final everywhere = _log(14, friedOn: {for (var i = 0; i < 14; i++) i});
      final pains = [for (var i = 0; i < 14; i++) PainPoint(DateTime(2026, 10, 10 - i, 21), i.isEven ? 8 : 2)];
      expect(NutritionInsights.compute(entries: everywhere, today: _today, pains: pains).isEmpty, isTrue);

      final twice = _log(14, friedOn: {12, 13});
      expect(
        NutritionInsights.compute(entries: twice, today: _today, pains: pains).overlaps,
        isEmpty,
        reason: 'two days is below minMarkerDays',
      );
    });

    test('a marker that is just as common on the good days is not reported', () {
      // «مقلي» on 7 of 14 days, pain unrelated to it.
      final entries = _log(14, friedOn: {0, 1, 2, 3, 4, 5, 6});
      final pains = <PainPoint>[];
      for (var i = 0; i < 14; i++) {
        final day = DateTime(2026, 10, 10 - (13 - i));
        pains.add(PainPoint(DateTime(day.year, day.month, day.day, 21), i.isEven ? 7 : 2));
      }
      final set = NutritionInsights.compute(entries: entries, today: _today, pains: pains);
      expect(set.overlaps.where((o) => o.gap < NutritionInsights.minGap), isEmpty);
    });
  });

  group('metrics', () {
    test('mood, sleep, water and fasting are all read, each by its own day', () {
      final days = NutritionInsights.minDays + 2;
      final entries = _log(days, friedOn: {for (var i = 0; i < days; i += 2) i});
      final moods = <MoodPoint>[];
      final waters = <WaterPoint>[];
      final fasts = <FastPoint>[];
      for (var i = 0; i < days; i++) {
        final day = DateTime(2026, 10, 10 - (days - 1 - i));
        final fried = i.isEven;
        moods.add(MoodPoint(DateTime(day.year, day.month, day.day, 22), mood: fried ? 2 : 5, sleepHours: fried ? 5 : 8));
        waters.add(WaterPoint(DateTime(day.year, day.month, day.day, 12), fried ? 500 : 2500));
        fasts.add(
          FastPoint(
            DateTime(day.year, day.month, day.day, 2),
            DateTime(day.year, day.month, day.day, fried ? 10 : 16),
          ),
        );
      }
      final set = NutritionInsights.compute(
        entries: entries,
        today: _today,
        moods: moods,
        waters: waters,
        fasts: fasts,
        markerLabels: {NutritionMarker.tagKey('مقلي'): 'مقلي'},
      );
      final metrics = set.means.map((m) => m.metric).toSet();
      expect(metrics, containsAll([NutritionMetric.mood, NutritionMetric.sleep, NutritionMetric.water, NutritionMetric.fasting]));
      final sleep = set.means.firstWhere((m) => m.metric == NutritionMetric.sleep);
      expect(sleep.meanWith, 5);
      expect(sleep.meanWithout, 8);
      expect(NutritionMetric.sleep.lowerIsWorse, isTrue);
      expect(NutritionMetric.pain.lowerIsWorse, isFalse);
    });

    test('"ate late" is a marker of its own, with the label the UI gives it', () {
      final entries = <FoodEntry>[];
      for (var i = 0; i < 14; i++) {
        final day = DateTime(2026, 10, 10 - (13 - i));
        final late = i >= 11;
        entries.add(_entry('e$i', DateTime(day.year, day.month, day.day, late ? 22 : 13)));
      }
      final moods = [
        for (var i = 0; i < 14; i++)
          MoodPoint(DateTime(2026, 10, 10 - (13 - i), 23, 30), sleepHours: i >= 11 ? 4 : 8),
      ];
      final set = NutritionInsights.compute(
        entries: entries,
        today: _today,
        moods: moods,
        markerLabels: {NutritionMarker.lateKey: 'أكل متأخر'},
      );
      final late = set.means.firstWhere((m) => m.marker.isLate);
      expect(late.marker.label, 'أكل متأخر');
      expect(late.daysWith, 3);
      expect(late.meanWith, 4);
      expect(late.meanWithout, 8);
    });

    test('a difference too small to matter is dropped', () {
      final days = 14;
      final entries = _log(days, friedOn: {for (var i = 0; i < days; i += 2) i});
      final moods = [
        for (var i = 0; i < days; i++)
          MoodPoint(DateTime(2026, 10, 10 - (days - 1 - i), 22), sleepHours: i.isEven ? 7.1 : 7.0),
      ];
      final set = NutritionInsights.compute(entries: entries, today: _today, moods: moods);
      expect(set.means.where((m) => m.metric == NutritionMetric.sleep), isEmpty);
    });

    test('markerLabelsFor builds the labels from his own spellings', () {
      final labels = NutritionInsights.markerLabelsFor(
        foods: [const Food(id: 'f1', name: 'فلافل', tags: ['مَقلي'])],
        entries: [_entry('e1', DateTime(2026, 10, 10, 13), tags: ['زيارة'])],
        lateLabel: 'أكل متأخر',
      );
      expect(labels[NutritionMarker.lateKey], 'أكل متأخر');
      expect(labels[NutritionMarker.tagKey('مقلي')], 'مَقلي');
      expect(labels[NutritionMarker.tagKey('زيارة')], 'زيارة');
    });
  });

  test('buildDays returns one record per day of the window, oldest first', () {
    final days = NutritionInsights.buildDays(entries: _log(3), today: _today, window: 5);
    expect(days, hasLength(5));
    expect(days.first.day, DateTime(2026, 10, 6));
    expect(days.last.day, _today);
    expect(days.first.hasFood, isFalse);
    expect(days.last.entries, 1);
  });
}
