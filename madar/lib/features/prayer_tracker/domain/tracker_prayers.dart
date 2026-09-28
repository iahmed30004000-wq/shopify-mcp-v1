/// Which prayers the tracker follows and how they group: the five
/// obligatory prayers, the sunnah rawatib grouped with their fard, and the
/// free-standing nawafil (Duha, Witr, Qiyam). Pure Dart.
library;

import '../../../core/domain/enums.dart';

/// How many rak'ahs of a sunnah rātibah are prayed before and after its fard.
typedef RakahPlan = ({int before, int after});

abstract final class TrackerPrayers {
  /// The five obligatory prayers in the order of the day.
  static const obligatory = <Prayer>[Prayer.fajr, Prayer.dhuhr, Prayer.asr, Prayer.maghrib, Prayer.isha];

  /// The confirmed sunnah rawatib (twelve rak'ahs a day).
  static const rawatib = <Prayer>[Prayer.sunnahFajr, Prayer.sunnahDhuhr, Prayer.sunnahMaghrib, Prayer.sunnahIsha];

  /// Voluntary prayers that stand on their own.
  static const nawafil = <Prayer>[Prayer.duha, Prayer.witr, Prayer.qiyam];

  /// Everything voluntary the tracker follows.
  static const voluntary = <Prayer>[...rawatib, ...nawafil];

  static const _sunnahOf = <Prayer, Prayer>{
    Prayer.fajr: Prayer.sunnahFajr,
    Prayer.dhuhr: Prayer.sunnahDhuhr,
    Prayer.maghrib: Prayer.sunnahMaghrib,
    Prayer.isha: Prayer.sunnahIsha,
  };

  static const _plans = <Prayer, RakahPlan>{
    Prayer.sunnahFajr: (before: 2, after: 0),
    Prayer.sunnahDhuhr: (before: 4, after: 2),
    Prayer.sunnahMaghrib: (before: 0, after: 2),
    Prayer.sunnahIsha: (before: 0, after: 2),
  };

  static bool isObligatory(Prayer p) => obligatory.contains(p);

  static bool isVoluntary(Prayer p) => !isObligatory(p);

  /// The sunnah rātibah grouped with [fard] (Asr has none).
  static Prayer? sunnahOf(Prayer fard) => _sunnahOf[fard];

  /// The fard a sunnah rātibah belongs to.
  static Prayer? fardOf(Prayer sunnah) {
    for (final e in _sunnahOf.entries) {
      if (e.value == sunnah) return e.key;
    }
    return null;
  }

  /// Rak'ahs of a sunnah rātibah before / after its fard (null otherwise).
  static RakahPlan? rakahOf(Prayer sunnah) => _plans[sunnah];

  /// The groups of the Today view: each fard with its rawatib.
  static List<({Prayer fard, Prayer? sunnah})> get groups => [
    for (final f in obligatory) (fard: f, sunnah: sunnahOf(f)),
  ];
}

extension PrayerStatusCounting on PrayerStatus {
  /// Whether the prayer was actually prayed (on time, late or made up).
  bool get counts => this != PrayerStatus.missed;
}

/// What a tap on an obligatory prayer does: no log → prayed on time → late
/// → missed → no log. A made-up prayer (qada) goes back to missed, where the
/// qada ledger picks it up again.
abstract final class StatusCycle {
  static PrayerStatus? next(PrayerStatus? current) => switch (current) {
    null => PrayerStatus.prayed,
    PrayerStatus.prayed => PrayerStatus.late,
    PrayerStatus.late => PrayerStatus.missed,
    PrayerStatus.missed => null,
    PrayerStatus.qada => PrayerStatus.missed,
  };
}
