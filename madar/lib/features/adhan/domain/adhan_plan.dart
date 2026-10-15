import 'package:flutter/foundation.dart';

import '../../../core/notifications/notification_models.dart';
import 'adhan_settings.dart';
import 'adhan_slot.dart';
import 'adhan_sound.dart';

/// The six moments of one prayer day as instants.
@immutable
class AdhanDayTimes {
  const AdhanDayTimes(this.day, this.times);

  /// The calendar date (a UTC midnight used as a plain date).
  final DateTime day;
  final Map<AdhanSlot, DateTime> times;

  DateTime? operator [](AdhanSlot slot) => times[slot];
}

/// Prayer times of a calendar [day] (UTC midnight used as a plain date).
typedef AdhanTimesFor = AdhanDayTimes Function(DateTime day);

/// The calendar date (UTC midnight) of [instant] in the user's time zone.
typedef LocalDayOf = DateTime Function(DateTime instant);

/// The device zone's calendar date of [instant].
DateTime deviceLocalDayOf(DateTime instant) {
  final l = instant.toLocal();
  return DateTime.utc(l.year, l.month, l.day);
}

/// One alarm the adhan feature wants pending.
@immutable
class AdhanAlarm {
  const AdhanAlarm({
    required this.id,
    required this.kind,
    required this.slot,
    required this.at,
    required this.prayerAt,
    required this.day,
    this.sound,
    this.minutesBefore = 0,
  });

  final int id;
  final AdhanKind kind;
  final AdhanSlot slot;

  /// When it fires.
  final DateTime at;

  /// The prayer (or sunrise) time it announces.
  final DateTime prayerAt;

  /// The prayer day (calendar date, UTC midnight).
  final DateTime day;

  /// The muezzin / tone of an adhan (null for reminders).
  final AdhanSoundRef? sound;

  /// Lead time of a reminder / sunrise alert.
  final int minutesBefore;

  @override
  bool operator ==(Object other) =>
      other is AdhanAlarm &&
      other.id == id &&
      other.kind == kind &&
      other.slot == slot &&
      other.at == at &&
      other.prayerAt == prayerAt &&
      other.day == day &&
      other.sound == sound &&
      other.minutesBefore == minutesBefore;

  @override
  int get hashCode => Object.hash(id, kind, slot, at, prayerAt, day, sound, minutesBefore);

  @override
  String toString() => 'AdhanAlarm(#$id ${kind.name} ${slot.name} at ${at.toUtc().toIso8601String()})';
}

/// Notification ids of the adhan feature inside
/// [NotificationNamespaces.adhan] (100000–101999):
///
/// `100000 + (epochDay mod 100) × 16 + slot` for the scheduled alarms – so
/// the same prayer on the same day always has the same id (re-scheduling
/// replaces instead of duplicating) – and fixed ids above 101800 for the
/// one-off test and snooze.
abstract final class AdhanIds {
  static const namespace = NotificationNamespaces.adhan;
  static const cycleDays = 100;
  static const slotsPerDay = 16;
  static const test = 101900;
  static const snooze = 101901;

  /// One-off ids (test, snooze) a re-plan must not cancel.
  static bool isOneOff(int id) => id >= 101800 && id <= namespace.last;

  static int slotIndex(AdhanKind kind, AdhanSlot slot) => switch ((kind, slot)) {
    (AdhanKind.sunrise, _) => 5,
    (AdhanKind.adhan, AdhanSlot.fajr) => 0,
    (AdhanKind.adhan, AdhanSlot.dhuhr) => 1,
    (AdhanKind.adhan, AdhanSlot.asr) => 2,
    (AdhanKind.adhan, AdhanSlot.maghrib) => 3,
    (AdhanKind.adhan, AdhanSlot.isha) => 4,
    (AdhanKind.preAdhan, AdhanSlot.fajr) => 6,
    (AdhanKind.preAdhan, AdhanSlot.dhuhr) => 7,
    (AdhanKind.preAdhan, AdhanSlot.asr) => 8,
    (AdhanKind.preAdhan, AdhanSlot.maghrib) => 9,
    (AdhanKind.preAdhan, AdhanSlot.isha) => 10,
    _ => throw ArgumentError('no scheduled slot for ${kind.name}/${slot.name}'),
  };

  static int epochDay(DateTime day) => DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/ 86400000;

  static int of(DateTime day, AdhanKind kind, AdhanSlot slot) {
    final cycle = epochDay(day) % cycleDays;
    return namespace.first + (cycle < 0 ? cycle + cycleDays : cycle) * slotsPerDay + slotIndex(kind, slot);
  }
}

/// Plans the alarms of the next days – pure (no plugins, no clock).
///
/// * Every enabled prayer's adhan at its exact time, its reminder (if any)
///   and the optional sunrise alert, for today and the next
///   [horizonDays] − 1 days: eight days, so the adhan keeps sounding through
///   a whole week without opening the app.
/// * Days are calendar days in the user's zone ([LocalDayOf]); instants come
///   from [AdhanTimesFor], so a daylight-saving change or a zone change
///   moves nothing but the local clock face.
/// * Yesterday is included, so an Isha after midnight (high-latitude
///   summer) still sounds.
/// * Only future moments; at most [maxAlarms] (the soonest), well inside
///   Android's 500-alarms-per-app limit so other features keep room.
class AdhanPlanner {
  const AdhanPlanner({this.horizonDays = 8, this.maxAlarms = 100}) : assert(horizonDays > 0 && horizonDays < 60);

  final int horizonDays;
  final int maxAlarms;

  List<AdhanAlarm> plan({
    required AdhanSettings settings,
    required DateTime now,
    required AdhanTimesFor timesFor,
    required LocalDayOf localDayOf,
  }) {
    final today = localDayOf(now);
    final out = <AdhanAlarm>[];
    final ids = <int>{};
    void add(AdhanAlarm a) {
      if (!a.at.isAfter(now)) return;
      if (!ids.add(a.id)) return;
      out.add(a);
    }

    for (var offset = -1; offset <= horizonDays; offset++) {
      final day = DateTime.utc(today.year, today.month, today.day + offset);
      final times = timesFor(day);
      for (final slot in AdhanSlot.prayers) {
        final at = times[slot];
        if (at == null) continue;
        final alert = settings.alertOf(slot);
        if (alert.adhan) {
          add(
            AdhanAlarm(
              id: AdhanIds.of(day, AdhanKind.adhan, slot),
              kind: AdhanKind.adhan,
              slot: slot,
              at: at,
              prayerAt: at,
              day: day,
              sound: settings.resolve(settings.soundFor(slot), slot),
            ),
          );
        }
        if (alert.hasReminder) {
          add(
            AdhanAlarm(
              id: AdhanIds.of(day, AdhanKind.preAdhan, slot),
              kind: AdhanKind.preAdhan,
              slot: slot,
              at: at.subtract(Duration(minutes: alert.preMinutes)),
              prayerAt: at,
              day: day,
              minutesBefore: alert.preMinutes,
            ),
          );
        }
      }
      final sunrise = times[AdhanSlot.sunrise];
      if (settings.sunriseAlert && sunrise != null) {
        add(
          AdhanAlarm(
            id: AdhanIds.of(day, AdhanKind.sunrise, AdhanSlot.sunrise),
            kind: AdhanKind.sunrise,
            slot: AdhanSlot.sunrise,
            at: sunrise.subtract(Duration(minutes: settings.sunriseMinutesBefore)),
            prayerAt: sunrise,
            day: day,
            minutesBefore: settings.sunriseMinutesBefore,
          ),
        );
      }
    }
    // Only the window [now, now + horizon]: yesterday contributes a late
    // Isha at most, the last day nothing beyond the horizon.
    final end = now.add(Duration(days: horizonDays));
    out.removeWhere((a) => a.at.isAfter(end));
    out.sort((a, b) {
      final c = a.at.compareTo(b.at);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
    return out.length <= maxAlarms ? out : out.sublist(0, maxAlarms);
  }

  /// The next adhan (not reminder) at or after [now] in [alarms].
  static AdhanAlarm? nextCall(List<AdhanAlarm> alarms, DateTime now) {
    for (final a in alarms) {
      if (a.kind == AdhanKind.adhan && !a.at.isBefore(now)) return a;
    }
    return null;
  }
}

/// While game music and the ambient bed stay muted after an adhan.
@immutable
class QuietWindow {
  const QuietWindow(this.start, this.end);

  final DateTime start;
  final DateTime end;

  bool contains(DateTime t) => !t.isBefore(start) && t.isBefore(end);

  @override
  bool operator ==(Object other) => other is QuietWindow && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  /// The window of the latest adhan in [alarms] (or [recentCalls]) covering
  /// [now]: from the adhan until [quiet] after it (at least [adhanLength],
  /// the time it sounds).
  static QuietWindow? covering(
    Iterable<DateTime> adhanTimes,
    DateTime now, {
    required Duration quiet,
    required Duration adhanLength,
  }) {
    final span = quiet > adhanLength ? quiet : adhanLength;
    QuietWindow? best;
    for (final t in adhanTimes) {
      final w = QuietWindow(t, t.add(span));
      if (w.contains(now) && (best == null || w.end.isAfter(best.end))) best = w;
    }
    return best;
  }
}
