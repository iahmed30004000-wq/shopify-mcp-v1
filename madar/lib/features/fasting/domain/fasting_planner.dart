/// Turns the rules into concrete notification times and ids.
///
/// The owner's rule: the reminder comes **the night before, after Isha**,
/// taken from the prayer schedule, not a fixed clock time. The caller hands
/// in `ishaOf` (the prayer schedule's Isha of a civil day); nothing here
/// stores a schedule, so a re-plan from scratch (offset changed, zone
/// changed, app restored) gives the same answer for the same inputs.
library;

import 'package:meta/meta.dart';

import '../../../core/notifications/notification_models.dart' show NotificationNamespace;
import '../../wird/domain/calendar_days.dart';
import 'fasting_log.dart';
import 'fasting_models.dart';
import 'fasting_rules.dart';

/// Notification ids of «تذكير الصيام».
///
/// PROPOSED block 200000-200999 (the last block in use is hifz, 190000). The
/// integrator adds it to `NotificationNamespaces` as `fasting` and to `all`.
///
/// An id is a pure function of the fasting day and kind, so re-planning an
/// unchanged reminder keeps its id. The block is split into regions that can
/// never overlap, each cycling over a span longer than five Hijri years
/// (1771 days), so no two reminders inside any five-year window share an id:
///
/// * 0-259    Mondays: the week number mod 260 (260 weeks = 5 years)
/// * 260-519  Thursdays: the same
/// * 520-735  white days: (Hijri month count mod 72) * 3 + (day - 13)
/// * 736-987  the yearly kinds: (Hijri year mod 6) * 42 + the kind's slot
abstract final class FastingNotificationIds {
  static const NotificationNamespace namespace = NotificationNamespace('fasting', 200000, 200999);

  static const int _weekCycle = 260;
  static const int _mondayBase = 0;
  static const int _thursdayBase = 260;
  static const int _whiteBase = 520;
  static const int _whiteMonthCycle = 72;
  static const int _yearlyBase = 736;
  static const int _yearCycle = 6;

  // Slots inside one year's 42: arafah 0, tasua 1, ashura 2, muharram nudge 3,
  // sha'ban nudge 4, the ten (days 1-9) 5-13, the six of Shawwal (days 2-29) 14-41.
  static const int _slotsPerYear = 42;

  /// The notification id of the reminder [r] (its winning kind).
  static int idFor(FastReminder r) => namespace.id(_offsetFor(r));

  static int _offsetFor(FastReminder r) {
    final h = r.hijri;
    final epochDay = DateTime.utc(r.day.year, r.day.month, r.day.day).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
    final year = h.year % _yearCycle;
    int yearly(int slot) => _yearlyBase + year * _slotsPerYear + slot;
    switch (r.kind) {
      case FastKind.monday:
        return _mondayBase + (epochDay ~/ 7) % _weekCycle;
      case FastKind.thursday:
        return _thursdayBase + (epochDay ~/ 7) % _weekCycle;
      case FastKind.whiteDay:
        final months = (h.year * 12 + h.month - 1) % _whiteMonthCycle;
        return _whiteBase + months * 3 + (h.day - 13).clamp(0, 2);
      case FastKind.arafah:
        return yearly(0);
      case FastKind.tasua:
        return yearly(1);
      case FastKind.ashura:
        return yearly(2);
      case FastKind.muharramMore:
        return yearly(3);
      case FastKind.shabanMore:
        return yearly(4);
      case FastKind.dhuHijjahTen:
        return yearly(5 + (h.day - 1).clamp(0, 8));
      case FastKind.sixShawwal:
        return yearly(14 + (h.day - 2).clamp(0, 27));
    }
  }
}

/// A reminder placed on the clock.
@immutable
final class PlannedFastReminder {
  const PlannedFastReminder({required this.reminder, required this.at, required this.usedFallback});

  final FastReminder reminder;

  /// When it fires: Isha of the evening before, plus the planner's minutes.
  final DateTime at;

  /// Isha was unknown for that evening, so [FastingPlanner.fallbackHour] was used.
  final bool usedFallback;

  int get notificationId => FastingNotificationIds.idFor(reminder);

  /// Handed back when an action is tapped («ناوي» / «لأ»): the fasting day.
  Map<String, Object?> get data => {'day': CalendarDays.key(reminder.day), 'kind': reminder.kind.id};

  @override
  bool operator ==(Object other) =>
      other is PlannedFastReminder && other.reminder == reminder && other.at == at && other.usedFallback == usedFallback;

  @override
  int get hashCode => Object.hash(reminder, at, usedFallback);

  @override
  String toString() => 'PlannedFastReminder(${reminder.key} @ $at)';
}

abstract final class FastingPlanner {
  /// Minutes after Isha. Like the adhkar reminders it is never 0: a ping at
  /// the Isha adhan would sound over the call to prayer. (My pick; the owner
  /// only said "after Isha".)
  static const int defaultAfterIshaMinutes = 20;

  /// When Isha cannot be computed for an evening (it never occurs at some
  /// high latitudes and the schedule had no fallback), the reminder is NOT
  /// skipped - a skipped night would silently break "set once, never touch
  /// again" - but placed at 21:00 local time of that evening, which is after
  /// Isha everywhere the prayer exists. No Isha offset is added to it.
  static const int fallbackHour = 21;

  /// The placed reminders for the fasting days from today to [daysAhead]
  /// days ahead whose reminder time is still after [now], in time order.
  ///
  /// * [ishaOf]: the prayer schedule's Isha of a civil day (null = unknown).
  /// * [intentions]: a day with any recorded answer («ناوي» or «لأ») is not
  ///   reminded again. «لأ» silences only that day.
  static List<PlannedFastReminder> plan({
    required FastingConfig config,
    required DateTime now,
    required DateTime? Function(DateTime day) ishaOf,
    Iterable<FastIntention> intentions = const [],
    int daysAhead = 21,
    int afterIshaMinutes = defaultAfterIshaMinutes,
  }) {
    final answered = {for (final i in intentions) CalendarDays.key(i.day)};
    final today = CalendarDays.dateOnly(now);
    final out = <PlannedFastReminder>[];
    for (final r in FastingRules.remindersBetween(today, CalendarDays.add(today, daysAhead), config)) {
      if (answered.contains(CalendarDays.key(r.day))) continue;
      final placed = placeAtIsha(r, ishaOf: ishaOf, afterIshaMinutes: afterIshaMinutes);
      if (placed.at.isAfter(now)) out.add(placed);
    }
    out.sort((a, b) {
      final t = a.at.compareTo(b.at);
      return t != 0 ? t : a.notificationId.compareTo(b.notificationId);
    });
    return out;
  }

  /// Places one reminder: Isha of the evening before plus [afterIshaMinutes],
  /// or the documented fallback when Isha is unknown.
  static PlannedFastReminder placeAtIsha(
    FastReminder r, {
    required DateTime? Function(DateTime day) ishaOf,
    int afterIshaMinutes = defaultAfterIshaMinutes,
  }) {
    final evening = r.eveningOf;
    final isha = ishaOf(evening);
    if (isha == null) {
      return PlannedFastReminder(
        reminder: r,
        at: DateTime(evening.year, evening.month, evening.day, fallbackHour),
        usedFallback: true,
      );
    }
    return PlannedFastReminder(
      reminder: r,
      at: isha.add(Duration(minutes: afterIshaMinutes < 0 ? 0 : afterIshaMinutes)),
      usedFallback: false,
    );
  }
}
