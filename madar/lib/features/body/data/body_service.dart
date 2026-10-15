import 'dart:async';

import 'package:drift/drift.dart';

import '../../../core/db/database.dart';
import '../../../core/db/repositories/repositories.dart';
import '../domain/fasting.dart';
import '../domain/training.dart';
import '../domain/water.dart';

/// Reverses one change (the UI wraps it in an undo toast).
typedef BodyUndo = Future<void> Function();

/// Logs a completion on the Body planet. The default writes an
/// `activity_log` row; the app routes it through the orbit's pulse hub so the
/// planet flares at once.
typedef BodyActivityRecorder =
    Future<void> Function(
      String kind,
      String? refTable,
      String? refId, {
      DateTime? at,
      double? value,
      Map<String, Object?> payload,
    });

/// A new or edited exercise of the training plan.
class ExerciseDraft {
  const ExerciseDraft({
    required this.name,
    this.weekdays = const [],
    this.sets,
    this.reps,
    this.durationMin,
    this.weight,
    this.notes,
    this.active = true,
    this.photo,
    this.video,
    this.muscles = const [],
    this.restSec,
    this.warmupSets,
  });

  final String name;
  final List<int> weekdays;
  final int? sets;
  final int? reps;
  final int? durationMin;
  final double? weight;
  final String? notes;
  final bool active;

  /// A file name in Madar's own folder (`gym_media.dart`).
  final String? photo;

  /// A link, or a path to his own clip. Never copied.
  final String? video;
  final List<String> muscles;
  final int? restSec;
  final int? warmupSets;
}

/// One set of a workout he is logging.
class SetDraft {
  const SetDraft({this.reps, this.weight, this.warmup = false});

  final int? reps;
  final double? weight;
  final bool warmup;
}

/// A new or edited template: a named training day of his own.
class TemplateDraft {
  const TemplateDraft({required this.name, this.weekdays = const [], this.notes, this.active = true});

  final String name;
  final List<int> weekdays;
  final String? notes;
  final bool active;
}

/// One exercise inside a template, with the numbers that day gives it.
class TemplateItemDraft {
  const TemplateItemDraft({required this.exerciseId, this.sets, this.reps, this.weight, this.restSec, this.warmupSets});

  final String exerciseId;
  final int? sets;
  final int? reps;
  final double? weight;
  final int? restSec;
  final int? warmupSets;
}

/// A new or edited workout log.
class WorkoutDraft {
  const WorkoutDraft({
    required this.name,
    required this.at,
    this.exerciseId,
    this.sets,
    this.reps,
    this.weight,
    this.durationMin,
    this.notes,
  });

  final String? exerciseId;
  final String name;
  final DateTime at;
  final int? sets;
  final int? reps;
  final double? weight;
  final int? durationMin;
  final String? notes;
}

String? _clean(String? s) {
  final t = s?.trim();
  return t == null || t.isEmpty ? null : t;
}

int? _positiveInt(int? v) => v == null || v <= 0 ? null : v;
double? _positive(double? v) => v == null || v <= 0 ? null : v;

/// Every write of the Body planet: the training plan and its logs, the
/// "avoid" list, fasting sessions and settings, water and its daily target.
/// Each write returns a [BodyUndo] that restores the exact prior state.
/// Completions (a workout, a glass, a finished fast) are logged on the
/// `body` planet so the orbit and the Neglect Radar react.
class BodyService {
  BodyService(this.repos, {DateTime Function()? clock, this.recorder}) : clock = clock ?? DateTime.now;

  final Repositories repos;
  final DateTime Function() clock;

  /// Null: completions are written straight to `activity_log`.
  final BodyActivityRecorder? recorder;

  static const String planetKey = 'body';
  static const String kindWorkout = 'body.workout';
  static const String kindWater = 'body.water';
  static const String kindFast = 'body.fast';

  static final KvKey<FastingPlan> fastingPlanKey = KvKey.json<FastingPlan>(
    FastingPlan.storageKey,
    fromJson: FastingPlan.fromJson,
    toJson: (p) => p.toJson(),
  );
  static final KvKey<int> waterTargetKey = KvKey.integer(WaterMath.targetKey);

  MadarDatabase get _db => repos.db;

  Future<void> _record(String kind, String table, String id, {DateTime? at, double? value, Map<String, Object?> payload = const {}}) {
    final r = recorder;
    if (r != null) return r(kind, table, id, at: at, value: value, payload: payload);
    return repos.activity.log(
      planetKey: planetKey,
      kind: kind,
      refTable: table,
      refId: id,
      at: at ?? clock(),
      value: value,
      payload: payload,
    );
  }

  /// Removes the activity logged for a row ([kind] null: every kind, e.g. a
  /// glass logged by home's quick add as `health.water`).
  Future<List<ActivityRow>> _unrecord(String table, String id, [String? kind]) =>
      repos.activity.removeFor(refTable: table, refId: id, kind: kind);

  // ------------------------------------------------------------ plan ----

  /// The training plan in the user's order.
  Stream<List<ExerciseRow>> watchExercises() => repos.exercises.watchAll();

  ExercisesCompanion _exercise(ExerciseDraft d) => ExercisesCompanion(
    name: Value(d.name.trim()),
    weekdays: Value(({for (final w in d.weekdays) if (w >= 1 && w <= 7) w}.toList()..sort())),
    sets: Value(_positiveInt(d.sets)),
    reps: Value(_positiveInt(d.reps)),
    durationMin: Value(_positiveInt(d.durationMin)),
    weight: Value(_positive(d.weight)),
    notes: Value(_clean(d.notes)),
    active: Value(d.active),
    photo: Value(_clean(d.photo)),
    video: Value(_clean(d.video)),
    muscles: Value([
      for (final m in d.muscles)
        if (m.trim().isNotEmpty) m.trim(),
    ]),
    restSec: Value(_positiveInt(d.restSec)),
    warmupSets: Value(_positiveInt(d.warmupSets)),
  );

  Future<(ExerciseRow, BodyUndo)> addExercise(ExerciseDraft d) async {
    final row = await repos.exercises.insert(_exercise(d));
    return (row, () async => repos.exercises.delete(row.id).then((_) {}));
  }

  Future<BodyUndo> updateExercise(ExerciseRow row, ExerciseDraft d) async {
    await repos.exercises.update(_exercise(d).copyWith(id: Value(row.id)));
    return () => repos.exercises.update(row);
  }

  Future<(ExerciseRow, BodyUndo)> duplicateExercise(ExerciseRow row, {String? name}) async {
    final copy = await repos.exercises.duplicate(row.id, overrides: {'name': ?name});
    return (copy, () async => repos.exercises.delete(copy.id).then((_) {}));
  }

  Future<BodyUndo> setExerciseActive(ExerciseRow row, bool active) async {
    await repos.exercises.setColumn(row.id, 'active', active);
    return () => repos.exercises.setColumn(row.id, 'active', row.active);
  }

  /// Deletes the exercise; its logged workouts stay in the history.
  Future<BodyUndo> deleteExercise(ExerciseRow row) async {
    final gone = await repos.exercises.delete(row.id);
    return () async {
      if (gone != null) await repos.exercises.restore(gone);
    };
  }

  Future<void> reorderExercises(List<String> ids) => repos.exercises.reorder(ids);

  /// Puts the machine's picture on the exercise (a file name in Madar's own
  /// folder, or null to take it off). The **file** is the caller's to
  /// delete, and only once the undo chance has passed – see
  /// `GymActions.pickPhoto`.
  Future<BodyUndo> setExercisePhoto(ExerciseRow row, String? photo) async {
    await repos.exercises.setColumn(row.id, 'photo', _clean(photo));
    return () => repos.exercises.setColumn(row.id, 'photo', row.photo);
  }

  /// Remembers where the movement's clip is (a link, or a path to his own
  /// file). The clip itself is never read, copied or deleted.
  Future<BodyUndo> setExerciseVideo(ExerciseRow row, String? video) async {
    await repos.exercises.setColumn(row.id, 'video', _clean(video));
    return () => repos.exercises.setColumn(row.id, 'video', row.video);
  }

  // -------------------------------------------------------- workouts ----

  /// Workout logs at or after [since] (all when null), newest first.
  Stream<List<WorkoutLogRow>> watchWorkouts({DateTime? since}) {
    final q = _db.select(_db.workoutLogs)
      ..orderBy([(t) => OrderingTerm.desc(t.at), (t) => OrderingTerm.desc(t.createdAt)]);
    if (since != null) q.where((t) => t.at.isBiggerOrEqualValue(since));
    return q.watch();
  }

  WorkoutLogsCompanion _workout(WorkoutDraft d) => WorkoutLogsCompanion(
    exerciseId: Value(d.exerciseId),
    name: Value(d.name.trim()),
    at: Value(d.at),
    sets: Value(_positiveInt(d.sets)),
    reps: Value(_positiveInt(d.reps)),
    weight: Value(_positive(d.weight)),
    durationMin: Value(_positiveInt(d.durationMin)),
    notes: Value(_clean(d.notes)),
  );

  /// The sets of workouts at or after [since], in the order they were
  /// done. One query, joined on the log so an old log far back in the
  /// history is not read for nothing.
  Stream<List<WorkoutSetRow>> watchSets({required DateTime since}) {
    final q = _db.select(_db.workoutSets).join([
      innerJoin(_db.workoutLogs, _db.workoutLogs.id.equalsExp(_db.workoutSets.logId)),
    ])
      ..where(_db.workoutLogs.at.isBiggerOrEqualValue(since))
      ..orderBy([OrderingTerm.asc(_db.workoutSets.sortOrder), OrderingTerm.asc(_db.workoutSets.createdAt)]);
    return q.map((r) => r.readTable(_db.workoutSets)).watch();
  }

  /// One log's sets, in order.
  Future<List<WorkoutSetRow>> setsOf(String logId) async {
    final rows = await repos.workoutSets.getAll(where: (t) => t.logId.equals(logId));
    return rows;
  }

  /// The one-line columns that stand for [sets]: how many working sets, and
  /// the reps and weight of the heaviest of them. The volume and the
  /// personal best are never read from these – they are summed over the set
  /// rows themselves.
  static ({int? sets, int? reps, double? weight}) summarise(List<SetDraft> sets) => SetMath.summarise([
    for (final s in sets) LoggedSet(id: '', reps: _positiveInt(s.reps), weight: _positive(s.weight), warmup: s.warmup),
  ]);

  Future<void> _writeSets(String logId, List<SetDraft> sets) async {
    for (var i = 0; i < sets.length; i++) {
      final s = sets[i];
      await repos.workoutSets.insert(
        WorkoutSetsCompanion.insert(
          logId: logId,
          reps: Value(_positiveInt(s.reps)),
          weight: Value(_positive(s.weight)),
          warmup: Value(s.warmup),
          sortOrder: Value(i),
        ),
      );
    }
  }

  /// Logs a workout (a planned exercise marked done, or an extra one).
  ///
  /// With [sets] it is the gym's kind of log: one row per set he actually
  /// did, warm-ups included, and the log's own sets / reps / weight become
  /// the headline of those rows ([summarise]).
  Future<(WorkoutLogRow, BodyUndo)> logWorkout(WorkoutDraft d, {List<SetDraft> sets = const []}) async {
    final s = sets.isEmpty ? (sets: _positiveInt(d.sets), reps: _positiveInt(d.reps), weight: _positive(d.weight)) : summarise(sets);
    final row = await repos.workoutLogs.insert(
      WorkoutLogsCompanion.insert(
        exerciseId: Value(d.exerciseId),
        name: d.name.trim(),
        at: d.at,
        sets: Value(s.sets),
        reps: Value(s.reps),
        weight: Value(s.weight),
        durationMin: Value(_positiveInt(d.durationMin)),
        notes: Value(_clean(d.notes)),
      ),
    );
    if (sets.isNotEmpty) await _writeSets(row.id, sets);
    await _record(
      kindWorkout,
      'workout_logs',
      row.id,
      at: row.at,
      value: row.durationMin?.toDouble(),
      payload: {'exerciseId': ?row.exerciseId, 'name': row.name},
    );
    return (
      row,
      () async {
        await repos.workoutSets.deleteWhere((t) => t.logId.equals(row.id));
        await repos.workoutLogs.delete(row.id);
        await _unrecord('workout_logs', row.id, kindWorkout);
      },
    );
  }

  /// Edits a log. With [sets] its set rows are replaced wholesale; undo
  /// puts the old ones back exactly.
  Future<BodyUndo> updateWorkout(WorkoutLogRow row, WorkoutDraft d, {List<SetDraft>? sets}) async {
    final before = sets == null ? const <WorkoutSetRow>[] : await setsOf(row.id);
    var companion = _workout(d).copyWith(id: Value(row.id));
    if (sets != null) {
      final s = summarise(sets);
      companion = companion.copyWith(sets: Value(s.sets), reps: Value(s.reps), weight: Value(s.weight));
      await repos.workoutSets.deleteWhere((t) => t.logId.equals(row.id));
      await _writeSets(row.id, sets);
    }
    await repos.workoutLogs.update(companion);
    return () async {
      if (sets != null) {
        await repos.workoutSets.deleteWhere((t) => t.logId.equals(row.id));
        await repos.workoutSets.restoreAll(before);
      }
      await repos.workoutLogs.update(row);
    };
  }

  Future<BodyUndo> deleteWorkout(WorkoutLogRow row) async {
    final sets = await repos.workoutSets.deleteWhere((t) => t.logId.equals(row.id));
    final gone = await repos.workoutLogs.delete(row.id);
    final activity = await _unrecord('workout_logs', row.id);
    return () async {
      if (gone != null) await repos.workoutLogs.restore(gone);
      await repos.workoutSets.restoreAll(sets);
      await repos.activityLog.restoreAll(activity);
    };
  }

  // -------------------------------------------------------- templates ----

  /// His named training days, in his order.
  Stream<List<WorkoutTemplateRow>> watchTemplates() => repos.workoutTemplates.watchAll();

  /// Every template's exercises, in his order (the provider groups them).
  Stream<List<WorkoutTemplateItemRow>> watchTemplateItems() => repos.workoutTemplateItems.watchAll();

  WorkoutTemplatesCompanion _template(TemplateDraft d) => WorkoutTemplatesCompanion(
    name: Value(d.name.trim()),
    weekdays: Value(({for (final w in d.weekdays) if (w >= 1 && w <= 7) w}.toList()..sort())),
    notes: Value(_clean(d.notes)),
    active: Value(d.active),
  );

  Future<(WorkoutTemplateRow, BodyUndo)> addTemplate(TemplateDraft d) async {
    final row = await repos.workoutTemplates.insert(_template(d));
    return (row, () async => repos.workoutTemplates.delete(row.id).then((_) {}));
  }

  Future<BodyUndo> updateTemplate(WorkoutTemplateRow row, TemplateDraft d) async {
    await repos.workoutTemplates.update(_template(d).copyWith(id: Value(row.id)));
    return () => repos.workoutTemplates.update(row);
  }

  /// Deletes a template and the rows that said which exercises it holds.
  /// His exercises themselves are never touched, and undo puts the day
  /// back whole.
  Future<BodyUndo> deleteTemplate(WorkoutTemplateRow row) async {
    final items = await repos.workoutTemplateItems.deleteWhere((t) => t.templateId.equals(row.id));
    final gone = await repos.workoutTemplates.delete(row.id);
    return () async {
      if (gone != null) await repos.workoutTemplates.restore(gone);
      await repos.workoutTemplateItems.restoreAll(items);
    };
  }

  Future<void> reorderTemplates(List<String> ids) => repos.workoutTemplates.reorder(ids);

  WorkoutTemplateItemsCompanion _templateItem(String templateId, TemplateItemDraft d) => WorkoutTemplateItemsCompanion(
    templateId: Value(templateId),
    exerciseId: Value(d.exerciseId),
    sets: Value(_positiveInt(d.sets)),
    reps: Value(_positiveInt(d.reps)),
    weight: Value(_positive(d.weight)),
    restSec: Value(_positiveInt(d.restSec)),
    warmupSets: Value(_positiveInt(d.warmupSets)),
  );

  Future<(WorkoutTemplateItemRow, BodyUndo)> addTemplateItem(String templateId, TemplateItemDraft d) async {
    final row = await repos.workoutTemplateItems.insert(
      WorkoutTemplateItemsCompanion.insert(
        templateId: templateId,
        exerciseId: d.exerciseId,
        sets: Value(_positiveInt(d.sets)),
        reps: Value(_positiveInt(d.reps)),
        weight: Value(_positive(d.weight)),
        restSec: Value(_positiveInt(d.restSec)),
        warmupSets: Value(_positiveInt(d.warmupSets)),
      ),
    );
    return (row, () async => repos.workoutTemplateItems.delete(row.id).then((_) {}));
  }

  Future<BodyUndo> updateTemplateItem(WorkoutTemplateItemRow row, TemplateItemDraft d) async {
    await repos.workoutTemplateItems.update(_templateItem(row.templateId, d).copyWith(id: Value(row.id)));
    return () => repos.workoutTemplateItems.update(row);
  }

  Future<BodyUndo> removeTemplateItem(WorkoutTemplateItemRow row) async {
    final gone = await repos.workoutTemplateItems.delete(row.id);
    return () async {
      if (gone != null) await repos.workoutTemplateItems.restore(gone);
    };
  }

  Future<void> reorderTemplateItems(List<String> ids) => repos.workoutTemplateItems.reorder(ids);

  // ----------------------------------------------------------- avoid ----

  Stream<List<AvoidItemRow>> watchAvoid() => repos.avoidItems.watchAll();

  Future<(AvoidItemRow, BodyUndo)> addAvoid(String body, {String? reason}) async {
    final row = await repos.avoidItems.insert(AvoidItemsCompanion.insert(body: body.trim(), reason: Value(_clean(reason))));
    return (row, () async => repos.avoidItems.delete(row.id).then((_) {}));
  }

  Future<BodyUndo> updateAvoid(AvoidItemRow row, String body, {String? reason}) async {
    await repos.avoidItems.update(
      AvoidItemsCompanion(id: Value(row.id), body: Value(body.trim()), reason: Value(_clean(reason))),
    );
    return () => repos.avoidItems.update(row);
  }

  Future<BodyUndo> deleteAvoid(AvoidItemRow row) async {
    final gone = await repos.avoidItems.delete(row.id);
    return () async {
      if (gone != null) await repos.avoidItems.restore(gone);
    };
  }

  Future<void> reorderAvoid(List<String> ids) => repos.avoidItems.reorder(ids);

  // --------------------------------------------------------- fasting ----

  /// Every fast, newest start first.
  Stream<List<FastingSessionRow>> watchFasts() =>
      (_db.select(_db.fastingSessions)..orderBy([(t) => OrderingTerm.desc(t.start)])).watch();

  Stream<FastingPlan> watchFastingPlan() => repos.keyValues.watch(fastingPlanKey).map((p) => p ?? const FastingPlan());

  Future<FastingPlan> fastingPlan() async => await repos.keyValues.get(fastingPlanKey) ?? const FastingPlan();

  Future<BodyUndo> setFastingPlan(FastingPlan plan) async {
    final had = await repos.keyValues.contains(FastingPlan.storageKey);
    final before = await repos.keyValues.getJson(FastingPlan.storageKey);
    await repos.keyValues.set(fastingPlanKey, plan);
    return () async {
      if (had) {
        await repos.keyValues.setJson(FastingPlan.storageKey, before);
      } else {
        await repos.keyValues.remove(FastingPlan.storageKey);
      }
    };
  }

  Future<FastingSessionRow?> activeFast() async {
    final rows = await (_db.select(_db.fastingSessions)
          ..where((t) => t.end.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.start)]))
        .get();
    return rows.isEmpty ? null : rows.first;
  }

  /// Starts a fast at [at] (now by default) with the plan's goal unless
  /// [targetHours] is given. A fast already running is returned as is.
  Future<(FastingSessionRow, BodyUndo)> startFast({DateTime? at, double? targetHours, String? note}) async {
    final running = await activeFast();
    if (running != null) return (running, () async {});
    final hours = targetHours ?? (await fastingPlan()).targetHours;
    final start = at ?? clock();
    final row = await repos.fastingSessions.insert(
      FastingSessionsCompanion.insert(start: start, targetHours: hours, note: Value(_clean(note))),
    );
    return (row, () async => repos.fastingSessions.delete(row.id).then((_) {}));
  }

  /// Ends [row] at [at] (now by default, never before its start) and logs it
  /// on the planet (value: hours fasted).
  Future<BodyUndo> stopFast(FastingSessionRow row, {DateTime? at}) async {
    var end = at ?? clock();
    if (end.isBefore(row.start)) end = row.start;
    await repos.fastingSessions.setColumn(row.id, 'end', end);
    final span = FastingSpan(id: row.id, start: row.start, end: end, targetHours: row.targetHours);
    final hours = span.duration(end).inMinutes / 60;
    await _record(
      kindFast,
      'fasting_sessions',
      row.id,
      at: end,
      value: double.parse(hours.toStringAsFixed(2)),
      payload: {'targetHours': row.targetHours, 'reached': span.reached(end)},
    );
    return () async {
      await repos.fastingSessions.setColumn(row.id, 'end', null);
      await _unrecord('fasting_sessions', row.id, kindFast);
    };
  }

  /// Edits a fast's times, goal or note (a finished fast stays finished).
  Future<BodyUndo> editFast(
    FastingSessionRow row, {
    required DateTime start,
    DateTime? end,
    required double targetHours,
    String? note,
  }) async {
    final fixedEnd = end != null && end.isBefore(start) ? start : end;
    await repos.fastingSessions.update(
      FastingSessionsCompanion(
        id: Value(row.id),
        start: Value(start),
        end: Value(fixedEnd),
        targetHours: Value(targetHours),
        note: Value(_clean(note)),
      ),
    );
    return () => repos.fastingSessions.update(row);
  }

  Future<BodyUndo> deleteFast(FastingSessionRow row) async {
    final gone = await repos.fastingSessions.delete(row.id);
    final activity = await _unrecord('fasting_sessions', row.id);
    return () async {
      if (gone != null) await repos.fastingSessions.restore(gone);
      await repos.activityLog.restoreAll(activity);
    };
  }

  // ----------------------------------------------------------- water ----

  /// Water logs at or after [since], newest first.
  Stream<List<WaterLogRow>> watchWater({required DateTime since}) =>
      (_db.select(_db.waterLogs)
            ..where((t) => t.at.isBiggerOrEqualValue(since))
            ..orderBy([(t) => OrderingTerm.desc(t.at), (t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  /// The stored daily target (null until the user sets one).
  Stream<int?> watchWaterTarget() => repos.keyValues.watchJson(WaterMath.targetKey).map((j) => j is num ? j.round() : null);

  Future<BodyUndo> setWaterTarget(int ml) async {
    final before = await repos.keyValues.getJson(WaterMath.targetKey);
    await repos.keyValues.set(waterTargetKey, ml.clamp(WaterMath.minTarget, WaterMath.maxTarget));
    return () async {
      if (before == null) {
        await repos.keyValues.remove(WaterMath.targetKey);
      } else {
        await repos.keyValues.setJson(WaterMath.targetKey, before);
      }
    };
  }

  Future<(WaterLogRow, BodyUndo)> addWater(int ml, {DateTime? at}) async {
    final when = at ?? clock();
    final amount = ml.clamp(WaterMath.minAmount, WaterMath.maxAmount);
    final row = await repos.waterLogs.insert(WaterLogsCompanion.insert(at: when, ml: amount));
    await _record(kindWater, 'water_logs', row.id, at: when, value: amount.toDouble());
    return (
      row,
      () async {
        await repos.waterLogs.delete(row.id);
        await _unrecord('water_logs', row.id, kindWater);
      },
    );
  }

  Future<BodyUndo> updateWater(WaterLogRow row, {required int ml, DateTime? at}) async {
    await repos.waterLogs.update(
      WaterLogsCompanion(
        id: Value(row.id),
        ml: Value(ml.clamp(WaterMath.minAmount, WaterMath.maxAmount)),
        at: Value(at ?? row.at),
      ),
    );
    return () => repos.waterLogs.update(row);
  }

  Future<BodyUndo> deleteWater(WaterLogRow row) async {
    final gone = await repos.waterLogs.delete(row.id);
    final activity = await _unrecord('water_logs', row.id);
    return () async {
      if (gone != null) await repos.waterLogs.restore(gone);
      await repos.activityLog.restoreAll(activity);
    };
  }
}
