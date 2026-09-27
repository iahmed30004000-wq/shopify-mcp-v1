import 'package:flutter/foundation.dart';

import '../../../core/domain/enums.dart';

/// The start times of the six prayer windows of one day, as offsets from
/// local midnight, and the window arithmetic the home screen needs.
///
/// Phase 0 ships [PrayerDayTimes.placeholder] – fixed, generic times that
/// are clearly labelled as approximate in the UI. Phase 2 replaces it with
/// computed times (location + calculation method) by overriding
/// `prayerDayProvider`; nothing else changes.
@immutable
class PrayerDayTimes {
  const PrayerDayTimes({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    this.isPlaceholder = false,
  });

  /// Generic mid-latitude times (not tied to any place). Shown as
  /// "approximate" until real prayer times arrive in Phase 2.
  static const placeholder = PrayerDayTimes(
    fajr: Duration(hours: 4, minutes: 45),
    sunrise: Duration(hours: 6, minutes: 10),
    dhuhr: Duration(hours: 12, minutes: 25),
    asr: Duration(hours: 15, minutes: 50),
    maghrib: Duration(hours: 18, minutes: 30),
    isha: Duration(hours: 19, minutes: 50),
    isPlaceholder: true,
  );

  final Duration fajr, sunrise, dhuhr, asr, maghrib, isha;

  /// True for [placeholder]: the UI must say the times are approximate.
  final bool isPlaceholder;

  /// The six windows in day order (anytime excluded).
  static const List<PrayerWindow> windows = [
    PrayerWindow.fajr,
    PrayerWindow.duha,
    PrayerWindow.dhuhr,
    PrayerWindow.asr,
    PrayerWindow.maghrib,
    PrayerWindow.isha,
  ];

  /// The five obligatory prayers in day order.
  static const List<Prayer> obligatory = [Prayer.fajr, Prayer.dhuhr, Prayer.asr, Prayer.maghrib, Prayer.isha];

  /// Offset from midnight at which [window] begins ([PrayerWindow.anytime]
  /// → midnight).
  Duration startOf(PrayerWindow window) => switch (window) {
    PrayerWindow.fajr => fajr,
    PrayerWindow.duha => sunrise,
    PrayerWindow.dhuhr => dhuhr,
    PrayerWindow.asr => asr,
    PrayerWindow.maghrib => maghrib,
    PrayerWindow.isha => isha,
    PrayerWindow.anytime => Duration.zero,
  };

  /// Offset from midnight at which [window] ends. After Isha runs past
  /// midnight, so its end is `fajr + 24h`.
  Duration endOf(PrayerWindow window) => switch (window) {
    PrayerWindow.fajr => sunrise,
    PrayerWindow.duha => dhuhr,
    PrayerWindow.dhuhr => asr,
    PrayerWindow.asr => maghrib,
    PrayerWindow.maghrib => isha,
    PrayerWindow.isha => fajr + const Duration(days: 1),
    PrayerWindow.anytime => const Duration(days: 1),
  };

  /// Time of an obligatory [prayer] as an offset from midnight.
  Duration timeOf(Prayer prayer) => switch (prayer) {
    Prayer.fajr => fajr,
    Prayer.dhuhr => dhuhr,
    Prayer.asr => asr,
    Prayer.maghrib => maghrib,
    Prayer.isha => isha,
    _ => startOf(PrayerWindow.duha),
  };

  /// The window containing [time] (local clock).
  PrayerWindow windowAt(DateTime time) {
    final t = sinceMidnight(time);
    if (t < fajr || t >= isha) return PrayerWindow.isha;
    if (t < sunrise) return PrayerWindow.fajr;
    if (t < dhuhr) return PrayerWindow.duha;
    if (t < asr) return PrayerWindow.dhuhr;
    if (t < maghrib) return PrayerWindow.asr;
    return PrayerWindow.maghrib;
  }

  /// The calendar day a moment belongs to in the prayer-anchored day: the
  /// small hours before Fajr still belong to yesterday's "after Isha".
  DateTime prayerDayOf(DateTime time) {
    final day = dateOnly(time);
    return sinceMidnight(time) < fajr ? day.subtract(const Duration(days: 1)) : day;
  }

  /// When [window] starts on the prayer day [day].
  DateTime startOn(PrayerWindow window, DateTime day) => _at(dateOnly(day), startOf(window));

  /// When [window] ends on the prayer day [day].
  DateTime endOn(PrayerWindow window, DateTime day) => _at(dateOnly(day), endOf(window));

  /// 0..1 progress of [time] through its window.
  double progressAt(DateTime time) {
    final w = windowAt(time);
    final day = prayerDayOf(time);
    final start = startOn(w, day);
    final end = endOn(w, day);
    final total = end.difference(start).inMilliseconds;
    if (total <= 0) return 0;
    return (time.difference(start).inMilliseconds / total).clamp(0.0, 1.0);
  }

  /// The next obligatory prayer strictly after [time] and when it starts.
  ({Prayer prayer, DateTime at}) nextPrayer(DateTime time) {
    final day = dateOnly(time);
    for (final p in obligatory) {
      final at = _at(day, timeOf(p));
      if (at.isAfter(time)) return (prayer: p, at: at);
    }
    return (prayer: Prayer.fajr, at: _at(day.add(const Duration(days: 1)), fajr));
  }

  /// Fraction of the 24-hour dial (0 = midnight, 0.5 = noon) for an offset.
  static double dialFraction(Duration sinceMidnight) =>
      (sinceMidnight.inMilliseconds / Duration.millisecondsPerDay) % 1.0;

  static Duration sinceMidnight(DateTime t) =>
      Duration(hours: t.hour, minutes: t.minute, seconds: t.second, milliseconds: t.millisecond);

  static DateTime dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);

  // DateTime(y, m, d, h, min) normalises overflow (e.g. 24h+ for after Isha)
  // and stays on local wall-clock time across DST changes.
  static DateTime _at(DateTime day, Duration offset) =>
      DateTime(day.year, day.month, day.day, 0, 0, 0, offset.inMilliseconds);

  @override
  bool operator ==(Object other) =>
      other is PrayerDayTimes &&
      other.fajr == fajr &&
      other.sunrise == sunrise &&
      other.dhuhr == dhuhr &&
      other.asr == asr &&
      other.maghrib == maghrib &&
      other.isha == isha &&
      other.isPlaceholder == isPlaceholder;

  @override
  int get hashCode => Object.hash(fajr, sunrise, dhuhr, asr, maghrib, isha, isPlaceholder);
}
