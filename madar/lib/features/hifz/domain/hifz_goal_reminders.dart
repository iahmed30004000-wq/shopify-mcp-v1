/// «تذكير الأهداف على وقت الصلاة» · the goals' reminders (Part 14).
///
/// Pure Dart. The owner's rule: a reminder hangs off **a prayer**, not off
/// a clock. «الكهف كل جمعة» rings after Fajr on Friday wherever he is and
/// whatever the season does to the sunrise; nothing here ever stores an
/// hour and a minute.
///
/// It is the same shape as the daily wird's planner
/// (`lib/features/wird/domain/wird_reminders.dart`) on purpose – the two
/// are planned by different syncs over **different id blocks**, so neither
/// can ever cancel the other's alarms: the wird owns 140000–140999 and the
/// goals own [NotificationNamespaces.hifz], 190000–190999.
library;

import 'package:meta/meta.dart';

import '../../../core/domain/enums.dart';
import '../../../core/notifications/notification_models.dart' show NotificationNamespace, NotificationNamespaces;
import '../../orbit/domain/prayer_schedule.dart' show DayTimes;
import '../../wird/domain/calendar_days.dart';
import 'hifz_goals.dart';

/// Notification ids of «الحفظ»'s goal reminders.
abstract final class HifzGoalReminderIds {
  static const NotificationNamespace namespace = NotificationNamespaces.hifz;

  /// Goals reminded per day (more than this are not reminded).
  static const int slotsPerDay = 20;

  /// Days an id stays unique for (the planner looks a week ahead).
  static const int cycleDays = 50;

  /// A stable id per calendar day and slot, so re-planning an unchanged
  /// reminder keeps its id and the notification service leaves it alone.
  static int idFor(DateTime day, int slot) {
    final epochDay = DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
    return namespace.id((epochDay % cycleDays) * slotsPerDay + slot);
  }
}

/// One planned reminder.
@immutable
final class HifzGoalReminder {
  const HifzGoalReminder({
    required this.goalId,
    required this.title,
    required this.day,
    required this.at,
    required this.window,
    required this.slot,
    this.today = false,
  });

  final String goalId;

  /// The goal's own title, as he wrote it.
  final String title;
  final DateTime day;

  /// The instant it fires: the prayer of [window] plus the goal's offset.
  final DateTime at;
  final PrayerWindow window;
  final int slot;

  /// It is today's reminder (its text may name today's portion).
  final bool today;

  int get notificationId => HifzGoalReminderIds.idFor(day, slot);

  @override
  bool operator ==(Object other) =>
      other is HifzGoalReminder &&
      other.goalId == goalId &&
      other.title == title &&
      other.day == day &&
      other.at == at &&
      other.window == window &&
      other.slot == slot &&
      other.today == today;

  @override
  int get hashCode => Object.hash(goalId, title, day, at, window, slot, today);

  @override
  String toString() => 'HifzGoalReminder($title @ $at #$notificationId)';
}

/// A reminder with its texts, ready for the notification layer.
@immutable
final class HifzGoalNotice {
  const HifzGoalNotice({required this.reminder, required this.title, required this.body});

  final HifzGoalReminder reminder;
  final String title;
  final String body;

  int get id => reminder.notificationId;
  DateTime get at => reminder.at;

  /// Handed back when the reminder is tapped (see [HifzGoalTaps]).
  Map<String, Object?> get data => {'goal': reminder.goalId};

  @override
  bool operator ==(Object other) =>
      other is HifzGoalNotice && other.reminder == reminder && other.title == title && other.body == body;

  @override
  int get hashCode => Object.hash(reminder, title, body);
}

/// Plans the goals' reminders off the prayer times.
abstract final class HifzGoalReminderPlanner {
  /// Which prayer of the day a window hangs off (Duha hangs off sunrise).
  static DateTime anchorOf(PrayerWindow window, DayTimes t) => switch (window) {
    PrayerWindow.fajr => t.fajr,
    PrayerWindow.duha => t.sunrise,
    PrayerWindow.dhuhr => t.dhuhr,
    PrayerWindow.asr => t.asr,
    PrayerWindow.maghrib => t.maghrib,
    PrayerWindow.isha || PrayerWindow.anytime => t.isha,
  };

  /// One reminder per goal per day for the next [days] days.
  ///
  /// Skipped: a goal that is off or wants no reminder, a goal with no
  /// prayer chosen, a day the goal does not apply to (Friday only, for
  /// «الكهف كل جمعة»), today's reminder once today's goal is met, and any
  /// time that has already passed.
  static List<HifzGoalReminder> plan({
    required List<HifzGoalProgress> goals,
    required DayTimes Function(DateTime day) timesFor,
    required DateTime now,
    int days = 7,
  }) {
    final eligible = [for (final g in goals) if (g.goal.canRemind) g]
      ..sort((a, b) {
        final o = a.goal.sortOrder.compareTo(b.goal.sortOrder);
        return o != 0 ? o : a.goal.id.compareTo(b.goal.id);
      });
    final out = <HifzGoalReminder>[];
    final today = CalendarDays.dateOnly(now);
    for (var d = 0; d < days; d++) {
      final day = CalendarDays.add(today, d);
      final times = timesFor(day);
      for (var slot = 0; slot < eligible.length && slot < HifzGoalReminderIds.slotsPerDay; slot++) {
        final progress = eligible[slot];
        final goal = progress.goal;
        if (!goal.appliesOn(day)) continue;
        if (d == 0 && progress.met) continue;
        final at = anchorOf(goal.window!, times).add(Duration(minutes: goal.offsetMinutes));
        if (!at.isAfter(now)) continue;
        out.add(
          HifzGoalReminder(
            goalId: goal.id,
            title: goal.title,
            day: day,
            at: at,
            window: goal.window!,
            slot: slot,
            today: d == 0,
          ),
        );
      }
    }
    out.sort((a, b) {
      final t = a.at.compareTo(b.at);
      return t != 0 ? t : a.slot.compareTo(b.slot);
    });
    return out;
  }
}

/// Delivers the goals' reminders (the notification service in the app, a
/// fake in tests, [NoopHifzGoalScheduler] when they are off).
abstract interface class HifzGoalScheduler {
  /// Replaces every scheduled goal reminder with [notices].
  Future<void> replaceAll(List<HifzGoalNotice> notices);

  Future<void> cancelAll();

  /// Asks for the notification permission when needed; true when reminders
  /// can be shown.
  Future<bool> ensurePermission();
}

class NoopHifzGoalScheduler implements HifzGoalScheduler {
  const NoopHifzGoalScheduler();

  @override
  Future<void> replaceAll(List<HifzGoalNotice> notices) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<bool> ensurePermission() async => true;
}
