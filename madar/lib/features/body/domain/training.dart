import 'package:flutter/foundation.dart';

import 'body_clock.dart';
import 'body_week.dart';

/// One exercise of the training plan (a plain copy of an `exercises` row).
@immutable
class PlannedExercise {
  const PlannedExercise({
    required this.id,
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

  final String id;
  final String name;

  /// ISO weekdays (1 = Monday … 7 = Sunday).
  final List<int> weekdays;
  final int? sets;
  final int? reps;
  final int? durationMin;

  /// Kilograms.
  final double? weight;
  final String? notes;
  final bool active;

  /// The machine's picture: a file name in Madar's own folder.
  final String? photo;

  /// The movement's video: his own file path, or a link. Never copied.
  final String? video;

  /// The muscles he says it works, in his own words.
  final List<String> muscles;

  /// Rest between sets in seconds (null: he has not set one).
  final int? restSec;

  /// How many of [sets] are warm-ups.
  final int? warmupSets;

  /// Working sets: the ones that count towards the heaviest set and the
  /// volume (every set that is not a warm-up).
  int? get workingSets {
    final s = sets;
    if (s == null) return null;
    final w = warmupSets ?? 0;
    final rest = s - w;
    return rest <= 0 ? null : rest;
  }

  bool get hasMedia => photo != null || video != null;

  bool trainsOn(DateTime day) => active && BodyWeek.trainsOn(weekdays, day);

  PlannedExercise copyWith({
    List<int>? weekdays,
    int? sets,
    int? reps,
    double? weight,
    int? restSec,
    int? warmupSets,
  }) => PlannedExercise(
    id: id,
    name: name,
    weekdays: weekdays ?? this.weekdays,
    sets: sets ?? this.sets,
    reps: reps ?? this.reps,
    durationMin: durationMin,
    weight: weight ?? this.weight,
    notes: notes,
    active: active,
    photo: photo,
    video: video,
    muscles: muscles,
    restSec: restSec ?? this.restSec,
    warmupSets: warmupSets ?? this.warmupSets,
  );

  @override
  bool operator ==(Object other) =>
      other is PlannedExercise &&
      other.id == id &&
      other.name == name &&
      listEquals(other.weekdays, weekdays) &&
      other.sets == sets &&
      other.reps == reps &&
      other.durationMin == durationMin &&
      other.weight == weight &&
      other.notes == notes &&
      other.active == active &&
      other.photo == photo &&
      other.video == video &&
      listEquals(other.muscles, muscles) &&
      other.restSec == restSec &&
      other.warmupSets == warmupSets;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    Object.hashAll(weekdays),
    sets,
    reps,
    durationMin,
    weight,
    notes,
    active,
    photo,
    video,
    Object.hashAll(muscles),
    restSec,
    warmupSets,
  );
}

/// One set as it happened: the reps and the weight of that set alone (a
/// plain copy of a `workout_sets` row).
@immutable
class LoggedSet {
  const LoggedSet({required this.id, this.reps, this.weight, this.warmup = false});

  final String id;
  final int? reps;

  /// Kilograms.
  final double? weight;

  /// A warm-up: it counts as done, never as a personal best and never in
  /// the volume.
  final bool warmup;

  /// Reps × kg of this set alone (null for a set with no weight).
  double? get volume => reps == null || reps! <= 0 || weight == null || weight! <= 0 ? null : reps! * weight!;

  @override
  bool operator ==(Object other) =>
      other is LoggedSet && other.id == id && other.reps == reps && other.weight == weight && other.warmup == warmup;

  @override
  int get hashCode => Object.hash(id, reps, weight, warmup);

  @override
  String toString() => 'LoggedSet($reps × $weight${warmup ? ' warm-up' : ''})';
}

/// Arithmetic over the sets of one workout. Warm-ups are left out of every
/// number that stands for work done: they happened, and they are never a
/// personal best.
abstract final class SetMath {
  static List<LoggedSet> working(Iterable<LoggedSet> sets) => [
    for (final s in sets)
      if (!s.warmup) s,
  ];

  /// Reps of the working sets (null when none of them says how many).
  static int? totalReps(Iterable<LoggedSet> sets) {
    var total = 0;
    var any = false;
    for (final s in working(sets)) {
      if (s.reps != null && s.reps! > 0) {
        total += s.reps!;
        any = true;
      }
    }
    return any ? total : null;
  }

  /// Σ reps × kg over the working sets (null when none carries a weight).
  static double? volume(Iterable<LoggedSet> sets) {
    var total = 0.0;
    var any = false;
    for (final s in working(sets)) {
      final v = s.volume;
      if (v != null) {
        total += v;
        any = true;
      }
    }
    return any ? total : null;
  }

  /// The heaviest working set (ties: the one with the most reps).
  static LoggedSet? topSet(Iterable<LoggedSet> sets) {
    LoggedSet? best;
    for (final s in working(sets)) {
      if (s.weight == null || s.weight! <= 0) continue;
      if (best == null ||
          s.weight! > best.weight! ||
          (s.weight == best.weight && (s.reps ?? 0) > (best.reps ?? 0))) {
        best = s;
      }
    }
    return best;
  }

  /// The working set with the most reps (for exercises with no weight).
  static LoggedSet? bestReps(Iterable<LoggedSet> sets) {
    LoggedSet? best;
    for (final s in working(sets)) {
      if (s.reps == null || s.reps! <= 0) continue;
      if (best == null || s.reps! > (best.reps ?? 0)) best = s;
    }
    return best;
  }

  /// What the one-line columns of `workout_logs` should say for [sets]: how
  /// many working sets, and the reps and weight of the heaviest of them —
  /// the headline a gym log shows («٤ × ١٠ · ٥٠ كغ»). The volume and the
  /// personal best are never read from these; they come from the set rows.
  static ({int? sets, int? reps, double? weight}) summarise(Iterable<LoggedSet> sets) {
    final work = working(sets);
    if (work.isEmpty) return (sets: null, reps: null, weight: null);
    final top = topSet(work) ?? bestReps(work);
    return (sets: work.length, reps: top?.reps, weight: top?.weight);
  }
}

/// One logged workout (a plain copy of a `workout_logs` row, with its
/// `workout_sets` rows when it has any).
@immutable
class WorkoutEntry {
  const WorkoutEntry({
    required this.id,
    required this.name,
    required this.at,
    this.exerciseId,
    this.sets,
    this.reps,
    this.weight,
    this.durationMin,
    this.notes,
    this.setLog = const [],
  });

  final String id;
  final String? exerciseId;
  final String name;
  final DateTime at;
  final int? sets;
  final int? reps;
  final double? weight;
  final int? durationMin;
  final String? notes;

  /// Every set of this workout in the order he did them, warm-ups
  /// included. Empty for a one-line log (the older kind, and a workout he
  /// logged without opening its sets).
  final List<LoggedSet> setLog;

  bool get hasSetLog => setLog.isNotEmpty;

  /// The sets that count as work (warm-ups left out).
  List<LoggedSet> get workingSetLog => SetMath.working(setLog);

  int? get totalReps => hasSetLog ? SetMath.totalReps(setLog) : WorkoutMath.totalReps(sets, reps);

  /// Sets × reps × kg (null without a weight); Σ reps × kg over the
  /// working sets once the workout carries them one by one.
  double? get volume => hasSetLog ? SetMath.volume(setLog) : WorkoutMath.volume(sets, reps, weight);

  /// The heaviest working set's weight, in kg.
  double? get topWeight {
    if (!hasSetLog) return weight != null && weight! > 0 ? weight : null;
    return SetMath.topSet(setLog)?.weight;
  }

  /// The reps of the heaviest working set (of the best set by reps when
  /// nothing carries a weight).
  int? get topReps {
    if (!hasSetLog) return reps != null && reps! > 0 ? reps : null;
    final top = SetMath.topSet(setLog) ?? SetMath.bestReps(setLog);
    return top?.reps;
  }

  WorkoutEntry withSets(List<LoggedSet> sets) => WorkoutEntry(
    id: id,
    name: name,
    at: at,
    exerciseId: exerciseId,
    sets: this.sets,
    reps: reps,
    weight: weight,
    durationMin: durationMin,
    notes: notes,
    setLog: sets,
  );

  /// Whether this log belongs to [exercise] (by id; by name for logs
  /// imported without one).
  bool isOf(PlannedExercise exercise) =>
      exerciseId == exercise.id || (exerciseId == null && name.trim() == exercise.name.trim());
}

/// Training arithmetic.
abstract final class WorkoutMath {
  /// Sets × reps; one set when only reps are given; null without reps.
  static int? totalReps(int? sets, int? reps) {
    if (reps == null || reps <= 0) return null;
    final s = sets == null || sets <= 0 ? 1 : sets;
    return s * reps;
  }

  /// Training volume in kg: sets × reps × weight. Null for bodyweight or
  /// timed work (no weight) or without reps.
  static double? volume(int? sets, int? reps, double? weight) {
    final r = totalReps(sets, reps);
    if (r == null || weight == null || weight <= 0) return null;
    return r * weight;
  }

  /// Sum of [volume] over [logs] (logs without a volume add nothing).
  static double totalVolume(Iterable<WorkoutEntry> logs) => logs.fold(0.0, (a, l) => a + (l.volume ?? 0));

  /// Sum of minutes over [logs].
  static int totalMinutes(Iterable<WorkoutEntry> logs) => logs.fold(0, (a, l) => a + (l.durationMin ?? 0));
}

/// One scheduled exercise of a day with what was logged for it.
@immutable
class SessionItem {
  const SessionItem(this.exercise, this.logs);

  final PlannedExercise exercise;

  /// That day's logs for the exercise, newest first.
  final List<WorkoutEntry> logs;

  bool get done => logs.isNotEmpty;

  WorkoutEntry? get latest => logs.isEmpty ? null : logs.first;
}

/// A day's training: the plan for its weekday (in the user's order) and
/// everything logged that day.
@immutable
class TrainingDay {
  const TrainingDay({required this.day, required this.items, required this.extras});

  final DateTime day;
  final List<SessionItem> items;

  /// Logs of the day that are not for a scheduled exercise (an extra walk,
  /// Monday's exercise done on Tuesday), newest first.
  final List<WorkoutEntry> extras;

  int get planned => items.length;
  int get done => items.where((i) => i.done).length;
  bool get isRestDay => items.isEmpty;
  bool get complete => planned > 0 && done == planned;
  double get progress => planned == 0 ? 0 : done / planned;

  /// Whether logging [exerciseId] completes this day's session: it is the
  /// one planned exercise not done yet.
  bool completedBy(String? exerciseId) =>
      exerciseId != null &&
      planned > 0 &&
      done == planned - 1 &&
      items.any((i) => i.exercise.id == exerciseId && !i.done);

  Iterable<WorkoutEntry> get allLogs sync* {
    for (final i in items) {
      yield* i.logs;
    }
    yield* extras;
  }

  int get minutes => WorkoutMath.totalMinutes(allLogs);
  double get volume => WorkoutMath.totalVolume(allLogs);

  /// [exercises] (already in the user's order) scheduled on [day] and the
  /// [logs] that fall on it.
  ///
  /// [planFor] replaces "every exercise whose weekdays hold this day" with
  /// whatever a day's own plan says — the named template of that weekday
  /// and the numbers it carries (`SessionPlan.forDay`). Without it the day
  /// is read straight off the exercises, as it always was.
  static TrainingDay build({
    required List<PlannedExercise> exercises,
    required Iterable<WorkoutEntry> logs,
    required DateTime day,
    BodyWallClock clock = const LocalBodyWallClock(),
    List<PlannedExercise> Function(DateTime day)? planFor,
  }) {
    final d = BodyDays.of(day);
    final todays = [
      for (final l in logs)
        if (BodyDays.same(clock.dayOf(l.at), d)) l,
    ]..sort((a, b) => b.at.compareTo(a.at));
    final scheduled = planFor != null
        ? planFor(d)
        : [
            for (final e in exercises)
              if (e.trainsOn(d)) e,
          ];
    final used = <String>{};
    final items = <SessionItem>[];
    for (final e in scheduled) {
      final mine = [
        for (final l in todays)
          if (!used.contains(l.id) && l.isOf(e)) l,
      ];
      used.addAll(mine.map((l) => l.id));
      items.add(SessionItem(e, mine));
    }
    return TrainingDay(
      day: d,
      items: items,
      extras: [
        for (final l in todays)
          if (!used.contains(l.id)) l,
      ],
    );
  }
}

/// Planned vs done sessions of a week so far (the plan tab's header).
@immutable
class WeekAdherence {
  const WeekAdherence({required this.expected, required this.done, required this.days});

  /// Scheduled exercise-days up to today.
  final int expected;

  /// Of those, the ones with a log that day.
  final int done;

  /// Per day of the display week: planned count and done count (future
  /// days included, done = 0).
  final List<({DateTime day, int planned, int done})> days;

  double get ratio => expected == 0 ? 0 : done / expected;

  static WeekAdherence of({
    required List<PlannedExercise> exercises,
    required Iterable<WorkoutEntry> logs,
    required DateTime today,
    required int weekStart,
    BodyWallClock clock = const LocalBodyWallClock(),
    List<PlannedExercise> Function(DateTime day)? planFor,
  }) {
    final t = BodyDays.of(today);
    final all = logs.toList();
    var expected = 0, done = 0;
    final days = <({DateTime day, int planned, int done})>[];
    for (final d in BodyWeek.weekOf(t, weekStart)) {
      final day = TrainingDay.build(exercises: exercises, logs: all, day: d, clock: clock, planFor: planFor);
      days.add((day: d, planned: day.planned, done: day.done));
      if (!d.isAfter(t)) {
        expected += day.planned;
        done += day.done;
      }
    }
    return WeekAdherence(expected: expected, done: done, days: days);
  }
}

/// What an exercise's progress chart can show.
enum ProgressMetric {
  /// Heaviest weight of the day (kg).
  weight,

  /// Sets × reps × kg of the day.
  volume,

  /// Total reps of the day.
  reps,

  /// Minutes of the day.
  minutes,
}

@immutable
class ProgressPoint {
  const ProgressPoint(this.day, this.value);

  final DateTime day;
  final double value;

  @override
  bool operator ==(Object other) => other is ProgressPoint && BodyDays.same(other.day, day) && other.value == value;

  @override
  int get hashCode => Object.hash(BodyDays.key(day), value);

  @override
  String toString() => 'ProgressPoint(${BodyDays.key(day)}, $value)';
}

/// An exercise's history: its logs and one point per training day for each
/// [ProgressMetric].
@immutable
class ExerciseProgress {
  const ExerciseProgress({required this.logs, required this.series});

  /// Newest first.
  final List<WorkoutEntry> logs;

  /// Oldest first; only days with data.
  final Map<ProgressMetric, List<ProgressPoint>> series;

  static const ExerciseProgress empty = ExerciseProgress(logs: [], series: {});

  List<ProgressPoint> of(ProgressMetric m) => series[m] ?? const [];

  /// Metrics with at least one point, in enum order.
  List<ProgressMetric> get available => [
    for (final m in ProgressMetric.values)
      if (of(m).isNotEmpty) m,
  ];

  /// The metric a chart should open on: the first with two or more days,
  /// else the first with any data.
  ProgressMetric? get preferred {
    for (final m in ProgressMetric.values) {
      if (of(m).length >= 2) return m;
    }
    final a = available;
    return a.isEmpty ? null : a.first;
  }

  double? best(ProgressMetric m) {
    final pts = of(m);
    if (pts.isEmpty) return null;
    return pts.map((p) => p.value).reduce((a, b) => a > b ? a : b);
  }

  /// Latest minus first value (null with fewer than two days).
  double? change(ProgressMetric m) {
    final pts = of(m);
    if (pts.length < 2) return null;
    return pts.last.value - pts.first.value;
  }

  DateTime? get lastDone => logs.isEmpty ? null : logs.first.at;

  /// The heaviest single working set he ever logged for this exercise, with
  /// the day he did it (null before he logs a weight).
  ({LoggedSet set, DateTime day})? get bestSet {
    ({LoggedSet set, DateTime day})? best;
    for (final l in logs) {
      final top = l.hasSetLog
          ? SetMath.topSet(l.setLog)
          : (l.topWeight == null ? null : LoggedSet(id: l.id, reps: l.reps, weight: l.topWeight));
      if (top == null || top.weight == null) continue;
      if (best == null ||
          top.weight! > best.set.weight! ||
          (top.weight == best.set.weight && (top.reps ?? 0) > (best.set.reps ?? 0))) {
        best = (set: top, day: l.at);
      }
    }
    return best;
  }

  /// The most reps he ever did in one working set (for a movement he does
  /// without a weight), with its day.
  ({LoggedSet set, DateTime day})? get bestRepsSet {
    ({LoggedSet set, DateTime day})? best;
    for (final l in logs) {
      final top = l.hasSetLog
          ? SetMath.bestReps(l.setLog)
          : (l.topReps == null ? null : LoggedSet(id: l.id, reps: l.topReps, weight: l.weight));
      if (top == null || top.reps == null) continue;
      if (best == null || top.reps! > (best.set.reps ?? 0)) best = (set: top, day: l.at);
    }
    return best;
  }

  static ExerciseProgress build(Iterable<WorkoutEntry> logs, {BodyWallClock clock = const LocalBodyWallClock()}) {
    final sorted = logs.toList()..sort((a, b) => b.at.compareTo(a.at));
    final byDay = <String, ({DateTime day, List<WorkoutEntry> logs})>{};
    for (final l in sorted) {
      final day = clock.dayOf(l.at);
      (byDay[BodyDays.key(day)] ??= (day: day, logs: <WorkoutEntry>[])).logs.add(l);
    }
    final days = byDay.values.toList()..sort((a, b) => a.day.compareTo(b.day));
    final series = <ProgressMetric, List<ProgressPoint>>{};
    void add(ProgressMetric m, DateTime day, double? v) {
      if (v == null || v <= 0) return;
      (series[m] ??= []).add(ProgressPoint(day, v));
    }

    for (final d in days) {
      final weights = [
        for (final l in d.logs)
          if (l.topWeight != null) l.topWeight!,
      ];
      add(ProgressMetric.weight, d.day, weights.isEmpty ? null : weights.reduce((a, b) => a > b ? a : b));
      final volumes = [for (final l in d.logs) ?l.volume];
      add(ProgressMetric.volume, d.day, volumes.isEmpty ? null : volumes.fold<double>(0, (a, b) => a + b));
      final reps = [for (final l in d.logs) ?l.totalReps];
      add(ProgressMetric.reps, d.day, reps.isEmpty ? null : reps.fold<int>(0, (a, b) => a + b).toDouble());
      final minutes = [
        for (final l in d.logs)
          if (l.durationMin != null && l.durationMin! > 0) l.durationMin!,
      ];
      add(ProgressMetric.minutes, d.day, minutes.isEmpty ? null : minutes.fold<int>(0, (a, b) => a + b).toDouble());
    }
    return ExerciseProgress(logs: List.unmodifiable(sorted), series: series);
  }
}
