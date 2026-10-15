/// The gym, properly (Part 8, «#24 – Body / gym»): his own named training
/// days, the plan one weekday asks for, and the numbers of his next session
/// read off his own log.
///
/// **Nothing here is advice.** [NextLoad] is arithmetic on rows he wrote
/// himself: the heaviest working set of each day he trained, and the
/// difference he put between them with his own hands. It says what he did
/// and what the same difference would come to — never what he should do,
/// never a programme, never a claim about his body.
library;

import 'package:flutter/foundation.dart';

import 'body_clock.dart';
import 'body_week.dart';
import 'training.dart';

// ------------------------------------------------------------ templates ----

/// One exercise inside a template. The numbers override the exercise's own
/// for that day only; null means "whatever the exercise says".
@immutable
class TemplateExercise {
  const TemplateExercise({
    required this.id,
    required this.exerciseId,
    this.sets,
    this.reps,
    this.weight,
    this.restSec,
    this.warmupSets,
  });

  final String id;
  final String exerciseId;
  final int? sets;
  final int? reps;
  final double? weight;
  final int? restSec;
  final int? warmupSets;

  /// [exercise] with this item's numbers on top of its own.
  PlannedExercise applyTo(PlannedExercise exercise) => exercise.copyWith(
    sets: sets,
    reps: reps,
    weight: weight,
    restSec: restSec,
    warmupSets: warmupSets,
  );

  @override
  bool operator ==(Object other) =>
      other is TemplateExercise &&
      other.id == id &&
      other.exerciseId == exerciseId &&
      other.sets == sets &&
      other.reps == reps &&
      other.weight == weight &&
      other.restSec == restSec &&
      other.warmupSets == warmupSets;

  @override
  int get hashCode => Object.hash(id, exerciseId, sets, reps, weight, restSec, warmupSets);
}

/// A named training day of his own («يوم صدر»), on the weekdays he gave it,
/// holding his exercises in the order he wants to do them.
@immutable
class WorkoutTemplate {
  const WorkoutTemplate({
    required this.id,
    required this.name,
    this.weekdays = const [],
    this.notes,
    this.active = true,
    this.items = const [],
  });

  final String id;
  final String name;

  /// ISO weekdays (1 = Monday … 7 = Sunday).
  final List<int> weekdays;
  final String? notes;
  final bool active;

  /// In the order he put them.
  final List<TemplateExercise> items;

  bool trainsOn(DateTime day) => active && items.isNotEmpty && BodyWeek.trainsOn(weekdays, day);

  @override
  bool operator ==(Object other) =>
      other is WorkoutTemplate &&
      other.id == id &&
      other.name == name &&
      listEquals(other.weekdays, weekdays) &&
      other.notes == notes &&
      other.active == active &&
      listEquals(other.items, items);

  @override
  int get hashCode => Object.hash(id, name, Object.hashAll(weekdays), notes, active, Object.hashAll(items));
}

/// What a weekday asks for.
abstract final class SessionPlan {
  /// The exercises of [day], in order:
  ///
  /// 1. every template that trains on [day], its items in his order, each
  ///    with the numbers that template gives it;
  /// 2. then any exercise whose own weekdays hold [day] and that no
  ///    template of the day already named — so the plan he had before
  ///    templates existed keeps working beside them.
  ///
  /// Every returned exercise carries [day]'s weekday, so a day read through
  /// this list is the same shape as one read straight off the exercises. A
  /// paused exercise is left out either way.
  static List<PlannedExercise> forDay({
    required List<PlannedExercise> exercises,
    required List<WorkoutTemplate> templates,
    required DateTime day,
  }) {
    final d = BodyDays.of(day);
    final byId = {for (final e in exercises) e.id: e};
    final out = <PlannedExercise>[];
    final used = <String>{};
    for (final t in templates) {
      if (!t.trainsOn(d)) continue;
      for (final item in t.items) {
        final e = byId[item.exerciseId];
        if (e == null || !e.active || used.contains(e.id)) continue;
        used.add(e.id);
        out.add(item.applyTo(e).copyWith(weekdays: [d.weekday]));
      }
    }
    for (final e in exercises) {
      if (used.contains(e.id) || !e.trainsOn(d)) continue;
      used.add(e.id);
      out.add(e);
    }
    return out;
  }

  /// The templates that train on [day], in his order.
  static List<WorkoutTemplate> templatesOn(List<WorkoutTemplate> templates, DateTime day) {
    final d = BodyDays.of(day);
    return [
      for (final t in templates)
        if (t.trainsOn(d)) t,
    ];
  }
}

// -------------------------------------------------------- the next load ----

/// Where the numbers of [NextLoad] come from.
enum LoadBasis {
  /// He has never logged this exercise: there is nothing to read.
  nothingYet,

  /// One day only, or the last day was not heavier than the one before it
  /// (he held, or came down). The numbers are that day's, unchanged.
  lastTime,

  /// He went up every time in the window, so the same step he took is
  /// added once more.
  sameStep,

  /// The weight stayed the same and the reps went up: the numbers are the
  /// last day's.
  repsUp,
}

/// The numbers of his next session, worked out from his own log.
///
/// It is a sum, not a suggestion from anyone: [last] is what he lifted last
/// time, [step] is the difference he himself put between two of his days,
/// and [weight] is `last + step` when every one of his last days went up.
/// The screen says exactly that; see `gym_texts.dart`.
@immutable
class NextLoad {
  const NextLoad({
    required this.basis,
    this.weight,
    this.reps,
    this.last,
    this.lastReps,
    this.step,
    this.sessions = 0,
    this.lastDay,
    this.byReps = false,
  });

  static const NextLoad none = NextLoad(basis: LoadBasis.nothingYet);

  final LoadBasis basis;

  /// Kilograms of the heaviest working set the arithmetic comes to.
  final double? weight;

  /// The reps of his last heaviest set (never invented, never raised).
  final int? reps;

  /// The heaviest working set of the last day he trained it.
  final double? last;
  final int? lastReps;

  /// The smallest difference he actually put between two of his own days,
  /// in kg (or in reps when [byReps]). Null when there is only one day, or
  /// when he did not go up.
  final double? step;

  /// Training days read.
  final int sessions;
  final DateTime? lastDay;

  /// The exercise carries no weight at all (push-ups, a plank): the
  /// arithmetic ran on reps, and [weight] is null.
  final bool byReps;

  bool get any => basis != LoadBasis.nothingYet;

  /// Whether the number offered is above what he did last time.
  bool get isStepUp => basis == LoadBasis.sameStep;

  /// Reads one exercise's history. [history] is `ExerciseProgress` built
  /// for that exercise; nothing else is consulted and nothing is stored.
  ///
  /// The arithmetic, in full:
  ///
  /// * take his training **days**, newest first, at most [window] of them;
  /// * each day's number is the heaviest working set of that day (its reps
  ///   come along) — or, when no day of his ever carried a weight, the most
  ///   reps he did in one working set that day;
  /// * no day with a number → [LoadBasis.nothingYet];
  /// * one day → [LoadBasis.lastTime]: that day's numbers, unchanged;
  /// * otherwise look at the differences between consecutive days. If the
  ///   newest difference is above zero and **none** of them is below zero,
  ///   the answer is `last + the smallest of his own positive differences`
  ///   ([LoadBasis.sameStep]) — the smallest step he ever actually took, so
  ///   the number is never bigger than a jump he has already made. If the
  ///   newest difference is zero and the reps went up, it is
  ///   [LoadBasis.repsUp] with the same weight. Anything else (he came
  ///   down, or he has been up and down) is [LoadBasis.lastTime]: last
  ///   time's numbers.
  static NextLoad of(ExerciseProgress history, {int window = 5, BodyWallClock clock = const LocalBodyWallClock()}) {
    if (history.logs.isEmpty) return none;
    // One entry per training day, newest first.
    final byDay = <String, ({DateTime day, List<WorkoutEntry> logs})>{};
    for (final l in history.logs) {
      final day = clock.dayOf(l.at);
      (byDay[BodyDays.key(day)] ??= (day: day, logs: <WorkoutEntry>[])).logs.add(l);
    }
    final days = byDay.values.toList()..sort((a, b) => b.day.compareTo(a.day));

    double? topWeightOf(List<WorkoutEntry> logs) {
      double? best;
      for (final l in logs) {
        final w = l.topWeight;
        if (w != null && (best == null || w > best)) best = w;
      }
      return best;
    }

    int? repsAt(List<WorkoutEntry> logs, double? weight) {
      int? best;
      for (final l in logs) {
        if (weight != null && l.topWeight != weight) continue;
        final r = l.topReps;
        if (r != null && (best == null || r > best)) best = r;
      }
      return best;
    }

    final anyWeight = days.any((d) => topWeightOf(d.logs) != null);
    // The ladder: one value per day, newest first.
    final rungs = <({DateTime day, double value, int? reps})>[];
    for (final d in days) {
      if (anyWeight) {
        final w = topWeightOf(d.logs);
        if (w == null) continue;
        rungs.add((day: d.day, value: w, reps: repsAt(d.logs, w)));
      } else {
        final r = repsAt(d.logs, null);
        if (r == null) continue;
        rungs.add((day: d.day, value: r.toDouble(), reps: r));
      }
      if (rungs.length >= window) break;
    }
    if (rungs.isEmpty) return none;
    final last = rungs.first;
    double? asWeight(double v) => anyWeight ? v : null;
    int? asReps(({DateTime day, double value, int? reps}) r) => anyWeight ? r.reps : r.value.round();

    if (rungs.length == 1) {
      return NextLoad(
        basis: LoadBasis.lastTime,
        weight: asWeight(last.value),
        reps: asReps(last),
        last: asWeight(last.value),
        lastReps: asReps(last),
        sessions: 1,
        lastDay: last.day,
        byReps: !anyWeight,
      );
    }
    final steps = [for (var i = 0; i + 1 < rungs.length; i++) rungs[i].value - rungs[i + 1].value];
    final newest = steps.first;
    final neverDown = !steps.any((s) => s < 0);
    if (newest > 0 && neverDown) {
      final positive = steps.where((s) => s > 0).reduce((a, b) => a < b ? a : b);
      final next = last.value + positive;
      return NextLoad(
        basis: LoadBasis.sameStep,
        weight: asWeight(next),
        reps: anyWeight ? last.reps : next.round(),
        last: asWeight(last.value),
        lastReps: asReps(last),
        step: positive,
        sessions: rungs.length,
        lastDay: last.day,
        byReps: !anyWeight,
      );
    }
    final prevReps = rungs[1].reps;
    if (anyWeight && newest == 0 && last.reps != null && prevReps != null && last.reps! > prevReps) {
      return NextLoad(
        basis: LoadBasis.repsUp,
        weight: last.value,
        reps: last.reps,
        last: last.value,
        lastReps: last.reps,
        step: (last.reps! - prevReps).toDouble(),
        sessions: rungs.length,
        lastDay: last.day,
      );
    }
    return NextLoad(
      basis: LoadBasis.lastTime,
      weight: asWeight(last.value),
      reps: asReps(last),
      last: asWeight(last.value),
      lastReps: asReps(last),
      sessions: rungs.length,
      lastDay: last.day,
      byReps: !anyWeight,
    );
  }
}

// --------------------------------------------------------- the session ----

/// How a session's sets are laid out for one exercise: the warm-ups first,
/// then the working sets. With no number of sets given it is one set.
abstract final class SessionSets {
  static const int maxSets = 20;

  /// How many sets [e] asks for (at least one).
  static int countOf(PlannedExercise e) {
    final s = e.sets;
    if (s == null || s <= 0) return 1;
    return s > maxSets ? maxSets : s;
  }

  /// Whether set [index] of [e] (0-based) is a warm-up.
  static bool isWarmup(PlannedExercise e, int index) {
    final w = e.warmupSets ?? 0;
    if (w <= 0) return false;
    return index < w && index < countOf(e);
  }

  /// The sets [e] asks for, as empty rows to fill in.
  static List<({bool warmup, int? reps, double? weight})> blank(PlannedExercise e) => [
    for (var i = 0; i < countOf(e); i++) (warmup: isWarmup(e, i), reps: e.reps, weight: e.weight),
  ];
}
