/// Stack Tower: a timing stacker.
///
/// A block slides back and forth above the tower; a tap drops it. The part
/// overhanging the block below is cut off (and falls as debris); a drop
/// within the perfect tolerance snaps into place with no cut, and three
/// perfect drops in a row widen the block again. Missing the tower entirely
/// ends the game. The slide speed grows with the height.
library;

import 'dart:math' as math;

import '../core/arcade_sim.dart';

final class StackConfig {
  const StackConfig({this.level = ArcadeLevel.medium, this.seed = 0});

  final ArcadeLevel level;
  final int seed;

  static const double width = 200;
  static const double baseWidth = 100;
  static const double blockHeight = 10;

  double get startSpeed => switch (level) {
    ArcadeLevel.easy => 70,
    ArcadeLevel.medium => 90,
    ArcadeLevel.hard => 120,
  };

  double get perfectTolerance => switch (level) {
    ArcadeLevel.easy => 4,
    ArcadeLevel.medium => 3,
    ArcadeLevel.hard => 2,
  };
}

final class StackInput {
  const StackInput({this.drop = false});
  static const StackInput none = StackInput();

  /// One-shot.
  final bool drop;
}

/// A placed block: its left edge and width.
final class StackBlock {
  const StackBlock(this.left, this.width);
  final double left;
  final double width;
  double get right => left + width;
}

/// A cut-off overhang (for the renderer).
final class StackDebris {
  const StackDebris(this.left, this.width, this.level);
  final double left;
  final double width;
  final int level;
}

final class StackState {
  final List<StackBlock> tower = [const StackBlock((StackConfig.width - StackConfig.baseWidth) / 2, StackConfig.baseWidth)];
  final List<StackDebris> debris = [];
  double movingLeft = 0;
  double movingWidth = StackConfig.baseWidth;
  double direction = 1;
  int combo = 0;
  int perfects = 0;
  int score = 0;
  bool over = false;

  int get height => tower.length - 1;
  StackBlock get top => tower.last;
}

final class StackTowerSim extends FixedStepSim<StackState, StackInput> {
  StackTowerSim(this.config) : rng = SeededRng(config.seed), super(hz: 60) {
    _spawn();
  }

  final StackConfig config;
  final SeededRng rng;
  final StackState _s = StackState();

  @override
  ArcadeKind get kind => ArcadeKind.stackTower;

  @override
  StackState get state => _s;

  @override
  int get score => _s.score;

  @override
  bool get isOver => _s.over;

  double get speed => math.min(260, config.startSpeed + 6.0 * _s.height);

  @override
  StackInput heldOnly(StackInput input) => StackInput.none;

  @override
  StackInput mergeInput(StackInput earlier, StackInput later) => StackInput(drop: earlier.drop || later.drop);

  void _spawn() {
    _s.movingWidth = _s.top.width;
    final fromLeft = rng.nextBool();
    _s.direction = fromLeft ? 1 : -1;
    _s.movingLeft = fromLeft ? -_s.movingWidth * 0.5 : StackConfig.width - _s.movingWidth * 0.5;
  }

  @override
  void update(StackInput input) {
    if (input.drop) {
      _drop();
      return;
    }
    final dt = tickSeconds;
    final minLeft = -_s.movingWidth * 0.5, maxLeft = StackConfig.width - _s.movingWidth * 0.5;
    _s.movingLeft += _s.direction * speed * dt;
    if (_s.movingLeft > maxLeft) {
      _s.movingLeft = 2 * maxLeft - _s.movingLeft;
      _s.direction = -1;
    } else if (_s.movingLeft < minLeft) {
      _s.movingLeft = 2 * minLeft - _s.movingLeft;
      _s.direction = 1;
    }
  }

  void _drop() {
    final top = _s.top;
    final left = _s.movingLeft, right = _s.movingLeft + _s.movingWidth;
    final offset = left - top.left;
    if (offset.abs() <= config.perfectTolerance) {
      _s.combo++;
      _s.perfects++;
      var width = top.width;
      if (_s.combo >= 3) width = math.min(StackConfig.baseWidth, width + 4);
      final placedLeft = top.left - (width - top.width) / 2;
      _s.tower.add(StackBlock(placedLeft, width));
      _s.score += 2;
      _spawn();
      return;
    }
    _s.combo = 0;
    final l = math.max(left, top.left), r = math.min(right, top.right);
    if (r - l <= 0) {
      _s.debris.add(StackDebris(left, _s.movingWidth, _s.height + 1));
      _s.over = true;
      return;
    }
    if (left < l) _s.debris.add(StackDebris(left, l - left, _s.height + 1));
    if (right > r) _s.debris.add(StackDebris(r, right - r, _s.height + 1));
    _s.tower.add(StackBlock(l, r - l));
    _s.score += 1;
    _spawn();
  }

  @override
  Map<String, Object?> snapshot() => {
    'tick': tick,
    'tower': [
      for (final b in _s.tower) [r4(b.left), r4(b.width)],
    ],
    'moving': r4(_s.movingLeft),
    'score': _s.score,
    'combo': _s.combo,
    'rng': rng.state,
  };
}
