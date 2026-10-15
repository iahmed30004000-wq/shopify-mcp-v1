// «خطة اليوم» (Part 14): what the plan decides every morning, and what it
// refuses to do – at the boundaries (nothing memorised, one page, the whole
// mushaf), after 1, 7 and 60 days away, with a verse he marked «مش عليّ»,
// and with no speech model on the phone.
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/quran/ayah.dart';
import 'package:madar/features/hifz/hifz_memorisation.dart';
import 'package:madar/features/tasmee/tasmee.dart';

import 'hifz_plan_fixtures.dart';

void main() {
  final shape = testShape();
  final today = DateTime(2026, 10, 15); // a Thursday
  const juzAmma = AyahRange(AyahRef(78, 1), AyahRef(114, 6));
  const kahfPage = AyahRange(AyahRef(18, 1), AyahRef(18, 4)); // page 293's start

  HifzDailyPlan planOf({
    List<AyahRange> memorised = const [],
    List<TasmeeSession> log = const [],
    HifzPlanSettings settings = const HifzPlanSettings(),
    HifzMarks marks = HifzMarks.empty,
    Set<DateTime> activeDays = const {},
    DateTime? day,
    List<HifzMethodState>? methods,
  }) => HifzPlanner.planFor(
    today: day ?? today,
    shape: shape,
    memorised: memorised,
    strengths: HifzStrengths.of(log, today: day ?? today, marks: marks),
    settings: settings,
    methods: methods ?? methodsWithoutRecogniser(),
    activeDays: activeDays,
  );

  group('the boundaries', () {
    test('nothing memorised: the new portion only, and it says why', () {
      final plan = planOf(settings: const HifzPlanSettings(newFrom: AyahRef(78, 1), newAyatPerDay: 5));
      expect(plan.has(HifzPlanNote.nothingMemorised), isTrue);
      expect(plan.near, isEmpty);
      expect(plan.far, isEmpty);
      expect(plan.fresh, isNotNull);
      expect(plan.fresh!.range, const AyahRange(AyahRef(78, 1), AyahRef(78, 5)));
      expect(plan.fresh!.track, HifzTrack.fresh);
      expect(plan.memorisedAyat, 0);
    });

    test('nothing memorised and no cursor: an empty day that explains itself', () {
      final plan = planOf();
      expect(plan.isEmpty, isTrue);
      expect(plan.has(HifzPlanNote.noNewPortion), isTrue);
      expect(plan.has(HifzPlanNote.nothingMemorised), isTrue);
      expect(plan.totalAyat, 0);
    });

    test('one page memorised: it all fits in one day and the rotation is one day long', () {
      final plan = planOf(memorised: const [kahfPage]);
      expect(plan.memorisedAyat, 4);
      expect(plan.cycleDays, 1);
      expect(plan.totalAyat, 4);
      expect(planAyat(shape, plan).toSet().length, 4);
      expect(plan.backlog.droppedAyat, 0);
    });

    test('the whole mushaf memorised: the day still obeys the cap', () {
      final plan = planOf(
        memorised: const [AyahRange(AyahRef(1, 1), AyahRef(114, 6))],
        settings: const HifzPlanSettings(newFrom: null),
      );
      expect(plan.memorisedAyat, 6236);
      expect(plan.totalAyat, lessThanOrEqualTo(80));
      expect(plan.near.isNotEmpty || plan.far.isNotEmpty, isTrue);
      expect(plan.cycleDays, greaterThan(100), reason: 'a full turn over 6236 ayat takes months at 40 a day');
    });
  });

  group('the three tracks', () {
    test('no verse is ever scheduled twice in one day', () {
      final log = [cleanSessionOf(shape, const AyahRange(AyahRef(78, 1), AyahRef(78, 20)), DateTime(2026, 10, 14))];
      final plan = planOf(
        memorised: const [juzAmma],
        log: log,
        settings: const HifzPlanSettings(newFrom: AyahRef(78, 1), newAyatPerDay: 5),
      );
      final ayat = planAyat(shape, plan);
      expect(ayat.length, ayat.toSet().length, reason: 'the three tracks never overlap');
    });

    test('the near track holds the last seven days, the untested and whatever went weak', () {
      final log = [
        // recited yesterday, cleanly: near because it is recent
        cleanSessionOf(shape, const AyahRange(AyahRef(78, 1), AyahRef(78, 3)), DateTime(2026, 10, 14)),
        // recited badly a month ago: near because it is weak
        sessionOf(
          at: DateTime(2026, 9, 10),
          ayat: {const AyahRef(99, 1): counts(words: 10, wrong: 8)},
          id: 'weak',
        ),
        // six clean attempts in a row, the last ten days ago: strong enough
        // that it is not due – it waits for the far rotation.
        for (var d = 10; d <= 30; d += 4)
          cleanSessionOf(shape, const AyahRange(AyahRef(100, 1), AyahRef(100, 1)), DateTime(2026, 10, 15 - d)),
      ];
      final plan = planOf(
        memorised: const [juzAmma],
        log: log,
        settings: const HifzPlanSettings(nearCapAyat: 200, dailyCapAyat: 300),
      );
      final near = [for (final p in plan.near) ...Mushaf.ayatIn(shape, p.range)];
      expect(near, contains(const AyahRef(78, 1)));
      expect(near, contains(const AyahRef(99, 1)), reason: 'weak comes back however old it is');
      expect(near, contains(const AyahRef(78, 21)), reason: 'never tested belongs in the near track');
      expect(near.length, 200, reason: 'and the near cap is what stops it swallowing the whole juz');
      expect(near, isNot(contains(const AyahRef(100, 1))), reason: 'strong and not recent: it waits for its turn');
    });

    test('the far rotation covers everything over its cycle, and never more than the cap a day', () {
      const settings = HifzPlanSettings(nearCapAyat: 30, farCapAyat: 100, dailyCapAyat: 200);
      final seen = <String>{};
      var cycle = 0;
      for (var d = 0; d < 10; d++) {
        final day = DateTime(2026, 10, 15 + d);
        final plan = planOf(memorised: const [juzAmma], settings: settings, day: day);
        cycle = plan.cycleDays;
        expect(plan.far.fold<int>(0, (n, p) => n + p.ayahCount), lessThanOrEqualTo(100));
        for (final ref in planAyat(shape, plan)) {
          seen.add(ref.toString());
        }
        if (d + 1 >= cycle) break;
      }
      final all = Mushaf.ayatIn(shape, juzAmma).map((r) => r.toString()).toSet();
      expect(cycle, greaterThan(1));
      expect(seen.length, all.length, reason: 'a full turn of the cycle visits every memorised ayah');
      expect(seen.difference(all), isEmpty);
    });

    test('the same data and the same day give exactly the same plan', () {
      final log = [cleanSessionOf(shape, const AyahRange(AyahRef(78, 1), AyahRef(78, 10)), DateTime(2026, 10, 13))];
      final a = planOf(
        memorised: const [juzAmma],
        log: log,
        settings: const HifzPlanSettings(newFrom: AyahRef(90, 1)),
      );
      final b = planOf(
        memorised: const [juzAmma],
        log: log,
        settings: const HifzPlanSettings(newFrom: AyahRef(90, 1)),
      );
      expect(a.toString(), b.toString());
      expect([for (final p in a.portions) '${p.track}${p.range}${p.method}${p.stage}${p.seed}'], [
        for (final p in b.portions) '${p.track}${p.range}${p.method}${p.stage}${p.seed}',
      ]);
      final tomorrow = planOf(
        memorised: const [juzAmma],
        log: log,
        settings: const HifzPlanSettings(newFrom: AyahRef(90, 1)),
        day: DateTime(2026, 10, 16),
      );
      expect(tomorrow.far.first.range, isNot(a.far.first.range), reason: 'the rotation moves on with the day');
    });
  });

  group('the cap and what it says was dropped', () {
    final away = DateTime(2026, 10, 15);

    HifzDailyPlan afterDaysAway(int days) => planOf(
      memorised: const [juzAmma],
      activeDays: {DateTime(2026, 10, 15 - (days + 1))},
      day: away,
    );

    test('one day away: nothing is dropped and nothing piles up', () {
      final plan = afterDaysAway(1);
      expect(plan.backlog.missedDays, 1);
      expect(plan.totalAyat, lessThanOrEqualTo(80));
      expect(plan.backlog.dropped.isEmpty || plan.backlog.droppedAyat > 0, isTrue);
    });

    test('seven days away: the day is still one day, and he is told what went back', () {
      final plan = afterDaysAway(7);
      expect(plan.backlog.missedDays, 7);
      expect(plan.totalAyat, lessThanOrEqualTo(80));
      expect(plan.has(HifzPlanNote.backlogDropped), isTrue);
      expect(plan.backlog.reasons, contains(HifzDropReason.missedDays));
      expect(plan.backlog.droppedAyat, greaterThan(0));
      expect(plan.backlog.dropped, isNotEmpty, reason: 'the stretches are named, not swallowed');
      expect(plan.backlog.wouldHaveBeenAyat, greaterThan(plan.backlog.todayAyat));
    });

    test('sixty days away: the same one day, with the whole rotation named as back in the queue', () {
      final plan = afterDaysAway(60);
      expect(plan.backlog.missedDays, 60);
      expect(plan.totalAyat, lessThanOrEqualTo(80));
      expect(plan.backlog.droppedAyat, greaterThan(plan.totalAyat));
      final dropped = {
        for (final r in plan.backlog.dropped) ...Mushaf.ayatIn(shape, r).map((a) => a.toString()),
      };
      final todayAyat = planAyat(shape, plan).map((a) => a.toString()).toSet();
      expect(dropped.intersection(todayAyat), isEmpty, reason: 'nothing is both done today and dropped');
    });

    test('a tight cap trims the day and records why', () {
      final plan = planOf(
        memorised: const [juzAmma],
        settings: const HifzPlanSettings(dailyCapAyat: 12, nearCapAyat: 30, farCapAyat: 40),
      );
      expect(plan.totalAyat, lessThanOrEqualTo(12));
      expect(plan.backlog.reasons, contains(HifzDropReason.dailyCap));
      expect(plan.backlog.droppedAyat, greaterThan(0));
    });

    test('his first day: no history, no backlog, and the plan says so', () {
      final plan = planOf(
        memorised: const [],
        settings: const HifzPlanSettings(newFrom: AyahRef(78, 1)),
      );
      expect(plan.has(HifzPlanNote.firstDay), isTrue);
      expect(plan.backlog.missedDays, 0);
      expect(plan.backlog.droppedAyat, 0);
      expect(plan.fresh, isNotNull);
    });
  });

  group('his own decisions and this phone', () {
    test('a verse marked «مش عليّ» never turns up anywhere in the plan', () {
      final marks = HifzMarks.of([
        HifzMark(
          id: 'm',
          kind: HifzMarkKind.skipReview,
          range: const AyahRange(AyahRef(78, 1), AyahRef(78, 40)),
          createdAt: today,
        ),
      ]);
      final plan = planOf(memorised: const [juzAmma], marks: marks, settings: const HifzPlanSettings(nearCapAyat: 600, farCapAyat: 600, dailyCapAyat: 2000));
      final ayat = planAyat(shape, plan).map((a) => a.toString()).toSet();
      for (final ref in Mushaf.ayatIn(shape, const AyahRange(AyahRef(78, 1), AyahRef(78, 40)))) {
        expect(ayat, isNot(contains(ref.toString())));
      }
      expect(plan.memorisedAyat, lessThan(Mushaf.count(shape, juzAmma)));
    });

    test('everything marked «مش عليّ»: the plan says that instead of showing an empty day', () {
      final marks = HifzMarks.of([
        HifzMark(
          id: 'm',
          kind: HifzMarkKind.skipReview,
          range: kahfPage,
          createdAt: today,
        ),
      ]);
      final plan = planOf(memorised: const [kahfPage], marks: marks);
      expect(plan.has(HifzPlanNote.everythingSkipped), isTrue);
      expect(plan.has(HifzPlanNote.nothingMemorised), isFalse);
    });

    test('with no speech model, «سمّع» is never scheduled and the written modes take over', () {
      final plan = planOf(memorised: const [juzAmma], settings: const HifzPlanSettings(newFrom: AyahRef(78, 1)));
      expect(plan.has(HifzPlanNote.recitingUnavailable), isTrue);
      expect([for (final p in plan.portions) p.method], isNot(contains(HifzMethod.reciting)));
    });

    test('with a working model, a firm portion is given back to «سمّع»', () {
      final log = [
        for (var d = 1; d <= 4; d++)
          cleanSessionOf(shape, const AyahRange(AyahRef(78, 1), AyahRef(78, 3)), DateTime(2026, 10, 15 - d), ),
      ];
      final plan = planOf(
        memorised: const [AyahRange(AyahRef(78, 1), AyahRef(78, 3))],
        log: log,
        methods: methodsWithRecogniser(),
      );
      expect(plan.has(HifzPlanNote.recitingUnavailable), isFalse);
      expect(plan.portions.first.band, anyOf(StrengthBand.firm, StrengthBand.solid));
      expect(plan.portions.first.method, HifzMethod.reciting);
      expect(plan.portions.first.stage, HidingStage.hidden);
    });

    test('a portion that crosses a surah and a juz keeps going, and says so', () {
      final plan = planOf(
        memorised: const [AyahRange(AyahRef(2, 140), AyahRef(2, 145))],
        settings: const HifzPlanSettings(newFrom: AyahRef(78, 1), newAyatPerDay: 45),
      );
      expect(plan.fresh!.crossesSurah, isTrue, reason: 'an-Naba has forty ayat, so the portion runs into an-Naziat');
      expect(Mushaf.crossesJuz(shape, plan.near.first.range), isTrue, reason: '2:141 ends juz 1');
    });
  });
}
