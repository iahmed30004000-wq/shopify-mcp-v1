import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/notifications/notification_models.dart';
import 'family_models.dart';
import 'rhythm.dart';

/// The Family planet's slice of the shared `reminders` notification
/// namespace (130000–139999). Family only ever reconciles this block, so
/// other features' reminders in the namespace are left alone:
///
/// * 136000–136099 – the daily digest (one per day of the plan);
/// * 136100–136999 – birthday reminders (the day before and the day).
abstract final class FamilyNotificationIds {
  static const NotificationNamespace namespace = NotificationNamespaces.reminders;
  static const int first = 136000, last = 136999;
  static const int digestFirst = 136000, digestLast = 136099;
  static const int birthdayFirst = 136100, birthdayLast = 136999;

  /// Whether [id] belongs to the Family block.
  static bool owns(int id) => id >= first && id <= last;

  static int _hash(String s) {
    var h = 0x811c9dc5;
    for (final unit in utf8.encode(s)) {
      h ^= unit;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h;
  }

  /// The digest of [day] (stable for a day, distinct across the plan).
  static int digest(DateTime day) => digestFirst + CalendarDays.between(DateTime(2000), day) % 16;

  /// Ids for birthday reminder [keys]: each its preferred hash slot, the
  /// next free one on a collision (in key order, so deterministic).
  static Map<String, int> birthdays(Iterable<String> keys) {
    const size = birthdayLast - birthdayFirst + 1;
    final sorted = keys.toSet().toList()..sort();
    final used = <int>{};
    final out = <String, int>{};
    for (final k in sorted) {
      var id = birthdayFirst + _hash(k) % size;
      for (var i = 0; used.contains(id) && i < size; i++) {
        id = id == birthdayLast ? birthdayFirst : id + 1;
      }
      used.add(id);
      out[k] = id;
    }
    return out;
  }
}

/// What kind of Family notification a tap was (the `k` payload field).
enum FamilyNoticeKind { digest, birthdayEve, birthday }

/// The texts of the Family notifications (in the UI language).
abstract interface class FamilyReminderTexts {
  String digestTitle(int count);

  /// [names] are already isolated; the body lists them.
  String digestBody(List<String> names, int more);
  String birthdayEveTitle(String name);
  String birthdayEveBody(int? turning);
  String birthdayDayTitle(String name);
  String birthdayDayBody(int? turning);

  /// A person's name, bidi-isolated.
  String name(String name);
}

/// One planned Family notification.
@immutable
class FamilyNotice {
  const FamilyNotice({
    required this.id,
    required this.kind,
    required this.at,
    required this.title,
    required this.body,
    this.personId,
    this.personIds = const [],
  });

  final int id;
  final FamilyNoticeKind kind;
  final DateTime at;
  final String title;
  final String body;

  /// The birthday's person.
  final String? personId;

  /// The digest's people, most overdue first.
  final List<String> personIds;

  Map<String, Object?> get data => {'k': kind.name, 'p': ?personId};

  @override
  String toString() => 'FamilyNotice($id, ${kind.name}, $at, $title)';
}

/// Plans the Family notifications (pure): a gentle daily digest listing
/// who is due or overdue that day – one notification, never one per person –
/// and birthday reminders (the day before and the day). Re-plan whenever
/// people, contacts or settings change; the result is the complete wanted
/// set for [FamilyNotificationIds].
abstract final class FamilyReminderPlanner {
  /// Days of digests planned ahead (re-planned daily while the app runs).
  static const int digestDays = 14;

  /// Birthdays within this many days are scheduled.
  static const int birthdayHorizonDays = 60;

  /// Names listed by name in a digest; the rest are counted.
  static const int digestNames = 4;

  static DateTime _at(DateTime day, int minutes) => DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);

  static List<FamilyNotice> plan({
    required List<PersonView> people,
    required FamilySettings settings,
    required DateTime now,
    required FamilyReminderTexts texts,
  }) {
    final out = <FamilyNotice>[];
    final today = CalendarDays.dayOf(now);

    if (settings.digestEnabled) {
      final withRhythm = people.where((p) => p.rhythm.nextDue != null).toList();
      for (var k = 0; k < digestDays && withRhythm.isNotEmpty; k++) {
        final day = CalendarDays.add(today, k);
        final at = _at(day, settings.digestMinutes);
        if (!at.isAfter(now)) continue;
        final due = withRhythm.where((p) => RhythmEngine.dueOn(p.rhythm, day)).toList()
          ..sort((a, b) {
            // Most overdue on that day first: the larger share of the rhythm.
            double share(PersonView p) => CalendarDays.between(p.rhythm.nextDue!, day) / p.rhythm.rhythmDays!;
            final c = share(b).compareTo(share(a));
            return c != 0 ? c : a.name.compareTo(b.name);
          });
        if (due.isEmpty) continue;
        final shown = due.take(digestNames).map((p) => texts.name(p.name)).toList();
        out.add(
          FamilyNotice(
            id: FamilyNotificationIds.digest(day),
            kind: FamilyNoticeKind.digest,
            at: at,
            title: texts.digestTitle(due.length),
            body: texts.digestBody(shown, due.length - shown.length),
            personIds: [for (final p in due) p.id],
          ),
        );
      }
    }

    if (settings.birthdaysEnabled) {
      final wanted = <(String key, FamilyNotice Function(int id))>[];
      for (final p in people) {
        final info = p.birthday;
        if (info == null || info.daysUntil > birthdayHorizonDays) continue;
        final day = info.next;
        final eve = _at(CalendarDays.add(day, -1), settings.birthdayMinutes);
        final on = _at(day, settings.birthdayMinutes);
        if (eve.isAfter(now)) {
          wanted.add((
            'eve:${p.id}',
            (id) => FamilyNotice(
              id: id,
              kind: FamilyNoticeKind.birthdayEve,
              at: eve,
              title: texts.birthdayEveTitle(texts.name(p.name)),
              body: texts.birthdayEveBody(info.turning),
              personId: p.id,
            ),
          ));
        }
        if (on.isAfter(now)) {
          wanted.add((
            'day:${p.id}',
            (id) => FamilyNotice(
              id: id,
              kind: FamilyNoticeKind.birthday,
              at: on,
              title: texts.birthdayDayTitle(texts.name(p.name)),
              body: texts.birthdayDayBody(info.turning),
              personId: p.id,
            ),
          ));
        }
      }
      final ids = FamilyNotificationIds.birthdays([for (final w in wanted) w.$1]);
      for (final (key, build) in wanted) {
        out.add(build(ids[key]!));
      }
    }

    out.sort((a, b) => a.at.compareTo(b.at));
    return out;
  }
}

/// Routing of tapped Family notifications.
abstract final class FamilyNotificationTaps {
  static bool isFamily(NotificationTap tap) =>
      tap.namespace == FamilyNotificationIds.namespace.name &&
      (tap.id == null || FamilyNotificationIds.owns(tap.id!)) &&
      FamilyNoticeKind.values.any((k) => k.name == tap.data['k']);

  static FamilyNoticeKind? kindOf(NotificationTap tap) {
    if (!isFamily(tap)) return null;
    return FamilyNoticeKind.values.where((k) => k.name == tap.data['k']).firstOrNull;
  }

  /// The person a birthday reminder is about (null for the digest: open the
  /// Family screen).
  static String? personOf(NotificationTap tap) {
    if (!isFamily(tap)) return null;
    final p = tap.data['p'];
    return p is String ? p : null;
  }
}
