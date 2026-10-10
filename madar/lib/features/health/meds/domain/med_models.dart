import 'package:flutter/foundation.dart';

import '../../../../core/domain/enums.dart';

/// Calendar-day helpers (local midnight, zone-free arithmetic).
abstract final class MedDays {
  /// Local midnight of [t].
  static DateTime dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);

  /// [day] moved by [days] calendar days (rolls over months and years).
  static DateTime add(DateTime day, int days) => DateTime(day.year, day.month, day.day + days);

  /// Whole calendar days from [from] to [to] (negative when [to] is earlier).
  static int between(DateTime from, DateTime to) =>
      DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

  static bool same(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  /// `2026-09-28`.
  static String key(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  /// Parses `yyyy-MM-dd` (a longer ISO string is cut to its date); null when
  /// malformed.
  static DateTime? parse(Object? raw) {
    if (raw is DateTime) return dateOnly(raw);
    if (raw is! String) return null;
    final m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(raw.trim());
    if (m == null) return null;
    final y = int.parse(m[1]!), mo = int.parse(m[2]!), d = int.parse(m[3]!);
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    return DateTime(y, mo, d);
  }

  /// [day] plus [months] calendar months, the day of month clamped to the
  /// target month's length (31 Jan + 1 month = 28/29 Feb).
  static DateTime addMonths(DateTime day, int months, {int? dayOfMonth}) {
    final total = day.year * 12 + (day.month - 1) + months;
    final y = total ~/ 12, m = total % 12 + 1;
    final last = DateTime(y, m + 1, 0).day;
    final d = (dayOfMonth ?? day.day).clamp(1, last);
    return DateTime(y, m, d);
  }
}

/// A wall-clock time of day as `HH:mm`.
@immutable
class ClockHm implements Comparable<ClockHm> {
  const ClockHm(this.hour, this.minute) : assert(hour >= 0 && hour < 24 && minute >= 0 && minute < 60);

  /// From minutes since midnight (wrapped into one day).
  factory ClockHm.fromMinutes(int minutes) {
    final m = ((minutes % 1440) + 1440) % 1440;
    return ClockHm(m ~/ 60, m % 60);
  }

  final int hour;
  final int minute;

  int get minutes => hour * 60 + minute;

  /// Parses `H:mm` / `HH:mm` (Western digits); null when malformed.
  static ClockHm? tryParse(Object? raw) {
    if (raw is! String) return null;
    final m = RegExp(r'^\s*(\d{1,2})\s*:\s*(\d{1,2})\s*$').firstMatch(raw);
    if (m == null) return null;
    final h = int.parse(m[1]!), mi = int.parse(m[2]!);
    if (h > 23 || mi > 59) return null;
    return ClockHm(h, mi);
  }

  String get hhmm => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  int compareTo(ClockHm other) => minutes.compareTo(other.minutes);

  @override
  bool operator ==(Object other) => other is ClockHm && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => hhmm;
}

/// The user's meals (plus bedtime) – what "taken with" slots and food rules
/// resolve to.
enum MealSlot { breakfast, lunch, dinner, bedtime }

/// What a dose time can follow instead of a fixed clock time: one of the
/// day's prayer moments or one of the user's meals.
enum AnchorBase { fajr, sunrise, dhuhr, asr, maghrib, isha, breakfast, lunch, dinner, bedtime }

extension AnchorBaseX on AnchorBase {
  bool get isPrayer => index <= AnchorBase.isha.index;
  bool get isMeal => !isPrayer;

  MealSlot? get meal => switch (this) {
    AnchorBase.breakfast => MealSlot.breakfast,
    AnchorBase.lunch => MealSlot.lunch,
    AnchorBase.dinner => MealSlot.dinner,
    AnchorBase.bedtime => MealSlot.bedtime,
    _ => null,
  };

  static AnchorBase ofMeal(MealSlot m) => switch (m) {
    MealSlot.breakfast => AnchorBase.breakfast,
    MealSlot.lunch => AnchorBase.lunch,
    MealSlot.dinner => AnchorBase.dinner,
    MealSlot.bedtime => AnchorBase.bedtime,
  };
}

/// "20 minutes after Fajr", "with breakfast", "30 minutes before dinner".
/// Resolved every day against that day's prayer times and the user's meal
/// times, so a dose "after Fajr" follows Fajr through the seasons.
@immutable
class TimeAnchor {
  const TimeAnchor(this.base, [this.offsetMinutes = 0]);

  final AnchorBase base;

  /// Signed: negative = before, positive = after.
  final int offsetMinutes;

  /// `prayer:fajr:+20`, `meal:dinner:-30`.
  String encode() {
    final sign = offsetMinutes < 0 ? '-' : '+';
    return '${base.isPrayer ? 'prayer' : 'meal'}:${base.name}:$sign${offsetMinutes.abs()}';
  }

  static TimeAnchor? decode(Object? raw) {
    if (raw is! String) return null;
    final m = RegExp(r'^(prayer|meal):([a-z]+):([+-]?\d+)$').firstMatch(raw.trim());
    if (m == null) return null;
    final base = AnchorBase.values.where((b) => b.name == m[2]).firstOrNull;
    if (base == null) return null;
    final offset = int.parse(m[3]!);
    if (offset.abs() > 12 * 60) return null;
    return TimeAnchor(base, offset);
  }

  @override
  bool operator ==(Object other) =>
      other is TimeAnchor && other.base == base && other.offsetMinutes == offsetMinutes;

  @override
  int get hashCode => Object.hash(base, offsetMinutes);

  @override
  String toString() => encode();
}

/// One daily time of a medication.
///
/// [key] is the `HH:mm` stored in `Medications.times`: the dose's identity
/// (`MedDoses.scheduledAt` = that day at [key]) and the fixed time when there
/// is no [anchor]. For an anchored time it is the anchor's resolution on the
/// day it was saved, kept stable so the dose log (and the orbit's Health
/// score, which reads `times`) keep matching while Fajr drifts.
@immutable
class MedSlot {
  const MedSlot(this.key, [this.anchor]);

  final ClockHm key;
  final TimeAnchor? anchor;

  @override
  bool operator ==(Object other) => other is MedSlot && other.key == key && other.anchor == anchor;

  @override
  int get hashCode => Object.hash(key, anchor);

  @override
  String toString() => anchor == null ? key.hhmm : '${key.hhmm}~$anchor';
}

/// A titration step: from [from] on, the dose is [dose] ([stop]: no doses
/// from that day – the end of a taper).
@immutable
class TitrationStep {
  const TitrationStep({required this.from, this.dose, this.doseAmount, this.stop = false});

  final DateTime from;
  final String? dose;
  final double? doseAmount;
  final bool stop;

  /// `{"from":"2026-10-01","dose":"5 mg","doseAmount":5}` (+ `"stop":true`).
  Map<String, Object?> toJson() => {
    'from': MedDays.key(from),
    if (dose != null) 'dose': dose,
    if (doseAmount != null) 'doseAmount': doseAmount,
    if (stop) 'stop': true,
  };

  static TitrationStep? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final from = MedDays.parse(raw['from'] ?? raw['date']);
    if (from == null) return null;
    final dose = raw['dose'];
    final amount = raw['doseAmount'] ?? raw['amount'];
    return TitrationStep(
      from: from,
      dose: dose is String && dose.trim().isNotEmpty ? dose.trim() : (dose is num ? '$dose' : null),
      doseAmount: amount is num ? amount.toDouble() : null,
      stop: raw['stop'] == true,
    );
  }

  /// Parses a stored list, dropping malformed entries, sorted by date (the
  /// later of two steps on one day wins).
  static List<TitrationStep> parseList(List<Object?> raw) {
    final steps = [for (final r in raw) ?fromJson(r)];
    steps.sort((a, b) => a.from.compareTo(b.from));
    final byDay = <String, TitrationStep>{};
    for (final s in steps) {
      byDay[MedDays.key(s.from)] = s;
    }
    return byDay.values.toList();
  }

  @override
  bool operator ==(Object other) =>
      other is TitrationStep &&
      MedDays.same(other.from, from) &&
      other.dose == dose &&
      other.doseAmount == doseAmount &&
      other.stop == stop;

  @override
  int get hashCode => Object.hash(MedDays.key(from), dose, doseAmount, stop);
}

/// A medication or supplement as the scheduler sees it.
@immutable
class MedSpec {
  const MedSpec({
    required this.id,
    required this.name,
    this.kind = MedKind.medication,
    this.dose,
    this.doseAmount,
    this.doseUnit,
    this.slots = const [],
    this.takenWith = TakenWith.anytime,
    this.takenWithNote,
    this.notes,
    this.active = true,
    this.stock,
    this.refillAt,
    this.courseId,
    this.titration = const [],
    this.color,
    this.createdAt,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final MedKind kind;
  final String? dose;
  final double? doseAmount;
  final String? doseUnit;
  final List<MedSlot> slots;
  final TakenWith takenWith;
  final String? takenWithNote;
  final String? notes;
  final bool active;
  final int? stock;
  final int? refillAt;
  final String? courseId;
  final List<TitrationStep> titration;
  final int? color;
  final DateTime? createdAt;
  final int sortOrder;

  /// No daily times and no meal slot: taken as needed (logged by hand).
  bool get asNeeded => slots.isEmpty && implicitMeal == null;

  /// The meal a time-less medication follows through its "taken with" slot.
  MealSlot? get implicitMeal => slots.isNotEmpty
      ? null
      : switch (takenWith) {
          TakenWith.emptyStomach || TakenWith.breakfast => MealSlot.breakfast,
          TakenWith.lunch => MealSlot.lunch,
          TakenWith.dinner => MealSlot.dinner,
          TakenWith.bedtime => MealSlot.bedtime,
          _ => null,
        };

  bool get needsRefill => stock != null && refillAt != null && stock! <= refillAt!;

  MedSpec copyWith({
    String? name,
    List<MedSlot>? slots,
    bool? active,
    int? stock,
    TakenWith? takenWith,
    List<TitrationStep>? titration,
    String? dose,
  }) => MedSpec(
    id: id,
    name: name ?? this.name,
    kind: kind,
    dose: dose ?? this.dose,
    doseAmount: doseAmount,
    doseUnit: doseUnit,
    slots: slots ?? this.slots,
    takenWith: takenWith ?? this.takenWith,
    takenWithNote: takenWithNote,
    notes: notes,
    active: active ?? this.active,
    stock: stock ?? this.stock,
    refillAt: refillAt,
    courseId: courseId,
    titration: titration ?? this.titration,
    color: color,
    createdAt: createdAt,
    sortOrder: sortOrder,
  );

  @override
  String toString() => 'MedSpec($id $name $slots)';
}

/// One phase of a course: [count] doses ([count] null = open-ended), one
/// every [interval] days / weeks / months.
@immutable
class CoursePhase {
  const CoursePhase({
    required this.frequency,
    this.interval = 1,
    this.count,
    this.dose,
    this.doseAmount,
    this.label,
  });

  final CourseFrequency frequency;
  final int interval;
  final int? count;
  final String? dose;
  final double? doseAmount;
  final String? label;

  bool get openEnded => count == null;

  Map<String, Object?> toJson() => {
    if (label != null) 'label': label,
    'frequency': frequency.name,
    'interval': interval,
    if (count != null) 'count': count,
    if (dose != null) 'dose': dose,
    if (doseAmount != null) 'doseAmount': doseAmount,
  };

  static CoursePhase? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final f = CourseFrequency.values.where((f) => f.name == raw['frequency']).firstOrNull;
    if (f == null) return null;
    final interval = raw['interval'];
    final count = raw['count'];
    final dose = raw['dose'];
    final amount = raw['doseAmount'];
    final label = raw['label'];
    return CoursePhase(
      frequency: f,
      interval: interval is num && interval >= 1 ? interval.toInt() : 1,
      count: count is num && count >= 1 ? count.toInt() : null,
      dose: dose is String && dose.trim().isNotEmpty ? dose.trim() : null,
      doseAmount: amount is num ? amount.toDouble() : null,
      label: label is String && label.trim().isNotEmpty ? label.trim() : null,
    );
  }

  /// Parses a stored list. Only the last phase may be open-ended: an earlier
  /// phase without a count gets one dose, so later phases stay reachable.
  static List<CoursePhase> parseList(List<Object?> raw) {
    final phases = [for (final r in raw) ?fromJson(r)];
    return [
      for (var i = 0; i < phases.length; i++)
        if (i < phases.length - 1 && phases[i].openEnded)
          CoursePhase(
            frequency: phases[i].frequency,
            interval: phases[i].interval,
            count: 1,
            dose: phases[i].dose,
            doseAmount: phases[i].doseAmount,
            label: phases[i].label,
          )
        else
          phases[i],
    ];
  }

  @override
  bool operator ==(Object other) =>
      other is CoursePhase &&
      other.frequency == frequency &&
      other.interval == interval &&
      other.count == count &&
      other.dose == dose &&
      other.doseAmount == doseAmount &&
      other.label == label;

  @override
  int get hashCode => Object.hash(frequency, interval, count, dose, doseAmount, label);
}

/// An injection / treatment course: [phases] expanded from [startDate]
/// into dose days for [medicationId].
@immutable
class CourseSpec {
  const CourseSpec({
    required this.id,
    required this.name,
    required this.startDate,
    this.medicationId,
    this.phases = const [],
    this.notes,
    this.active = true,
  });

  final String id;
  final String name;
  final String? medicationId;
  final DateTime startDate;
  final List<CoursePhase> phases;
  final String? notes;
  final bool active;
}

/// A timing rule the scheduler enforces.
@immutable
class RuleSpec {
  const RuleSpec({required this.id, required this.kind, required this.medAId, this.medBId, this.minutes = 0, this.note});

  final String id;
  final MedRuleKind kind;
  final String medAId;
  final String? medBId;
  final int minutes;
  final String? note;

  bool get isFood => kind == MedRuleKind.beforeFood || kind == MedRuleKind.afterFood || kind == MedRuleKind.withFood;

  bool get isSeparation => kind == MedRuleKind.separate && medBId != null && medBId != medAId;

  bool involves(String medId) => medAId == medId || medBId == medId;
}

/// A dose-log entry (`MedDoses`).
///
/// * [slot] (`scheduledAt`): the scheduled dose it answers – that day at one
///   of the medication's `times` (its identity, not the shifted plan time);
///   null for a dose logged by hand outside the plan.
/// * [at] (`takenAt`): when it was taken – or, for [DoseStatus.snoozed], the
///   moment it was snoozed until.
@immutable
class DoseLog {
  const DoseLog({required this.id, required this.medId, required this.status, this.slot, this.at, this.dose, this.note});

  final String id;
  final String medId;
  final DateTime? slot;
  final DateTime? at;
  final DoseStatus status;
  final String? dose;
  final String? note;

  DateTime? get snoozedUntil => status == DoseStatus.snoozed ? at : null;
  DateTime? get takenAt => status == DoseStatus.taken ? at : null;

  @override
  String toString() => 'DoseLog($medId ${status.name} slot=$slot at=$at)';
}
