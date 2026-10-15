import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/qibla/domain/circular_filter.dart';
import 'package:madar/features/qibla/domain/compass_math.dart';

void main() {
  group('CircularMath', () {
    test('wrap and delta', () {
      expect(CircularMath.wrap360(-1), 359);
      expect(CircularMath.wrap360(360), 0);
      expect(CircularMath.wrap360(725), 5);
      expect(CircularMath.wrap180(190), -170);
      expect(CircularMath.wrap180(-180), 180);
      expect(CircularMath.delta(359, 1), 2);
      expect(CircularMath.delta(1, 359), -2);
      expect(CircularMath.delta(10, 190), 180);
    });

    test('unwrapNear keeps animations on the short way round', () {
      expect(CircularMath.unwrapNear(1, 359), 361);
      expect(CircularMath.unwrapNear(359, 721), 719);
      expect(CircularMath.unwrapNear(180, 0), 180);
    });

    test('circular mean and spread straddle north correctly', () {
      expect(CircularMath.mean([350, 10]), closeTo(0, 1e-9));
      expect(CircularMath.mean([355, 5, 0]), closeTo(0, 1e-9));
      expect(CircularMath.mean([0, 180]), isNull);
      expect(CircularMath.spread([350, 10]), closeTo(10, 0.1));
      expect(CircularMath.spread([90, 90, 90]), closeTo(0, 0.01));
    });

    test('compass points', () {
      expect(CompassPoint.of(0), CompassPoint.north);
      expect(CompassPoint.of(22.4), CompassPoint.north);
      expect(CompassPoint.of(22.5), CompassPoint.northEast);
      expect(CompassPoint.of(160.7), CompassPoint.south); // Amman: 157.5–202.5 is S
      expect(CompassPoint.of(118.99), CompassPoint.southEast); // London
      expect(CompassPoint.of(295.2), CompassPoint.northWest);
      expect(CompassPoint.of(337.6), CompassPoint.north);
      expect(CompassPoint.of(-90), CompassPoint.west);
    });
  });

  group('CircularOneEuroFilter', () {
    const dt = 0.02; // 50 Hz

    test('crossing north never swings through south', () {
      final f = CircularOneEuroFilter();
      f.filter(355, dt);
      for (var i = 0; i < 100; i++) {
        final out = f.filter(5, dt);
        // Always between 355 and 5 the short way.
        expect(CircularMath.delta(355, out), inInclusiveRange(0, 10.0001), reason: 'sample $i: $out');
      }
      expect(f.value, closeTo(5, 0.5));
    });

    test('a sweep through 359° → 0° stays continuous', () {
      final f = CircularOneEuroFilter();
      double? prev;
      for (var i = 0; i <= 200; i++) {
        final angle = CircularMath.wrap360(340 + i * 0.2); // 340° → 20°
        final out = f.filter(angle, dt);
        if (prev != null) expect(CircularMath.delta(prev, out).abs(), lessThan(1.0));
        prev = out;
      }
    });

    test('low latency: a 90° turn is followed within 1° in under 0.4 s', () {
      final f = CircularOneEuroFilter();
      for (var i = 0; i < 50; i++) {
        f.filter(0, dt);
      }
      var t = 0.0;
      while (CircularMath.delta(f.value!, 90).abs() > 1) {
        f.filter(90, dt);
        t += dt;
        expect(t, lessThan(0.4), reason: 'still at ${f.value} after ${t}s');
      }
    });

    test('suppresses jitter at rest (noise std reduced at least 3×)', () {
      final rnd = math.Random(7);
      final f = CircularOneEuroFilter();
      final inputs = <double>[];
      final outputs = <double>[];
      for (var i = 0; i < 600; i++) {
        // ±3° uniform noise around 2° (straddling north).
        final x = CircularMath.wrap360(2 + (rnd.nextDouble() - 0.5) * 6);
        final y = f.filter(x, dt);
        if (i > 100) {
          inputs.add(x);
          outputs.add(y);
        }
      }
      expect(CircularMath.spread(outputs), lessThan(CircularMath.spread(inputs) / 3));
      expect(CircularMath.delta(2, CircularMath.mean(outputs)!).abs(), lessThan(0.3));
    });

    test('a long gap restarts instead of dragging stale state', () {
      final f = CircularOneEuroFilter();
      f.filter(10, dt);
      expect(f.filter(200, 2.0), 200);
      expect(f.filter(123, 0), 200); // duplicate timestamp: unchanged
    });
  });

  group('helpers', () {
    test('Vec3LowPass and EwmStats', () {
      final lp = Vec3LowPass(0.1);
      expect(lp.add(const Vec3(1, 0, 0), 0), const Vec3(1, 0, 0));
      final v = lp.add(const Vec3(0, 0, 0), 0.1);
      expect(v.x, closeTo(0.5, 1e-9));

      final s = EwmStats(0.5);
      for (var i = 0; i < 500; i++) {
        s.add(i.isEven ? 40 : 44, 0.02);
      }
      expect(s.mean, closeTo(42, 0.2));
      expect(s.std, closeTo(2, 0.2));
    });
  });
}
