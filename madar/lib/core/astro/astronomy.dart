import 'dart:math' as math;

/// Low-cost positional astronomy for the living sky of the Astrolabe Orbit.
///
/// Algorithms: NOAA solar calculator (after Meeus) for the sun, Meeus ch. 47
/// (truncated) for the moon, IAU 1982 GMST. Accuracy is a small fraction of a
/// degree – far below one pixel of the sky backdrop.
abstract final class Astro {
  static const double deg = math.pi / 180.0;
  static const double rad = 180.0 / math.pi;

  /// Julian day (UT) for an instant.
  static double julianDay(DateTime t) =>
      t.toUtc().millisecondsSinceEpoch / 86400000.0 + 2440587.5;

  /// Julian centuries since J2000.0.
  static double centuries(DateTime t) => (julianDay(t) - 2451545.0) / 36525.0;

  static double _norm360(double x) {
    final r = x % 360.0;
    return r < 0 ? r + 360.0 : r;
  }

  /// Greenwich mean sidereal time in degrees.
  static double gmstDeg(DateTime t) {
    final jd = julianDay(t);
    final tc = (jd - 2451545.0) / 36525.0;
    final g = 280.46061837 +
        360.98564736629 * (jd - 2451545.0) +
        0.000387933 * tc * tc -
        tc * tc * tc / 38710000.0;
    return _norm360(g);
  }

  /// Local sidereal time in degrees for an east-positive longitude.
  static double lstDeg(DateTime t, double longitude) => _norm360(gmstDeg(t) + longitude);

  /// Mean obliquity of the ecliptic (degrees).
  static double obliquityDeg(double tc) =>
      23.0 + (26.0 + (21.448 - tc * (46.815 + tc * (0.00059 - tc * 0.001813))) / 60.0) / 60.0;

  /// Converts equatorial coordinates to horizontal ones.
  static Horizontal toHorizontal({
    required double raDeg,
    required double decDeg,
    required DateTime time,
    required double latitude,
    required double longitude,
  }) {
    final ha = (lstDeg(time, longitude) - raDeg) * deg;
    final lat = latitude * deg;
    final dec = decDeg * deg;
    final sinAlt = math.sin(lat) * math.sin(dec) + math.cos(lat) * math.cos(dec) * math.cos(ha);
    final alt = math.asin(sinAlt.clamp(-1.0, 1.0));
    // Azimuth measured from north, clockwise (east = 90°).
    final y = -math.sin(ha) * math.cos(dec);
    final x = math.cos(lat) * math.sin(dec) - math.sin(lat) * math.cos(dec) * math.cos(ha);
    final az = _norm360(math.atan2(y, x) * rad);
    return Horizontal(altitude: alt * rad, azimuth: az);
  }

  /// Sun position (NOAA). Altitude includes a standard refraction correction.
  static SunState sun(DateTime time, {required double latitude, required double longitude}) {
    final tc = centuries(time);
    final l0 = _norm360(280.46646 + tc * (36000.76983 + tc * 0.0003032));
    final m = 357.52911 + tc * (35999.05029 - 0.0001537 * tc);
    final e = 0.016708634 - tc * (0.000042037 + 0.0000001267 * tc);
    final mr = m * deg;
    final c = math.sin(mr) * (1.914602 - tc * (0.004817 + 0.000014 * tc)) +
        math.sin(2 * mr) * (0.019993 - 0.000101 * tc) +
        math.sin(3 * mr) * 0.000289;
    final trueLong = l0 + c;
    final omega = 125.04 - 1934.136 * tc;
    final lambda = trueLong - 0.00569 - 0.00478 * math.sin(omega * deg);
    final eps = obliquityDeg(tc) + 0.00256 * math.cos(omega * deg);
    final lr = lambda * deg;
    final er = eps * deg;
    final ra = _norm360(math.atan2(math.cos(er) * math.sin(lr), math.cos(lr)) * rad);
    final dec = math.asin(math.sin(er) * math.sin(lr)) * rad;

    final y = math.pow(math.tan(er / 2), 2).toDouble();
    final l0r = l0 * deg;
    final eqTimeMin = 4 *
        rad *
        (y * math.sin(2 * l0r) -
            2 * e * math.sin(mr) +
            4 * e * y * math.sin(mr) * math.cos(2 * l0r) -
            0.5 * y * y * math.sin(4 * l0r) -
            1.25 * e * e * math.sin(2 * mr));

    final h = toHorizontal(raDeg: ra, decDeg: dec, time: time, latitude: latitude, longitude: longitude);
    final alt = h.altitude + refractionDeg(h.altitude);
    // Local apparent solar time → 0..1 fraction of the solar day (0.5 = noon).
    final utc = time.toUtc();
    final utcMin = utc.hour * 60 + utc.minute + utc.second / 60.0 + utc.millisecond / 60000.0;
    final solarMin = (utcMin + eqTimeMin + 4 * longitude) % 1440.0;
    return SunState(
      altitude: alt,
      azimuth: h.azimuth,
      rightAscension: ra,
      declination: dec,
      equationOfTimeMin: eqTimeMin,
      solarDayFraction: (solarMin < 0 ? solarMin + 1440 : solarMin) / 1440.0,
    );
  }

  /// Bennett's refraction formula (degrees) for an apparent altitude.
  static double refractionDeg(double altitude) {
    if (altitude < -1.0) return 0;
    final r = 1.02 / math.tan((altitude + 10.3 / (altitude + 5.11)) * deg) / 60.0;
    return r.isFinite ? r : 0;
  }

  /// Moon position and phase (Meeus ch. 47/48, main terms).
  static MoonState moon(DateTime time, {required double latitude, required double longitude}) {
    final tc = centuries(time);
    final lp = _norm360(218.3164477 + 481267.88123421 * tc); // mean longitude
    final d = _norm360(297.8501921 + 445267.1114034 * tc); // mean elongation
    final m = _norm360(357.5291092 + 35999.0502909 * tc); // sun mean anomaly
    final mp = _norm360(134.9633964 + 477198.8675055 * tc); // moon mean anomaly
    final f = _norm360(93.2720950 + 483202.0175233 * tc); // argument of latitude
    double s(double x) => math.sin(x * deg);

    final lon = lp +
        6.288774 * s(mp) +
        1.274027 * s(2 * d - mp) +
        0.658314 * s(2 * d) +
        0.213618 * s(2 * mp) -
        0.185116 * s(m) -
        0.114332 * s(2 * f) +
        0.058793 * s(2 * d - 2 * mp) +
        0.057066 * s(2 * d - m - mp) +
        0.053322 * s(2 * d + mp) +
        0.045758 * s(2 * d - m) -
        0.040923 * s(m - mp) -
        0.034720 * s(d) -
        0.030383 * s(m + mp);
    final lat = 5.128122 * s(f) +
        0.280602 * s(mp + f) +
        0.277693 * s(mp - f) +
        0.173237 * s(2 * d - f) +
        0.055413 * s(2 * d - mp + f) +
        0.046271 * s(2 * d - mp - f);

    final eps = obliquityDeg(tc) * deg;
    final lr = lon * deg;
    final br = lat * deg;
    final ra = _norm360(math.atan2(
            math.sin(lr) * math.cos(eps) - math.tan(br) * math.sin(eps), math.cos(lr)) *
        rad);
    final dec = math.asin(math.sin(br) * math.cos(eps) + math.cos(br) * math.sin(eps) * math.sin(lr)) * rad;
    final h = toHorizontal(raDeg: ra, decDeg: dec, time: time, latitude: latitude, longitude: longitude);

    // Phase angle i (Meeus 48.4) and illuminated fraction k.
    final i = 180 -
        d -
        6.289 * s(mp) +
        2.100 * s(m) -
        1.274 * s(2 * d - mp) -
        0.658 * s(2 * d) -
        0.214 * s(2 * mp) -
        0.110 * s(d);
    final k = (1 + math.cos(i * deg)) / 2;
    // Elongation of the moon from the sun (0..360) → waxing when < 180.
    final sunLon = _norm360(280.46646 + 36000.76983 * tc + 1.914602 * s(357.52911 + 35999.05029 * tc));
    final elong = _norm360(lon - sunLon);
    return MoonState(
      altitude: h.altitude + refractionDeg(h.altitude),
      azimuth: h.azimuth,
      rightAscension: ra,
      declination: dec,
      illumination: k.clamp(0.0, 1.0),
      phase: elong / 360.0,
    );
  }
}

class Horizontal {
  const Horizontal({required this.altitude, required this.azimuth});

  /// Degrees above the horizon.
  final double altitude;

  /// Degrees from north, clockwise.
  final double azimuth;
}

class SunState {
  const SunState({
    required this.altitude,
    required this.azimuth,
    required this.rightAscension,
    required this.declination,
    required this.equationOfTimeMin,
    required this.solarDayFraction,
  });

  final double altitude;
  final double azimuth;
  final double rightAscension;
  final double declination;
  final double equationOfTimeMin;

  /// Local apparent solar time as a fraction of the day (0.5 = solar noon).
  final double solarDayFraction;

  SkyPhase get skyPhase => SkyPhase.fromSunAltitude(altitude);
}

class MoonState {
  const MoonState({
    required this.altitude,
    required this.azimuth,
    required this.rightAscension,
    required this.declination,
    required this.illumination,
    required this.phase,
  });

  final double altitude;
  final double azimuth;
  final double rightAscension;
  final double declination;

  /// Illuminated fraction of the disc, 0 (new) … 1 (full).
  final double illumination;

  /// Synodic phase 0..1: 0 new, 0.25 first quarter, 0.5 full, 0.75 last quarter.
  final double phase;

  bool get waxing => phase < 0.5;
}

/// Sky look driven by the real sun altitude.
enum SkyPhase {
  night, // sun < -18°
  astronomicalTwilight, // -18° … -12° (Fajr / Isha band)
  nauticalTwilight, // -12° … -6°
  civilTwilight, // -6° … -0.833° (dawn / Maghrib glow)
  goldenHour, // -0.833° … 6°
  day; // > 6°

  static SkyPhase fromSunAltitude(double alt) {
    if (alt < -18) return night;
    if (alt < -12) return astronomicalTwilight;
    if (alt < -6) return nauticalTwilight;
    if (alt < -0.833) return civilTwilight;
    if (alt < 6) return goldenHour;
    return day;
  }
}
