import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/qibla/domain/compass_math.dart';
import 'package:madar/features/qibla/domain/qibla_fix.dart';
import 'package:madar/features/qibla/domain/sun_compass.dart';

/// Independent reference: initial great-circle bearing and haversine
/// distance to the Kaaba (21.4225241 N, 39.8261818 E), R = 6371.0088 km.
(double, double) _reference(double lat, double lon) {
  const kLat = 21.4225241, kLon = 39.8261818;
  double rad(double d) => d * math.pi / 180;
  final p1 = rad(lat), p2 = rad(kLat), dl = rad(kLon - lon);
  final y = math.sin(dl) * math.cos(p2);
  final x = math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl);
  final b = (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  final h = math.pow(math.sin((p2 - p1) / 2), 2) + math.cos(p1) * math.cos(p2) * math.pow(math.sin(dl / 2), 2);
  return (b, 2 * 6371.0088 * math.asin(math.sqrt(h)));
}

void main() {
  // lat, lon, bearing°, distance km – computed independently (above, and
  // cross-checked in Python); they agree with the commonly published qibla
  // bearings (London ≈ 119°, New York ≈ 58.5°, Jakarta ≈ 295°).
  const cities = <String, (double, double, double, double)>{
    'Amman': (31.9539, 35.9106, 160.71, 1233.7),
    'London': (51.5074, -0.1278, 118.99, 4793.8),
    'Jakarta': (-6.2088, 106.8456, 295.15, 7920.1),
    'New York': (40.7128, -74.0060, 58.48, 10306.3),
  };

  group('bearing and distance to the Kaaba', () {
    cities.forEach((name, c) {
      test(name, () {
        final fix = QiblaFix.at(c.$1, c.$2);
        final (refB, refD) = _reference(c.$1, c.$2);
        expect(fix.bearing, closeTo(refB, 0.01));
        expect(fix.bearing, closeTo(c.$3, 0.01));
        expect(fix.distanceKm, closeTo(refD, 0.5));
        expect(fix.distanceKm, closeTo(c.$4, 1));
        expect(fix.atKaaba, isFalse);
      });
    });

    test('compass points: Amman S, London SE, Jakarta NW, New York NE', () {
      expect(QiblaFix.at(31.9539, 35.9106).point, CompassPoint.south);
      expect(QiblaFix.at(51.5074, -0.1278).point, CompassPoint.southEast);
      expect(QiblaFix.at(-6.2088, 106.8456).point, CompassPoint.northWest);
      expect(QiblaFix.at(40.7128, -74.0060).point, CompassPoint.northEast);
    });

    test('any coordinates (a travel destination) and a named place', () {
      const istanbul = QiblaPlace(latitude: 41.0082, longitude: 28.9784, nameAr: 'إسطنبول', nameEn: 'Istanbul');
      final fix = QiblaFix.of(istanbul);
      expect(fix.bearing, closeTo(_reference(41.0082, 28.9784).$1, 0.01));
      expect(fix.place.name('ar'), 'إسطنبول');
      expect(fix.place.name('en'), 'Istanbul');
      expect(const QiblaPlace(latitude: 0, longitude: 0, nameAr: 'س').name('en'), 'س');
    });

    test('at the Kaaba the bearing is meaningless', () {
      expect(QiblaFix.at(21.4225, 39.8262).atKaaba, isTrue);
      expect(QiblaFix.at(21.4300, 39.8262).atKaaba, isFalse); // ~0.8 km away
    });

    test('turnFrom: signed shortest turn, positive to the right', () {
      final fix = QiblaFix.at(31.9539, 35.9106); // 160.7°
      expect(fix.turnFrom(160.7), closeTo(0, 0.01));
      expect(fix.turnFrom(70.7), closeTo(90, 0.01));
      expect(fix.turnFrom(250.7), closeTo(-90, 0.01));
      expect(fix.turnFrom(350), closeTo(170.71, 0.01));
    });
  });

  group('sun compass', () {
    test('Amman at 12:40 local (09:40 UTC) on 28 Sep 2026: the sun is up, south, and usable', () {
      final sun = SunGuide.at(DateTime.utc(2026, 9, 28, 9, 40), latitude: 31.9539, longitude: 35.9106);
      expect(sun.usable, isTrue);
      // Solar noon in Amman ≈ 09:27 UTC: the sun is just past the meridian.
      expect(sun.azimuth, inInclusiveRange(180, 200));
      expect(sun.altitude, inInclusiveRange(55, 60));
      expect(sun.high, isFalse);
      // The qibla (160.7°) is to the left of the sun.
      expect(sun.turnTo(160.71), lessThan(0));
      expect(sun.shadowAzimuth, closeTo(CircularMath.wrap360(sun.azimuth + 180), 1e-9));
    });

    test('at night the sun cannot be used', () {
      final sun = SunGuide.at(DateTime.utc(2026, 9, 28, 20), latitude: 31.9539, longitude: 35.9106);
      expect(sun.usable, isFalse);
    });

    test('a midsummer noon sun is flagged as high', () {
      final sun = SunGuide.at(DateTime.utc(2026, 6, 21, 9, 30), latitude: 31.9539, longitude: 35.9106);
      expect(sun.high, isTrue);
    });
  });
}
