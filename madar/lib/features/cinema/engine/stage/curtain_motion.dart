import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/animation.dart' show Curve, Curves;

/// The physics of the house curtains (pure Dart, no allocation per tick).
///
/// A stagehand hauls the rope along an eased profile; the curtain's
/// leading edge follows the rope through a stiff, slightly under-damped
/// spring (so a heavy velvet panel lags, overshoots a touch and settles),
/// and the hem swings like a damped pendulum driven by the edge's
/// acceleration (it trails while the curtain speeds up, swings past when it
/// stops). The tie-back gathers the drape only near fully open.
///
/// [open] is the leading edge as a fraction (0 = closed, 1 = open; the
/// spring may overshoot slightly outside that range), [swing] the hem's
/// angle in radians (+ = the hem trails toward the centre of the stage).
class CurtainMotion {
  CurtainMotion({double open = 0}) : _open = open, _rope = open, _ropeTo = open, _ropeFrom = open;

  // Spring of the leading edge (per unit of travel).
  static const double stiffness = 110;
  static const double damping = 15.5; // ζ ≈ 0.74 → a small overshoot
  // Pendulum of the hem: natural frequency (rad/s), damping ratio, and how
  // strongly the edge's acceleration (travel units/s²) drives it.
  static const double swingOmega = 3.6;
  static const double swingZeta = 0.22;
  static const double swingDrive = 0.25;
  static const double maxSwing = 0.14;

  double _open;
  double _vel = 0;
  double _acc = 0;
  double _swing = 0;
  double _swingVel = 0;
  double _phase = 0;

  // Rope haul.
  double _rope;
  double _ropeFrom;
  double _ropeTo;
  double _t = 1;
  double _duration = 0;
  double _settle = 0;
  Curve _curve = Curves.easeInOutCubic;
  Completer<void>? _done;

  /// Leading edge, 0 = closed … 1 = open (may overshoot a little).
  double get open => _open;

  /// [open] clamped to 0..1 (StageFrame.curtainOpen).
  double get openClamped => _open.clamp(0.0, 1.0);

  /// Edge velocity (travel fractions per second).
  double get velocity => _vel;

  /// Hem angle in radians (+ = trailing toward the stage centre).
  double get swing => _swing;

  /// Ripple phase for the fabric (advances with time and with speed).
  double get ripplePhase => _phase;

  /// Target of the current haul (0 or 1).
  double get target => _ropeTo;

  /// Tie-back gather 0..1: the drape is caught by its tassel only when the
  /// curtain is (nearly) open.
  double get gather {
    final t = ((_open - 0.55) / 0.45).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  bool get isMoving => _done != null || _t < 1 || _vel.abs() > 0.02 || _swing.abs() > 0.004;

  /// Hauls the curtain to [target] (0 closed, 1 open) over [duration]; the
  /// future completes when the drape has settled (game time).
  Future<void> haul(double target, Duration duration, {Curve curve = Curves.easeInOutCubic}) {
    _complete();
    final d = duration.inMicroseconds / 1e6;
    if (d <= 0) {
      jumpTo(target);
      return Future.value();
    }
    _ropeFrom = _rope;
    _ropeTo = target;
    _curve = curve;
    _duration = d;
    _t = 0;
    _settle = 0;
    return (_done = Completer<void>()).future;
  }

  /// Instantly at rest at [value].
  void jumpTo(double value) {
    _open = _rope = _ropeFrom = _ropeTo = value;
    _vel = _acc = _swing = _swingVel = 0;
    _t = 1;
    _complete();
  }

  void update(double dt) {
    if (dt <= 0) return;
    // Sub-step at ≤ 1/120 s so the spring stays stable at 20 fps too.
    final steps = math.max(1, (dt * 120).ceil());
    final h = dt / steps;
    for (var i = 0; i < steps; i++) {
      _step(h);
    }
    _phase += dt * (0.9 + _vel.abs() * 9);
    final d = _done;
    if (d != null && _t >= 1) {
      _settle += dt;
      final settled = (_open - _ropeTo).abs() < 0.004 && _vel.abs() < 0.03 && _swing.abs() < 0.03;
      if (settled || _settle > 1.4) _complete();
    }
  }

  void _step(double h) {
    if (_t < 1) {
      _t = math.min(1, _t + h / _duration);
      if (_t > 1 - 1e-6) _t = 1;
      _rope = _ropeFrom + (_ropeTo - _ropeFrom) * _curve.transform(_t);
    }
    final a = stiffness * (_rope - _open) - damping * _vel;
    _vel += a * h;
    _open += _vel * h;
    _acc = a;
    // Hem pendulum: trails the acceleration (opening = the edge moves out,
    // so a positive acceleration of `open` makes the hem trail inward).
    final w = swingOmega;
    final sa = -w * w * _swing - 2 * swingZeta * w * _swingVel + _acc * swingDrive;
    _swingVel += sa * h;
    _swing = (_swing + _swingVel * h).clamp(-maxSwing, maxSwing);
  }

  void _complete() {
    final d = _done;
    _done = null;
    if (d != null && !d.isCompleted) d.complete();
  }

  /// Completes any pending haul (dispose / scene cut).
  void cancel() => _complete();
}
