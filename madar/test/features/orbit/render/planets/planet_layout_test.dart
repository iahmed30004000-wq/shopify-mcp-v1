import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/orbit/domain/scene_math.dart';
import 'package:madar/features/orbit/render/orbit_shaders.dart';
import 'package:madar/features/orbit/render/planets/planets.dart';

double _wrap(double a) {
  var d = a % (2 * math.pi);
  if (d > math.pi) d -= 2 * math.pi;
  if (d < -math.pi) d += 2 * math.pi;
  return d;
}

void main() {
  const layout = PlanetSystemLayout();

  group('planet lanes', () {
    test('eight planets fill the annulus in order, evenly', () {
      final lanes = [for (var i = 0; i < 8; i++) layout.laneRadius(i, 8)];
      expect(lanes.first, closeTo(layout.innerRadius, 1e-9));
      expect(lanes.last, closeTo(layout.outerRadius, 1e-9));
      for (var i = 1; i < 8; i++) {
        expect(lanes[i] - lanes[i - 1], closeTo((layout.outerRadius - layout.innerRadius) / 7, 1e-9));
      }
    });

    test('many planets keep the minimum gap (the system grows)', () {
      final lanes = [for (var i = 0; i < 12; i++) layout.laneRadius(i, 12)];
      for (var i = 1; i < 12; i++) {
        expect(lanes[i] - lanes[i - 1], greaterThanOrEqualTo(layout.minLaneGap - 1e-9));
      }
      expect(lanes.first, layout.innerRadius);
    });

    test('few planets keep a pleasant spacing and never touch the core', () {
      for (final n in [1, 2, 3]) {
        final lanes = [for (var i = 0; i < n; i++) layout.laneRadius(i, n)];
        for (final l in lanes) {
          expect(l, inInclusiveRange(layout.innerRadius, layout.outerRadius));
        }
        for (var i = 1; i < n; i++) {
          expect(lanes[i] - lanes[i - 1], lessThanOrEqualTo(0.2 + 1e-9));
        }
      }
    });

    test('neighbouring lanes never begin at nearly the same angle', () {
      // Each world takes its own even share of the circle, nudged a little;
      // the nudge is bounded, so however close two lanes are, the worlds on
      // them begin well apart along the orbit.
      for (final n in [2, 3, 8, 10, 13, 16]) {
        for (var i = 1; i < n; i++) {
          final d = _wrap(layout.initialAngle(i, n, i * 7.31) - layout.initialAngle(i - 1, n, (i - 1) * 7.31)).abs();
          expect(d, greaterThanOrEqualTo(layout.minAngularGap(n) - 1e-9), reason: '$n worlds, planet $i');
        }
      }
    });

    test('ten worlds are spread far more evenly than a golden angle left them', () {
      const golden = 2.399963229728653;
      double smallestGap(List<double> angles) {
        final sorted = [for (final a in angles) a % (2 * math.pi)]..sort();
        var min = sorted.first + 2 * math.pi - sorted.last;
        for (var i = 1; i < sorted.length; i++) {
          min = math.min(min, sorted[i] - sorted[i - 1]);
        }
        return min;
      }

      final scatter = [for (var i = 0; i < 10; i++) 0.62 + i * golden];
      final even = [for (var i = 0; i < 10; i++) layout.initialAngle(i, 10, i * 7.31)];
      // The golden angle leaves two worlds 20° apart where an even share
      // (less the bounded nudge) guarantees at least 29°.
      expect(
        smallestGap(scatter),
        lessThan(layout.minAngularGap(10)),
        reason: 'the golden angle clumps four worlds down one side',
      );
      expect(smallestGap(even), greaterThanOrEqualTo(layout.minAngularGap(10) - 1e-9));
    });

    test('outer worlds orbit more slowly (softened Kepler)', () {
      final inner = layout.periodFor(layout.innerRadius);
      final outer = layout.periodFor(layout.outerRadius);
      expect(inner, closeTo(layout.innerPeriod, 1e-9));
      expect(outer, greaterThan(inner));
      expect(outer / inner, lessThan(math.pow(layout.outerRadius / layout.innerRadius, 1.5)));
      expect(layout.angularSpeedFor(layout.innerRadius), closeTo(2 * math.pi / inner, 1e-12));
    });

    test('orbit tilts are small, stable per planet and varied', () {
      final tilts = [for (var s = 0; s < 20; s++) layout.inclinationOf(s * 7.31)];
      for (final t in tilts) {
        expect(t.abs(), lessThanOrEqualTo(layout.maxInclination + 1e-12));
      }
      expect(tilts.toSet().length, greaterThan(15));
      expect(layout.inclinationOf(3.3), layout.inclinationOf(3.3));
    });

    test('orbitPoint agrees with OrbitElements.positionAt', () {
      final rnd = math.Random(4);
      for (var i = 0; i < 40; i++) {
        final r = 0.5 + rnd.nextDouble();
        final a = rnd.nextDouble() * 7;
        final inc = (rnd.nextDouble() - 0.5) * 0.8;
        final node = rnd.nextDouble() * 6;
        final center = V3(rnd.nextDouble(), rnd.nextDouble(), rnd.nextDouble());
        final expected = OrbitElements(
          radius: r,
          phase: a,
          periodSeconds: 0,
          inclination: inc,
          node: node,
        ).positionAt(0, center: center);
        final got = PlanetSystemLayout.orbitPoint(r, a, inclination: inc, node: node, center: center);
        expect((got - expected).length, lessThan(1e-12));
      }
    });

    test('world size follows the archetype; the gas giant is the largest', () {
      for (final a in PlanetArchetype.values) {
        expect(layout.bodyRadiusOf(a), inInclusiveRange(layout.bodyRadius * 0.8, layout.bodyRadius * 1.2));
      }
      final sizes = PlanetArchetype.values.map(layout.bodyRadiusOf);
      expect(sizes.reduce(math.max), layout.bodyRadiusOf(PlanetArchetype.gasGiant));
      // The family is tightened: the biggest world is only a little bigger
      // than the smallest, so none of them looks like a mistake.
      expect(sizes.reduce(math.max) / sizes.reduce(math.min), lessThanOrEqualTo(PlanetStyle.maxSizeRatio + 1e-9));
    });
  });

  group('moon lanes', () {
    test('spread evenly from the lane start across the band', () {
      for (final a in [PlanetArchetype.terracotta, PlanetArchetype.gasGiant]) {
        final lanes = [for (var j = 0; j < 8; j++) MoonLayout.laneOf(j, 8, a)];
        expect(lanes.first, PlanetStyle.moonLaneStartOf(a));
        expect(lanes.last, closeTo(PlanetStyle.moonLaneStartOf(a) + MoonLayout.span, 1e-12));
      }
      expect(
        MoonLayout.laneOf(0, 1, PlanetArchetype.faith),
        greaterThan(PlanetStyle.moonLaneStartOf(PlanetArchetype.faith)),
      );
    });

    test('the biggest moon never grazes its world\'s halo (or the ship lanes)', () {
      final biggest = MoonStyle.radiusFactor(1);
      for (final a in PlanetArchetype.values) {
        final clear = PlanetStyle.moonLaneStartOf(a) - biggest;
        // The atmospheric halo (Faith's draw rect is larger only for the
        // dome standing proud of its pole, not for a wider halo).
        final halo = a == PlanetArchetype.gasGiant ? 2.17 : OrbitShader.planetOcean.haloFactor;
        expect(clear, greaterThan(halo), reason: a.name);
      }
    });

    test('inner moons are faster; tilts and nodes vary per moon', () {
      expect(MoonLayout.periodOf(1.7), lessThan(MoonLayout.periodOf(2.5)));
      final inc = [for (var s = 0; s < 12; s++) MoonLayout.inclinationOf(s * 3.17)];
      for (final i in inc) {
        expect(i, inInclusiveRange(0.2, 0.62));
      }
      expect(inc.toSet().length, 12);
      final nodes = {for (var s = 0; s < 12; s++) MoonLayout.nodeOf(s * 3.17).toStringAsFixed(3)};
      expect(nodes.length, 12);
    });

    test('moons start evenly around their world', () {
      final angles = [for (var j = 0; j < 4; j++) MoonLayout.initialAngle(j, 4, 0)];
      for (var j = 1; j < 4; j++) {
        expect(_wrap(angles[j] - angles[j - 1]), closeTo(math.pi / 2, 1e-9));
      }
    });
  });
}
