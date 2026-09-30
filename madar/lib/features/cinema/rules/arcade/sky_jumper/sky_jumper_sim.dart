/// Sky Jumper: bounce ever upwards on generated platforms.
///
/// Heights grow upwards (y is altitude). The jumper bounces automatically
/// when it lands on a platform while falling (a swept vertical test, so no
/// platform is skipped at speed); the horizontal input steers and the world
/// wraps left–right. Platforms are generated ahead of the camera with
/// vertical gaps capped below the reachable jump height, so a solid
/// platform is always within reach; some move, some crumble on contact
/// (without bouncing), some carry a spring. Falling below the screen ends
/// the run; the score is the best altitude.
library;

import 'dart:math' as math;

import '../core/arcade_sim.dart';

final class SkyConfig {
  const SkyConfig({this.level = ArcadeLevel.medium, this.seed = 0});

  final ArcadeLevel level;
  final int seed;

  static const double width = 240;
  static const double screenHeight = 400;
  static const double gravity = 900;
  static const double jumpSpeed = 520;
  static const double springFactor = 1.6;
  static const double moveSpeed = 220;
  static const double platformWidth = 44;
  static const double radius = 10;

  /// Apex height of a normal bounce.
  static double get maxJump => jumpSpeed * jumpSpeed / (2 * gravity);

  /// Largest vertical gap between consecutive solid platforms.
  double get maxGap => maxJump * switch (level) {
    ArcadeLevel.easy => 0.55,
    ArcadeLevel.medium => 0.7,
    ArcadeLevel.hard => 0.8,
  };
}

final class SkyInput {
  const SkyInput([this.axis = 0]);
  static const SkyInput none = SkyInput();
  final double axis;
}

enum PlatformKind { normal, moving, crumbling, spring }

final class SkyPlatform {
  SkyPlatform(this.kind, this.x, this.y, [this.vx = 0]);
  final PlatformKind kind;

  /// Left edge.
  double x;
  final double y;
  double vx;
  bool broken = false;

  bool get solid => kind != PlatformKind.crumbling;
}

final class SkyState {
  double x = SkyConfig.width / 2;
  double y = 20;
  double vy = SkyConfig.jumpSpeed;
  double camera = 0;
  double best = 0;
  final List<SkyPlatform> platforms = [];
  double generatedTo = 0;
  double lastSolid = 0;
  int bounces = 0;
  bool over = false;
}

final class SkyJumperSim extends FixedStepSim<SkyState, SkyInput> {
  SkyJumperSim(this.config) : rng = SeededRng(config.seed), super(hz: 60) {
    _s.platforms.add(SkyPlatform(PlatformKind.normal, SkyConfig.width / 2 - SkyConfig.platformWidth / 2, 10));
    _s.generatedTo = 10;
    _s.lastSolid = 10;
    _generate();
  }

  final SkyConfig config;
  final SeededRng rng;
  final SkyState _s = SkyState();

  @override
  ArcadeKind get kind => ArcadeKind.skyJumper;

  @override
  SkyState get state => _s;

  @override
  int get score => _s.best.floor();

  @override
  bool get isOver => _s.over;

  void _generate() {
    final minGap = config.maxGap * 0.35;
    while (_s.generatedTo < _s.camera + SkyConfig.screenHeight * 2) {
      // Difficulty ramps with altitude: gaps widen towards the cap.
      final ramp = math.min(1.0, _s.generatedTo / 6000);
      final hiGap = minGap + (config.maxGap - minGap) * (0.5 + 0.5 * ramp);
      var y = _s.generatedTo + rng.nextDoubleRange(minGap, hiGap);
      final x = rng.nextDoubleRange(0, SkyConfig.width - SkyConfig.platformWidth);
      final roll = rng.nextDouble();
      PlatformKind kind;
      if (roll < 0.12 * (0.5 + ramp)) {
        kind = PlatformKind.crumbling;
      } else if (roll < 0.3 * (0.5 + ramp)) {
        kind = PlatformKind.moving;
      } else if (roll < 0.36) {
        kind = PlatformKind.spring;
      } else {
        kind = PlatformKind.normal;
      }
      // Never leave a solid-free stretch taller than the cap.
      if (kind == PlatformKind.crumbling && y + minGap - _s.lastSolid > config.maxGap) {
        kind = PlatformKind.normal;
      }
      if (kind.index != PlatformKind.crumbling.index && y - _s.lastSolid > config.maxGap) {
        y = _s.lastSolid + config.maxGap;
      }
      final vx = kind == PlatformKind.moving ? rng.nextDoubleRange(40, 80) * (rng.nextBool() ? 1 : -1) : 0.0;
      _s.platforms.add(SkyPlatform(kind, x, y, vx));
      _s.generatedTo = y;
      if (kind != PlatformKind.crumbling) _s.lastSolid = y;
    }
    _s.platforms.removeWhere((p) => p.y < _s.camera - 100);
  }

  /// Horizontal overlap with wrap-around.
  bool _overlapsX(double px, SkyPlatform p) {
    for (final shift in const [-SkyConfig.width, 0.0, SkyConfig.width]) {
      final l = p.x + shift, r = p.x + shift + SkyConfig.platformWidth;
      if (px + SkyConfig.radius * 0.6 >= l && px - SkyConfig.radius * 0.6 <= r) return true;
    }
    return false;
  }

  @override
  void update(SkyInput input) {
    final dt = tickSeconds;
    for (final p in _s.platforms) {
      if (p.kind != PlatformKind.moving) continue;
      p.x += p.vx * dt;
      if (p.x < 0) {
        p.x = -p.x;
        p.vx = -p.vx;
      } else if (p.x > SkyConfig.width - SkyConfig.platformWidth) {
        p.x = 2 * (SkyConfig.width - SkyConfig.platformWidth) - p.x;
        p.vx = -p.vx;
      }
    }
    _s.x = (_s.x + input.axis.clamp(-1.0, 1.0) * SkyConfig.moveSpeed * dt) % SkyConfig.width;
    final prevY = _s.y;
    _s.vy -= SkyConfig.gravity * dt;
    _s.y += _s.vy * dt;
    if (_s.vy < 0) {
      // Swept landing: the feet crossed a platform top this tick.
      SkyPlatform? landed;
      for (final p in _s.platforms) {
        if (p.broken) continue;
        if (prevY >= p.y && _s.y <= p.y && _overlapsX(_s.x, p)) {
          if (landed == null || p.y > landed.y) landed = p;
        }
      }
      if (landed != null) {
        if (landed.kind == PlatformKind.crumbling) {
          landed.broken = true;
        } else {
          _s.y = landed.y;
          _s.vy = SkyConfig.jumpSpeed * (landed.kind == PlatformKind.spring ? SkyConfig.springFactor : 1);
          _s.bounces++;
        }
      }
    }
    if (_s.y > _s.best) _s.best = _s.y;
    _s.camera = math.max(_s.camera, _s.y - SkyConfig.screenHeight * 0.4);
    if (_s.y < _s.camera - 40) _s.over = true;
    _generate();
  }

  @override
  Map<String, Object?> snapshot() => {
    'tick': tick,
    'x': r4(_s.x),
    'y': r4(_s.y),
    'vy': r4(_s.vy),
    'camera': r4(_s.camera),
    'platforms': [
      for (final p in _s.platforms) [p.kind.index, r4(p.x), r4(p.y), p.broken],
    ],
    'best': r4(_s.best),
    'rng': rng.state,
  };
}
