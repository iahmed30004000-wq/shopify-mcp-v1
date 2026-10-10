import 'dart:async';

import 'package:flutter/animation.dart';

/// A game-time tween with a completion future, advanced by [update] from the
/// game loop (never its own Ticker). Retargeting or jumping completes the
/// pending future, so awaiting code always proceeds.
const double _eps = 1e-6;

class CinemaTween {
  CinemaTween([double value = 0]) : _value = value, _from = value, _to = value;

  double _value;
  double _from;
  double _to;
  double _t = 1;
  double _duration = 0;
  Curve _curve = Curves.linear;
  Completer<void>? _done;

  double get value => _value;
  double get target => _to;
  bool get isActive => _t < 1;

  Future<void> animateTo(double target, Duration duration, {Curve curve = Curves.easeInOutCubic}) {
    _complete();
    _from = _value;
    _to = target;
    _curve = curve;
    _duration = duration.inMicroseconds / 1e6;
    if (_duration <= 0 || _from == _to) {
      _value = _to;
      _t = 1;
      return Future.value();
    }
    _t = 0;
    return (_done = Completer<void>()).future;
  }

  void jumpTo(double value) {
    _value = _from = _to = value;
    _t = 1;
    _complete();
  }

  void update(double dt) {
    if (_t >= 1) return;
    _t = (_t + dt / _duration).clamp(0.0, 1.0);
    // Snap the last float ulps (30 × 1/60 s must finish a 0.5 s tween).
    if (_t > 1 - _eps) _t = 1;
    _value = _from + (_to - _from) * _curve.transform(_t);
    if (_t >= 1) {
      _value = _to;
      _complete();
    }
  }

  void _complete() {
    final d = _done;
    _done = null;
    if (d != null && !d.isCompleted) d.complete();
  }
}

/// A game-time delay (e.g. how long an intertitle holds), advanced by
/// [update]. [cancel] completes it early.
class CinemaDelay {
  double _left = 0;
  Completer<void>? _done;

  bool get isActive => _done != null;

  Future<void> start(Duration duration) {
    cancel();
    _left = duration.inMicroseconds / 1e6;
    if (_left <= 0) return Future.value();
    return (_done = Completer<void>()).future;
  }

  void update(double dt) {
    if (_done == null) return;
    _left -= dt;
    if (_left <= _eps) cancel();
  }

  void cancel() {
    final d = _done;
    _done = null;
    if (d != null && !d.isCompleted) d.complete();
  }
}
