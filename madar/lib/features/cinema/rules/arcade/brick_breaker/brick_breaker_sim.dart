/// Brick Breaker: a paddle keeps a ball in play to break a wall of bricks.
///
/// Ball motion is resolved with swept circle-vs-box tests against the
/// walls, the paddle and every brick, up to several contacts per tick, so
/// the ball never tunnels at any speed. The paddle bounce angle depends on
/// where the ball lands (up to ±60° from vertical). Bricks have 1–3 hit
/// points or are unbreakable; the ball speeds up a little on every brick.
/// Clearing all breakable bricks starts the next (faster) level; losing the
/// ball costs a life.
library;

import 'dart:math' as math;

import '../core/arcade_sim.dart';
import '../core/geometry.dart';

final class BrickConfig {
  const BrickConfig({this.level = ArcadeLevel.medium, this.seed = 0, this.lives = 3});

  final ArcadeLevel level;
  final int seed;
  final int lives;

  static const double width = 240;
  static const double height = 320;
  static const double paddleY = 300;
  static const double paddleH = 6;
  static const double ballRadius = 4;

  double get paddleWidth => switch (level) {
    ArcadeLevel.easy => 52,
    ArcadeLevel.medium => 42,
    ArcadeLevel.hard => 34,
  };

  double get startSpeed => switch (level) {
    ArcadeLevel.easy => 150,
    ArcadeLevel.medium => 180,
    ArcadeLevel.hard => 210,
  };

  double get maxSpeed => startSpeed * 2;
}

/// Paddle control: a target x (pointer) or an axis (-1..1), plus a
/// one-shot launch.
final class BrickInput {
  const BrickInput({this.targetX, this.axis = 0, this.launch = false});
  static const BrickInput none = BrickInput();
  final double? targetX;
  final double axis;
  final bool launch;
}

final class Brick {
  Brick(this.box, this.hp);
  final Aabb box;

  /// Remaining hits; -1 is unbreakable; 0 is gone.
  int hp;
  bool get alive => hp != 0;
  bool get breakable => hp > 0;
}

final class BrickState {
  double paddleX = BrickConfig.width / 2;
  Vec2 ball = Vec2.zero;
  Vec2 velocity = Vec2.zero;
  bool attached = true;
  final List<Brick> bricks = [];
  int lives = 3;
  int level = 1;
  int score = 0;
  int hits = 0;
  bool over = false;
}

final class BrickBreakerSim extends FixedStepSim<BrickState, BrickInput> {
  BrickBreakerSim(this.config) : rng = SeededRng(config.seed), super(hz: 60) {
    _s.lives = config.lives;
    _buildLevel();
  }

  final BrickConfig config;
  final SeededRng rng;
  final BrickState _s = BrickState();

  static const double paddleSpeed = 320;

  @override
  ArcadeKind get kind => ArcadeKind.brickBreaker;

  @override
  BrickState get state => _s;

  @override
  int get score => _s.score;

  @override
  bool get isOver => _s.over;

  double get speed => math.min(config.maxSpeed, config.startSpeed * (1 + 0.1 * (_s.level - 1)) + 2.0 * _s.hits);

  Aabb get paddleBox => Aabb(
    _s.paddleX - config.paddleWidth / 2,
    BrickConfig.paddleY,
    _s.paddleX + config.paddleWidth / 2,
    BrickConfig.paddleY + BrickConfig.paddleH,
  );

  @override
  BrickInput heldOnly(BrickInput input) => BrickInput(targetX: input.targetX, axis: input.axis);

  @override
  BrickInput mergeInput(BrickInput earlier, BrickInput later) =>
      BrickInput(targetX: later.targetX, axis: later.axis, launch: earlier.launch || later.launch);

  /// Seeded wall: 6–9 rows × 10 columns, tougher rows on top, a few steel
  /// bricks from level 2.
  void _buildLevel() {
    _s.bricks.clear();
    const cols = 10;
    final rows = math.min(9, 5 + _s.level);
    const bw = BrickConfig.width / cols;
    const bh = 10.0;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (rng.nextInt(10) == 0) continue; // gaps
        var hp = 1 + (rows - 1 - r) ~/ 3;
        if (hp > 3) hp = 3;
        if (_s.level >= 2 && rng.nextInt(18) == 0) hp = -1;
        _s.bricks.add(Brick(Aabb(c * bw + 1, 40 + r * bh + 1, (c + 1) * bw - 1, 40 + (r + 1) * bh - 1), hp));
      }
    }
    if (!_s.bricks.any((b) => b.breakable)) _s.bricks.first.hp = 1;
    _attach();
  }

  void _attach() {
    _s.attached = true;
    _s.velocity = Vec2.zero;
    _s.ball = Vec2(_s.paddleX, BrickConfig.paddleY - BrickConfig.ballRadius - 0.5);
  }

  void _launch() {
    _s.attached = false;
    final angle = -math.pi / 2 + rng.nextDoubleRange(-0.35, 0.35);
    _s.velocity = Vec2.fromAngle(angle, speed);
  }

  @override
  void update(BrickInput input) {
    final dt = tickSeconds;
    // Paddle.
    final half = config.paddleWidth / 2;
    var x = _s.paddleX;
    if (input.targetX != null) {
      final dx = (input.targetX! - x).clamp(-paddleSpeed * dt, paddleSpeed * dt);
      x += dx;
    } else {
      x += input.axis.clamp(-1.0, 1.0) * paddleSpeed * dt;
    }
    _s.paddleX = x.clamp(half, BrickConfig.width - half);
    if (_s.attached) {
      _s.ball = Vec2(_s.paddleX, _s.ball.y);
      if (input.launch) _launch();
      return;
    }
    _moveBall(dt);
    if (_s.ball.y - BrickConfig.ballRadius > BrickConfig.height) {
      _s.lives--;
      if (_s.lives <= 0) {
        _s.over = true;
      } else {
        _attach();
      }
    }
    if (!_s.bricks.any((b) => b.breakable)) {
      _s.level++;
      _s.score += 100 * _s.level;
      _buildLevel();
    }
  }

  void _moveBall(double dt) {
    const r = BrickConfig.ballRadius;
    var remaining = 1.0;
    for (var iter = 0; iter < 8 && remaining > 1e-9; iter++) {
      final d = _s.velocity * (dt * remaining);
      SweepHit? best;
      Object? target;
      void consider(SweepHit? h, Object what) {
        if (h == null) return;
        // Ignore contacts we are already leaving.
        if (_s.velocity.dot(h.normal) >= 0) return;
        if (best == null || h.t < best!.t) {
          best = h;
          target = what;
        }
      }

      // Walls as thick boxes outside the field.
      consider(sweepCircleAabb(_s.ball, d, r, const Aabb(-100, -100, 0, BrickConfig.height + 100)), 'wall');
      consider(
        sweepCircleAabb(_s.ball, d, r, const Aabb(BrickConfig.width, -100, BrickConfig.width + 100, BrickConfig.height + 100)),
        'wall',
      );
      consider(sweepCircleAabb(_s.ball, d, r, const Aabb(-100, -100, BrickConfig.width + 100, 0)), 'wall');
      consider(sweepCircleAabb(_s.ball, d, r, paddleBox), 'paddle');
      for (final b in _s.bricks) {
        if (b.alive) consider(sweepCircleAabb(_s.ball, d, r, b.box), b);
      }
      if (best == null) {
        _s.ball = _s.ball + d;
        return;
      }
      final hit = best!;
      final t = math.max(0.0, hit.t - 1e-6);
      _s.ball = _s.ball + d * t;
      remaining *= 1 - t;
      if (target == 'paddle' && hit.normal.y < -0.5) {
        final offset = ((_s.ball.x - _s.paddleX) / (config.paddleWidth / 2 + r)).clamp(-1.0, 1.0);
        final angle = -math.pi / 2 + offset * (math.pi / 3);
        _s.velocity = Vec2.fromAngle(angle, speed);
      } else {
        _s.velocity = _s.velocity.reflect(hit.normal);
      }
      if (target is Brick) {
        final b = target! as Brick;
        if (b.breakable) {
          b.hp--;
          _s.hits++;
          _s.score += 10;
          if (b.hp == 0) _s.score += 5 * _s.level;
        }
        _s.velocity = _s.velocity.normalized * speed;
      }
      // Avoid perfectly horizontal loops.
      if (_s.velocity.y.abs() < speed * 0.15) {
        final sign = _s.velocity.y < 0 ? -1.0 : 1.0;
        _s.velocity = Vec2(_s.velocity.x, sign * speed * 0.15).normalized * speed;
      }
    }
  }

  @override
  Map<String, Object?> snapshot() => {
    'tick': tick,
    'paddle': r4(_s.paddleX),
    'ball': _s.ball.toJson(),
    'vel': _s.velocity.toJson(),
    'bricks': [for (final b in _s.bricks) b.hp],
    'lives': _s.lives,
    'level': _s.level,
    'score': _s.score,
  };
}
