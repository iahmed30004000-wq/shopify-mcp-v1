import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/qibla/domain/compass_math.dart';
import 'package:madar/features/qibla/domain/tilt_compass.dart';

import 'qibla_fakes.dart';

void main() {
  double headingOf(Pose p, {int turns = 0, double dip = 50}) =>
      TiltCompass.solve(p.accel(), p.magnetic(dip: dip), quarterTurns: turns)!.heading;

  Matcher angleNear(double expected, [double tol = 0.01]) =>
      predicate<double>((a) => CircularMath.delta(expected, a).abs() <= tol, 'within $tol° of $expected');

  group('flat phone', () {
    for (final h in [0.0, 45.0, 90.0, 161.0, 180.0, 270.0, 359.5]) {
      test('heading $h°', () {
        expect(headingOf(Pose(heading: h)), angleNear(h));
      });
    }
  });

  group('tilt compensation', () {
    test('pitch does not move the heading (top raised or lowered)', () {
      for (final pitch in [-60.0, -30.0, -10.0, 10.0, 30.0, 45.0, 60.0, 80.0, 89.0]) {
        expect(headingOf(Pose(heading: 123, pitch: pitch)), angleNear(123), reason: 'pitch $pitch');
      }
    });

    test('roll does not move the heading of a flat-ish phone', () {
      for (final roll in [-40.0, -15.0, 15.0, 40.0]) {
        expect(headingOf(Pose(heading: 250, roll: roll)), angleNear(250), reason: 'roll $roll');
        expect(headingOf(Pose(heading: 250, pitch: -20, roll: roll)), angleNear(250), reason: 'roll $roll, pitch −20');
      }
    });

    test('an upright phone (camera pose) points where its back faces', () {
      expect(headingOf(Pose(heading: 30, pitch: 90)), angleNear(30));
      // Turning an upright phone about the vertical is a change of heading.
      expect(headingOf(Pose(heading: 30, pitch: 90, roll: 20)), angleNear(50));
    });

    test('the dip does not leak into the heading (strong and weak dips, southern hemisphere)', () {
      for (final dip in [-70.0, -30.0, 0.0, 20.0, 50.0, 75.0]) {
        expect(headingOf(Pose(heading: 200, pitch: 35, roll: 10), dip: dip), angleNear(200), reason: 'dip $dip');
      }
    });

    test('without tilt compensation the same pose would read far off', () {
      // A naive atan2(my, mx) on the raw magnetometer at 35° pitch.
      final p = Pose(heading: 90, pitch: 35);
      final m = p.magnetic();
      final naive = CircularMath.wrap360(math.atan2(-m.x, m.y) * CircularMath.degPerRad);
      expect(CircularMath.delta(90, naive).abs(), greaterThan(20));
      expect(headingOf(p), angleNear(90));
    });
  });

  group('screen rotation', () {
    test('landscape (ROTATION_90): the device +x edge is forward', () {
      final p = Pose(heading: 10, roll: 0);
      // Device +x points at 100°.
      expect(headingOf(p, turns: 1), angleNear(100));
      expect(headingOf(p, turns: 3), angleNear(280));
      expect(headingOf(p, turns: 2), angleNear(190));
    });

    test('landscape turns follow gravity with hysteresis', () {
      const leftUp = Vec3(9.8, 0, 0);
      const rightUp = Vec3(-9.8, 0, 0);
      expect(TiltCompass.landscapeTurns(leftUp), 1);
      expect(TiltCompass.landscapeTurns(rightUp), 3);
      expect(TiltCompass.landscapeTurns(const Vec3(-1, 0, 9.7), previous: 1), 1);
      expect(TiltCompass.landscapeTurns(const Vec3(-2, 0, 9.6), previous: 1), 3);
    });
  });

  group('measurements', () {
    test('pitch, roll, dip and field strength', () {
      final p = Pose(heading: 70, pitch: 30, roll: -12);
      final s = TiltCompass.solve(p.accel(), p.magnetic(total: 44.5, dip: 49.8))!;
      expect(s.pitch, closeTo(30, 0.01));
      // Elevation of the right edge after the pitch: asin(sin r · cos p).
      expect(
        s.roll,
        closeTo(math.asin(math.sin(-12 * math.pi / 180) * math.cos(30 * math.pi / 180)) * 180 / math.pi, 0.01),
      );
      expect(s.dip, closeTo(49.8, 0.01));
      expect(s.fieldMicroTesla, closeTo(44.5, 1e-9));
      expect(s.gravity, closeTo(TiltCompass.g0, 1e-9));
      expect(s.pointing, 1.0);
    });

    test('pointing quality drops as the top edge points at the ground', () {
      final s = TiltCompass.solve(Pose(heading: 0, pitch: -80).accel(), Pose(heading: 0, pitch: -80).magnetic())!;
      expect(s.pointing, lessThan(0.3));
    });

    test('degenerate inputs give no heading', () {
      final p = Pose(heading: 0);
      expect(TiltCompass.solve(Vec3.zero, p.magnetic()), isNull); // free fall
      expect(TiltCompass.solve(p.accel(), Vec3.zero), isNull); // no field
      // Field parallel to gravity (a magnetic pole): no horizontal component.
      expect(TiltCompass.solve(p.accel(), const Vec3(0, 0, -50)), isNull);
      expect(TiltCompass.solve(const Vec3(double.nan, 0, 9.8), p.magnetic()), isNull);
    });
  });
}
