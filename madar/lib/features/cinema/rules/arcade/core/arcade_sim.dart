/// The uniform interface of the Madar Cinema Tier 2 arcade simulations.
///
/// Pure Dart, logic only: no rendering, no Flutter, no user-facing text.
/// Every simulation advances in fixed ticks (60 Hz unless stated) from a
/// variable frame `dt`, draws randomness from a [SeededRng] and is fully
/// deterministic: the same seed and the same `(dt, input)` sequence give the
/// same [ArcadeSim.snapshot].
library;

import 'dart:math' as math;

export '../../puzzles/core/seeded_rng.dart';

/// The arcade games implemented under `rules/arcade`.
enum ArcadeKind {
  snake,
  brickBreaker,
  starHunter,
  asteroidBelt,
  paddleDuel,
  stackTower,
  fruitSlice,
  skyJumper,
  mazeChase,
  roadCrossing,
  pinball,
}

/// AI / pacing difficulty shared by the arcade games.
enum ArcadeLevel { easy, medium, hard }

/// The contract every simulation implements.
abstract interface class ArcadeSim<S, I> {
  ArcadeKind get kind;

  /// The live simulation state (treat as read-only).
  S get state;
  int get score;
  bool get isOver;

  /// Fixed ticks simulated so far.
  int get tick;

  /// Seconds per fixed tick.
  double get tickSeconds;

  /// Fraction of a tick left in the accumulator (render interpolation).
  double get alpha;

  /// Advances by [dt] seconds of real time with [input].
  void step(double dt, I input);

  /// A JSON-friendly snapshot of everything that drives the simulation.
  Map<String, Object?> snapshot();
}

/// Fixed-timestep plumbing: accumulates frame time, runs whole ticks and
/// delivers one-shot input events exactly once (carrying them over when a
/// frame is too short to run a tick).
abstract class FixedStepSim<S, I> implements ArcadeSim<S, I> {
  FixedStepSim({this.hz = 60, this.maxTicksPerStep = 8});

  final int hz;

  /// Frames longer than this many ticks are clamped (no spiral of death).
  final int maxTicksPerStep;

  double _acc = 0;
  int _tick = 0;
  I? _pending;

  @override
  double get tickSeconds => 1 / hz;

  @override
  int get tick => _tick;

  @override
  double get alpha => (_acc / tickSeconds).clamp(0.0, 1.0);

  /// One fixed tick.
  void update(I input);

  /// [input] without its one-shot events (used after the first tick of a
  /// frame).
  I heldOnly(I input) => input;

  /// Combines carried-over events with the next frame's input.
  I mergeInput(I earlier, I later) => later;

  @override
  void step(double dt, I input) {
    var d = dt.isNaN || dt < 0 ? 0.0 : dt;
    d = math.min(d, maxTicksPerStep * tickSeconds);
    _acc += d;
    var current = _pending == null ? input : mergeInput(_pending as I, input);
    _pending = null;
    var ran = false;
    while (_acc + 1e-9 >= tickSeconds) {
      _acc -= tickSeconds;
      if (isOver) {
        _acc = 0;
        return;
      }
      update(current);
      _tick++;
      current = heldOnly(current);
      ran = true;
    }
    if (!ran) _pending = current;
  }

  /// Runs exactly [ticks] ticks with [input] (tests, AI, replays).
  void runTicks(int ticks, I input) {
    for (var i = 0; i < ticks && !isOver; i++) {
      update(i == 0 ? input : heldOnly(input));
      _tick++;
    }
  }
}

/// Rounds for compact, stable snapshots.
double r4(double v) => (v * 10000).roundToDouble() / 10000;
