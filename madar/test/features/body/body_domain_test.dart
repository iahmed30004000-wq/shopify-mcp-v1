import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/notifications/notification_models.dart';
import 'package:madar/features/body/body.dart';

import 'body_test_clock.dart';

/// Tuesday 29 September 2026.
final DateTime tue = DateTime(2026, 9, 29);

PlannedExercise ex(String id, List<int> days, {bool active = true, int? sets, int? reps, double? weight, int? minutes}) =>
    PlannedExercise(
      id: id,
      name: 'Exercise $id',
      weekdays: days,
      active: active,
      sets: sets,
      reps: reps,
      weight: weight,
      durationMin: minutes,
    );

WorkoutEntry log(
  String id,
  DateTime at, {
  String? exerciseId,
  String name = 'x',
  int? sets,
  int? reps,
  double? weight,
  int? minutes,
}) => WorkoutEntry(
  id: id,
  exerciseId: exerciseId,
  name: name,
  at: at,
  sets: sets,
  reps: reps,
  weight: weight,
  durationMin: minutes,
);

void main() {
  group('BodyWeek', () {
    test('Arabic weeks start on Saturday, English on Sunday', () {
      expect(BodyWeek.startFor('ar'), DateTime.saturday);
      expect(BodyWeek.startFor('en'), DateTime.sunday);
      expect(BodyWeek.ordered(DateTime.saturday), [6, 7, 1, 2, 3, 4, 5]);
      expect(BodyWeek.ordered(DateTime.sunday), [7, 1, 2, 3, 4, 5, 6]);
      expect(BodyWeek.ordered(DateTime.monday), [1, 2, 3, 4, 5, 6, 7]);
    });

    test('normalize keeps unique valid ISO days, sorted', () {
      expect(BodyWeek.normalize([7, 3, 3, 0, 8, 1, -1]), [1, 3, 7]);
      expect(BodyWeek.normalize(const []), isEmpty);
    });

    test('display order follows the week start', () {
      // Mon, Wed, Sat.
      expect(BodyWeek.inDisplayOrder([1, 3, 6], DateTime.saturday), [6, 1, 3]);
      expect(BodyWeek.inDisplayOrder([1, 3, 6], DateTime.sunday), [1, 3, 6]);
      expect(BodyWeek.inDisplayOrder([7, 6], DateTime.saturday), [6, 7]);
      expect(BodyWeek.inDisplayOrder([7, 6], DateTime.sunday), [7, 6]);
    });

    test('week of a Tuesday: Saturday-first and Sunday-first', () {
      expect(BodyWeek.weekStartOf(tue, DateTime.saturday), DateTime(2026, 9, 26));
      expect(BodyWeek.weekStartOf(tue, DateTime.sunday), DateTime(2026, 9, 27));
      // A Saturday starts its own Arabic week.
      expect(BodyWeek.weekStartOf(DateTime(2026, 9, 26), DateTime.saturday), DateTime(2026, 9, 26));
      // A Friday is the last day of the Arabic week.
      expect(BodyWeek.weekStartOf(DateTime(2026, 10, 2), DateTime.saturday), DateTime(2026, 9, 26));
      final week = BodyWeek.weekOf(tue, DateTime.saturday);
      expect(week.first, DateTime(2026, 9, 26));
      expect(week.last, DateTime(2026, 10, 2));
      expect(week.map((d) => d.weekday), [6, 7, 1, 2, 3, 4, 5]);
    });

    test('weeks crossing a month and a year', () {
      final w = BodyWeek.weekOf(DateTime(2027, 1, 1), DateTime.saturday); // a Friday
      expect(w.first, DateTime(2026, 12, 26));
      expect(w.last, DateTime(2027, 1, 1));
    });

    test('next training day (today counts) and trains-on', () {
      expect(BodyWeek.nextOn([2], tue), tue);
      expect(BodyWeek.nextOn([1], tue), DateTime(2026, 10, 5));
      expect(BodyWeek.nextOn([6, 3], tue), DateTime(2026, 9, 30));
      expect(BodyWeek.nextOn(const [], tue), isNull);
      expect(BodyWeek.trainsOn([2, 4], tue), isTrue);
      expect(BodyWeek.trainsOn([1, 3], tue), isFalse);
      expect(BodyWeek.perWeek([1, 1, 3, 9]), 2);
    });
  });

  group('training day', () {
    final exercises = [
      ex('a', [2, 4]),
      ex('b', [1]),
      ex('c', [2], active: false),
      ex('d', [2]),
    ];

    test("today's session is the active plan for the weekday, in order", () {
      final day = TrainingDay.build(exercises: exercises, logs: const [], day: tue);
      expect(day.items.map((i) => i.exercise.id), ['a', 'd']);
      expect(day.planned, 2);
      expect(day.done, 0);
      expect(day.isRestDay, isFalse);
      final monday = TrainingDay.build(exercises: exercises, logs: const [], day: DateTime(2026, 9, 28));
      expect(monday.items.map((i) => i.exercise.id), ['b']);
      final sunday = TrainingDay.build(exercises: exercises, logs: const [], day: DateTime(2026, 9, 27));
      expect(sunday.isRestDay, isTrue);
      expect(sunday.progress, 0);
    });

    test('logs of the day mark exercises done; others are extras', () {
      final logs = [
        log('1', DateTime(2026, 9, 29, 7), exerciseId: 'a', minutes: 20),
        log('2', DateTime(2026, 9, 29, 18), exerciseId: 'a', minutes: 10),
        log('3', DateTime(2026, 9, 29, 19), exerciseId: 'b', minutes: 15), // Monday's, done today
        log('4', DateTime(2026, 9, 28, 19), exerciseId: 'd'), // yesterday
        log('5', DateTime(2026, 9, 29, 12), name: 'Exercise d'), // imported without id
      ];
      final day = TrainingDay.build(exercises: exercises, logs: logs, day: tue);
      expect(day.items[0].done, isTrue);
      expect(day.items[0].logs.map((l) => l.id), ['2', '1']);
      expect(day.items[0].latest!.id, '2');
      expect(day.items[1].logs.map((l) => l.id), ['5']);
      expect(day.complete, isTrue);
      expect(day.extras.map((l) => l.id), ['3']);
      expect(day.minutes, 45);
    });

    test('only the last open exercise completes the session', () {
      final none = TrainingDay.build(exercises: exercises, logs: const [], day: tue);
      expect(none.completedBy('a'), isFalse); // two still open
      final oneDone = TrainingDay.build(
        exercises: exercises,
        logs: [log('1', DateTime(2026, 9, 29, 7), exerciseId: 'a')],
        day: tue,
      );
      expect(oneDone.completedBy('d'), isTrue);
      expect(oneDone.completedBy('a'), isFalse); // logging it again adds nothing
      expect(oneDone.completedBy('b'), isFalse); // not on today's plan
      expect(oneDone.completedBy(null), isFalse); // a free workout
      final rest = TrainingDay.build(exercises: exercises, logs: const [], day: DateTime(2026, 9, 27));
      expect(rest.completedBy('a'), isFalse);
    });

    test('days follow the wall clock (a +3 zone)', () {
      final amman = FakeZoneClock.fixed(3);
      final logs = [
        log('late', DateTime.utc(2026, 9, 28, 21, 30), exerciseId: 'a'), // 00:30 Tue local
        log('early', DateTime.utc(2026, 9, 28, 20, 30), exerciseId: 'd'), // 23:30 Mon local
      ];
      final day = TrainingDay.build(exercises: exercises, logs: logs, day: tue, clock: amman);
      expect(day.items[0].done, isTrue);
      expect(day.items[1].done, isFalse);
    });

    test('week adherence counts scheduled days up to today', () {
      // Saturday-first week of Tue 29 Sep: Sat 26 … Fri 2 Oct.
      final plan = [
        ex('a', [6, 2, 4]),
      ];
      final logs = [log('1', DateTime(2026, 9, 26, 9), exerciseId: 'a')];
      final w = WeekAdherence.of(exercises: plan, logs: logs, today: tue, weekStart: DateTime.saturday);
      expect(w.expected, 2); // Saturday and today; Thursday is still ahead
      expect(w.done, 1);
      expect(w.ratio, 0.5);
      expect(w.days.map((d) => d.planned), [1, 0, 0, 1, 0, 1, 0]);
      expect(w.days.map((d) => d.done), [1, 0, 0, 0, 0, 0, 0]);
      final en = WeekAdherence.of(exercises: plan, logs: logs, today: tue, weekStart: DateTime.sunday);
      expect(en.expected, 1); // Sunday-first: Saturday 26 belongs to last week
      expect(en.days.first.day, DateTime(2026, 9, 27));
    });
  });

  group('workout volume', () {
    test('sets × reps × kg', () {
      expect(WorkoutMath.volume(3, 10, 20), 600);
      expect(WorkoutMath.volume(4, 8, 62.5), 2000);
      expect(WorkoutMath.volume(null, 12, 10), 120);
      expect(WorkoutMath.volume(3, 10, null), isNull);
      expect(WorkoutMath.volume(3, 10, 0), isNull);
      expect(WorkoutMath.volume(3, null, 20), isNull);
      expect(WorkoutMath.totalReps(3, 12), 36);
      expect(WorkoutMath.totalReps(0, 12), 12);
      expect(WorkoutMath.totalReps(3, null), isNull);
    });

    test('totals over logs skip what has no volume', () {
      final logs = [
        log('1', tue, sets: 3, reps: 10, weight: 20, minutes: 15),
        log('2', tue, sets: 3, reps: 10, minutes: 5),
        log('3', tue, reps: 5, weight: 10),
      ];
      expect(WorkoutMath.totalVolume(logs), 650);
      expect(WorkoutMath.totalMinutes(logs), 20);
    });

    test('progress: one point per day per metric', () {
      final logs = [
        log('1', DateTime(2026, 9, 22, 8), sets: 3, reps: 10, weight: 20),
        log('2', DateTime(2026, 9, 22, 18), sets: 2, reps: 8, weight: 25),
        log('3', DateTime(2026, 9, 25, 8), sets: 3, reps: 10, weight: 22.5, minutes: 30),
        log('4', DateTime(2026, 9, 29, 8), sets: 4, reps: 10),
      ];
      final p = ExerciseProgress.build(logs);
      expect(p.logs.map((l) => l.id), ['4', '3', '2', '1']);
      expect(p.of(ProgressMetric.weight), [
        ProgressPoint(DateTime(2026, 9, 22), 25),
        ProgressPoint(DateTime(2026, 9, 25), 22.5),
      ]);
      expect(p.of(ProgressMetric.volume), [
        ProgressPoint(DateTime(2026, 9, 22), 1000),
        ProgressPoint(DateTime(2026, 9, 25), 675),
      ]);
      expect(p.of(ProgressMetric.reps).map((x) => x.value), [46, 30, 40]);
      expect(p.of(ProgressMetric.minutes).map((x) => x.value), [30]);
      expect(p.available, ProgressMetric.values);
      expect(p.preferred, ProgressMetric.weight);
      expect(p.best(ProgressMetric.volume), 1000);
      expect(p.change(ProgressMetric.weight), -2.5);
      expect(p.change(ProgressMetric.minutes), isNull);
      expect(p.lastDone, DateTime(2026, 9, 29, 8));
    });

    test('bodyweight exercises open on reps', () {
      final p = ExerciseProgress.build([
        log('1', DateTime(2026, 9, 20), sets: 3, reps: 12),
        log('2', DateTime(2026, 9, 21), sets: 3, reps: 15),
      ]);
      expect(p.available, [ProgressMetric.reps]);
      expect(p.preferred, ProgressMetric.reps);
      expect(ExerciseProgress.empty.preferred, isNull);
    });
  });

  group('fasting plan', () {
    test('16:8 by default, eating window is the rest of the day', () {
      const p = FastingPlan();
      expect(p.target, const Duration(hours: 16));
      expect(p.eatingWindow, const Duration(hours: 8));
      expect(p.ratio, '16:8');
      expect(p.isPreset, isTrue);
      expect(const FastingPlan(targetHours: 36).eatingWindow, Duration.zero);
      expect(const FastingPlan(targetHours: 36).ratio, isNull);
      expect(const FastingPlan(targetHours: 13.5).ratio, isNull);
      expect(const FastingPlan(targetHours: 13.5).isPreset, isFalse);
    });

    test('JSON round trip and tolerant decoding', () {
      const p = FastingPlan(targetHours: 18, lastMealMinutes: 19 * 60 + 30, notifyGoal: true, eatingLeadMinutes: 15);
      expect(FastingPlan.fromJson(p.toJson()), p);
      expect(p.toJson()['lastMeal'], '19:30');
      expect(FastingPlan.fromJson(null), const FastingPlan());
      expect(FastingPlan.fromJson({'targetHours': 900, 'lastMeal': '25:00', 'eatingLeadMinutes': -3}), const FastingPlan());
    });
  });

  group('fasting timer', () {
    const plan = FastingPlan(); // 16:8, last meal 20:00

    test('a fast across midnight: elapsed, remaining, goal the next day', () {
      final f = FastingSpan(id: 'f', start: DateTime(2026, 9, 29, 20), targetHours: 16);
      expect(f.goalAt, DateTime(2026, 9, 30, 12));
      final s = FastingMath.status(plan: plan, now: DateTime(2026, 9, 30, 2, 30), active: f);
      expect(s.phase, FastingPhase.fasting);
      expect(s.elapsed, const Duration(hours: 6, minutes: 30));
      expect(s.remaining, const Duration(hours: 9, minutes: 30));
      expect(s.progress, closeTo(6.5 / 16, 1e-9));
      expect(s.reached, isFalse);
      expect(s.overtime, Duration.zero);
    });

    test('past the goal: reached with overtime', () {
      final f = FastingSpan(id: 'f', start: DateTime(2026, 9, 29, 20), targetHours: 16);
      final s = FastingMath.status(plan: plan, now: DateTime(2026, 9, 30, 13, 15), active: f);
      expect(s.reached, isTrue);
      expect(s.remaining, Duration.zero);
      expect(s.overtime, const Duration(hours: 1, minutes: 15));
      expect(s.progress, greaterThan(1));
      expect(f.reached(DateTime(2026, 9, 30, 12)), isTrue);
      expect(f.reached(DateTime(2026, 9, 30, 11, 59)), isFalse);
    });

    test('a start in the future never gives negative time', () {
      final f = FastingSpan(id: 'f', start: DateTime(2026, 9, 29, 21), targetHours: 16);
      expect(f.duration(DateTime(2026, 9, 29, 20)), Duration.zero);
      final s = FastingMath.status(plan: plan, now: DateTime(2026, 9, 29, 20), active: f);
      expect(s.elapsed, Duration.zero);
    });

    test('after breaking the fast: eating until the next last meal', () {
      final s = FastingMath.status(plan: plan, now: DateTime(2026, 9, 30, 14), lastEnd: DateTime(2026, 9, 30, 12, 10));
      expect(s.phase, FastingPhase.eating);
      expect(s.from, DateTime(2026, 9, 30, 12, 10));
      expect(s.until, DateTime(2026, 9, 30, 20));
      expect(s.remaining, const Duration(hours: 6));
    });

    test('inside the planned window without a logged fast: eating', () {
      final s = FastingMath.status(plan: plan, now: DateTime(2026, 9, 30, 15));
      expect(s.phase, FastingPhase.eating);
      expect(s.from, DateTime(2026, 9, 30, 12));
      expect(s.until, DateTime(2026, 9, 30, 20));
      expect(s.progress, closeTo(3 / 8, 1e-9));
    });

    test('a missed start shows as fasting time for a few hours', () {
      final s = FastingMath.status(plan: plan, now: DateTime(2026, 9, 30, 21), lastEnd: DateTime(2026, 9, 30, 12));
      expect(s.phase, FastingPhase.waiting);
      expect(s.lastPlannedStart, DateTime(2026, 9, 30, 20));
      expect(s.missedStart(), isTrue);
      expect(s.until, DateTime(2026, 10, 1, 20));
      // Before the window opens in the morning it is not "missed" any more.
      final morning = FastingMath.status(plan: plan, now: DateTime(2026, 10, 1, 9));
      expect(morning.phase, FastingPhase.waiting);
      expect(morning.missedStart(), isFalse);
    });

    test('next / last planned start around the last-meal time', () {
      expect(FastingMath.nextPlannedStart(plan, DateTime(2026, 9, 29, 19, 59)), DateTime(2026, 9, 29, 20));
      expect(FastingMath.nextPlannedStart(plan, DateTime(2026, 9, 29, 20)), DateTime(2026, 9, 30, 20));
      expect(FastingMath.lastPlannedStart(plan, DateTime(2026, 9, 29, 20)), DateTime(2026, 9, 29, 20));
      expect(FastingMath.lastPlannedStart(plan, DateTime(2026, 9, 29, 19)), DateTime(2026, 9, 28, 20));
      // Month and year boundaries.
      expect(FastingMath.nextPlannedStart(plan, DateTime(2026, 12, 31, 22)), DateTime(2027, 1, 1, 20));
    });

    test('fasts of a day or more have no eating window', () {
      const long = FastingPlan(targetHours: 36);
      final s = FastingMath.status(plan: long, now: DateTime(2026, 9, 30, 15), lastEnd: DateTime(2026, 9, 30, 8));
      expect(s.phase, FastingPhase.waiting);
      expect(s.until, DateTime(2026, 9, 30, 20));
    });

    group('daylight saving', () {
      test('spring forward: the goal is 16 real hours later (wall clock +1)', () {
        final zone = FakeZoneClock.spring();
        final start = zone.at(DateTime(2027, 3, 25), 20 * 60); // 20:00 at +2
        expect(start, DateTime.utc(2027, 3, 25, 18));
        final f = FastingSpan(id: 'f', start: start, targetHours: 16);
        expect(f.goalAt, DateTime.utc(2027, 3, 26, 10));
        expect(zone.wall(f.goalAt), '13:00');
        final s = FastingMath.status(plan: plan, now: DateTime.utc(2027, 3, 26, 3), active: f, clock: zone);
        expect(s.elapsed, const Duration(hours: 9));
        expect(s.remaining, const Duration(hours: 7));
      });

      test('spring forward: the next planned start is 20:00 on the wall, 22 real hours later', () {
        final zone = FakeZoneClock.spring();
        final now = DateTime.utc(2027, 3, 25, 19); // 21:00 at +2
        final next = FastingMath.nextPlannedStart(plan, now, clock: zone);
        expect(next, DateTime.utc(2027, 3, 26, 17));
        expect(zone.wall(next), '20:00');
        expect(next.difference(now), const Duration(hours: 22));
        // The eating window opens 8 real hours before it: 12:00 on the wall.
        final eating = FastingMath.status(plan: plan, now: DateTime.utc(2027, 3, 26, 10), clock: zone);
        expect(eating.phase, FastingPhase.eating);
        expect(zone.wall(eating.from), '12:00');
      });

      test('a wall time skipped by the change resolves forward', () {
        final zone = FakeZoneClock.spring();
        final t = zone.at(DateTime(2027, 3, 26), 30); // 00:30 does not exist
        expect(zone.wall(t), '01:30');
      });

      test('fall back: 20:00 → 12:00 lasts 17 real hours; the goal comes at 11:00', () {
        final zone = FakeZoneClock.fall();
        final start = zone.at(DateTime(2027, 10, 28), 20 * 60); // +3
        final f = FastingSpan(id: 'f', start: start, targetHours: 16);
        expect(zone.wall(f.goalAt), '11:00');
        final noon = zone.at(DateTime(2027, 10, 29), 12 * 60); // +2
        expect(noon.difference(start), const Duration(hours: 17));
        final s = FastingMath.status(plan: plan, now: noon, active: f, clock: zone);
        expect(s.reached, isTrue);
        expect(s.overtime, const Duration(hours: 1));
      });
    });
  });

  group('fasting stats', () {
    final now = DateTime(2026, 9, 29, 21);
    FastingSpan fast(String id, DateTime start, Duration length, {double target = 16}) =>
        FastingSpan(id: id, start: start, end: start.add(length), targetHours: target);

    test('streak of days with a reached fast, counted on the day it ended', () {
      final spans = [
        fast('1', DateTime(2026, 9, 25, 20), const Duration(hours: 16)), // ends 26th ✓
        fast('2', DateTime(2026, 9, 26, 20), const Duration(hours: 17)), // ends 27th ✓
        fast('3', DateTime(2026, 9, 27, 20), const Duration(hours: 15)), // ends 28th ✗
        fast('4', DateTime(2026, 9, 28, 20), const Duration(hours: 16, minutes: 5)), // ends 29th ✓
      ];
      final s = FastingStats.of(spans, now: now);
      expect(s.streak, 1);
      expect(s.reachedToday, isTrue);
      expect(s.total, 4);
      expect(s.completed, 3);
      expect(s.longest, const Duration(hours: 17));
      expect(s.average, const Duration(hours: 16, minutes: 1, seconds: 15));
    });

    test("an unfinished today keeps yesterday's streak alive", () {
      final spans = [
        fast('1', DateTime(2026, 9, 26, 20), const Duration(hours: 16)),
        fast('2', DateTime(2026, 9, 27, 20), const Duration(hours: 16)),
        FastingSpan(id: 'now', start: DateTime(2026, 9, 29, 20), targetHours: 16),
      ];
      final s = FastingStats.of(spans, now: now);
      expect(s.streak, 2);
      expect(s.reachedToday, isFalse);
      expect(s.total, 2); // the running fast is not finished
    });

    test('a running fast past its goal counts for today', () {
      final spans = [FastingSpan(id: 'now', start: DateTime(2026, 9, 29, 4), targetHours: 16)];
      final s = FastingStats.of(spans, now: now);
      expect(s.reachedToday, isTrue);
      expect(s.streak, 1);
      expect(FastingStats.of(const [], now: now).streak, 0);
    });
  });

  group('water', () {
    WaterEntry w(String id, DateTime at, int ml) => WaterEntry(id: id, at: at, ml: ml);

    test('totals per local day (+3: 00:30 local is 21:30 UTC the day before)', () {
      final amman = FakeZoneClock.fixed(3);
      final entries = [
        w('a', DateTime.utc(2026, 9, 28, 20, 59), 250), // 23:59 Mon
        w('b', DateTime.utc(2026, 9, 28, 21, 30), 500), // 00:30 Tue
        w('c', DateTime.utc(2026, 9, 29, 10), 250), // 13:00 Tue
      ];
      expect(WaterMath.totalOn(entries, DateTime(2026, 9, 28), clock: amman), 250);
      expect(WaterMath.totalOn(entries, tue, clock: amman), 750);
      expect(WaterMath.totalsByDay(entries, clock: amman), {'2026-09-28': 250, '2026-09-29': 750});
    });

    test('seven days, oldest first, zero-filled', () {
      final entries = [w('a', DateTime(2026, 9, 29, 9), 500), w('b', DateTime(2026, 9, 25, 9), 2500)];
      final days = WaterMath.lastDays(entries, tue);
      expect(days, hasLength(7));
      expect(days.first.day, DateTime(2026, 9, 23));
      expect(days.last.day, tue);
      expect(days.map((d) => d.ml), [0, 0, 2500, 0, 0, 0, 500]);
    });

    test('streak of days meeting the target', () {
      final entries = [
        w('1', DateTime(2026, 9, 26, 9), 2500),
        w('2', DateTime(2026, 9, 27, 9), 1500),
        w('3', DateTime(2026, 9, 27, 18), 1000),
        w('4', DateTime(2026, 9, 28, 9), 3000),
        w('5', DateTime(2026, 9, 29, 9), 1000),
      ];
      expect(WaterMath.streak(entries, tue, 2500), 3); // today not met yet
      expect(WaterMath.streak(entries, tue, 1000), 4);
      expect(WaterMath.streak(entries, tue, 0), 0);
    });

    test('target default and bounds; progress is capped', () {
      expect(WaterMath.targetOf(null), 2500);
      expect(WaterMath.targetOf(3000), 3000);
      expect(WaterMath.targetOf(3000.4), 3000);
      expect(WaterMath.targetOf(10), 2500);
      expect(WaterMath.targetOf('x'), 2500);
      expect(WaterMath.progress(1250, 2500), 0.5);
      expect(WaterMath.progress(4000, 2500), 1);
      expect(WaterMath.progress(100, 0), 0);
    });
  });

  group('reminder plan', () {
    const plan = FastingPlan(notifyGoal: true, notifyEatingClose: true, eatingLeadMinutes: 30);
    List<BodyNotice> planAt(DateTime now, {FastingSpan? active, FastingPlan p = plan, BodyWallClock? clock}) =>
        BodyReminderPlanner.plan(
          plan: p,
          now: now,
          active: active,
          goalTitle: 'goal',
          goalBody: (f) => 'goal ${f.targetHours}',
          eatingTitle: 'eat',
          eatingBody: (at) => 'closes $at',
          clock: clock ?? const LocalBodyWallClock(),
        );

    test('ids live in their own block of the reminders namespace', () {
      expect(BodyReminderIds.namespace, NotificationNamespaces.reminders);
      expect(BodyReminderIds.goal, 139800);
      expect(BodyReminderIds.eating(0), 139801);
      expect(BodyReminderIds.eating(2), 139803);
      expect(BodyReminderIds.owns(139803), isTrue);
      expect(BodyReminderIds.owns(139804), isFalse);
      expect(BodyReminderIds.owns(130000), isFalse);
      expect(() => BodyReminderIds.eating(3), throwsRangeError);
    });

    test('while fasting: the goal, and eating reminders outside the fast', () {
      final f = FastingSpan(id: 'f', start: DateTime(2026, 9, 29, 20), targetHours: 16);
      final n = planAt(DateTime(2026, 9, 29, 22), active: f);
      expect(n.first.kind, BodyNoticeKind.fastGoal);
      expect(n.first.at, DateTime(2026, 9, 30, 12));
      expect(n.first.body, 'goal 16.0');
      final eating = n.where((x) => x.kind == BodyNoticeKind.eatingClose).toList();
      expect(eating.map((x) => x.at), [
        DateTime(2026, 9, 30, 19, 30),
        DateTime(2026, 10, 1, 19, 30),
        DateTime(2026, 10, 2, 19, 30),
      ]);
      expect(eating.map((x) => x.id), [139801, 139802, 139803]);
    });

    test("past moments and the fast's own span are skipped", () {
      // 19:45: today's 19:30 is past.
      final n = planAt(DateTime(2026, 9, 29, 19, 45));
      expect(n.every((x) => x.kind == BodyNoticeKind.eatingClose), isTrue);
      expect(n.first.at, DateTime(2026, 9, 30, 19, 30));
      // A 36 h fast covers tomorrow's reminder.
      final long = FastingSpan(id: 'f', start: DateTime(2026, 9, 29, 20), targetHours: 36);
      final m = planAt(DateTime(2026, 9, 29, 21), active: long);
      expect(m.where((x) => x.kind == BodyNoticeKind.eatingClose).map((x) => x.at), [
        DateTime(2026, 10, 1, 19, 30),
        DateTime(2026, 10, 2, 19, 30),
      ]);
      // A goal already behind is not planned.
      final done = FastingSpan(id: 'f', start: DateTime(2026, 9, 28, 20), targetHours: 16);
      expect(planAt(DateTime(2026, 9, 29, 13), active: done).any((x) => x.kind == BodyNoticeKind.fastGoal), isFalse);
    });

    test('switches off; no eating reminders without an eating window', () {
      expect(planAt(DateTime(2026, 9, 29, 9), p: const FastingPlan()), isEmpty);
      expect(planAt(DateTime(2026, 9, 29, 9), p: plan.copyWith(targetHours: 30)), isEmpty);
    });

    test('eating reminders follow the wall clock across DST', () {
      final zone = FakeZoneClock.spring();
      final n = planAt(DateTime.utc(2027, 3, 25, 12), p: const FastingPlan(notifyEatingClose: true), clock: zone);
      expect(n.map((x) => zone.wall(x.at)), ['19:30', '19:30', '19:30']);
      expect(n[0].at, DateTime.utc(2027, 3, 25, 17, 30));
      expect(n[1].at, DateTime.utc(2027, 3, 26, 16, 30));
    });
  });

  group('times', () {
    test('HH:mm parsing and formatting', () {
      expect(BodyTimes.parse('20:30'), 1230);
      expect(BodyTimes.parse('7:05'), 425);
      expect(BodyTimes.parse('24:00'), isNull);
      expect(BodyTimes.parse('x'), isNull);
      expect(BodyTimes.format(1230), '20:30');
      expect(BodyTimes.format(0), '00:00');
      expect(BodyDays.between(DateTime(2026, 9, 29), DateTime(2026, 10, 2)), 3);
      expect(BodyDays.key(DateTime(2026, 1, 5)), '2026-01-05');
    });
  });
}
