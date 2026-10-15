// The qibla compass controller: declination, alignment hysteresis, the
// calibration prompt and the fallbacks. Timers run on the widget tester's
// fake clock (tester.pump).
import 'package:flutter_test/flutter_test.dart' hide testWidgets;
import 'package:flutter_test/flutter_test.dart' as flutter_test show testWidgets;
import 'package:madar/features/qibla/application/qibla_compass_controller.dart';
import 'package:madar/features/qibla/domain/compass_math.dart';
import 'package:madar/features/qibla/domain/heading.dart';
import 'package:madar/features/qibla/domain/qibla_fix.dart';
import 'package:madar/features/qibla/domain/wmm.dart';

import 'qibla_fakes.dart';

const amman = QiblaPlace(latitude: 31.9539, longitude: 35.9106, nameAr: 'عمّان', nameEn: 'Amman');

/// 12:40 in Amman (sun up) and 23:00 (sun down).
final day = DateTime.utc(2026, 9, 28, 9, 40);
final night = DateTime.utc(2026, 9, 28, 20);

void main() {
  final field = WorldMagneticModel.wmm2025.fieldAt(amman.latitude, amman.longitude, day);
  final qibla = QiblaFix.of(amman).bearing;

  /// A clean reading whose TRUE heading is [trueHeading].
  HeadingReading at(double trueHeading, {int ms = 0}) => HeadingReading(
    heading: CircularMath.wrap360(trueHeading - field.declination),
    fieldMicroTesla: field.fMicroTesla,
    dip: field.inclination,
    jitter: 0.3,
    timestamp: Duration(milliseconds: ms),
  );

  // Controllers made in a test are disposed at the end of its body (the
  // binding checks for pending timers before tear-downs run).
  final created = <QiblaCompassController>[];
  QiblaCompassController make(FakeHeadingSource source, {DateTime? now, QiblaPlace place = amman}) {
    final clock = now ?? day;
    final c = QiblaCompassController(source: source, place: place, clock: () => clock);
    created.add(c);
    return c;
  }

  void testWidgets(String description, Future<void> Function(WidgetTester tester) body) {
    flutter_test.testWidgets(description, (tester) async {
      try {
        await body(tester);
      } finally {
        for (final c in created) {
          c.dispose();
        }
        created.clear();
      }
    });
  }

  testWidgets('starts waiting, then applies the declination to the magnetic heading', (tester) async {
    final source = FakeHeadingSource();
    final c = make(source)..start();
    expect(c.value.mode, QiblaMode.starting);
    expect(source.hasListener, isTrue);
    source.emit(at(70));
    await tester.pump();
    expect(c.value.mode, QiblaMode.compass);
    expect(c.value.heading, 70);
    expect(c.live.value.facing, closeTo(70, 1e-6));
    expect(c.value.declination, closeTo(field.declination, 1e-9));
    expect(c.value.turn, closeTo(qibla - 70, 0.6));
  });

  testWidgets('alignment: in at ±3°, out beyond ±5°, one chime per entry', (tester) async {
    final source = FakeHeadingSource();
    final c = make(source)..start();
    source.emit(at(qibla + 10));
    await tester.pump();
    expect(c.value.aligned, isFalse);
    source.emit(at(qibla + 2.5));
    await tester.pump();
    expect(c.value.aligned, isTrue);
    expect(c.value.alignCount, 1);
    source.emit(at(qibla - 4.5)); // still inside the release band
    await tester.pump();
    expect(c.value.aligned, isTrue);
    source.emit(at(qibla - 6));
    await tester.pump();
    expect(c.value.aligned, isFalse);
    // Re-entering at once does not chime again (gap 1.5 s).
    source.emit(at(qibla));
    await tester.pump();
    expect(c.value.aligned, isTrue);
    expect(c.value.alignCount, 1);
  });

  testWidgets('re-entry after the chime gap chimes again', (tester) async {
    final source = FakeHeadingSource();
    var now = day;
    final c = QiblaCompassController(source: source, place: amman, clock: () => now)..start();
    created.add(c);
    source.emit(at(qibla));
    await tester.pump();
    source.emit(at(qibla + 30));
    await tester.pump();
    now = now.add(const Duration(seconds: 2));
    source.emit(at(qibla + 1));
    await tester.pump();
    expect(c.value.alignCount, 2);
  });

  testWidgets('a disturbed field raises the calibration prompt; dismiss and self-clear', (tester) async {
    final source = FakeHeadingSource();
    final c = make(source)..start();
    var ms = 0;
    void disturbed() => source.emit(
      HeadingReading(
        heading: 10,
        fieldMicroTesla: field.fMicroTesla * 1.35,
        dip: field.inclination + 25,
        fieldSpread: 6,
        timestamp: Duration(milliseconds: ms += 20),
      ),
    );
    for (var i = 0; i < 100; i++) {
      disturbed();
      await tester.pump();
    }
    expect(c.value.quality.needsCalibration, isTrue);
    expect(c.value.showCalibration, isTrue);
    c.dismissCalibration();
    expect(c.value.showCalibration, isFalse);
    for (var i = 0; i < 150; i++) {
      source.emit(at(10, ms: ms += 20));
      await tester.pump();
    }
    expect(c.value.quality.needsCalibration, isFalse);
    expect(c.value.calibratedCount, 1);
  });

  testWidgets('no magnetometer by day → the sun compass', (tester) async {
    final source = FakeHeadingSource(error: const HeadingUnavailable(HeadingUnavailableReason.noSensor));
    final c = make(source)..start();
    await tester.pump();
    expect(c.value.mode, QiblaMode.sun);
    expect(c.value.unavailable, HeadingUnavailableReason.noSensor);
    expect(c.value.facing, c.value.sun.azimuth);
    expect(c.live.value.facing, c.value.sun.azimuth);
    expect(c.value.turn, closeTo(CircularMath.delta(c.value.sun.azimuth, qibla), 1e-9));
  });

  testWidgets('no magnetometer at night → the static diagram', (tester) async {
    final source = FakeHeadingSource(error: const HeadingUnavailable(HeadingUnavailableReason.noSensor));
    final c = make(source, now: night)..start();
    await tester.pump();
    expect(c.value.mode, QiblaMode.diagram);
    expect(c.value.facing, isNull);
    expect(c.value.turn, isNull);
    expect(c.live.value.facing, isNull);
  });

  testWidgets('silence → falls back after the timeout, a late reading brings the compass back', (tester) async {
    final source = FakeHeadingSource();
    final c = make(source)..start();
    await tester.pump(const Duration(seconds: 2));
    expect(c.value.mode, QiblaMode.starting);
    await tester.pump(const Duration(seconds: 2));
    expect(c.value.mode, QiblaMode.sun);
    expect(c.value.unavailable, HeadingUnavailableReason.noReadings);
    source.emit(at(12));
    await tester.pump();
    expect(c.value.mode, QiblaMode.compass);
    expect(c.value.unavailable, isNull);
  });

  testWidgets('useSun / useCompass switch modes and the sensors', (tester) async {
    final source = FakeHeadingSource(initial: at(100));
    final c = make(source)..start();
    await tester.pump();
    expect(c.value.mode, QiblaMode.compass);
    c.useSun();
    await tester.pump();
    expect(c.value.mode, QiblaMode.sun);
    expect(source.hasListener, isFalse);
    c.useCompass();
    await tester.pump();
    expect(c.value.mode, QiblaMode.compass);
    expect(source.listens, 2);
  });

  testWidgets('pause stops the sensors; resume restarts them', (tester) async {
    final source = FakeHeadingSource(initial: at(100));
    final c = make(source)..start();
    await tester.pump();
    c.pause();
    await tester.pump();
    expect(source.hasListener, isFalse);
    c.start();
    await tester.pump();
    expect(source.hasListener, isTrue);
  });

  testWidgets('battery saver and landscape re-subscribe with the new options', (tester) async {
    final source = FakeHeadingSource(initial: at(100));
    final c = make(source)..start();
    await tester.pump();
    c.setBatterySaver(true);
    await tester.pump();
    expect(source.lastBatterySaver, isTrue);
    c.setLandscape(true);
    await tester.pump();
    expect(source.lastLandscape, isTrue);
    expect(source.listens, 3);
  });

  testWidgets('a new place moves the qibla and the declination', (tester) async {
    final source = FakeHeadingSource(initial: at(100));
    final c = make(source)..start();
    await tester.pump();
    const london = QiblaPlace(latitude: 51.5074, longitude: -0.1278, nameEn: 'London');
    c.setPlace(london);
    expect(c.value.fix.bearing, closeTo(118.99, 0.01));
    expect(c.value.declination, lessThan(2)); // ≈ +1° in 2026
  });

  testWidgets('a phone pointing at the ground asks to be held flat (with hysteresis)', (tester) async {
    final source = FakeHeadingSource();
    final c = make(source)..start();
    HeadingReading pointing(double p, int ms) => HeadingReading(
      heading: 20,
      pointing: p,
      fieldMicroTesla: field.fMicroTesla,
      dip: field.inclination,
      timestamp: Duration(milliseconds: ms),
    );
    source.emit(pointing(1, 0));
    await tester.pump();
    expect(c.value.holdFlat, isFalse);
    source.emit(pointing(0.3, 100));
    await tester.pump();
    expect(c.value.holdFlat, isTrue);
    source.emit(pointing(0.5, 200));
    await tester.pump();
    expect(c.value.holdFlat, isTrue);
    source.emit(pointing(0.9, 300));
    await tester.pump();
    expect(c.value.holdFlat, isFalse);
  });

  testWidgets('heading-only updates are throttled; the live pose is not', (tester) async {
    final source = FakeHeadingSource();
    final c = make(source)..start();
    var notified = 0;
    c.state.addListener(() => notified++);
    for (var i = 0; i < 25; i++) {
      source.emit(at(40.0 + i, ms: i * 20)); // 1° per 20 ms for half a second
      await tester.pump();
    }
    expect(c.live.value.facing, closeTo(64, 0.01));
    // 500 ms / 80 ms ≈ 7 texts updates (plus the first), not 25.
    expect(notified, lessThanOrEqualTo(9));
    expect(c.value.heading, inInclusiveRange(58, 64));
  });

  testWidgets('at the Kaaba there is no alignment chime', (tester) async {
    final source = FakeHeadingSource();
    final c = make(source, place: const QiblaPlace(latitude: 21.4225, longitude: 39.8262))..start();
    source.emit(HeadingReading(heading: c.value.fix.bearing - c.value.declination));
    await tester.pump();
    expect(c.value.fix.atKaaba, isTrue);
    expect(c.value.aligned, isFalse);
  });
}
