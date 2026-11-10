/// The pure rules: which voluntary fast, if any, falls on a given day.
///
/// Every rule is expressed on the **Hijri date of the fasting day**, computed
/// once through [HijriCalendarMath] with the owner's offset, so shifting the
/// date by a day moves the white days, Arafah, Ashura, the ten, Tashriq and
/// the Eids together. Only Monday / Thursday follow the Gregorian weekday,
/// which an offset of the Hijri label cannot change.
///
/// Nothing is stored: any future day can be asked, so the schedule repeats by
/// itself every Hijri month and year.
library;

import 'package:meta/meta.dart';

import '../../prayer/domain/hijri.dart';
import '../../wird/domain/calendar_days.dart';
import 'fasting_models.dart';

/// One reminder: fast on [day], told the evening before.
@immutable
final class FastReminder {
  const FastReminder({required this.day, required this.hijri, required this.kind, this.alsoKinds = const []});

  /// The fasting day (local midnight).
  final DateTime day;

  /// [day]'s Hijri date under the offset the reminder was planned with.
  final HijriDate hijri;

  /// The day's one reminder: the highest-priority kind (see [FastKind]).
  final FastKind kind;

  /// Other kinds that also fall on [day] (lower priority, in priority
  /// order), e.g. a Monday that is also Ashura: the text may mention them.
  final List<FastKind> alsoKinds;

  /// The evening the reminder belongs to: the evening before [day].
  DateTime get eveningOf => CalendarDays.add(day, -1);

  /// Stable string id, e.g. `2026-11-16.monday`.
  String get key => '${CalendarDays.key(day)}.${kind.id}';

  @override
  bool operator ==(Object other) =>
      other is FastReminder &&
      CalendarDays.same(other.day, day) &&
      other.hijri == hijri &&
      other.kind == kind &&
      other.alsoKinds.length == alsoKinds.length &&
      [for (var i = 0; i < alsoKinds.length; i++) other.alsoKinds[i] == alsoKinds[i]].every((e) => e);

  @override
  int get hashCode => Object.hash(day.year, day.month, day.day, hijri, kind, Object.hashAll(alsoKinds));

  @override
  String toString() => 'FastReminder($key $hijri also=$alsoKinds)';
}

abstract final class FastingRules {
  /// The Hijri date of the civil [day] under [config]'s offset.
  static HijriDate hijriOf(DateTime day, FastingConfig config) =>
      HijriCalendarMath.fromGregorian(CalendarDays.dateOnly(day), offsetDays: config.effectiveOffset);

  /// Whether fasting [h] is forbidden: the two Eids and the days of Tashriq.
  static ForbiddenFastDay? forbiddenDay(HijriDate h) {
    if (h.month == 10 && h.day == 1) return ForbiddenFastDay.eidAlFitr;
    if (h.month == 12) {
      if (h.day == 10) return ForbiddenFastDay.eidAlAdha;
      if (h.day >= 11 && h.day <= 13) return ForbiddenFastDay.tashriq;
    }
    return null;
  }

  /// Every kind that applies to the day with Hijri date [h] and Gregorian
  /// [weekday] (`DateTime.monday` ...), ignoring which kinds are switched
  /// off, in priority order.
  ///
  /// Empty on a forbidden day, and (stated assumption) throughout Ramadan:
  /// the whole month is already fasted, so no voluntary reminder of any kind
  /// is made there.
  static List<FastKind> applicable(
    HijriDate h,
    int weekday, {
    int shawwalStartDay = 2,
    int nudgeDay = 1,
  }) {
    if (h.isRamadan || forbiddenDay(h) != null) return const [];
    final start = shawwalStartDay.clamp(2, 30 - FastingConfig.shawwalDays);
    // 29 at most, so the nudge exists in 29-day months too.
    final nudge = nudgeDay.clamp(1, 29);
    return [
      if (h.month == 12 && h.day == 9) FastKind.arafah,
      if (h.month == 1 && h.day == 10) FastKind.ashura,
      if (h.month == 1 && h.day == 9) FastKind.tasua,
      // 1...9 only: the tenth is the Eid and was returned empty above.
      if (h.month == 12 && h.day >= 1 && h.day <= 9) FastKind.dhuHijjahTen,
      if (h.month == 10 && h.day >= start && h.day < start + FastingConfig.shawwalDays) FastKind.sixShawwal,
      if (h.day >= 13 && h.day <= 15) FastKind.whiteDay,
      if (weekday == DateTime.monday) FastKind.monday,
      if (weekday == DateTime.thursday) FastKind.thursday,
      if (h.month == 1 && h.day == nudge) FastKind.muharramMore,
      if (h.month == 8 && h.day == nudge) FastKind.shabanMore,
    ];
  }

  /// The kinds that apply to the civil [day] under [config], switched-off
  /// kinds removed, in priority order.
  static List<FastKind> kindsOn(DateTime day, FastingConfig config) {
    final d = CalendarDays.dateOnly(day);
    final h = hijriOf(d, config);
    return [
      for (final k in applicable(
        h,
        d.weekday,
        shawwalStartDay: config.shawwalStartDay,
        nudgeDay: config.nudgeDay,
      ))
        if (config.isEnabled(k)) k,
    ];
  }

  /// The one reminder for fasting day [day], or null when it has none.
  static FastReminder? reminderOn(DateTime day, FastingConfig config) {
    final d = CalendarDays.dateOnly(day);
    final h = hijriOf(d, config);
    final kinds = [
      for (final k in applicable(h, d.weekday, shawwalStartDay: config.shawwalStartDay, nudgeDay: config.nudgeDay))
        if (config.isEnabled(k)) k,
    ];
    if (kinds.isEmpty) return null;
    return FastReminder(day: d, hijri: h, kind: kinds.first, alsoKinds: List.unmodifiable(kinds.skip(1)));
  }

  /// The reminders of the fasting days from [from] to [to] inclusive, in day
  /// order, one per day.
  static List<FastReminder> remindersBetween(DateTime from, DateTime to, FastingConfig config) {
    final out = <FastReminder>[];
    final end = CalendarDays.dateOnly(to);
    for (var d = CalendarDays.dateOnly(from); !d.isAfter(end); d = CalendarDays.add(d, 1)) {
      final r = reminderOn(d, config);
      if (r != null) out.add(r);
    }
    return out;
  }
}
