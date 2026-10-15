import 'package:flutter/material.dart';

import '../../../core/domain/enums.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../orbit/domain/prayer_schedule.dart';
import '../domain/cities.dart';
import '../domain/hijri.dart';
import '../domain/location.dart';
import '../domain/prayer_clock.dart';
import '../domain/prayer_day.dart';
import '../domain/time_zones.dart';

/// Localised names and formatted values of the prayer feature.
extension PrayerLabels on L10n {
  String momentName(PrayerMoment m, {bool friday = false}) => switch (m) {
    PrayerMoment.fajr => ptFajr,
    PrayerMoment.sunrise => ptSunrise,
    PrayerMoment.duha => ptDuha,
    PrayerMoment.dhuhr => friday ? ptJumuah : ptDhuhr,
    PrayerMoment.asr => ptAsr,
    PrayerMoment.maghrib => ptMaghrib,
    PrayerMoment.isha => ptIsha,
    PrayerMoment.midnight => ptMidnight,
    PrayerMoment.lastThird => ptLastThird,
  };

  String? momentHint(PrayerMoment m) => switch (m) {
    PrayerMoment.sunrise => ptSunriseHint,
    PrayerMoment.duha => ptDuhaHint,
    PrayerMoment.midnight => ptMidnightHint,
    PrayerMoment.lastThird => ptLastThirdHint,
    _ => null,
  };

  String prayerName(Prayer p, {bool friday = false}) => momentName(PrayerMoment.ofPrayer(p), friday: friday);

  String hijriMonth(int month) => switch (month) {
    1 => ptHijriMonth1,
    2 => ptHijriMonth2,
    3 => ptHijriMonth3,
    4 => ptHijriMonth4,
    5 => ptHijriMonth5,
    6 => ptHijriMonth6,
    7 => ptHijriMonth7,
    8 => ptHijriMonth8,
    9 => ptHijriMonth9,
    10 => ptHijriMonth10,
    11 => ptHijriMonth11,
    _ => ptHijriMonth12,
  };

  /// «١٦ ربيع الآخر ١٤٤٨ هـ» / "16 Rabiʿ al-Akhir 1448 AH".
  String hijriDate(HijriDate h, MadarFormatter fmt) =>
      ptHijriDate(fmt.formatInt(h.day, grouping: false), hijriMonth(h.month), fmt.formatInt(h.year, grouping: false));

  /// «١٦ ربيع الآخر».
  String hijriDayMonth(HijriDate h, MadarFormatter fmt) =>
      ptHijriDayMonth(fmt.formatInt(h.day, grouping: false), hijriMonth(h.month));

  String methodName(PrayerMethod m) => switch (m) {
    PrayerMethod.jordan => ptMethodJordan,
    PrayerMethod.muslimWorldLeague => ptMethodMuslimWorldLeague,
    PrayerMethod.ummAlQura => ptMethodUmmAlQura,
    PrayerMethod.egyptian => ptMethodEgyptian,
    PrayerMethod.karachi => ptMethodKarachi,
    PrayerMethod.northAmerica => ptMethodNorthAmerica,
    PrayerMethod.dubai => ptMethodDubai,
    PrayerMethod.kuwait => ptMethodKuwait,
    PrayerMethod.qatar => ptMethodQatar,
    PrayerMethod.turkiye => ptMethodTurkiye,
    PrayerMethod.singapore => ptMethodSingapore,
    PrayerMethod.tehran => ptMethodTehran,
    PrayerMethod.gulfRegion => ptMethodGulfRegion,
    PrayerMethod.moonsightingCommittee => ptMethodMoonsightingCommittee,
    PrayerMethod.algerian => ptMethodAlgerian,
    PrayerMethod.morocco => ptMethodMorocco,
    PrayerMethod.tunisia => ptMethodTunisia,
    PrayerMethod.france => ptMethodFrance,
    PrayerMethod.russia => ptMethodRussia,
    PrayerMethod.indonesian => ptMethodIndonesian,
    PrayerMethod.jafari => ptMethodJafari,
    PrayerMethod.custom => ptMethodCustom,
  };

  String highLatitudeName(HighLatitudeMode m) => switch (m) {
    HighLatitudeMode.auto => ptHighLatAuto,
    HighLatitudeMode.middleOfTheNight => ptHighLatMiddle,
    HighLatitudeMode.seventhOfTheNight => ptHighLatSeventh,
    HighLatitudeMode.twilightAngle => ptHighLatAngle,
  };

  /// "Fajr 18° · Isha 18° · Sunrise −7 min · Maghrib +7 min" (Arabic joins
  /// with «،»: a middle dot beside Arabic-Indic digits reads as ٠).
  String methodSummary(PrayerSettings s, MadarFormatter fmt) {
    final p = s.method == PrayerMethod.custom ? null : s.method.parameters();
    // Custom angles keep the offsets / Maghrib angle of the preset they
    // started from (see PrayerSettings.customBase).
    final offsets = p ?? s.customBase?.parameters();
    final parts = <String>[];
    final fajr = p?.fajrAngle ?? s.fajrAngle;
    parts.add(ptSummaryAngle(ptFajr, degrees(fajr, fmt)));
    final interval = p != null ? (p.ishaInterval ?? 0) : (s.ishaIntervalMin ?? 0);
    if (interval > 0) {
      parts.add(ptSummaryIshaInterval(fmt.formatInt(interval)));
      if (s.method == PrayerMethod.ummAlQura) parts.add(ptSummaryRamadan(fmt.formatInt(120)));
    } else {
      parts.add(ptSummaryAngle(ptIsha, degrees(p?.ishaAngle ?? s.ishaAngle, fmt)));
    }
    final maghribAngle = offsets?.maghribAngle;
    if (maghribAngle != null) parts.add(ptSummaryMaghribAngle(degrees(maghribAngle, fmt)));
    if (offsets != null) {
      for (final e in offsets.methodAdjustments.entries) {
        if (e.value == 0) continue;
        final name = switch (e.key.name) {
          'sunrise' => ptSunrise,
          'dhuhr' => ptDhuhr,
          'asr' => ptAsr,
          'maghrib' => ptMaghrib,
          'isha' => ptIsha,
          _ => ptFajr,
        };
        parts.add(ptSummaryOffset(name, signedMinutes(e.value, fmt)));
      }
    }
    // Each part stays on one line ("Maghrib +7 min" never splits); lines
    // break only between parts.
    return parts.map((p) => p.replaceAll(' ', '\u00A0')).join(commonFactSeparator);
  }

  /// "18°" / "١٨٫٥°".
  String degrees(double value, MadarFormatter fmt) => '${fmt.formatNumber(value, maxDecimals: 1)}°';

  /// "+5" / "−٥" / "0" – a true minus sign, isolated left-to-right.
  /// A minute adjustment as a stepper shows it: "+٢ د" / "−5 min", and
  /// «بلا تعديل» / "None" for zero – a lone «٠ د» reads as a dotted «د».
  String adjustmentValue(int minutes, MadarFormatter fmt) =>
      minutes == 0 ? ptNoAdjustment : ptMinutesSigned(signedMinutes(minutes, fmt));

  String signedMinutes(int minutes, MadarFormatter fmt) {
    final n = fmt.formatInt(minutes.abs(), grouping: false);
    final s = minutes > 0 ? '+$n' : (minutes < 0 ? '−$n' : n);
    return BidiIsolate.ltr(s);
  }

  /// The location's display name: "عمّان، الأردن", "قرب عمّان", or the
  /// default marker.
  String placeLabel(PrayerSettings s, String languageCode, {CityDatabase? cities, bool withCountry = true}) {
    final name = s.placeName(languageCode);
    if (s.locationSource == PrayerLocationSource.defaultCity && name == null) {
      return ptLocationDefault(ptDefaultCityName);
    }
    if (name == null) return ptPinnedLocation;
    var label = name;
    if (s.locationSource == PrayerLocationSource.gps && cities != null) {
      final city = cities.byId(s.cityId);
      if (city != null && city.distanceKmTo(s.latitude, s.longitude) > PrayerLocationChanges.nearKm) {
        label = ptLocationNear(name);
      }
    }
    final cc = s.countryCode;
    if (withCountry && cc != null && cities != null) {
      return ptPlaceWithCountry(label, cities.countryName(cc, languageCode));
    }
    return label;
  }

  /// "GMT+3" / "غرينتش +٣" for the zone at [instant].
  String zoneOffset(Duration offset, MadarFormatter fmt) {
    final minutes = offset.inMinutes;
    final sign = minutes < 0 ? '−' : '+';
    final h = minutes.abs() ~/ 60;
    final m = minutes.abs() % 60;
    final raw = m == 0 ? '$h' : '$h:${m.toString().padLeft(2, '0')}';
    return ptZoneOffset(BidiIsolate.ltr('$sign${fmt.localizeDigits(raw)}'));
  }

  /// "Asia/Amman (GMT+3)" style label of the settings' zone.
  String zoneLabel(PrayerSettings s, DateTime instant, MadarFormatter fmt) {
    final zone = MadarTimeZones.find(s.timeZone);
    final offset = MadarTimeZones.offsetAt(instant, zone);
    final name = zone == null ? ptTimeZoneDevice : BidiIsolate.ltr(zone.name.replaceAll('_', ' '));
    return '$name$commonFactSeparator${zoneOffset(offset, fmt)}';
  }
}

/// Icon of each moment (the sun's / moon's place in the sky).
IconData momentIcon(PrayerMoment m) => switch (m) {
  PrayerMoment.fajr => Icons.wb_twilight_rounded,
  PrayerMoment.sunrise => Icons.wb_sunny_outlined,
  PrayerMoment.duha => Icons.light_mode_outlined,
  PrayerMoment.dhuhr => Icons.wb_sunny_rounded,
  PrayerMoment.asr => Icons.brightness_5_rounded,
  PrayerMoment.maghrib => Icons.nights_stay_outlined,
  PrayerMoment.isha => Icons.dark_mode_rounded,
  PrayerMoment.midnight => Icons.bedtime_outlined,
  PrayerMoment.lastThird => Icons.auto_awesome_rounded,
};

/// The 12/24-hour clock formatter for [s] in [context].
PrayerClockFormat prayerClockOf(BuildContext context, PrayerSettings s) {
  final l = L10n.of(context);
  return PrayerClockFormat(MadarFormatter.of(context), h24: s.clock24h, am: l.ptAm, pm: l.ptPm);
}
