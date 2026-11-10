/// «أهدافه بكلامه» · his own memorisation goals (Part 14).
///
/// Pure Dart. Three shapes, and they are exactly the three he asked for:
///
/// * «الكهف كل جمعة» – [HifzGoalKind.rangeOnWeekday]: a stretch, on one
///   weekday of every week.
/// * «راجع جزء عمّ» – [HifzGoalKind.rangeReview]: keep a stretch under
///   review, so that every ayah of it is gone over at least once inside
///   the goal's window of days.
/// * «N صفحات باليوم» – [HifzGoalKind.amountPerDay]: an amount of the
///   mushaf every day, in pages, juz', hizb or ayat.
///
/// **The title is his, verbatim.** The engine never writes a goal's name
/// and never renames one; a screen shows [HifzGoal.title] as he typed it.
///
/// **Progress is read off the log**, exactly like the strength: an ayah
/// counts towards a goal because it was actually recited, written or
/// drilled that day, never because a screen was opened.
library;

import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../../../core/domain/enums.dart';
import '../../../core/quran/ayah.dart';
import '../../tasmee/tasmee.dart';
import '../../wird/domain/calendar_days.dart';
import 'hifz_strength.dart';
import 'mushaf_shape.dart';

/// One goal, in his own words.
@immutable
final class HifzGoal {
  const HifzGoal({
    required this.id,
    required this.title,
    required this.kind,
    required this.createdAt,
    this.range,
    this.weekday,
    this.amount,
    this.unit = WirdUnit.pages,
    this.window,
    this.offsetMinutes = 15,
    this.remind = true,
    this.active = true,
    this.sortOrder = 0,
    this.withinDays = 7,
  });

  final String id;

  /// His own words («الكهف كل جمعة»). Never generated, never rewritten.
  final String title;

  final HifzGoalKind kind;

  /// The stretch the goal is about (null for [HifzGoalKind.amountPerDay]).
  final AyahRange? range;

  /// `DateTime.monday … DateTime.sunday` (Friday is `DateTime.friday`, 5).
  final int? weekday;

  /// How much a day, for [HifzGoalKind.amountPerDay].
  final double? amount;
  final WirdUnit unit;

  /// The prayer the reminder hangs off – never a bare clock.
  final PrayerWindow? window;

  /// Minutes after that prayer.
  final int offsetMinutes;

  final bool remind;
  final bool active;
  final int sortOrder;
  final DateTime createdAt;

  /// How many days a [HifzGoalKind.rangeReview] goal has to cover its
  /// whole stretch in.
  final int withinDays;

  /// Whether the goal asks for something on [day].
  bool appliesOn(DateTime day) {
    if (!active) return false;
    return switch (kind) {
      HifzGoalKind.rangeOnWeekday => weekday == null || day.weekday == weekday,
      HifzGoalKind.rangeReview || HifzGoalKind.amountPerDay => true,
    };
  }

  /// Whether a reminder can be planned at all (he wants one and said which
  /// prayer it hangs off).
  bool get canRemind => active && remind && window != null && window != PrayerWindow.anytime;

  @override
  String toString() => 'HifzGoal($title, ${kind.name}${range == null ? '' : ' $range'})';
}

/// How one goal stands on one day.
@immutable
final class HifzGoalProgress {
  const HifzGoalProgress({
    required this.goal,
    required this.day,
    required this.due,
    required this.done,
    required this.target,
    required this.unitName,
    this.lastDoneDay,
    this.remaining,
  });

  final HifzGoal goal;
  final DateTime day;

  /// Whether the goal asks for something today.
  final bool due;

  /// How much of it is done (ayat, pages, juz' or hizb – [unitName] says).
  final int done;
  final int target;

  /// `ayat` · `pages` · `juz` · `hizb`, so a screen knows what it is
  /// counting without guessing.
  final String unitName;

  /// The last day something of this goal was done.
  final DateTime? lastDoneDay;

  /// What is still missing, as ranges (for the stretch goals).
  final List<AyahRange>? remaining;

  bool get met => target <= 0 || done >= target;

  double get progress => target <= 0 ? 1 : (done / target).clamp(0.0, 1.0);

  @override
  String toString() => 'HifzGoalProgress(${goal.title}: $done/$target $unitName${met ? ', met' : ''})';
}

/// Reading the goals off the log.
abstract final class HifzGoalProgressReader {
  /// How [goal] stands on [day], from the recitation log and nothing else.
  static HifzGoalProgress of(
    HifzGoal goal, {
    required DateTime day,
    required MushafShape shape,
    required Iterable<TasmeeSession> log,
  }) {
    final today = CalendarDays.dateOnly(day);
    final due = goal.appliesOn(today);
    switch (goal.kind) {
      case HifzGoalKind.rangeOnWeekday:
        final range = goal.range;
        if (range == null) {
          return HifzGoalProgress(goal: goal, day: today, due: due, done: 0, target: 0, unitName: 'ayat');
        }
        final wanted = Mushaf.ayatIn(shape, Mushaf.clamp(shape, range));
        final done = _refsOn(log, from: today, to: today, within: range);
        return HifzGoalProgress(
          goal: goal,
          day: today,
          due: due,
          done: done.length,
          target: wanted.length,
          unitName: 'ayat',
          lastDoneDay: _lastDayTouching(log, range, today),
          remaining: Mushaf.rangesOf(shape, [
            for (final r in wanted)
              if (!done.contains(r.toString())) r,
          ]),
        );
      case HifzGoalKind.rangeReview:
        final range = goal.range;
        if (range == null) {
          return HifzGoalProgress(goal: goal, day: today, due: due, done: 0, target: 0, unitName: 'ayat');
        }
        final wanted = Mushaf.ayatIn(shape, Mushaf.clamp(shape, range));
        final since = CalendarDays.add(today, -(math.max(1, goal.withinDays) - 1));
        final done = _refsOn(log, from: since, to: today, within: range);
        return HifzGoalProgress(
          goal: goal,
          day: today,
          due: due,
          done: done.length,
          target: wanted.length,
          unitName: 'ayat',
          lastDoneDay: _lastDayTouching(log, range, today),
          remaining: Mushaf.rangesOf(shape, [
            for (final r in wanted)
              if (!done.contains(r.toString())) r,
          ]),
        );
      case HifzGoalKind.amountPerDay:
        final refs = _refsOn(log, from: today, to: today);
        final units = <int>{};
        for (final key in refs) {
          final ref = AyahRef.tryParse(key);
          if (ref == null) continue;
          units.add(switch (goal.unit) {
            WirdUnit.pages => shape.pageOf(ref),
            WirdUnit.juz => shape.juzOf(ref),
            WirdUnit.hizb => shape.hizbOf(ref),
            WirdUnit.ayat => shape.indexOf(ref),
          });
        }
        return HifzGoalProgress(
          goal: goal,
          day: today,
          due: due,
          done: units.length,
          target: (goal.amount ?? 0).ceil(),
          unitName: goal.unit.name,
          lastDoneDay: _lastDayTouching(log, null, today),
        );
    }
  }

  /// Every goal, in his own order.
  static List<HifzGoalProgress> all(
    Iterable<HifzGoal> goals, {
    required DateTime day,
    required MushafShape shape,
    required Iterable<TasmeeSession> log,
  }) {
    final sorted = goals.toList()
      ..sort((a, b) {
        final o = a.sortOrder.compareTo(b.sortOrder);
        return o != 0 ? o : a.createdAt.compareTo(b.createdAt);
      });
    return [for (final g in sorted) of(g, day: day, shape: shape, log: log)];
  }

  /// The refs actually worked on between two days (inclusive), optionally
  /// only those inside [within]. Modes that judge nothing – «شازام القرآن»
  /// – do not count.
  static Set<String> _refsOn(
    Iterable<TasmeeSession> log, {
    required DateTime from,
    required DateTime to,
    AyahRange? within,
  }) {
    final out = <String>{};
    for (final s in log) {
      if (!HifzStrengthModel.judges(s.mode)) continue;
      if (CalendarDays.between(from, s.day) < 0 || CalendarDays.between(s.day, to) < 0) continue;
      for (final a in s.ayat) {
        if (a.counts.reached <= 0) continue;
        if (within != null && !within.contains(a.ref)) continue;
        out.add(a.ref.toString());
      }
    }
    return out;
  }

  static DateTime? _lastDayTouching(Iterable<TasmeeSession> log, AyahRange? range, DateTime today) {
    DateTime? best;
    for (final s in log) {
      if (!HifzStrengthModel.judges(s.mode)) continue;
      if (CalendarDays.between(s.day, today) < 0) continue;
      for (final a in s.ayat) {
        if (a.counts.reached <= 0) continue;
        if (range != null && !range.contains(a.ref)) continue;
        if (best == null || a.day.isAfter(best)) best = a.day;
      }
    }
    return best;
  }
}
