/// Asteroid Belt: a wrap-around shooter with inertia and splitting rocks.
///
/// The ship rotates, thrusts (with drag and a speed cap) and fires bullets
/// that live a short time; everything wraps around the screen edges. Large
/// rocks split into two medium ones, medium into two small ones, small ones
/// vanish (20 / 50 / 100 points). A cleared belt starts a bigger wave. A
/// collision costs a life; the ship respawns in the centre once it is clear,
/// with brief invulnerability. Hyperspace jumps to a random spot.
library;

import 'dart:math' as math;

import '../core/arcade_sim.dart';
import '../core/geometry.dart';

final class AsteroidConfig {
  const AsteroidConfig({this.level = ArcadeLevel.medium, this.seed = 0, this.lives = 3});

  final ArcadeLevel level;
  final int seed;
  final int lives;

  static const double width = 320;
  static const double height = 240;

  double get rockSpeedScale => switch (level) {
    ArcadeLevel.easy => 0.75,
    ArcadeLevel.medium => 1.0,
    ArcadeLevel.hard => 1.3,
  };
}

final class AsteroidInput {
  const AsteroidInput({this.turn = 0, this.thrust = false, this.fire = false, this.hyperspace = false});
  static const AsteroidInput none = AsteroidInput();

  /// -1 (counter-clockwise) … 1 (clockwise).
  final double turn;
  final bool thrust;

  /// Held: auto-fire at the weapon rate.
  final bool fire;

  /// One-shot.
  final bool hyperspace;
}

final class Rock {
  Rock(this.size, this.pos, this.vel);

  /// 3 large, 2 medium, 1 small.
  final int size;
  Vec2 pos;
  final Vec2 vel;
  bool alive = true;

  double get radius => const [0.0, 6.0, 12.0, 22.0][size];
  int get points => const [0, 100, 50, 20][size];
}

final class Bullet {
  Bullet(this.pos, this.vel);
  Vec2 pos;
  final Vec2 vel;
  double life = 0.9;
}

final class AsteroidState {
  Vec2 ship = const Vec2(AsteroidConfig.width / 2, AsteroidConfig.height / 2);
  Vec2 shipVel = Vec2.zero;

  /// Heading in radians; 0 points up the screen.
  double angle = 0;
  bool alive = true;
  double respawn = 0;
  double invulnerable = 2;
  double cooldown = 0;
  double hyperCooldown = 0;
  final List<Rock> rocks = [];
  final List<Bullet> bullets = [];
  int lives = 3;
  int score = 0;
  int wave = 0;
  bool over = false;

  Vec2 get facing => Vec2(math.sin(angle), -math.cos(angle));
}

final class AsteroidBeltSim extends FixedStepSim<AsteroidState, AsteroidInput> {
  AsteroidBeltSim(this.config) : rng = SeededRng(config.seed), super(hz: 60) {
    _s.lives = config.lives;
    _nextWave();
  }

  final AsteroidConfig config;
  final SeededRng rng;
  final AsteroidState _s = AsteroidState();

  static const double shipRadius = 6;
  static const double turnRate = 4;
  static const double thrustAccel = 200;
  static const double maxSpeed = 220;
  static const double bulletSpeed = 300;
  static const int maxBullets = 6;

  @override
  ArcadeKind get kind => ArcadeKind.asteroidBelt;

  @override
  AsteroidState get state => _s;

  @override
  int get score => _s.score;

  @override
  bool get isOver => _s.over;

  @override
  AsteroidInput heldOnly(AsteroidInput input) =>
      AsteroidInput(turn: input.turn, thrust: input.thrust, fire: input.fire);

  @override
  AsteroidInput mergeInput(AsteroidInput earlier, AsteroidInput later) => AsteroidInput(
    turn: later.turn,
    thrust: later.thrust,
    fire: later.fire,
    hyperspace: earlier.hyperspace || later.hyperspace,
  );

  Vec2 _randomVel(int size) {
    final speed = rng.nextDoubleRange(20.0 + 15 * (3 - size), 45.0 + 30 * (3 - size)) * config.rockSpeedScale;
    return Vec2.fromAngle(rng.nextDoubleRange(0, 2 * math.pi), speed);
  }

  void _nextWave() {
    _s.wave++;
    final count = math.min(11, 3 + _s.wave);
    for (var i = 0; i < count; i++) {
      Vec2 p;
      var guard = 0;
      do {
        p = Vec2(rng.nextDoubleRange(0, AsteroidConfig.width), rng.nextDoubleRange(0, AsteroidConfig.height));
      } while (wrapDelta(p, _s.ship, AsteroidConfig.width, AsteroidConfig.height).length < 80 && ++guard < 50);
      _s.rocks.add(Rock(3, p, _randomVel(3)));
    }
  }

  Vec2 _wrap(Vec2 p) => wrapPoint(p, AsteroidConfig.width, AsteroidConfig.height);

  bool _hits(Vec2 a, double ra, Vec2 b, double rb) =>
      wrapDelta(a, b, AsteroidConfig.width, AsteroidConfig.height).length < ra + rb;

  @override
  void update(AsteroidInput input) {
    final dt = tickSeconds;
    // Rocks drift.
    for (final r in _s.rocks) {
      r.pos = _wrap(r.pos + r.vel * dt);
    }
    // Bullets.
    for (final b in _s.bullets) {
      b.pos = _wrap(b.pos + b.vel * dt);
      b.life -= dt;
    }
    _s.bullets.removeWhere((b) => b.life <= 0);
    // Ship.
    _s.cooldown = math.max(0, _s.cooldown - dt);
    _s.hyperCooldown = math.max(0, _s.hyperCooldown - dt);
    _s.invulnerable = math.max(0, _s.invulnerable - dt);
    if (!_s.alive) {
      _s.respawn -= dt;
      final clear = !_s.rocks.any((r) => _hits(r.pos, r.radius, _s.ship, 50));
      if (_s.respawn <= 0 && clear) {
        _s.alive = true;
        _s.invulnerable = 2;
      }
    } else {
      _s.angle += input.turn.clamp(-1.0, 1.0) * turnRate * dt;
      if (input.thrust) _s.shipVel = _s.shipVel + _s.facing * (thrustAccel * dt);
      _s.shipVel = _s.shipVel * (1 - 0.4 * dt);
      if (_s.shipVel.length > maxSpeed) _s.shipVel = _s.shipVel.normalized * maxSpeed;
      _s.ship = _wrap(_s.ship + _s.shipVel * dt);
      if (input.hyperspace && _s.hyperCooldown == 0) {
        _s.ship = Vec2(rng.nextDoubleRange(0, AsteroidConfig.width), rng.nextDoubleRange(0, AsteroidConfig.height));
        _s.shipVel = Vec2.zero;
        _s.hyperCooldown = 3;
      }
      if (input.fire && _s.cooldown == 0 && _s.bullets.length < maxBullets) {
        _s.bullets.add(Bullet(_s.ship + _s.facing * shipRadius, _s.shipVel + _s.facing * bulletSpeed));
        _s.cooldown = 0.25;
      }
    }
    // Bullets vs rocks.
    final born = <Rock>[];
    for (final b in _s.bullets) {
      if (b.life <= 0) continue;
      for (final r in _s.rocks) {
        if (!r.alive || !_hits(b.pos, 1, r.pos, r.radius)) continue;
        r.alive = false;
        b.life = 0;
        _s.score += r.points;
        if (r.size > 1) {
          for (var k = 0; k < 2; k++) {
            born.add(Rock(r.size - 1, r.pos, _randomVel(r.size - 1)));
          }
        }
        break;
      }
    }
    _s.bullets.removeWhere((b) => b.life <= 0);
    // Ship vs rocks.
    if (_s.alive && _s.invulnerable == 0) {
      for (final r in _s.rocks) {
        if (r.alive && _hits(r.pos, r.radius, _s.ship, shipRadius * 0.8)) {
          r.alive = false;
          _s.score += r.points;
          if (r.size > 1) {
            for (var k = 0; k < 2; k++) {
              born.add(Rock(r.size - 1, r.pos, _randomVel(r.size - 1)));
            }
          }
          _s.lives--;
          _s.alive = false;
          _s.respawn = 1.5;
          _s.ship = const Vec2(AsteroidConfig.width / 2, AsteroidConfig.height / 2);
          _s.shipVel = Vec2.zero;
          _s.angle = 0;
          if (_s.lives <= 0) _s.over = true;
          break;
        }
      }
    }
    _s.rocks
      ..removeWhere((r) => !r.alive)
      ..addAll(born);
    if (_s.rocks.isEmpty) _nextWave();
  }

  @override
  Map<String, Object?> snapshot() => {
    'tick': tick,
    'ship': _s.ship.toJson(),
    'vel': _s.shipVel.toJson(),
    'angle': r4(_s.angle),
    'rocks': [
      for (final r in _s.rocks) [r.size, ...r.pos.toJson()],
    ],
    'bullets': [for (final b in _s.bullets) b.pos.toJson()],
    'lives': _s.lives,
    'wave': _s.wave,
    'score': _s.score,
    'rng': rng.state,
  };
}
