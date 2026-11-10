import 'package:flutter/foundation.dart';

import '../../../../core/domain/enums.dart';
import 'dose_scheduler.dart';
import 'med_models.dart';
import 'meds_settings.dart';

/// Where a planned dose stands right now.
enum DoseState {
  /// Its time has not come.
  upcoming,

  /// Its time has come (within [MedsSettings.lateAfter]).
  due,

  /// Not taken well after its time.
  late,

  /// Not taken, and its window is over.
  missed,
  taken,
  skipped,

  /// Snoozed until a later moment.
  snoozed,
}

extension DoseStateX on DoseState {
  /// Waiting for an answer (Taken / Snooze / Skip make sense).
  bool get open => this == DoseState.upcoming || this == DoseState.due || this == DoseState.late || this == DoseState.snoozed;

  /// Its time has come and it has no answer.
  bool get needsAction => this == DoseState.due || this == DoseState.late;

  bool get done => this == DoseState.taken || this == DoseState.skipped;
}

/// A planned dose with its log entry and state.
@immutable
class TrackedDose {
  const TrackedDose({required this.dose, required this.state, this.log, required this.missesAt});

  final PlannedDose dose;
  final DoseState state;
  final DoseLog? log;

  /// When an unanswered dose counts as missed.
  final DateTime missesAt;

  DateTime? get takenAt => log?.takenAt;
  DateTime? get snoozedUntil => log?.snoozedUntil;

  /// The moment the dose is (again) due: its planned time, or the end of its
  /// snooze.
  DateTime get dueAt {
    final s = snoozedUntil;
    return s != null && s.isAfter(dose.at) ? s : dose.at;
  }

  String get key => dose.key;
}

/// A day's adherence counts (past and answered / expired doses only).
@immutable
class DayAdherence {
  const DayAdherence({
    required this.day,
    this.taken = 0,
    this.skipped = 0,
    this.missed = 0,
    this.pending = 0,
    this.late = 0,
  });

  final DateTime day;
  final int taken;
  final int skipped;
  final int missed;

  /// Not yet due, or due / late and still open.
  final int pending;

  /// Taken more than [MedsSettings.lateAfter] after their time.
  final int late;

  /// Doses whose outcome is known.
  int get counted => taken + skipped + missed;

  int get total => counted + pending;

  /// Taken ÷ counted (null when nothing was due).
  double? get rate => counted == 0 ? null : taken / counted;
}

/// Adherence over a range of days.
@immutable
class AdherenceSummary {
  const AdherenceSummary(this.days);

  /// Oldest first.
  final List<DayAdherence> days;

  int get taken => days.fold(0, (s, d) => s + d.taken);
  int get skipped => days.fold(0, (s, d) => s + d.skipped);
  int get missed => days.fold(0, (s, d) => s + d.missed);
  int get counted => taken + skipped + missed;

  double? get rate => counted == 0 ? null : taken / counted;

  /// Consecutive fully-taken days ending with the latest day that had doses.
  int get streak {
    var n = 0;
    for (final d in days.reversed) {
      if (d.counted == 0 && d.pending > 0) continue; // today, still open
      if (d.counted == 0) continue;
      if (d.missed > 0 || d.skipped > 0) break;
      n++;
    }
    return n;
  }
}

/// Matches the dose log to the plan and derives states and adherence.
abstract final class DoseTracker {
  /// A log without a slot (logged by hand, imported) answers the closest
  /// unanswered dose of its medication within this window.
  static const looseMatch = Duration(hours: 3);

  /// Pairs each dose with its log entry: first by slot (same medication,
  /// same `scheduledAt` minute), else a slot-less log within [looseMatch]
  /// of the dose's time, closest first, each log used once.
  static Map<String, DoseLog> match(Iterable<PlannedDose> doses, Iterable<DoseLog> logs) {
    final out = <String, DoseLog>{};
    final bySlot = <String, DoseLog>{};
    final loose = <String, List<DoseLog>>{};
    for (final l in logs) {
      final slot = l.slot;
      if (slot != null) {
        final key = PlannedDose.doseKey(l.medId, slot);
        final prev = bySlot[key];
        // Two entries for one slot (should not happen): the answered one wins.
        if (prev == null || _rank(l.status) > _rank(prev.status)) bySlot[key] = l;
      } else if (l.at != null && (l.status == DoseStatus.taken || l.status == DoseStatus.skipped)) {
        (loose[l.medId] ??= []).add(l);
      }
    }
    final unmatched = <PlannedDose>[];
    for (final d in doses) {
      final l = bySlot[d.key];
      if (l != null) {
        out[d.key] = l;
      } else {
        unmatched.add(d);
      }
    }
    if (loose.isEmpty) return out;
    // Closest pairs first, so a log goes to the dose it was meant for.
    final pairs = <(Duration, PlannedDose, DoseLog)>[];
    for (final d in unmatched) {
      for (final l in loose[d.medId] ?? const <DoseLog>[]) {
        final gap = l.at!.difference(d.baseAt).abs();
        if (gap <= looseMatch) pairs.add((gap, d, l));
      }
    }
    pairs.sort((a, b) => a.$1.compareTo(b.$1));
    final used = <String>{};
    for (final (_, d, l) in pairs) {
      if (out.containsKey(d.key) || used.contains(l.id)) continue;
      out[d.key] = l;
      used.add(l.id);
    }
    return out;
  }

  static int _rank(DoseStatus s) => switch (s) {
    DoseStatus.taken => 3,
    DoseStatus.skipped => 2,
    DoseStatus.snoozed => 1,
    DoseStatus.missed => 0,
  };

  /// The moment an unanswered [dose] counts as missed: [MedsSettings.missedAfter]
  /// after it is due, or when [nextSameMed] (the next dose of the same
  /// medication) comes due, whichever is first.
  static DateTime missesAt(PlannedDose dose, DateTime dueAt, MedsSettings settings, {PlannedDose? nextSameMed}) {
    final byWindow = dueAt.add(Duration(minutes: settings.missedAfter));
    final next = nextSameMed?.at;
    if (next != null && next.isAfter(dueAt) && next.isBefore(byWindow)) return next;
    return byWindow;
  }

  /// The state of [dose] at [now].
  static DoseState stateOf(
    PlannedDose dose,
    DoseLog? log,
    DateTime now,
    MedsSettings settings, {
    PlannedDose? nextSameMed,
  }) => track(dose, log, now, settings, nextSameMed: nextSameMed).state;

  static TrackedDose track(
    PlannedDose dose,
    DoseLog? log,
    DateTime now,
    MedsSettings settings, {
    PlannedDose? nextSameMed,
  }) {
    final snooze = log?.snoozedUntil;
    final dueAt = snooze != null && snooze.isAfter(dose.at) ? snooze : dose.at;
    final misses = missesAt(dose, dueAt, settings, nextSameMed: nextSameMed);
    final DoseState state;
    switch (log?.status) {
      case DoseStatus.taken:
        state = DoseState.taken;
      case DoseStatus.skipped:
        state = DoseState.skipped;
      case DoseStatus.missed:
        state = DoseState.missed;
      case DoseStatus.snoozed when snooze != null && now.isBefore(snooze):
        state = DoseState.snoozed;
      default:
        if (now.isBefore(dueAt)) {
          state = DoseState.upcoming;
        } else if (!now.isBefore(misses)) {
          state = DoseState.missed;
        } else if (now.difference(dueAt) >= Duration(minutes: settings.lateAfter)) {
          state = DoseState.late;
        } else {
          state = DoseState.due;
        }
    }
    return TrackedDose(dose: dose, state: state, log: log, missesAt: misses);
  }

  /// Tracks every dose of [plans] against [logs] at [now].
  static List<TrackedDose> trackAll(
    Iterable<PlannedDose> doses,
    Iterable<DoseLog> logs,
    DateTime now,
    MedsSettings settings,
  ) {
    final list = doses.toList();
    final matched = match(list, logs);
    final byMed = <String, List<PlannedDose>>{};
    for (final d in list) {
      (byMed[d.medId] ??= []).add(d);
    }
    for (final l in byMed.values) {
      l.sort((a, b) => a.at.compareTo(b.at));
    }
    PlannedDose? nextOf(PlannedDose d) {
      final same = byMed[d.medId]!;
      final i = same.indexOf(d);
      return i >= 0 && i < same.length - 1 ? same[i + 1] : null;
    }

    return [for (final d in list) track(d, matched[d.key], now, settings, nextSameMed: nextOf(d))];
  }

  /// Adherence of each plan's day (oldest first).
  static AdherenceSummary adherence(
    List<DayPlan> plans,
    Iterable<DoseLog> logs,
    DateTime now,
    MedsSettings settings, {
    String? medId,
  }) {
    final allDoses = [
      for (final p in plans)
        for (final d in p.doses)
          if (medId == null || d.medId == medId)
            if (d.med.createdAt == null || !d.slot.isBefore(_minuteFloor(d.med.createdAt!))) d,
    ];
    final tracked = trackAll(allDoses, logs, now, settings);
    final byDay = <String, List<TrackedDose>>{};
    for (final t in tracked) {
      (byDay[MedDays.key(t.dose.day)] ??= []).add(t);
    }
    return AdherenceSummary([
      for (final p in plans) _dayOf(p.day, byDay[MedDays.key(p.day)] ?? const [], settings),
    ]);
  }

  static DateTime _minuteFloor(DateTime t) => DateTime(t.year, t.month, t.day, t.hour, t.minute);

  static DayAdherence _dayOf(DateTime day, List<TrackedDose> doses, MedsSettings settings) {
    var taken = 0, skipped = 0, missed = 0, pending = 0, late = 0;
    for (final t in doses) {
      switch (t.state) {
        case DoseState.taken:
          taken++;
          final at = t.takenAt;
          if (at != null && at.difference(t.dose.at) >= Duration(minutes: settings.lateAfter)) late++;
        case DoseState.skipped:
          skipped++;
        case DoseState.missed:
          missed++;
        case DoseState.upcoming || DoseState.due || DoseState.late || DoseState.snoozed:
          pending++;
      }
    }
    return DayAdherence(day: day, taken: taken, skipped: skipped, missed: missed, pending: pending, late: late);
  }
}

/// Stock arithmetic.
abstract final class MedStock {
  /// Units a dose uses from the stock: its amount when the unit is a count
  /// (tablets, capsules, ampoules, drops, puffs…) and the amount is whole,
  /// else one.
  static int unitsPerDose(String? unit, double? amount) {
    if (amount == null || amount <= 0) return 1;
    if (amount != amount.roundToDouble()) return 1;
    if (unit == null || !isCountUnit(unit)) return 1;
    return amount.round();
  }

  static final RegExp _count = RegExp(
    r'^(tab|tabs|tablet|tablets|pill|pills|cap|caps|capsule|capsules|amp|amps|ampoule|ampoules|ampule|vial|vials|'
    r'drop|drops|puff|puffs|sachet|sachets|patch|patches|unit dose|dose|doses|piece|pieces|'
    r'حبة|حبه|حبات|حبّة|حبّات|قرص|أقراص|اقراص|كبسولة|كبسوله|كبسولات|أمبولة|امبولة|أمبولات|حقنة|حقن|نقطة|نقط|نقاط|'
    r'بخة|بخّة|بخات|كيس|أكياس|لصقة|لصقات|جرعة|جرعات)$',
    caseSensitive: false,
    unicode: true,
  );

  static bool isCountUnit(String unit) => _count.hasMatch(unit.trim());

  static bool needsRefill(int? stock, int? refillAt) => stock != null && refillAt != null && stock <= refillAt;

  /// Taking a dose moved the stock across the refill threshold.
  static bool crossedRefill({required int? before, required int? after, required int? refillAt}) =>
      before != null && after != null && refillAt != null && before > refillAt && after <= refillAt;

  /// Whole days the stock lasts at [unitsPerDay] (null when unknown).
  static int? daysLeft(int? stock, double unitsPerDay) {
    if (stock == null || unitsPerDay <= 0) return null;
    return (stock / unitsPerDay).floor();
  }
}
