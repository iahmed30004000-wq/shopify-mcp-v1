import 'package:flutter/foundation.dart';

import '../../../core/domain/enums.dart';
import '../../../core/quran/ayah.dart';
import '../../wird/domain/quran_axis.dart';
import 'ramadan_calendar.dart';

/// A run of mushaf pages, 1-based and inclusive. Empty when [pages] is 0.
@immutable
class KhatmahPortion {
  const KhatmahPortion(this.fromPage, this.pages);

  /// First page of the run (meaningless when empty).
  final int fromPage;
  final int pages;

  bool get isEmpty => pages <= 0;
  int get toPage => fromPage + pages - 1;

  /// The ayat of this run on [axis] (the same page axis the wird uses, so the
  /// plan follows the app's mushaf and never hard-codes one). Null when empty.
  AyahRange? ayahRange(QuranAxis axis) {
    assert(axis.unit == WirdUnit.pages, 'the khatmah plan counts pages');
    if (isEmpty) return null;
    return axis.index.rangeOf(axis.unitStart(fromPage - 1), axis.unitStart(toPage));
  }

  @override
  bool operator ==(Object other) => other is KhatmahPortion && other.fromPage == fromPage && other.pages == pages;

  @override
  int get hashCode => Object.hash(fromPage, pages);

  @override
  String toString() => isEmpty ? 'KhatmahPortion(empty)' : 'KhatmahPortion($fromPage-$toPage)';
}

enum KhatmahStatus {
  /// The plan's first day has not come; today shows day 1 as a preview.
  notStarted,

  /// Inside the plan's days with pages left.
  active,

  /// Every page is read.
  finished,

  /// The plan's days are over and pages remain: the shortfall and a
  /// suggested extension are reported; today shows a catch-up portion.
  overdue,
}

/// The plan: finish [totalPages] pages in [days] days from [startDate], never
/// asking for more than [ceilingPages] a day.
@immutable
class KhatmahPlan {
  KhatmahPlan({
    required DateTime startDate,
    this.totalPages = 604,
    int days = defaultDays,
    int ceilingPages = defaultCeilingPages,
  }) : startDate = civilDay(startDate),
       days = days < 1 ? 1 : days,
       ceilingPages = ceilingPages < 1 ? 1 : ceilingPages;

  /// A plan for a Ramadan: starts on its first day; [days] is capped at the
  /// month's length so the khatmah is finished inside the month.
  factory KhatmahPlan.forSpan(
    RamadanSpan span, {
    required int totalPages,
    int days = defaultDays,
    int ceilingPages = defaultCeilingPages,
  }) => KhatmahPlan(
    startDate: span.first,
    totalPages: totalPages,
    days: days > span.length ? span.length : days,
    ceilingPages: ceilingPages,
  );

  factory KhatmahPlan.fromJson(Map<String, dynamic> json) {
    final start = DateTime.tryParse('${json['startDate']}') ?? DateTime(2000);
    return KhatmahPlan(
      startDate: start,
      totalPages: _int(json['totalPages']) ?? 604,
      days: _int(json['days']) ?? defaultDays,
      ceilingPages: _int(json['ceilingPages']) ?? defaultCeilingPages,
    );
  }

  static const int defaultDays = 30;

  /// A starting value only; the owner edits it (a Ramadan with long working
  /// days needs a low ceiling, a free week a high one).
  static const int defaultCeilingPages = 40;

  final DateTime startDate;
  final int totalPages;
  final int days;
  final int ceilingPages;

  KhatmahPlan copyWith({int? days, int? ceilingPages}) => KhatmahPlan(
    startDate: startDate,
    totalPages: totalPages,
    days: days ?? this.days,
    ceilingPages: ceilingPages ?? this.ceilingPages,
  );

  /// Days since the start (0 = the first day; negative before it).
  int dayIndexOf(DateTime date) => civilDaysBetween(startDate, date);

  /// The portions of an even re-plan: [remaining] pages over [daysLeft] days,
  /// the first days taking the odd pages, none above the ceiling. `pages`
  /// holds one entry per day; `shortfall` is what did not fit.
  ({List<int> pages, int shortfall}) spread(int remaining, int daysLeft) {
    final r = remaining < 0 ? 0 : remaining;
    if (daysLeft <= 0) return (pages: const [], shortfall: r);
    final q = r ~/ daysLeft, extra = r % daysLeft;
    final pages = [for (var i = 0; i < daysLeft; i++) (q + (i < extra ? 1 : 0)).clamp(0, ceilingPages)];
    return (pages: pages, shortfall: r - pages.fold<int>(0, (a, b) => a + b));
  }

  /// Pages that an unbroken, never-behind reader has read by the START of day
  /// [dayIndex] (the original even plan).
  int plannedBefore(int dayIndex) {
    final d = dayIndex.clamp(0, days);
    final q = totalPages ~/ days, extra = totalPages % days;
    return d * q + (d < extra ? d : extra);
  }

  /// Today's portion, the re-planned rest, and what is left to catch up.
  KhatmahToday today(DateTime date, KhatmahProgress progress) {
    final rawIndex = dayIndexOf(date);
    final index = rawIndex < 0 ? 0 : rawIndex;
    final now = progress.frontier.clamp(0, totalPages);
    // The re-plan is anchored at the start of the day, so today's portion does
    // not shrink as he reads through it.
    final before = progress.frontierBefore(index).clamp(0, totalPages);
    final remainingAtDayStart = totalPages - before;
    final remainingNow = totalPages - now;
    final readToday = (now - before).clamp(0, totalPages);

    if (remainingNow <= 0) {
      return KhatmahToday._(
        status: KhatmahStatus.finished,
        dayIndex: index,
        daysLeft: 0,
        portion: KhatmahPortion(before + 1, 0),
        readToday: readToday,
        remainingPages: 0,
        upcoming: const [],
        shortfallPages: 0,
        suggestedExtensionDays: 0,
        pagesBehind: 0,
      );
    }

    final daysLeft = days - index;
    if (daysLeft <= 0) {
      // Past the plan's last day: nothing can be spread. Offer a catch-up
      // portion within the ceiling and say how many extra days the rest needs.
      final catchUp = remainingAtDayStart < ceilingPages ? remainingAtDayStart : ceilingPages;
      return KhatmahToday._(
        status: KhatmahStatus.overdue,
        dayIndex: index,
        daysLeft: 0,
        portion: KhatmahPortion(before + 1, catchUp),
        readToday: readToday,
        remainingPages: remainingNow,
        upcoming: const [],
        shortfallPages: remainingNow,
        suggestedExtensionDays: _ceilDiv(remainingNow, ceilingPages),
        pagesBehind: remainingNow,
      );
    }

    final plan = spread(remainingAtDayStart, daysLeft);
    final todayPages = plan.pages.first;
    // Reading beyond today's portion lightens the days after it.
    final extraToday = readToday > todayPages ? readToday - todayPages : 0;
    final later = spread(remainingAtDayStart - (todayPages > readToday ? todayPages : readToday), daysLeft - 1);
    final shortfall = (plan.shortfall - extraToday).clamp(0, totalPages);
    return KhatmahToday._(
      status: rawIndex < 0 ? KhatmahStatus.notStarted : KhatmahStatus.active,
      dayIndex: index,
      daysLeft: daysLeft,
      portion: KhatmahPortion(before + 1, todayPages),
      readToday: readToday,
      remainingPages: remainingNow,
      upcoming: later.pages,
      shortfallPages: shortfall,
      suggestedExtensionDays: shortfall == 0 ? 0 : _ceilDiv(shortfall, ceilingPages),
      pagesBehind: (plannedBefore(index) - before).clamp(0, totalPages),
    );
  }

  Map<String, dynamic> toJson() => {
    'startDate':
        '${startDate.year.toString().padLeft(4, '0')}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}',
    'totalPages': totalPages,
    'days': days,
    'ceilingPages': ceilingPages,
  };

  @override
  bool operator ==(Object other) =>
      other is KhatmahPlan &&
      other.startDate == startDate &&
      other.totalPages == totalPages &&
      other.days == days &&
      other.ceilingPages == ceilingPages;

  @override
  int get hashCode => Object.hash(startDate, totalPages, days, ceilingPages);
}

int _ceilDiv(int a, int b) => (a + b - 1) ~/ b;

int? _int(Object? v) => v is int ? v : (v is num ? v.toInt() : int.tryParse('$v'));

/// How far he has read, as the page reached at the end of each day he read
/// (0-based day index of the plan → pages read from page 1 so far).
///
/// Keeping the frontier per day lets the plan tell "what was left when today
/// began" from "what is left now", and survives a phone clock changed by hand.
@immutable
class KhatmahProgress {
  KhatmahProgress([Map<int, int> frontierByDay = const {}])
    : frontierByDay = Map.unmodifiable(_normalise(frontierByDay));

  factory KhatmahProgress.fromJson(Map<String, dynamic> json) {
    final raw = json['frontierByDay'];
    final out = <int, int>{};
    if (raw is Map) {
      for (final e in raw.entries) {
        final day = int.tryParse('${e.key}'), page = _int(e.value);
        if (day != null && day >= 0 && page != null && page > 0) out[day] = page;
      }
    }
    return KhatmahProgress(out);
  }

  /// Day index → pages read after that day (always rising with the day).
  final Map<int, int> frontierByDay;

  static Map<int, int> _normalise(Map<int, int> m) {
    final keys = m.keys.where((k) => k >= 0 && (m[k] ?? 0) > 0).toList()..sort();
    final out = <int, int>{};
    var high = 0;
    for (final k in keys) {
      high = m[k]! > high ? m[k]! : high;
      out[k] = high;
    }
    return out;
  }

  /// Pages read so far.
  int get frontier => frontierByDay.isEmpty ? 0 : frontierByDay.values.last;

  /// Pages read before day [dayIndex] began.
  int frontierBefore(int dayIndex) {
    var f = 0;
    for (final e in frontierByDay.entries) {
      if (e.key >= dayIndex) break;
      f = e.value;
    }
    return f;
  }

  /// Marks pages up to [page] read on day [dayIndex] (clamped between what
  /// was read before that day and [totalPages]; never below an earlier day's
  /// mark). Returns the new progress; keep the old one to undo.
  KhatmahProgress markReadThrough(int dayIndex, int page, {required int totalPages}) {
    final idx = dayIndex < 0 ? 0 : dayIndex;
    final before = frontierBefore(idx);
    final to = page.clamp(before, totalPages);
    final next = Map<int, int>.of(frontierByDay);
    if (to <= before) {
      next.remove(idx);
    } else {
      next[idx] = to;
    }
    return KhatmahProgress(next);
  }

  /// Marks today's whole [portion] read (what the one-tap button does).
  KhatmahProgress markPortionRead(int dayIndex, KhatmahPortion portion, {required int totalPages}) =>
      portion.isEmpty ? this : markReadThrough(dayIndex, portion.toPage, totalPages: totalPages);

  Map<String, dynamic> toJson() => {
    'frontierByDay': {for (final e in frontierByDay.entries) '${e.key}': e.value},
  };

  @override
  bool operator ==(Object other) => other is KhatmahProgress && mapEquals(other.frontierByDay, frontierByDay);

  @override
  int get hashCode => Object.hashAll(frontierByDay.entries.map((e) => Object.hash(e.key, e.value)));
}

/// The answer to "what do I read today?".
@immutable
class KhatmahToday {
  const KhatmahToday._({
    required this.status,
    required this.dayIndex,
    required this.daysLeft,
    required this.portion,
    required this.readToday,
    required this.remainingPages,
    required this.upcoming,
    required this.shortfallPages,
    required this.suggestedExtensionDays,
    required this.pagesBehind,
  });

  final KhatmahStatus status;

  /// 0-based day of the plan (clamped at 0 before the start).
  final int dayIndex;

  /// Plan days left including today (0 once the plan's days are over).
  final int daysLeft;

  /// Today's portion, fixed from what was left when the day began.
  final KhatmahPortion portion;

  /// Pages read today so far.
  final int readToday;

  /// Pages still unread, right now.
  final int remainingPages;

  /// Pages per day for the days after today, re-planned.
  final List<int> upcoming;

  /// Pages that cannot fit in the remaining days under the ceiling (0 when
  /// the plan still fits). The ceiling is never exceeded; this is reported
  /// instead.
  final int shortfallPages;

  /// Extra days (at the ceiling) that would absorb [shortfallPages].
  final int suggestedExtensionDays;

  /// Pages behind the original even plan at the start of today.
  final int pagesBehind;

  bool get todayDone => remainingPages <= 0 || (readToday >= portion.pages && portion.pages > 0);

  /// Pages of today's portion still to read.
  int get portionLeft => (portion.pages - readToday).clamp(0, portion.pages);
}
