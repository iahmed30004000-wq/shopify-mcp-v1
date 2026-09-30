import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import '../../../../core/motion/motion.dart';
import '../../../../core/motion/springs.dart';
import '../../domain/scene_math.dart';

/// The user's hold on the orbit camera (pure; unit-tested): drag to turn the
/// system (with inertia after a fling), drag vertically to tilt it, pinch to
/// zoom from the whole system to a single world (or into the astrolabe), a
/// slow cinematic drift and a [reset] that springs back to the exact pose of
/// a fresh start.
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

  /// Roll offset, only ever non-zero while a [reset] eases the drift's
  /// slant back to a fresh start's.
  final SpringMotion _roll = SpringMotion(spring: MadarMotion.gentle, tolerance: MadarSprings.unit);

  double _velocity = 0;
  bool _dragging = false, _pinching = false;
  double _pinchStartZoom = 0;
  String? _zoomKey;
  double _drift = 0;
  bool _homing = false;

  /// The cinematic drift's offsets (yaw, elevation, roll; radians) after
  /// [t] seconds of drift – a slow breath of a few degrees at most.
  static ({double yaw, double elevation, double roll}) driftAt(double t) => (
    yaw: 0.032 * math.sin(2 * math.pi * t / 53),
    elevation: 0.014 * math.sin(2 * math.pi * t / 71 + 1.3),
    roll: 0.006 * math.sin(2 * math.pi * t / 97 + 0.7),
  );

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

  /// Something moves: interaction, inertia or a spring (reset / zoom
  /// settle).
  bool get isMoving => interacting || !_yaw.isAtRest || !_tilt.isAtRest || !_zoom.isAtRest || !_roll.isAtRest;

  /// A [reset] is springing home (no touch has interrupted it yet).
  bool get isHoming => _homing;

  /// The camera is visibly away from the overview – turned more than ~3°,
  /// tilted more than ~2°, zoomed at all or still spinning (show the "reset
  /// view" control).
  bool get isAway => yaw.abs() > 0.05 || tilt.abs() > 0.035 || zoom > 0.02 || _velocity.abs() > restSpeed;

  // ------------------------------------------------------------- gestures --

  /// A gesture begins (one or two fingers). Stops any spin (and a reset in
  /// progress: the owner takes over where the camera is).
  void begin({bool pinch = false, String? zoomKey}) {
    _velocity = 0;
    _dragging = true;
    _homing = false;
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

  /// A touch was cut off without its end (the app left the foreground or
  /// the scene was hidden mid-gesture): the turn and tilt stay where they
  /// are (no fling), and a pinch the owner never released springs back out
  /// to the whole system – it is not "held" half-way (or past the point
  /// that opens a world) as a deliberate release would be.
  void cancelGesture() {
    if (!_dragging && !_pinching) return;
    final pinching = _pinching;
    _dragging = _pinching = false;
    if (pinching) _zoom.retarget(0, time: _time);
  }

  /// Springs back to the default overview – exactly the pose of a fresh
  /// start: no turn, tilt or zoom, no spin, and the drift's breath begun
  /// anew (the yaw goes the shortest way round; a spin carries into the
  /// spring instead of stopping dead).
  ///
  /// [gyroYaw] / [gyroPitch] are the parallax offsets (radians) the scene
  /// added to this frame and is about to drop: they are folded into the
  /// springs – like the drift's current offsets (unless the scene renders
  /// without [drift]) – so the view glides from exactly where it is instead
  /// of jumping.
  void reset({double gyroYaw = 0, double gyroPitch = 0, bool drift = true}) {
    final spin = _velocity;
    _velocity = 0;
    _dragging = _pinching = false;
    const still = (yaw: 0.0, elevation: 0.0, roll: 0.0);
    final now = drift ? driftAt(_drift) : still, fresh = drift ? driftAt(0) : still;
    var y = _yaw.value % (2 * math.pi);
    if (y > math.pi) y -= 2 * math.pi;
    final yawVelocity = spin != 0 ? spin : _yaw.velocity;
    _yaw
      ..jumpTo(y + now.yaw - fresh.yaw + gyroYaw * gyroYawGain)
      ..retarget(0, time: _time, velocity: yawVelocity);
    final tiltVelocity = _tilt.velocity;
    _tilt
      ..jumpTo(_tilt.value + now.elevation - fresh.elevation + gyroPitch * gyroPitchGain)
      ..retarget(0, time: _time, velocity: tiltVelocity);
    final rollVelocity = _roll.velocity;
    _roll
      ..jumpTo(_roll.value + now.roll - fresh.roll)
      ..retarget(0, time: _time, velocity: rollVelocity);
    _zoom.retarget(0, time: _time);
    _drift = 0;
    _homing = isMoving;
  }

  /// Jumps straight to the exact overview of a fresh start (reduced
  /// motion, tests).
  void snapHome() {
    _velocity = 0;
    _dragging = _pinching = false;
    _yaw.jumpTo(0);
    _tilt.jumpTo(0);
    _zoom.jumpTo(0);
    _roll.jumpTo(0);
    _zoomKey = null;
    _drift = 0;
    _homing = false;
  }

  /// Drops the pinch zoom at once (a world the pinch opened is now its
  /// page: the scene must not come back zoomed into it).
  void clearZoom() {
    if (_pinching) return;
    _zoom.jumpTo(0);
    _zoomKey = null;
  }

  /// Springs the pinch zoom back out to the whole system (turn and tilt
  /// stay): a world a pinch opened whose page closed before it landed must
  /// not stay filling the scene.
  void releaseZoom() {
    if (_pinching) return;
    _zoom.retarget(0, time: _time);
  }

  /// How much of the gyro parallax turns / tilts the camera (see [user]).
  static const double gyroYawGain = 0.9, gyroPitchGain = 0.7;

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
    _roll.advanceTo(_time);
    if (_zoom.isAtRest && _zoom.value <= 0.001) {
      _zoom.jumpTo(0);
      _zoomKey = null;
    }
    if (_homing && !isMoving) _homing = false;
  }

  /// The overview [base] turned and tilted by the user, breathing with the
  /// cinematic drift, offset by gyro parallax ([gyroYaw] / [gyroPitch],
  /// radians).
  OrbitCamera user(OrbitCamera base, {double gyroYaw = 0, double gyroPitch = 0, bool drift = true}) {
    final d = drift ? driftAt(_drift) : (yaw: 0.0, elevation: 0.0, roll: 0.0);
    final el = (base.elevation + tilt + d.elevation + gyroPitch * gyroPitchGain).clamp(
      minElevation - 0.05,
      maxElevation + 0.05,
    );
    return base.copyWith(
      azimuth: base.azimuth + yaw + d.yaw + gyroYaw * gyroYawGain,
      elevation: el,
      roll: base.roll + d.roll + _roll.value,
    );
  }
}
