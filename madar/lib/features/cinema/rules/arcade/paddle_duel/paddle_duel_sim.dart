/// Paddle Duel: two paddles, one ball, first to 11.
///
/// The ball bounces off the top and bottom walls; the paddle bounce angle
/// depends on where it hits (up to ±50°) and every return speeds it up.
/// The right paddle is an AI; the left one follows player input, or a second
/// AI for attract mode. AI levels differ in reaction time (how often the
/// target is re-evaluated), top speed, how far ahead they predict (bounces
/// included) and aiming error.
library;

import 'dart:math' as math;

import '../core/arcade_sim.dart';
import '../core/geometry.dart';

final class PaddleDuelConfig {
  const PaddleDuelConfig({
    this.ai = ArcadeLevel.medium,
    this.leftAi,
    this.seed = 0,
    this.pointsToWin = 11,
  });

  /// Right-hand AI strength.
  final ArcadeLevel ai;

  /// When set, the left paddle is also an AI (attract mode / tests).
  final ArcadeLevel? leftAi;
  final int seed;
  final int pointsToWin;

  static const double width = 320;
  static const double height = 200;
  static const double paddleH = 36;
  static const double paddleW = 6;
  static const double leftX = 12;
  static const double rightX = width - 12;
  static const double ballRadius = 4;
  static const double startSpeed = 190;
  static const double maxSpeed = 380;
}

/// Player control of the left paddle: a pointer target or an axis.
final class PaddleInput {
  const PaddleInput({this.targetY, this.axis = 0});
  static const PaddleInput none = PaddleInput();
  final double? targetY;
  final double axis;
}

/// Tuning of an AI level.
final class PaddleAiProfile {
  const PaddleAiProfile(this.reactionTicks, this.maxSpeed, this.error, this.errorAtSpeed, this.predicts, this.aim);

  factory PaddleAiProfile.of(ArcadeLevel l) => switch (l) {
    ArcadeLevel.easy => const PaddleAiProfile(14, 150, 20, 24, false, 0),
    ArcadeLevel.medium => const PaddleAiProfile(7, 200, 8, 28, true, 1),
    ArcadeLevel.hard => const PaddleAiProfile(2, 280, 2, 24, true, 2),
  };

  final int reactionTicks;
  final double maxSpeed;

  /// Interception error (± units) drawn once per approaching ball; it grows
  /// by up to [errorAtSpeed] as the ball reaches its top speed.
  final double error;
  final double errorAtSpeed;

  /// Predicts the interception point with wall bounces (else chases the
  /// ball's current height).
  final bool predicts;

  /// 0: hits with the centre; 1: random angles; 2: angles away from the
  /// opponent.
  final int aim;
}

final class PaddleDuelState {
  double leftY = PaddleDuelConfig.height / 2;
  double rightY = PaddleDuelConfig.height / 2;
  Vec2 ball = const Vec2(PaddleDuelConfig.width / 2, PaddleDuelConfig.height / 2);
  Vec2 velocity = Vec2.zero;
  int leftScore = 0;
  int rightScore = 0;
  int rally = 0;
  double serveDelay = 1;

  /// Side that serves next: -1 towards the left, 1 towards the right.
  int serveTo = 1;
  final List<double> aiTarget = [PaddleDuelConfig.height / 2, PaddleDuelConfig.height / 2];
  final List<int> aiClock = [0, 0];
  final List<bool> aiApproach = [false, false];
  final List<double> aiError = [0, 0];
  final List<double> aiAim = [0, 0];
  bool over = false;

  /// 0 left, 1 right, -1 none yet.
  int winner = -1;
}

final class PaddleDuelSim extends FixedStepSim<PaddleDuelState, PaddleInput> {
  PaddleDuelSim(this.config) : rng = SeededRng(config.seed), super(hz: 60) {
    _s.serveTo = rng.nextBool() ? 1 : -1;
  }

  final PaddleDuelConfig config;
  final SeededRng rng;
  final PaddleDuelState _s = PaddleDuelState();

  static const double playerSpeed = 300;

  @override
  ArcadeKind get kind => ArcadeKind.paddleDuel;

  @override
  PaddleDuelState get state => _s;

  /// The left (player) score.
  @override
  int get score => _s.leftScore;

  @override
  bool get isOver => _s.over;

  double get speed => math.min(PaddleDuelConfig.maxSpeed, PaddleDuelConfig.startSpeed + 12.0 * _s.rally);

  void _serve() {
    final angle = rng.nextDoubleRange(-0.5, 0.5);
    _s.velocity = Vec2(math.cos(angle) * _s.serveTo, math.sin(angle)) * PaddleDuelConfig.startSpeed;
    _s.rally = 0;
  }

  /// Where the ball will cross [x], folding wall bounces.
  double predictY(double x) {
    final v = _s.velocity;
    if (v.x == 0) return _s.ball.y;
    final t = (x - _s.ball.x) / v.x;
    if (t < 0) return _s.ball.y;
    const lo = PaddleDuelConfig.ballRadius, hi = PaddleDuelConfig.height - PaddleDuelConfig.ballRadius;
    const span = hi - lo;
    var y = _s.ball.y + v.y * t - lo;
    y = y % (2 * span);
    if (y < 0) y += 2 * span;
    if (y > span) y = 2 * span - y;
    return y + lo;
  }

  double _aiMove(int side, ArcadeLevel level, double current) {
    final p = PaddleAiProfile.of(level);
    final towards = side == 0 ? _s.velocity.x < 0 : _s.velocity.x > 0;
    if (towards && !_s.aiApproach[side]) {
      // A new approach: commit to an error and an aim for this ball.
      const range = PaddleDuelConfig.maxSpeed - PaddleDuelConfig.startSpeed;
      final frac = ((_s.velocity.length - PaddleDuelConfig.startSpeed) / range).clamp(0.0, 1.0);
      final e = p.error + p.errorAtSpeed * frac;
      _s.aiError[side] = rng.nextDoubleRange(-e, e);
      const reach = PaddleDuelConfig.paddleH / 2;
      _s.aiAim[side] = switch (p.aim) {
        0 => 0,
        1 => rng.nextDoubleRange(-0.45, 0.45) * reach,
        _ => ((side == 0 ? _s.rightY : _s.leftY) < PaddleDuelConfig.height / 2 ? 1 : -1) * 0.6 * reach,
      };
    }
    _s.aiApproach[side] = towards;
    if (_s.aiClock[side] <= 0) {
      _s.aiClock[side] = p.reactionTicks;
      final x = side == 0 ? PaddleDuelConfig.leftX : PaddleDuelConfig.rightX;
      if (!towards) {
        _s.aiTarget[side] = PaddleDuelConfig.height / 2;
      } else {
        final y = p.predicts ? predictY(x) : _s.ball.y;
        _s.aiTarget[side] = y + _s.aiError[side] - _s.aiAim[side];
      }
    }
    _s.aiClock[side]--;
    final delta = (_s.aiTarget[side] - current).clamp(-p.maxSpeed * tickSeconds, p.maxSpeed * tickSeconds);
    return current + delta;
  }

  double _clampPaddle(double y) =>
      y.clamp(PaddleDuelConfig.paddleH / 2, PaddleDuelConfig.height - PaddleDuelConfig.paddleH / 2);

  Aabb _paddle(double x, double y) => Aabb(
    x - PaddleDuelConfig.paddleW / 2,
    y - PaddleDuelConfig.paddleH / 2,
    x + PaddleDuelConfig.paddleW / 2,
    y + PaddleDuelConfig.paddleH / 2,
  );

  @override
  void update(PaddleInput input) {
    final dt = tickSeconds;
    // Paddles.
    if (config.leftAi != null) {
      _s.leftY = _clampPaddle(_aiMove(0, config.leftAi!, _s.leftY));
    } else if (input.targetY != null) {
      final d = (input.targetY! - _s.leftY).clamp(-playerSpeed * dt, playerSpeed * dt);
      _s.leftY = _clampPaddle(_s.leftY + d);
    } else {
      _s.leftY = _clampPaddle(_s.leftY + input.axis.clamp(-1.0, 1.0) * playerSpeed * dt);
    }
    _s.rightY = _clampPaddle(_aiMove(1, config.ai, _s.rightY));
    // Serve.
    if (_s.velocity == Vec2.zero) {
      _s.serveDelay -= dt;
      if (_s.serveDelay <= 0) _serve();
      return;
    }
    // Ball with swept collisions.
    const r = PaddleDuelConfig.ballRadius;
    var remaining = 1.0;
    for (var iter = 0; iter < 4 && remaining > 1e-9; iter++) {
      final d = _s.velocity * (dt * remaining);
      SweepHit? best;
      var which = -1;
      void consider(SweepHit? h, int id) {
        if (h == null || _s.velocity.dot(h.normal) >= 0) return;
        if (best == null || h.t < best!.t) {
          best = h;
          which = id;
        }
      }

      consider(sweepCircleAabb(_s.ball, d, r, const Aabb(-1000, -100, 1000 + PaddleDuelConfig.width, 0)), 2);
      consider(
        sweepCircleAabb(
          _s.ball,
          d,
          r,
          const Aabb(-1000, PaddleDuelConfig.height, 1000 + PaddleDuelConfig.width, PaddleDuelConfig.height + 100),
        ),
        2,
      );
      consider(sweepCircleAabb(_s.ball, d, r, _paddle(PaddleDuelConfig.leftX, _s.leftY)), 0);
      consider(sweepCircleAabb(_s.ball, d, r, _paddle(PaddleDuelConfig.rightX, _s.rightY)), 1);
      if (best == null) {
        _s.ball = _s.ball + d;
        break;
      }
      final t = math.max(0.0, best!.t - 1e-6);
      _s.ball = _s.ball + d * t;
      remaining *= 1 - t;
      if (which == 2) {
        _s.velocity = _s.velocity.reflect(best!.normal);
      } else {
        final py = which == 0 ? _s.leftY : _s.rightY;
        final offset = ((_s.ball.y - py) / (PaddleDuelConfig.paddleH / 2 + r)).clamp(-1.0, 1.0);
        _s.rally++;
        final angle = offset * 50 * math.pi / 180;
        final dir = which == 0 ? 1.0 : -1.0;
        _s.velocity = Vec2(math.cos(angle) * dir, math.sin(angle)) * speed;
      }
    }
    // Points.
    if (_s.ball.x < -r || _s.ball.x > PaddleDuelConfig.width + r) {
      final rightScored = _s.ball.x < 0;
      if (rightScored) {
        _s.rightScore++;
      } else {
        _s.leftScore++;
      }
      _s.serveTo = rightScored ? -1 : 1;
      _s.ball = const Vec2(PaddleDuelConfig.width / 2, PaddleDuelConfig.height / 2);
      _s.velocity = Vec2.zero;
      _s.serveDelay = 0.8;
      if (_s.leftScore >= config.pointsToWin || _s.rightScore >= config.pointsToWin) {
        _s.over = true;
        _s.winner = _s.leftScore > _s.rightScore ? 0 : 1;
      }
    }
  }

  @override
  Map<String, Object?> snapshot() => {
    'tick': tick,
    'left': r4(_s.leftY),
    'right': r4(_s.rightY),
    'ball': _s.ball.toJson(),
    'vel': _s.velocity.toJson(),
    'score': [_s.leftScore, _s.rightScore],
    'rng': rng.state,
  };
}
