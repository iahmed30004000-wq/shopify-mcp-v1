import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/orbit/domain/scene_math.dart';
import 'package:madar/features/orbit/render/sky/sky.dart';

import 'sky_fixtures.dart';

const _size = Size(412, 915);

void main() {
  group('SkyController', () {
    test('has no state until the theme is known', () {
      final c = SkyController(time: SkyShot.night.time);
      addTearDown(c.dispose);
      expect(c.state, isNull);
      expect(c.frameFor(_size), isNull);
      c.tone = testTone();
      expect(c.state, isNotNull);
      expect(c.state!.mood, SkyMood.night);
    });

    test('recomputes the sky only for ≥ 1 s of sky time', () {
      final c = SkyController(time: SkyShot.night.time, tone: testTone());
      addTearDown(c.dispose);
      final v = c.stateVersion;
      c.time = SkyShot.night.time.add(const Duration(milliseconds: 400));
      expect(c.stateVersion, v);
      c.time = SkyShot.night.time.add(const Duration(seconds: 2));
      expect(c.stateVersion, v + 1);
    });

    test('frames are cached until an input changes', () {
      final c = SkyController(time: SkyShot.night.time, tone: testTone());
      addTearDown(c.dispose);
      final a = c.frameFor(_size)!;
      expect(identical(c.frameFor(_size), a), isTrue);
      final v = c.inputsVersion;
      c.camera = const OrbitCamera(); // same camera: nothing to do
      expect(c.inputsVersion, v);
      expect(identical(c.frameFor(_size), a), isTrue);
      c.camera = const OrbitCamera(azimuth: 0.4);
      final b = c.frameFor(_size)!;
      expect(identical(b, a), isFalse);
      expect(b.camera.aim.yaw, isNot(a.camera.aim.yaw));
      // Another layer's size does not disturb the cache.
      c.peekFrame(const Size(200, 200));
      expect(identical(c.frameFor(_size), b), isTrue);
    });

    test('the moon is on screen at 22:30 and absent when it is down', () {
      final c = SkyController(time: SkyShot.night.time, tone: testTone());
      addTearDown(c.dispose);
      final f = c.frameFor(_size)!;
      expect(f.moonCenter, isNotNull);
      expect(f.moonVisibility, 1);
      expect(f.moonLight.z, greaterThan(0.9));
      c.time = SkyShot.newMoon.time;
      expect(c.frameFor(_size)!.moonCenter, isNull);
    });

    test('backdrop repaints only for view changes beyond 0.05°, then a still is scheduled', () {
      final c = SkyController(time: SkyShot.night.time, tone: testTone());
      addTearDown(c.dispose);
      final f = c.frameFor(_size)!;
      c.notePaintedBackdrop(f);
      var fired = 0;
      c.backdrop.addListener(() => fired++);
      // 0.01 rad of orbit azimuth → 0.07° of sky: repaint.
      c.camera = const OrbitCamera(azimuth: 0.01);
      expect(fired, 1);
      c.notePaintedBackdrop(c.frameFor(_size)!);
      // 0.004 rad → 0.027°: no repaint.
      c.camera = const OrbitCamera(azimuth: 0.014);
      expect(fired, 1);
      expect(c.backdropMatches(c.frameFor(_size)!), isTrue);
      final epoch = c.captureEpoch;
      c.advanceSeconds(0.1);
      expect(c.captureEpoch, epoch);
      c.advanceSeconds(0.2);
      expect(c.captureEpoch, epoch + 1);
      expect(fired, 2);
      c.advanceSeconds(1);
      expect(c.captureEpoch, epoch + 1); // once per change
    });

    test('advance runs the shader clock unless motion is reduced or the sky is still', () {
      final c = SkyController(time: SkyShot.night.time, tone: testTone());
      addTearDown(c.dispose);
      var ticks = 0;
      c.addListener(() => ticks++);
      c.advanceSeconds(0.5);
      expect(c.seconds, closeTo(0.5, 1e-9));
      expect(ticks, greaterThan(0));
      expect(c.twinkling, isTrue);
      c.reducedMotion = true;
      c.advanceSeconds(0.5);
      expect(c.seconds, closeTo(0.5, 1e-9));
      expect(c.twinkling, isFalse);
      c
        ..reducedMotion = false
        ..still = true;
      c.advanceSeconds(0.5);
      expect(c.seconds, closeTo(0.5, 1e-9));
    });

    test('follows its clock every step', () {
      var now = SkyShot.golden.time;
      final c = SkyController(clock: () => now, clockStep: const Duration(seconds: 10), tone: testTone());
      addTearDown(c.dispose);
      expect(c.time, SkyShot.golden.time);
      now = SkyShot.maghrib.time;
      c.advanceSeconds(5);
      expect(c.time, SkyShot.golden.time);
      c.advanceSeconds(6);
      expect(c.time, SkyShot.maghrib.time);
      expect(c.state!.mood, SkyMood.dusk);
    });

    test('flare: none without a source; motion brightens it', () {
      final c = SkyController(time: SkyShot.night.time, tone: testTone());
      addTearDown(c.dispose);
      expect(c.coreFlareIntensity, 0);
      c.coreStar = const Offset(206, 366);
      c.advanceSeconds(1 / 60);
      final rest = c.coreFlareIntensity;
      expect(rest, greaterThan(0));
      for (var i = 0; i < 20; i++) {
        c
          ..camera = OrbitCamera(azimuth: i * 0.03)
          ..advanceSeconds(1 / 60);
      }
      expect(c.angularSpeed, greaterThan(1));
      expect(c.coreFlareIntensity, greaterThan(rest));
      c.pulse = 1;
      expect(c.coreFlareIntensity, greaterThan(rest));
    });

    test('star names toggle and language invalidate the view', () {
      final c = SkyController(time: SkyShot.newMoon.time, tone: testTone());
      addTearDown(c.dispose);
      final v = c.inputsVersion;
      c.showStarNames = false;
      expect(c.inputsVersion, greaterThan(v));
      final w = c.inputsVersion;
      c.arabicNames = false;
      expect(c.inputsVersion, greaterThan(w));
      c.labelKeepOut = const Rect.fromLTWH(0, 0, 10, 10);
      expect(c.inputsVersion, greaterThan(w + 1));
    });
  });
}
