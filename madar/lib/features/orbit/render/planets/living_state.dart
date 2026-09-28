import 'dart:math' as math;

import 'package:flutter/physics.dart';

import '../../../../core/motion/springs.dart';

/// Springs of the living planets.
abstract final class LivingSprings {
  /// The displayed score easing toward the real one: critically damped
  /// (never overshoots into the wrong state) and slow enough to be watched –
  /// ~90 % of the way at 0.65 s, visually settled by ~1.2 s.
  static final SpringDescription morph = SpringDescription.withDampingRatio(mass: 1, stiffness: 34, ratio: 1.0);

  /// A world or moon moving to a new lane after a reorder.
  static final SpringDescription lane = SpringDescription.withDampingRatio(mass: 1, stiffness: 22, ratio: 1.0);
}

/// The celebration flare after a completion: 0 → 1 → 0 over [duration].
///
/// A quick smooth rise (the world flashes as the particles leave it) and a
/// long ease-out decay (the glow lingers, then settles).
abstract final class PulseEnvelope {
  static const double duration = 1.5;
  static const double attack = 0.22;

  /// Envelope value [seconds] after the trigger (0 outside the pulse).
  static double at(double seconds) {
    if (seconds <= 0 || seconds >= duration) return 0;
    if (seconds < attack) {
      final x = seconds / attack;
      return x * x * (3 - 2 * x);
    }
    final x = (seconds - attack) / (duration - attack);
    final k = 1 - x;
    // Ease-out: fast initial fall-off of the peak, soft tail to exactly 0.
    return k * k * (0.35 + 0.65 * k);
  }
}

class _Living {
  _Living(double score) : spring = SpringMotion(spring: LivingSprings.morph, value: score);

  final SpringMotion spring;
  double pulseAge = double.infinity;
  double pulseStrength = 0;
}

/// Per-key living state of the orbit's bodies (planets and moons): the
/// **displayed** score that springs toward the real score, and the pulse
/// envelope of completion events.
///
/// Pure Dart with an explicit clock: the scene's single ticker calls
/// [advance]; nothing here allocates per frame.
class LivingStateAnimator {
  LivingStateAnimator({this._time = 0});

  final Map<String, _Living> _states = {};
  double _time;

  /// Seconds on this animator's clock.
  double get time => _time;

  bool _reducedMotion = false;

  /// Reduced motion: scores jump to their targets and pulses do not flare.
  bool get reducedMotion => _reducedMotion;
  set reducedMotion(bool value) {
    if (value == _reducedMotion) return;
    _reducedMotion = value;
    if (value) _settleAll();
  }

  /// Keys that have a state.
  Iterable<String> get keys => _states.keys;

  bool contains(String key) => _states.containsKey(key);

  /// Sets the real score of [key]. A new key shows it at once; a known key
  /// morphs toward it (unless [animate] is false or motion is reduced).
  /// Returns whether a morph started.
  bool setScore(String key, double score, {bool animate = true}) {
    final s = score.clamp(0.0, 1.0);
    final st = _states[key];
    if (st == null) {
      _states[key] = _Living(s);
      return false;
    }
    if (st.spring.target == s) return false;
    if (!animate || _reducedMotion) {
      st.spring.jumpTo(s);
      return false;
    }
    st.spring.retarget(s, time: _time);
    return !st.spring.isAtRest;
  }

  /// Flares [key] (a completion). [strength] 0..1 scales the envelope; a
  /// pulse that is still bright is not dimmed by a weaker one.
  void pulse(String key, {double strength = 1}) {
    if (_reducedMotion) return;
    final st = _states[key];
    if (st == null) return;
    final s = strength.clamp(0.0, 1.0);
    final current = PulseEnvelope.at(st.pulseAge) * st.pulseStrength;
    if (current > s) return;
    // Restart on the rising edge at the current brightness (no dip).
    st.pulseStrength = s;
    st.pulseAge = _riseAgeFor(s == 0 ? 0 : current / s);
  }

  /// The displayed score (0.6 for unknown keys – a calm world).
  double score(String key) => _states[key]?.spring.value ?? 0.6;

  /// The real score [key] is heading for.
  double targetOf(String key) => _states[key]?.spring.target ?? 0.6;

  /// `uPulse` of [key] now.
  double pulseOf(String key) {
    final st = _states[key];
    if (st == null) return 0;
    return PulseEnvelope.at(st.pulseAge) * st.pulseStrength;
  }

  /// A score is morphing or a pulse is running – the scene should render at
  /// full rate until this turns false.
  bool get isAnimating {
    for (final st in _states.values) {
      if (!st.spring.isAtRest || st.pulseAge < PulseEnvelope.duration) return true;
    }
    return false;
  }

  /// Advances every spring and pulse by [dt] seconds.
  void advance(double dt) {
    if (dt <= 0) return;
    _time += dt;
    for (final st in _states.values) {
      if (!st.spring.isAtRest) st.spring.advanceTo(_time);
      if (st.pulseAge < PulseEnvelope.duration) st.pulseAge += dt;
    }
  }

  /// Forgets every key not in [keep] (removed planets / moons).
  void retain(Set<String> keep) => _states.removeWhere((k, _) => !keep.contains(k));

  void _settleAll() {
    for (final st in _states.values) {
      st.spring.jumpTo(st.spring.target);
      st.pulseAge = double.infinity;
      st.pulseStrength = 0;
    }
  }

  /// Age on the rising edge where the envelope equals [level] (0..1).
  static double _riseAgeFor(double level) {
    if (level <= 0) return 1e-6;
    if (level >= 1) return PulseEnvelope.attack;
    // Invert smoothstep by bisection (a handful of iterations, only on a
    // pulse event).
    var lo = 0.0, hi = 1.0;
    for (var i = 0; i < 18; i++) {
      final m = (lo + hi) / 2;
      final v = m * m * (3 - 2 * m);
      if (v < level) {
        lo = m;
      } else {
        hi = m;
      }
    }
    return math.max(1e-6, (lo + hi) / 2 * PulseEnvelope.attack);
  }
}

/// Smoothly fades a set of keyed opacities toward their targets (labels
/// appearing and disappearing). First-order, frame-rate independent.
class OpacityFader {
  OpacityFader({this.timeConstant = 0.16});

  /// Seconds to cover ~63 % of the remaining distance.
  final double timeConstant;

  final Map<String, double> _value = {};
  final Map<String, double> _target = {};

  /// Current opacity (0 for unknown keys).
  double of(String key) => _value[key] ?? 0;

  /// Sets where [key] is heading. A new key starts from [initial] (0 =
  /// fade in, or the target itself when [snap]).
  void target(String key, double value, {bool snap = false}) {
    final v = value.clamp(0.0, 1.0);
    _target[key] = v;
    if (snap || !_value.containsKey(key)) _value[key] = snap ? v : 0;
  }

  /// Jumps every key to its target.
  void settle() {
    for (final e in _target.entries) {
      _value[e.key] = e.value;
    }
  }

  bool get isAnimating {
    for (final e in _target.entries) {
      if (((_value[e.key] ?? 0) - e.value).abs() > 0.004) return true;
    }
    return false;
  }

  void advance(double dt) {
    if (dt <= 0) return;
    final k = 1 - math.exp(-dt / timeConstant);
    for (final e in _target.entries) {
      final v = _value[e.key] ?? 0;
      final next = v + (e.value - v) * k;
      _value[e.key] = (e.value - next).abs() <= 0.004 ? e.value : next;
    }
  }

  /// Forgets keys not in [keep].
  void retain(Set<String> keep) {
    _value.removeWhere((k, _) => !keep.contains(k));
    _target.removeWhere((k, _) => !keep.contains(k));
  }
}
