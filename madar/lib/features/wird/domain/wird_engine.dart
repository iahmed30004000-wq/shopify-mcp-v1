import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../core/domain/enums.dart';
import '../../../core/quran/ayah.dart';
import 'calendar_days.dart';
import 'quran_axis.dart';
import 'wird_plan.dart';

/// How a day went for a plan.
enum WirdDayStatus {
  /// The day's portion was read.
  met,

  /// Something was read, not the whole portion.
  partial,

  /// Nothing was read.
  missed,

  /// Nothing was owed (ahead of schedule, or the khatma is finished).
  rest,

  /// The plan was paused.
  paused,

  /// Today, not met yet.
  pending,
}

/// One day of a plan's history.
@immutable
class WirdDay {
  const WirdDay({required this.day, required this.status, this.quota = 0, this.done = 0});

  final DateTime day;
  final WirdDayStatus status;

  /// Units owed that day (after rounding to page / ayah boundaries).
  final double quota;

  /// Units read that day.
  final double done;

  /// Share of the portion read (1 when nothing was owed).
  double get progress =>
      quota <= WirdEngine.eps ? (status == WirdDayStatus.paused ? 0 : 1) : (done / quota).clamp(0, 1);
}

/// Today's portion of a plan.
@immutable
class WirdTarget {
  const WirdTarget({
    this.range,
    this.remaining,
    this.resumeAt,
    this.quota = 0,
    this.done = 0,
    this.base = 0,
    this.deviation = 0,
    this.met = false,
  });

  /// Today's whole portion (from where the day started to the target), null
  /// when nothing is owed.
  final AyahRange? range;

  /// What is left of it now (null once met).
  final AyahRange? remaining;

  /// The next unread ayah (null when a khatma is finished).
  final AyahRef? resumeAt;

  /// Units owed today (rounded to the portion's end).
  final double quota;

  /// Units read today.
  final double done;

  /// The plan's regular daily amount.
  final double base;

  /// Units behind (> 0) or ahead (< 0) of schedule when the day began.
  final double deviation;

  /// Today's portion is read (or nothing was owed).
  final bool met;

  double get progress => quota <= WirdEngine.eps ? (met ? 1 : 0) : (done / quota).clamp(0, 1);

  /// Units behind schedule at the start of today (0 when not behind).
  double get behind => deviation > WirdEngine.eps ? deviation : 0;

  /// Units ahead of schedule at the start of today (0 when not ahead).
  double get ahead => deviation < -WirdEngine.eps ? -deviation : 0;
}

/// Everything the wird screens show about one plan on one day.
@immutable
class WirdPlanState {
  const WirdPlanState({
    required this.plan,
    required this.today,
    required this.target,
    required this.days,
    required this.progress,
    required this.unitsPerKhatma,
    this.position = 0,
    this.span,
    this.cursor,
    this.streak = 0,
    this.bestStreak = 0,
    this.khatmas = 0,
    this.completedOn,
    this.projectedFinish,
    this.paused = false,
    this.started = true,
  });

  final WirdPlan plan;
  final DateTime today;
  final WirdTarget target;

  /// Start date … today (empty before the plan starts).
  final List<WirdDay> days;

  /// Units read since the plan's start.
  final double progress;
  final int unitsPerKhatma;

  /// Where the next unread ayah sits in the mushaf, `0…unitsPerKhatma`.
  final double position;

  /// Units a khatma plan covers (null for an open-ended plan).
  final double? span;

  /// Next unread ayah (null once a khatma is finished).
  final AyahRef? cursor;
  final int streak;
  final int bestStreak;

  /// Khatmas finished by this plan.
  final int khatmas;

  /// The day a khatma plan was finished.
  final DateTime? completedOn;

  /// When the plan (a khatma) or the current round of the mushaf (an
  /// open-ended plan) should finish at the recent pace.
  final DateTime? projectedFinish;
  final bool paused;

  /// False while the start date is still ahead.
  final bool started;

  bool get completed => completedOn != null;

  /// Progress through the khatma (khatma plans) or the current round of the
  /// mushaf (open-ended plans), 0…1.
  double get fraction {
    final s = span;
    if (s != null) return s <= 0 ? 1 : (progress / s).clamp(0, 1);
    return (position / unitsPerKhatma).clamp(0, 1);
  }

  WirdDay? dayOf(DateTime day) {
    final i = CalendarDays.between(plan.startDate, day);
    if (i < 0 || i >= days.length) return null;
    return days[i];
  }
}

/// The wird maths (pure): replays a plan's sessions day by day from its start
/// to find today's portion, the history, streaks and the projected finish.
///
/// * **Position.** Progress is the furthest point read, measured on a
///   [QuranAxis] in the plan's unit (fractions of pages, juz, hizb, or ayat).
///   A session moves the plan forward when it is tagged with the plan's id
///   (any range ahead of the position), or when it is untagged (logged by the
///   reader) and starts at or before the position and reaches past it.
/// * **Schedule.** An open-ended plan owes `amount × active days`; a khatma
///   owes the rest of the mushaf spread evenly up to its target date
///   (paused days are not counted).
/// * **Catch-up.** Today's portion is the regular amount plus the gap to the
///   schedule, all at once or spread (over the days left of a khatma, or
///   [WirdPlanMeta.catchUpDays]). Being ahead shrinks the portion the same
///   way (possibly to nothing).
/// * **Portions end on boundaries.** A page / juz / hizb portion of at least
///   one unit ends at the nearest unit boundary, so the day stops at the end
///   of a page.
abstract final class WirdEngine {
  static const double eps = 1e-6;

  /// Days of recent history the projected finish is based on.
  static const int paceWindow = 14;

  static WirdPlanState compute({
    required WirdPlan plan,
    required Iterable<WirdSession> sessions,
    required QuranAxis axis,
    required DateTime today,
  }) {
    today = CalendarDays.dateOnly(today);
    final index = axis.index;
    final total = index.total;
    final units = axis.units;
    final startG = index.indexOf(plan.start);
    final startPos = axis.positionOf(startG);
    final khatma = plan.isKhatma;
    final span = khatma ? units - startPos : null;
    double u(int g) => axis.positionOfCumulative(g) - startPos;

    // Sessions that may count, grouped by day, in the order they were logged.
    final relevant =
        sessions
            .where((s) => s.planId == null || s.planId == plan.id)
            .where((s) => CalendarDays.between(plan.startDate, s.day) >= 0 && CalendarDays.between(s.day, today) >= 0)
            .toList()
          ..sort((a, b) {
            final d = a.day.compareTo(b.day);
            return d != 0 ? d : a.createdAt.compareTo(b.createdAt);
          });
    final byDay = <String, List<WirdSession>>{};
    for (final s in relevant) {
      (byDay[CalendarDays.key(s.day)] ??= []).add(s);
    }

    int apply(int g, WirdSession s) {
      if (khatma && g >= total) return g;
      final lap = g ~/ total;
      final c = g - lap * total;
      final a = index.indexOf(s.range.first);
      final b = index.indexOf(s.range.last);
      final reaches = b + 1 > c;
      final counts = s.planId == plan.id ? reaches : (a <= c && reaches);
      if (!counts) return g;
      final next = lap * total + b + 1;
      return khatma ? math.min(next, total) : next;
    }

    // Days a khatma is spread over (paused days inside it excluded).
    var plannedDays = 0;
    if (khatma) {
      final end = plan.targetDate!;
      final calendar = CalendarDays.between(plan.startDate, end) + 1;
      var paused = 0;
      for (var d = plan.startDate; CalendarDays.between(d, end) >= 0; d = CalendarDays.add(d, 1)) {
        if (CalendarDays.between(d, today) < 0) break;
        if (plan.pausedOn(d, today: today)) paused++;
      }
      plannedDays = math.max(1, calendar - paused);
    }
    final base = khatma ? span! / plannedDays : plan.amountPerDay;

    double quotaFor(int active, double a0) {
      if (khatma) {
        final s = span!;
        final left = s - a0;
        if (left <= eps) return 0;
        final rem = plannedDays - active;
        if (rem <= 0) return left;
        final expected = math.min(s, s * active / plannedDays);
        final window = plan.meta.catchUp == WirdCatchUp.spread ? rem : 1;
        return (base + (expected - a0) / window).clamp(0.0, left);
      }
      final owed = plan.amountPerDay * active - a0;
      if (plan.meta.catchUp != WirdCatchUp.spread) return math.max(0.0, base + owed);
      var extra = owed / plan.meta.catchUpDays;
      // A portion of a unit or more ends on a whole page / juz / hizb (or
      // ayah), so a daily share of the debt under half a unit would be
      // rounded away every day and the plan would never catch up: owe at
      // least one whole unit a day (never more than the debt) until it does.
      if (owed > eps && (axis.unit == WirdUnit.ayat || base >= 1 - eps)) {
        extra = math.max(extra, math.min(owed, 1.0));
      }
      return math.max(0.0, base + extra);
    }

    double expectedBefore(int active) {
      if (khatma) return math.min(span!, span * active / plannedDays);
      return plan.amountPerDay * active;
    }

    int targetIndex(int g0, double a0, double quota) {
      if (quota <= eps) return g0;
      int t;
      if (axis.unit == WirdUnit.ayat) {
        t = g0 + math.max(1, quota.round());
      } else {
        final p = a0 + startPos + quota;
        var pr = p;
        if (quota >= 1 - eps) {
          pr = p.roundToDouble();
          if (pr <= axis.positionOfCumulative(g0) + eps) pr = p.ceilToDouble();
        }
        t = axis.indexAtCumulative(pr);
      }
      if (t <= g0) t = g0 + 1;
      if (khatma) t = math.min(t, total);
      return t;
    }

    var g = startG;
    var active = 0;
    DateTime? completedOn;
    final days = <WirdDay>[];
    var target = const WirdTarget();
    final started = CalendarDays.between(plan.startDate, today) >= 0;

    for (var day = plan.startDate; CalendarDays.between(day, today) >= 0; day = CalendarDays.add(day, 1)) {
      final daySessions = byDay[CalendarDays.key(day)] ?? const <WirdSession>[];
      final g0 = g;
      final a0 = u(g0);
      final isToday = CalendarDays.same(day, today);
      if (plan.pausedOn(day, today: today)) {
        for (final s in daySessions) {
          g = apply(g, s);
        }
        if (khatma && completedOn == null && g >= total) completedOn = day;
        days.add(WirdDay(day: day, status: WirdDayStatus.paused, done: u(g) - a0));
        if (isToday) {
          target = WirdTarget(
            resumeAt: khatma && g >= total ? null : index.refAt(g % total),
            done: u(g) - a0,
            base: base,
            deviation: expectedBefore(active) - a0,
          );
        }
        continue;
      }
      final quota = quotaFor(active, a0);
      final tg = targetIndex(g0, a0, quota);
      final owed = u(tg) - a0;
      for (final s in daySessions) {
        g = apply(g, s);
      }
      if (khatma && completedOn == null && g >= total) completedOn = day;
      final done = u(g) - a0;
      final WirdDayStatus status;
      if (owed <= eps) {
        status = done > eps ? WirdDayStatus.met : WirdDayStatus.rest;
      } else if (g >= tg) {
        status = WirdDayStatus.met;
      } else if (isToday) {
        status = WirdDayStatus.pending;
      } else {
        status = done > eps ? WirdDayStatus.partial : WirdDayStatus.missed;
      }
      days.add(WirdDay(day: day, status: status, quota: owed, done: done));
      if (isToday) {
        target = WirdTarget(
          range: owed > eps ? _range(index, g0, tg) : null,
          remaining: g < tg ? _range(index, g, tg) : null,
          resumeAt: khatma && g >= total ? null : index.refAt(g % total),
          quota: owed,
          done: done,
          base: base,
          deviation: expectedBefore(active) - a0,
          met: g >= tg,
        );
      }
      active++;
    }

    if (!started) {
      // Preview of the first day's portion.
      final quota = quotaFor(0, 0);
      final tg = targetIndex(startG, 0, quota);
      target = WirdTarget(
        range: _range(index, startG, tg),
        remaining: _range(index, startG, tg),
        resumeAt: plan.start,
        quota: u(tg),
        base: base,
      );
    }

    final paused = plan.pausedOn(today, today: today);
    final progress = u(g);
    final (streak, best) = _streaks(days);
    return WirdPlanState(
      plan: plan,
      today: today,
      target: target,
      days: List.unmodifiable(days),
      progress: progress,
      unitsPerKhatma: units,
      position: khatma && g >= total ? units.toDouble() : axis.positionOf(g % total),
      span: span,
      cursor: khatma && g >= total ? null : index.refAt(g % total),
      streak: streak,
      bestStreak: best,
      khatmas: khatma ? (completedOn != null ? 1 : 0) : g ~/ total,
      completedOn: completedOn,
      projectedFinish: paused || !started
          ? null
          : _projection(
              days: days,
              today: today,
              base: base,
              remaining: khatma ? span! - progress : units - (axis.positionOfCumulative(g) - (g ~/ total) * units),
              metToday: target.met,
              completedOn: completedOn,
            ),
      paused: paused,
      started: started,
    );
  }

  static AyahRange? _range(QuranIndex index, int fromG, int toGExclusive) {
    if (toGExclusive <= fromG) return null;
    final total = index.total;
    final first = index.refAt(fromG % total);
    final last = index.refAt((toGExclusive - 1) % total);
    // A portion that wraps into the next round ends at the end of the mushaf
    // for display; the rest is picked up tomorrow.
    if (last < first) return AyahRange(first, index.refAt(total - 1));
    return AyahRange(first, last);
  }

  /// Current and best streak of met days (paused and rest days neither count
  /// nor break it; today only counts once met).
  static (int, int) _streaks(List<WirdDay> days) {
    var best = 0, run = 0;
    for (final d in days) {
      switch (d.status) {
        case WirdDayStatus.met:
          run++;
          best = math.max(best, run);
        case WirdDayStatus.paused || WirdDayStatus.rest || WirdDayStatus.pending:
          break;
        case WirdDayStatus.partial || WirdDayStatus.missed:
          run = 0;
      }
    }
    return (run, best);
  }

  static DateTime? _projection({
    required List<WirdDay> days,
    required DateTime today,
    required double base,
    required double remaining,
    required bool metToday,
    required DateTime? completedOn,
  }) {
    if (completedOn != null) return completedOn;
    if (remaining <= eps) return today;
    var sum = 0.0, count = 0;
    for (var i = days.length - 1; i >= 0 && count < paceWindow; i--) {
      final d = days[i];
      if (CalendarDays.same(d.day, today) || d.status == WirdDayStatus.paused) continue;
      sum += math.max(0, d.done);
      count++;
    }
    final pace = count >= 3 && sum > eps ? sum / count : base;
    if (pace <= eps) return null;
    final n = (remaining / pace - eps).ceil();
    return CalendarDays.add(today, metToday ? n : math.max(0, n - 1));
  }
}
