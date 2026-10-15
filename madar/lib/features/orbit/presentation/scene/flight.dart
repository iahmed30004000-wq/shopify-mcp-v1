import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/animation.dart' show Cubic, Curve;

import '../../../../core/motion/motion.dart';
import '../../domain/scene_math.dart';

/// Camera interpolation for cinematic moves (pure).
abstract final class CameraPath {
  /// Interpolates [a] → [b]: azimuth along the shortest arc, distance
  /// geometrically (so the apparent zoom rate is even instead of rushing at
  /// the end), everything else linearly.
  static OrbitCamera lerp(OrbitCamera a, OrbitCamera b, double t) {
    if (t <= 0) return a;
    if (t >= 1) return b;
    var dAz = (b.azimuth - a.azimuth) % (2 * math.pi);
    if (dAz > math.pi) dAz -= 2 * math.pi;
    if (dAz < -math.pi) dAz += 2 * math.pi;
    double l(double x, double y) => x + (y - x) * t;
    final da = math.max(a.distance, 1e-4), db = math.max(b.distance, 1e-4);
    return OrbitCamera(
      target: V3.lerp(a.target, b.target, t),
      azimuth: a.azimuth + dAz * t,
      elevation: l(a.elevation, b.elevation),
      distance: math.exp(l(math.log(da), math.log(db))),
      roll: l(a.roll, b.roll),
      fovY: l(a.fovY, b.fovY),
      principal: Offset.lerp(a.principal, b.principal, t)!,
    );
  }

  /// Whether two cameras render the same view (within float noise).
  static bool same(OrbitCamera a, OrbitCamera b, {double eps = 1e-9}) =>
      identical(a, b) ||
      ((a.azimuth - b.azimuth).abs() < eps &&
          (a.elevation - b.elevation).abs() < eps &&
          (a.roll - b.roll).abs() < eps &&
          (a.distance - b.distance).abs() < eps &&
          (a.fovY - b.fovY).abs() < eps &&
          (a.principal - b.principal).distanceSquared < eps &&
          (a.target - b.target).length < eps);
}

/// The choreography of a planet fly-in / fly-out as functions of the raw
/// route progress t ∈ [0, 1] (pure; the reverse runs the same curves
/// backwards, so the fly-out is the exact reverse of the fly-in).
abstract final class FlightTiming {
  /// Fly-in and fly-out duration (quality gate: < 800 ms).
  static const Duration duration = MadarMotion.cinematic;

  /// The camera's ease: a gentle first beat, then a confident rush that
  /// has the world at ~60 % of its final size by t = 0.5, and a long soft
  /// landing (the zoom is geometric, so most of the growth must not be
  /// left to the end).
  static const Curve cameraCurve = Cubic(0.32, 0.0, 0.16, 1.0);

  /// Eased camera progress.
  static double camera(double t) => cameraCurve.transform(t.clamp(0.0, 1.0));

  /// How far the camera rises above the straight path mid-flight
  /// (radians of elevation at eased progress [c]): an arc over the system,
  /// so the astrolabe sweeps past in the foreground.
  static double arcLift(double c) {
    final x = c.clamp(0.0, 1.0);
    return 0.16 * math.sin(math.pi * x) * (1 - 0.35 * x);
  }

  /// Depth of field of everything but the target world, 0..1 of the
  /// maximum blur.
  static double depthOfField(double t) => _smooth(0.1, 0.7, t);

  /// Radial motion blur strength (0..1): on through the fast part
  /// (t ≈ 0.2 … 0.7), off for the take-off and the landing.
  static double motionBlur(double t) {
    final x = t.clamp(0.0, 1.0);
    return _smooth(0.1, 0.24, x) * (1 - _smooth(0.62, 0.8, x));
  }

  /// Opacity of the astrolabe: it stays (blurring) while the camera sweeps
  /// past it, then fades.
  static double astrolabe(double t) => 1 - _smooth(0.22, 0.6, t);

  /// Home's header leaving: 0 → 1.
  static double chromeOut(double t) => _smooth(0, 0.28, t);

  /// Home's glass panel sliding straight down off the screen (ease-in, at
  /// full opacity – it never double-exposes over the flight), gone by
  /// t = [panelGone]: 0 → 1 of its own height.
  static double panelOut(double t) {
    final x = (t / panelGone).clamp(0.0, 1.0);
    return x * x * (0.35 + 0.65 * x);
  }

  /// When home's panel has left the screen.
  static const double panelGone = 0.45;

  /// The worlds' name labels leaving (0 → 1): gone by t = 0.2, before the
  /// camera really moves (blurred labels would read as smudges).
  static double labelsOut(double t) => _smooth(0, 0.2, t);

  /// When the planet page's sheet starts to rise: just after home's panel
  /// has gone, as the world sinks onto its landing spot – one continuous
  /// hand-off from the panel to the sheet (the gap between them shows the
  /// horizon haze, never an empty slab).
  static const double sheetStart = 0.55;

  /// The planet page's glass sheet rising from below the screen onto the
  /// world's surface (decelerating): 0 → 1.
  static double sheet(double t) {
    final x = ((t - sheetStart) / (1 - sheetStart)).clamp(0.0, 1.0);
    final k = 1 - x;
    return 1 - k * k * k;
  }

  /// The sky's horizon settles a little lower as the camera rises toward a
  /// world (fraction of the viewport added to the horizon height).
  static double horizonLift(double t) => 0.12 * camera(t);

  /// The planet page's header appearing: 0 → 1.
  static double header(double t) => _smooth(0.62, 1, t);

  /// Ambient swell amount for a fly-in (fly-outs swell softer).
  static const double swellIn = 1, swellOut = 0.55;

  static double _smooth(double a, double b, double x) {
    final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }
}
