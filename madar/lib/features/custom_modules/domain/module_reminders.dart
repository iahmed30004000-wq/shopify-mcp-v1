/// Reminders of custom modules: which notifications to schedule, when, and
/// under which ids. Pure logic (no plugin, no clock of its own).
///
/// Reminder rows live in the shared `reminders` table (`owner_table =
/// 'custom_modules'`, `owner_id` = module id) with the standard rule shapes
/// (`once`, `daily`, `weekly`, `prayer` – see `core_tables.dart`).
library;

import 'dart:convert';

import '../../../core/domain/enums.dart';
import '../../../core/interaction/sheets/reminder_rule.dart';
import '../../../core/notifications/notification_models.dart';

/// The Custom Modules block of the shared `reminders` namespace
/// (130000–139999): **137000–137999** (offsets 7000–7999). Syncing only ever
/// touches ids for which [owns] is true, so Family (136xxx), Travel (138xxx),
/// Goals (132xxx) and Body (1398xx) are left alone.
abstract final class CustomModuleReminderIds {
  static const NotificationNamespace namespace = NotificationNamespaces.reminders;
  static const int firstOffset = 7000;
  static const int size = 1000;

  static int get first => namespace.first + firstOffset;
  static int get last => first + size - 1;

  static bool owns(int id) => id >= first && id <= last;

  static int _hash(String s) {
    var h = 0x811c9dc5;
    for (final unit in utf8.encode(s)) {
      h ^= unit;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h;
  }

  /// Ids for occurrence [keys]: each its preferred hash slot, the next free
  /// one on a collision (keys in sorted order, so deterministic). At most
  /// [size] keys get an id.
  static Map<String, int> assign(Iterable<String> keys) {
    final sorted = keys.toSet().toList()..sort();
    final used = <int>{};
    final out = <String, int>{};
    for (final k in sorted) {
      if (used.length >= size) break;
      var slot = _hash(k) % size;
      while (used.contains(slot)) {
        slot = (slot + 1) % size;
      }
      used.add(slot);
      out[k] = first + slot;
    }
    return out;
  }
}

/// A module reminder as the planner sees it.
class ModuleReminderInput {
  const ModuleReminderInput({
    required this.reminderId,
    required this.moduleId,
    required this.moduleName,
    required this.kind,
    required this.rule,
    this.enabled = true,
    this.note,
  });

  final String reminderId;
  final String moduleId;
  final String moduleName;
  final CustomModuleKind kind;
  final Map<String, Object?> rule;
  final bool enabled;

  /// The reminder's own title (`reminders.title`), shown as the body.
  final String? note;
}

/// The start of [window] on [day] (Fajr, sunrise for Duha, Dhuhr …); null
/// when unknown.
typedef PrayerStartOf = DateTime? Function(DateTime day, PrayerWindow window);

/// Localised notification texts.
abstract interface class CustomReminderTexts {
  String reminderTitle(String moduleName);
  String reminderBody(CustomModuleKind kind, String moduleName);
}

/// One notification to schedule.
class ModuleNotice {
  const ModuleNotice({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
    required this.moduleId,
    required this.reminderId,
  });

  final int id;
  final DateTime at;
  final String title;
  final String body;
  final String moduleId;
  final String reminderId;

  /// Tap payload: `{"k":"cmod","m":moduleId,"r":reminderId}`.
  Map<String, Object?> get data => {'k': CustomModuleNotificationTaps.kind, 'm': moduleId, 'r': reminderId};

  @override
  String toString() => 'ModuleNotice($id, $at, $title)';
}

abstract final class CustomReminderPlanner {
  /// Recurring reminders are planned this many days ahead (re-planned
  /// whenever the app runs or anything changes).
  static const int horizonDays = 7;

  /// At most this many pending notifications (the nearest ones).
  static const int cap = 96;

  /// The rule kinds a module reminder may use.
  static const Set<ReminderKind> kinds = {ReminderKind.once, ReminderKind.daily, ReminderKind.weekly, ReminderKind.prayer};

  static List<ModuleNotice> plan({
    required List<ModuleReminderInput> reminders,
    required DateTime now,
    required PrayerStartOf prayerStart,
    required CustomReminderTexts texts,
    int horizon = horizonDays,
  }) {
    final raw = <({ModuleReminderInput r, DateTime at})>[];
    for (final r in reminders) {
      if (!r.enabled) continue;
      final rule = ReminderRule.fromJson(r.rule);
      if (rule == null) continue;
      for (final at in occurrences(rule, now: now, horizon: horizon, prayerStart: prayerStart)) {
        raw.add((r: r, at: at));
      }
    }
    raw.sort((a, b) {
      final c = a.at.compareTo(b.at);
      return c != 0 ? c : a.r.reminderId.compareTo(b.r.reminderId);
    });
    final kept = raw.take(cap).toList();
    String key(({ModuleReminderInput r, DateTime at}) x) => '${x.r.reminderId}|${ReminderRule.formatLocal(x.at)}';
    final ids = CustomModuleReminderIds.assign(kept.map(key));
    return [
      for (final x in kept)
        if (ids[key(x)] case final int id)
          ModuleNotice(
            id: id,
            at: x.at,
            title: texts.reminderTitle(x.r.moduleName),
            body: (x.r.note?.trim().isNotEmpty ?? false) ? x.r.note!.trim() : texts.reminderBody(x.r.kind, x.r.moduleName),
            moduleId: x.r.moduleId,
            reminderId: x.r.reminderId,
          ),
    ];
  }

  /// The instants [rule] fires after [now]: a one-off whenever it is in the
  /// future, recurring ones within [horizon] days (today included).
  static List<DateTime> occurrences(
    ReminderRule rule, {
    required DateTime now,
    required PrayerStartOf prayerStart,
    int horizon = horizonDays,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    DateTime at(DateTime day, String hm) =>
        DateTime(day.year, day.month, day.day, int.parse(hm.substring(0, 2)), int.parse(hm.substring(3, 5)));
    final out = <DateTime>[];
    switch (rule) {
      case OnceReminder(at: final t):
        if (t.isAfter(now)) out.add(t);
      case DailyReminder(:final time):
        for (var i = 0; i < horizon; i++) {
          final t = at(DateTime(today.year, today.month, today.day + i), time);
          if (t.isAfter(now)) out.add(t);
        }
      case WeeklyReminder(:final time, :final weekdays):
        for (var i = 0; i < horizon; i++) {
          final day = DateTime(today.year, today.month, today.day + i);
          if (!weekdays.contains(day.weekday)) continue;
          final t = at(day, time);
          if (t.isAfter(now)) out.add(t);
        }
      case PrayerReminder(:final window, :final offsetMin):
        for (var i = 0; i < horizon; i++) {
          final day = DateTime(today.year, today.month, today.day + i);
          final start = prayerStart(day, window);
          if (start == null) continue;
          final t = start.add(Duration(minutes: offsetMin));
          final minute = DateTime(t.year, t.month, t.day, t.hour, t.minute);
          if (minute.isAfter(now)) out.add(minute);
        }
      case BeforeDueReminder():
        break; // Modules have no due date.
    }
    return out;
  }
}

/// Routing of notification taps.
abstract final class CustomModuleNotificationTaps {
  static const String kind = 'cmod';

  static bool isCustomModule(NotificationTap tap) =>
      tap.namespace == CustomModuleReminderIds.namespace.name &&
      (tap.id == null || CustomModuleReminderIds.owns(tap.id!)) &&
      tap.data['k'] == kind;

  /// The module to open for [tap] (null when the tap is not ours).
  static String? moduleOf(NotificationTap tap) {
    if (!isCustomModule(tap)) return null;
    final m = tap.data['m'];
    return m is String && m.isNotEmpty ? m : null;
  }
}
