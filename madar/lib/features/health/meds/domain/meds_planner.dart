import 'package:flutter/foundation.dart';

import '../../../../core/domain/enums.dart';
import 'dose_scheduler.dart';
import 'dose_tracker.dart';
import 'med_models.dart';

/// Plans and tracks a stretch of days in one go: the dose log pins taken
/// doses (so timing rules follow what really happened) and drops skipped
/// ones from the rules, then every dose gets its state at [now].
@immutable
class MedsPeriod {
  const MedsPeriod({required this.plans, required this.tracked, required this.now});

  /// One plan per day, oldest first.
  final List<DayPlan> plans;

  /// Every planned dose of [plans], tracked at [now] (sorted by time).
  final List<TrackedDose> tracked;
  final DateTime now;

  List<TrackedDose> on(DateTime day) => [
    for (final t in tracked)
      if (MedDays.same(t.dose.day, day)) t,
  ];

  List<DoseConflict> get conflicts => [for (final p in plans) ...p.conflicts];
}

abstract final class MedsPlanner {
  /// Plans [count] days from [from] against [logs] and tracks them at [now].
  static MedsPeriod period(
    DoseScheduler scheduler, {
    required DateTime from,
    required int count,
    required Iterable<DoseLog> logs,
    required DateTime now,
  }) {
    final logList = logs.toList();
    final first = MedDays.dateOnly(from);
    // Answers known before planning (so a taken dose pins where it was
    // taken): match the log against the rule-free expansion.
    final base = [for (var i = -1; i <= count; i++) ...scheduler.expandDay(MedDays.add(first, i))];
    final matched = DoseTracker.match(base, logList);
    final taken = <String, DateTime>{};
    final skipped = <String>{};
    matched.forEach((key, log) {
      if (log.status == DoseStatus.taken && log.at != null) taken[key] = log.at!;
      if (log.status == DoseStatus.skipped) skipped.add(key);
    });
    final plans = scheduler.planDays(first, count, taken: taken, skipped: skipped);
    final doses = [for (final p in plans) ...p.doses];
    final tracked = DoseTracker.trackAll(doses, logList, now, scheduler.settings)
      ..sort((a, b) => a.dose.at.compareTo(b.dose.at));
    return MedsPeriod(plans: plans, tracked: tracked, now: now);
  }

  /// The doses whose (possibly snoozed) time falls in (`now`, `now` +
  /// [horizon]] and that are still open – what reminders are for.
  static List<TrackedDose> upcoming(MedsPeriod period, {Duration horizon = const Duration(hours: 48)}) {
    final end = period.now.add(horizon);
    return [
      for (final t in period.tracked)
        if ((t.state == DoseState.upcoming || t.state == DoseState.snoozed) &&
            t.dueAt.isAfter(period.now) &&
            !t.dueAt.isAfter(end))
          t,
    ]..sort((a, b) => a.dueAt.compareTo(b.dueAt));
  }

  /// Doses waiting for an answer right now (due or late), oldest first.
  static List<TrackedDose> dueNow(Iterable<TrackedDose> tracked) =>
      [for (final t in tracked) if (t.state.needsAction) t]..sort((a, b) => a.dueAt.compareTo(b.dueAt));

  /// The next dose still to come (after [now]).
  static TrackedDose? next(Iterable<TrackedDose> tracked) {
    TrackedDose? best;
    for (final t in tracked) {
      if (t.state != DoseState.upcoming && t.state != DoseState.snoozed) continue;
      if (best == null || t.dueAt.isBefore(best.dueAt)) best = t;
    }
    return best;
  }
}
