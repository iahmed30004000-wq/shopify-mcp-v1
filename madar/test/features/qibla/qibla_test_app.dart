// Builds the qibla widgets over the prayer package's test app (in-memory
// database with Amman as the prayer location, recording Fx) with a fake
// HeadingSource and a frozen clock.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/features/qibla/qibla.dart';

import '../prayer/prayer_test_app.dart';
import 'qibla_fakes.dart';

export '../prayer/prayer_test_app.dart' show PrayerTestSetup, settlePrayer;
export 'qibla_fakes.dart';

/// 14:10 in Amman on 28 Sep 2026 – the sun is up (south-west, ~45°).
final qiblaDay = DateTime.utc(2026, 9, 28, 11, 10);

/// 23:00 in Amman – the sun is down.
final qiblaNight = DateTime.utc(2026, 9, 28, 20);

/// The prayer test location (Amman) as used by the qibla providers.
const ammanPlace = QiblaPlace(latitude: 31.9539, longitude: 35.9106);

/// The WMM field at Amman on [at].
GeomagneticField ammanField([DateTime? at]) =>
    WorldMagneticModel.wmm2025.fieldAt(ammanPlace.latitude, ammanPlace.longitude, at ?? qiblaDay);

/// A clean reading (field as the model expects) whose TRUE heading is
/// [trueHeading].
HeadingReading readingAt(double trueHeading, {int ms = 0, DateTime? at, double pitch = 0, double roll = 0}) {
  final f = ammanField(at);
  return HeadingReading(
    heading: CircularMath.wrap360(trueHeading - f.declination),
    fieldMicroTesla: f.fMicroTesla * 1.02,
    dip: f.inclination + 0.8,
    jitter: 0.6,
    fieldSpread: 0.25,
    pitch: pitch,
    roll: roll,
    timestamp: Duration(milliseconds: ms),
  );
}

/// A disturbed reading (a magnetic case nearby).
HeadingReading disturbedAt(double trueHeading, {required int ms}) {
  final f = ammanField();
  return HeadingReading(
    heading: CircularMath.wrap360(trueHeading - f.declination),
    fieldMicroTesla: f.fMicroTesla * 1.38,
    dip: f.inclination + 22,
    fieldSpread: 5,
    jitter: 2,
    timestamp: Duration(milliseconds: ms),
  );
}

/// The qibla from Amman (degrees).
double get ammanQibla => QiblaFix.of(ammanPlace).bearing;

Future<PrayerTestSetup> buildQiblaTestApp(
  WidgetTester tester, {
  required Widget home,
  required FakeHeadingSource source,
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('ar'),
  DateTime? now,
}) {
  final clock = now ?? qiblaDay;
  return buildPrayerTestApp(
    tester,
    home: home,
    theme: theme,
    locale: locale,
    now: clock,
    overrides: [headingSourceProvider.overrideWithValue(source), qiblaClockProvider.overrideWithValue(() => clock)],
  );
}
