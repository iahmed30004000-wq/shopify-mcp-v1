import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/health/wellbeing/wellbeing.dart';

final DateTime today = DateTime(2026, 9, 29);

MoodSample mood(
  int daysAgo, {
  int? mood,
  int? stress,
  int? anxiety,
  int? energy,
  double? sleep,
  int? cups,
  int hour = 21,
}) => MoodSample(
  at: DateTime(today.year, today.month, today.day - daysAgo, hour),
  mood: mood,
  stress: stress,
  anxiety: anxiety,
  energy: energy,
  sleepHours: sleep,
  caffeineCups: cups,
);

PainSample pain(int daysAgo, int score, {int hour = 12}) =>
    PainSample(at: DateTime(today.year, today.month, today.day - daysAgo, hour), score: score);

void main() {
  group('pearson', () {
    test('perfect positive, perfect negative, none', () {
      expect(InsightEngine.pearson([1, 2, 3, 4], [2, 4, 6, 8]), closeTo(1, 1e-9));
      expect(InsightEngine.pearson([1, 2, 3, 4], [8, 6, 4, 2]), closeTo(-1, 1e-9));
      expect(InsightEngine.pearson([1, 2, 3, 4, 5], [2, 1, 3, 1, 2]), closeTo(0, 0.2));
    });

    test('null without variance or with too few points', () {
      expect(InsightEngine.pearson([1, 1, 1], [1, 2, 3]), isNull);
      expect(InsightEngine.pearson([1, 2], [1, 2]), isNull);
      expect(InsightEngine.pearson([1, 2, 3], [1, 2]), isNull);
    });

    test('matches a hand-computed value', () {
      // x = 1..5, y = 2,4,5,4,5 → r ≈ 0.7746.
      expect(InsightEngine.pearson([1, 2, 3, 4, 5], [2, 4, 5, 4, 5]), closeTo(0.7746, 1e-4));
    });
  });

  group('DayRecord.build', () {
    test('averages check-ins, keeps the largest sleep/caffeine and the day max pain', () {
      final records = DayRecord.build(
        moods: [
          mood(0, mood: 2, stress: 8, sleep: 5, cups: 1, hour: 9),
          mood(0, mood: 4, stress: 4, sleep: 6, cups: 3, hour: 20),
        ],
        pains: [pain(0, 3), pain(0, 7, hour: 18)],
        from: today,
        to: today,
      );
      expect(records, hasLength(1));
      final r = records.single;
      expect(r[WellMetric.mood], 3);
      expect(r[WellMetric.stress], 6);
      expect(r[WellMetric.sleep], 6);
      expect(r[WellMetric.caffeine], 3);
      expect(r[WellMetric.pain], 7);
      expect(r[WellMetric.anxiety], isNull);
    });

    test('drops days outside the range and sorts oldest first', () {
      final records = DayRecord.build(
        moods: [mood(1, mood: 3), mood(10, mood: 3), mood(3, mood: 4)],
        pains: const [],
        from: today.subtract(const Duration(days: 5)),
        to: today,
      );
      expect([for (final r in records) r.day.day], [26, 28]);
    });
  });

  group('splits', () {
    List<MoodSample> sleepStress({
      required int shortDays,
      required int longDays,
      double shortStress = 7,
      double longStress = 4,
    }) => [
      for (var i = 0; i < shortDays; i++) mood(i, sleep: 5, stress: shortStress.round() + (i.isEven ? 0 : 1)),
      for (var i = 0; i < longDays; i++)
        mood(shortDays + i, sleep: 7.5, stress: longStress.round() + (i.isEven ? 0 : 1)),
    ];

    test('short sleep → higher mean stress, with the numbers', () {
      final list = InsightEngine.compute(moods: sleepStress(shortDays: 6, longDays: 8), pains: const [], today: today);
      final s = list.whereType<SplitInsight>().firstWhere((s) => s.outcome == WellMetric.stress);
      expect(s.condition, SplitCondition.shortSleep);
      expect(s.daysIn, 6);
      expect(s.daysOut, 8);
      expect(s.meanIn, closeTo(7.5, 1e-9));
      expect(s.meanOut, closeTo(4.5, 1e-9));
      expect(s.diff, closeTo(3, 1e-9));
      expect(s.higher, isTrue);
    });

    test('hidden when a group is under the minimum', () {
      final list = InsightEngine.compute(moods: sleepStress(shortDays: 3, longDays: 12), pains: const [], today: today);
      expect(list.whereType<SplitInsight>(), isEmpty);
    });

    test('hidden when the total is under the minimum', () {
      final list = InsightEngine.compute(moods: sleepStress(shortDays: 4, longDays: 5), pains: const [], today: today);
      expect(list, isEmpty);
    });

    test('hidden when the difference is too small to mention', () {
      final list = InsightEngine.compute(
        moods: [
          for (var i = 0; i < 6; i++) mood(i, sleep: 5, stress: 5),
          for (var i = 0; i < 6; i++) mood(6 + i, sleep: 8, stress: i.isEven ? 4 : 5),
        ],
        pains: const [],
        today: today,
      );
      expect(list.whereType<SplitInsight>().where((s) => s.outcome == WellMetric.stress), isEmpty);
    });

    test('caffeine → shorter sleep reads as "lower"', () {
      final list = InsightEngine.compute(
        moods: [
          for (var i = 0; i < 5; i++) mood(i, cups: 4, sleep: 5.5),
          for (var i = 0; i < 7; i++) mood(5 + i, cups: 1, sleep: 7.5),
        ],
        pains: const [],
        today: today,
      );
      final s = list.whereType<SplitInsight>().firstWhere((s) => s.condition == SplitCondition.muchCaffeine);
      expect(s.outcome, WellMetric.sleep);
      expect(s.higher, isFalse);
      expect(s.diff, closeTo(-2, 1e-9));
    });

    test('ignores data older than the 90-day window', () {
      final list = InsightEngine.compute(
        moods: [
          for (var i = 0; i < 6; i++) mood(100 + i, sleep: 5, stress: 8),
          for (var i = 0; i < 8; i++) mood(110 + i, sleep: 8, stress: 3),
        ],
        pains: const [],
        today: today,
      );
      expect(list, isEmpty);
    });
  });

  group('correlations', () {
    test('stress and pain rising together', () {
      final moods = [for (var i = 0; i < 12; i++) mood(i, stress: i % 6 + 2)];
      final pains = [for (var i = 0; i < 12; i++) pain(i, (i % 6 + 2) ~/ 2 + (i.isEven ? 1 : 0))];
      final list = InsightEngine.compute(moods: moods, pains: pains, today: today);
      final c = list.whereType<CorrelationInsight>().firstWhere(
        (c) => c.pair.containsAll({WellMetric.stress, WellMetric.pain}),
      );
      expect(c.positive, isTrue);
      expect(c.r, greaterThan(0.3));
      expect(c.days, 12);
    });

    test('needs ten days with both values', () {
      final moods = [for (var i = 0; i < 9; i++) mood(i, stress: i)];
      final pains = [for (var i = 0; i < 9; i++) pain(i, i)];
      expect(InsightEngine.compute(moods: moods, pains: pains, today: today), isEmpty);
    });

    test('weak links are hidden', () {
      final moods = [
        for (var i = 0; i < 14; i++) mood(i, sleep: 6 + (i % 3).toDouble(), energy: const [5, 3, 6, 4, 5, 6, 3][i % 7]),
      ];
      final list = InsightEngine.compute(moods: moods, pains: const [], today: today);
      expect(
        list.whereType<CorrelationInsight>().where((c) => c.pair.containsAll({WellMetric.sleep, WellMetric.energy})),
        isEmpty,
      );
    });

    test('a split already covering the pair suppresses the correlation', () {
      final moods = [
        for (var i = 0; i < 6; i++) mood(i, sleep: 5 + (i % 2) * 0.5, stress: 7 + i % 2),
        for (var i = 0; i < 8; i++) mood(6 + i, sleep: 7 + (i % 3) * 0.5, stress: 3 + i % 2),
      ];
      final list = InsightEngine.compute(moods: moods, pains: const [], today: today);
      final aboutSleepStress = [
        for (final i in list)
          if (i.pair.containsAll({WellMetric.sleep, WellMetric.stress})) i,
      ];
      expect(aboutSleepStress, hasLength(1));
      expect(aboutSleepStress.single, isA<SplitInsight>());
    });
  });

  test('ranked by strength, capped and one per pair', () {
    final moods = [
      for (var i = 0; i < 30; i++)
        mood(
          i,
          sleep: i.isEven ? 5 : 8,
          stress: i.isEven ? 8 : 3,
          anxiety: i.isEven ? 7 : 3,
          mood: i.isEven ? 2 : 4,
          energy: i.isEven ? 3 : 7,
          cups: i % 3 == 0 ? 4 : 1,
        ),
    ];
    final pains = [for (var i = 0; i < 30; i++) pain(i, i.isEven ? 6 : 2)];
    final list = InsightEngine.compute(moods: moods, pains: pains, today: today, max: 4);
    expect(list, hasLength(4));
    for (var i = 1; i < list.length; i++) {
      expect(list[i - 1].strength, greaterThanOrEqualTo(list[i].strength));
    }
    final keys = {for (final i in list) (i.pair.map((m) => m.index).toList()..sort()).join()};
    expect(keys, hasLength(list.length));
  });

  test('readiness counts logged days in the window', () {
    final r = InsightEngine.readiness(
      moods: [mood(0, mood: 3), mood(0, mood: 4), mood(2, mood: 3)],
      pains: [pain(5, 2), pain(200, 5)],
      today: today,
    );
    expect(r.daysLogged, 3);
    expect(r.daysNeeded, InsightEngine.minTotalDays);
    expect(r.progress, closeTo(0.3, 1e-9));
  });
}
