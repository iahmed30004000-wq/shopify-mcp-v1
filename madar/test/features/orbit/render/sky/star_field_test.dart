import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/astro/astronomy.dart';
import 'package:madar/core/astro/star_catalog.dart';
import 'package:madar/features/orbit/domain/scene_math.dart';
import 'package:madar/features/orbit/render/sky/sky.dart';

import 'sky_fixtures.dart';

const _size = Size(412, 915);

void main() {
  final night = SkyModel.compute(SkyShot.newMoon.time, tone: testTone());
  final cam = SkyView.camera(night, _size);

  group('equatorial → ENU', () {
    test('matches Astro.toHorizontal for bright stars', () {
      final t = SkyShot.newMoon.time;
      for (final s in StarCatalog.stars.take(40)) {
        final h = Astro.toHorizontal(raDeg: s.raDeg, decDeg: s.decDeg, time: t, latitude: 31.9539, longitude: 35.9106);
        final (x, y, z) = s.unitVector;
        final v = enuOf(V3(x, y, z), night.localSiderealDeg, 31.9539);
        final expected = SkyModel.enu(h.altitude, h.azimuth);
        expect(math.acos(v.dot(expected).clamp(-1.0, 1.0)) * 180 / math.pi, lessThan(0.01));
      }
    });
  });

  group('StarField.project', () {
    test('only stars above the horizon, on screen and bright enough', () {
      final f = StarField()
        ..project(cam, lstDeg: night.localSiderealDeg, latitudeDeg: 31.9539, limitMagnitude: 4, gain: 1, force: true);
      expect(f.count, greaterThan(20));
      final (e, n, u) = equatorialToEnu(night.localSiderealDeg, 31.9539);
      for (var i = 0; i < f.count; i++) {
        final star = StarCatalog.stars[f.visibleIndex(i)];
        expect(star.magnitude, lessThanOrEqualTo(4.35));
        final (x, y, z) = star.unitVector;
        final eq = V3(x, y, z);
        final enu = V3(e.dot(eq), n.dot(eq), u.dot(eq));
        expect(enu.z, greaterThan(-0.005));
        final p = f.visiblePosition(i);
        final expected = cam.project(enu)!;
        expect((p - expected).distance, lessThan(0.05));
        expect((Offset.zero & _size).inflate(20).contains(p), isTrue);
      }
    });

    test('more stars as the sky darkens; none by day', () {
      final f = StarField();
      int count(double limit, double gain) {
        f.project(
          cam,
          lstDeg: night.localSiderealDeg,
          latitudeDeg: 31.9539,
          limitMagnitude: limit,
          gain: gain,
          force: true,
        );
        return f.count;
      }

      final c2 = count(2, 1), c4 = count(4, 1), c5 = count(5.3, 1);
      expect(c2, lessThan(c4));
      expect(c4, lessThan(c5));
      expect(count(5.3, 0), 0);
      expect(count(-2, 1), 0);
    });

    test('skips re-projection for sub-0.05° changes', () {
      final f = StarField();
      expect(f.project(cam, lstDeg: 10, latitudeDeg: 31.9539, limitMagnitude: 4, gain: 1), isTrue);
      final nudged = SkyCamera.fromAim(
        SkyAim(cam.aim.yaw + 0.02, cam.aim.pitch),
        viewport: cam.viewport,
        principal: cam.principal,
        fovY: 1.45,
      );
      final moved = SkyCamera.fromAim(
        SkyAim(cam.aim.yaw + 0.2, cam.aim.pitch),
        viewport: cam.viewport,
        principal: cam.principal,
        fovY: 1.45,
      );
      // `cam` itself came from SkyView (same fov) – reuse its aim.
      expect(f.project(nudged, lstDeg: 10, latitudeDeg: 31.9539, limitMagnitude: 4, gain: 1), isFalse);
      expect(f.project(nudged, lstDeg: 10.01, latitudeDeg: 31.9539, limitMagnitude: 4, gain: 1), isFalse);
      expect(f.project(moved, lstDeg: 10, latitudeDeg: 31.9539, limitMagnitude: 4, gain: 1), isTrue);
      expect(f.project(moved, lstDeg: 10.2, latitudeDeg: 31.9539, limitMagnitude: 4, gain: 1), isTrue);
      expect(f.project(moved, lstDeg: 10.2, latitudeDeg: 31.9539, limitMagnitude: 3, gain: 1), isTrue);
    });

    test('stars behind the moon are hidden', () {
      final f = StarField()
        ..project(cam, lstDeg: night.localSiderealDeg, latitudeDeg: 31.9539, limitMagnitude: 5.3, gain: 1, force: true);
      final p = f.visiblePosition(0);
      final before = f.count;
      f.project(
        cam,
        lstDeg: night.localSiderealDeg,
        latitudeDeg: 31.9539,
        limitMagnitude: 5.3,
        gain: 1,
        occluder: p,
        occluderRadius: 30,
      );
      expect(f.count, lessThan(before));
      for (var i = 0; i < f.count; i++) {
        expect((f.visiblePosition(i) - p).distance, greaterThanOrEqualTo(30));
      }
    });

    test('views are trimmed to the visible count and cached', () {
      final f = StarField()
        ..project(cam, lstDeg: night.localSiderealDeg, latitudeDeg: 31.9539, limitMagnitude: 4, gain: 1, force: true)
        ..colorize(0);
      final t = f.transformsView;
      expect(t.length, f.count * 4);
      expect(f.rectsView.length, f.count * 4);
      expect(f.colorsView.length, f.count);
      expect(identical(f.transformsView, t), isTrue);
    });
  });

  group('StarField.colorize', () {
    test('twinkle stays gentle and bounded; steady without it', () {
      final f = StarField()
        ..project(cam, lstDeg: night.localSiderealDeg, latitudeDeg: 31.9539, limitMagnitude: 5.3, gain: 1, force: true)
        ..colorize(0, twinkle: false);
      final base = [for (var i = 0; i < f.count; i++) (f.colors[i] >> 24) & 0xFF];
      for (var i = 0; i < f.count; i++) {
        expect(base[i], (f.visibleAlpha(i).clamp(0.0, 1.0) * 255).round());
      }
      var changed = 0;
      for (final t in [0.7, 3.1, 9.4]) {
        f.colorize(t);
        for (var i = 0; i < f.count; i++) {
          final a = (f.colors[i] >> 24) & 0xFF;
          if (a != base[i]) changed++;
          // At most ±36% (low stars scintillate most).
          expect(a, inInclusiveRange((base[i] * 0.6).floor(), math.min(255, (base[i] * 1.4).ceil())));
        }
      }
      expect(changed, greaterThan(f.count));
    });

    test('colours lean white with a hint of temperature and the theme tint', () {
      final f = StarField(tint: const Color(0xFFFFF1D6))
        ..project(cam, lstDeg: night.localSiderealDeg, latitudeDeg: 31.9539, limitMagnitude: 5.3, gain: 1, force: true)
        ..colorize(0, twinkle: false);
      for (var i = 0; i < f.count; i++) {
        final c = f.colors[i];
        final r = (c >> 16) & 0xFF, g = (c >> 8) & 0xFF, b = c & 0xFF;
        expect(math.min(r, math.min(g, b)), greaterThan(100));
      }
    });
  });

  group('StarNames', () {
    test('matches catalogue magnitudes', () {
      final names = StarNames();
      final sirius = names.all.firstWhere((n) => n.en == 'Sirius');
      expect(sirius.magnitude, closeTo(-1.46, 0.01));
      expect(sirius.label(true), 'الشعرى اليمانية');
      final pleiades = names.all.firstWhere((n) => n.en == 'Pleiades');
      expect(pleiades.magnitude, greaterThan(1));
    });

    test('labels sit beside their stars, inside the view, outside the keep-out and apart', () {
      final s = SkyModel.compute(SkyShot.milkyWay.time, tone: testTone());
      final names = StarNames();
      // Aim at Altair so several named stars (Altair, Vega, Deneb…) are in view.
      final altair = names.all.firstWhere((n) => n.en == 'Altair');
      final (alt, az) = SkyModel.altAz(enuOf(altair.eq, s.localSiderealDeg, 31.9539));
      final c = SkyCamera.fromAim(SkyAim(az, alt), viewport: _size, principal: const Offset(206, 366), fovY: 1.6);
      void layout({required bool rtl, Rect? keepOut, double opacity = 1}) => names.layout(
        c,
        lstDeg: s.localSiderealDeg,
        latitudeDeg: 31.9539,
        labelSize: (_) => const Size(56, 16),
        rtl: rtl,
        keepOut: keepOut,
        opacity: opacity,
        limitMagnitude: 2.5,
      );

      layout(rtl: true);
      expect(names.count, greaterThan(1));
      final first = names.placed[0].star;
      final bounds = (Offset.zero & _size).deflate(6);
      for (var i = 0; i < names.count; i++) {
        final a = names.placed[i];
        expect(bounds.contains(a.star), isTrue);
        expect(bounds.contains(a.rect.topLeft) && bounds.contains(a.rect.bottomRight), isTrue);
        // RTL: the text ends just before the star.
        expect(a.rect.right, closeTo(a.star.dx - 7, 1e-9));
        for (var j = 0; j < i; j++) {
          expect(names.placed[j].rect.overlaps(a.rect), isFalse);
        }
      }
      // A keep-out rect (the astrolabe) removes the labels inside it.
      final keepOut = Rect.fromCircle(center: first, radius: 40);
      layout(rtl: true, keepOut: keepOut);
      for (var i = 0; i < names.count; i++) {
        expect(names.placed[i].rect.overlaps(keepOut), isFalse);
        expect((names.placed[i].star - first).distance, greaterThan(1));
      }
      layout(rtl: false);
      expect(names.placed[0].rect.left, closeTo(names.placed[0].star.dx + 7, 1e-9));
      layout(rtl: false, opacity: 0);
      expect(names.count, 0);
    });
  });

  group('StarSprite', () {
    test('bright core, zero edges, spikes only on the bright cells', () {
      expect(StarSprite.intensity(0, 0, 0), closeTo(1, 1e-9));
      for (var k = 0; k < StarSpriteLayout.cells; k++) {
        expect(StarSprite.intensity(k, 0.999, 0), 0);
        expect(StarSprite.intensity(k, 0.8, 0.8), 0);
      }
      expect(StarSprite.intensity(1, 0.5, 0), greaterThan(StarSprite.intensity(0, 0.5, 0) * 2));
      expect(StarSprite.intensity(2, 0.3, 0.3), greaterThan(StarSprite.intensity(1, 0.3, 0.3)));
    });

    test('pixels are premultiplied white', () {
      final px = StarSprite.pixels();
      expect(px.length, StarSprite.width * StarSprite.height * 4);
      for (var i = 0; i < px.length; i += 4) {
        expect(px[i], px[i + 3]);
      }
    });

    test('cells follow magnitude', () {
      expect(StarSpriteLayout.cellFor(-1.46), StarSpriteLayout.spikes8);
      expect(StarSpriteLayout.cellFor(1.2), StarSpriteLayout.spikes4);
      expect(StarSpriteLayout.cellFor(3), StarSpriteLayout.round);
    });
  });
}
