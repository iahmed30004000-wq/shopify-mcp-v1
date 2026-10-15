import 'package:flutter/foundation.dart';

import '../../../core/notifications/notification_models.dart' show NotificationNamespaces;
import '../../orbit/domain/prayer_schedule.dart';
import 'adhkar_models.dart';
import 'adhkar_timing.dart';

/// The user's adhkar reminders: morning adhkar a little after Fajr, evening
/// adhkar a little after Asr. Off on a fresh install.
@immutable
class AdhkarReminderSettings {
  const AdhkarReminderSettings({
    this.morning = false,
    this.evening = false,
    this.morningOffsetMin = 20,
    this.eveningOffsetMin = 20,
  });

  /// Minutes after the adhan the user can pick. Never 0: a reminder at the
  /// adhan itself would chime over the call to prayer, and the adhkar of
  /// the morning / evening come after the prayer anyway.
  static const List<int> offsets = [10, 20, 30, 45, 60];

  /// The allowed offset nearest to [minutes].
  static int snapOffset(int minutes) =>
      offsets.reduce((a, b) => (a - minutes).abs() <= (b - minutes).abs() ? a : b);

  final bool morning;
  final bool evening;

  /// Minutes after Fajr.
  final int morningOffsetMin;

  /// Minutes after Asr.
  final int eveningOffsetMin;

  bool get anyEnabled => morning || evening;

  AdhkarReminderSettings copyWith({bool? morning, bool? evening, int? morningOffsetMin, int? eveningOffsetMin}) =>
      AdhkarReminderSettings(
        morning: morning ?? this.morning,
        evening: evening ?? this.evening,
        morningOffsetMin: morningOffsetMin ?? this.morningOffsetMin,
        eveningOffsetMin: eveningOffsetMin ?? this.eveningOffsetMin,
      );

  Map<String, Object?> toJson() => {
    'morning': morning,
    'evening': evening,
    'morningOffsetMin': morningOffsetMin,
    'eveningOffsetMin': eveningOffsetMin,
  };

  factory AdhkarReminderSettings.fromJson(Object? json) {
    if (json is! Map) return const AdhkarReminderSettings();
    int offset(Object? v, int fallback) => v is num && v >= 0 && v <= 180 ? snapOffset(v.toInt()) : fallback;
    return AdhkarReminderSettings(
      morning: json['morning'] == true,
      evening: json['evening'] == true,
      morningOffsetMin: offset(json['morningOffsetMin'], 20),
      eveningOffsetMin: offset(json['eveningOffsetMin'], 20),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AdhkarReminderSettings &&
      other.morning == morning &&
      other.evening == evening &&
      other.morningOffsetMin == morningOffsetMin &&
      other.eveningOffsetMin == eveningOffsetMin;

  @override
  int get hashCode => Object.hash(morning, evening, morningOffsetMin, eveningOffsetMin);
}

/// One planned reminder.
@immutable
class AdhkarReminder {
  const AdhkarReminder({required this.category, required this.at});

  final AdhkarCategoryId category;
  final DateTime at;

  /// Stable string id (`adhkar.morning.2026-09-28`).
  String get id => 'adhkar.${category.name}.${AdhkarTiming.dayKey(at)}';

  /// Days a reminder id stays unique for (ids repeat after this many days;
  /// the planner only looks a week ahead).
  static const int idCycleDays = 400;

  /// A stable notification id inside Madar's adhkar block
  /// ([NotificationNamespaces.adhkar], 110000–111999): one slot per set and
  /// calendar day, so re-planning the same reminder keeps its id (the
  /// notification service then leaves it alone) and no two planned
  /// reminders ever share one.
  int get notificationId {
    final day = DateTime.utc(at.year, at.month, at.day).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
    final slots = AdhkarCategoryId.values.length;
    return NotificationNamespaces.adhkar.id((day % idCycleDays) * slots + category.index);
  }

  @override
  bool operator ==(Object other) => other is AdhkarReminder && other.category == category && other.at == at;

  @override
  int get hashCode => Object.hash(category, at);

  @override
  String toString() => 'AdhkarReminder($id @ $at)';
}

/// A reminder ready for the notification layer: when, what to show, and the
/// deep-link payload (`adhkar:<category>`).
@immutable
class AdhkarReminderNotice {
  const AdhkarReminderNotice({required this.reminder, required this.title, required this.body});

  final AdhkarReminder reminder;
  final String title;
  final String body;

  DateTime get at => reminder.at;

  /// The notification id (inside [NotificationNamespaces.adhkar]).
  int get id => reminder.notificationId;
  String get payload => 'adhkar:${reminder.category.name}';

  /// What a tap hands back to the app (see `AdhkarReminderTaps`).
  Map<String, Object?> get data => {'set': reminder.category.name};

  @override
  bool operator ==(Object other) =>
      other is AdhkarReminderNotice && other.reminder == reminder && other.title == title && other.body == body;

  @override
  int get hashCode => Object.hash(reminder, title, body);
}

/// Plans reminders from the prayer times (pure).
abstract final class AdhkarReminderPlanner {
  /// Reminders for today and the next [days] − 1 days that are still ahead
  /// of [now], in time order.
  static List<AdhkarReminder> plan({
    required AdhkarReminderSettings settings,
    required DayTimes Function(DateTime day) timesFor,
    required DateTime now,
    int days = 7,
  }) {
    final out = <AdhkarReminder>[];
    for (var d = 0; d < days; d++) {
      final day = DateTime(now.year, now.month, now.day + d);
      final t = timesFor(day);
      if (settings.morning) {
        final at = t.fajr.add(Duration(minutes: settings.morningOffsetMin));
        if (at.isAfter(now)) out.add(AdhkarReminder(category: AdhkarCategoryId.morning, at: at));
      }
      if (settings.evening) {
        final at = t.asr.add(Duration(minutes: settings.eveningOffsetMin));
        if (at.isAfter(now)) out.add(AdhkarReminder(category: AdhkarCategoryId.evening, at: at));
      }
    }
    out.sort((a, b) => a.at.compareTo(b.at));
    return out;
  }
}

/// Delivers adhkar reminders as local notifications
/// (`NotificationAdhkarReminderScheduler` over Madar's notification
/// service); [NoopAdhkarReminderScheduler] until it is wired.
abstract interface class AdhkarReminderScheduler {
  /// Replaces every scheduled adhkar reminder with [notices].
  Future<void> replaceAll(List<AdhkarReminderNotice> notices);

  /// Cancels every adhkar reminder.
  Future<void> cancelAll();

  /// Asks for permission to post notifications when it is not granted yet
  /// (Android 13+). True when reminders can be shown.
  Future<bool> ensurePermission();
}

/// Schedules nothing (tests, and until the notification layer is wired).
class NoopAdhkarReminderScheduler implements AdhkarReminderScheduler {
  const NoopAdhkarReminderScheduler();

  @override
  Future<void> replaceAll(List<AdhkarReminderNotice> notices) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<bool> ensurePermission() async => true;
}
