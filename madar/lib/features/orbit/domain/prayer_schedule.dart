import 'package:adhan_dart/adhan_dart.dart' as adhan;

import '../../../core/domain/enums.dart';

/// Calculation settings (stored encrypted in KeyValues `prayer.settings`).
class PrayerSettings {
  const PrayerSettings({
    this.latitude = 31.9539,
    this.longitude = 35.9106,
    this.cityName,
    this.fajrAngle = 18,
    this.ishaAngle = 18,
    this.hanafiAsr = false,
    this.adjustmentsMin = const {},
    this.useJordanPreset = true,
  });

  /// Default location: Amman (the brief's default region, Jordan). Replaced by
  /// GPS or a manually chosen city in Phase 2.
  final double latitude;
  final double longitude;
  final String? cityName;
  final double fajrAngle;
  final double ishaAngle;
  final bool hanafiAsr;

  /// Per-prayer manual offsets in minutes (keys: fajr, sunrise, dhuhr, asr,
  /// maghrib, isha).
  final Map<String, int> adjustmentsMin;

  /// Use the Jordanian Awqaf preset (18°/18°, Maghrib +5 min) as the base.
  final bool useJordanPreset;

  Map<String, Object?> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'cityName': cityName,
        'fajrAngle': fajrAngle,
        'ishaAngle': ishaAngle,
        'hanafiAsr': hanafiAsr,
        'adjustmentsMin': adjustmentsMin,
        'useJordanPreset': useJordanPreset,
      };

  factory PrayerSettings.fromJson(Map<String, Object?> j) {
    const d = PrayerSettings();
    double n(Object? v, double fb) => v is num ? v.toDouble() : fb;
    final adj = <String, int>{};
    final raw = j['adjustmentsMin'];
    if (raw is Map) {
      for (final e in raw.entries) {
        if (e.value is num) adj['${e.key}'] = (e.value as num).round();
      }
    }
    return PrayerSettings(
      latitude: n(j['latitude'], d.latitude),
      longitude: n(j['longitude'], d.longitude),
      cityName: j['cityName'] as String?,
      fajrAngle: n(j['fajrAngle'], d.fajrAngle),
      ishaAngle: n(j['ishaAngle'], d.ishaAngle),
      hanafiAsr: j['hanafiAsr'] as bool? ?? d.hanafiAsr,
      adjustmentsMin: adj,
      useJordanPreset: j['useJordanPreset'] as bool? ?? d.useJordanPreset,
    );
  }
}

/// The six moments of a day (five prayers + sunrise), local time.
class DayTimes {
  const DayTimes({
    required this.day,
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
  });

  final DateTime day;
  final DateTime fajr, sunrise, dhuhr, asr, maghrib, isha;

  List<(Prayer, DateTime)> get obligatory => [
        (Prayer.fajr, fajr),
        (Prayer.dhuhr, dhuhr),
        (Prayer.asr, asr),
        (Prayer.maghrib, maghrib),
        (Prayer.isha, isha),
      ];
}

/// Where "now" sits in the prayer-anchored day.
class WindowState {
  const WindowState({
    required this.window,
    required this.start,
    required this.end,
    required this.nextPrayer,
    required this.nextPrayerAt,
  });

  final PrayerWindow window;
  final DateTime start;
  final DateTime end;

  /// The next obligatory prayer (sunrise is not a prayer).
  final Prayer nextPrayer;
  final DateTime nextPrayerAt;

  double progressAt(DateTime now) {
    final total = end.difference(start).inMilliseconds;
    if (total <= 0) return 0;
    return (now.difference(start).inMilliseconds / total).clamp(0.0, 1.0);
  }
}

/// Offline prayer times (adhan_dart; Jordanian defaults) and the six windows
/// of the day: after Fajr (Fajr→sunrise), Duha (sunrise→Dhuhr), Dhuhr→Asr,
/// Asr→Maghrib, Maghrib→Isha, after Isha (Isha→next Fajr).
class PrayerSchedule {
  PrayerSchedule(this.settings);

  final PrayerSettings settings;
  final Map<DateTime, DayTimes> _cache = {};

  adhan.CalculationParameters _params() {
    final p = settings.useJordanPreset
        ? adhan.CalculationMethodParameters.jordan()
        : adhan.CalculationMethodParameters.other();
    p.fajrAngle = settings.fajrAngle;
    p.ishaAngle = settings.ishaAngle;
    p.madhab = settings.hanafiAsr ? adhan.Madhab.hanafi : adhan.Madhab.shafi;
    for (final e in settings.adjustmentsMin.entries) {
      final prayer = adhan.Prayer.values.where((pr) => pr.name == e.key).firstOrNull;
      if (prayer != null) p.adjustments[prayer] = e.value;
    }
    return p;
  }

  /// Times for the local calendar day containing [date].
  DayTimes timesFor(DateTime date) {
    final key = DateTime(date.year, date.month, date.day);
    return _cache.putIfAbsent(key, () {
      final pt = adhan.PrayerTimes(
        date: DateTime(key.year, key.month, key.day, 12),
        coordinates: adhan.Coordinates(settings.latitude, settings.longitude),
        calculationParameters: _params(),
        precision: true,
      );
      return DayTimes(
        day: key,
        fajr: pt.fajr.toLocal(),
        sunrise: pt.sunrise.toLocal(),
        dhuhr: pt.dhuhr.toLocal(),
        asr: pt.asr.toLocal(),
        maghrib: pt.maghrib.toLocal(),
        isha: pt.isha.toLocal(),
      );
    });
  }

  /// The current window and the next obligatory prayer.
  WindowState windowAt(DateTime now) {
    final today = timesFor(now);
    final tomorrow = timesFor(now.add(const Duration(days: 1)));
    final yesterday = timesFor(now.subtract(const Duration(days: 1)));
    if (now.isBefore(today.fajr)) {
      return WindowState(
        window: PrayerWindow.isha,
        start: yesterday.isha,
        end: today.fajr,
        nextPrayer: Prayer.fajr,
        nextPrayerAt: today.fajr,
      );
    }
    if (now.isBefore(today.sunrise)) {
      return WindowState(
        window: PrayerWindow.fajr,
        start: today.fajr,
        end: today.sunrise,
        nextPrayer: Prayer.dhuhr,
        nextPrayerAt: today.dhuhr,
      );
    }
    if (now.isBefore(today.dhuhr)) {
      return WindowState(
        window: PrayerWindow.duha,
        start: today.sunrise,
        end: today.dhuhr,
        nextPrayer: Prayer.dhuhr,
        nextPrayerAt: today.dhuhr,
      );
    }
    if (now.isBefore(today.asr)) {
      return WindowState(
        window: PrayerWindow.dhuhr,
        start: today.dhuhr,
        end: today.asr,
        nextPrayer: Prayer.asr,
        nextPrayerAt: today.asr,
      );
    }
    if (now.isBefore(today.maghrib)) {
      return WindowState(
        window: PrayerWindow.asr,
        start: today.asr,
        end: today.maghrib,
        nextPrayer: Prayer.maghrib,
        nextPrayerAt: today.maghrib,
      );
    }
    if (now.isBefore(today.isha)) {
      return WindowState(
        window: PrayerWindow.maghrib,
        start: today.maghrib,
        end: today.isha,
        nextPrayer: Prayer.isha,
        nextPrayerAt: today.isha,
      );
    }
    return WindowState(
      window: PrayerWindow.isha,
      start: today.isha,
      end: tomorrow.fajr,
      nextPrayer: Prayer.fajr,
      nextPrayerAt: tomorrow.fajr,
    );
  }

  /// Obligatory prayers whose time started within the last [days] days up to
  /// [now] (feeds the Faith planet score).
  int obligatoryStartedInLast(DateTime now, {int days = 7}) {
    var count = 0;
    final from = now.subtract(Duration(days: days));
    for (var i = 0; i <= days; i++) {
      final t = timesFor(now.subtract(Duration(days: i)));
      for (final (_, at) in t.obligatory) {
        if (!at.isAfter(now) && at.isAfter(from)) count++;
      }
    }
    return count;
  }

  /// Fraction of the 24-hour dial (0 = local midnight, 0.5 = noon).
  static double dialFraction(DateTime t) =>
      (t.hour * 3600 + t.minute * 60 + t.second + t.millisecond / 1000) / 86400.0;
}
