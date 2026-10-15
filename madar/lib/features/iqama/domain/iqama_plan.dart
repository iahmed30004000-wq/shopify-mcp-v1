import 'package:flutter/foundation.dart';

import '../../../core/notifications/notification_models.dart';
import '../../adhan/domain/adhan_plan.dart';
import '../../adhan/domain/adhan_settings.dart';
import '../../adhan/domain/adhan_slot.dart';
import 'iqama_settings.dart';

/// One iqama the feature wants pending.
@immutable
class IqamaAlarm {
  const IqamaAlarm({
    required this.id,
    required this.slot,
    required this.at,
    required this.prayerAt,
    required this.day,
    required this.minutes,
    this.nextAdhanAt,
    this.jumuah = false,
  });

  final int id;
  final AdhanSlot slot;

  /// When it calls (`prayerAt` + [minutes]).
  final DateTime at;

  /// The adhan it follows.
  final DateTime prayerAt;

  /// The prayer day (calendar date, UTC midnight).
  final DateTime day;

  /// Minutes after the adhan.
  final int minutes;

  /// The next prayer's adhan – nothing of this prayer may be armed past it
  /// (the snooze included).
  final DateTime? nextAdhanAt;

  /// Friday's Dhuhr, which has its own offset.
  final bool jumuah;

  @override
  bool operator ==(Object other) =>
      other is IqamaAlarm &&
      other.id == id &&
      other.slot == slot &&
      other.at == at &&
      other.prayerAt == prayerAt &&
      other.day == day &&
      other.minutes == minutes &&
      other.nextAdhanAt == nextAdhanAt &&
      other.jumuah == jumuah;

  @override
  int get hashCode => Object.hash(id, slot, at, prayerAt, day, minutes, nextAdhanAt, jumuah);

  @override
  String toString() => 'IqamaAlarm(#$id ${slot.name} at ${at.toUtc().toIso8601String()} +${minutes}m)';
}

/// Notification ids of «الإقامة» inside [NotificationNamespaces.iqama]
/// (180000–180999) – its own block, never inside the adhan's:
///
/// `180000 + (epochDay mod 100) × 8 + slot` for the planned iqamas (the
/// same prayer on the same day always keeps the same id, so a re-plan
/// replaces instead of duplicating), and fixed ids from 180800 up for the
/// one-off snooze and the two notices, which no re-plan may cancel.
abstract final class IqamaIds {
  static const namespace = NotificationNamespaces.iqama;
  static const cycleDays = 100;
  static const slotsPerDay = 8;

  /// The single «بعد شوي» snooze (one at a time, by design).
  static const snooze = 180900;

  /// "You already logged it" – one per prayer, so two prayers answered
  /// minutes apart never overwrite each other's notice.
  static const alreadyFirst = 180910;

  /// "It was not recorded – open Madar".
  static const failedFirst = 180920;

  /// Ids a re-plan must leave alone (the snooze and the notices).
  static bool isOneOff(int id) => id >= 180800 && id <= namespace.last;

  static int slotIndex(AdhanSlot slot) => switch (slot) {
    AdhanSlot.fajr => 0,
    AdhanSlot.dhuhr => 1,
    AdhanSlot.asr => 2,
    AdhanSlot.maghrib => 3,
    AdhanSlot.isha => 4,
    AdhanSlot.sunrise => throw ArgumentError('sunrise has no iqama'),
  };

  static int epochDay(DateTime day) => DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/ 86400000;

  static int of(DateTime day, AdhanSlot slot) {
    final cycle = epochDay(day) % cycleDays;
    return namespace.first + (cycle < 0 ? cycle + cycleDays : cycle) * slotsPerDay + slotIndex(slot);
  }

  static int already(AdhanSlot slot) => alreadyFirst + slotIndex(slot);

  static int failed(AdhanSlot slot) => failedFirst + slotIndex(slot);
}

/// Plans the iqamas of the next days – pure (no plugins, no clock).
///
/// * One per prayer whose **adhan** is on and whose **iqama** is on, at its
///   own offset after the adhan; Friday's Dhuhr takes Friday's own offset
///   and its own switch.
/// * Never past the next prayer's adhan: a long offset, or Maghrib's iqama
///   in a winter where Isha follows it closely, is dropped rather than
///   moved – the prayer's time is over by then.
/// * Days are calendar days in the user's zone ([LocalDayOf]) and the
///   moments come from [AdhanTimesFor], so a daylight-saving change or a
///   flight moves nothing but the clock face. Yesterday is included (an
///   Isha past midnight).
class IqamaPlanner {
  const IqamaPlanner({this.horizonDays = 8, this.maxAlarms = 60}) : assert(horizonDays > 0 && horizonDays < 60);

  final int horizonDays;
  final int maxAlarms;

  List<IqamaAlarm> plan({
    required IqamaSettings settings,
    required AdhanSettings adhan,
    required DateTime now,
    required AdhanTimesFor timesFor,
    required LocalDayOf localDayOf,
  }) {
    final today = localDayOf(now);
    final out = <IqamaAlarm>[];
    final ids = <int>{};
    for (var offset = -1; offset <= horizonDays; offset++) {
      final day = DateTime.utc(today.year, today.month, today.day + offset);
      final times = timesFor(day);
      final next = timesFor(DateTime.utc(day.year, day.month, day.day + 1));
      for (final slot in AdhanSlot.prayers) {
        final prayerAt = times[slot];
        if (prayerAt == null) continue;
        if (!adhan.alertOf(slot).adhan) continue;
        final iqama = settings.on(day, slot);
        if (!iqama.on) continue;
        final at = prayerAt.add(Duration(minutes: iqama.minutes));
        if (!at.isAfter(now)) continue;
        final nextAdhanAt = _nextPrayerAfter(slot, times, next);
        // Its time is over: an iqama (or a snooze) past the next adhan is
        // dropped, never moved.
        if (nextAdhanAt != null && !at.isBefore(nextAdhanAt)) continue;
        final id = IqamaIds.of(day, slot);
        if (!ids.add(id)) continue;
        out.add(
          IqamaAlarm(
            id: id,
            slot: slot,
            at: at,
            prayerAt: prayerAt,
            day: day,
            minutes: iqama.minutes,
            nextAdhanAt: nextAdhanAt,
            jumuah: IqamaSettings.isJumuah(day, slot),
          ),
        );
      }
    }
    final end = now.add(Duration(days: horizonDays));
    out.removeWhere((a) => a.at.isAfter(end));
    out.sort((a, b) {
      final c = a.at.compareTo(b.at);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
    return out.length <= maxAlarms ? out : out.sublist(0, maxAlarms);
  }

  /// The prayer after [slot]: the next of the day, else the next day's
  /// Fajr.
  static DateTime? _nextPrayerAfter(AdhanSlot slot, AdhanDayTimes today, AdhanDayTimes tomorrow) {
    final order = AdhanSlot.prayers;
    for (var i = order.indexOf(slot) + 1; i < order.length; i++) {
      final at = today[order[i]];
      if (at != null) return at;
    }
    return tomorrow[AdhanSlot.fajr];
  }

  /// The next iqama at or after [now] in [alarms].
  static IqamaAlarm? next(List<IqamaAlarm> alarms, DateTime now) {
    for (final a in alarms) {
      if (!a.at.isBefore(now)) return a;
    }
    return null;
  }
}
