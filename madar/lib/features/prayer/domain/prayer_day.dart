import 'package:flutter/foundation.dart';

import '../../../core/domain/enums.dart';
import '../../orbit/domain/prayer_schedule.dart';

/// Every moment the prayer-times screen lists, in day order.
enum PrayerMoment {
  fajr,
  sunrise,

  /// The start of Duha (a quarter of an hour after sunrise, when the sun has
  /// risen "a spear's length").
  duha,
  dhuhr,
  asr,
  maghrib,
  isha,

  /// Islamic midnight – halfway from Maghrib to the next Fajr.
  midnight,

  /// The start of the last third of the night (the time for Qiyam).
  lastThird;

  /// Whether the moment is one of the five obligatory prayers.
  bool get isObligatory => switch (this) {
    PrayerMoment.fajr || PrayerMoment.dhuhr || PrayerMoment.asr || PrayerMoment.maghrib || PrayerMoment.isha => true,
    _ => false,
  };

  /// Whether the moment belongs to the night after the day's Isha.
  bool get isNight => this == PrayerMoment.midnight || this == PrayerMoment.lastThird;

  /// The obligatory prayer of this moment, if any.
  Prayer? get prayer => switch (this) {
    PrayerMoment.fajr => Prayer.fajr,
    PrayerMoment.dhuhr => Prayer.dhuhr,
    PrayerMoment.asr => Prayer.asr,
    PrayerMoment.maghrib => Prayer.maghrib,
    PrayerMoment.isha => Prayer.isha,
    _ => null,
  };

  static PrayerMoment ofPrayer(Prayer p) => switch (p) {
    Prayer.fajr || Prayer.sunnahFajr => PrayerMoment.fajr,
    Prayer.dhuhr || Prayer.sunnahDhuhr => PrayerMoment.dhuhr,
    Prayer.asr => PrayerMoment.asr,
    Prayer.maghrib || Prayer.sunnahMaghrib => PrayerMoment.maghrib,
    Prayer.isha || Prayer.sunnahIsha || Prayer.witr => PrayerMoment.isha,
    Prayer.duha => PrayerMoment.duha,
    Prayer.qiyam => PrayerMoment.lastThird,
  };
}

/// Where a moment stands relative to "now".
enum MomentStatus { past, current, upcoming }

/// One timed row of the day.
@immutable
class PrayerMomentTime {
  const PrayerMomentTime(this.moment, this.at);

  final PrayerMoment moment;

  /// The instant (device-local `DateTime`).
  final DateTime at;

  @override
  bool operator ==(Object other) => other is PrayerMomentTime && other.moment == moment && other.at == at;

  @override
  int get hashCode => Object.hash(moment, at);
}

/// A full prayer day of the location: the five prayers, sunrise, the start
/// of Duha, and the following night's midnight and last third.
@immutable
class PrayerTimesDay {
  const PrayerTimesDay({
    required this.date,
    required this.times,
    required this.duha,
    required this.midnight,
    required this.lastThird,
    required this.nextFajr,
  });

  /// Minutes after sunrise at which Duha begins.
  static const duhaAfterSunrise = Duration(minutes: 15);

  /// Computes the day of [schedule] whose (location) date is [date].
  factory PrayerTimesDay.of(PrayerSchedule schedule, DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final times = schedule.timesFor(day);
    final nextFajr = schedule.timesFor(DateTime(day.year, day.month, day.day + 1)).fajr;
    final night = nextFajr.difference(times.maghrib);
    return PrayerTimesDay(
      date: day,
      times: times,
      duha: times.sunrise.add(duhaAfterSunrise),
      midnight: times.maghrib.add(night ~/ 2),
      lastThird: times.maghrib.add(night * 2 ~/ 3),
      nextFajr: nextFajr,
    );
  }

  /// The location's calendar date (midnight).
  final DateTime date;
  final DayTimes times;
  final DateTime duha;
  final DateTime midnight;
  final DateTime lastThird;

  /// The next day's Fajr (the end of this prayer day).
  final DateTime nextFajr;

  List<PrayerMomentTime> get moments => [
    PrayerMomentTime(PrayerMoment.fajr, times.fajr),
    PrayerMomentTime(PrayerMoment.sunrise, times.sunrise),
    PrayerMomentTime(PrayerMoment.duha, duha),
    PrayerMomentTime(PrayerMoment.dhuhr, times.dhuhr),
    PrayerMomentTime(PrayerMoment.asr, times.asr),
    PrayerMomentTime(PrayerMoment.maghrib, times.maghrib),
    PrayerMomentTime(PrayerMoment.isha, times.isha),
    PrayerMomentTime(PrayerMoment.midnight, midnight),
    PrayerMomentTime(PrayerMoment.lastThird, lastThird),
  ];

  DateTime timeOf(PrayerMoment m) => switch (m) {
    PrayerMoment.fajr => times.fajr,
    PrayerMoment.sunrise => times.sunrise,
    PrayerMoment.duha => duha,
    PrayerMoment.dhuhr => times.dhuhr,
    PrayerMoment.asr => times.asr,
    PrayerMoment.maghrib => times.maghrib,
    PrayerMoment.isha => times.isha,
    PrayerMoment.midnight => midnight,
    PrayerMoment.lastThird => lastThird,
  };

  /// Whether [now] lies inside this prayer day (its Fajr up to the next
  /// Fajr).
  bool contains(DateTime now) => !now.isBefore(times.fajr) && now.isBefore(nextFajr);

  /// The moment whose period contains [now] (the last one already begun),
  /// or null when [now] is outside this prayer day.
  PrayerMoment? currentAt(DateTime now) {
    if (!contains(now)) return null;
    PrayerMoment? current;
    for (final m in moments) {
      if (!now.isBefore(m.at)) current = m.moment;
    }
    return current;
  }

  MomentStatus statusOf(PrayerMoment m, DateTime now) {
    final current = currentAt(now);
    if (current == m) return MomentStatus.current;
    return timeOf(m).isAfter(now) ? MomentStatus.upcoming : MomentStatus.past;
  }

  /// The next moment still ahead of [now] within this prayer day.
  PrayerMomentTime? nextAt(DateTime now) {
    for (final m in moments) {
      if (m.at.isAfter(now)) return m;
    }
    return null;
  }
}

/// The next obligatory prayer after [now] (crossing into tomorrow).
({Prayer prayer, DateTime at}) nextObligatoryPrayer(PrayerSchedule schedule, DateTime now) {
  final w = schedule.windowAt(now);
  return (prayer: w.nextPrayer, at: w.nextPrayerAt);
}
