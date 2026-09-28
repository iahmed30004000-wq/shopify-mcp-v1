import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/orbit/domain/scene_math.dart';
import 'package:madar/features/orbit/render/sky/sky.dart';

import 'sky_fixtures.dart';

const _size = Size(412, 915);

double _angleDeg(V3 a, V3 b) => math.acos(a.dot(b).clamp(-1.0, 1.0)) * 180 / math.pi;

void main() {
  group('SkyView.weights', () {
    test('face the sun in twilight, the moon at night when up, else the qibla', () {
      expect(SkyView.dominant(-10, 30), SkyTarget.sun);
      expect(SkyView.dominant(-18, 30), SkyTarget.sun);
      expect(SkyView.dominant(4, -20), SkyTarget.sun);
      expect(SkyView.dominant(-40, 30), SkyTarget.moon);
      expect(SkyView.dominant(-40, -10), SkyTarget.qibla);
      expect(SkyView.dominant(40, 30), SkyTarget.qibla);
    });

    test('sum to one and change continuously', () {
      Map<SkyTarget, double>? prev;
      for (var alt = -40.0; alt <= 40; alt += 0.1) {
        final w = SkyView.weights(alt, 20);
        expect(w.values.fold<double>(0, (a, b) => a + b), closeTo(1, 1e-9));
        for (final v in w.values) {
          expect(v, inInclusiveRange(0, 1));
        }
        if (prev != null) {
          for (final t in SkyTarget.values) {
            expect((w[t]! - prev[t]!).abs(), lessThan(0.05), reason: '$t at $alt');
          }
        }
        prev = w;
      }
    });
  });

  group('aiming', () {
    const principal = Offset(206, 366);
    final focal = _size.height / (2 * math.tan(1.45 / 2));

    test('aimAtBody frames the body exactly at the anchor', () {
      for (final (alt, az) in [(47.0, 110.0), (20.0, 250.0), (70.0, 10.0), (35.0, 181.0)]) {
        const anchor = Offset(0.26, 0.15);
        final aim = SkyView.aimAtBody(alt, az, anchor, _size, principal, focal);
        final cam = SkyCamera.fromAim(aim, viewport: _size, principal: principal, fovY: 1.45);
        final p = cam.project(SkyModel.enu(alt, az))!;
        expect(p.dx, closeTo(anchor.dx * _size.width, 0.5), reason: 'alt $alt az $az');
        expect(p.dy, closeTo(anchor.dy * _size.height, 0.5), reason: 'alt $alt az $az');
      }
    });

    test('aimAtHorizon puts an azimuth on the horizon at the requested point', () {
      final aim = SkyView.aimAtHorizon(270, 0.8, 0.56, _size, principal, focal);
      final cam = SkyCamera.fromAim(aim, viewport: _size, principal: principal, fovY: 1.45);
      final p = cam.project(SkyModel.enu(0, 270))!;
      expect(p.dx, closeTo(0.8 * _size.width, 0.5));
      expect(p.dy, closeTo(0.56 * _size.height, 0.5));
      // The whole horizon is level (no roll): another azimuth, same height.
      expect(cam.project(SkyModel.enu(0, 260))!.dy, closeTo(p.dy, 0.5));
    });

    test('ray and project are inverse', () {
      final cam = SkyCamera.fromAim(
        const SkyAim(123, 31),
        viewport: _size,
        principal: principal,
        fovY: 1.45,
        roll: 0.1,
      );
      for (final o in const [Offset(10, 20), Offset(206, 366), Offset(400, 900)]) {
        final back = cam.project(cam.ray(o))!;
        expect((back - o).distance, lessThan(1e-6));
      }
    });

    test('basis is orthonormal', () {
      final (r, u, f) = SkyCamera.basisFor(37, 22, 0.3);
      expect(r.length, closeTo(1, 1e-12));
      expect(u.length, closeTo(1, 1e-12));
      expect(f.length, closeTo(1, 1e-12));
      expect(r.dot(u), closeTo(0, 1e-12));
      expect(r.dot(f), closeTo(0, 1e-12));
      expect(u.dot(f), closeTo(0, 1e-12));
    });

    test('SkyAim.lerp takes the shortest arc', () {
      expect(SkyAim.lerp(const SkyAim(350, 0), const SkyAim(10, 0), 0.5).yaw % 360, closeTo(0, 1e-9));
      expect(SkyAim.lerp(const SkyAim(10, 0), const SkyAim(350, 20), 0.5).pitch, 10);
    });
  });

  group('SkyView.camera for the reference instants', () {
    final tone = testTone();

    test('twilight faces the sun, night the moon, moonless night and day the qibla', () {
      final fajr = SkyModel.compute(SkyShot.fajr.time, tone: tone);
      final c1 = SkyView.camera(fajr, _size);
      expect(_angleDeg(V3(c1.forward.x, c1.forward.y, 0).normalized, SkyModel.enu(0, fajr.sun.azimuth)), lessThan(40));
      final sunScreen = c1.project(SkyModel.enu(0, fajr.sun.azimuth))!;
      expect(sunScreen.dx, closeTo(0.8 * _size.width, 1));

      // The moon is framed near its anchor (the pitch is clamped so the
      // horizon never rises above the twilight framing).
      final night = SkyModel.compute(SkyShot.night.time, tone: tone);
      final moon = SkyView.camera(night, _size).project(night.moonDir)!;
      expect(moon.dx, closeTo(0.26 * _size.width, 0.03 * _size.width));
      expect(moon.dy, closeTo(0.15 * _size.height, 0.06 * _size.height));

      for (final shot in [SkyShot.newMoon, SkyShot.noon]) {
        final s = SkyModel.compute(shot.time, tone: tone);
        final c = SkyView.camera(s, _size);
        expect(c.aim.yaw % 360, closeTo(s.qiblaAzimuth, 0.01), reason: shot.name);
      }
    });

    test('the view moves continuously (slow pans, no jumps) through a whole day', () {
      // Sampled every 20 s: the fastest pan (setting moon → dawn, ~180°
      // over ~25 min) stays well under 0.2°/s.
      SkyCamera? prev;
      for (var t = 0; t < 24 * 3600; t += 20) {
        final s = SkyModel.compute(DateTime.utc(2026, 9, 26, 21).add(Duration(seconds: t)), tone: tone);
        final c = SkyView.camera(s, _size);
        if (prev != null) expect(c.angleTo(prev), lessThan(4), reason: 'second $t');
        prev = c;
      }
    });

    test('the whole Fajr window already faces the dawn', () {
      final s = SkyModel.compute(DateTime.utc(2026, 9, 27, 2, 7), tone: tone); // Fajr 05:06 + 1 min
      expect(s.sun.altitude, lessThan(-17));
      expect(SkyView.weights(s.sun.altitude, s.moon.altitude)[SkyTarget.sun], greaterThan(0.99));
    });

    test('orbit rotation turns the sky 0.12× in the same sense as the scene', () {
      final s = SkyModel.compute(SkyShot.newMoon.time, tone: tone);
      const a = OrbitCamera(), b = OrbitCamera(azimuth: 0.2);
      final ca = SkyView.camera(s, _size, orbit: a), cb = SkyView.camera(s, _size, orbit: b);
      expect(ca.aim.yaw - cb.aim.yaw, closeTo(0.12 * 0.2 * 180 / math.pi, 1e-9));
      // A far scene object and a star shift the same way on screen.
      final far = a.position + (a.target - a.position).normalized * 1e5;
      final sceneShift = b.project(far, _size).offset.dx - a.project(far, _size).offset.dx;
      final star = ca.ray(ca.principal);
      final skyShift = cb.project(star)!.dx - ca.project(star)!.dx;
      expect(sceneShift.sign, skyShift.sign);
      expect(skyShift.abs(), lessThan(sceneShift.abs() * 0.2));
    });

    test('gyro adds only a few degrees; pitch stays clamped', () {
      final s = SkyModel.compute(SkyShot.noon.time, tone: tone);
      final base = SkyView.camera(s, _size);
      final g = SkyView.camera(s, _size, gyro: const Offset(30, -30));
      expect((g.aim.yaw - base.aim.yaw).abs(), closeTo(4, 1e-9));
      expect((g.aim.pitch - base.aim.pitch).abs(), closeTo(4, 1e-9));
      final up = SkyView.camera(s, _size, orbit: const OrbitCamera(elevation: -20));
      expect(up.aim.pitch, lessThanOrEqualTo(const SkyComposition().maxPitchDeg));
    });

    test('a fly-in narrows the sky slightly', () {
      final s = SkyModel.compute(SkyShot.noon.time, tone: tone);
      expect(SkyView.camera(s, _size, zoom: 1).focal, greaterThan(SkyView.camera(s, _size).focal));
    });

    test('differsFrom honours the 0.05° threshold', () {
      final a = SkyCamera.fromAim(
        const SkyAim(100, 30),
        viewport: _size,
        principal: const Offset(206, 366),
        fovY: 1.45,
      );
      final b = SkyCamera.fromAim(
        const SkyAim(100.03, 30),
        viewport: _size,
        principal: const Offset(206, 366),
        fovY: 1.45,
      );
      final c = SkyCamera.fromAim(
        const SkyAim(100.08, 30),
        viewport: _size,
        principal: const Offset(206, 366),
        fovY: 1.45,
      );
      expect(b.differsFrom(a), isFalse);
      expect(c.differsFrom(a), isTrue);
      expect(a.differsFrom(null), isTrue);
    });
  });

  group('moon phase & bright limb', () {
    test('the bright limb faces the sun on screen', () {
      final cam = SkyCamera.fromAim(
        const SkyAim(0, 10),
        viewport: _size,
        principal: const Offset(206, 366),
        fovY: 1.45,
      );
      final moon = SkyModel.enu(10, 0);
      expect(SkyView.brightLimbDirection(cam, moon, SkyModel.enu(10, 40)).dx, greaterThan(0.9));
      expect(SkyView.brightLimbDirection(cam, moon, SkyModel.enu(10, -40)).dx, lessThan(-0.9));
      expect(SkyView.brightLimbDirection(cam, moon, SkyModel.enu(-60, 0)).dy, lessThan(-0.9));
      // Sun behind the camera still gives a sensible direction.
      final back = SkyView.brightLimbDirection(cam, moon, SkyModel.enu(-5, 180));
      expect(back.distance, closeTo(1, 1e-9));
    });

    test('light vector: full faces the viewer, new faces away', () {
      final full = SkyView.moonLight(0, const Offset(1, 0));
      expect(full.z, closeTo(1, 1e-12));
      final newMoon = SkyView.moonLight(math.pi, const Offset(1, 0));
      expect(newMoon.z, closeTo(-1, 1e-12));
      final quarter = SkyView.moonLight(math.pi / 2, const Offset(0, 1));
      expect(quarter.y, closeTo(1, 1e-12));
      expect(quarter.z.abs(), lessThan(1e-12));
    });

    test('the 22:30 moon is lit from the sun’s side', () {
      final s = SkyModel.compute(SkyShot.night.time, tone: testTone());
      final cam = SkyView.camera(s, _size);
      final l = SkyView.moonLight(s.moonPhaseAngle, SkyView.brightLimbDirection(cam, s.moonDir, s.sunDir));
      expect(l.z, greaterThan(0.9)); // nearly full
      expect(l.length, closeTo(1, 1e-9));
    });
  });
}
