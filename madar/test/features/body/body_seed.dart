// Generic sample data for Body tests and screenshots (test-only; the app
// itself starts empty).
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/features/body/body.dart';

enum BodySeed {
  /// Plan, three weeks of logs, the avoid list, a fast running since last
  /// night, water today and this week.
  full,

  /// As [full] but the last fast ended at 12:10 today (eating window).
  eating,

  /// Only the plan (no logs, fasts or water).
  planOnly,
}

class _Ex {
  const _Ex(this.ar, this.en, this.days, {this.sets, this.reps, this.weight, this.minutes, this.notesAr, this.notesEn, this.active = true});

  final String ar;
  final String en;
  final List<int> days;
  final int? sets;
  final int? reps;
  final double? weight;
  final int? minutes;
  final String? notesAr;
  final String? notesEn;
  final bool active;
}

const _exercises = [
  _Ex('قرفصاء بالبار', 'Barbell squats', [6, 2, 4], sets: 4, reps: 8, weight: 60),
  _Ex('تمرين ضغط', 'Push-ups', [6, 2, 4], sets: 3, reps: 15),
  _Ex('مشي سريع', 'Brisk walk', [7, 2, 5], minutes: 30, notesAr: 'بعد صلاة العصر', notesEn: 'After Asr'),
  _Ex('تمارين الإطالة', 'Stretching', [1, 3, 5], minutes: 15),
  _Ex('سباحة', 'Swimming', [5], minutes: 45, active: false),
];

Future<void> seedBody(MadarDatabase db, BodySeed seed, {required DateTime now, bool arabic = true}) async {
  final repos = Repositories(db);
  final s = BodyService(repos, clock: () => now);
  final today = DateTime(now.year, now.month, now.day);
  final ids = <String>[];
  for (final e in _exercises) {
    final (row, _) = await s.addExercise(
      ExerciseDraft(
        name: arabic ? e.ar : e.en,
        weekdays: e.days,
        sets: e.sets,
        reps: e.reps,
        weight: e.weight,
        durationMin: e.minutes,
        notes: arabic ? e.notesAr : e.notesEn,
        active: e.active,
      ),
    );
    ids.add(row.id);
  }
  if (seed == BodySeed.planOnly) return;

  // Three weeks of training, the squat weight creeping up.
  var squat = 50.0;
  for (var d = -21; d <= -1; d++) {
    final day = DateTime(today.year, today.month, today.day + d);
    for (var i = 0; i < 3; i++) {
      final e = _exercises[i];
      if (!e.days.contains(day.weekday)) continue;
      if ((d + i) % 7 == 3) continue; // a few misses
      final at = DateTime(day.year, day.month, day.day, i == 2 ? 16 : 6, 40 + i * 5);
      await s.logWorkout(
        WorkoutDraft(
          exerciseId: ids[i],
          name: arabic ? e.ar : e.en,
          at: at,
          sets: e.sets,
          reps: i == 1 ? 12 + (d + 21) ~/ 6 : e.reps,
          weight: i == 0 ? squat : null,
          durationMin: e.minutes ?? (i == 0 ? 35 : 10),
        ),
      );
      if (i == 0) squat += 1.25;
    }
  }
  // Today: squats done this morning.
  await s.logWorkout(
    WorkoutDraft(
      exerciseId: ids[0],
      name: arabic ? _exercises[0].ar : _exercises[0].en,
      at: DateTime(today.year, today.month, today.day, 7, 5),
      sets: 4,
      reps: 8,
      weight: 62.5,
      durationMin: 35,
    ),
  );

  await s.addAvoid(
    arabic ? 'رفع الأثقال فوق الرأس' : 'Overhead lifting',
    reason: arabic ? 'بحسب نصيحة المختص' : 'As my specialist advised',
  );
  await s.addAvoid(arabic ? 'المشروبات الغازية' : 'Fizzy drinks');
  await s.addAvoid(
    arabic ? 'الجلوس المتواصل أكثر من ساعة' : 'Sitting for over an hour straight',
    reason: arabic ? 'أقوم وأتمشّى قليلًا' : 'I get up and walk a little',
  );

  // Fasts of the past week (one fell short).
  const lengths = [Duration(hours: 16, minutes: 10), Duration(hours: 17), Duration(hours: 15, minutes: 20), Duration(hours: 16, minutes: 40), Duration(hours: 16, minutes: 5)];
  for (var k = 0; k < lengths.length; k++) {
    final start = DateTime(today.year, today.month, today.day - 6 + k, 20, 5 + k * 3);
    final (row, _) = await s.startFast(at: start, targetHours: 16);
    await s.stopFast(row, at: start.add(lengths[k]));
  }
  final lastStart = DateTime(today.year, today.month, today.day - 1, 20, 5);
  final (running, _) = await s.startFast(at: lastStart, targetHours: 16);
  if (seed == BodySeed.eating) await s.stopFast(running, at: DateTime(today.year, today.month, today.day, 12, 10));
  await s.setFastingPlan(const FastingPlan(notifyGoal: true));

  // Water: this week and today.
  const week = [2600, 2250, 2750, 1800, 2500, 3000];
  for (var k = 0; k < week.length; k++) {
    final day = DateTime(today.year, today.month, today.day - 6 + k);
    var left = week[k];
    var h = 7;
    while (left > 0) {
      final ml = left >= 500 ? 500 : left;
      await s.addWater(ml, at: DateTime(day.year, day.month, day.day, h));
      left -= ml;
      h += 2;
    }
  }
  final todays = seed == BodySeed.eating
      ? const [(6, 10, 250), (8, 30, 500), (10, 5, 500), (12, 20, 500), (14, 0, 250)]
      : const [(6, 10, 250), (8, 30, 500), (10, 5, 500)];
  for (final (h, m, ml) in todays) {
    await s.addWater(ml, at: DateTime(today.year, today.month, today.day, h, m));
  }
}
