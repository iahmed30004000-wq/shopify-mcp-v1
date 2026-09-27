import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/motion/particles/celebration.dart';
import 'package:madar/core/motion/particles/particle_atlas.dart';
import 'package:madar/core/motion/particles/particle_pool.dart';
import 'package:madar/core/motion/particles/particle_system.dart';

class _Rects implements SpriteRects {
  @override
  double left(int s) => s * 64.0;
  @override
  double top(int s) => 0;
  @override
  double right(int s) => s * 64.0 + (s == ParticleSprite.streak.index ? 16 : 64);
  @override
  double bottom(int s) => s == ParticleSprite.streak.index ? 96 : 64;
  @override
  double spriteWidth(int s) => right(s) - left(s);
  @override
  double spriteHeight(int s) => bottom(s) - top(s);
}

final _palette = CelebrationPalettes.of(CelebrationKind.stardust, MadarPalettes.tokensFor(MadarThemeId.lapis));

int _runUntilIdle(ParticleSystem sys, {double maxSeconds = 20}) {
  var peak = 0;
  var t = 0.0;
  while (!sys.isIdle && t < maxSeconds) {
    sys.step(1 / 60);
    t += 1 / 60;
    if (sys.pool.count > peak) peak = sys.pool.count;
    expect(sys.pool.count, lessThanOrEqualTo(sys.capacity));
  }
  expect(sys.isIdle, isTrue, reason: 'died out within $maxSeconds s');
  return peak;
}

void main() {
  test('every burst stays within capacity and dies out', () {
    final sys = ParticleSystem(capacity: 400, seed: 1);
    ParticlePresets.stardustBurst(sys, 100, 100, _palette);
    ParticlePresets.lanternSparksBurst(sys, 100, 300, _palette);
    ParticlePresets.lightRainBurst(sys, 200, 300, _palette);
    ParticlePresets.orbitalRingBurst(sys, 200, 200, 60, _palette);
    expect(sys.pool.count, greaterThan(50));
    final peak = _runUntilIdle(sys);
    expect(peak, lessThanOrEqualTo(400));
  });

  test('a flood of bursts saturates the pool but never exceeds it', () {
    final sys = ParticleSystem(capacity: 120, seed: 2);
    for (var i = 0; i < 20; i++) {
      ParticlePresets.stardustBurst(sys, 50, 50, _palette, intensity: 3);
    }
    expect(sys.pool.count, 120);
    _runUntilIdle(sys);
  });

  test('timed emitters finish; open-ended ones run until stopped', () {
    final sys = ParticleSystem(capacity: 600, seed: 3);
    final timed = LightRainEmitter(area: const Rect.fromLTWH(0, 0, 400, 800), palette: _palette, rate: 60, duration: 1);
    final open = LanternSparksEmitter(area: const Rect.fromLTWH(0, 700, 400, 60), palette: _palette);
    sys
      ..addEmitter(timed)
      ..addEmitter(open);
    for (var i = 0; i < 120; i++) {
      sys.step(1 / 60);
    }
    expect(timed.isActive, isFalse);
    expect(open.isActive, isTrue);
    expect(sys.emitterCount, 1);
    expect(sys.pool.count, greaterThan(0));
    open.stop();
    _runUntilIdle(sys);
  });

  test('ring and drift emitters produce particles', () {
    final sys = ParticleSystem(capacity: 300, seed: 4);
    sys
      ..addEmitter(OrbitalRingEmitter(cx: 100, cy: 100, radius: 50, palette: _palette, duration: 1))
      ..addEmitter(StardustDriftEmitter(area: const Rect.fromLTWH(0, 0, 300, 300), palette: _palette, duration: 1));
    for (var i = 0; i < 30; i++) {
      sys.step(1 / 60);
    }
    expect(sys.pool.count, greaterThan(5));
    _runUntilIdle(sys);
  });

  test('flashes are capped and fade', () {
    final sys = ParticleSystem(seed: 5);
    for (var i = 0; i < 10; i++) {
      sys.flash(10, 10, const Color(0xFFFFFFFF));
    }
    expect(sys.flashCount, ParticleSystem.flashCapacity);
    expect(sys.pool.count, 0);
    _runUntilIdle(sys);
  });

  test('render buffers hold exactly the drawn sprites with tinted alpha', () {
    final sys = ParticleSystem(capacity: 200, seed: 6);
    ParticlePresets.stardustBurst(sys, 100, 100, _palette);
    sys.step(1 / 30);
    final n = sys.prepareRender(_Rects());
    expect(n, greaterThan(0));
    expect(n, lessThanOrEqualTo(sys.pool.count + sys.flashCount));
    expect(sys.transforms.length, n * 4);
    expect(sys.rects.length, n * 4);
    expect(sys.colors.length, n);
    for (var i = 0; i < n; i++) {
      final alpha = (sys.colors[i] >> 24) & 0xFF;
      expect(alpha, inInclusiveRange(1, 255));
    }
    sys.clear();
    expect(sys.isIdle, isTrue);
    expect(sys.prepareRender(_Rects()), 0);
    expect(sys.transforms, isEmpty);
  });

  test('streaks are rotated along their velocity', () {
    final sys = ParticleSystem(capacity: 4, seed: 7);
    final p = sys.pool.obtain();
    sys.pool
      ..life[p] = 1
      ..vx[p] = 0
      ..vy[p] = 500
      ..size0[p] = 96
      ..size1[p] = 96
      ..fadeIn[p] = 0
      ..alignToVelocity[p] = 1
      ..sprite[p] = ParticleSprite.streak.index;
    sys.step(0.01);
    expect(sys.prepareRender(_Rects()), 1);
    // Falling straight down: no rotation (scos = scale, ssin = 0).
    expect(sys.transforms[0], closeTo(1, 1e-3));
    expect(sys.transforms[1], closeTo(0, 1e-3));
  });

  test('the procedural atlas paints and disposes', () {
    final atlas = ParticleAtlas.create();
    expect(atlas.image.width, ParticleAtlas.width);
    expect(atlas.spriteWidth(ParticleSprite.glow.index), 64);
    expect(atlas.spriteHeight(ParticleSprite.streak.index), 96);
    atlas.dispose();
    expect(atlas.isDisposed, isTrue);
  });
}
