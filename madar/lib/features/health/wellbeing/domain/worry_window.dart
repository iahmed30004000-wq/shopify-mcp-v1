import 'package:flutter/foundation.dart';

import '../../../../core/notifications/notification_models.dart';
import 'wellbeing_data.dart';

/// The user's daily worry window: a set time and length when parked worries
/// are reviewed. Off until the user sets it (a fresh install has none).
@immutable
class WorryWindowSettings {
  const WorryWindowSettings({
    this.enabled = false,
    this.minuteOfDay = 18 * 60,
    this.durationMinutes = 15,
    this.remind = true,
  });

  final bool enabled;

  /// Start, minutes after local midnight.
  final int minuteOfDay;
  final int durationMinutes;

  /// Post a notification when the window opens.
  final bool remind;

  static const List<int> durations = [10, 15, 20, 30];

  int get hour => minuteOfDay ~/ 60;
  int get minute => minuteOfDay % 60;

  /// `HH:mm`.
  String get hhmm => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  static int? parseHhmm(String s) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(s.trim());
    if (m == null) return null;
    final h = int.parse(m[1]!), mi = int.parse(m[2]!);
    if (h > 23 || mi > 59) return null;
    return h * 60 + mi;
  }

  WorryWindowSettings copyWith({bool? enabled, int? minuteOfDay, int? durationMinutes, bool? remind}) =>
      WorryWindowSettings(
        enabled: enabled ?? this.enabled,
        minuteOfDay: minuteOfDay ?? this.minuteOfDay,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        remind: remind ?? this.remind,
      );

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'minute': minuteOfDay,
    'duration': durationMinutes,
    'remind': remind,
  };

  static WorryWindowSettings fromJson(Object? json) {
    if (json is! Map) return const WorryWindowSettings();
    int intOr(Object? v, int d) => v is num ? v.toInt() : d;
    return WorryWindowSettings(
      enabled: json['enabled'] == true,
      minuteOfDay: intOr(json['minute'], 18 * 60).clamp(0, 24 * 60 - 1),
      durationMinutes: intOr(json['duration'], 15).clamp(5, 120),
      remind: json['remind'] != false,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WorryWindowSettings &&
      other.enabled == enabled &&
      other.minuteOfDay == minuteOfDay &&
      other.durationMinutes == durationMinutes &&
      other.remind == remind;

  @override
  int get hashCode => Object.hash(enabled, minuteOfDay, durationMinutes, remind);
}

/// Where the day stands relative to the window.
enum WorryWindowPhase { off, before, open, after }

@immutable
class WorryWindowStatus {
  const WorryWindowStatus(this.phase, {this.start, this.end});

  final WorryWindowPhase phase;

  /// Today's window (or the next one when [phase] is [WorryWindowPhase.after]).
  final DateTime? start;
  final DateTime? end;

  bool get isOpen => phase == WorryWindowPhase.open;

  /// Time left while open / until it opens.
  Duration remaining(DateTime now) => switch (phase) {
    WorryWindowPhase.open => end!.difference(now),
    WorryWindowPhase.before || WorryWindowPhase.after => start!.difference(now),
    WorryWindowPhase.off => Duration.zero,
  };
}

abstract final class WorryWindow {
  /// Today's window start (local wall clock).
  static DateTime startOn(DateTime day, WorryWindowSettings s) =>
      DateTime(day.year, day.month, day.day, s.hour, s.minute);

  static WorryWindowStatus statusAt(WorryWindowSettings s, DateTime now) {
    if (!s.enabled) return const WorryWindowStatus(WorryWindowPhase.off);
    final start = startOn(now, s);
    final end = start.add(Duration(minutes: s.durationMinutes));
    if (now.isBefore(start)) return WorryWindowStatus(WorryWindowPhase.before, start: start, end: end);
    if (now.isBefore(end)) return WorryWindowStatus(WorryWindowPhase.open, start: start, end: end);
    final next = startOn(WbDays.add(WbDays.dateOf(now), 1), s);
    return WorryWindowStatus(
      WorryWindowPhase.after,
      start: next,
      end: next.add(Duration(minutes: s.durationMinutes)),
    );
  }

  /// The next [days] window starts strictly after [now] (none when off or
  /// reminders are disabled).
  static List<DateTime> upcoming(WorryWindowSettings s, DateTime now, {int days = WorryReminderIds.size}) {
    if (!s.enabled || !s.remind) return const [];
    final out = <DateTime>[];
    var day = WbDays.dateOf(now);
    while (out.length < days) {
      final start = startOn(day, s);
      if (start.isAfter(now)) out.add(start);
      day = WbDays.add(day, 1);
    }
    return out;
  }
}

/// The worry window's block of the shared health namespace
/// (150000–150999): offsets 900–906 = 150900–150906, one per planned day.
/// The appointment reminders own 150000–150399; syncing only ever touches
/// ids for which [owns] is true.
abstract final class WorryReminderIds {
  static const NotificationNamespace namespace = NotificationNamespaces.health;
  static const int firstOffset = 900;

  /// Days planned ahead (re-planned whenever the app runs).
  static const int size = 7;

  static int get first => namespace.first + firstOffset;
  static int get last => first + size - 1;

  static bool owns(int id) => id >= first && id <= last;

  static int of(int slot) {
    if (slot < 0 || slot >= size) throw RangeError.range(slot, 0, size - 1, 'slot');
    return namespace.id(firstOffset + slot);
  }
}
