import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/orbit/render/astrolabe/astrolabe.dart';

import 'astrolabe_fixtures.dart';

const _eps = 1e-9;

Matcher _near(double v, [double tol = 1e-6]) => closeTo(v, tol);

/// Angle difference folded into (-π, π].
double _angleDiff(double a, double b) {
  var d = (a - b) % (2 * math.pi);
  if (d > math.pi) d -= 2 * math.pi;
  return d;
}

void main() {
  group('dial angles', () {
    test('noon at the top, midnight at the bottom, morning left, evening right', () {
      const c = Offset(100, 100);
      final noon = AstrolabeGeometry.pointAt(c, 50, 0.5);
      final midnight = AstrolabeGeometry.pointAt(c, 50, 0);
      final six = AstrolabeGeometry.pointAt(c, 50, 0.25);
      final eighteen = AstrolabeGeometry.pointAt(c, 50, 0.75);
      expect(noon.dx, _near(100));
      expect(noon.dy, _near(50));
      expect(midnight.dy, _near(150));
      expect(six.dx, _near(50));
      expect(eighteen.dx, _near(150));
    });

    test('time runs clockwise on screen', () {
      // Just after noon the point moves right (clockwise from the top).
      final p = AstrolabeGeometry.pointAt(Offset.zero, 1, 0.51);
      expect(p.dx, greaterThan(0));
      expect(p.dy, lessThan(0));
    });

    test('fraction ↔ angle round-trip for the whole day', () {
      for (var i = 0; i < 96; i++) {
        final f = i / 96;
        final back = AstrolabeGeometry.fractionForAngle(AstrolabeGeometry.angleForFraction(f));
        expect(back, _near(f));
      }
    });

    test('angle for a clock time', () {
      expect(AstrolabeGeometry.angleForTime(DateTime(2026, 9, 27, 12)), _near(-math.pi / 2));
      expect(AstrolabeGeometry.angleForTime(DateTime(2026, 9, 27, 18)), _near(0));
      final a = AstrolabeGeometry.angleForTime(DateTime(2026, 9, 27, 15, 51, 50));
      expect(AstrolabeGeometry.fractionForAngle(a), _near((15 * 3600 + 51 * 60 + 50) / 86400));
    });

    test('directionOf is a unit vector toward the time', () {
      final d = AstrolabeGeometry.directionOf(0.5);
      expect(d.distance, _near(1));
      expect(d.dy, _near(-1));
    });
  });

  group('arcs', () {
    test('a daytime window sweeps clockwise between its bounds', () {
      final t = AmmanDay.times;
      final arc = AstrolabeGeometry.arc(t.dhuhr, t.asr);
      expect(arc.start, _near(AstrolabeGeometry.angleForTime(t.dhuhr)));
      final seconds = t.asr.difference(t.dhuhr).inMilliseconds / 1000;
      expect(arc.sweep, _near(seconds / 86400 * 2 * math.pi));
      expect(_angleDiff(arc.start + arc.sweep, AstrolabeGeometry.angleForTime(t.asr)), _near(0));
    });

    test('the Isha window wraps through midnight', () {
      final t = AmmanDay.times;
      final nextFajr = t.fajr.add(const Duration(days: 1));
      final arc = AstrolabeGeometry.arc(t.isha, nextFajr);
      expect(arc.sweep, greaterThan(math.pi / 2));
      expect(arc.sweep, lessThan(math.pi));
      expect(_angleDiff(arc.start + arc.sweep, AstrolabeGeometry.angleForTime(nextFajr)), _near(0));
    });

    test('degenerate and over-long arcs are clamped', () {
      final now = DateTime(2026, 9, 27, 10);
      expect(AstrolabeGeometry.arc(now, now).sweep, 0);
      expect(AstrolabeGeometry.arc(now, now.subtract(const Duration(hours: 1))).sweep, 0);
      expect(AstrolabeGeometry.arc(now, now.add(const Duration(days: 2))).sweep, _near(2 * math.pi));
    });

    test('progress along an arc', () {
      final a = DateTime(2026, 9, 27, 12);
      final b = DateTime(2026, 9, 27, 16);
      expect(AstrolabeGeometry.arcProgress(a, b, DateTime(2026, 9, 27, 13)), _near(0.25));
      expect(AstrolabeGeometry.arcProgress(a, b, DateTime(2026, 9, 27, 11)), 0);
      expect(AstrolabeGeometry.arcProgress(a, b, DateTime(2026, 9, 27, 17)), 1);
      expect(AstrolabeGeometry.arcProgress(a, a, a), 1);
    });
  });

  group('pointers', () {
    test('star in the channel, tip on the limb, both at the prayer time', () {
      const c = Offset(200, 200);
      const r = 150.0;
      final f = AmmanDay.times.asr.hour / 24 + AmmanDay.times.asr.minute / 1440;
      final star = AstrolabeGeometry.pointerCenter(c, r, f);
      final tip = AstrolabeGeometry.pointerTip(c, r, f);
      expect((star - c).distance, _near(r * AstrolabeRadii.channel));
      expect((tip - c).distance, _near(r * AstrolabeRadii.limbInner));
      expect(_angleDiff((star - c).direction, AstrolabeGeometry.angleForFraction(f)), _near(0));
      expect(_angleDiff((tip - c).direction, (star - c).direction), _near(0));
    });

    test('names stay upright all around the dial', () {
      // top: no rotation; bottom: no rotation (glyph tops point inward = up)
      expect(AstrolabeGeometry.uprightRotation(-math.pi / 2), _near(0));
      expect(AstrolabeGeometry.uprightRotation(math.pi / 2), _near(0));
      for (var i = 0; i < 48; i++) {
        final a = -math.pi + i * math.pi / 24;
        final rot = AstrolabeGeometry.uprightRotation(a);
        // a glyph's up vector (0,-1) rotated by rot never points down
        final up = Offset(math.sin(rot), -math.cos(rot));
        expect(up.dy, lessThanOrEqualTo(_eps), reason: 'angle $a');
      }
    });

    test('spread keeps crowded names apart and centred', () {
      final out = AstrolabeGeometry.spread([0.0, 0.1, 0.2], [0.3, 0.3]);
      expect(out[1] - out[0], greaterThanOrEqualTo(0.3 - 1e-6));
      expect(out[2] - out[1], greaterThanOrEqualTo(0.3 - 1e-6));
      expect((out[0] + out[2]) / 2, _near(0.1, 1e-6));
      expect(AstrolabeGeometry.spread([0.0, 1.0], [0.3]), [0.0, 1.0]);
    });

    test('label angles respect the minimum gap even across midnight', () {
      final state = AmmanDay.state(AmmanDay.at(21, 0));
      final angles = AstrolabeGeometry.labelAngles(state.fractions, gapFor: (_) => 0.5);
      expect(angles.keys.toSet(), AstrolabeGeometry.prayers.toSet());
      final sorted = angles.values.map(AstrolabeGeometry.fractionForAngle).toList()..sort();
      for (var i = 0; i + 1 < sorted.length; i++) {
        expect((sorted[i + 1] - sorted[i]) * 2 * math.pi, greaterThanOrEqualTo(0.5 - 1e-3));
      }
      // Dhuhr keeps its place near the top (its neighbours are far away).
      expect(
        _angleDiff(angles[Prayer.dhuhr]!, AstrolabeGeometry.angleForTime(AmmanDay.times.dhuhr)).abs(),
        lessThan(0.05),
      );
    });

    test('indexOf follows the dial order', () {
      for (var i = 0; i < AstrolabeGeometry.prayers.length; i++) {
        expect(AstrolabeGeometry.indexOf(AstrolabeGeometry.prayers[i]), i);
      }
      expect(AstrolabeGeometry.indexOf(Prayer.witr), -1);
    });
  });

  group('status', () {
    final t = AmmanDay.times;
    AstrolabePrayerStatus at(Prayer p, DateTime now, {Set<Prayer> prayed = const {}, Set<Prayer> missed = const {}}) =>
        AstrolabeGeometry.statusOf(p, t, now, prayed: prayed, missed: missed);

    test('upcoming → due → missed as the day passes', () {
      expect(at(Prayer.asr, AmmanDay.at(12, 0)), AstrolabePrayerStatus.upcoming);
      expect(at(Prayer.asr, AmmanDay.at(16, 0)), AstrolabePrayerStatus.due);
      expect(at(Prayer.asr, AmmanDay.at(19, 0)), AstrolabePrayerStatus.missed);
      expect(at(Prayer.fajr, AmmanDay.at(6, 0)), AstrolabePrayerStatus.due);
      expect(at(Prayer.fajr, AmmanDay.at(6, 30)), AstrolabePrayerStatus.missed);
    });

    test('Isha stays due past midnight until the next Fajr', () {
      final lateNight = DateTime(2026, 9, 28, 2);
      expect(at(Prayer.isha, lateNight), AstrolabePrayerStatus.due);
      expect(at(Prayer.isha, DateTime(2026, 9, 28, 5, 30)), AstrolabePrayerStatus.missed);
    });

    test('a log wins over the clock', () {
      expect(at(Prayer.asr, AmmanDay.at(12, 0), prayed: {Prayer.asr}), AstrolabePrayerStatus.prayed);
      expect(at(Prayer.asr, AmmanDay.at(16, 0), missed: {Prayer.asr}), AstrolabePrayerStatus.missed);
    });

    test('each prayer ends where the next begins', () {
      expect(AstrolabeGeometry.windowEndOf(Prayer.fajr, t), t.sunrise);
      expect(AstrolabeGeometry.windowEndOf(Prayer.dhuhr, t), t.asr);
      expect(AstrolabeGeometry.windowEndOf(Prayer.asr, t), t.maghrib);
      expect(AstrolabeGeometry.windowEndOf(Prayer.maghrib, t), t.isha);
      expect(AstrolabeGeometry.windowEndOf(Prayer.isha, t), t.fajr.add(const Duration(days: 1)));
    });

    test("Isha ends at the next day's real Fajr (a DST change is not + 24 h)", () {
      final real = t.fajr.add(const Duration(days: 1, minutes: 1));
      expect(AstrolabeGeometry.windowEndOf(Prayer.isha, t, nextFajr: real), real);
      // Without it: the same wall-clock time a calendar day later.
      final end = AstrolabeGeometry.windowEndOf(Prayer.isha, t);
      expect((end.day, end.hour, end.minute), (t.fajr.add(const Duration(days: 1)).day, t.fajr.hour, t.fajr.minute));
      // Due until the real Fajr, not the approximation.
      final between = t.fajr.add(const Duration(days: 1, seconds: 30));
      expect(
        AstrolabeGeometry.statusOf(Prayer.isha, t, between, prayed: const {}, nextFajr: real),
        AstrolabePrayerStatus.due,
      );
      expect(AstrolabeGeometry.statusOf(Prayer.isha, t, between, prayed: const {}), AstrolabePrayerStatus.missed);
    });
  });

  group('tilt', () {
    test('project / unproject round-trip on a tilted disc', () {
      const c = Offset(200, 200);
      final m = AstrolabeGeometry.tiltMatrix(c, 150, const AstrolabeTilt(pitch: 0.4, yaw: -0.3));
      for (final p in const [Offset(200, 200), Offset(320, 180), Offset(90, 300), Offset(210, 60)]) {
        final s = AstrolabeGeometry.project(m, p);
        final back = AstrolabeGeometry.unproject(m, s)!;
        expect((back - p).distance, lessThan(1e-6));
      }
    });

    test('the centre stays put and the far edge shrinks', () {
      const c = Offset(200, 200);
      final m = AstrolabeGeometry.tiltMatrix(c, 150, const AstrolabeTilt(pitch: 0.4));
      expect((AstrolabeGeometry.project(m, c) - c).distance, lessThan(1e-9));
      final top = AstrolabeGeometry.project(m, const Offset(200, 50));
      final bottom = AstrolabeGeometry.project(m, const Offset(200, 350));
      expect((top - c).distance, lessThan(150));
      expect((top - c).distance, isNot(_near((bottom - c).distance, 1e-3)));
    });

    test('flat tilt is the identity', () {
      expect(AstrolabeTilt.flat.isFlat, isTrue);
      final m = AstrolabeGeometry.tiltMatrix(const Offset(10, 10), 100, AstrolabeTilt.flat);
      expect(AstrolabeGeometry.project(m, const Offset(40, 70)), const Offset(40, 70));
      expect(
        AstrolabeTilt.lerp(AstrolabeTilt.flat, const AstrolabeTilt(pitch: 0.2, yaw: 0.4), 0.5),
        const AstrolabeTilt(pitch: 0.1, yaw: 0.2),
      );
    });
  });

  group('hit testing', () {
    const size = Size(400, 400);
    final state = AmmanDay.state(AmmanDay.at(16, 0));
    final fractions = state.fractions;
    final center = size.center(Offset.zero);
    final r = AstrolabeGeometry.radiusFor(size);

    test('each pointer star and tip hits its prayer', () {
      for (final p in AstrolabeGeometry.prayers) {
        final star = AstrolabeGeometry.pointerCenter(center, r, fractions[p]!);
        final tip = AstrolabeGeometry.pointerTip(center, r, fractions[p]!);
        expect(AstrolabeGeometry.hitTestPrayer(star, size: size, fractions: fractions), p);
        expect(AstrolabeGeometry.hitTestPrayer(tip + const Offset(3, -2), size: size, fractions: fractions), p);
      }
    });

    test('empty space and the centre hit nothing', () {
      expect(AstrolabeGeometry.hitTestPrayer(center, size: size, fractions: fractions), isNull);
      expect(AstrolabeGeometry.hitTestPrayer(const Offset(2, 2), size: size, fractions: fractions), isNull);
    });

    test('engraved names are targets too', () {
      final label = const Offset(0.2, -0.6);
      expect(
        AstrolabeGeometry.hitTestPrayer(
          center + label * r,
          size: size,
          fractions: fractions,
          labelCenters: {Prayer.dhuhr: label},
        ),
        Prayer.dhuhr,
      );
    });

    test('a tilted disc is hit where the pointer is drawn', () {
      const tilt = AstrolabeTilt(pitch: 0.45, yaw: 0.25);
      final m = AstrolabeGeometry.tiltMatrix(center, r, tilt);
      for (final p in AstrolabeGeometry.prayers) {
        final onScreen = AstrolabeGeometry.project(m, AstrolabeGeometry.pointerCenter(center, r, fractions[p]!));
        expect(AstrolabeGeometry.hitTestPrayer(onScreen, size: size, fractions: fractions, tilt: tilt), p);
      }
    });
  });

  group('level of detail', () {
    test('grows with the on-screen radius', () {
      expect(AstrolabeGeometry.lodFor(40), AstrolabeLod.minimal);
      expect(AstrolabeGeometry.lodFor(120), AstrolabeLod.medium);
      expect(AstrolabeGeometry.lodFor(200), AstrolabeLod.full);
      expect(AstrolabeGeometry.lodFor(600), AstrolabeLod.ultra);
      expect(AstrolabeLod.full >= AstrolabeLod.medium, isTrue);
      expect(AstrolabeLod.minimal < AstrolabeLod.medium, isTrue);
    });

    test('the render cache records at quantised radii', () {
      for (final r in [20.0, 77.0, 150.0, 333.0, 1600.0]) {
        final b = AstrolabeRenderCache.bucketFor(r);
        expect(b / r, inInclusiveRange(1 / 1.1, 1.1));
      }
      expect(AstrolabeRenderCache.bucketFor(150), AstrolabeRenderCache.bucketFor(151));
    });
  });

  group('stereographic projection', () {
    test('the rete fits the plate: Capricorn on the rim, the ecliptic touches it', () {
      expect(AstrolabeProjection.radiusForDec(-AstrolabeProjection.obliquityDeg), _near(AstrolabeRadii.capricorn));
      expect(AstrolabeProjection.cancer, lessThan(AstrolabeProjection.equator));
      final ecl = AstrolabeProjection.ecliptic;
      expect(ecl.center.dy + ecl.radius, _near(AstrolabeRadii.capricorn));
      expect(ecl.center.dy - ecl.radius, _near(-AstrolabeProjection.cancer));
      // every ecliptic longitude lands on that circle
      for (var l = 0; l < 360; l += 15) {
        final p = AstrolabeProjection.eclipticPoint(l.toDouble());
        expect((p - ecl.center).distance, _near(ecl.radius, 1e-9));
      }
    });

    test('the rete puts the sun at its clock time', () {
      final sky = AmmanDay.skyAt(AmmanDay.at(15, 20));
      final sun = sky.sunReteLocal;
      final onDial = sun.direction + sky.reteRotation;
      expect(_angleDiff(onDial, AstrolabeGeometry.angleForFraction(sky.sunFraction)), _near(0, 1e-9));
    });

    test('the sun crosses the plate horizon at sunrise and the twilight line at Fajr', () {
      double offCircle(DateTime clock, double altitude) {
        final sky = AmmanDay.skyAt(clock);
        final sun = Offset.fromDirection(sky.sunReteLocal.direction + sky.reteRotation, sky.sunReteLocal.distance);
        final c = AstrolabeProjection.almucantar(altitude, sky.latitude);
        final rotated = Offset.fromDirection(c.center.direction + sky.plateRotation, c.center.distance);
        return (sun - rotated).distance - c.radius;
      }

      // adhan's sunrise is for the upper limb with refraction (-0.833°).
      expect(offCircle(AmmanDay.times.sunrise, -0.833).abs(), lessThan(0.006));
      expect(offCircle(AmmanDay.times.maghrib.subtract(const Duration(minutes: 5)), -0.833).abs(), lessThan(0.006));
      expect(offCircle(AmmanDay.times.fajr, -18).abs(), lessThan(0.006));
      expect(offCircle(AmmanDay.times.isha, -18).abs(), lessThan(0.006));
      // At noon the sun is well inside the horizon circle (above it).
      expect(offCircle(AmmanDay.times.dhuhr, 0), lessThan(-0.1));
    });

    test('ecliptic ↔ equatorial conversion at the cardinal points', () {
      final spring = AstrolabeProjection.eclipticToEquatorial(0);
      final summer = AstrolabeProjection.eclipticToEquatorial(90);
      expect(spring.ra, _near(0));
      expect(spring.dec, _near(0));
      expect(summer.ra, _near(90));
      expect(summer.dec, _near(AstrolabeProjection.obliquityDeg));
    });

    test('plate rotation is the clock minus solar time, folded to ±½ day', () {
      final r = AstrolabeProjection.plateRotation(clockFraction: 0.02, solarFraction: 0.98);
      expect(r, _near(0.04 * 2 * math.pi));
    });
  });
}
