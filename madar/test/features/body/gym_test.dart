// The gym's own arithmetic and its writes (Part 8, «#24 – Body / gym»):
// a set, a warm-up, the volume, the heaviest set, his named training days,
// where a picture and a video live, and – the one that must never drift –
// the next load being nothing but a sum over his own rows.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/features/body/body.dart';

import '../../helpers/test_app.dart' show testDatabase;

/// A picker that hands back what the test scripted.
class _Picker implements GymFilePicker {
  _Picker({this.image, this.video});

  PickedGymFile? image;
  PickedGymFile? video;
  int imageCalls = 0;
  int videoCalls = 0;

  @override
  Future<PickedGymFile?> pickImage() async {
    imageCalls++;
    return image;
  }

  @override
  Future<PickedGymFile?> pickVideo() async {
    videoCalls++;
    return video;
  }
}

PickedGymFile _file(String name, {int bytes = 64, String? path}) => PickedGymFile(
  name: name,
  path: path,
  read: () async => Uint8List.fromList(List.filled(bytes, 7)),
);

/// One day of history: the heaviest working set he did that day.
WorkoutEntry _day(DateTime at, {required double? weight, required int reps, String id = 'l'}) => WorkoutEntry(
  id: '$id${at.day}',
  exerciseId: 'ex',
  name: 'squat',
  at: at,
  setLog: [
    LoggedSet(id: '$id${at.day}w', reps: 8, weight: weight == null ? null : weight - 10, warmup: true),
    LoggedSet(id: '$id${at.day}a', reps: reps, weight: weight),
  ],
);

ExerciseProgress _history(List<WorkoutEntry> logs) => ExerciseProgress.build(logs);

void main() {
  group('a set, and what counts as work', () {
    const warm = LoggedSet(id: 'w', reps: 10, weight: 20, warmup: true);
    const a = LoggedSet(id: 'a', reps: 10, weight: 50);
    const b = LoggedSet(id: 'b', reps: 8, weight: 55);
    const c = LoggedSet(id: 'c', reps: 12, weight: 55);

    test('a warm-up happened, and counts for nothing else', () {
      expect(SetMath.working(const [warm, a, b]), [a, b]);
      expect(SetMath.totalReps(const [warm, a, b]), 18, reason: 'the warm-up 10 are not work');
      expect(SetMath.volume(const [warm, a, b]), 10 * 50 + 8 * 55);
      expect(SetMath.topSet(const [warm, a, b]), b);
      expect(SetMath.topSet(const [warm]), isNull, reason: 'a warm-up is never a personal best');
    });

    test('the heaviest set breaks a tie on reps', () {
      expect(SetMath.topSet(const [b, c]), c);
      expect(SetMath.bestReps(const [a, b, c]), c);
    });

    test('nothing to read gives null, not zero', () {
      expect(SetMath.volume(const [LoggedSet(id: 'x', reps: 10)]), isNull, reason: 'no weight: no volume');
      expect(SetMath.totalReps(const [LoggedSet(id: 'x', weight: 10)]), isNull);
      expect(SetMath.summarise(const []), (sets: null, reps: null, weight: null));
    });

    test('the one-line columns are the headline of the set rows', () {
      expect(SetMath.summarise(const [warm, a, b]), (sets: 2, reps: 8, weight: 55.0));
    });

    test('a workout reads its volume from its sets, and an old one from its columns', () {
      final withSets = WorkoutEntry(
        id: 'l1',
        name: 'squat',
        at: _fixed,
        sets: 2,
        reps: 8,
        weight: 55,
        setLog: const [warm, a, b],
      );
      expect(withSets.volume, 10 * 50 + 8 * 55);
      expect(withSets.totalReps, 18);
      expect(withSets.topWeight, 55);
      expect(withSets.topReps, 8);
      final oneLine = WorkoutEntry(id: 'l2', name: 'squat', at: _fixed, sets: 3, reps: 10, weight: 40);
      expect(oneLine.volume, 3 * 10 * 40, reason: 'the older kind of log still reads');
      expect(oneLine.topWeight, 40);
      expect(oneLine.hasSetLog, isFalse);
    });
  });

  group('his next load is a sum over his own rows', () {
    final mon = DateTime(2026, 10, 5, 18);
    final wed = DateTime(2026, 10, 7, 18);
    final fri = DateTime(2026, 10, 9, 18);
    final nextMon = DateTime(2026, 10, 12, 18);

    test('nothing logged: nothing is offered', () {
      final load = NextLoad.of(ExerciseProgress.empty);
      expect(load.basis, LoadBasis.nothingYet);
      expect(load.any, isFalse);
      expect(load.weight, isNull);
    });

    test('one day: his own numbers, unchanged', () {
      final load = NextLoad.of(_history([_day(mon, weight: 50, reps: 10)]));
      expect(load.basis, LoadBasis.lastTime);
      expect(load.weight, 50);
      expect(load.reps, 10);
      expect(load.step, isNull, reason: 'there is no step of his to repeat yet');
      expect(load.sessions, 1);
    });

    test('three rising days: last + the smallest step he took himself', () {
      final load = NextLoad.of(
        _history([
          _day(mon, weight: 40, reps: 10),
          _day(wed, weight: 45, reps: 10),
          _day(fri, weight: 47.5, reps: 10),
        ]),
      );
      expect(load.basis, LoadBasis.sameStep);
      expect(load.last, 47.5);
      expect(load.step, 2.5, reason: 'his steps were 5 then 2.5 – the smaller one is one he has really done');
      expect(load.weight, 50);
      expect(load.reps, 10, reason: 'the reps are his last, never raised');
      expect(load.sessions, 3);
      expect(load.isStepUp, isTrue);
    });

    test('a day he came down: last time, not a step', () {
      final load = NextLoad.of(
        _history([
          _day(mon, weight: 50, reps: 8),
          _day(wed, weight: 55, reps: 8),
          _day(fri, weight: 52.5, reps: 8),
        ]),
      );
      expect(load.basis, LoadBasis.lastTime);
      expect(load.weight, 52.5);
      expect(load.isStepUp, isFalse);
    });

    test('up, then down, then up: still last time – the window holds a fall', () {
      final load = NextLoad.of(
        _history([
          _day(mon, weight: 50, reps: 8),
          _day(wed, weight: 45, reps: 8),
          _day(fri, weight: 50, reps: 8),
        ]),
      );
      expect(load.basis, LoadBasis.lastTime);
      expect(load.weight, 50);
    });

    test('the same weight with more reps is its own story', () {
      final load = NextLoad.of(
        _history([
          _day(wed, weight: 60, reps: 8),
          _day(fri, weight: 60, reps: 10),
        ]),
      );
      expect(load.basis, LoadBasis.repsUp);
      expect(load.weight, 60);
      expect(load.reps, 10);
      expect(load.step, 2, reason: 'the two reps he added himself');
    });

    test('a movement with no weight runs on reps alone', () {
      final load = NextLoad.of(
        _history([
          _day(mon, weight: null, reps: 12),
          _day(wed, weight: null, reps: 14),
          _day(fri, weight: null, reps: 16),
        ]),
      );
      expect(load.byReps, isTrue);
      expect(load.weight, isNull);
      expect(load.basis, LoadBasis.sameStep);
      expect(load.reps, 18, reason: '16 plus the two he added every time');
    });

    test('only the last few days are read', () {
      final logs = [
        for (var i = 0; i < 9; i++) _day(DateTime(2026, 10, 1 + i, 18), weight: 40 + i.toDouble(), reps: 10),
      ];
      final load = NextLoad.of(_history(logs), window: 5);
      expect(load.sessions, 5);
      expect(load.step, 1);
    });

    test('two logs on the same day are one day, read at its heaviest', () {
      final load = NextLoad.of(
        _history([
          _day(mon, weight: 40, reps: 10),
          _day(nextMon, weight: 45, reps: 10, id: 'a'),
          _day(nextMon, weight: 42.5, reps: 12, id: 'b'),
        ]),
      );
      expect(load.sessions, 2);
      expect(load.last, 45);
      expect(load.step, 5);
      expect(load.weight, 50);
    });
  });

  group('what a weekday asks for', () {
    const chest = PlannedExercise(id: 'a', name: 'bench', weekdays: [3], sets: 3, reps: 10, weight: 40);
    const fly = PlannedExercise(id: 'b', name: 'fly', weekdays: [], sets: 3, reps: 12);
    const walk = PlannedExercise(id: 'c', name: 'walk', weekdays: [1], durationMin: 30);
    const paused = PlannedExercise(id: 'd', name: 'swim', weekdays: [1], active: false);
    final monday = DateTime(2026, 10, 12);

    test('with no template the day is read straight off the exercises', () {
      final plan = SessionPlan.forDay(exercises: const [chest, fly, walk, paused], templates: const [], day: monday);
      expect([for (final e in plan) e.id], ['c'], reason: 'only the walk falls on Monday, and the paused swim never');
    });

    test('a template of the day gives the order and the numbers', () {
      const day = WorkoutTemplate(
        id: 't1',
        name: 'يوم صدر',
        weekdays: [1, 4],
        items: [
          TemplateExercise(id: 'i1', exerciseId: 'b', sets: 4, reps: 8, weight: 25, restSec: 120, warmupSets: 1),
          TemplateExercise(id: 'i2', exerciseId: 'a'),
        ],
      );
      final plan = SessionPlan.forDay(exercises: const [chest, fly, walk, paused], templates: const [day], day: monday);
      expect([for (final e in plan) e.id], ['b', 'a', 'c'], reason: 'his order first, then what Monday already had');
      expect(plan.first.sets, 4);
      expect(plan.first.weight, 25);
      expect(plan.first.restSec, 120);
      expect(plan.first.warmupSets, 1);
      expect(plan.first.weekdays, [1], reason: 'the day it is being read for');
      expect(plan[1].sets, 3, reason: 'nothing set: the exercise keeps its own numbers');
      expect(plan[1].weight, 40);
    });

    test('a paused or empty template is not a day', () {
      const off = WorkoutTemplate(id: 't', name: 'x', weekdays: [1], active: false, items: [TemplateExercise(id: 'i', exerciseId: 'b')]);
      const empty = WorkoutTemplate(id: 't2', name: 'y', weekdays: [1]);
      expect(off.trainsOn(monday), isFalse);
      expect(empty.trainsOn(monday), isFalse);
      final plan = SessionPlan.forDay(exercises: const [chest, fly], templates: const [off, empty], day: monday);
      expect(plan, isEmpty);
      expect(SessionPlan.templatesOn(const [off, empty], monday), isEmpty);
    });

    test('an exercise named twice in a day is done once', () {
      const twice = WorkoutTemplate(
        id: 't',
        name: 'x',
        weekdays: [1],
        items: [TemplateExercise(id: 'i1', exerciseId: 'b'), TemplateExercise(id: 'i2', exerciseId: 'b')],
      );
      final plan = SessionPlan.forDay(exercises: const [fly], templates: const [twice], day: monday);
      expect(plan, hasLength(1));
    });

    test('the sets of a session: warm-ups first, and at least one set', () {
      const e = PlannedExercise(id: 'a', name: 'bench', sets: 4, warmupSets: 2);
      expect(SessionSets.countOf(e), 4);
      expect([for (var i = 0; i < 4; i++) SessionSets.isWarmup(e, i)], [true, true, false, false]);
      expect(SessionSets.countOf(const PlannedExercise(id: 'b', name: 'x')), 1);
      expect(SessionSets.isWarmup(const PlannedExercise(id: 'b', name: 'x'), 0), isFalse);
      expect(e.workingSets, 2);
      expect(const PlannedExercise(id: 'c', name: 'x', sets: 2, warmupSets: 5).workingSets, isNull);
    });
  });

  group('where a picture and a video live', () {
    test('a link, a host he typed without the scheme, and a path on the phone', () {
      expect(GymVideo.parse(null), isNull);
      expect(GymVideo.parse('   '), isNull);
      final link = GymVideo.parse('https://example.com/squat')!;
      expect(link.kind, GymVideoKind.link);
      expect(link.label, 'example.com');
      final bare = GymVideo.parse('example.com/squat')!;
      expect(bare.kind, GymVideoKind.link);
      expect(bare.raw, 'https://example.com/squat');
      final file = GymVideo.parse('/storage/emulated/0/Movies/squat.mp4')!;
      expect(file.kind, GymVideoKind.file);
      expect(file.label, 'squat.mp4');
      expect(file.exists, isFalse, reason: 'it is not on this machine');
      expect(link.exists, isTrue, reason: 'Madar never goes near the network to check a link');
      expect(GymVideo.parse('my squat clip')!.kind, GymVideoKind.file);
    });

    test('a picture is copied in, so his gallery is free to lose it', () async {
      final dir = Directory.systemTemp.createTempSync('gym_media');
      addTearDown(() => dir.deleteSync(recursive: true));
      final picker = _Picker(image: _file('IMG_1.jpg'));
      final media = GymMedia.at(dir, picker: picker);
      final result = await media.pickPhoto();
      expect(result.ok, isTrue);
      expect(picker.imageCalls, 1);
      final name = result.value!;
      expect(name.endsWith('.jpg'), isTrue);
      expect(name.contains('/'), isFalse, reason: 'a file name, never a path into the gallery');
      final file = await media.photoFile(name);
      expect(file, isNotNull);
      expect(file!.existsSync(), isTrue);
      await media.removePhotos([name]);
      expect(await media.photoFile(name), isNull);
    });

    test('a picture Madar cannot show, one too big, and a cancelled pick', () async {
      final dir = Directory.systemTemp.createTempSync('gym_media');
      addTearDown(() => dir.deleteSync(recursive: true));
      final picker = _Picker();
      final media = GymMedia.at(dir, picker: picker);
      expect((await media.pickPhoto()).error, GymMediaError.cancelled);
      picker.image = _file('notes.txt');
      expect((await media.pickPhoto()).error, GymMediaError.unsupported);
      picker.image = _file('huge.png', bytes: GymMedia.maxPhotoBytes + 1);
      expect((await media.pickPhoto()).error, GymMediaError.tooLarge);
      expect(dir.listSync(), isEmpty, reason: 'nothing refused is left behind');
    });

    test('a video is remembered where it is, never copied', () async {
      final dir = Directory.systemTemp.createTempSync('gym_media');
      addTearDown(() => dir.deleteSync(recursive: true));
      final picker = _Picker(video: _file('squat.mp4', bytes: 1024, path: '/movies/squat.mp4'));
      final media = GymMedia.at(dir, picker: picker);
      final result = await media.pickVideo();
      expect(result.value, '/movies/squat.mp4');
      expect(dir.listSync(), isEmpty, reason: 'the clip stays in his folder: Madar holds the place only');
      // A picker that gives no path has nothing to remember.
      picker.video = _file('squat.mp4');
      expect((await media.pickVideo()).error, GymMediaError.noPath);
    });

    test('a picture that came in with a backup as a full path is not ours to delete', () async {
      final dir = Directory.systemTemp.createTempSync('gym_media');
      addTearDown(() => dir.deleteSync(recursive: true));
      final outside = File('${dir.path}/outside.jpg')..writeAsBytesSync([1, 2, 3]);
      final media = GymMedia.at(Directory('${dir.path}/own'));
      expect(await media.photoFile(outside.path), isNotNull);
      await media.removePhotos([outside.path]);
      expect(outside.existsSync(), isTrue);
    });
  });

  group('the writes', () {
    late MadarDatabase db;
    late Repositories repos;
    late BodyService service;
    final now = DateTime(2026, 10, 12, 18, 30);

    setUp(() {
      db = testDatabase();
      repos = Repositories(db);
      service = BodyService(repos, clock: () => now);
    });

    tearDown(() => db.close());

    Future<ExerciseRow> exercise() async {
      final (row, _) = await service.addExercise(
        const ExerciseDraft(
          name: 'قرفصاء بالبار',
          weekdays: [1, 4],
          sets: 3,
          reps: 10,
          weight: 50,
          muscles: ['أرجل', '  '],
          restSec: 90,
          warmupSets: 1,
          photo: 'abc.jpg',
          video: ' https://example.com/squat ',
        ),
      );
      return row;
    }

    test('an exercise carries the machine, the movement and his own words', () async {
      final row = await exercise();
      expect(row.photo, 'abc.jpg');
      expect(row.video, 'https://example.com/squat');
      expect(row.muscles, ['أرجل'], reason: 'blanks are dropped, his words kept');
      expect(row.restSec, 90);
      expect(row.warmupSets, 1);
    });

    test('a fresh install has no set, no template and no media', () async {
      expect(await repos.workoutSets.getAll(), isEmpty);
      expect(await repos.workoutTemplates.getAll(), isEmpty);
      expect(await repos.workoutTemplateItems.getAll(), isEmpty);
    });

    test('logging a session writes its sets in order, and its headline is the heaviest', () async {
      final row = await exercise();
      final (log, undo) = await service.logWorkout(
        WorkoutDraft(exerciseId: row.id, name: row.name, at: now),
        sets: const [
          SetDraft(reps: 10, weight: 30, warmup: true),
          SetDraft(reps: 10, weight: 50),
          SetDraft(reps: 8, weight: 55),
        ],
      );
      final sets = await service.setsOf(log.id);
      expect(sets, hasLength(3));
      expect(sets.first.warmup, isTrue);
      expect([for (final s in sets) s.weight], [30, 50, 55]);
      expect(log.sets, 2, reason: 'two working sets');
      expect(log.reps, 8);
      expect(log.weight, 55, reason: 'the heaviest working set is the headline');
      // The planet felt it.
      expect((await repos.activityLog.getAll()).single.refId, log.id);

      await undo();
      expect(await repos.workoutLogs.getAll(), isEmpty);
      expect(await repos.workoutSets.getAll(), isEmpty, reason: 'undo takes the sets with it');
      expect(await repos.activityLog.getAll(), isEmpty);
    });

    test('deleting a logged session, and undoing it, brings its sets back', () async {
      final row = await exercise();
      final (log, _) = await service.logWorkout(
        WorkoutDraft(exerciseId: row.id, name: row.name, at: now),
        sets: const [SetDraft(reps: 10, weight: 50), SetDraft(reps: 9, weight: 50)],
      );
      final undo = await service.deleteWorkout(log);
      expect(await repos.workoutSets.getAll(), isEmpty);
      await undo();
      final back = await service.setsOf(log.id);
      expect(back, hasLength(2));
      expect([for (final s in back) s.reps], [10, 9]);
      expect((await repos.workoutLogs.byId(log.id))!.weight, 50);
    });

    test('editing a session replaces its sets, and undo restores the old ones exactly', () async {
      final row = await exercise();
      final (log, _) = await service.logWorkout(
        WorkoutDraft(exerciseId: row.id, name: row.name, at: now),
        sets: const [SetDraft(reps: 10, weight: 50)],
      );
      final undo = await service.updateWorkout(
        log,
        WorkoutDraft(exerciseId: row.id, name: row.name, at: now),
        sets: const [SetDraft(reps: 12, weight: 60), SetDraft(reps: 12, weight: 60)],
      );
      expect((await repos.workoutLogs.byId(log.id))!.weight, 60);
      expect(await service.setsOf(log.id), hasLength(2));
      await undo();
      final back = await service.setsOf(log.id);
      expect(back, hasLength(1));
      expect(back.single.weight, 50);
      expect((await repos.workoutLogs.byId(log.id))!.weight, 50);
    });

    test('the sets stream reads only the days asked for', () async {
      final row = await exercise();
      await service.logWorkout(
        WorkoutDraft(exerciseId: row.id, name: row.name, at: DateTime(2026, 1, 1)),
        sets: const [SetDraft(reps: 10, weight: 20)],
      );
      await service.logWorkout(
        WorkoutDraft(exerciseId: row.id, name: row.name, at: now),
        sets: const [SetDraft(reps: 10, weight: 50)],
      );
      final recent = await service.watchSets(since: DateTime(2026, 10, 1)).first;
      expect(recent, hasLength(1));
      expect(recent.single.weight, 50);
    });

    test('the picture and the video go on and off the exercise, each with its undo', () async {
      final row = await exercise();
      final undoPhoto = await service.setExercisePhoto(row, null);
      expect((await repos.exercises.byId(row.id))!.photo, isNull);
      await undoPhoto();
      expect((await repos.exercises.byId(row.id))!.photo, 'abc.jpg');
      final undoVideo = await service.setExerciseVideo(row, '/movies/squat.mp4');
      expect((await repos.exercises.byId(row.id))!.video, '/movies/squat.mp4');
      await undoVideo();
      expect((await repos.exercises.byId(row.id))!.video, 'https://example.com/squat');
    });

    test('a named day: its exercises, its numbers, and undo on every destructive step', () async {
      final row = await exercise();
      final (day, _) = await service.addTemplate(
        const TemplateDraft(name: '  يوم أرجل  ', weekdays: [4, 1, 1, 9], notes: '   '),
      );
      expect(day.name, 'يوم أرجل');
      expect(day.weekdays, [1, 4]);
      expect(day.notes, isNull);
      expect(day.active, isTrue);

      final (item, undoAdd) = await service.addTemplateItem(day.id, TemplateItemDraft(exerciseId: row.id));
      expect(item.sets, isNull, reason: 'empty means: whatever the exercise says');
      final undoNumbers = await service.updateTemplateItem(
        item,
        TemplateItemDraft(exerciseId: row.id, sets: 5, reps: 5, weight: 80, restSec: 150, warmupSets: 2),
      );
      final tuned = (await repos.workoutTemplateItems.byId(item.id))!;
      expect((tuned.sets, tuned.reps, tuned.weight, tuned.restSec, tuned.warmupSets), (5, 5, 80.0, 150, 2));
      await undoNumbers();
      expect((await repos.workoutTemplateItems.byId(item.id))!.sets, isNull);
      await undoAdd();
      expect(await repos.workoutTemplateItems.getAll(), isEmpty);

      // Deleting the day takes its lines with it, and undo brings them back.
      await service.addTemplateItem(day.id, TemplateItemDraft(exerciseId: row.id));
      final undoDelete = await service.deleteTemplate(day);
      expect(await repos.workoutTemplates.getAll(), isEmpty);
      expect(await repos.workoutTemplateItems.getAll(), isEmpty);
      await undoDelete();
      expect((await repos.workoutTemplates.byId(day.id))!.name, 'يوم أرجل');
      expect(await repos.workoutTemplateItems.getAll(), hasLength(1));
      // His exercise was never touched by any of it.
      expect((await repos.exercises.byId(row.id))!.name, 'قرفصاء بالبار');
    });

    test('one exercise of a template, removed and put back', () async {
      final row = await exercise();
      final (day, _) = await service.addTemplate(const TemplateDraft(name: 'يوم صدر', weekdays: [1]));
      final (item, _) = await service.addTemplateItem(day.id, TemplateItemDraft(exerciseId: row.id));
      final undo = await service.removeTemplateItem(item);
      expect(await repos.workoutTemplateItems.getAll(), isEmpty);
      await undo();
      expect((await repos.workoutTemplateItems.byId(item.id))!.exerciseId, row.id);
    });
  });
}

final DateTime _fixed = DateTime(2026, 10, 12, 18);
