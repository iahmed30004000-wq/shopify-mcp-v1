/// Maze Chase: eat every pellet while four chasers hunt you – the classic
/// arcade structure with original characters and generated mazes.
///
/// Maze: a perfect maze is carved on the left half of an odd-sized grid,
/// mirrored to the right, joined across the middle, and then every dead end
/// is opened up, so corridors always loop (a chaser can never trap the
/// runner in a cul-de-sac). The chasers start in a central den and leave it
/// one by one.
///
/// Chasers decide at each tile centre, never reversing, taking the open
/// direction closest (straight-line) to a target tile:
/// * Ember targets the runner's tile;
/// * Tide targets four tiles ahead of the runner;
/// * Moss targets the point that mirrors Ember through the tile two ahead
///   of the runner (a flanker);
/// * Dusk chases while farther than eight tiles, else retreats to its
///   corner.
/// Modes alternate scatter (each chaser heads for its own corner) and chase
/// on a timer; a power pellet makes them frightened (slow, random turns,
/// edible for a chain of 200/400/800/1600) for a time that shrinks with the
/// level; an eaten chaser returns to the den at speed. Mode changes reverse
/// every chaser.
library;

import 'dart:math' as math;

import '../../puzzles/core/grid.dart';
import '../core/arcade_sim.dart';

final class MazeConfig {
  const MazeConfig({this.level = ArcadeLevel.medium, this.seed = 0, this.lives = 3});

  final ArcadeLevel level;
  final int seed;
  final int lives;

  static const int width = 21;
  static const int height = 23;

  double get chaserSpeedFactor => switch (level) {
    ArcadeLevel.easy => 0.85,
    ArcadeLevel.medium => 0.95,
    ArcadeLevel.hard => 1.05,
  };
}

/// The runner's desired direction (held).
final class MazeInput {
  const MazeInput([this.direction]);
  static const MazeInput none = MazeInput();
  final Dir4? direction;
}

enum ChaserId { ember, tide, moss, dusk }

enum ChaserMode { waiting, scatter, chase, frightened, eaten }

final class Mover {
  Mover(this.x, this.y, this.dir);

  /// Position in tile units (tile centres are integers).
  double x;
  double y;
  Dir4 dir;

  int get tx => x.round();
  int get ty => y.round();
}

final class Chaser extends Mover {
  Chaser(this.id, super.x, super.y, super.dir, this.release);
  final ChaserId id;
  ChaserMode mode = ChaserMode.waiting;

  /// Seconds before leaving the den.
  double release;
}

/// A generated maze: `true` = wall.
final class MazeMap {
  MazeMap(this.walls, this.den, this.start);

  final List<bool> walls;
  final (int, int) den;
  final (int, int) start;

  static const int w = MazeConfig.width;
  static const int h = MazeConfig.height;

  bool wall(int x, int y) => x < 0 || y < 0 || x >= w || y >= h || walls[y * w + x];

  bool open(int x, int y) => !wall(x, y);

  List<Dir4> exits(int x, int y) => [
    for (final d in Dir4.values)
      if (open(x + d.dx, y + d.dy)) d,
  ];

  List<(int, int)> get corridors => [
    for (var y = 0; y < h; y++)
      for (var x = 0; x < w; x++)
        if (open(x, y)) (x, y),
  ];

  /// Generates a symmetric, loop-rich maze.
  static MazeMap generate(SeededRng rng) {
    final walls = List<bool>.filled(w * h, true);
    void carve(int x, int y) {
      walls[y * w + x] = false;
      walls[y * w + (w - 1 - x)] = false;
    }

    // Cells at odd coordinates; the left half has x in 1..9 (mirrored).
    const half = (w - 1) ~/ 2; // 10
    final visited = <(int, int)>{};
    final stack = <(int, int)>[(1, 1)];
    visited.add((1, 1));
    carve(1, 1);
    while (stack.isNotEmpty) {
      final (cx, cy) = stack.last;
      final options = <(int, int)>[];
      for (final d in Dir4.values) {
        final nx = cx + 2 * d.dx, ny = cy + 2 * d.dy;
        if (nx < 1 || ny < 1 || nx >= half || ny >= h - 1) continue;
        if (!visited.contains((nx, ny))) options.add((nx, ny));
      }
      if (options.isEmpty) {
        stack.removeLast();
        continue;
      }
      final (nx, ny) = rng.pick(options);
      carve((cx + nx) ~/ 2, (cy + ny) ~/ 2);
      carve(nx, ny);
      visited.add((nx, ny));
      stack.add((nx, ny));
    }
    // Join the halves through the centre column on a few rows.
    final rows = [for (var y = 1; y < h - 1; y += 2) y];
    rng.shuffle(rows);
    for (final y in rows.take(4)) {
      walls[y * w + half] = false;
    }
    // Remove dead ends (mirrored so symmetry holds).
    bool isOpen(int x, int y) => x >= 0 && y >= 0 && x < w && y < h && !walls[y * w + x];
    var changed = true;
    while (changed) {
      changed = false;
      for (var y = 1; y < h - 1; y += 2) {
        for (var x = 1; x <= half; x += 2) {
          if (!isOpen(x, y)) continue;
          final exits = Dir4.values.where((d) => isOpen(x + d.dx, y + d.dy)).length;
          if (exits >= 2) continue;
          final candidates = [
            for (final d in Dir4.values)
              if (!isOpen(x + d.dx, y + d.dy) &&
                  x + 2 * d.dx >= 1 &&
                  x + 2 * d.dx <= w - 2 &&
                  y + 2 * d.dy >= 1 &&
                  y + 2 * d.dy <= h - 2)
                d,
          ];
          if (candidates.isEmpty) continue;
          final d = rng.pick(candidates);
          carve(x + d.dx, y + d.dy);
          changed = true;
        }
      }
    }
    // Den in the middle, runner start low in the middle.
    (int, int) nearestOpen(int x, int y) {
      var best = (1, 1);
      var bestD = 1 << 30;
      for (var yy = 0; yy < h; yy++) {
        for (var xx = 0; xx < w; xx++) {
          if (walls[yy * w + xx]) continue;
          final d = (xx - x) * (xx - x) + (yy - y) * (yy - y);
          if (d < bestD) {
            bestD = d;
            best = (xx, yy);
          }
        }
      }
      return best;
    }

    return MazeMap(List.unmodifiable(walls), nearestOpen(half, h ~/ 2), nearestOpen(half, h - 5));
  }
}

final class MazeState {
  MazeState(this.map, this.runner, this.chasers);

  final MazeMap map;
  final Mover runner;
  final List<Chaser> chasers;
  final Set<(int, int)> pellets = {};
  final Set<(int, int)> powerPellets = {};
  int score = 0;
  int lives = 3;
  int level = 1;
  double modeClock = 0;
  int modeIndex = 0;
  double frightened = 0;
  int chain = 0;
  double deathPause = 0;
  bool over = false;
}

final class MazeChaseSim extends FixedStepSim<MazeState, MazeInput> {
  MazeChaseSim(this.config) : rng = SeededRng(config.seed), super(hz: 60) {
    final map = MazeMap.generate(rng);
    _s = MazeState(map, Mover(0, 0, Dir4.left), []);
    _s.lives = config.lives;
    _resetLevel();
  }

  final MazeConfig config;
  final SeededRng rng;
  late MazeState _s;

  /// Scatter / chase durations (seconds); the last chase lasts forever.
  static const List<double> schedule = [7, 20, 7, 20, 5, 20, 5];

  static const double runnerSpeed = 7.5;
  static const double chaserSpeed = 7.0;

  @override
  ArcadeKind get kind => ArcadeKind.mazeChase;

  @override
  MazeState get state => _s;

  @override
  int get score => _s.score;

  @override
  bool get isOver => _s.over;

  MazeMap get map => _s.map;

  double get frightTime => math.max(1.5, 7.0 - _s.level);

  void _resetLevel() {
    _s.pellets
      ..clear()
      ..addAll(map.corridors);
    _s.pellets.remove(map.start);
    _s.pellets.remove(map.den);
    _s.powerPellets.clear();
    for (final (cx, cy) in const [(0, 0), (MazeConfig.width - 1, 0), (0, MazeConfig.height - 1), (MazeConfig.width - 1, MazeConfig.height - 1)]) {
      final nearest = _s.pellets.reduce((a, b) {
        final da = (a.$1 - cx) * (a.$1 - cx) + (a.$2 - cy) * (a.$2 - cy);
        final db = (b.$1 - cx) * (b.$1 - cx) + (b.$2 - cy) * (b.$2 - cy);
        return da <= db ? a : b;
      });
      _s.pellets.remove(nearest);
      _s.powerPellets.add(nearest);
    }
    _resetPositions();
  }

  void _resetPositions() {
    final (sx, sy) = map.start;
    _s.runner
      ..x = sx.toDouble()
      ..y = sy.toDouble()
      ..dir = Dir4.left;
    final (dx, dy) = map.den;
    _s.chasers
      ..clear()
      ..addAll([
        for (final id in ChaserId.values) Chaser(id, dx.toDouble(), dy.toDouble(), Dir4.up, id.index * 2.5),
      ]);
    _s.modeClock = 0;
    _s.modeIndex = 0;
    _s.frightened = 0;
  }

  /// Scatter corners per chaser.
  static (int, int) corner(ChaserId id) => switch (id) {
    ChaserId.ember => (MazeConfig.width - 2, -3),
    ChaserId.tide => (1, -3),
    ChaserId.moss => (MazeConfig.width - 1, MazeConfig.height + 1),
    ChaserId.dusk => (0, MazeConfig.height + 1),
  };

  bool get _scatterPhase => _s.modeIndex < schedule.length && _s.modeIndex.isEven;

  /// Target tile of [c] in the current mode.
  (int, int) targetOf(Chaser c) {
    if (c.mode == ChaserMode.eaten) return map.den;
    if (c.mode == ChaserMode.scatter) return corner(c.id);
    final r = _s.runner;
    final (rx, ry) = (r.tx, r.ty);
    switch (c.id) {
      case ChaserId.ember:
        return (rx, ry);
      case ChaserId.tide:
        return (rx + 4 * r.dir.dx, ry + 4 * r.dir.dy);
      case ChaserId.moss:
        final ember = _s.chasers.first;
        final px = rx + 2 * r.dir.dx, py = ry + 2 * r.dir.dy;
        return (2 * px - ember.tx, 2 * py - ember.ty);
      case ChaserId.dusk:
        final d2 = (c.tx - rx) * (c.tx - rx) + (c.ty - ry) * (c.ty - ry);
        return d2 > 64 ? (rx, ry) : corner(c.id);
    }
  }

  double _speedOf(Chaser c) {
    final base = chaserSpeed * config.chaserSpeedFactor * (1 + 0.05 * (_s.level - 1));
    return switch (c.mode) {
      ChaserMode.frightened => base * 0.6,
      ChaserMode.eaten => base * 2,
      _ => base,
    };
  }

  /// Distance from [m] to the next tile centre ahead along its heading.
  static double _toCentre(Mover m) => switch (m.dir) {
    Dir4.right => m.x.ceilToDouble() - m.x,
    Dir4.left => m.x - m.x.floorToDouble(),
    Dir4.down => m.y.ceilToDouble() - m.y,
    Dir4.up => m.y - m.y.floorToDouble(),
  };

  /// Moves [m] by [dist] tiles, calling [decide] at every tile centre it
  /// reaches (null from [decide] stops it there).
  void _advance(Mover m, double dist, Dir4? Function(int tx, int ty) decide) {
    var left = dist;
    for (var guard = 0; guard < 8 && left > 1e-9; guard++) {
      final ahead = _toCentre(m);
      if (ahead > 1e-6) {
        final step = math.min(ahead, left);
        m.x += m.dir.dx * step;
        m.y += m.dir.dy * step;
        left -= step;
        if (left <= 1e-9 && ahead - step > 1e-6) break;
      }
      // At a centre: snap and decide.
      m.x = m.x.roundToDouble();
      m.y = m.y.roundToDouble();
      final next = decide(m.tx, m.ty);
      if (next == null) return;
      m.dir = next;
      if (left <= 1e-9) break;
      final step = math.min(left, 1.0);
      m.x += m.dir.dx * step;
      m.y += m.dir.dy * step;
      left -= step;
    }
  }

  @override
  void update(MazeInput input) {
    final dt = tickSeconds;
    if (_s.deathPause > 0) {
      _s.deathPause -= dt;
      if (_s.deathPause <= 0) _resetPositions();
      return;
    }
    // Modes.
    if (_s.frightened > 0) {
      _s.frightened -= dt;
      if (_s.frightened <= 0) {
        for (final c in _s.chasers) {
          if (c.mode == ChaserMode.frightened) c.mode = _scatterPhase ? ChaserMode.scatter : ChaserMode.chase;
        }
      }
    } else if (_s.modeIndex < schedule.length) {
      _s.modeClock += dt;
      if (_s.modeClock >= schedule[_s.modeIndex]) {
        _s.modeClock = 0;
        _s.modeIndex++;
        for (final c in _s.chasers) {
          if (c.mode == ChaserMode.scatter || c.mode == ChaserMode.chase) {
            c.mode = _scatterPhase ? ChaserMode.scatter : ChaserMode.chase;
            c.dir = c.dir.opposite;
          }
        }
      }
    }
    // Runner.
    final want = input.direction;
    _advance(_s.runner, runnerSpeed * dt, (tx, ty) {
      if (want != null && map.open(tx + want.dx, ty + want.dy)) return want;
      if (map.open(tx + _s.runner.dir.dx, ty + _s.runner.dir.dy)) return _s.runner.dir;
      return null;
    });
    // Mid-corridor reversal is always allowed.
    if (want != null && want == _s.runner.dir.opposite) _s.runner.dir = want;
    final tile = (_s.runner.tx, _s.runner.ty);
    if (_s.pellets.remove(tile)) _s.score += 10;
    if (_s.powerPellets.remove(tile)) {
      _s.score += 50;
      _s.frightened = frightTime;
      _s.chain = 0;
      for (final c in _s.chasers) {
        if (c.mode == ChaserMode.scatter || c.mode == ChaserMode.chase) {
          c.mode = ChaserMode.frightened;
          c.dir = c.dir.opposite;
        }
      }
    }
    // Chasers.
    for (final c in _s.chasers) {
      if (c.mode == ChaserMode.waiting) {
        c.release -= dt;
        if (c.release <= 0) c.mode = _s.frightened > 0 ? ChaserMode.frightened : (_scatterPhase ? ChaserMode.scatter : ChaserMode.chase);
        continue;
      }
      _advance(c, _speedOf(c) * dt, (tx, ty) {
        if (c.mode == ChaserMode.eaten && (tx, ty) == map.den) {
          c.mode = _s.frightened > 0 ? ChaserMode.frightened : (_scatterPhase ? ChaserMode.scatter : ChaserMode.chase);
        }
        final options = map.exits(tx, ty).where((d) => d != c.dir.opposite).toList();
        if (options.isEmpty) return c.dir.opposite; // cannot happen without dead ends
        if (c.mode == ChaserMode.frightened) return rng.pick(options);
        final (gx, gy) = targetOf(c);
        Dir4? best;
        var bestD = double.infinity;
        for (final d in options) {
          final nx = tx + d.dx, ny = ty + d.dy;
          final dd = ((nx - gx) * (nx - gx) + (ny - gy) * (ny - gy)).toDouble();
          if (dd < bestD) {
            bestD = dd;
            best = d;
          }
        }
        return best;
      });
    }
    // Contacts.
    for (final c in _s.chasers) {
      if (c.mode == ChaserMode.waiting || c.mode == ChaserMode.eaten) continue;
      final dx = c.x - _s.runner.x, dy = c.y - _s.runner.y;
      if (dx * dx + dy * dy > 0.36) continue;
      if (c.mode == ChaserMode.frightened) {
        c.mode = ChaserMode.eaten;
        _s.score += 200 << _s.chain;
        if (_s.chain < 3) _s.chain++;
      } else {
        _s.lives--;
        if (_s.lives <= 0) {
          _s.over = true;
        } else {
          _s.deathPause = 1;
        }
        return;
      }
    }
    if (_s.pellets.isEmpty && _s.powerPellets.isEmpty) {
      _s.level++;
      _s.score += 500;
      _resetLevel();
    }
  }

  @override
  Map<String, Object?> snapshot() => {
    'tick': tick,
    'runner': [r4(_s.runner.x), r4(_s.runner.y), _s.runner.dir.index],
    'chasers': [
      for (final c in _s.chasers) [c.id.index, c.mode.index, r4(c.x), r4(c.y), c.dir.index],
    ],
    'pellets': _s.pellets.length,
    'power': _s.powerPellets.length,
    'score': _s.score,
    'lives': _s.lives,
    'level': _s.level,
    'rng': rng.state,
  };
}
