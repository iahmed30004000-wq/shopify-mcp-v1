import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'wmm2025_coefficients.dart';

/// The geomagnetic field at one place and time (World Magnetic Model).
///
/// Components in nanotesla in the local geodetic frame: [x] north, [y] east,
/// [z] down.
@immutable
class GeomagneticField {
  const GeomagneticField({
    required this.x,
    required this.y,
    required this.z,
    required this.decimalYear,
    required this.withinValidity,
  });

  /// North, east and down components (nT).
  final double x, y, z;

  /// The epoch the field was computed for (e.g. 2026.74).
  final double decimalYear;

  /// Whether [decimalYear] lies inside the model's five-year validity.
  final bool withinValidity;

  /// Horizontal intensity (nT).
  double get h => math.sqrt(x * x + y * y);

  /// Total intensity (nT).
  double get f => math.sqrt(x * x + y * y + z * z);

  /// Magnetic declination in degrees, east positive: true bearing =
  /// magnetic bearing + declination.
  double get declination => math.atan2(y, x) * 180 / math.pi;

  /// Inclination (dip) in degrees, positive when the field points down.
  double get inclination => math.atan2(z, h) * 180 / math.pi;

  /// Total intensity in microtesla (the unit Android's magnetometer reports).
  double get fMicroTesla => f / 1000;

  /// Horizontal intensity in microtesla.
  double get hMicroTesla => h / 1000;

  /// The WMM "blackout zone" (H < 2000 nT): a compass is unreliable.
  bool get inBlackoutZone => h < 2000;

  /// The WMM "caution zone" (H < 6000 nT): compass accuracy degrades.
  bool get inCautionZone => h < 6000;

  @override
  String toString() =>
      'GeomagneticField(D ${declination.toStringAsFixed(2)}°, I ${inclination.toStringAsFixed(2)}°, '
      'F ${f.toStringAsFixed(0)} nT @ ${decimalYear.toStringAsFixed(2)})';
}

/// A spherical-harmonic main-field model evaluated in pure Dart – the World
/// Magnetic Model's own algorithm (the NOAA reference implementation of the
/// WMM technical report): geodetic → geocentric spherical coordinates on
/// WGS-84, Gauss-normalised associated Legendre functions by recursion,
/// secular variation applied linearly from the epoch, and the result rotated
/// back into the geodetic frame. Verified against every official WMM2025
/// test value (test/features/qibla/wmm_test.dart).
class WorldMagneticModel {
  WorldMagneticModel({
    required this.name,
    required this.epoch,
    required List<List<double>> coefficients,
    this.lifespanYears = 5,
  }) : maxDegree = coefficients.fold<int>(0, (m, r) => math.max(m, r[0].toInt())) {
    final n1 = maxDegree + 1;
    _g = List.generate(n1, (_) => List.filled(n1, 0.0));
    _h = List.generate(n1, (_) => List.filled(n1, 0.0));
    _gd = List.generate(n1, (_) => List.filled(n1, 0.0));
    _hd = List.generate(n1, (_) => List.filled(n1, 0.0));
    _k = List.generate(n1, (_) => List.filled(n1, 0.0));
    for (final r in coefficients) {
      final n = r[0].toInt();
      final m = r[1].toInt();
      _g[n][m] = r[2];
      _h[n][m] = r[3];
      _gd[n][m] = r[4];
      _hd[n][m] = r[5];
    }
    // Schmidt semi-normalised → Gauss-normalised coefficients (the recursion
    // below produces Gauss-normalised Legendre functions), and the recursion
    // factors k(n, m).
    final snorm = List.generate(n1, (_) => List.filled(n1, 0.0));
    snorm[0][0] = 1;
    for (var n = 1; n <= maxDegree; n++) {
      snorm[n][0] = snorm[n - 1][0] * (2 * n - 1) / n;
      for (var m = 0; m <= n; m++) {
        _k[n][m] = n > 1 ? ((n - 1) * (n - 1) - m * m) / ((2 * n - 1) * (2 * n - 3)) : 0.0;
        if (m > 0) {
          final j = m == 1 ? 2 : 1;
          snorm[n][m] = snorm[n][m - 1] * math.sqrt((n - m + 1) * j / (n + m));
        }
        _g[n][m] *= snorm[n][m];
        _h[n][m] *= snorm[n][m];
        _gd[n][m] *= snorm[n][m];
        _hd[n][m] *= snorm[n][m];
      }
    }
    _k[1][1] = 0;
  }

  /// WMM2025 (NOAA NCEI / BGS; public domain), valid 2025.0–2030.0.
  static final WorldMagneticModel wmm2025 = WorldMagneticModel(
    name: 'WMM2025',
    epoch: 2025.0,
    coefficients: wmm2025Coefficients,
  );

  final String name;

  /// Reference epoch (decimal year) of the coefficients.
  final double epoch;
  final double lifespanYears;
  final int maxDegree;

  late final List<List<double>> _g, _h, _gd, _hd, _k;

  // WGS-84 ellipsoid and the geomagnetic reference radius (km).
  static const double _a = 6378.137;
  static const double _b = 6356.7523142;
  static const double _re = 6371.2;

  /// The field at geodetic [latitude] / [longitude] (degrees), [altitudeKm]
  /// above the WGS-84 ellipsoid, at [decimalYear].
  GeomagneticField field({
    required double latitude,
    required double longitude,
    double altitudeKm = 0,
    required double decimalYear,
  }) {
    const dtr = math.pi / 180;
    final dt = decimalYear - epoch;
    final glat = latitude.clamp(-90.0, 90.0);
    final rlon = longitude * dtr;
    final rlat = glat * dtr;
    final srlon = math.sin(rlon);
    final crlon = math.cos(rlon);
    final srlat = math.sin(rlat);
    final crlat = math.cos(rlat);
    final srlat2 = srlat * srlat;
    final crlat2 = crlat * crlat;

    const a2 = _a * _a;
    const b2 = _b * _b;
    const c2 = a2 - b2;
    const a4 = a2 * a2;
    const b4 = b2 * b2;
    const c4 = a4 - b4;

    // Geodetic → geocentric spherical: ct/st = cos/sin of the geocentric
    // colatitude, r the geocentric radius, ca/sa the rotation back.
    final alt = altitudeKm;
    final q = math.sqrt(a2 - c2 * srlat2);
    final q1 = alt * q;
    final q2 = ((q1 + a2) / (q1 + b2)) * ((q1 + a2) / (q1 + b2));
    final ct = srlat / math.sqrt(q2 * crlat2 + srlat2);
    final st = math.sqrt(math.max(0.0, 1.0 - ct * ct));
    final r2 = alt * alt + 2.0 * q1 + (a4 - c4 * srlat2) / (q * q);
    final r = math.sqrt(r2);
    final d = math.sqrt(a2 * crlat2 + b2 * srlat2);
    final ca = (alt + d) / r;
    final sa = c2 * crlat * srlat / (r * d);

    final nMax = maxDegree;
    final sp = List.filled(nMax + 1, 0.0);
    final cp = List.filled(nMax + 1, 0.0);
    cp[0] = 1;
    sp[1] = srlon;
    cp[1] = crlon;
    for (var m = 2; m <= nMax; m++) {
      sp[m] = sp[1] * cp[m - 1] + cp[1] * sp[m - 1];
      cp[m] = cp[1] * cp[m - 1] - sp[1] * sp[m - 1];
    }

    final p = List.generate(nMax + 1, (_) => List.filled(nMax + 1, 0.0));
    final dp = List.generate(nMax + 1, (_) => List.filled(nMax + 1, 0.0));
    final pp = List.filled(nMax + 1, 0.0);
    p[0][0] = 1;
    pp[0] = 1;

    final aor = _re / r;
    var ar = aor * aor;
    var br = 0.0, bt = 0.0, bp = 0.0, bpp = 0.0;
    final atPole = st < 1e-12;
    for (var n = 1; n <= nMax; n++) {
      ar *= aor;
      for (var m = 0; m <= n; m++) {
        // Gauss-normalised associated Legendre functions and their
        // derivatives with respect to the colatitude.
        if (n == m) {
          p[n][m] = st * p[n - 1][m - 1];
          dp[n][m] = st * dp[n - 1][m - 1] + ct * p[n - 1][m - 1];
        } else if (n == 1 && m == 0) {
          p[n][m] = ct * p[n - 1][m];
          dp[n][m] = ct * dp[n - 1][m] - st * p[n - 1][m];
        } else {
          final pm2 = m > n - 2 ? 0.0 : p[n - 2][m];
          final dpm2 = m > n - 2 ? 0.0 : dp[n - 2][m];
          p[n][m] = ct * p[n - 1][m] - _k[n][m] * pm2;
          dp[n][m] = ct * dp[n - 1][m] - st * p[n - 1][m] - _k[n][m] * dpm2;
        }
        final g = _g[n][m] + dt * _gd[n][m];
        final h = _h[n][m] + dt * _hd[n][m];
        final par = ar * p[n][m];
        final double temp1, temp2;
        if (m == 0) {
          temp1 = g * cp[m];
          temp2 = g * sp[m];
        } else {
          temp1 = g * cp[m] + h * sp[m];
          temp2 = g * sp[m] - h * cp[m];
        }
        bt -= ar * temp1 * dp[n][m];
        bp += m * temp2 * par;
        br += (n + 1) * temp1 * par;
        // At a geographic pole the east component is the limit of bp / st.
        if (atPole && m == 1) {
          pp[n] = n == 1 ? pp[n - 1] : ct * pp[n - 1] - _k[n][m] * pp[n - 2];
          bpp += m * temp2 * ar * pp[n];
        }
      }
    }
    bp = atPole ? bpp : bp / st;

    // Spherical → geodetic.
    final bx = -bt * ca - br * sa;
    final by = bp;
    final bz = bt * sa - br * ca;
    return GeomagneticField(
      x: bx,
      y: by,
      z: bz,
      decimalYear: decimalYear,
      withinValidity: decimalYear >= epoch && decimalYear <= epoch + lifespanYears,
    );
  }

  /// [field] at the instant [time] (converted with [decimalYearOf]).
  GeomagneticField fieldAt(double latitude, double longitude, DateTime time, {double altitudeKm = 0}) =>
      field(latitude: latitude, longitude: longitude, altitudeKm: altitudeKm, decimalYear: decimalYearOf(time));

  /// Declination (degrees, east positive) at a place and instant.
  double declination(double latitude, double longitude, DateTime time, {double altitudeKm = 0}) =>
      fieldAt(latitude, longitude, time, altitudeKm: altitudeKm).declination;

  /// The WMM's decimal year: the year plus the elapsed fraction of it (UTC).
  static double decimalYearOf(DateTime time) {
    final t = time.toUtc();
    final start = DateTime.utc(t.year);
    final end = DateTime.utc(t.year + 1);
    return t.year + t.difference(start).inMicroseconds / end.difference(start).inMicroseconds;
  }
}
