/// Snake on a grid: steer, eat, grow, speed up; walls or wrap-around.
///
/// The snake advances one cell every `interval` ticks (60 Hz); the interval
/// shrinks every 5 foods down to a floor. Up to two queued turns are
/// honoured per cell (quick double turns), a turn onto the opposite
/// direction is ignored. Hitting a wall (unless wrapping) or the body ends
/// the game; filling the board wins it.
library;

import '../../puzzles/core/grid.dart';
import '../core/arcade_sim.dart';

final class SnakeConfig {
  const SnakeConfig({this.width = 20, this.height = 20, this.wrap = false, this.level = ArcadeLevel.medium, this.seed = 0});

  final int width;
  final int height;
  final bool wrap;
  final ArcadeLevel level;
  final int seed;

  /// Ticks per cell at the start and the fastest allowed.
  int get startInterval => switch (level) {
    ArcadeLevel.easy => 10,
    ArcadeLevel.medium => 8,
    ArcadeLevel.hard => 6,
  };
  int get minInterval => 3;
}

/// A one-shot turn request (null = keep going).
final class SnakeInput {
  const SnakeInput([this.turn]);
  static const SnakeInput none = SnakeInput();
  final Dir4? turn;
}

final class SnakeState {
  SnakeState(this.body, this.direction, this.food);

  /// Head first.
  final List<(int, int)> body;
  Dir4 direction;
  (int, int)? food;
  final List<Dir4> queued = [];
  int score = 0;
  int eaten = 0;
  int countdown = 0;
  bool dead = false;
  bool won = false;

  (int, int) get head => body.first;
}

final class SnakeSim extends FixedStepSim<SnakeState, SnakeInput> {
  SnakeSim(this.config) : rng = SeededRng(config.seed), super(hz: 60) {
    final cx = config.width ~/ 2, cy = config.height ~/ 2;
    _s = SnakeState([(cx, cy), (cx - 1, cy), (cx - 2, cy)], Dir4.right, null);
    _s.countdown = config.startInterval;
    _placeFood();
  }

  final SnakeConfig config;
  final SeededRng rng;
  late SnakeState _s;

  @override
  ArcadeKind get kind => ArcadeKind.snake;

  @override
  SnakeState get state => _s;

  @override
  int get score => _s.score;

  @override
  bool get isOver => _s.dead || _s.won;

  int get interval {
    final i = config.startInterval - _s.eaten ~/ 5;
    return i < config.minInterval ? config.minInterval : i;
  }

  @override
  SnakeInput heldOnly(SnakeInput input) => SnakeInput.none;

  @override
  SnakeInput mergeInput(SnakeInput earlier, SnakeInput later) => later.turn != null ? later : earlier;

  void _placeFood() {
    final occupied = {..._s.body};
    final free = [
      for (var y = 0; y < config.height; y++)
        for (var x = 0; x < config.width; x++)
          if (!occupied.contains((x, y))) (x, y),
    ];
    if (free.isEmpty) {
      _s.food = null;
      _s.won = true;
      return;
    }
    _s.food = rng.pick(free);
  }

  @override
  void update(SnakeInput input) {
    final t = input.turn;
    if (t != null && _s.queued.length < 2) {
      final last = _s.queued.isEmpty ? _s.direction : _s.queued.last;
      if (t != last && t != last.opposite) _s.queued.add(t);
    }
    if (--_s.countdown > 0) return;
    _s.countdown = interval;
    if (_s.queued.isNotEmpty) _s.direction = _s.queued.removeAt(0);
    var (x, y) = _s.head;
    x += _s.direction.dx;
    y += _s.direction.dy;
    if (config.wrap) {
      x = (x + config.width) % config.width;
      y = (y + config.height) % config.height;
    } else if (x < 0 || y < 0 || x >= config.width || y >= config.height) {
      _s.dead = true;
      return;
    }
    final next = (x, y);
    final eating = next == _s.food;
    // The tail cell frees up this step unless the snake is eating.
    final bodyToCheck = eating ? _s.body : _s.body.sublist(0, _s.body.length - 1);
    if (bodyToCheck.contains(next)) {
      _s.dead = true;
      return;
    }
    _s.body.insert(0, next);
    if (eating) {
      _s.eaten++;
      _s.score += 10 * (1 + config.level.index);
      _placeFood();
    } else {
      _s.body.removeLast();
    }
  }

  @override
  Map<String, Object?> snapshot() => {
    'tick': tick,
    'body': [for (final (x, y) in _s.body) [x, y]],
    'dir': _s.direction.name,
    'food': _s.food == null ? null : [_s.food!.$1, _s.food!.$2],
    'score': _s.score,
    'dead': _s.dead,
    'rng': rng.state,
  };
}
