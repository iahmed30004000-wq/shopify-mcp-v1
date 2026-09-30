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

  bool trainsOn(DateTime day) => active && BodyWeek.trainsOn(weekdays, day);

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
      other.active == active;

  @override
  int get hashCode => Object.hash(id, name, Object.hashAll(weekdays), sets, reps, durationMin, weight, notes, active);
}

/// One logged workout (a plain copy of a `workout_logs` row).
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

  int? get totalReps => WorkoutMath.totalReps(sets, reps);

  /// Sets × reps × kg (null without a weight).
  double? get volume => WorkoutMath.volume(sets, reps, weight);

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
  static TrainingDay build({
    required List<PlannedExercise> exercises,
    required Iterable<WorkoutEntry> logs,
    required DateTime day,
    BodyWallClock clock = const LocalBodyWallClock(),
  }) {
    final d = BodyDays.of(day);
    final todays = [
      for (final l in logs)
        if (BodyDays.same(clock.dayOf(l.at), d)) l,
    ]..sort((a, b) => b.at.compareTo(a.at));
    final scheduled = [
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
  }) {
    final t = BodyDays.of(today);
    final all = logs.toList();
    var expected = 0, done = 0;
    final days = <({DateTime day, int planned, int done})>[];
    for (final d in BodyWeek.weekOf(t, weekStart)) {
      final day = TrainingDay.build(exercises: exercises, logs: all, day: d, clock: clock);
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
          if (l.weight != null && l.weight! > 0) l.weight!,
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
