import 'package:flutter/widgets.dart';

import '../../../../core/astro/astronomy.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../domain/prayer_schedule.dart';
import '../../domain/scene_snapshot.dart' show PrayerState;
import 'astrolabe_geometry.dart';
import 'astrolabe_paths.dart';

/// Where the sun is, for the rete and the plate.
@immutable
class AstrolabeSky {
  const AstrolabeSky({
    required this.sunFraction,
    required this.solarFraction,
    required this.sunRaDeg,
    required this.sunDecDeg,
    this.latitude = 31.9539,
  });

  /// The real sun at [now] over ([latitude], [longitude]); the sun marker
  /// follows the local clock so it meets each prayer pointer exactly at that
  /// prayer's time.
  factory AstrolabeSky.at(DateTime now, {double latitude = 31.9539, double longitude = 35.9106}) {
    final sun = Astro.sun(now, latitude: latitude, longitude: longitude);
    return AstrolabeSky(
      sunFraction: PrayerSchedule.dialFraction(now),
      solarFraction: sun.solarDayFraction,
      sunRaDeg: sun.rightAscension,
      sunDecDeg: sun.declination,
      latitude: latitude,
    );
  }

  /// Dial fraction of the sun marker (local clock; 0 = midnight).
  final double sunFraction;

  /// Apparent solar day fraction at the same instant (0.5 = solar noon).
  final double solarFraction;

  /// Sun's right ascension / declination (degrees) – its place on the
  /// rete's ecliptic ring.
  final double sunRaDeg;
  final double sunDecDeg;

  /// Plate latitude (horizon, twilight line and almucantars).
  final double latitude;

  /// Rotation of the rete (canvas radians).
  double get reteRotation => AstrolabeProjection.reteRotation(sunFraction: sunFraction, sunRaDeg: sunRaDeg);

  /// Rotation of the plate engraving (clock minus solar time).
  double get plateRotation =>
      AstrolabeProjection.plateRotation(clockFraction: sunFraction, solarFraction: solarFraction);

  /// Sun marker position in rete-local unit coordinates.
  Offset get sunReteLocal => AstrolabeProjection.reteLocal(sunRaDeg, sunDecDeg);

  @override
  bool operator ==(Object other) =>
      other is AstrolabeSky &&
      other.sunFraction == sunFraction &&
      other.solarFraction == solarFraction &&
      other.sunRaDeg == sunRaDeg &&
      other.sunDecDeg == sunDecDeg &&
      other.latitude == latitude;

  @override
  int get hashCode => Object.hash(sunFraction, solarFraction, sunRaDeg, sunDecDeg, latitude);
}

/// Localised text engraved on the astrolabe (prayer names, numerals,
/// countdown) – built from [L10n] and the app's [MadarFormatter] so digits
/// follow the digit setting.
@immutable
class AstrolabeLabels {
  const AstrolabeLabels(this.l10n, this.formatter);

  factory AstrolabeLabels.of(BuildContext context) => AstrolabeLabels(L10n.of(context), MadarFormatter.of(context));

  final L10n l10n;
  final MadarFormatter formatter;

  bool get arabic => formatter.isArabic;
  bool get arabicIndic => formatter.arabicIndic;
  TextDirection get textDirection => arabic ? TextDirection.rtl : TextDirection.ltr;

  String prayerName(Prayer p) => switch (p) {
    Prayer.fajr => l10n.prayerFajr,
    Prayer.dhuhr => l10n.prayerDhuhr,
    Prayer.asr => l10n.prayerAsr,
    Prayer.maghrib => l10n.prayerMaghrib,
    Prayer.isha => l10n.prayerIsha,
    _ => l10n.prayerSunrise,
  };

  String windowName(PrayerWindow w) => switch (w) {
    PrayerWindow.fajr => l10n.windowFajr,
    PrayerWindow.duha => l10n.windowDuha,
    PrayerWindow.dhuhr => l10n.windowDhuhr,
    PrayerWindow.asr => l10n.windowAsr,
    PrayerWindow.maghrib => l10n.windowMaghrib,
    PrayerWindow.isha => l10n.windowIsha,
    PrayerWindow.anytime => l10n.windowAnytime,
  };

  /// Traditional name of a rete star.
  String starName(ReteStarId s) => switch (s) {
    ReteStarId.denebKaitos => l10n.astrolabeStarDenebKaitos,
    ReteStarId.menkar => l10n.astrolabeStarMenkar,
    ReteStarId.aldebaran => l10n.astrolabeStarAldebaran,
    ReteStarId.rigel => l10n.astrolabeStarRigel,
    ReteStarId.betelgeuse => l10n.astrolabeStarBetelgeuse,
    ReteStarId.sirius => l10n.astrolabeStarSirius,
    ReteStarId.procyon => l10n.astrolabeStarProcyon,
    ReteStarId.alphard => l10n.astrolabeStarAlphard,
    ReteStarId.regulus => l10n.astrolabeStarRegulus,
    ReteStarId.denebola => l10n.astrolabeStarDenebola,
    ReteStarId.spica => l10n.astrolabeStarSpica,
    ReteStarId.arcturus => l10n.astrolabeStarArcturus,
    ReteStarId.unukalhai => l10n.astrolabeStarUnukalhai,
    ReteStarId.rasAlhague => l10n.astrolabeStarRasAlhague,
    ReteStarId.altair => l10n.astrolabeStarAltair,
    ReteStarId.denebAlgedi => l10n.astrolabeStarDenebAlgedi,
    ReteStarId.markab => l10n.astrolabeStarMarkab,
  };

  /// Zodiac sign [index] (0 = Aries, starting at the vernal equinox).
  String zodiacName(int index) => switch (index % 12) {
    0 => l10n.astrolabeZodiacAries,
    1 => l10n.astrolabeZodiacTaurus,
    2 => l10n.astrolabeZodiacGemini,
    3 => l10n.astrolabeZodiacCancer,
    4 => l10n.astrolabeZodiacLeo,
    5 => l10n.astrolabeZodiacVirgo,
    6 => l10n.astrolabeZodiacLibra,
    7 => l10n.astrolabeZodiacScorpio,
    8 => l10n.astrolabeZodiacSagittarius,
    9 => l10n.astrolabeZodiacCapricorn,
    10 => l10n.astrolabeZodiacAquarius,
    _ => l10n.astrolabeZodiacPisces,
  };

  /// An hour numeral of the limb scale.
  String numeral(int n) => formatter.localizeDigits('$n');

  /// A stopwatch clock `1:23:05` (hours unpadded; minutes/seconds padded).
  static String clockOf(Duration d) {
    final v = d.isNegative ? Duration.zero : d;
    final h = v.inHours;
    final m = v.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = v.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  /// «العصر بعد ١:٢٣:٠٥» / "Asr in 1:23:05".
  String countdown(Prayer next, Duration remaining) {
    if (remaining <= Duration.zero) return l10n.astrolabeCountdownNow(prayerName(next));
    final clock = formatter.localizeDigits(clockOf(remaining));
    return l10n.astrolabeCountdown(prayerName(next), BidiIsolate.ltr(clock));
  }

  /// The countdown for screen readers, in words («العصر بعد ٣ ساعات و٢١
  /// دقيقة»), never a clock read digit by digit.
  String spokenCountdown(Prayer next, Duration remaining) {
    if (remaining <= Duration.zero) return l10n.astrolabeCountdownNow(prayerName(next));
    final rounded = Duration(minutes: (remaining.inSeconds / 60).ceil());
    return l10n.astrolabeCountdown(prayerName(next), formatter.formatDurationWords(l10n, rounded));
  }

  /// The countdown split in two bands for a small hub: the engraved clock
  /// «١:٢٣:٠٥» across the top and «حتى العصر» across the bottom (at the
  /// prayer's very moment: the prayer's name, then «حان وقتها»).
  ({String top, String bottom}) countdownBands(Prayer next, Duration remaining) {
    if (remaining <= Duration.zero) return (top: prayerName(next), bottom: l10n.astrolabeCountdownNowBand);
    return (top: formatter.localizeDigits(clockOf(remaining)), bottom: l10n.astrolabeCountdownUntil(prayerName(next)));
  }

  String time(DateTime t) => formatter.formatTime(t);

  @override
  bool operator ==(Object other) =>
      other is AstrolabeLabels &&
      other.l10n.localeName == l10n.localeName &&
      other.formatter.languageCode == formatter.languageCode &&
      other.formatter.digits == formatter.digits;

  @override
  int get hashCode => Object.hash(l10n.localeName, formatter.languageCode, formatter.digits);
}

/// Everything the astrolabe shows. Immutable: push a new one into the
/// [AstrolabeController] (or the layer) when anything changes – typically
/// once a second for the countdown.
@immutable
class AstrolabeState {
  const AstrolabeState({
    required this.times,
    required this.window,
    required this.now,
    required this.sky,
    required this.labels,
    this.prayed = const {},
    this.missed = const {},
    this.balance = 1,
    this.countdownText,
  });

  /// Builds the state from the offline prayer schedule at [now].
  factory AstrolabeState.fromSchedule({
    required PrayerSchedule schedule,
    required DateTime now,
    required AstrolabeLabels labels,
    Set<Prayer> prayed = const {},
    Set<Prayer> missed = const {},
    double balance = 1,
  }) {
    final today = schedule.timesFor(now);
    // Before Fajr the prayer day is still yesterday's (its Isha is running).
    final times = now.isBefore(today.fajr) ? schedule.timesFor(now.subtract(const Duration(days: 1))) : today;
    return AstrolabeState(
      times: times,
      window: schedule.windowAt(now),
      now: now,
      sky: AstrolabeSky.at(now, latitude: schedule.settings.latitude, longitude: schedule.settings.longitude),
      labels: labels,
      prayed: prayed,
      missed: missed,
      balance: balance,
    );
  }

  /// Builds the state from the scene snapshot's prayer state: prayed / late
  /// / made-up prayers are lit, prayers logged as missed are dimmed.
  factory AstrolabeState.fromPrayerState(
    PrayerState prayer, {
    required DateTime now,
    required AstrolabeLabels labels,
    double balance = 1,
  }) {
    final calendarDay = DateTime(now.year, now.month, now.day);
    // Before Fajr the pointers belong to the prayer day that is still running.
    final times = prayer.prayerDay == calendarDay
        ? prayer.times
        : PrayerSchedule(prayer.settings).timesFor(prayer.prayerDay);
    return AstrolabeState(
      times: times,
      window: prayer.window,
      now: now,
      sky: AstrolabeSky.at(now, latitude: prayer.settings.latitude, longitude: prayer.settings.longitude),
      labels: labels,
      prayed: prayer.lit,
      missed: {
        for (final e in prayer.logged.entries)
          if (e.value == PrayerStatus.missed) e.key,
      },
      balance: balance,
    );
  }

  /// The prayer day's times (the day whose Fajr began most recently).
  final DayTimes times;

  /// The current window (lit arc) and the next prayer (countdown).
  final WindowState window;
  final DateTime now;
  final AstrolabeSky sky;
  final AstrolabeLabels labels;

  /// Obligatory prayers logged today.
  final Set<Prayer> prayed;

  /// Prayers explicitly logged as missed (a prayer whose time ended without
  /// a log counts as missed too).
  final Set<Prayer> missed;

  /// Overall life balance 0..1 (core star brightness, brass polish).
  final double balance;

  /// Overrides the engraved countdown (otherwise derived from [window]).
  final String? countdownText;

  String get countdown => countdownText ?? labels.countdown(window.nextPrayer, window.nextPrayerAt.difference(now));

  /// [countdown] for screen readers (see [AstrolabeLabels.spokenCountdown]).
  String get spokenCountdown =>
      countdownText ?? labels.spokenCountdown(window.nextPrayer, window.nextPrayerAt.difference(now));

  /// [countdown] in two bands (clock on top, the prayer below) for a hub too
  /// small to carry it in one line; an overriding [countdownText] stays whole.
  ({String top, String bottom}) get countdownBands {
    final override = countdownText;
    if (override != null) return (top: override, bottom: '');
    return labels.countdownBands(window.nextPrayer, window.nextPrayerAt.difference(now));
  }

  AstrolabePrayerStatus statusOf(Prayer p) =>
      AstrolabeGeometry.statusOf(p, times, now, prayed: prayed, missed: missed, nextFajr: nextFajr);

  /// The next day's real Fajr (Isha's end) once Isha's window runs.
  DateTime? get nextFajr => window.nextPrayer == Prayer.fajr ? window.nextPrayerAt : null;

  DateTime timeOf(Prayer p) => AstrolabeGeometry.timeOf(p, times);

  double fractionOf(Prayer p) => PrayerSchedule.dialFraction(timeOf(p));

  /// Dial fractions of the five obligatory prayers.
  Map<Prayer, double> get fractions => {for (final p in AstrolabeGeometry.prayers) p: fractionOf(p)};

  int get prayedCount => AstrolabeGeometry.prayers.where(prayed.contains).length;

  AstrolabeState copyWith({
    DayTimes? times,
    WindowState? window,
    DateTime? now,
    AstrolabeSky? sky,
    AstrolabeLabels? labels,
    Set<Prayer>? prayed,
    Set<Prayer>? missed,
    double? balance,
    String? countdownText,
  }) => AstrolabeState(
    times: times ?? this.times,
    window: window ?? this.window,
    now: now ?? this.now,
    sky: sky ?? this.sky,
    labels: labels ?? this.labels,
    prayed: prayed ?? this.prayed,
    missed: missed ?? this.missed,
    balance: balance ?? this.balance,
    countdownText: countdownText ?? this.countdownText,
  );
}
