// WMM2025 against NOAA's official test values (WMM2025_TEST_VALUES.txt,
// recorded in fixtures/): 100 points spread over the globe, altitudes 0–98 km
// and epochs 2025.0–2029.5.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/qibla/domain/wmm.dart';

class _Row {
  _Row(List<double> v)
    : year = v[0],
      altKm = v[1],
      lat = v[2],
      lon = v[3],
      d = v[4],
      i = v[5],
      h = v[6],
      x = v[7],
      y = v[8],
      z = v[9],
      f = v[10];
  final double year, altKm, lat, lon, d, i, h, x, y, z, f;
}

List<_Row> _loadRows() {
  final file = File('test/features/qibla/fixtures/WMM2025_TEST_VALUES.txt');
  return [
    for (final line in file.readAsLinesSync())
      if (line.trim().isNotEmpty && !line.startsWith('#'))
        _Row(line.trim().split(RegExp(r'\s+')).map(double.parse).toList()),
  ];
}

void main() {
  final model = WorldMagneticModel.wmm2025;
  final rows = _loadRows();

  test('the fixture holds all 100 official test points', () {
    expect(rows, hasLength(100));
  });

  test('declination and inclination match NOAA within 0.01° (values are rounded to 0.01°)', () {
    var worst = 0.0;
    for (final r in rows) {
      final f = model.field(latitude: r.lat, longitude: r.lon, altitudeKm: r.altKm, decimalYear: r.year);
      final dd = (f.declination - r.d).abs();
      final di = (f.inclination - r.i).abs();
      worst = [worst, dd, di].reduce((a, b) => a > b ? a : b);
      expect(
        dd,
        lessThanOrEqualTo(0.0051 + 1e-6),
        reason: 'D at ${r.lat},${r.lon} ${r.year}: ${f.declination} vs ${r.d}',
      );
      expect(
        di,
        lessThanOrEqualTo(0.0051 + 1e-6),
        reason: 'I at ${r.lat},${r.lon} ${r.year}: ${f.inclination} vs ${r.i}',
      );
    }
    // The brief's gate (0.1°) with a wide margin.
    expect(worst, lessThan(0.1));
  });

  test('X, Y, Z, H and F match NOAA within 0.1 nT', () {
    for (final r in rows) {
      final f = model.field(latitude: r.lat, longitude: r.lon, altitudeKm: r.altKm, decimalYear: r.year);
      final where = '${r.lat},${r.lon} ${r.year}';
      expect(f.x, closeTo(r.x, 0.1), reason: 'X at $where');
      expect(f.y, closeTo(r.y, 0.1), reason: 'Y at $where');
      expect(f.z, closeTo(r.z, 0.1), reason: 'Z at $where');
      expect(f.h, closeTo(r.h, 0.1), reason: 'H at $where');
      expect(f.f, closeTo(r.f, 0.1), reason: 'F at $where');
    }
  });

  test('Amman: about 5° east, dip about 50°, 44 µT – and in the validity window', () {
    final f = model.fieldAt(31.9539, 35.9106, DateTime.utc(2026, 9, 28), altitudeKm: 0.8);
    expect(f.declination, inInclusiveRange(4.5, 6.0));
    expect(f.inclination, inInclusiveRange(48.0, 52.0));
    expect(f.fMicroTesla, inInclusiveRange(42.0, 47.0));
    expect(f.withinValidity, isTrue);
    expect(f.inBlackoutZone, isFalse);
  });

  test('the geographic poles are finite (pole special case)', () {
    for (final lat in [90.0, -90.0]) {
      final f = model.field(latitude: lat, longitude: 0, decimalYear: 2026.5);
      expect(f.x.isFinite && f.y.isFinite && f.z.isFinite, isTrue);
      // Compare with a point a hair off the pole.
      final near = model.field(latitude: lat - lat.sign * 1e-6, longitude: 0, decimalYear: 2026.5);
      expect(f.x, closeTo(near.x, 1));
      expect(f.y, closeTo(near.y, 1));
      expect(f.z, closeTo(near.z, 1));
    }
  });

  test('near the north magnetic pole the blackout zone is flagged', () {
    // WMM2025 places the dip pole near 85.8°N 139°E in 2026.
    final f = model.field(latitude: 85.8, longitude: 139, decimalYear: 2026.0);
    expect(f.inBlackoutZone, isTrue);
  });

  test('decimal year', () {
    expect(WorldMagneticModel.decimalYearOf(DateTime.utc(2026)), 2026.0);
    expect(WorldMagneticModel.decimalYearOf(DateTime.utc(2026, 7, 2, 12)), closeTo(2026.5, 0.0001));
    expect(WorldMagneticModel.decimalYearOf(DateTime.utc(2028, 7, 2)), closeTo(2028.5, 0.0001)); // leap year
    expect(model.field(latitude: 0, longitude: 0, decimalYear: 2031).withinValidity, isFalse);
  });
}
