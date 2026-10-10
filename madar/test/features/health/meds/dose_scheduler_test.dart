import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/health/meds/domain/course_schedule.dart';
import 'package:madar/features/health/meds/domain/dose_scheduler.dart';
import 'package:madar/features/health/meds/domain/med_models.dart';
import 'package:madar/features/health/meds/domain/meds_settings.dart';

MedSpec med(
  String id, {
  List<String> times = const [],
  List<MedSlot>? slots,
  TakenWith takenWith = TakenWith.anytime,
  List<TitrationStep> titration = const [],
  String? dose,
  bool active = true,
  int order = 0,
  String? courseId,
}) => MedSpec(
  id: id,
  name: id.toUpperCase(),
  dose: dose,
  slots: slots ?? [for (final t in times) MedSlot(ClockHm.tryParse(t)!)],
  takenWith: takenWith,
  titration: titration,
  active: active,
  sortOrder: order,
  courseId: courseId,
);

RuleSpec sep(String id, String a, String b, int minutes) =>
    RuleSpec(id: id, kind: MedRuleKind.separate, medAId: a, medBId: b, minutes: minutes);

RuleSpec food(String id, String a, MedRuleKind kind, [int minutes = 0]) =>
    RuleSpec(id: id, kind: kind, medAId: a, minutes: minutes);

DateTime hm(DateTime day, int h, int m) => DateTime(day.year, day.month, day.day, h, m);

PlannedDose doseOf(DayPlan plan, String medId, {int index = 0}) =>
    plan.doses.where((d) => d.medId == medId).elementAt(index);

/// A zone at UTC+2 that springs forward to UTC+3 at 02:00 local on
/// [springDay] and falls back to UTC+2 at 03:00 local on [fallDay] (both
/// transitions in one fake zone, far apart).
class FakeDstClock implements WallClock {
  FakeDstClock({required this.springDay, required this.fallDay});

  final DateTime springDay;
  final DateTime fallDay;

  /// Instants of the transitions.
  DateTime get springAt => DateTime.utc(springDay.year, springDay.month, springDay.day); // 02:00 (+2) = 00:00Z
  DateTime get fallAt => DateTime.utc(fallDay.year, fallDay.month, fallDay.day); // 03:00 (+3) = 00:00Z

  int offsetAt(DateTime instant) => !instant.isBefore(springAt) && instant.isBefore(fallAt) ? 3 : 2;

  @override
  DateTime at(DateTime day, int minuteOfDay) {
    final naive = DateTime.utc(day.year, day.month, day.day).add(Duration(minutes: minuteOfDay));
    // First occurrence: try the earlier-offset reading first (+3 before +2
    // in a fall-back overlap, since +3 gives the earlier instant).
    for (final off in [3, 2]) {
      final instant = naive.subtract(Duration(hours: off));
      if (offsetAt(instant) == off) return instant;
    }
    // In the spring-forward gap: resolve forward by the gap.
    return naive.subtract(const Duration(hours: 2));
  }
}

void main() {
  final day = DateTime(2026, 9, 29);

  group('expansion', () {
    test('daily times, inactive and as-needed medications', () {
      final s = DoseScheduler(
        meds: [
          med('a', times: ['21:00', '08:00']),
          med('b', times: ['09:00'], active: false),
          med('c'),
        ],
      );
      final doses = s.expandDay(day);
      expect(doses.map((d) => (d.medId, d.at)), [('a', hm(day, 8, 0)), ('a', hm(day, 21, 0))]);
      expect(doses.first.slot, hm(day, 8, 0));
      expect(s.slotsOf(s.meds.last), isEmpty);
      expect(s.meds.last.asNeeded, isTrue);
    });

    test('a time-less medication follows its taken-with meal (empty stomach before breakfast)', () {
      final s = DoseScheduler(
        meds: [
          med('a', takenWith: TakenWith.breakfast),
          med('b', takenWith: TakenWith.emptyStomach),
          med('c', takenWith: TakenWith.bedtime),
        ],
        settings: const MedsSettings(
          meals: {
            MealSlot.breakfast: ClockHm(7, 15),
            MealSlot.lunch: ClockHm(14, 0),
            MealSlot.dinner: ClockHm(20, 0),
            MealSlot.bedtime: ClockHm(23, 30),
          },
        ),
      );
      final plan = s.planDay(day);
      expect(doseOf(plan, 'a').at, hm(day, 7, 15));
      expect(doseOf(plan, 'b').at, hm(day, 6, 45));
      expect(doseOf(plan, 'c').at, hm(day, 23, 30));
    });

    test('prayer anchors follow the day’s prayer time, the slot stays the stored time', () {
      final s = DoseScheduler(
        meds: [
          med('a', slots: [const MedSlot(ClockHm(4, 50), TimeAnchor(AnchorBase.fajr, 20))]),
          med('b', slots: [const MedSlot(ClockHm(19, 30), TimeAnchor(AnchorBase.dinner, -30))]),
        ],
        prayerTime: (d, p) => p == AnchorBase.fajr ? hm(d, 5, 10) : null,
      );
      final plan = s.planDay(day);
      expect(doseOf(plan, 'a').at, hm(day, 5, 30));
      expect(doseOf(plan, 'a').slot, hm(day, 4, 50));
      expect(doseOf(plan, 'b').at, hm(day, 19, 30));
      // Unknown prayer times fall back to the stored time.
      final noPrayers = DoseScheduler(meds: [s.meds.first]);
      expect(noPrayers.planDay(day).doses.single.at, hm(day, 4, 50));
    });

    test('titration: the latest step on or before the day, a stop step ends the doses', () {
      final m = med(
        'a',
        times: ['08:00'],
        dose: '2.5 mg',
        titration: TitrationStep.parseList([
          {'from': '2026-10-08', 'dose': '10 mg', 'doseAmount': 10},
          {'from': '2026-10-01', 'dose': '5 mg', 'doseAmount': 5},
          {'from': '2026-10-15', 'stop': true},
          {'from': 'garbage'},
        ]),
      );
      final s = DoseScheduler(meds: [m]);
      String? doseAt(DateTime d) => s.planDay(d).doses.singleOrNull?.dose;
      expect(doseAt(DateTime(2026, 9, 30)), '2.5 mg');
      expect(doseAt(DateTime(2026, 10, 1)), '5 mg');
      expect(doseAt(DateTime(2026, 10, 7)), '5 mg');
      expect(doseAt(DateTime(2026, 10, 8)), '10 mg');
      expect(s.planDay(DateTime(2026, 10, 8)).doses.single.source, DoseSource.titration);
      expect(s.planDay(DateTime(2026, 10, 15)).doses, isEmpty);
    });

    test('titration day boundary: a dose moved past midnight keeps its own day’s dose', () {
      final s = DoseScheduler(
        meds: [
          med('a', times: ['23:00']),
          med(
            'b',
            times: ['23:00'],
            dose: '5 mg',
            titration: [TitrationStep(from: DateTime(2026, 10, 1), dose: '10 mg')],
          ),
        ],
        rules: [sep('r', 'a', 'b', 90)],
      );
      final sep30 = s.planDay(DateTime(2026, 9, 30));
      final b = doseOf(sep30, 'b');
      expect(b.at, DateTime(2026, 10, 1, 0, 30));
      expect(b.day, DateTime(2026, 9, 30));
      expect(b.pastMidnight, isTrue);
      expect(b.dose, '5 mg');
      expect(doseOf(s.planDay(DateTime(2026, 10, 1)), 'b').dose, '10 mg');
    });
  });

  group('food rules', () {
    const settings = MedsSettings();

    test('before / after / with food pin the dose to its meal', () {
      final s = DoseScheduler(
        meds: [
          med('a', times: ['07:00'], takenWith: TakenWith.breakfast),
          med('b', times: ['13:00'], takenWith: TakenWith.lunch),
          med('c', times: ['19:00'], takenWith: TakenWith.dinner),
        ],
        rules: [
          food('r1', 'a', MedRuleKind.beforeFood, 30),
          food('r2', 'b', MedRuleKind.afterFood, 60),
          food('r3', 'c', MedRuleKind.withFood),
        ],
        settings: settings,
      );
      final plan = s.planDay(day);
      expect(doseOf(plan, 'a').at, hm(day, 7, 30));
      expect(doseOf(plan, 'a').pinned, isTrue);
      expect(doseOf(plan, 'a').meal, MealSlot.breakfast);
      expect(doseOf(plan, 'b').at, hm(day, 15, 0));
      expect(doseOf(plan, 'c').at, hm(day, 20, 0));
      expect(doseOf(plan, 'c').ruleIds, ['r3']);
      expect(plan.conflicts, isEmpty);
    });

    test('several daily doses spread over the nearest free meals', () {
      final s = DoseScheduler(
        meds: [
          med('a', times: ['08:30', '09:00', '19:00']),
        ],
        rules: [food('r', 'a', MedRuleKind.afterFood, 15)],
      );
      final plan = s.planDay(day);
      expect(plan.doses.map((d) => d.meal), [MealSlot.breakfast, MealSlot.lunch, MealSlot.dinner]);
      expect(plan.doses.map((d) => d.at), [hm(day, 8, 15), hm(day, 14, 15), hm(day, 20, 15)]);
    });

    test('more doses than meals: the extra dose keeps its time and is reported', () {
      final s = DoseScheduler(
        meds: [
          med('a', times: ['08:00', '12:00', '16:00', '22:00']),
        ],
        rules: [food('r', 'a', MedRuleKind.withFood)],
      );
      final plan = s.planDay(day);
      expect(plan.doses, hasLength(4));
      expect(plan.conflicts.single.kind, DoseConflictKind.noMeal);
      expect(plan.conflicts.single.a.slot, hm(day, 22, 0));
      expect(doseOf(plan, 'a', index: 3).at, hm(day, 22, 0));
    });

    test('a second, different food rule is reported and the first wins', () {
      final s = DoseScheduler(
        meds: [
          med('a', times: ['08:00']),
        ],
        rules: [food('r1', 'a', MedRuleKind.beforeFood, 30), food('r2', 'a', MedRuleKind.afterFood, 30)],
      );
      final plan = s.planDay(day);
      expect(plan.doses.single.at, hm(day, 7, 30));
      expect(plan.conflicts.single.kind, DoseConflictKind.ruleClash);
      expect(plan.conflicts.single.rule.id, 'r2');
    });
  });

  group('separation', () {
    test('ties: B yields to A', () {
      final s = DoseScheduler(
        meds: [
          med('a', times: ['08:00']),
          med('b', times: ['08:00']),
        ],
        rules: [sep('r', 'a', 'b', 120)],
      );
      final plan = s.planDay(day);
      expect(doseOf(plan, 'a').at, hm(day, 8, 0));
      expect(doseOf(plan, 'b').at, hm(day, 10, 0));
      expect(doseOf(plan, 'b').ruleIds, ['r']);
      expect(doseOf(plan, 'b').shift, const Duration(hours: 2));
      expect(plan.conflicts, isEmpty);
    });

    test('the later dose moves later, whichever medication it is', () {
      final s = DoseScheduler(
        meds: [
          med('a', times: ['09:00']),
          med('b', times: ['08:00']),
        ],
        rules: [sep('r', 'a', 'b', 120)],
      );
      final plan = s.planDay(day);
      expect(doseOf(plan, 'b').at, hm(day, 8, 0));
      expect(doseOf(plan, 'a').at, hm(day, 10, 0));
    });

    test('a chain of rules settles', () {
      final s = DoseScheduler(
        meds: [
          med('a', times: ['08:00']),
          med('b', times: ['08:00']),
          med('c', times: ['08:00']),
        ],
        rules: [sep('ab', 'a', 'b', 120), sep('bc', 'b', 'c', 60), sep('ac', 'a', 'c', 180)],
      );
      final plan = s.planDay(day);
      expect(doseOf(plan, 'a').at, hm(day, 8, 0));
      expect(doseOf(plan, 'b').at, hm(day, 10, 0));
      expect(doseOf(plan, 'c').at, hm(day, 11, 0));
      expect(plan.conflicts, isEmpty);
    });

    test('a longer chain settles with the least moving (C may stay before B)', () {
      final s = DoseScheduler(
        meds: [
          for (final id in ['a', 'b', 'c', 'd']) med(id, times: ['08:00']),
        ],
        rules: [sep('1', 'a', 'b', 60), sep('2', 'b', 'c', 60), sep('3', 'c', 'd', 60)],
      );
      final plan = s.planDay(day);
      // a–b pushes B to 09:00; C at 08:00 is already an hour before B; c–d
      // pushes D to 09:00. Every rule holds.
      expect([for (final id in ['a', 'b', 'c', 'd']) doseOf(plan, id).at.hour], [8, 9, 8, 9]);
      expect(plan.conflicts, isEmpty);
    });

    test('pinned doses cannot move: an unmet rule is a conflict and both doses stay', () {
      final s = DoseScheduler(
        meds: [
          med('a', times: ['07:00'], takenWith: TakenWith.emptyStomach),
          med('b', times: ['08:00'], takenWith: TakenWith.breakfast),
        ],
        rules: [
          food('fa', 'a', MedRuleKind.beforeFood, 30),
          food('fb', 'b', MedRuleKind.withFood),
          sep('r', 'a', 'b', 240),
        ],
      );
      final plan = s.planDay(day);
      expect(plan.doses, hasLength(2));
      expect(doseOf(plan, 'a').at, hm(day, 7, 30));
      expect(doseOf(plan, 'b').at, hm(day, 8, 0));
      final c = plan.conflicts.single;
      expect(c.kind, DoseConflictKind.separation);
      expect(c.requiredMinutes, 240);
      expect(c.actualMinutes, 30);
      expect(c.a.medId, 'a');
      expect(c.b!.medId, 'b');
    });

    test('the allowed shift is bounded; the earlier dose may move earlier instead', () {
      final s = DoseScheduler(
        meds: [
          med('a', times: ['08:00']),
          med('b', times: ['08:30']),
        ],
        rules: [sep('r', 'a', 'b', 150)],
        settings: const MedsSettings(maxShift: 90),
      );
      // 150 − 30 = 120 more minutes are needed, more than either dose may
      // move (90).
      final plan = s.planDay(day);
      expect(plan.conflicts.single.kind, DoseConflictKind.separation);
      expect(plan.doses, hasLength(2));

      final s2 = DoseScheduler(
        meds: [
          med('a', times: ['08:00']),
          med('b', times: ['08:30'], takenWith: TakenWith.breakfast),
        ],
        rules: [sep('r', 'a', 'b', 90), food('f', 'b', MedRuleKind.withFood)],
      );
      final plan2 = s2.planDay(day);
      // B is pinned at breakfast (08:00), level with A: B cannot yield, so
      // A moves earlier instead.
      expect(doseOf(plan2, 'b').at, hm(day, 8, 0));
      expect(doseOf(plan2, 'a').at, hm(day, 6, 30));
      expect(plan2.conflicts, isEmpty);
    });

    test('a shift never passes the medication’s own neighbouring dose', () {
      final s = DoseScheduler(
        meds: [
          med('a', times: ['08:00']),
          med('b', times: ['08:00', '09:30']),
        ],
        rules: [sep('r', 'a', 'b', 120)],
      );
      final plan = s.planDay(day);
      // B's 08:00 cannot move to 10:00, past its own 09:30 dose, so A moves
      // two hours earlier (within the default four-hour limit).
      expect(doseOf(plan, 'a').at, hm(day, 6, 0));
      expect(doseOf(plan, 'b').at, hm(day, 8, 0));
      expect(doseOf(plan, 'b', index: 1).at, hm(day, 9, 30));
      expect(plan.conflicts, isEmpty);
    });

    test('midnight wrap: yesterday’s late dose pushes today’s early one', () {
      final s = DoseScheduler(
        meds: [
          med('a', times: ['23:30']),
          med('b', times: ['00:30']),
        ],
        rules: [sep('r', 'a', 'b', 120)],
      );
      final today = DateTime(2026, 9, 30);
      final plan = s.planDay(today);
      expect(doseOf(plan, 'b').at, hm(today, 1, 30));
      // …and tonight's 23:30 dose of A is fine with tomorrow's (moved) B.
      expect(doseOf(plan, 'a').at, hm(today, 23, 30));
      expect(plan.conflicts, isEmpty);
    });

    test('midnight wrap: a dose pushed into tomorrow stays on its own day', () {
      final s = DoseScheduler(
        meds: [
          med('a', times: ['23:00']),
          med('b', times: ['23:00']),
        ],
        rules: [sep('r', 'a', 'b', 120)],
      );
      final plans = s.planDays(day, 2);
      final b = doseOf(plans.first, 'b');
      expect(b.at, DateTime(2026, 9, 30, 1, 0));
      expect(b.day, day);
      expect(plans[1].doses.where((d) => d.medId == 'b').single.day, DateTime(2026, 9, 30));
      expect(plans[1].doses.where((d) => d.medId == 'b').single.at, DateTime(2026, 10, 1, 1, 0));
    });

    test('a taken dose is pinned at its real time and moves the other medication', () {
      final s = DoseScheduler(
        meds: [
          med('a', times: ['08:00']),
          med('b', times: ['10:00']),
        ],
        rules: [sep('r', 'a', 'b', 120)],
      );
      final a = s.expandDay(day).firstWhere((d) => d.medId == 'a');
      final plan = s.planDay(day, taken: {a.key: hm(day, 9, 0)});
      expect(doseOf(plan, 'a').at, hm(day, 9, 0));
      expect(doseOf(plan, 'a').pinned, isTrue);
      expect(doseOf(plan, 'b').at, hm(day, 11, 0));
    });

    test('a skipped dose neither moves nor constrains', () {
      final s = DoseScheduler(
        meds: [
          med('a', times: ['08:00']),
          med('b', times: ['08:00']),
        ],
        rules: [sep('r', 'a', 'b', 120)],
      );
      final a = s.expandDay(day).firstWhere((d) => d.medId == 'a');
      final plan = s.planDay(day, skipped: {a.key});
      expect(doseOf(plan, 'b').at, hm(day, 8, 0));
      expect(plan.doses, hasLength(2));
    });

    test('two rules pulling one dose apart: it moves one way only, the other rule is reported', () {
      final s = DoseScheduler(
        meds: [
          med('a', times: ['05:00']),
          med('b', times: ['08:00']),
          med('c', times: ['11:00']),
        ],
        rules: [sep('ab', 'a', 'b', 240), sep('bc', 'b', 'c', 360)],
      );
      final plan = s.planDay(day);
      // a–b pushes B to 09:00; b–c would need C at 15:00 (+4 h, at the
      // limit) – allowed; nothing oscillates.
      expect(doseOf(plan, 'b').at, hm(day, 9, 0));
      expect(doseOf(plan, 'c').at, hm(day, 15, 0));
      expect(plan.conflicts, isEmpty);

      final tight = DoseScheduler(
        meds: s.meds,
        rules: [sep('ab', 'a', 'b', 240), sep('bc', 'b', 'c', 400)],
      );
      final p2 = tight.planDay(day);
      // C cannot go 4 h 40 later and B, already pushed later, may not come
      // back earlier: b–c is reported, a–b holds.
      expect(doseOf(p2, 'b').at, hm(day, 9, 0));
      expect(p2.conflicts.single.rule.id, 'bc');
      expect(p2.conflicts.single.actualMinutes, 120);
    });

    test('no dose is ever dropped, whatever the rules', () {
      final meds = [
        for (var i = 0; i < 6; i++) med('m$i', times: ['08:00', '08:05', '20:00'], order: i),
      ];
      final rules = [
        for (var i = 0; i < 6; i++)
          for (var j = i + 1; j < 6; j++) sep('r$i$j', 'm$i', 'm$j', 600),
      ];
      final s = DoseScheduler(meds: meds, rules: rules);
      final plan = s.planDay(day);
      expect(plan.doses, hasLength(18));
      expect(plan.conflicts, isNotEmpty);
    });
  });

  group('daylight saving', () {
    final spring = DateTime(2027, 3, 26);
    final fall = DateTime(2027, 10, 29);
    final clock = FakeDstClock(springDay: spring, fallDay: fall);

    test('a time skipped by the spring-forward resolves forward', () {
      final s = DoseScheduler(
        meds: [
          med('a', times: ['02:30']),
        ],
        wallClock: clock,
      );
      final dose = s.planDay(spring).doses.single;
      // 02:30 does not exist; 03:30 local (+3) = 00:30Z.
      expect(dose.at, DateTime.utc(2027, 3, 26, 0, 30));
      expect(dose.slot, dose.at);
    });

    test('separation counts real minutes across the transition', () {
      final s = DoseScheduler(
        meds: [
          med('a', times: ['01:30']),
          med('b', times: ['03:00']),
        ],
        rules: [sep('r', 'a', 'b', 120)],
        wallClock: clock,
      );
      final plan = s.planDay(spring);
      // 01:30 (+2) = 23:30Z; 03:00 (+3) = 00:00Z: only 30 real minutes apart.
      expect(doseOf(plan, 'a').at, DateTime.utc(2027, 3, 25, 23, 30));
      expect(doseOf(plan, 'b').at, DateTime.utc(2027, 3, 26, 1, 30));
      expect(plan.conflicts, isEmpty);
    });

    test('a repeated hour on the fall-back day takes its first occurrence', () {
      final s = DoseScheduler(
        meds: [
          med('a', times: ['02:30']),
        ],
        wallClock: clock,
      );
      // 02:30 happens at +3 (23:30Z) and again at +2 (00:30Z): the first.
      expect(s.planDay(fall).doses.single.at, DateTime.utc(2027, 10, 28, 23, 30));
    });
  });

  group('courses', () {
    final course = CourseSpec(
      id: 'c',
      name: 'Course',
      medicationId: 'inj',
      startDate: DateTime(2026, 10, 1),
      phases: CoursePhase.parseList([
        {'frequency': 'daily', 'interval': 1, 'count': 10, 'dose': '10 units'},
        {'frequency': 'weekly', 'interval': 1, 'count': 4, 'dose': '4 units'},
        {'frequency': 'monthly', 'interval': 1, 'dose': '1 amp'},
      ]),
    );

    test('phases chain from the start date', () {
      final days = CourseSchedule.expand(course, until: DateTime(2027, 1, 31));
      final keys = days.map((d) => MedDays.key(d.day)).toList();
      expect(keys.take(10), [for (var i = 1; i <= 10; i++) '2026-10-${i.toString().padLeft(2, '0')}']);
      expect(keys.skip(10).take(4), ['2026-10-17', '2026-10-24', '2026-10-31', '2026-11-07']);
      expect(keys.skip(14), ['2026-12-07', '2027-01-07']);
      expect(days[12].phase, 1);
      expect(days[12].indexInPhase, 2);
      expect(days.last.dose, '1 amp');
      expect(CourseSchedule.total(course), isNull);
    });

    test('monthly doses keep their day of month through short months', () {
      final c = CourseSpec(
        id: 'm',
        name: 'M',
        startDate: DateTime(2027, 1, 31),
        phases: const [CoursePhase(frequency: CourseFrequency.monthly, count: 4)],
      );
      expect(CourseSchedule.expand(c).map((d) => MedDays.key(d.day)), [
        '2027-01-31',
        '2027-02-28',
        '2027-03-31',
        '2027-04-30',
      ]);
      expect(CourseSchedule.endDate(c), DateTime(2027, 4, 30));
    });

    test('dose on a day, progress through phases', () {
      expect(CourseSchedule.doseOn(course, DateTime(2026, 10, 12)), isNull);
      expect(CourseSchedule.doseOn(course, DateTime(2026, 10, 17))!.phase, 1);
      expect(CourseSchedule.doseOn(course, DateTime(2026, 9, 30)), isNull);

      final p = CourseSchedule.progress(course, DateTime(2026, 10, 5));
      expect(p.phase, 0);
      expect(p.doneInPhase, 4);
      expect(p.dosesInPhase, 10);
      expect(p.next!.day, DateTime(2026, 10, 5));
      expect(CourseSchedule.progress(course, DateTime(2026, 10, 5), takenToday: true).doneInPhase, 5);

      final later = CourseSchedule.progress(course, DateTime(2026, 10, 20));
      expect(later.phase, 1);
      expect(later.doneInPhase, 1);
      expect(later.next!.day, DateTime(2026, 10, 24));
      expect(later.finished, isFalse);

      final finite = CourseSpec(
        id: 'f',
        name: 'F',
        startDate: DateTime(2026, 10, 1),
        phases: const [CoursePhase(frequency: CourseFrequency.daily, count: 3)],
      );
      final done = CourseSchedule.progress(finite, DateTime(2026, 10, 9));
      expect(done.finished, isTrue);
      expect(done.done, 3);
      expect(done.fraction, 1);
    });

    test('an open-ended phase before the last gets one dose', () {
      final phases = CoursePhase.parseList([
        {'frequency': 'daily'},
        {'frequency': 'weekly', 'count': 2},
      ]);
      expect(phases.first.count, 1);
      expect(phases.last.count, 2);
    });

    test('a course drives its medication: doses only on dose days, with the phase dose', () {
      final s = DoseScheduler(
        meds: [
          med('inj', times: ['10:00'], dose: 'base'),
        ],
        courses: [course],
      );
      expect(s.planDay(DateTime(2026, 10, 3)).doses.single.dose, '10 units');
      expect(s.planDay(DateTime(2026, 10, 3)).doses.single.source, DoseSource.course);
      expect(s.planDay(DateTime(2026, 10, 12)).doses, isEmpty);
      expect(s.planDay(DateTime(2026, 10, 17)).doses.single.dose, '4 units');
      expect(s.planDay(DateTime(2026, 9, 30)).doses, isEmpty);
    });

    test('a course medication without a time gets the default course time; a paused course none', () {
      final s = DoseScheduler(meds: [med('inj')], courses: [course]);
      expect(s.planDay(DateTime(2026, 10, 1)).doses.single.at, DateTime(2026, 10, 1, 9, 0));
      final paused = CourseSpec(
        id: 'c',
        name: 'Course',
        medicationId: 'inj',
        startDate: course.startDate,
        phases: course.phases,
        active: false,
      );
      expect(DoseScheduler(meds: [med('inj', times: ['08:00'])], courses: [paused]).planDay(DateTime(2026, 10, 1)).doses,
          isEmpty);
    });
  });

  group('models', () {
    test('anchors round-trip and reject garbage', () {
      const a = TimeAnchor(AnchorBase.maghrib, -15);
      expect(a.encode(), 'prayer:maghrib:-15');
      expect(TimeAnchor.decode(a.encode()), a);
      expect(TimeAnchor.decode('meal:lunch:+0'), const TimeAnchor(AnchorBase.lunch));
      expect(TimeAnchor.decode('prayer:noon:+5'), isNull);
      expect(TimeAnchor.decode('meal:lunch:+9999'), isNull);
      expect(TimeAnchor.decode(3), isNull);
    });

    test('settings round-trip, clamp and default', () {
      final s = const MedsSettings().copyWith(
        meals: {...MedsSettings.defaultMeals, MealSlot.lunch: const ClockHm(15, 30)},
        snoozeMinutes: 30,
      );
      expect(MedsSettings.fromJson(s.toJson()), s);
      expect(MedsSettings.fromJson({'lateAfter': -4, 'meals': {'lunch': 'x'}}).lateAfter, 5);
      expect(MedsSettings.fromJson('nope'), const MedsSettings());
    });

    test('months add with clamping', () {
      expect(MedDays.addMonths(DateTime(2027, 1, 31), 1), DateTime(2027, 2, 28));
      expect(MedDays.addMonths(DateTime(2028, 1, 31), 1), DateTime(2028, 2, 29));
      expect(MedDays.addMonths(DateTime(2026, 12, 15), 2), DateTime(2027, 2, 15));
    });
  });
}
