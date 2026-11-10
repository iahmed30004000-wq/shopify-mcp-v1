import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'compass_math.dart';

/// One tilt-compensated solution from a gravity and a magnetic vector.
@immutable
class TiltSolution {
  const TiltSolution({
    required this.heading,
    required this.pitch,
    required this.roll,
    required this.dip,
    required this.fieldMicroTesla,
    required this.gravity,
    required this.pointing,
  });

  /// Magnetic heading of the direction the screen faces "forward" (degrees
  /// clockwise from magnetic north, [0, 360)).
  final double heading;

  /// Elevation of the screen's top edge above the horizontal (degrees).
  final double pitch;

  /// Elevation of the screen's right edge above the horizontal (degrees).
  final double roll;

  /// Measured inclination of the field below the horizontal (degrees).
  final double dip;

  /// |B| in microtesla.
  final double fieldMicroTesla;

  /// |a| in m/s² (≈ 9.81 when the phone is held still).
  final double gravity;

  /// How well the pointing direction is defined (0 … 1): 1 when the phone
  /// is flat or upright, → 0 when the top edge points at the ground.
  final double pointing;
}

/// Tilt-compensated compass maths (the same construction as Android's
/// `SensorManager.getRotationMatrix`, generalised to any pointing axis).
///
/// With A the accelerometer (pointing up when still) and E the magnetic
/// field, both in device coordinates, H = E × A is magnetic east and
/// M = A × H magnetic north, both horizontal. The heading of any device
/// direction v is atan2(H·v, M·v).
///
/// The direction the user "points" is the screen's top edge while the phone
/// lies in the palm (pitch below 45°, any roll), and blends smoothly into
/// the back of the phone as it is raised toward upright like a camera
/// (v = top + w·back, w rising 0 → 1 between 45° and 80° of pitch). Both
/// point the same way whenever the top is raised, so the heading stays
/// defined through every pitch between the two; only a phone both steeply
/// raised and rolled reads between its top edge and its back.
abstract final class TiltCompass {
  /// Standard gravity (m/s²).
  static const double g0 = 9.80665;

  /// The screen's "up" axis in device coordinates for [quarterTurns] of
  /// display rotation (0 = natural portrait; 1 = Android ROTATION_90, the
  /// device's +x edge up; 2 = upside down; 3 = ROTATION_270, −x edge up).
  static Vec3 screenUp(int quarterTurns) => switch (quarterTurns % 4) {
    0 => const Vec3(0, 1, 0),
    1 => const Vec3(1, 0, 0),
    2 => const Vec3(0, -1, 0),
    _ => const Vec3(-1, 0, 0),
  };

  /// The screen's "right" axis for [quarterTurns].
  static Vec3 screenRight(int quarterTurns) => screenUp(quarterTurns + 1);

  /// Weight of the back of the phone in the pointing direction for a top
  /// edge raised by asin([raise]) (smoothstep from 45° to 80°).
  static double backWeight(double raise) {
    const lo = 0.7071067811865476; // sin 45°
    const hi = 0.984807753012208; // sin 80°
    final t = ((raise - lo) / (hi - lo)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  /// Solves the heading, or returns null when the inputs are degenerate
  /// (free fall, no field, or the field parallel to gravity – at a magnetic
  /// pole or in a strong disturbance).
  static TiltSolution? solve(Vec3 accel, Vec3 magnetic, {int quarterTurns = 0}) {
    if (!accel.isFinite || !magnetic.isFinite) return null;
    final gLen = accel.length;
    final bLen = magnetic.length;
    if (gLen < 1.0 || bLen < 1e-3) return null;
    final up = accel * (1 / gLen);
    final hRaw = magnetic.cross(up);
    // |E × Â| is the horizontal field strength (µT); below ~0.5 µT the
    // horizontal direction is noise.
    if (hRaw.length < 0.5) return null;
    final east = hRaw.normalized;
    final north = up.cross(east);

    final top = screenUp(quarterTurns);
    const back = Vec3(0, 0, -1);
    final raise = top.dot(up);
    final v = top + back * backWeight(raise);
    final horizontal = v - up * v.dot(up);
    final pointing = math.min(1.0, horizontal.length / 0.7);
    if (horizontal.length < 1e-6) return null;

    final heading = CircularMath.wrap360(math.atan2(east.dot(v), north.dot(v)) * CircularMath.degPerRad);
    final pitch = math.asin(raise.clamp(-1.0, 1.0)) * CircularMath.degPerRad;
    final roll = math.asin(screenRight(quarterTurns).dot(up).clamp(-1.0, 1.0)) * CircularMath.degPerRad;
    final dip = math.asin((-magnetic.dot(up) / bLen).clamp(-1.0, 1.0)) * CircularMath.degPerRad;
    return TiltSolution(
      heading: heading,
      pitch: pitch,
      roll: roll,
      dip: dip,
      fieldMicroTesla: bLen,
      gravity: gLen,
      pointing: pointing,
    );
  }

  /// Picks the landscape quarter turn from gravity (the edge that is up),
  /// keeping [previous] inside a ±[hysteresis] m/s² dead band.
  static int landscapeTurns(Vec3 accel, {int? previous, double hysteresis = 1.5}) {
    if (previous == 1 && accel.x > -hysteresis) return 1;
    if (previous == 3 && accel.x < hysteresis) return 3;
    return accel.x >= 0 ? 1 : 3;
  }
}
