import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// A step of a breathing pattern.
enum BreathPhase { inhale, holdIn, exhale, holdOut }

/// A guided breathing rhythm (whole seconds per phase).
@immutable
class BreathingPattern {
  const BreathingPattern(this.id, this.steps);

  /// `478` or `box`.
  final String id;
  final List<(BreathPhase, int)> steps;

  /// 4-7-8: breathe in 4 s, hold 7 s, breathe out 8 s.
  static const fourSevenEight = BreathingPattern('478', [
    (BreathPhase.inhale, 4),
    (BreathPhase.holdIn, 7),
    (BreathPhase.exhale, 8),
  ]);

  /// Box: in 4, hold 4, out 4, hold 4.
  static const box = BreathingPattern('box', [
    (BreathPhase.inhale, 4),
    (BreathPhase.holdIn, 4),
    (BreathPhase.exhale, 4),
    (BreathPhase.holdOut, 4),
  ]);

  static const all = [fourSevenEight, box];

  static BreathingPattern byId(String? id) => all.firstWhere((p) => p.id == id, orElse: () => fourSevenEight);

  int get cycleSeconds => steps.fold(0, (s, e) => s + e.$2);

  Duration get cycle => Duration(seconds: cycleSeconds);

  Duration total(int cycles) => cycle * cycles;
}

/// Where a session is at a moment.
@immutable
class BreathState {
  const BreathState({
    required this.cycle,
    required this.stepIndex,
    required this.phase,
    required this.phaseSeconds,
    required this.phaseProgress,
    required this.expansion,
    required this.finished,
  });

  /// Zero-based cycle.
  final int cycle;

  /// Index into [BreathingPattern.steps].
  final int stepIndex;
  final BreathPhase phase;

  /// Length of the current phase.
  final int phaseSeconds;

  /// 0 → 1 through the current phase.
  final double phaseProgress;

  /// How open the breath ring is, 0 (empty lungs) → 1 (full), eased.
  final double expansion;
  final bool finished;

  /// Whole seconds left in the phase, counted down (4, 3, 2, 1).
  int get secondsLeft {
    final left = (phaseSeconds * (1 - phaseProgress)).ceil();
    return left.clamp(1, phaseSeconds);
  }

  /// Same step of the same cycle (a phase change fires the cue).
  bool samePhaseAs(BreathState o) => o.cycle == cycle && o.stepIndex == stepIndex && o.finished == finished;
}

abstract final class BreathingClock {
  /// The state [elapsed] into a session of [cycles] cycles (null = endless).
  static BreathState at(BreathingPattern pattern, Duration elapsed, {int? cycles}) {
    final cycleMs = pattern.cycleSeconds * 1000;
    final ms = elapsed.inMilliseconds < 0 ? 0 : elapsed.inMilliseconds;
    if (cycles != null && ms >= cycleMs * cycles) {
      final last = pattern.steps.length - 1;
      return BreathState(
        cycle: cycles - 1,
        stepIndex: last,
        phase: pattern.steps[last].$1,
        phaseSeconds: pattern.steps[last].$2,
        phaseProgress: 1,
        expansion: 0,
        finished: true,
      );
    }
    final cycle = ms ~/ cycleMs;
    var inCycle = ms - cycle * cycleMs;
    for (var i = 0; i < pattern.steps.length; i++) {
      final (phase, secs) = pattern.steps[i];
      final len = secs * 1000;
      if (inCycle < len || i == pattern.steps.length - 1) {
        final p = (inCycle / len).clamp(0.0, 1.0);
        return BreathState(
          cycle: cycle,
          stepIndex: i,
          phase: phase,
          phaseSeconds: secs,
          phaseProgress: p,
          expansion: expansionFor(phase, p),
          finished: false,
        );
      }
      inCycle -= len;
    }
    throw StateError('unreachable');
  }

  /// Ring opening for [phase] at progress [p] (sine ease, like a breath).
  static double expansionFor(BreathPhase phase, double p) => switch (phase) {
    BreathPhase.inhale => _ease(p),
    BreathPhase.holdIn => 1,
    BreathPhase.exhale => 1 - _ease(p),
    BreathPhase.holdOut => 0,
  };

  static double _ease(double t) => 0.5 - 0.5 * math.cos(t * math.pi);
}
