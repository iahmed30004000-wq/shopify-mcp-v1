import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/astro/astronomy.dart';
import 'package:madar/core/astro/star_catalog.dart';

void main() {
  const lat = 31.9539, lon = 35.9106; // Amman

  test('solar noon in Amman on 2026-09-27 is due south at ~56°', () {
    final s = Astro.sun(DateTime.utc(2026, 9, 27, 9, 27), latitude: lat, longitude: lon);
    expect(s.altitude, closeTo(56.3, 0.3));
    expect(s.azimuth, closeTo(180, 1.5));
    expect(s.solarDayFraction, closeTo(0.5, 0.002));
    expect(s.skyPhase, SkyPhase.day);
  });

  test('dawn twilight before sunrise', () {
    final s = Astro.sun(DateTime.utc(2026, 9, 27, 3, 0), latitude: lat, longitude: lon);
    expect(s.skyPhase, SkyPhase.nauticalTwilight);
    expect(s.azimuth, closeTo(88, 2));
  });

  test('moon phases of September 2026', () {
    final newMoon = Astro.moon(DateTime.utc(2026, 9, 11, 12), latitude: lat, longitude: lon);
    final firstQuarter = Astro.moon(DateTime.utc(2026, 9, 18, 12), latitude: lat, longitude: lon);
    final full = Astro.moon(DateTime.utc(2026, 9, 26, 12), latitude: lat, longitude: lon);
    expect(newMoon.illumination, lessThan(0.02));
    expect(firstQuarter.illumination, closeTo(0.5, 0.06));
    expect(firstQuarter.waxing, isTrue);
    expect(full.illumination, greaterThan(0.98));
  });

  test('star catalog decodes with Sirius first', () {
    final stars = StarCatalog.stars;
    expect(stars.length, greaterThan(2000));
    expect(stars.first.magnitude, closeTo(-1.46, 0.01));
    expect(stars.first.raDeg, closeTo(101.29, 0.05));
    final c = stars.first.color;
    expect(c.b, greaterThan(c.r)); // hot, blue-white star
  });
}
