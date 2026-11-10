import 'package:flutter/foundation.dart';

import 'body_clock.dart';

/// The user's intermittent-fasting rhythm (key/value `body.fasting`).
///
/// A day is [targetHours] of fasting starting at the last meal
/// ([lastMealMinutes] after midnight), then an eating window of the rest of
/// the 24 hours (16:8 → fast 20:00 → 12:00, eat 12:00 → 20:00).
@immutable
class FastingPlan {
  const FastingPlan({
    this.targetHours = 16,
    this.lastMealMinutes = 20 * 60,
    this.notifyGoal = false,
    this.notifyEatingClose = false,
    this.eatingLeadMinutes = 30,
  });

  static const String storageKey = 'body.fasting';

  /// Fasting hours offered as chips (12:12 … 20:4, 23:1).
  static const List<int> presets = [12, 14, 16, 18, 20, 23];
  static const double minHours = 1;
  static const double maxHours = 72;

  /// Minutes before the eating window closes that the reminder comes.
  static const List<int> leadChoices = [0, 15, 30, 60];

  final double targetHours;

  /// Planned last meal (= planned fast start), minutes after midnight.
  final int lastMealMinutes;

  /// Notify when an ongoing fast reaches its goal.
  final bool notifyGoal;

  /// Notify [eatingLeadMinutes] before the eating window closes.
  final bool notifyEatingClose;
  final int eatingLeadMinutes;

  Duration get target => Duration(minutes: (targetHours * 60).round());

  /// The rest of the day after the fast (zero for fasts of 24 h or more).
  Duration get eatingWindow {
    const day = Duration(hours: 24);
    return target >= day ? Duration.zero : day - target;
  }

  /// `16:8` for whole-hour fasts shorter than a day, else null.
  String? get ratio {
    final w = eatingWindow;
    if (w == Duration.zero || target.inMinutes % 60 != 0) return null;
    return '${target.inHours}:${w.inHours}';
  }

  bool get isPreset => presets.any((p) => p * 60 == target.inMinutes);

  FastingPlan copyWith({
    double? targetHours,
    int? lastMealMinutes,
    bool? notifyGoal,
    bool? notifyEatingClose,
    int? eatingLeadMinutes,
  }) => FastingPlan(
    targetHours: targetHours ?? this.targetHours,
    lastMealMinutes: lastMealMinutes ?? this.lastMealMinutes,
    notifyGoal: notifyGoal ?? this.notifyGoal,
    notifyEatingClose: notifyEatingClose ?? this.notifyEatingClose,
    eatingLeadMinutes: eatingLeadMinutes ?? this.eatingLeadMinutes,
  );

  Map<String, Object?> toJson() => {
    'targetHours': targetHours,
    'lastMeal': BodyTimes.format(lastMealMinutes),
    'notifyGoal': notifyGoal,
    'notifyEatingClose': notifyEatingClose,
    'eatingLeadMinutes': eatingLeadMinutes,
  };

  /// Tolerant: anything missing or out of range falls back to the default.
  static FastingPlan fromJson(Object? json) {
    if (json is! Map) return const FastingPlan();
    const d = FastingPlan();
    final hours = json['targetHours'];
    final lead = json['eatingLeadMinutes'];
    return FastingPlan(
      targetHours: hours is num && hours >= minHours && hours <= maxHours ? hours.toDouble() : d.targetHours,
      lastMealMinutes: BodyTimes.parse(json['lastMeal'] as String?) ?? d.lastMealMinutes,
      notifyGoal: json['notifyGoal'] == true,
      notifyEatingClose: json['notifyEatingClose'] == true,
      eatingLeadMinutes: lead is num && lead >= 0 && lead <= 180 ? lead.toInt() : d.eatingLeadMinutes,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FastingPlan &&
      other.targetHours == targetHours &&
      other.lastMealMinutes == lastMealMinutes &&
      other.notifyGoal == notifyGoal &&
      other.notifyEatingClose == notifyEatingClose &&
      other.eatingLeadMinutes == eatingLeadMinutes;

  @override
  int get hashCode => Object.hash(targetHours, lastMealMinutes, notifyGoal, notifyEatingClose, eatingLeadMinutes);
}

/// One fast (a plain copy of a `fasting_sessions` row).
@immutable
class FastingSpan {
  const FastingSpan({required this.id, required this.start, required this.targetHours, this.end, this.note});

  final String id;
  final DateTime start;
  final DateTime? end;
  final double targetHours;
  final String? note;

  bool get active => end == null;

  Duration get target => Duration(minutes: (targetHours * 60).round());

  /// The moment the goal is (was) reached – real elapsed time, so a
  /// daylight-saving change in between moves its wall time, not its length.
  DateTime get goalAt => start.add(target);

  /// Real time fasted by [now] (the end for a finished fast); never negative.
  Duration duration(DateTime now) {
    final d = (end ?? now).difference(start);
    return d.isNegative ? Duration.zero : d;
  }

  bool reached(DateTime now) => duration(now) >= target;
}

enum FastingPhase {
  /// A fast is running.
  fasting,

  /// After a fast (or inside the planned window): eating until the next
  /// planned fast.
  eating,

  /// No fast and outside the eating window (a missed fast, or before the
  /// window opens).
  waiting,
}

/// Everything the fasting ring shows at one moment.
@immutable
class FastingStatus {
  const FastingStatus({
    required this.phase,
    required this.now,
    required this.from,
    required this.until,
    required this.target,
    this.active,
    this.lastPlannedStart,
  });

  final FastingPhase phase;
  final DateTime now;

  /// Start of what the ring measures: the fast's start, or the eating
  /// window's opening.
  final DateTime from;

  /// Its end: the fast's goal, or the next planned fast (the eating window
  /// closes).
  final DateTime until;

  /// The plan's (or running fast's) fasting duration.
  final Duration target;
  final FastingSpan? active;

  /// The most recent planned fast start at or before now (a missed fast
  /// shows "planned for 8:00 PM").
  final DateTime? lastPlannedStart;

  Duration get elapsed {
    final d = now.difference(from);
    return d.isNegative ? Duration.zero : d;
  }

  Duration get span {
    final d = until.difference(from);
    return d <= Duration.zero ? const Duration(minutes: 1) : d;
  }

  /// 0‥1 of the ring (can exceed 1 while a fast runs past its goal).
  double get progress => elapsed.inSeconds / span.inSeconds;

  /// Time left until [until] (zero once passed).
  Duration get remaining {
    final d = until.difference(now);
    return d.isNegative ? Duration.zero : d;
  }

  bool get reached => phase == FastingPhase.fasting && !now.isBefore(until);

  /// Time fasted beyond the goal.
  Duration get overtime => reached ? now.difference(until) : Duration.zero;

  /// Whether a planned fast was missed within the last [grace] (waiting
  /// phase only).
  bool missedStart({Duration grace = const Duration(hours: 6)}) {
    final p = lastPlannedStart;
    return phase == FastingPhase.waiting && p != null && now.difference(p) < grace;
  }
}

/// Fasting timer arithmetic. Elapsed and remaining time are real
/// durations between instants; planned starts are wall times on calendar
/// days (through [BodyWallClock]), so both stay right across midnight and
/// daylight-saving changes.
abstract final class FastingMath {
  /// The first planned fast start (the last-meal time) strictly after
  /// [now].
  static DateTime nextPlannedStart(FastingPlan plan, DateTime now, {BodyWallClock clock = const LocalBodyWallClock()}) {
    final today = clock.dayOf(now);
    final t = clock.at(today, plan.lastMealMinutes);
    return t.isAfter(now) ? t : clock.at(BodyDays.add(today, 1), plan.lastMealMinutes);
  }

  /// The latest planned fast start at or before [now].
  static DateTime lastPlannedStart(FastingPlan plan, DateTime now, {BodyWallClock clock = const LocalBodyWallClock()}) {
    final today = clock.dayOf(now);
    final t = clock.at(today, plan.lastMealMinutes);
    return t.isAfter(now) ? clock.at(BodyDays.add(today, -1), plan.lastMealMinutes) : t;
  }

  static FastingStatus status({
    required FastingPlan plan,
    required DateTime now,
    FastingSpan? active,
    DateTime? lastEnd,
    BodyWallClock clock = const LocalBodyWallClock(),
  }) {
    if (active != null) {
      return FastingStatus(
        phase: FastingPhase.fasting,
        now: now,
        from: active.start,
        until: active.goalAt,
        target: active.target,
        active: active,
      );
    }
    final next = nextPlannedStart(plan, now, clock: clock);
    final prev = lastPlannedStart(plan, now, clock: clock);
    final window = plan.eatingWindow;
    final plannedOpen = next.subtract(window);
    // Broke a fast since the last planned start: eating from then on.
    if (window > Duration.zero && lastEnd != null && !lastEnd.isAfter(now) && lastEnd.isAfter(prev)) {
      return FastingStatus(phase: FastingPhase.eating, now: now, from: lastEnd, until: next, target: plan.target);
    }
    // Inside the planned eating window.
    if (window > Duration.zero && !now.isBefore(plannedOpen)) {
      return FastingStatus(phase: FastingPhase.eating, now: now, from: plannedOpen, until: next, target: plan.target);
    }
    final missed = lastEnd == null || !lastEnd.isAfter(prev);
    return FastingStatus(
      phase: FastingPhase.waiting,
      now: now,
      from: lastEnd != null && lastEnd.isAfter(prev) ? lastEnd : prev,
      until: next,
      target: plan.target,
      lastPlannedStart: missed ? prev : null,
    );
  }
}

/// Aggregates over past fasts.
@immutable
class FastingStats {
  const FastingStats({
    required this.streak,
    required this.completed,
    required this.total,
    this.longest,
    this.average,
    this.reachedToday = false,
  });

  /// Consecutive days (ending today, or yesterday while today's fast is
  /// still open) with a fast that reached its goal, counted on the day it
  /// ended.
  final int streak;

  /// Finished fasts that reached their goal.
  final int completed;

  /// Finished fasts.
  final int total;
  final Duration? longest;

  /// Mean length of finished fasts.
  final Duration? average;
  final bool reachedToday;

  static const FastingStats empty = FastingStats(streak: 0, completed: 0, total: 0);

  static FastingStats of(
    Iterable<FastingSpan> spans, {
    required DateTime now,
    BodyWallClock clock = const LocalBodyWallClock(),
  }) {
    final done = <String>{};
    Duration? longest;
    var total = 0, completed = 0;
    var sum = Duration.zero;
    for (final s in spans) {
      if (s.start.isAfter(now)) continue;
      final length = s.duration(now);
      final reached = s.reached(now);
      if (reached) done.add(BodyDays.key(clock.dayOf(s.end ?? now)));
      if (s.active) continue;
      total++;
      sum += length;
      if (reached) completed++;
      if (longest == null || length > longest) longest = length;
    }
    final today = clock.dayOf(now);
    final reachedToday = done.contains(BodyDays.key(today));
    var day = reachedToday ? today : BodyDays.add(today, -1);
    var streak = 0;
    while (done.contains(BodyDays.key(day))) {
      streak++;
      day = BodyDays.add(day, -1);
    }
    return FastingStats(
      streak: streak,
      completed: completed,
      total: total,
      longest: longest,
      average: total == 0 ? null : Duration(seconds: sum.inSeconds ~/ total),
      reachedToday: reachedToday,
    );
  }
}
