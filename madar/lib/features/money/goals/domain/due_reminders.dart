/// Reminder plan for debt and obligation due dates (pure Dart).
library;

import 'package:meta/meta.dart';

import 'due_dates.dart';

/// When due reminders fire. Stored in `key_values['money.goals.reminders']`.
@immutable
class GoalsReminderSettings {
  const GoalsReminderSettings({
    this.enabled = true,
    this.leadDays = 1,
    this.minuteOfDay = defaultMinuteOfDay,
    this.onDueDay = true,
  });

  static const String storageKey = 'money.goals.reminders';

  /// 09:00.
  static const int defaultMinuteOfDay = 9 * 60;

  /// Lead times offered in the settings sheet (0 = no early reminder).
  static const List<int> leadChoices = [0, 1, 2, 3, 7];

  final bool enabled;

  /// Days before the due date for the early reminder (0 = none).
  final int leadDays;

  /// Local time of day, minutes after midnight.
  final int minuteOfDay;

  /// Also remind on the due day itself.
  final bool onDueDay;

  int get hour => minuteOfDay ~/ 60;
  int get minute => minuteOfDay % 60;

  GoalsReminderSettings copyWith({bool? enabled, int? leadDays, int? minuteOfDay, bool? onDueDay}) =>
      GoalsReminderSettings(
        enabled: enabled ?? this.enabled,
        leadDays: leadDays ?? this.leadDays,
        minuteOfDay: minuteOfDay ?? this.minuteOfDay,
        onDueDay: onDueDay ?? this.onDueDay,
      );

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'leadDays': leadDays,
    'minuteOfDay': minuteOfDay,
    'onDueDay': onDueDay,
  };

  /// Tolerant: missing or malformed fields keep their defaults.
  factory GoalsReminderSettings.fromJson(Object? json) {
    if (json is! Map) return const GoalsReminderSettings();
    const d = GoalsReminderSettings();
    final lead = json['leadDays'];
    final minute = json['minuteOfDay'];
    return GoalsReminderSettings(
      enabled: json['enabled'] is bool ? json['enabled'] as bool : d.enabled,
      leadDays: lead is num ? lead.toInt().clamp(0, 30) : d.leadDays,
      minuteOfDay: minute is num ? minute.toInt().clamp(0, 24 * 60 - 1) : d.minuteOfDay,
      onDueDay: json['onDueDay'] is bool ? json['onDueDay'] as bool : d.onDueDay,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GoalsReminderSettings &&
      other.enabled == enabled &&
      other.leadDays == leadDays &&
      other.minuteOfDay == minuteOfDay &&
      other.onDueDay == onDueDay;

  @override
  int get hashCode => Object.hash(enabled, leadDays, minuteOfDay, onDueDay);
}

/// What a due reminder is about.
enum DueReminderKind { obligation, debt }

/// Something with a due date that may deserve a reminder.
@immutable
class DueItem {
  const DueItem({required this.kind, required this.refId, required this.due});

  final DueReminderKind kind;
  final String refId;
  final DateTime due;
}

/// One planned reminder (the data layer gives it a notification id).
@immutable
class DueReminder {
  const DueReminder({required this.item, required this.at, required this.daysBefore});

  final DueItem item;

  /// When it fires (local wall clock).
  final DateTime at;

  /// 0 on the due day, otherwise the lead time in days.
  final int daysBefore;

  @override
  String toString() => 'DueReminder(${item.kind.name} ${item.refId} at $at, $daysBefore d before)';
}

/// Plans due reminders: an early one [GoalsReminderSettings.leadDays]
/// before and one on the due day, at the configured time, for due dates in
/// the next [horizonDays]. Moments already past are dropped; the result is
/// sorted by time and capped at [max].
abstract final class DueReminderPlanner {
  static List<DueReminder> plan({
    required Iterable<DueItem> items,
    required GoalsReminderSettings settings,
    required DateTime now,
    int horizonDays = 62,
    int max = 1000,
  }) {
    if (!settings.enabled) return const [];
    final today = CalendarDays.of(now);
    final horizon = CalendarDays.addDays(today, horizonDays);
    final out = <DueReminder>[];
    DateTime at(DateTime day) => DateTime(day.year, day.month, day.day, settings.hour, settings.minute);
    for (final item in items) {
      final due = CalendarDays.of(item.due);
      if (due.isBefore(today) || due.isAfter(horizon)) continue;
      if (settings.leadDays > 0) {
        final early = at(CalendarDays.addDays(due, -settings.leadDays));
        if (early.isAfter(now)) out.add(DueReminder(item: item, at: early, daysBefore: settings.leadDays));
      }
      if (settings.onDueDay) {
        final onDay = at(due);
        if (onDay.isAfter(now)) out.add(DueReminder(item: item, at: onDay, daysBefore: 0));
      }
    }
    out.sort((a, b) {
      final c = a.at.compareTo(b.at);
      if (c != 0) return c;
      final k = a.item.kind.index.compareTo(b.item.kind.index);
      return k != 0 ? k : a.item.refId.compareTo(b.item.refId);
    });
    return out.length > max ? out.sublist(0, max) : out;
  }
}
