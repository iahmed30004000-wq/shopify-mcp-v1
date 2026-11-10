/// Road Crossing: hop forward across endless generated lanes.
///
/// Lanes are generated per row from the seed (the same row always looks
/// the same): grass (with trees that never close the lane), roads (vehicles
/// looping at a fixed speed and direction, gaps of at least two cells) and
/// rivers (logs to ride; water drowns, and riding off the edge is fatal).
/// Vehicle and log positions are closed-form functions of time, so the sim
/// is exact and cheap. A creeping storm line follows the player: lagging too
/// far behind it ends the run. The score is the furthest row reached.
library;

import 'dart:math' as math;

import '../../puzzles/core/grid.dart';
import '../core/arcade_sim.dart';

final class RoadConfig {
  const RoadConfig({this.level = ArcadeLevel.medium, this.seed = 0});

  final ArcadeLevel level;
  final int seed;

  static const int columns = 9;

  double get speedScale => switch (level) {
    ArcadeLevel.easy => 0.75,
    ArcadeLevel.medium => 1.0,
    ArcadeLevel.hard => 1.3,
  };
}

final class RoadInput {
  const RoadInput([this.hop]);
  static const RoadInput none = RoadInput();

  /// One-shot hop (up = forward).
  final Dir4? hop;
}

enum LaneKind { grass, road, river }

/// A lane: moving things repeat along a loop of [period] cells.
final class Lane {
  Lane(this.row, this.kind, {this.speed = 0, this.items = const [], this.lengths = const [], this.trees = const {}});

  final int row;
  final LaneKind kind;

  /// Cells per second; the sign is the direction.
  final double speed;

  /// Start offsets of vehicles / logs within the loop.
  final List<double> items;
  final List<int> lengths;
  final Set<int> trees;

  static const double period = RoadConfig.columns + 6.0;

  /// Left edges of every item at [time] (cells; may be off-screen).
  List<(double, int)> spans(double time) => [
    for (var i = 0; i < items.length; i++)
      (((items[i] + speed * time) % period + period) % period - 3, lengths[i]),
  ];

  /// Whether the cell interval [x - half, x + half] touches an item.
  bool covered(double x, double time, {double half = 0.35}) {
    for (final (l, len) in spans(time)) {
      if (x + half > l && x - half < l + len) return true;
    }
    return false;
  }
}

final class RoadState {
  /// Column (continuous while riding a log) and row.
  double x = RoadConfig.columns ~/ 2 * 1.0;
  int row = 0;
  int best = 0;
  double time = 0;
  double hopCooldown = 0;
  double storm = -4;
  bool moved = false;
  bool dead = false;

  /// Why the run ended: 'vehicle', 'water', 'edge', 'storm' (ids).
  String cause = '';
}

final class RoadCrossingSim extends FixedStepSim<RoadState, RoadInput> {
  RoadCrossingSim(this.config) : super(hz: 60);

  final RoadConfig config;
  final RoadState _s = RoadState();
  final Map<int, Lane> _lanes = {};

  static const double hopTime = 0.12;

  @override
  ArcadeKind get kind => ArcadeKind.roadCrossing;

  @override
  RoadState get state => _s;

  @override
  int get score => _s.best;

  @override
  bool get isOver => _s.dead;

  @override
  RoadInput heldOnly(RoadInput input) => RoadInput.none;

  @override
  RoadInput mergeInput(RoadInput earlier, RoadInput later) => later.hop != null ? later : earlier;

  /// Deterministic lane of [row]; rows are always generated in order.
  Lane lane(int row) {
    final cached = _lanes[row];
    if (cached != null) return cached;
    for (var r = 0; r <= row; r++) {
      if (!_lanes.containsKey(r)) _lanes[r] = _makeLane(r);
    }
    return _lanes[row]!;
  }

  Lane _makeLane(int row) {
    if (row < 3) return Lane(row, LaneKind.grass);
    final rng = SeededRng(config.seed * 1000003 + row * 7919);
    // Lane kind with streaks: the previous lane influences the next.
    final prev = row > 3 ? lane(row - 1).kind : LaneKind.grass;
    final roll = rng.nextDouble();
    LaneKind kind;
    if (prev == LaneKind.grass) {
      kind = roll < 0.5 ? LaneKind.road : (roll < 0.8 ? LaneKind.river : LaneKind.grass);
    } else {
      final streak = _streak(row - 1, prev);
      final stay = streak >= (prev == LaneKind.river ? 3 : 4) ? 0.0 : 0.6;
      kind = roll < stay ? prev : (roll < stay + 0.25 ? LaneKind.grass : (prev == LaneKind.road ? LaneKind.river : LaneKind.road));
    }
    final difficulty = math.min(1.0, row / 150);
    switch (kind) {
      case LaneKind.grass:
        final trees = <int>{};
        final prevFree = prev == LaneKind.grass
            ? {for (var c = 0; c < RoadConfig.columns; c++) if (!lane(row - 1).trees.contains(c)) c}
            : {for (var c = 0; c < RoadConfig.columns; c++) c};
        final count = rng.nextInt(4);
        for (var i = 0; i < count; i++) {
          trees.add(rng.nextInt(RoadConfig.columns));
        }
        // Keep at least three cells open, two of them shared with the lane
        // below, so a path forward always exists.
        final shared = prevFree.difference(trees);
        if (shared.length < 2 || RoadConfig.columns - trees.length < 3) trees.clear();
        return Lane(row, kind, trees: trees);
      case LaneKind.road:
        final dir = rng.nextBool() ? 1.0 : -1.0;
        final speed = dir * rng.nextDoubleRange(1.2, 2.6 + 1.6 * difficulty) * config.speedScale;
        final items = <double>[], lengths = <int>[];
        var at = rng.nextDoubleRange(0, 2);
        while (true) {
          final len = rng.nextInt(5) == 0 ? 2 : 1;
          if (at + len + 2 > Lane.period) break;
          items.add(at);
          lengths.add(len);
          at += len + rng.nextDoubleRange(2.5, 5.5 - 1.5 * difficulty);
        }
        return Lane(row, kind, speed: speed, items: items, lengths: lengths);
      case LaneKind.river:
        final dir = rng.nextBool() ? 1.0 : -1.0;
        final speed = dir * rng.nextDoubleRange(0.8, 1.6 + difficulty) * config.speedScale;
        final items = <double>[], lengths = <int>[];
        var at = rng.nextDoubleRange(0, 1);
        while (true) {
          final len = 2 + rng.nextInt(3) - (difficulty > 0.6 && rng.nextBool() ? 1 : 0);
          if (at + len > Lane.period - 1) break;
          items.add(at);
          lengths.add(len);
          at += len + rng.nextDoubleRange(1.0, 2.5 + difficulty);
        }
        return Lane(row, kind, speed: speed, items: items, lengths: lengths);
    }
  }

  int _streak(int row, LaneKind kind) {
    var n = 0;
    for (var r = row; r >= 3 && lane(r).kind == kind; r--) {
      n++;
    }
    return n;
  }

  @override
  void update(RoadInput input) {
    final dt = tickSeconds;
    _s.time += dt;
    _s.hopCooldown = math.max(0, _s.hopCooldown - dt);
    final here = lane(_s.row);
    // Ride logs.
    if (here.kind == LaneKind.river) _s.x += here.speed * dt;
    // Hop.
    final hop = input.hop;
    if (hop != null && _s.hopCooldown == 0) {
      final nx = (_s.x + hop.dx).roundToDouble();
      final nrow = _s.row - hop.dy; // up = forward
      if (nx >= 0 && nx < RoadConfig.columns && nrow >= 0) {
        final target = lane(nrow);
        final blocked = target.kind == LaneKind.grass && target.trees.contains(nx.toInt());
        if (!blocked) {
          _s.x = target.kind == LaneKind.river ? _s.x + hop.dx : nx;
          _s.row = nrow;
          _s.hopCooldown = hopTime;
          _s.moved = true;
          if (_s.row > _s.best) _s.best = _s.row;
        }
      }
    }
    // Storm line creeps forward once the player has moved.
    if (_s.moved) _s.storm += dt * (0.35 + 0.004 * _s.best) * config.speedScale;
    if (_s.storm < _s.best - 6) _s.storm = _s.best - 6.0;
    _check();
  }

  void _check() {
    final l = lane(_s.row);
    switch (l.kind) {
      case LaneKind.grass:
        break;
      case LaneKind.road:
        if (l.covered(_s.x, _s.time)) _die('vehicle');
      case LaneKind.river:
        if (!l.covered(_s.x, _s.time, half: 0.0)) _die('water');
        if (_s.x < -0.5 || _s.x > RoadConfig.columns - 0.5) _die('edge');
    }
    if (_s.row < _s.storm) _die('storm');
  }

  void _die(String cause) {
    if (_s.dead) return;
    _s.dead = true;
    _s.cause = cause;
  }

  @override
  Map<String, Object?> snapshot() => {
    'tick': tick,
    'x': r4(_s.x),
    'row': _s.row,
    'best': _s.best,
    'storm': r4(_s.storm),
    'dead': _s.dead,
    'cause': _s.cause,
  };
}
