import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/features/body/body.dart';

import '../../helpers/test_app.dart' show testDatabase;

void main() {
  late MadarDatabase db;
  late Repositories repos;
  late BodyService service;
  var now = DateTime(2026, 9, 29, 20, 15);

  setUp(() async {
    now = DateTime(2026, 9, 29, 20, 15);
    db = testDatabase();
    repos = Repositories(db);
    service = BodyService(repos, clock: () => now);
  });

  tearDown(() => db.close());

  Future<List<ActivityRow>> activity() => repos.activityLog.getAll();

  test('a fresh install has no Body data', () async {
    expect(await repos.exercises.getAll(), isEmpty);
    expect(await repos.avoidItems.getAll(), isEmpty);
    expect(await repos.fastingSessions.getAll(), isEmpty);
    expect(await repos.waterLogs.getAll(), isEmpty);
    expect(await repos.keyValues.contains(WaterMath.targetKey), isFalse);
    expect(await service.fastingPlan(), const FastingPlan());
  });

  group('plan', () {
    test('add normalises days and blanks; edit, pause, duplicate, delete with undo', () async {
      final (row, undoAdd) = await service.addExercise(
        const ExerciseDraft(name: '  Push-ups ', weekdays: [3, 6, 1, 3, 9], sets: 3, reps: 12, weight: 0, notes: '  '),
      );
      expect(row.name, 'Push-ups');
      expect(row.weekdays, [1, 3, 6]);
      expect(row.weight, isNull);
      expect(row.notes, isNull);

      final undoEdit = await service.updateExercise(row, const ExerciseDraft(name: 'Push-ups', weekdays: [2], reps: 15));
      final edited = (await repos.exercises.byId(row.id))!;
      expect(edited.weekdays, [2]);
      expect(edited.sets, isNull);
      await undoEdit();
      expect((await repos.exercises.byId(row.id))!.weekdays, [1, 3, 6]);

      final undoPause = await service.setExerciseActive(row, false);
      expect((await repos.exercises.byId(row.id))!.active, isFalse);
      await undoPause();
      expect((await repos.exercises.byId(row.id))!.active, isTrue);

      final (copy, undoCopy) = await service.duplicateExercise(row, name: 'Push-ups (copy)');
      expect(copy.name, 'Push-ups (copy)');
      expect(copy.weekdays, [1, 3, 6]);
      await undoCopy();
      expect(await repos.exercises.count(), 1);

      final undoDelete = await service.deleteExercise(row);
      expect(await repos.exercises.count(), 0);
      await undoDelete();
      expect((await repos.exercises.byId(row.id))!.name, 'Push-ups');

      await undoAdd();
      expect(await repos.exercises.count(), 0);
    });

    test('reorder persists the order', () async {
      final (a, _) = await service.addExercise(const ExerciseDraft(name: 'A'));
      final (b, _) = await service.addExercise(const ExerciseDraft(name: 'B'));
      final (c, _) = await service.addExercise(const ExerciseDraft(name: 'C'));
      await service.reorderExercises([c.id, a.id, b.id]);
      expect((await repos.exercises.getAll()).map((e) => e.name), ['C', 'A', 'B']);
    });
  });

  group('workouts', () {
    test('logging a workout feeds the Body planet; undo removes both', () async {
      final (ex, _) = await service.addExercise(const ExerciseDraft(name: 'Squats', weekdays: [2], sets: 3, reps: 10, weight: 40));
      final (row, undo) = await service.logWorkout(
        WorkoutDraft(exerciseId: ex.id, name: 'Squats', at: now, sets: 3, reps: 10, weight: 42.5, durationMin: 20),
      );
      expect(row.weight, 42.5);
      final a = await activity();
      expect(a, hasLength(1));
      expect(a.single.planetKey, 'body');
      expect(a.single.kind, 'body.workout');
      expect(a.single.refTable, 'workout_logs');
      expect(a.single.refId, row.id);
      expect(a.single.value, 20);
      await undo();
      expect(await repos.workoutLogs.count(), 0);
      expect(await activity(), isEmpty);
    });

    test('edit and delete with undo (activity comes back too)', () async {
      final (row, _) = await service.logWorkout(WorkoutDraft(name: 'Walk', at: now, durationMin: 30));
      final undoEdit = await service.updateWorkout(row, WorkoutDraft(name: 'Walk', at: now, durationMin: 45, notes: 'park'));
      expect((await repos.workoutLogs.byId(row.id))!.durationMin, 45);
      await undoEdit();
      expect((await repos.workoutLogs.byId(row.id))!.durationMin, 30);
      final undo = await service.deleteWorkout(row);
      expect(await repos.workoutLogs.count(), 0);
      expect(await activity(), isEmpty);
      await undo();
      expect(await repos.workoutLogs.count(), 1);
      expect(await activity(), hasLength(1));
    });

    test('the watch lists newest first', () async {
      await service.logWorkout(WorkoutDraft(name: 'A', at: now.subtract(const Duration(hours: 2))));
      await service.logWorkout(WorkoutDraft(name: 'B', at: now));
      final rows = await service.watchWorkouts(since: DateTime(2026, 9, 29)).first;
      expect(rows.map((r) => r.name), ['B', 'A']);
    });
  });

  group('avoid list', () {
    test('add, edit, reorder, delete with undo', () async {
      final (a, _) = await service.addAvoid('Fizzy drinks', reason: ' ');
      final (b, _) = await service.addAvoid('Deep squats', reason: 'knee');
      expect(a.reason, isNull);
      final undoEdit = await service.updateAvoid(a, 'Sugary drinks', reason: 'my choice');
      expect((await repos.avoidItems.byId(a.id))!.body, 'Sugary drinks');
      await undoEdit();
      expect((await repos.avoidItems.byId(a.id))!.body, 'Fizzy drinks');
      await service.reorderAvoid([b.id, a.id]);
      expect((await repos.avoidItems.getAll()).map((x) => x.body), ['Deep squats', 'Fizzy drinks']);
      final undo = await service.deleteAvoid(b);
      expect(await repos.avoidItems.count(), 1);
      await undo();
      expect((await repos.avoidItems.getAll()).map((x) => x.body), ['Deep squats', 'Fizzy drinks']);
    });
  });

  group('fasting', () {
    test('start → stop logs the fast; undo of stop reopens it', () async {
      final (row, _) = await service.startFast();
      expect(row.start, now);
      expect(row.targetHours, 16);
      expect((await service.activeFast())!.id, row.id);
      // A second start returns the running fast.
      final (again, _) = await service.startFast();
      expect(again.id, row.id);
      expect(await repos.fastingSessions.count(), 1);

      now = DateTime(2026, 9, 30, 12, 45);
      final undo = await service.stopFast(row);
      final stopped = (await repos.fastingSessions.byId(row.id))!;
      expect(stopped.end, now);
      final a = await activity();
      expect(a.single.kind, 'body.fast');
      expect(a.single.planetKey, 'body');
      expect(a.single.value, 16.5);
      expect(a.single.payload['reached'], true);
      await undo();
      expect((await repos.fastingSessions.byId(row.id))!.end, isNull);
      expect(await activity(), isEmpty);
    });

    test("the plan's goal is used; stop never ends before the start", () async {
      await service.setFastingPlan(const FastingPlan(targetHours: 18));
      final (row, _) = await service.startFast(at: now.add(const Duration(minutes: 5)));
      expect(row.targetHours, 18);
      await service.stopFast(row);
      expect((await repos.fastingSessions.byId(row.id))!.end, row.start);
    });

    test('edit and delete with undo', () async {
      final (row, _) = await service.startFast(at: DateTime(2026, 9, 28, 20));
      now = DateTime(2026, 9, 29, 12);
      await service.stopFast(row);
      final stopped = (await repos.fastingSessions.byId(row.id))!;
      final undoEdit = await service.editFast(
        stopped,
        start: DateTime(2026, 9, 28, 19),
        end: DateTime(2026, 9, 29, 13),
        targetHours: 18,
        note: 'Ramadan',
      );
      final edited = (await repos.fastingSessions.byId(row.id))!;
      expect(edited.start, DateTime(2026, 9, 28, 19));
      expect(edited.note, 'Ramadan');
      await undoEdit();
      expect((await repos.fastingSessions.byId(row.id))!.note, isNull);
      final undo = await service.deleteFast(stopped);
      expect(await repos.fastingSessions.count(), 0);
      expect(await activity(), isEmpty);
      await undo();
      expect(await repos.fastingSessions.count(), 1);
      expect(await activity(), hasLength(1));
    });

    test('plan settings persist under body.fasting and undo restores the default', () async {
      final undo = await service.setFastingPlan(const FastingPlan(targetHours: 14, lastMealMinutes: 19 * 60));
      expect(await repos.keyValues.getJson(FastingPlan.storageKey), containsPair('lastMeal', '19:00'));
      expect((await service.fastingPlan()).targetHours, 14);
      await undo();
      expect(await repos.keyValues.contains(FastingPlan.storageKey), isFalse);
    });
  });

  group('water', () {
    test('add logs on the Body planet; delete and undo', () async {
      final (row, undoAdd) = await service.addWater(250);
      expect(row.ml, 250);
      expect(row.at, now);
      final a = await activity();
      expect(a.single.kind, 'body.water');
      expect(a.single.value, 250);
      final undo = await service.deleteWater(row);
      expect(await repos.waterLogs.count(), 0);
      expect(await activity(), isEmpty);
      await undo();
      expect(await repos.waterLogs.count(), 1);
      expect(await activity(), hasLength(1));
      await undoAdd();
      expect(await repos.waterLogs.count(), 0);
    });

    test('amounts are clamped; edits keep the day', () async {
      final (row, _) = await service.addWater(99999);
      expect(row.ml, WaterMath.maxAmount);
      await service.updateWater(row, ml: 330, at: DateTime(2026, 9, 29, 9));
      final r = (await repos.waterLogs.byId(row.id))!;
      expect(r.ml, 330);
      expect(r.at, DateTime(2026, 9, 29, 9));
    });

    test('deleting a glass logged by quick add removes its health activity too', () async {
      final row = await repos.waterLogs.insert(WaterLogsCompanion.insert(at: now, ml: 500));
      await repos.activity.log(planetKey: 'health', kind: 'health.water', refTable: 'water_logs', refId: row.id);
      await service.deleteWater(row);
      expect(await activity(), isEmpty);
    });

    test('the target is a plain JSON number the orbit can read; undo removes it', () async {
      expect(await service.watchWaterTarget().first, isNull);
      final undo = await service.setWaterTarget(3000);
      expect(await repos.keyValues.getJson('body.waterTargetMl'), 3000);
      expect(await service.watchWaterTarget().first, 3000);
      final undo2 = await service.setWaterTarget(50);
      expect(await repos.keyValues.getJson('body.waterTargetMl'), WaterMath.minTarget);
      await undo2();
      expect(await repos.keyValues.getJson('body.waterTargetMl'), 3000);
      await undo();
      expect(await repos.keyValues.contains('body.waterTargetMl'), isFalse);
    });
  });

  group('recorder', () {
    test('completions go through the injected recorder (the orbit pulse hub)', () async {
      final calls = <String>[];
      final s = BodyService(
        repos,
        clock: () => now,
        recorder: (kind, table, id, {at, value, payload = const {}}) async => calls.add('$kind|$table|$value'),
      );
      await s.addWater(500);
      expect(calls, ['body.water|water_logs|500.0']);
      expect(await activity(), isEmpty);
    });
  });
}
