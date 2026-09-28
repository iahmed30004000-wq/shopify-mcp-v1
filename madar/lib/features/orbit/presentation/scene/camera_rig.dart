import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import '../../../../core/motion/motion.dart';
import '../../../../core/motion/springs.dart';
import '../../domain/scene_math.dart';

/// The user's hold on the orbit camera (pure; unit-tested): drag to turn the
/// system (with inertia after a fling), drag vertically to tilt it, pinch to
/// zoom from the whole system to a single world (or into the astrolabe), a
/// slow cinematic drift and a spring back to the overview.
///
/// The scene composes the final camera as `user(base)` → optional zoom lerp
/// (see [zoomEased] and [zoomKey]) → optional fly-in lerp.
class CameraRig {
  CameraRig({this.minElevation = 0.3, this.maxElevation = 1.02});

  /// Tilt limits of the camera (radians above the orbital plane).
  final double minElevation, maxElevation;

  /// Radians of azimuth per viewport width dragged.
  static const double turnPerWidth = 0.9 * math.pi;

  /// Radians of elevation per viewport height dragged.
  static const double tiltPerHeight = 1.3;

  /// Fling friction (1/s).
  static const double friction = 2.6;

  /// Below this angular speed (rad/s) a spin has stopped.
  static const double restSpeed = 0.01;

  /// Zoom gained per e-fold of pinch scale.
  static const double zoomPerLogScale = 1.15;

  double _time = 0;

  final SpringMotion _yaw = SpringMotion(spring: MadarMotion.gentle, tolerance: MadarSprings.unit);
  final SpringMotion _tilt = SpringMotion(spring: MadarMotion.gentle, tolerance: MadarSprings.unit);
  final SpringMotion _zoom = SpringMotion(spring: MadarMotion.gentle, tolerance: MadarSprings.unit);

  double _velocity = 0;
  bool _dragging = false, _pinching = false;
  double _pinchStartZoom = 0;
  String? _zoomKey;
  double _drift = 0;

  /// User azimuth offset from the overview (radians, unbounded).
  double get yaw => _yaw.value;

  /// User elevation offset from the overview (radians).
  double get tilt => _tilt.value;

  /// Pinch zoom 0 (whole system) … 1 (one world / the dial up close).
  double get zoom => _zoom.value.clamp(0.0, 1.0);

  /// [zoom] eased for the camera move.
  double get zoomEased => MadarMotion.standard.transform(zoom);

  /// The world the pinch zooms into; null = the astrolabe.
  String? get zoomKey => _zoomKey;

  /// Seconds of drift so far.
  double get driftTime => _drift;

  /// A finger is on the scene or it is still spinning from a fling.
  bool get interacting => _dragging || _pinching || _velocity.abs() > restSpeed;

  /// Something moves: interaction, inertia or a spring (recenter / zoom
  /// settle).
  bool get isMoving => interacting || !_yaw.isAtRest || !_tilt.isAtRest || !_zoom.isAtRest;

  /// The camera is away from the overview (show a "back to the orbit"
  /// control).
  bool get isAway => yaw.abs() > 0.12 || tilt.abs() > 0.06 || zoom > 0.04;

  // ------------------------------------------------------------- gestures --

  /// A gesture begins (one or two fingers). Stops any spin.
  void begin({bool pinch = false, String? zoomKey}) {
    _velocity = 0;
    _dragging = true;
    _yaw.jumpTo(_yaw.value);
    _tilt.jumpTo(_tilt.value);
    if (pinch) startPinch(zoomKey: zoomKey);
  }

  /// A second finger arrived: pinch into [zoomKey] (null = the astrolabe).
  void startPinch({String? zoomKey}) {
    if (_pinching) return;
    _pinching = true;
    if (_zoom.value <= 0.02) _zoomKey = zoomKey;
    _zoom.jumpTo(_zoom.value);
    _pinchStartZoom = _zoom.value;
  }

  /// A finger moved by [delta] px on a [viewport]-sized scene: turn / tilt.
  /// Dragging right turns the near side of the system to the right.
  void dragBy(Offset delta, Size viewport, {required double baseElevation}) {
    if (viewport.isEmpty) return;
    final dYaw = -delta.dx / viewport.width * turnPerWidth;
    final dTilt = delta.dy / viewport.height * tiltPerHeight;
    _yaw.jumpTo(_yaw.value + dYaw);
    final lo = minElevation - baseElevation, hi = maxElevation - baseElevation;
    _tilt.jumpTo((_tilt.value + dTilt).clamp(lo, hi));
  }

  /// Pinch scale relative to the gesture start.
  void pinchTo(double scale) {
    if (!_pinching || !scale.isFinite || scale <= 0) return;
    _zoom.jumpTo((_pinchStartZoom + math.log(scale) * zoomPerLogScale).clamp(0.0, 1.0));
    if (_zoom.value <= 0.001 && scale < 1) _zoomKey = null;
  }

  /// The gesture ended with [velocity] px/s: a horizontal fling keeps the
  /// system spinning (friction); a barely-zoomed pinch springs back.
  void end({Offset velocity = Offset.zero, Size viewport = Size.zero}) {
    _dragging = false;
    if (_pinching) {
      _pinching = false;
      if (_zoom.value < 0.12) _zoom.retarget(0, time: _time);
    } else if (!viewport.isEmpty) {
      final v = -velocity.dx / viewport.width * turnPerWidth;
      _velocity = v.abs() > restSpeed * 4 ? v.clamp(-4.0, 4.0) : 0;
    }
  }

  /// Springs back to the overview (yaw along the shortest way round).
  void recenter() {
    _velocity = 0;
    _dragging = _pinching = false;
    var y = _yaw.value % (2 * math.pi);
    if (y > math.pi) y -= 2 * math.pi;
    _yaw.jumpTo(y);
    _yaw.retarget(0, time: _time);
    _tilt.retarget(0, time: _time);
    _zoom.retarget(0, time: _time);
  }

  /// Jumps straight to the overview (reduced motion, tests).
  void snapHome() {
    _velocity = 0;
    _dragging = _pinching = false;
    _yaw.jumpTo(0);
    _tilt.jumpTo(0);
    _zoom.jumpTo(0);
    _zoomKey = null;
  }

  // ------------------------------------------------------------- animation --

  /// Advances inertia, springs and (unless [drift] is false) the drift.
  void advance(double dt, {bool drift = true}) {
    if (!dt.isFinite || dt <= 0) return;
    _time += dt;
    if (drift) _drift += dt;
    if (_velocity != 0 && !_dragging) {
      _yaw.jumpTo(_yaw.value + _velocity * dt);
      _velocity *= math.exp(-friction * dt);
      if (_velocity.abs() < restSpeed) _velocity = 0;
    }
    _yaw.advanceTo(_time);
    _tilt.advanceTo(_time);
    _zoom.advanceTo(_time);
    if (_zoom.isAtRest && _zoom.value <= 0.001) {
      _zoom.jumpTo(0);
      _zoomKey = null;
    }
  }

  /// The overview [base] turned and tilted by the user, breathing with the
  /// cinematic drift, offset by gyro parallax ([gyroYaw] / [gyroPitch],
  /// radians).
  OrbitCamera user(OrbitCamera base, {double gyroYaw = 0, double gyroPitch = 0, bool drift = true}) {
    final t = _drift;
    final dYaw = drift ? 0.032 * math.sin(2 * math.pi * t / 53) : 0.0;
    final dEl = drift ? 0.014 * math.sin(2 * math.pi * t / 71 + 1.3) : 0.0;
    final dRoll = drift ? 0.006 * math.sin(2 * math.pi * t / 97 + 0.7) : 0.0;
    final el = (base.elevation + tilt + dEl + gyroPitch * 0.7).clamp(minElevation - 0.05, maxElevation + 0.05);
    return base.copyWith(azimuth: base.azimuth + yaw + dYaw + gyroYaw * 0.9, elevation: el, roll: base.roll + dRoll);
  }
}
