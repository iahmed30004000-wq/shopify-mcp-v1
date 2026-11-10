import 'package:flutter/foundation.dart';

import 'last_ten_nights.dart';
import 'prayer_times_of.dart';
import 'ramadan_calendar.dart';
import 'ramadan_config.dart';
import 'ramadan_notification_ids.dart';

/// One reminder of the plan.
@immutable
class PlannedRamadanReminder {
  const PlannedRamadanReminder({
    required this.kind,
    required this.number,
    required this.hijriYear,
    required this.date,
    required this.at,
    required this.eventAt,
  });

  final RamadanReminderKind kind;

  /// The day (suhoor, iftar) or the night (Taraweeh, last ten), 1…30.
  final int number;
  final int hijriYear;

  /// The civil day the event falls on (for a night: the evening it begins).
  final DateTime date;

  /// When it rings (an instant).
  final DateTime at;

  /// The moment it is about - Fajr, Maghrib or Isha - so the text can name it.
  final DateTime eventAt;

  int get notificationId => RamadanNotificationIds.forDay(kind, number);

  /// Whole minutes between the ring and the event (negative: after it).
  int get minutesBefore => eventAt.difference(at).inMinutes;

  @override
  bool operator ==(Object other) =>
      other is PlannedRamadanReminder &&
      other.kind == kind &&
      other.number == number &&
      other.hijriYear == hijriYear &&
      other.at == at &&
      other.eventAt == eventAt;

  @override
  int get hashCode => Object.hash(kind, number, hijriYear, at, eventAt);

  @override
  String toString() => 'PlannedRamadanReminder(${kind.name} $number at $at)';
}

/// What one planning run decided.
@immutable
class RamadanPlan {
  const RamadanPlan({required this.span, required this.reminders, this.runwayAt});

  /// The Ramadan planned for (the current one, or the next).
  final RamadanSpan span;

  /// Every reminder still to come, in order.
  final List<PlannedRamadanReminder> reminders;

  /// When to ask him to open Madar, set only while Ramadan is too far off to
  /// plan yet (null once the alarms themselves are armed).
  final DateTime? runwayAt;

  Set<int> get ids => {for (final r in reminders) r.notificationId};
}

/// Plans Ramadan's reminders from the calendar and the prayer times.
///
/// * suhoor: [RamadanConfig.suhoorLeadMinutes] before Fajr of each day;
/// * iftar: [RamadanConfig.iftarLeadMinutes] before Maghrib of each day;
/// * Taraweeh: [taraweehAfterIsha] after Isha of each night;
/// * the last ten nights: one more, [lastTenAfterIsha] after Isha.
///
/// Only the days of the current (or next) Ramadan, only moments after [now],
/// and only once Ramadan is within [planAheadDays] - before that a single
/// "open Madar" notice stands in. Every id is `RamadanNotificationIds.forDay`,
/// so planning twice gives the same ids.
abstract final class RamadanPlanner {
  static const int planAheadDays = 45;

  /// Where the notice that asks him to open Madar falls: this many days
  /// before the first of Ramadan, at 10:00.
  static const int runwayDaysBefore = 40;

  static const Duration taraweehAfterIsha = Duration(minutes: 30);
  static const Duration lastTenAfterIsha = Duration(minutes: 60);

  static RamadanPlan plan({
    required RamadanConfig config,
    required RamadanCalendar calendar,
    required DateTime now,
    required PrayerTimesOf timesOf,
  }) {
    final today = civilDay(now);
    final span = calendar.spanContaining(today) ?? calendar.nextSpanOnOrAfter(today);
    final untilStart = civilDaysBetween(today, span.first);
    if (untilStart > planAheadDays) {
      final d = addCivilDays(span.first, -runwayDaysBefore);
      return RamadanPlan(span: span, reminders: const [], runwayAt: DateTime(d.year, d.month, d.day, 10));
    }

    final out = <PlannedRamadanReminder>[];
    void add(RamadanReminderKind kind, int number, DateTime date, DateTime event, Duration lead) {
      final at = event.subtract(lead);
      if (!at.isAfter(now)) return;
      out.add(
        PlannedRamadanReminder(kind: kind, number: number, hijriYear: span.hijriYear, date: date, at: at, eventAt: event),
      );
    }

    for (var n = 1; n <= span.length; n++) {
      final day = span.dateOfDay(n);
      final t = timesOf(day);
      if (config.suhoorReminder) {
        add(RamadanReminderKind.suhoor, n, day, t.fajr, Duration(minutes: config.effectiveSuhoorLead));
      }
      if (config.iftarReminder) {
        add(RamadanReminderKind.iftar, n, day, t.maghrib, Duration(minutes: config.effectiveIftarLead));
      }
      final evening = span.eveningOfNight(n);
      final isha = timesOf(evening).isha;
      if (config.taraweehReminder) add(RamadanReminderKind.taraweeh, n, evening, isha, -taraweehAfterIsha);
      if (config.lastTenReminder && n >= LastTenNights.first) add(RamadanReminderKind.lastTenNight, n, evening, isha, -lastTenAfterIsha);
    }
    out.sort((a, b) {
      final c = a.at.compareTo(b.at);
      return c != 0 ? c : a.notificationId.compareTo(b.notificationId);
    });
    return RamadanPlan(span: span, reminders: List.unmodifiable(out));
  }
}
