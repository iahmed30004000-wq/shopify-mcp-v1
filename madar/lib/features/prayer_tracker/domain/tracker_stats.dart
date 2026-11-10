/// History maths of the prayer tracker: per-day summaries, streaks, totals,
/// the qada ledger and the month grid. Pure Dart – no clock, no database.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show immutable;

import '../../../core/db/database.dart' show PrayerLogRow;
import '../../../core/domain/enums.dart';
import 'tracker_days.dart';
import 'tracker_prayers.dart';

/// What was logged on one prayer day.
@immutable
class DaySummary {
  DaySummary({required DateTime day, required Map<Prayer, PrayerLogRow> logs})
    : day = TrackerDays.dateOnly(day),
      logs = Map.unmodifiable(logs);

  /// A day without any log.
  factory DaySummary.empty(DateTime day) => DaySummary(day: day, logs: const {});

  final DateTime day;
  final Map<Prayer, PrayerLogRow> logs;

  PrayerStatus? statusOf(Prayer p) => logs[p]?.status;

  Iterable<PrayerLogRow> get _fard => [for (final p in TrackerPrayers.obligatory) ?logs[p]];

  bool get isEmpty => logs.isEmpty;

  /// Obligatory prayers prayed on time, late or made up.
  int get fardPrayed => _fard.where((l) => l.status.counts).length;

  int get onTime => _fard.where((l) => l.status == PrayerStatus.prayed).length;

  int get late => _fard.where((l) => l.status == PrayerStatus.late).length;

  int get madeUp => _fard.where((l) => l.status == PrayerStatus.qada).length;

  /// Obligatory prayers logged as missed and not made up yet.
  int get missed => _fard.where((l) => l.status == PrayerStatus.missed).length;

  int get jamaah => _fard.where((l) => l.status.counts && l.inJamaah).length;

  int get mosque => _fard.where((l) => l.status.counts && l.atMosque).length;

  /// Voluntary prayers logged that day.
  Set<Prayer> get voluntary => {
    for (final p in TrackerPrayers.voluntary)
      if (logs[p]?.status.counts ?? false) p,
  };

  /// All five obligatory prayers were prayed or made up – the day counts
  /// toward a streak.
  bool get complete => fardPrayed == TrackerPrayers.obligatory.length;

  /// Share of the five prayed (0..1).
  double get completion => fardPrayed / TrackerPrayers.obligatory.length;

  /// Share of the prayed obligatory prayers prayed in jamaah (0..1).
  double get jamaahShare => fardPrayed == 0 ? 0 : jamaah / fardPrayed;
}

/// The current and the best run of complete days.
@immutable
class TrackerStreaks {
  const TrackerStreaks({required this.current, required this.best, required this.todayComplete});

  static const zero = TrackerStreaks(current: 0, best: 0, todayComplete: false);

  /// Complete days in a row up to today – or up to yesterday while today is
  /// still under way (an unfinished today never breaks the streak).
  final int current;

  /// The longest run of complete days ever.
  final int best;

  final bool todayComplete;

  /// Streaks from the set of complete prayer days. Any calendar day in
  /// between without all five prayers (including a day with no log at all)
  /// breaks a run; month and year boundaries do not.
  factory TrackerStreaks.of(Iterable<DateTime> completeDays, {required DateTime today}) {
    final ordinals = {for (final d in completeDays) TrackerDays.ordinal(d)};
    if (ordinals.isEmpty) return zero;
    final t = TrackerDays.ordinal(today);
    final todayComplete = ordinals.contains(t);
    var cursor = todayComplete ? t : t - 1;
    var current = 0;
    while (ordinals.contains(cursor)) {
      current++;
      cursor--;
    }
    final sorted = ordinals.toList()..sort();
    var best = 0;
    var run = 0;
    int? previous;
    for (final o in sorted) {
      run = previous != null && o == previous + 1 ? run + 1 : 1;
      best = math.max(best, run);
      previous = o;
    }
    return TrackerStreaks(current: current, best: math.max(best, current), todayComplete: todayComplete);
  }

  @override
  bool operator ==(Object other) =>
      other is TrackerStreaks && other.current == current && other.best == best && other.todayComplete == todayComplete;

  @override
  int get hashCode => Object.hash(current, best, todayComplete);

  @override
  String toString() => 'TrackerStreaks(current: $current, best: $best, todayComplete: $todayComplete)';
}

/// How one obligatory prayer went over a span.
@immutable
class PrayerBreakdown {
  const PrayerBreakdown({this.onTime = 0, this.late = 0, this.madeUp = 0, this.missed = 0});

  final int onTime;
  final int late;
  final int madeUp;
  final int missed;

  int get total => onTime + late + madeUp + missed;

  PrayerBreakdown _add(PrayerStatus s) => PrayerBreakdown(
    onTime: onTime + (s == PrayerStatus.prayed ? 1 : 0),
    late: late + (s == PrayerStatus.late ? 1 : 0),
    madeUp: madeUp + (s == PrayerStatus.qada ? 1 : 0),
    missed: missed + (s == PrayerStatus.missed ? 1 : 0),
  );
}

/// Totals over a span of days.
@immutable
class TrackerTotals {
  const TrackerTotals({
    this.days = 0,
    this.loggedDays = 0,
    this.completeDays = 0,
    this.fardPrayed = 0,
    this.onTime = 0,
    this.late = 0,
    this.madeUp = 0,
    this.missed = 0,
    this.jamaah = 0,
    this.mosque = 0,
    this.voluntary = const {},
    this.perPrayer = const {},
  });

  /// Sums [summaries] (a span of [days] calendar days; defaults to the
  /// number of summaries).
  factory TrackerTotals.of(Iterable<DaySummary> summaries, {int? days}) {
    var count = 0, logged = 0, complete = 0, prayed = 0, onTime = 0, late = 0, madeUp = 0, missed = 0;
    var jamaah = 0, mosque = 0;
    final voluntary = <Prayer, int>{};
    final per = <Prayer, PrayerBreakdown>{};
    for (final s in summaries) {
      count++;
      if (!s.isEmpty) logged++;
      if (s.complete) complete++;
      prayed += s.fardPrayed;
      onTime += s.onTime;
      late += s.late;
      madeUp += s.madeUp;
      missed += s.missed;
      jamaah += s.jamaah;
      mosque += s.mosque;
      for (final p in s.voluntary) {
        voluntary[p] = (voluntary[p] ?? 0) + 1;
      }
      for (final p in TrackerPrayers.obligatory) {
        final status = s.statusOf(p);
        if (status != null) per[p] = (per[p] ?? const PrayerBreakdown())._add(status);
      }
    }
    return TrackerTotals(
      days: days ?? count,
      loggedDays: logged,
      completeDays: complete,
      fardPrayed: prayed,
      onTime: onTime,
      late: late,
      madeUp: madeUp,
      missed: missed,
      jamaah: jamaah,
      mosque: mosque,
      voluntary: Map.unmodifiable(voluntary),
      perPrayer: Map.unmodifiable(per),
    );
  }

  final int days;
  final int loggedDays;
  final int completeDays;

  /// Obligatory prayers prayed on time, late or made up.
  final int fardPrayed;
  final int onTime;
  final int late;
  final int madeUp;

  /// Obligatory prayers still logged as missed.
  final int missed;
  final int jamaah;
  final int mosque;

  /// Voluntary prayers by kind.
  final Map<Prayer, int> voluntary;

  /// Each obligatory prayer's statuses.
  final Map<Prayer, PrayerBreakdown> perPrayer;

  int voluntaryOf(Prayer p) => voluntary[p] ?? 0;

  /// Sunnah rawatib prayed (all four together).
  int get rawatib => TrackerPrayers.rawatib.fold(0, (sum, p) => sum + voluntaryOf(p));

  PrayerBreakdown breakdownOf(Prayer p) => perPrayer[p] ?? const PrayerBreakdown();

  /// On time among the prayed obligatory prayers (0..1).
  double get onTimeShare => fardPrayed == 0 ? 0 : onTime / fardPrayed;

  /// In jamaah among the prayed obligatory prayers (0..1).
  double get jamaahShare => fardPrayed == 0 ? 0 : jamaah / fardPrayed;

  /// At the mosque among the prayed obligatory prayers (0..1).
  double get mosqueShare => fardPrayed == 0 ? 0 : mosque / fardPrayed;

  bool get isEmpty => fardPrayed == 0 && missed == 0 && voluntary.isEmpty;
}

/// A missed obligatory prayer waiting to be made up.
@immutable
class QadaEntry {
  const QadaEntry({required this.day, required this.log});

  /// The prayer day it was missed on (kept when it is made up).
  final DateTime day;
  final PrayerLogRow log;

  Prayer get prayer => log.prayer;
}

/// Missed obligatory prayers not made up yet (oldest first, then in the
/// order of the day – the order they are best made up in) and how many were
/// made up already.
@immutable
class QadaLedger {
  const QadaLedger({this.outstanding = const [], this.madeUp = 0});

  factory QadaLedger.of(Iterable<PrayerLogRow> rows) {
    final out = <QadaEntry>[];
    var madeUp = 0;
    for (final r in rows) {
      if (!TrackerPrayers.isObligatory(r.prayer)) continue;
      if (r.status == PrayerStatus.qada) madeUp++;
      if (r.status != PrayerStatus.missed) continue;
      final day = TrackerDays.parse(r.day);
      if (day == null) continue;
      out.add(QadaEntry(day: day, log: r));
    }
    out.sort((a, b) {
      final byDay = a.day.compareTo(b.day);
      if (byDay != 0) return byDay;
      return TrackerPrayers.obligatory.indexOf(a.prayer).compareTo(TrackerPrayers.obligatory.indexOf(b.prayer));
    });
    return QadaLedger(outstanding: List.unmodifiable(out), madeUp: madeUp);
  }

  final List<QadaEntry> outstanding;
  final int madeUp;

  bool get isEmpty => outstanding.isEmpty;

  /// The entries of [prayer] (all of them when null).
  List<QadaEntry> filtered(Prayer? prayer) => prayer == null
      ? outstanding
      : [
          for (final e in outstanding)
            if (e.prayer == prayer) e,
        ];

  /// Outstanding entries per obligatory prayer.
  Map<Prayer, int> get countsByPrayer => {
    for (final p in TrackerPrayers.obligatory) p: outstanding.where((e) => e.prayer == p).length,
  };
}

/// Everything the History tab shows, from every prayer log.
@immutable
class TrackerHistory {
  const TrackerHistory({required this.today, required this.days, required this.streaks, required this.qada});

  factory TrackerHistory.of(Iterable<PrayerLogRow> rows, {required DateTime today}) {
    final grouped = <DateTime, Map<Prayer, PrayerLogRow>>{};
    final all = <PrayerLogRow>[];
    for (final r in rows) {
      final day = TrackerDays.parse(r.day);
      if (day == null) continue;
      all.add(r);
      (grouped[day] ??= {})[r.prayer] = r;
    }
    final days = {for (final e in grouped.entries) e.key: DaySummary(day: e.key, logs: e.value)};
    final t = TrackerDays.dateOnly(today);
    return TrackerHistory(
      today: t,
      days: Map.unmodifiable(days),
      streaks: TrackerStreaks.of([
        for (final s in days.values)
          if (s.complete) s.day,
      ], today: t),
      qada: QadaLedger.of(all),
    );
  }

  /// The current prayer day.
  final DateTime today;

  /// Days with at least one log.
  final Map<DateTime, DaySummary> days;
  final TrackerStreaks streaks;
  final QadaLedger qada;

  DaySummary dayOf(DateTime d) => days[TrackerDays.dateOnly(d)] ?? DaySummary.empty(d);

  /// The first day with a log.
  DateTime? get firstDay => days.isEmpty ? null : days.keys.reduce((a, b) => a.isBefore(b) ? a : b);

  /// Totals of the days from [from] to [to] (inclusive).
  TrackerTotals totalsBetween(DateTime from, DateTime to) {
    final a = TrackerDays.ordinal(from);
    final b = TrackerDays.ordinal(to);
    if (b < a) return const TrackerTotals();
    return TrackerTotals.of([
      for (final s in days.values)
        if (TrackerDays.ordinal(s.day) >= a && TrackerDays.ordinal(s.day) <= b) s,
    ], days: b - a + 1);
  }

  /// Totals of a calendar month.
  TrackerTotals month(int year, int month) =>
      totalsBetween(DateTime(year, month), DateTime(year, month, TrackerDays.daysInMonth(year, month)));

  /// Totals of a calendar month up to [today]: the current month spans the
  /// days so far (days still to come are not "days without a log"), a past
  /// month all of its days and a future month none.
  TrackerTotals monthToDate(int year, int month) {
    final last = DateTime(year, month, TrackerDays.daysInMonth(year, month));
    return totalsBetween(DateTime(year, month), last.isAfter(today) ? today : last);
  }

  /// The last [count] days ending with [today], oldest first.
  List<DaySummary> lastDays(int count) => [for (var i = count - 1; i >= 0; i--) dayOf(TrackerDays.add(today, -i))];
}

/// A month laid out in weeks for the heatmap.
abstract final class MonthGrid {
  /// Index of [d]'s weekday with Sunday = 0 … Saturday = 6 (the convention
  /// of `MaterialLocalizations.firstDayOfWeekIndex`).
  static int weekdayIndex(DateTime d) => d.weekday % 7;

  /// The seven weekday indexes starting at [firstDayOfWeek].
  static List<int> weekdayOrder(int firstDayOfWeek) => [for (var i = 0; i < 7; i++) (firstDayOfWeek + i) % 7];

  /// The month's days in rows of seven, with null padding before the first
  /// and after the last day.
  static List<DateTime?> cells(int year, int month, {required int firstDayOfWeek}) {
    final first = DateTime(year, month);
    final lead = (weekdayIndex(first) - firstDayOfWeek + 7) % 7;
    final count = TrackerDays.daysInMonth(year, month);
    final out = <DateTime?>[
      for (var i = 0; i < lead; i++) null,
      for (var d = 1; d <= count; d++) DateTime(year, month, d),
    ];
    while (out.length % 7 != 0) {
      out.add(null);
    }
    return out;
  }
}
