import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show HSLColor;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/orbit/domain/scene_math.dart';
import 'package:madar/features/orbit/render/orbit_shaders.dart';
import 'package:madar/features/orbit/render/planets/planets.dart';

import 'planet_fixtures.dart';

double _hueDistance(double a, double b) {
  final d = (a - b).abs() % 360;
  return d > 180 ? 360 - d : d;
}

void main() {
  group('shader per archetype', () {
    test('each built-in world has its own shader; ice/desert borrow the closest', () {
      const expected = {
        PlanetArchetype.faith: OrbitShader.planetFaith,
        PlanetArchetype.ocean: OrbitShader.planetOcean,
        PlanetArchetype.terracotta: OrbitShader.planetTerracotta,
        PlanetArchetype.industrial: OrbitShader.planetIndustrial,
        PlanetArchetype.crystal: OrbitShader.planetCrystal,
        PlanetArchetype.verdant: OrbitShader.planetVerdant,
        PlanetArchetype.volcanic: OrbitShader.planetVolcanic,
        PlanetArchetype.gasGiant: OrbitShader.planetGasGiant,
        PlanetArchetype.ice: OrbitShader.planetCrystal,
        PlanetArchetype.desert: OrbitShader.planetTerracotta,
      };
      for (final a in PlanetArchetype.values) {
        expect(PlanetStyle.shaderOf(a), expected[a], reason: a.name);
        expect(shaderForArchetype(a), expected[a]);
      }
      expect({for (final a in PlanetArchetype.values.take(8)) PlanetStyle.shaderOf(a)}.length, 8);
    });

    test('halo factors come from the shader headers', () {
      for (final a in PlanetArchetype.values) {
        // Faith's rect also holds the dome standing proud of its pole.
        final want = switch (a) {
          PlanetArchetype.gasGiant => 2.3,
          PlanetArchetype.faith => 1.5,
          _ => 1.35,
        };
        expect(PlanetStyle.haloFactorOf(a), want, reason: a.name);
      }
      expect(OrbitShader.dataMoon.haloFactor, 1.6);
      expect(OrbitShader.sky.isBody, isFalse);
      expect(OrbitShader.dataMoon.isBody, isTrue);
      expect(OrbitShader.values.where((s) => s.isBody).length, 9);
    });

    test('every body shader asset is a registered orbit program', () {
      for (final s in OrbitShader.values) {
        expect(s.asset, startsWith('shaders/orbit/'));
        expect(s.asset, endsWith('.frag'));
      }
    });
  });

  group('borrowed styles', () {
    test('the eight worlds keep their palette', () {
      for (final a in PlanetArchetype.values.take(8)) {
        expect(identical(PlanetStyle.paletteOf(a, PlanetPalettes.money), PlanetPalettes.money), isTrue);
      }
    });

    test('ice is a frosted, cold recolour – never the Money jewel', () {
      final ice = PlanetStyle.paletteOf(PlanetArchetype.ice, PlanetPalettes.money);
      final s = HSLColor.fromColor(ice.surface);
      expect(s.lightness, greaterThan(0.7));
      expect(s.saturation, lessThanOrEqualTo(0.5));
      expect(HSLColor.fromColor(ice.glow).lightness, greaterThan(0.88));
      expect(HSLColor.fromColor(ice.deep).lightness, lessThan(0.25));
      expect(ice.surface, isNot(PlanetPalettes.money.surface));
      // Leaning cold from any hue (a warm user colour still reads icy).
      final fromWarm = PlanetStyle.paletteOf(PlanetArchetype.ice, PlanetPalettes.body);
      expect(
        _hueDistance(HSLColor.fromColor(fromWarm.glow).hue, 195),
        lessThan(_hueDistance(HSLColor.fromColor(PlanetPalettes.body.glow).hue, 195)),
      );
    });

    test('desert is a sun-bleached warm recolour – never the Family terracotta', () {
      final desert = PlanetStyle.paletteOf(PlanetArchetype.desert, PlanetPalettes.family);
      expect(desert.surface, isNot(PlanetPalettes.family.surface));
      final h = HSLColor.fromColor(desert.surface);
      expect(_hueDistance(h.hue, 34), lessThan(20));
      expect(HSLColor.fromColor(desert.glow).lightness, greaterThan(0.7));
      final fromCool = PlanetStyle.paletteOf(PlanetArchetype.desert, PlanetPalettes.travel);
      expect(
        _hueDistance(HSLColor.fromColor(fromCool.surface).hue, 34),
        lessThan(_hueDistance(HSLColor.fromColor(PlanetPalettes.travel.surface).hue, 34)),
      );
    });

    test('borrowed styles get their own seed, so the layout differs', () {
      final crystal = PlanetFixtures.body('money');
      final ice = PlanetFixtures.body('money', archetype: PlanetArchetype.ice);
      expect(ice.shader, crystal.shader);
      expect(ice.shaderSeed, isNot(crystal.shaderSeed));
      final desert = PlanetFixtures.custom('d', PlanetArchetype.desert);
      expect(desert.shaderSeed - desert.seed, closeTo(PlanetStyle.seedOffsetOf(PlanetArchetype.desert), 1e-9));
    });
  });

  group('per-planet motion', () {
    test('axial tilt is stable and the gas giant always opens its rings', () {
      for (var s = 0; s < 30; s++) {
        final seed = s * 1.37;
        expect(PlanetStyle.axialTiltOf(PlanetArchetype.verdant, seed), inInclusiveRange(0.16, 0.42));
        expect(PlanetStyle.axialTiltOf(PlanetArchetype.gasGiant, seed), inInclusiveRange(0.34, 0.42));
        expect(PlanetStyle.spinPeriodOf(seed), inInclusiveRange(70, 130));
      }
    });
  });

  group('PlanetUniforms', () {
    test('writes the planet uniform contract in declaration order', () {
      final u = PlanetUniforms()
        ..set(
          canvas: const Size(400, 900),
          center: const Offset(12, 34),
          radius: 56,
          time: 7,
          lightX: 0.1,
          lightY: 0.2,
          lightZ: 0.3,
          score: 0.4,
          pulse: 0.5,
          spin: 0.6,
          tilt: 0.7,
          spinZ: 0.8,
          colorA: const Color.from(alpha: 1, red: 0.25, green: 0.5, blue: 0.75),
          colorB: const Color.from(alpha: 0.5, red: 1, green: 0, blue: 0),
          colorC: const Color.from(alpha: 0, red: 0, green: 1, blue: 0),
          detail: 0.9,
          seed: 3.5,
          extra: const [6, 0.25],
        );
      final v = u.values;
      expect(v.length, 32);
      expect(v.sublist(0, 14), [
        400,
        900,
        12,
        34,
        56,
        7,
        closeTo(0.1, 1e-6),
        closeTo(0.2, 1e-6),
        closeTo(0.3, 1e-6),
        closeTo(0.4, 1e-6),
        0.5,
        closeTo(0.6, 1e-6),
        closeTo(0.7, 1e-6),
        closeTo(0.8, 1e-6),
      ]);
      expect(v.sublist(PlanetUniforms.iColorA, PlanetUniforms.iColorA + 4), [0.25, 0.5, 0.75, 1]);
      expect(v.sublist(PlanetUniforms.iColorB, PlanetUniforms.iColorB + 4), [1, 0, 0, 0.5]);
      expect(v.sublist(PlanetUniforms.iColorC, PlanetUniforms.iColorC + 4), [0, 1, 0, 0]);
      expect(v[PlanetUniforms.iDetail], closeTo(0.9, 1e-6));
      expect(v[PlanetUniforms.iSeed], 3.5);
      expect(v.sublist(PlanetUniforms.iExtra), [6, 0.25, 0, 0], reason: 'missing extras are 0');
      u.setExtra(1, 1);
      expect(v[PlanetUniforms.iExtra + 1], 1);
    });
  });

  group('PlanetViewMath', () {
    const cam = OrbitCamera(elevation: 0, azimuth: 0);
    final (r, u, f) = cam.basis;

    test('light points from the world toward the star, in view space', () {
      // A world to the right of the star: light comes from the left.
      final (x, y, z) = PlanetViewMath.lightInView(const V3(1, 0, 0), V3.zero, r, u, f);
      expect(x, lessThan(-0.9));
      expect(y, closeTo(0, 1e-9));
      expect(z, closeTo(PlanetViewMath.zBias, 1e-9));
      // Physically exact with no compression.
      final (px, _, pz) = PlanetViewMath.lightInView(const V3(1, 0, 0), V3.zero, r, u, f, bias: 0, scale: 1);
      expect(px, closeTo(-1, 1e-9));
      expect(pz, closeTo(0, 1e-9));
    });

    test('depth is only gently compressed: near worlds back-lit crescents, far worlds lit gibbous', () {
      // Between the camera and the star (slightly off-axis): a real
      // crescent (near and far worlds must not show the same phase).
      final (_, _, zb) = PlanetViewMath.lightInView(const V3(0.2, 0, 1), V3.zero, r, u, f);
      expect(zb, inInclusiveRange(-0.65, -0.5));
      // Behind the star.
      final (_, _, zf) = PlanetViewMath.lightInView(const V3(-0.2, 0, -1), V3.zero, r, u, f);
      expect(zf, inInclusiveRange(0.84, 0.92));
      expect(zf, greaterThan(zb), reason: 'order kept');
      // Exactly in line: light from above, still unit length.
      final (ax, ay, az) = PlanetViewMath.lightInView(const V3(0, 0, 1), V3.zero, r, u, f);
      expect(ax, 0);
      expect(ay, closeTo(math.sqrt(1 - az * az), 1e-9));
      expect(ay, greaterThan(0.75));
      expect(math.sqrt(ax * ax + ay * ay + az * az), closeTo(1, 1e-9));
      final (sx, sy, sz) = PlanetViewMath.lightInView(V3.zero, V3.zero, r, u, f);
      expect([sx, sy, sz], [0, 0, 1]);
    });

    test('level of detail follows the on-screen radius', () {
      expect(PlanetViewMath.detailFor(2), 0.04);
      expect(PlanetViewMath.detailFor(22), closeTo(0.1, 1e-9));
      expect(PlanetViewMath.detailFor(110), closeTo(0.5, 1e-9));
      expect(PlanetViewMath.detailFor(220), 1);
      expect(PlanetViewMath.detailFor(900), 1);
    });

    test('on-screen test with margin', () {
      const v = Size(400, 800);
      expect(PlanetViewMath.onScreen(const Rect.fromLTWH(10, 10, 5, 5), v), isTrue);
      expect(PlanetViewMath.onScreen(const Rect.fromLTWH(-20, 10, 19, 5), v), isTrue, reason: 'within margin');
      expect(PlanetViewMath.onScreen(const Rect.fromLTWH(-30, 10, 10, 5), v), isFalse);
      expect(PlanetViewMath.onScreen(const Rect.fromLTWH(10, 805, 5, 5), v), isFalse);
    });
  });
}
