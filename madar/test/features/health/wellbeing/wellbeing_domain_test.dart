import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/notifications/notification_models.dart';
import 'package:madar/features/health/wellbeing/wellbeing.dart';

void main() {
  final today = DateTime(2026, 9, 29);

  group('BodyPoint', () {
    test('round-trips JSON (rounded to 3 decimals)', () {
      const p = BodyPoint(0.42371, 0.31, BodySide.back);
      final j = p.toJson();
      expect(j, {'x': 0.424, 'y': 0.31, 'side': 'back'});
      expect(BodyPoint.fromJson(j), const BodyPoint(0.424, 0.31, BodySide.back));
    });

    test('tolerant reader', () {
      expect(BodyPoint.fromJson({'x': '0.5', 'y': 0.2}), const BodyPoint(0.5, 0.2, BodySide.front));
      expect(BodyPoint.fromJson({'x': 1.7, 'y': -1}), const BodyPoint(1, 0, BodySide.front));
      expect(BodyPoint.fromJson('nope'), isNull);
      expect(BodyPoint.fromJson({'x': 0.5}), isNull);
      expect(
        BodyPoint.listFrom([
          {'x': 0.1, 'y': 0.2, 'side': 'front'},
          null,
          3,
        ]),
        hasLength(1),
      );
    });

    test('distance counts the 1×2 box', () {
      expect(
        const BodyPoint(0.5, 0.5, BodySide.front).distanceTo(const BodyPoint(0.5, 0.6, BodySide.front)),
        closeTo(0.2, 1e-9),
      );
    });
  });

  group('BodyFigure.regionAt', () {
    test('named areas from head to feet', () {
      expect(BodyFigure.regionAt(0.5, 0.06, BodySide.front), BodyRegion.head);
      expect(BodyFigure.regionAt(0.5, 0.145, BodySide.front), BodyRegion.neck);
      expect(BodyFigure.regionAt(0.33, 0.19, BodySide.front), BodyRegion.shoulders);
      expect(BodyFigure.regionAt(0.5, 0.27, BodySide.front), BodyRegion.chest);
      expect(BodyFigure.regionAt(0.5, 0.27, BodySide.back), BodyRegion.upperBack);
      expect(BodyFigure.regionAt(0.5, 0.4, BodySide.front), BodyRegion.abdomen);
      expect(BodyFigure.regionAt(0.5, 0.42, BodySide.back), BodyRegion.lowerBack);
      expect(BodyFigure.regionAt(0.2, 0.35, BodySide.front), BodyRegion.arms);
      expect(BodyFigure.regionAt(0.16, 0.53, BodySide.front), BodyRegion.hands);
      expect(BodyFigure.regionAt(0.45, 0.52, BodySide.front), BodyRegion.hips);
      expect(BodyFigure.regionAt(0.4, 0.6, BodySide.front), BodyRegion.legs);
      expect(BodyFigure.regionAt(0.4, 0.71, BodySide.front), BodyRegion.knees);
      expect(BodyFigure.regionAt(0.39, 0.95, BodySide.front), BodyRegion.feet);
    });

    test('outside the figure', () {
      expect(BodyFigure.regionAt(0.05, 0.05, BodySide.front), isNull);
      expect(BodyFigure.regionAt(-0.1, 0.5, BodySide.front), isNull);
      expect(BodyFigure.regionAt(0.95, 0.8, BodySide.front), isNull);
    });
  });

  test('the drawn silhouette keeps every part (no limb lost in the path union)', () {
    const inside = [
      (0.5, 0.06),
      (0.5, 0.14),
      (0.5, 0.3),
      (0.3, 0.19),
      (0.25, 0.28),
      (0.195, 0.42),
      (0.162, 0.525),
      (0.805, 0.42),
      (0.838, 0.525),
      (0.405, 0.6),
      (0.398, 0.82),
      (0.39, 0.945),
      (0.602, 0.82),
      (0.61, 0.945),
    ];
    for (final (x, y) in inside) {
      expect(BodyMapPainter.hits(x, y), isTrue, reason: '($x, $y)');
    }
    expect(BodyMapPainter.hits(0.05, 0.05), isFalse);
    expect(BodyMapPainter.hits(0.5, 0.8), isFalse);
    expect(BodyMapPainter.hits(0.3, 0.4), isFalse);
  });

  group('BodyHeat', () {
    test('merges nearby points per side and keeps the mean score', () {
      final spots = BodyHeat.cluster([
        (const BodyPoint(0.5, 0.3, BodySide.front), 4),
        (const BodyPoint(0.52, 0.31, BodySide.front), 8),
        (const BodyPoint(0.5, 0.3, BodySide.back), 2),
        (const BodyPoint(0.2, 0.8, BodySide.front), 5),
      ]);
      expect(spots, hasLength(3));
      expect(spots.first.count, 2);
      expect(spots.first.meanScore, 6);
      expect(spots.first.side, BodySide.front);
      expect(spots.where((s) => s.side == BodySide.back), hasLength(1));
    });
  });

  group('WellbeingStats.pain', () {
    test('daily max and mean, trigger and location frequency, heat', () {
      final s = WellbeingStats.pain(
        [
          PainSample(at: DateTime(2026, 9, 29, 9), score: 3, triggers: const ['Sitting'], locations: const ['Neck']),
          PainSample(
            at: DateTime(2026, 9, 29, 18),
            score: 7,
            triggers: const ['Sitting', 'Stress', 'Sitting'],
            points: const [BodyPoint(0.5, 0.15, BodySide.back)],
          ),
          PainSample(at: DateTime(2026, 9, 20, 18), score: 5, triggers: const ['Stress']),
          PainSample(at: DateTime(2026, 8, 1), score: 9, triggers: const ['Old']),
        ],
        today: today,
        days: 14,
      );
      expect(s.entries, 3);
      expect(s.days, hasLength(2));
      expect(s.days.last.max, 7);
      expect(s.days.last.mean, 5);
      expect(s.days.last.count, 2);
      expect(s.triggers, [('Sitting', 2), ('Stress', 2)]);
      expect(s.locations, [('Neck', 1)]);
      expect(s.heat, hasLength(1));
      expect(s.peak, 7);
      expect(s.meanOfDailyMax, 6);
      expect(s.from, DateTime(2026, 9, 16));
    });

    test('empty range', () {
      final s = WellbeingStats.pain(const [], today: today, days: 30);
      expect(s.isEmpty, isTrue);
      expect(s.peak, isNull);
      expect(s.meanOfDailyMax, isNull);
    });
  });

  group('WellbeingStats.series', () {
    test('one value per logged day, oldest first', () {
      final series = WellbeingStats.series(
        [
          MoodSample(at: DateTime(2026, 9, 28, 8), stress: 6),
          MoodSample(at: DateTime(2026, 9, 28, 20), stress: 2),
          MoodSample(at: DateTime(2026, 9, 26, 20), stress: 5),
          MoodSample(at: DateTime(2026, 9, 27, 20), mood: 3),
        ],
        WellMetric.stress,
        today: today,
        days: 7,
      );
      expect(series, [MetricPoint(DateTime(2026, 9, 26), 5), MetricPoint(DateTime(2026, 9, 28), 4)]);
      expect(WellbeingStats.mean(series), 4.5);
    });

    test('pain series uses the day maximum', () {
      final series = WellbeingStats.series(
        const [],
        WellMetric.pain,
        today: today,
        days: 7,
        pains: [
          PainSample(at: DateTime(2026, 9, 29, 8), score: 2),
          PainSample(at: DateTime(2026, 9, 29, 9), score: 6),
        ],
      );
      expect(series.single.value, 6);
    });

    test('factor counts', () {
      final f = WellbeingStats.factorCounts(
        [
          MoodSample(at: DateTime(2026, 9, 28), factors: const ['Work', 'Sleep']),
          MoodSample(at: DateTime(2026, 9, 27), factors: const ['Work']),
        ],
        today: today,
        days: 7,
      );
      expect(f, [('Work', 2), ('Sleep', 1)]);
    });
  });

  group('SupportRule (mood ≤ 2 on 3 of the last 5 check-ins, 14 days)', () {
    final now = DateTime(2026, 9, 29, 20);
    List<(DateTime, int?)> moods(List<int?> newestFirst) => [
      for (var i = 0; i < newestFirst.length; i++) (now.subtract(Duration(hours: 12 * i + 1)), newestFirst[i]),
    ];

    test('three low of the last five shows', () {
      final s = SupportRule.evaluate(moods([2, 4, 1, 3, 2, 5, 5]), now: now);
      expect(s.show, isTrue);
      expect(s.lowCount, 3);
      expect(s.considered, 5);
    });

    test('two low of five does not', () {
      expect(SupportRule.evaluate(moods([2, 4, 1, 3, 4, 1, 1]), now: now).show, isFalse);
    });

    test('check-ins without a mood are skipped', () {
      final s = SupportRule.evaluate(moods([null, 1, null, 2, 1, 5]), now: now);
      expect(s.show, isTrue);
      expect(s.considered, 4);
    });

    test('only the last 14 days count', () {
      final old = [for (var i = 0; i < 5; i++) (now.subtract(Duration(days: 15 + i)), 1)];
      expect(SupportRule.evaluate([...old, (now, 4)], now: now).show, isFalse);
    });

    test('a dismissal hides it for a week', () {
      final until = SupportRule.dismissUntil(now.subtract(const Duration(days: 2)));
      final s = SupportRule.evaluate(moods([1, 1, 1]), now: now, dismissedUntil: until);
      expect(s.triggered, isTrue);
      expect(s.snoozed, isTrue);
      expect(s.show, isFalse);
      final later = SupportRule.evaluate(
        moods([1, 1, 1]),
        now: now,
        dismissedUntil: now.subtract(const Duration(minutes: 1)),
      );
      expect(later.show, isTrue);
    });

    test('fewer than three check-ins never trigger', () {
      expect(SupportRule.evaluate(moods([1, 1]), now: now).show, isFalse);
    });
  });

  group('HabitStreaks', () {
    Set<String> days(List<int> ago) => {for (final a in ago) WbDays.key(WbDays.add(today, -a))};

    test('streak through today', () {
      final p = HabitStreaks.of(days([0, 1, 2, 4]), today: today);
      expect(p.doneToday, isTrue);
      expect(p.streak, 3);
      expect(p.best, 3);
      expect(p.last7, [false, false, true, false, true, true, true]);
      expect(p.doneIn30, 4);
    });

    test('an open today keeps yesterday\'s streak alive', () {
      final p = HabitStreaks.of(days([1, 2]), today: today);
      expect(p.doneToday, isFalse);
      expect(p.streak, 2);
    });

    test('best run across a month boundary', () {
      final p = HabitStreaks.of({'2026-08-30', '2026-08-31', '2026-09-01', '2026-09-02', '2026-09-10'}, today: today);
      expect(p.best, 4);
      expect(p.streak, 0);
    });

    test('ignores malformed keys and future days', () {
      final p = HabitStreaks.of({'nope', WbDays.key(WbDays.add(today, 3)), WbDays.key(today)}, today: today);
      expect(p.best, 1);
      expect(p.streak, 1);
    });
  });

  group('WorryWindow', () {
    const s = WorryWindowSettings(enabled: true, minuteOfDay: 18 * 60 + 30, durationMinutes: 15);

    test('before, open and after', () {
      final before = WorryWindow.statusAt(s, DateTime(2026, 9, 29, 17));
      expect(before.phase, WorryWindowPhase.before);
      expect(before.remaining(DateTime(2026, 9, 29, 17)), const Duration(minutes: 90));
      final open = WorryWindow.statusAt(s, DateTime(2026, 9, 29, 18, 40));
      expect(open.isOpen, isTrue);
      expect(open.remaining(DateTime(2026, 9, 29, 18, 40)), const Duration(minutes: 5));
      final after = WorryWindow.statusAt(s, DateTime(2026, 9, 29, 19));
      expect(after.phase, WorryWindowPhase.after);
      expect(after.start, DateTime(2026, 9, 30, 18, 30));
    });

    test('off unless enabled', () {
      expect(WorryWindow.statusAt(const WorryWindowSettings(), DateTime(2026, 9, 29)).phase, WorryWindowPhase.off);
      expect(WorryWindow.upcoming(const WorryWindowSettings(), DateTime(2026, 9, 29)), isEmpty);
      expect(WorryWindow.upcoming(s.copyWith(remind: false), DateTime(2026, 9, 29)), isEmpty);
    });

    test('plans the next seven starts', () {
      final starts = WorryWindow.upcoming(s, DateTime(2026, 9, 29, 19));
      expect(starts, hasLength(7));
      expect(starts.first, DateTime(2026, 9, 30, 18, 30));
      expect(starts.last, DateTime(2026, 10, 6, 18, 30));
    });

    test('ids stay inside the health block, clear of the record\'s', () {
      expect(WorryReminderIds.first, 150900);
      expect(WorryReminderIds.last, 150906);
      expect(NotificationNamespaces.health.contains(WorryReminderIds.last), isTrue);
      expect(WorryReminderIds.owns(150399), isFalse);
      expect(() => WorryReminderIds.of(7), throwsRangeError);
    });

    test('settings JSON and HH:mm', () {
      expect(WorryWindowSettings.fromJson(s.toJson()), s);
      expect(s.hhmm, '18:30');
      expect(WorryWindowSettings.parseHhmm('7:05'), 425);
      expect(WorryWindowSettings.parseHhmm('24:00'), isNull);
      expect(WorryWindowSettings.fromJson('junk'), const WorryWindowSettings());
    });

    test('reminder planner', () {
      final notices = WorryReminderPlanner.plan(
        settings: s,
        now: DateTime(2026, 9, 29, 12),
        title: 'T',
        body: (d) => 'B${d.day}',
      );
      expect(notices, hasLength(7));
      expect(notices.first.id, 150900);
      expect(notices.first.at, DateTime(2026, 9, 29, 18, 30));
      expect(notices.first.body, 'B29');
    });
  });

  group('BreathingClock', () {
    const p = BreathingPattern.fourSevenEight;

    test('4-7-8 phases and expansion', () {
      expect(p.cycleSeconds, 19);
      final mid = BreathingClock.at(p, const Duration(seconds: 2));
      expect(mid.phase, BreathPhase.inhale);
      expect(mid.phaseProgress, closeTo(0.5, 1e-9));
      expect(mid.expansion, closeTo(0.5, 1e-9));
      expect(mid.secondsLeft, 2);
      final hold = BreathingClock.at(p, const Duration(seconds: 5));
      expect(hold.phase, BreathPhase.holdIn);
      expect(hold.expansion, 1);
      final out = BreathingClock.at(p, const Duration(seconds: 15));
      expect(out.phase, BreathPhase.exhale);
      expect(out.expansion, closeTo(0.5, 1e-9));
      final next = BreathingClock.at(p, const Duration(seconds: 20));
      expect(next.cycle, 1);
      expect(next.phase, BreathPhase.inhale);
    });

    test('box breathing holds empty too', () {
      final s = BreathingClock.at(BreathingPattern.box, const Duration(seconds: 13));
      expect(s.phase, BreathPhase.holdOut);
      expect(s.expansion, 0);
    });

    test('finishes after the chosen cycles', () {
      final s = BreathingClock.at(p, const Duration(seconds: 38), cycles: 2);
      expect(s.finished, isTrue);
      expect(BreathingClock.at(p, const Duration(seconds: 37), cycles: 2).finished, isFalse);
    });

    test('phase changes are detected', () {
      final a = BreathingClock.at(p, const Duration(milliseconds: 3900));
      final b = BreathingClock.at(p, const Duration(milliseconds: 4100));
      expect(a.samePhaseAs(b), isFalse);
      expect(a.samePhaseAs(BreathingClock.at(p, const Duration(milliseconds: 3000))), isTrue);
    });

    test('byId falls back to 4-7-8', () {
      expect(BreathingPattern.byId('box'), BreathingPattern.box);
      expect(BreathingPattern.byId('?'), BreathingPattern.fourSevenEight);
    });
  });

  group('WellbeingSettings', () {
    test('defaults: Jordan 911, nothing dismissed, window off', () {
      const s = WellbeingSettings();
      expect(s.supportNumber, '911');
      expect(s.dialable, '911');
      expect(s.supportDismissedUntil, isNull);
      expect(s.worry.enabled, isFalse);
    });

    test('JSON round trip', () {
      final s = WellbeingSettings(
        supportNumber: '+44 999',
        supportDismissedUntil: DateTime(2026, 10, 6, 9),
        worry: const WorryWindowSettings(enabled: true, minuteOfDay: 600),
        breathingPattern: 'box',
        breathingCycles: 6,
        breathingSound: false,
      );
      expect(WellbeingSettings.fromJson(s.toJson()), s);
    });

    test('dialable numbers', () {
      expect(WellbeingSettings.normalizeNumber('٩١١'), '911');
      expect(WellbeingSettings.normalizeNumber('+962 6 123-4567'), '+96261234567');
      expect(WellbeingSettings.normalizeNumber('call me'), isNull);
      expect(WellbeingSettings.normalizeNumber('1'), isNull);
      expect(WellbeingSettings.fromJson({'supportNumber': 'x'}).supportNumber, '911');
    });

    test('clearing a dismissal', () {
      final s = WellbeingSettings(supportDismissedUntil: DateTime(2026));
      expect(s.copyWith(clearDismissal: true).supportDismissedUntil, isNull);
    });
  });

  group('drafts', () {
    test('pain draft clamps, trims and dedupes', () {
      final d = PainDraft(at: today, score: 14, locations: const [' Neck ', 'Neck', ''], notes: '  ').normalized();
      expect(d.score, 10);
      expect(d.locations, ['Neck']);
      expect(d.notes, isNull);
    });

    test('mood draft rounds sleep to half hours and knows when empty', () {
      final d = MoodDraft(at: today, sleepHours: 6.8, mood: 9, caffeineCups: 40).normalized();
      expect(d.sleepHours, 7);
      expect(d.mood, 5);
      expect(d.caffeineCups, MoodDraft.maxCups);
      expect(MoodDraft(at: today).isEmpty, isTrue);
      expect(MoodDraft(at: today, notes: 'x').isEmpty, isFalse);
    });
  });

  test('WbDays helpers', () {
    expect(WbDays.key(DateTime(2026, 3, 5)), '2026-03-05');
    expect(WbDays.parse('2026-03-05'), DateTime(2026, 3, 5));
    expect(WbDays.parse('2026-3-5'), isNull);
    expect(WbDays.between(DateTime(2026, 3, 28), DateTime(2026, 4, 2)), 5);
    expect(WbDays.window(today, 3), [DateTime(2026, 9, 27), DateTime(2026, 9, 28), today]);
  });
}
