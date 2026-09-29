import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/qibla/data/sensor_heading_source.dart';
import 'package:madar/features/qibla/domain/compass_math.dart';
import 'package:madar/features/qibla/domain/compass_quality.dart';
import 'package:madar/features/qibla/domain/heading.dart';
import 'package:madar/features/qibla/domain/heading_engine.dart';
import 'package:madar/features/qibla/domain/wmm.dart';

import 'qibla_fakes.dart';

const _step = Duration(milliseconds: 20);

/// Feeds [n] samples of [pose] (with optional noise) and returns the last
/// reading.
HeadingReading? _feed(
  HeadingEngine e,
  Pose pose, {
  int n = 50,
  Duration start = Duration.zero,
  double total = 44,
  double dip = 50,
  math.Random? noise,
  double noiseMicroTesla = 0,
}) {
  HeadingReading? last;
  for (var i = 0; i < n; i++) {
    final t = start + _step * i;
    e.addAccelerometer(pose.accel(), t);
    var m = pose.magnetic(total: total, dip: dip);
    if (noise != null) {
      m =
          m +
          Vec3(
            (noise.nextDouble() - 0.5) * 2 * noiseMicroTesla,
            (noise.nextDouble() - 0.5) * 2 * noiseMicroTesla,
            (noise.nextDouble() - 0.5) * 2 * noiseMicroTesla,
          );
    }
    last = e.addMagnetometer(m, t) ?? last;
  }
  return last;
}

void main() {
  group('HeadingEngine', () {
    test('no reading before gravity is known', () {
      final e = HeadingEngine();
      expect(e.addMagnetometer(Pose(heading: 0).magnetic(), Duration.zero), isNull);
    });

    test('tilted phone reads its heading with field statistics', () {
      final e = HeadingEngine();
      final r = _feed(e, Pose(heading: 161, pitch: 25, roll: -10))!;
      expect(CircularMath.delta(161, r.heading).abs(), lessThan(0.05));
      expect(r.fieldMicroTesla, closeTo(44, 0.01));
      expect(r.fieldSpread, lessThan(0.01));
      expect(r.dip, closeTo(50, 0.01));
      expect(r.pitch, closeTo(25, 0.5));
      expect(r.steady, isTrue);
      expect(r.jitter, lessThan(0.01));
    });

    test('turning through north is continuous (no 359 → 0 jump in the output)', () {
      final e = HeadingEngine();
      double? prev;
      for (var i = 0; i < 150; i++) {
        final t = _step * i;
        final pose = Pose(heading: CircularMath.wrap360(345 + i * 0.2));
        e.addAccelerometer(pose.accel(), t);
        final r = e.addMagnetometer(pose.magnetic(), t);
        if (r == null) continue;
        if (prev != null) expect(CircularMath.delta(prev, r.heading).abs(), lessThan(1));
        prev = r.heading;
      }
      expect(CircularMath.delta(prev!, 14.8).abs(), lessThan(1.5));
    });

    test('magnetometer noise is smoothed and reported as jitter', () {
      final e = HeadingEngine();
      final r = _feed(e, Pose(heading: 90), n: 300, noise: math.Random(3), noiseMicroTesla: 1.5)!;
      expect(CircularMath.delta(90, r.heading).abs(), lessThan(1.5));
      expect(r.jitter, greaterThan(0.2));
      expect(r.jitter, lessThan(4));
    });

    test('shaking marks the reading unsteady', () {
      final e = HeadingEngine();
      final pose = Pose(heading: 10);
      HeadingReading? r;
      for (var i = 0; i < 60; i++) {
        final t = _step * i;
        e.addAccelerometer(pose.accel(g: i.isEven ? 14 : 5), t);
        r = e.addMagnetometer(pose.magnetic(), t) ?? r;
      }
      expect(r!.steady, isFalse);
    });

    test('landscape picks the edge that is up', () {
      final e = HeadingEngine(landscape: true);
      // Upright on its side, device −x edge up (ROTATION_270), screen
      // facing north-west-ish: the back of the phone faces 270°.
      final r = _feed(e, Pose(heading: 0, roll: -90))!;
      expect(CircularMath.delta(270, r.heading).abs(), lessThan(0.1));
      // The other side up (+x edge, ROTATION_90): the back faces 90°.
      final e2 = HeadingEngine(landscape: true);
      final r2 = _feed(e2, Pose(heading: 0, roll: 90))!;
      expect(CircularMath.delta(90, r2.heading).abs(), lessThan(0.1));
    });
  });

  group('SensorHeadingSource', () {
    test('turns raw samples into readings and stops the sensors on cancel', () async {
      final sensors = FakeMotionSensors();
      final source = SensorHeadingSource(sensors: sensors);
      final got = <HeadingReading>[];
      final sub = source.readings().listen(got.add);
      expect(sensors.period, SensorHeadingSource.livePeriod);
      final pose = Pose(heading: 250);
      for (var i = 0; i < 10; i++) {
        sensors.accel.add(MotionSample(pose.accel(), _step * i));
        sensors.mag.add(MotionSample(pose.magnetic(), _step * i));
      }
      await Future<void>.delayed(Duration.zero);
      expect(got, isNotEmpty);
      expect(CircularMath.delta(250, got.last.heading).abs(), lessThan(0.1));
      expect(sensors.accel.hasListener, isTrue);
      await sub.cancel();
      expect(sensors.accel.hasListener, isFalse);
      expect(sensors.mag.hasListener, isFalse);
    });

    test('battery saver samples slower', () async {
      final sensors = FakeMotionSensors();
      final sub = SensorHeadingSource(sensors: sensors).readings(batterySaver: true).listen((_) {});
      expect(sensors.period, SensorHeadingSource.saverPeriod);
      await sub.cancel();
    });

    test('a missing magnetometer becomes HeadingUnavailable(noSensor)', () async {
      final sensors = FakeMotionSensors();
      final errors = <Object>[];
      final done = Completer<void>();
      SensorHeadingSource(sensors: sensors).readings().listen((_) {}, onError: errors.add, onDone: done.complete);
      sensors.mag.addError(PlatformException(code: 'NO_SENSOR', message: 'Sensor not found'));
      await done.future;
      expect(
        errors.single,
        isA<HeadingUnavailable>().having((e) => e.reason, 'reason', HeadingUnavailableReason.noSensor),
      );
      expect(sensors.mag.hasListener, isFalse);
    });

    test('error mapping', () {
      expect(SensorHeadingSource.reasonFor(MissingPluginException()), HeadingUnavailableReason.noSensor);
      expect(SensorHeadingSource.reasonFor(StateError('x')), HeadingUnavailableReason.sensorError);
      expect(
        SensorHeadingSource.reasonFor(const HeadingUnavailable(HeadingUnavailableReason.noReadings)),
        HeadingUnavailableReason.noReadings,
      );
    });
  });

  group('CompassQualityMonitor (Amman, WMM2025)', () {
    final expected = WorldMagneticModel.wmm2025.fieldAt(31.9539, 35.9106, DateTime.utc(2026, 9, 28));
    HeadingReading reading(
      int ms, {
      double? f,
      double? dip,
      double spread = 0,
      double jitter = 0.3,
      double pointing = 1,
    }) => HeadingReading(
      heading: 100,
      fieldMicroTesla: f ?? expected.fMicroTesla,
      dip: dip ?? expected.inclination,
      fieldSpread: spread,
      jitter: jitter,
      pointing: pointing,
      timestamp: Duration(milliseconds: ms),
    );

    test('a field that matches the model is high accuracy', () {
      final m = CompassQualityMonitor(expected: expected);
      late CompassQuality q;
      for (var t = 0; t < 2000; t += 20) {
        q = m.update(reading(t));
      }
      expect(q.accuracy, CompassAccuracy.high);
      expect(q.errorDeg, lessThan(3));
      expect(q.needsCalibration, isFalse);
      expect(q.interference, isFalse);
    });

    test('a uniform scale error within 8 % is tolerated', () {
      final m = CompassQualityMonitor(expected: expected);
      expect(m.errorOf(reading(0, f: expected.fMicroTesla * 1.07)), lessThan(2));
    });

    test('a disturbed field asks for calibration after a second, and clears after the fix', () {
      final m = CompassQualityMonitor(expected: expected);
      var t = 0;
      late CompassQuality q;
      // Hard-iron offset: |B| wanders ±8 µT and the dip is 20° off.
      for (; t < 600; t += 20) {
        q = m.update(reading(t, f: expected.fMicroTesla * 1.3, dip: expected.inclination + 20, spread: 6));
      }
      expect(q.needsCalibration, isFalse, reason: 'not before the persistence delay');
      for (; t < 2000; t += 20) {
        q = m.update(reading(t, f: expected.fMicroTesla * 1.3, dip: expected.inclination + 20, spread: 6));
      }
      expect(q.needsCalibration, isTrue);
      expect(q.accuracy, anyOf(CompassAccuracy.low, CompassAccuracy.unreliable));
      // Figure-eight done: the field matches the model again.
      for (; t < 2600; t += 20) {
        q = m.update(reading(t));
      }
      expect(q.needsCalibration, isTrue, reason: 'holds until good for 1.5 s');
      for (; t < 5000; t += 20) {
        q = m.update(reading(t));
      }
      expect(q.needsCalibration, isFalse);
      expect(q.accuracy, CompassAccuracy.high);
    });

    test('a magnet nearby is interference', () {
      final m = CompassQualityMonitor(expected: expected);
      expect(m.update(reading(0, f: expected.fMicroTesla * 2.2)).interference, isTrue);
    });

    test('error estimate: a 10 µT excess across H≈33 µT is ~11–17°', () {
      final m = CompassQualityMonitor(expected: expected);
      final e = m.errorOf(reading(0, f: expected.fMicroTesla + 10 + 0.08 * expected.fMicroTesla));
      expect(e, inInclusiveRange(11, 20));
    });

    test('an unknown field (a heading-only source) is judged on jitter alone', () {
      final m = CompassQualityMonitor(expected: expected);
      const r = HeadingReading(heading: 5, jitter: 1);
      expect(m.errorOf(r), closeTo(math.sqrt(1.5 * 1.5 + 1), 1e-9));
    });

    test('near a magnetic pole the compass is unreliable', () {
      final polar = WorldMagneticModel.wmm2025.field(latitude: 85.8, longitude: 139, decimalYear: 2026.0);
      final m = CompassQualityMonitor(expected: polar);
      expect(CompassQuality.levelFor(m.errorOf(const HeadingReading(heading: 0))), CompassAccuracy.unreliable);
    });
  });
}
