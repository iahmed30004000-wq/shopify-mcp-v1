import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

import '../../../../core/domain/enums.dart';
import 'astrolabe_geometry.dart';
import 'astrolabe_state.dart';

/// Called when a prayer pointer starts to ignite (hook for Sfx.prayerLit and
/// a Celebrate orbitalRing burst).
typedef AstrolabeIgniteListener = void Function(Prayer prayer);

/// The astrolabe's animated values, advanced by the scene's single ticker
/// ([advance]) – the painter listens to it, so nothing rebuilds per frame.
///
/// * [time]: shader clock (brass glint, flame flicker, corona flow);
/// * [ignition]: 0 → 1 over [igniteDuration] when a prayer gets logged;
/// * [pulse]: the core star's celebration flare (1 → 0);
/// * [tilt] / [light]: gyro parallax and the brass highlight direction.
class AstrolabeController extends ChangeNotifier {
  AstrolabeController({
    AstrolabeState? state,
    this.igniteDuration = const Duration(milliseconds: 800),
    this.pulseDuration = const Duration(milliseconds: 1700),
    this.extinguishDuration = const Duration(milliseconds: 300),
    double initialTime = 12,
  }) : _time = initialTime {
    if (state != null) update(state, animate: false);
  }

  final Duration igniteDuration;
  final Duration pulseDuration;
  final Duration extinguishDuration;

  AstrolabeState? _state;
  AstrolabeState? get state => _state;

  double _time;

  /// Shader clock in seconds (frozen under reduced motion).
  double get time => _time;

  final Float64List _ignition = Float64List(5);
  final Float64List _target = Float64List(5);

  /// Ignition 0..1 of an obligatory prayer's fire.
  double ignition(Prayer p) {
    final i = AstrolabeGeometry.indexOf(p);
    return i < 0 ? 0 : _ignition[i];
  }

  double _pulse = 0;

  /// Core star celebration flare (0..1).
  double get pulse => _pulse;

  AstrolabeTilt _tilt = AstrolabeTilt.flat;
  AstrolabeTilt get tilt => _tilt;
  set tilt(AstrolabeTilt value) {
    if (value == _tilt) return;
    _tilt = value;
    _light = lightFor(value);
    notifyListeners();
  }

  Offset _light = lightFor(AstrolabeTilt.flat);

  /// Unit light direction in the screen plane for the brushed brass: from
  /// the upper left, swinging with the tilt (the highlight slides across the
  /// metal as the phone turns).
  Offset get light => _light;

  /// The brass light direction for a disc [tilt].
  static Offset lightFor(AstrolabeTilt tilt) {
    final x = -0.52 + tilt.yaw * 2.4;
    final y = -0.85 + tilt.pitch * 2.4;
    final len = math.sqrt(x * x + y * y);
    return len < 1e-6 ? const Offset(0, -1) : Offset(x / len, y / len);
  }

  bool _reducedMotion = false;

  /// Reduced motion: ignitions and pulses jump to their end, the clock stops.
  bool get reducedMotion => _reducedMotion;
  set reducedMotion(bool value) {
    if (value == _reducedMotion) return;
    _reducedMotion = value;
    if (value) _settle();
    notifyListeners();
  }

  /// Whether a one-shot animation (ignition, extinguish, pulse) is running –
  /// the scene should tick at full rate until it settles.
  bool get isAnimating {
    if (_pulse > 0) return true;
    for (var i = 0; i < 5; i++) {
      if (_ignition[i] != _target[i]) return true;
    }
    return false;
  }

  final List<AstrolabeIgniteListener> _igniteListeners = [];

  void addIgniteListener(AstrolabeIgniteListener l) => _igniteListeners.add(l);
  void removeIgniteListener(AstrolabeIgniteListener l) => _igniteListeners.remove(l);

  /// Pushes a new [state]. Prayers that became logged ignite: ignite
  /// listeners are told, the core star pulses and the fire grows 0 → 1 over
  /// [igniteDuration] (at once under reduced motion). Un-logged ones go out
  /// quickly. The first state, and any pushed with [animate] false, is shown
  /// as it is without celebrating. Returns the prayers that ignited.
  List<Prayer> update(AstrolabeState next, {bool animate = true}) {
    final quiet = _state == null || !animate;
    _state = next;
    final lit = <Prayer>[];
    for (var i = 0; i < 5; i++) {
      final p = AstrolabeGeometry.prayers[i];
      final on = next.prayed.contains(p) ? 1.0 : 0.0;
      if (on == _target[i]) continue;
      _target[i] = on;
      if (on == 1) {
        if (quiet) {
          _ignition[i] = 1;
        } else {
          _ignition[i] = _reducedMotion ? 1 : math.min(_ignition[i], 0.001);
          lit.add(p);
        }
      } else if (quiet || _reducedMotion) {
        _ignition[i] = 0;
      }
    }
    if (lit.isNotEmpty) {
      _flare(0.85);
      for (final p in lit) {
        for (final l in List<AstrolabeIgniteListener>.of(_igniteListeners)) {
          l(p);
        }
      }
    }
    notifyListeners();
    return lit;
  }

  /// Flares the core star (a completed task, a lit prayer, …).
  void celebrate({double strength = 1}) {
    if (_flare(strength)) notifyListeners();
  }

  bool _flare(double strength) {
    if (_reducedMotion) return false;
    _pulse = math.max(_pulse, strength.clamp(0.0, 1.0));
    return true;
  }

  /// Advances every animation by [dt] and repaints.
  void advance(Duration dt) => advanceSeconds(dt.inMicroseconds / 1e6);

  void advanceSeconds(double dt) {
    if (dt <= 0) return;
    if (_reducedMotion) {
      _settle();
    } else {
      _time += dt;
      final up = dt / (igniteDuration.inMicroseconds / 1e6);
      final down = dt / (extinguishDuration.inMicroseconds / 1e6);
      for (var i = 0; i < 5; i++) {
        final v = _ignition[i], t = _target[i];
        if (v < t) {
          _ignition[i] = math.min(t, v + up);
        } else if (v > t) {
          _ignition[i] = math.max(t, v - down);
        }
      }
      if (_pulse > 0) {
        _pulse = math.max(0, _pulse - dt / (pulseDuration.inMicroseconds / 1e6));
      }
    }
    notifyListeners();
  }

  void _settle() {
    for (var i = 0; i < 5; i++) {
      _ignition[i] = _target[i];
    }
    _pulse = 0;
  }

  @override
  void dispose() {
    _igniteListeners.clear();
    super.dispose();
  }
}
