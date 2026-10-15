/// Pinball: a small table with two flippers, three pop bumpers, two
/// slingshots, three top rollovers and a plunger lane.
///
/// Physics ("rigid body lite"): one ball (a circle) against static segments
/// (capsules), circles and two rotating flipper capsules. The simulation
/// ticks at 120 Hz with four substeps per tick; the speed cap keeps the
/// travel per substep well below the ball radius, and every contact is
/// resolved by projection plus an impulse on the relative normal velocity
/// (flippers transfer their surface velocity `ω × r`), so the ball cannot
/// tunnel and the energy stays bounded. Pop bumpers and slingshots kick the
/// ball away at a fixed speed.
///
/// Units: the table is 20 × 36, y grows towards the player; gravity is the
/// table's tilt.
library;

import 'dart:math' as math;

import '../core/arcade_sim.dart';
import '../core/geometry.dart';

final class PinballConfig {
  const PinballConfig({this.balls = 3, this.seed = 0});

  final int balls;
  final int seed;

  static const double width = 20;
  static const double height = 36;
  static const double ballRadius = 0.5;
  static const double gravity = 20;
  static const double maxSpeed = 45;
  static const int substeps = 4;
}

final class PinballInput {
  const PinballInput({this.left = false, this.right = false, this.launch = false, this.power = 1});
  static const PinballInput none = PinballInput();

  /// Held flipper buttons.
  final bool left;
  final bool right;

  /// One-shot plunger release with [power] in 0..1.
  final bool launch;
  final double power;
}

/// A static wall segment.
final class PinSegment {
  const PinSegment(this.a, this.b, {this.kick = 0, this.id = -1});
  final Vec2 a;
  final Vec2 b;

  /// Kick speed for slingshot faces (0 = plain wall).
  final double kick;
  final int id;
}

final class PinBumper {
  const PinBumper(this.center, this.radius, this.id);
  final Vec2 center;
  final double radius;
  final int id;
}

final class Flipper {
  Flipper(this.pivot, this.length, this.rest, this.up) : angle = rest;
  final Vec2 pivot;
  final double length;
  final double rest;
  final double up;
  double angle;

  /// Angular velocity over the last substep (rad/s).
  double omega = 0;

  static const double radius = 0.3;

  Vec2 get tip => pivot + Vec2.fromAngle(angle, length);
}

/// The fixed table layout.
abstract final class PinballTable {
  static const double laneX = 18.6;
  static const Vec2 plungerRest = Vec2(19.3, 34.8);

  static final List<PinSegment> walls = [
    // Outer shell with a rounded top.
    const PinSegment(Vec2(0, 34), Vec2(0, 6)),
    const PinSegment(Vec2(0, 6), Vec2(1.2, 3)),
    const PinSegment(Vec2(1.2, 3), Vec2(3.5, 1)),
    const PinSegment(Vec2(3.5, 1), Vec2(6.5, 0)),
    const PinSegment(Vec2(6.5, 0), Vec2(13.5, 0)),
    const PinSegment(Vec2(13.5, 0), Vec2(16.5, 1)),
    const PinSegment(Vec2(16.5, 1), Vec2(18.8, 3)),
    const PinSegment(Vec2(18.8, 3), Vec2(20, 6)),
    const PinSegment(Vec2(20, 6), Vec2(20, 36)),
    // Plunger lane inner wall and the plunger tip.
    const PinSegment(Vec2(laneX, 36), Vec2(laneX, 9)),
    const PinSegment(Vec2(laneX, 35.4), Vec2(20, 35.4)),
    // Funnels towards the flipper pivots.
    const PinSegment(Vec2(0, 27.5), Vec2(4.9, 31.6)),
    const PinSegment(Vec2(laneX, 27.5), Vec2(13.7, 31.6)),
    // Slingshot bodies.
    const PinSegment(Vec2(2.2, 23.5), Vec2(2.2, 27.4)),
    const PinSegment(Vec2(2.2, 27.4), Vec2(4.4, 28.6)),
    const PinSegment(Vec2(16.4, 23.5), Vec2(16.4, 27.4)),
    const PinSegment(Vec2(16.4, 27.4), Vec2(14.2, 28.6)),
  ];

  /// Slingshot kicking faces.
  static final List<PinSegment> kickers = [
    const PinSegment(Vec2(2.2, 23.5), Vec2(4.4, 28.6), kick: 16, id: 0),
    const PinSegment(Vec2(16.4, 23.5), Vec2(14.2, 28.6), kick: 16, id: 1),
  ];

  static final List<PinBumper> bumpers = [
    const PinBumper(Vec2(5.5, 9.5), 1.3, 0),
    const PinBumper(Vec2(13.1, 9.5), 1.3, 1),
    const PinBumper(Vec2(9.3, 13.5), 1.3, 2),
  ];

  /// Rollover sensors (no collision).
  static const List<Vec2> rollovers = [Vec2(7.5, 4), Vec2(9.3, 4), Vec2(11.1, 4)];
}

final class PinballState {
  Vec2 ball = PinballTable.plungerRest;
  Vec2 velocity = Vec2.zero;
  bool onPlunger = true;
  final Flipper left = Flipper(const Vec2(5.2, 31.8), 3.6, 0.5, -0.45);
  final Flipper right = Flipper(const Vec2(13.4, 31.8), 3.6, math.pi - 0.5, math.pi + 0.45);
  int ballsLeft = 3;
  int score = 0;
  int multiplier = 1;
  final List<bool> lit = [false, false, false];
  final List<bool> inRollover = [false, false, false];
  int bumperHits = 0;
  int kickerHits = 0;
  int flipperHits = 0;
  bool over = false;
}

final class PinballSim extends FixedStepSim<PinballState, PinballInput> {
  PinballSim([this.config = const PinballConfig()]) : rng = SeededRng(config.seed), super(hz: 120, maxTicksPerStep: 12) {
    _s.ballsLeft = config.balls;
  }

  final PinballConfig config;
  final SeededRng rng;
  final PinballState _s = PinballState();

  static const double flipUpSpeed = 28;
  static const double flipDownSpeed = 16;
  static const double wallRestitution = 0.45;
  static const double flipperRestitution = 0.35;
  static const double bumperKick = 22;

  @override
  ArcadeKind get kind => ArcadeKind.pinball;

  @override
  PinballState get state => _s;

  @override
  int get score => _s.score;

  @override
  bool get isOver => _s.over;

  @override
  PinballInput heldOnly(PinballInput input) => PinballInput(left: input.left, right: input.right);

  @override
  PinballInput mergeInput(PinballInput earlier, PinballInput later) => PinballInput(
    left: later.left,
    right: later.right,
    launch: earlier.launch || later.launch,
    power: later.launch ? later.power : earlier.power,
  );

  /// Places the ball (tests / tools).
  void placeBall(Vec2 p, [Vec2 v = Vec2.zero]) {
    _s.ball = p;
    _s.velocity = v;
    _s.onPlunger = false;
  }

  @override
  void update(PinballInput input) {
    final h = tickSeconds / PinballConfig.substeps;
    if (_s.onPlunger) {
      _s.ball = PinballTable.plungerRest;
      _s.velocity = Vec2.zero;
      if (input.launch) {
        _s.onPlunger = false;
        // A little seeded variation keeps launches from being identical.
        final power = input.power.clamp(0.0, 1.0);
        _s.velocity = Vec2(0, -(30 + 12 * power + rng.nextDoubleRange(-0.5, 0.5)));
      }
    }
    for (var k = 0; k < PinballConfig.substeps && !_s.over; k++) {
      _moveFlipper(_s.left, input.left, h);
      _moveFlipper(_s.right, input.right, h);
      if (!_s.onPlunger) _substep(h);
    }
  }

  void _moveFlipper(Flipper f, bool pressed, double h) {
    final target = pressed ? f.up : f.rest;
    final speed = pressed ? flipUpSpeed : flipDownSpeed;
    final before = f.angle;
    final delta = (target - f.angle).clamp(-speed * h, speed * h);
    f.angle += delta;
    f.omega = (f.angle - before) / h;
  }

  void _substep(double h) {
    const r = PinballConfig.ballRadius;
    var v = _s.velocity + const Vec2(0, PinballConfig.gravity) * h;
    if (v.length > PinballConfig.maxSpeed) v = v.normalized * PinballConfig.maxSpeed;
    _s.velocity = v;
    _s.ball = _s.ball + v * h;
    for (final w in PinballTable.walls) {
      _segment(w.a, w.b, r, wallRestitution);
    }
    for (final kck in PinballTable.kickers) {
      if (_segment(kck.a, kck.b, r, wallRestitution, kick: kck.kick)) {
        _s.kickerHits++;
        _s.score += 10 * _s.multiplier;
      }
    }
    for (final b in PinballTable.bumpers) {
      final d = _s.ball - b.center;
      final dist = d.length;
      if (dist < b.radius + r && dist > 1e-9) {
        final n = d / dist;
        _s.ball = b.center + n * (b.radius + r);
        final vn = _s.velocity.dot(n);
        if (vn < bumperKick) {
          _s.velocity = _s.velocity - n * vn + n * bumperKick;
          _s.bumperHits++;
          _s.score += 100 * _s.multiplier;
        }
      }
    }
    _flipper(_s.left);
    _flipper(_s.right);
    if (_s.velocity.length > PinballConfig.maxSpeed) {
      _s.velocity = _s.velocity.normalized * PinballConfig.maxSpeed;
    }
    // Rollovers light on entry; all three raise the multiplier.
    for (var i = 0; i < 3; i++) {
      final inside = (_s.ball - PinballTable.rollovers[i]).length < 0.8;
      if (inside && !_s.inRollover[i]) {
        _s.lit[i] = true;
        _s.score += 50;
      }
      _s.inRollover[i] = inside;
    }
    if (_s.lit.every((l) => l)) {
      _s.score += 1000 * _s.multiplier;
      _s.multiplier = math.min(5, _s.multiplier + 1);
      _s.lit.fillRange(0, 3, false);
    }
    // Back into the plunger lane: rest on the plunger again.
    if (_s.ball.x > PinballTable.laneX && _s.ball.y > 34.5 && _s.velocity.y >= 0) {
      _s.onPlunger = true;
      _s.ball = PinballTable.plungerRest;
      _s.velocity = Vec2.zero;
    }
    // Drain.
    if (_s.ball.y > PinballConfig.height + 1) {
      _s.ballsLeft--;
      _s.multiplier = 1;
      if (_s.ballsLeft <= 0) {
        _s.over = true;
      } else {
        _s.onPlunger = true;
        _s.ball = PinballTable.plungerRest;
        _s.velocity = Vec2.zero;
      }
    }
  }

  /// Resolves the ball against a capsule segment; true when a kick fired.
  bool _segment(Vec2 a, Vec2 b, double r, double e, {double kick = 0}) {
    final q = closestOnSegment(_s.ball, a, b);
    var d = _s.ball - q;
    var dist = d.length;
    if (dist >= r) return false;
    if (dist < 1e-9) {
      d = (b - a).perp;
      dist = d.length;
    }
    final n = d / dist;
    _s.ball = q + n * r;
    final vn = _s.velocity.dot(n);
    if (vn >= 0) return false;
    if (kick > 0) {
      _s.velocity = _s.velocity - n * vn + n * math.max(kick, -vn * e);
      return true;
    }
    final vt = _s.velocity - n * vn;
    _s.velocity = vt * 0.995 - n * (vn * e);
    return false;
  }

  void _flipper(Flipper f) {
    const r = PinballConfig.ballRadius;
    final q = closestOnSegment(_s.ball, f.pivot, f.tip);
    final d = _s.ball - q;
    final dist = d.length;
    final reach = r + Flipper.radius;
    if (dist >= reach || dist < 1e-9) return;
    final n = d / dist;
    _s.ball = q + n * reach;
    final surface = (q - f.pivot).perp * f.omega;
    final rel = _s.velocity - surface;
    final vn = rel.dot(n);
    if (vn >= 0) return;
    _s.velocity = _s.velocity - n * (vn * (1 + flipperRestitution));
    if (f.omega.abs() > 1) _s.flipperHits++;
  }

  @override
  Map<String, Object?> snapshot() => {
    'tick': tick,
    'ball': _s.ball.toJson(),
    'vel': _s.velocity.toJson(),
    'flippers': [r4(_s.left.angle), r4(_s.right.angle)],
    'balls': _s.ballsLeft,
    'score': _s.score,
    'mult': _s.multiplier,
    'rng': rng.state,
  };
}
