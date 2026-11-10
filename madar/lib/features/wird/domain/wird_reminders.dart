import 'package:flutter/foundation.dart';

import '../../../core/domain/enums.dart';
import '../../../core/notifications/notification_models.dart' show NotificationNamespace, NotificationNamespaces;
import '../../orbit/domain/prayer_schedule.dart' show DayTimes;
import 'calendar_days.dart';
import 'wird_engine.dart';

/// Notification ids of the wird reminders.
///
/// Madar's shared [NotificationNamespace] list has no block for the wird
/// yet, so it owns 140000–140999 here (clear of adhan, adhkar, meds and
/// reminders); register [namespace] in `NotificationNamespaces` when
/// integrating.
abstract final class WirdReminderIds {
  static const NotificationNamespace namespace = NotificationNamespaces.wird;

  /// Plans with reminders per day (more are not reminded).
  static const int slotsPerDay = 20;

  /// Days an id stays unique for (the planner looks a week ahead).
  static const int cycleDays = 50;

  /// A stable id per calendar day and plan slot, so re-planning an unchanged
  /// reminder keeps its id (the notification service leaves it alone).
  static int idFor(DateTime day, int slot) {
    final epochDay = DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
    return namespace.id((epochDay % cycleDays) * slotsPerDay + slot);
  }
}

/// One planned wird reminder.
@immutable
class WirdReminder {
  const WirdReminder({
    required this.planId,
    required this.planName,
    required this.day,
    required this.at,
    required this.window,
    required this.slot,
    this.today = false,
  });

  final String planId;
  final String planName;
  final DateTime day;
  final DateTime at;
  final PrayerWindow window;
  final int slot;

  /// It is today's reminder (its text can name today's portion).
  final bool today;

  int get notificationId => WirdReminderIds.idFor(day, slot);

  @override
  bool operator ==(Object other) =>
      other is WirdReminder &&
      other.planId == planId &&
      other.planName == planName &&
      other.day == day &&
      other.at == at &&
      other.window == window &&
      other.slot == slot &&
      other.today == today;

  @override
  int get hashCode => Object.hash(planId, planName, day, at, window, slot, today);

  @override
  String toString() => 'WirdReminder($planName @ $at #$notificationId)';
}

/// A reminder with its texts, ready for the notification layer.
@immutable
class WirdReminderNotice {
  const WirdReminderNotice({required this.reminder, required this.title, required this.body});

  final WirdReminder reminder;
  final String title;
  final String body;

  int get id => reminder.notificationId;
  DateTime get at => reminder.at;

  /// Handed back when the reminder is tapped (see `WirdReminderTaps`).
  Map<String, Object?> get data => {'plan': reminder.planId};

  @override
  bool operator ==(Object other) =>
      other is WirdReminderNotice && other.reminder == reminder && other.title == title && other.body == body;

  @override
  int get hashCode => Object.hash(reminder, title, body);
}

/// Plans wird reminders from the prayer times (pure): for every active plan
/// with a prayer window and reminders on, a reminder [WirdPlanMeta.remindOffsetMin]
/// minutes after that window's prayer (sunrise for Duha), each day of the
/// next week – skipping today once today's portion is read, days before the
/// plan starts, and finished khatmas.
abstract final class WirdReminderPlanner {
  static DateTime anchorOf(PrayerWindow window, DayTimes t) => switch (window) {
    PrayerWindow.fajr => t.fajr,
    PrayerWindow.duha => t.sunrise,
    PrayerWindow.dhuhr => t.dhuhr,
    PrayerWindow.asr => t.asr,
    PrayerWindow.maghrib => t.maghrib,
    PrayerWindow.isha || PrayerWindow.anytime => t.isha,
  };

  static List<WirdReminder> plan({
    required List<WirdPlanState> states,
    required DayTimes Function(DateTime day) timesFor,
    required DateTime now,
    int days = 7,
  }) {
    final eligible =
        states.where((s) {
          final p = s.plan;
          return p.active && p.meta.remind && p.window != null && p.window != PrayerWindow.anytime && !s.completed;
        }).toList()..sort((a, b) {
          final o = a.plan.sortOrder.compareTo(b.plan.sortOrder);
          return o != 0 ? o : a.plan.id.compareTo(b.plan.id);
        });
    final out = <WirdReminder>[];
    final today = CalendarDays.dateOnly(now);
    for (var d = 0; d < days; d++) {
      final day = CalendarDays.add(today, d);
      final times = timesFor(day);
      for (var slot = 0; slot < eligible.length && slot < WirdReminderIds.slotsPerDay; slot++) {
        final s = eligible[slot];
        final p = s.plan;
        if (CalendarDays.between(p.startDate, day) < 0) continue;
        if (p.meta.pausedOn(day)) continue;
        if (d == 0 && (s.target.met || s.paused)) continue;
        final at = anchorOf(p.window!, times).add(Duration(minutes: p.meta.remindOffsetMin));
        if (!at.isAfter(now)) continue;
        out.add(
          WirdReminder(planId: p.id, planName: p.name, day: day, at: at, window: p.window!, slot: slot, today: d == 0),
        );
      }
    }
    out.sort((a, b) => a.at.compareTo(b.at));
    return out;
  }
}

/// Delivers wird reminders (the notification service in the app; a fake in
/// tests; [NoopWirdReminderScheduler] schedules nothing).
abstract interface class WirdReminderScheduler {
  /// Replaces every scheduled wird reminder with [notices].
  Future<void> replaceAll(List<WirdReminderNotice> notices);

  Future<void> cancelAll();

  /// Asks for the notification permission when needed; true when reminders
  /// can be shown.
  Future<bool> ensurePermission();
}

class NoopWirdReminderScheduler implements WirdReminderScheduler {
  const NoopWirdReminderScheduler();

  @override
  Future<void> replaceAll(List<WirdReminderNotice> notices) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<bool> ensurePermission() async => true;
}
