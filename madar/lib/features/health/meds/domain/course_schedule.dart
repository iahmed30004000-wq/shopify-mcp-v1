import 'package:flutter/foundation.dart';

import '../../../../core/domain/enums.dart';
import 'med_models.dart';

/// One dose day of a course.
@immutable
class CourseDoseDay {
  const CourseDoseDay({
    required this.day,
    required this.phase,
    required this.indexInPhase,
    required this.index,
    this.dose,
    this.doseAmount,
  });

  final DateTime day;

  /// Index into the course's phases.
  final int phase;

  /// 0-based position inside its phase, and across the whole course.
  final int indexInPhase;
  final int index;
  final String? dose;
  final double? doseAmount;

  @override
  bool operator ==(Object other) =>
      other is CourseDoseDay &&
      MedDays.same(other.day, day) &&
      other.phase == phase &&
      other.indexInPhase == indexInPhase &&
      other.index == index;

  @override
  int get hashCode => Object.hash(MedDays.key(day), phase, indexInPhase, index);

  @override
  String toString() => 'CourseDoseDay(${MedDays.key(day)} p$phase#$indexInPhase)';
}

/// Where a course stands on a day.
@immutable
class CourseProgress {
  const CourseProgress({
    required this.phase,
    required this.dosesInPhase,
    required this.doneInPhase,
    required this.done,
    required this.total,
    required this.next,
    required this.last,
    required this.finished,
    required this.started,
  });

  /// The current phase (the phase of the next dose; the last phase once
  /// finished).
  final int phase;

  /// Doses the current phase has (null when open-ended) and how many of
  /// them are behind us (dose days before today, plus today's once taken).
  final int? dosesInPhase;
  final int doneInPhase;

  /// Dose days passed over the whole course, and its total (null when
  /// open-ended).
  final int done;
  final int? total;

  /// The next dose day (today's included while not yet taken), null once
  /// finished.
  final CourseDoseDay? next;

  /// The latest dose day on or before today.
  final CourseDoseDay? last;
  final bool finished;
  final bool started;

  double? get fraction => total == null || total == 0 ? null : (done / total!).clamp(0.0, 1.0);
}

/// Expands a course's phases into dose days.
///
/// The doses form one chain from the start date: each dose comes one
/// phase-interval after the previous one, so "daily ×10 → weekly ×4 →
/// monthly" gives ten daily doses, the first weekly dose a week after the
/// tenth daily one, and monthly doses on that day of the month (clamped to
/// short months without drifting: 31 Jan → 28 Feb → 31 Mar).
abstract final class CourseSchedule {
  /// Safety cap on expanded doses (an open-ended daily phase over years).
  static const maxDoses = 5000;

  /// Dose days from the start up to [until] (inclusive; required when the
  /// last phase is open-ended, else the whole course).
  static List<CourseDoseDay> expand(CourseSpec course, {DateTime? until}) {
    final out = <CourseDoseDay>[];
    final end = until == null ? null : MedDays.dateOnly(until);
    final phases = course.phases;
    if (phases.isEmpty) return out;
    DateTime? prev;
    var index = 0;
    for (var p = 0; p < phases.length; p++) {
      final phase = phases[p];
      final base = prev;
      final dayOfMonth = base?.day ?? course.startDate.day;
      for (var k = 0; phase.count == null || k < phase.count!; k++) {
        final DateTime day;
        if (base == null) {
          // The course's very first dose is on its start date.
          day = k == 0
              ? MedDays.dateOnly(course.startDate)
              : _advance(MedDays.dateOnly(course.startDate), phase, k, dayOfMonth);
        } else {
          day = _advance(base, phase, k + 1, dayOfMonth);
        }
        if (end != null && day.isAfter(end)) return out;
        if (index >= maxDoses) return out;
        out.add(
          CourseDoseDay(
            day: day,
            phase: p,
            indexInPhase: k,
            index: index++,
            dose: phase.dose,
            doseAmount: phase.doseAmount,
          ),
        );
        prev = day;
        if (phase.count == null && end == null) return out; // open-ended without a bound
      }
    }
    return out;
  }

  static DateTime _advance(DateTime base, CoursePhase phase, int steps, int dayOfMonth) => switch (phase.frequency) {
    CourseFrequency.daily => MedDays.add(base, steps * phase.interval),
    CourseFrequency.weekly => MedDays.add(base, steps * 7 * phase.interval),
    CourseFrequency.monthly => MedDays.addMonths(base, steps * phase.interval, dayOfMonth: dayOfMonth),
  };

  /// The dose day on [day], if the course has one.
  static CourseDoseDay? doseOn(CourseSpec course, DateTime day) {
    final d = MedDays.dateOnly(day);
    if (d.isBefore(MedDays.dateOnly(course.startDate))) return null;
    for (final dose in expand(course, until: d).reversed) {
      if (MedDays.same(dose.day, d)) return dose;
      if (dose.day.isBefore(d)) return null;
    }
    return null;
  }

  /// The total number of doses (null when open-ended).
  static int? total(CourseSpec course) {
    if (course.phases.isEmpty) return 0;
    var sum = 0;
    for (final p in course.phases) {
      if (p.count == null) return null;
      sum += p.count!;
    }
    return sum;
  }

  /// The last dose day of a finite course (null when open-ended / empty).
  static DateTime? endDate(CourseSpec course) {
    if (total(course) == null) return null;
    final all = expand(course);
    return all.isEmpty ? null : all.last.day;
  }

  /// Progress on [today]. [takenToday] tells whether today's dose (if any)
  /// has been taken, so it counts as done.
  static CourseProgress progress(CourseSpec course, DateTime today, {bool takenToday = false}) {
    final t = MedDays.dateOnly(today);
    final phases = course.phases;
    final tot = total(course);
    if (phases.isEmpty) {
      return const CourseProgress(
        phase: 0,
        dosesInPhase: 0,
        doneInPhase: 0,
        done: 0,
        total: 0,
        next: null,
        last: null,
        finished: true,
        started: false,
      );
    }
    // One dose past today is enough to know "next".
    final horizon = _horizonAfter(course, t);
    final all = expand(course, until: horizon);
    CourseDoseDay? last, next;
    var done = 0;
    for (final d in all) {
      final isToday = MedDays.same(d.day, t);
      if (d.day.isBefore(t) || (isToday && takenToday)) {
        done++;
        last = d;
      } else {
        if (isToday) last = d;
        next ??= d;
      }
    }
    final finished = next == null && tot != null;
    final phase = next?.phase ?? last?.phase ?? 0;
    var doneInPhase = 0;
    for (final d in all) {
      if (d.phase != phase) continue;
      if (d.day.isBefore(t) || (MedDays.same(d.day, t) && takenToday)) doneInPhase++;
    }
    return CourseProgress(
      phase: phase,
      dosesInPhase: phases[phase].count,
      doneInPhase: doneInPhase,
      done: done,
      total: tot,
      next: next,
      last: last,
      finished: finished,
      started: !t.isBefore(MedDays.dateOnly(course.startDate)),
    );
  }

  static DateTime _horizonAfter(CourseSpec course, DateTime t) {
    // The longest gap between two doses is one interval of the slowest
    // phase; a year past today covers every realistic course.
    final start = MedDays.dateOnly(course.startDate);
    final from = t.isAfter(start) ? t : start;
    var maxMonths = 1;
    for (final p in course.phases) {
      if (p.frequency == CourseFrequency.monthly && p.interval > maxMonths) maxMonths = p.interval;
    }
    return MedDays.addMonths(from, 12 + maxMonths);
  }
}
