import 'dart:math' as math;
import 'dart:ui' show Color, Offset, Size;

import 'sky_colors.dart';
import 'sky_model.dart';

/// Lens-flare rules (pure): a restrained flare from the core star whose
/// strength follows the camera angle and motion, and a sun flare while the
/// sun is up and in view.
abstract final class SkyFlares {
  /// Resting strength of the core-star flare (lens_flare.frag asks for ≤ 0.4).
  static const double coreRest = 0.22;

  /// Core-star flare strength 0..1.
  ///
  /// * [elevation]: orbit-camera elevation (radians) – grazing views (low
  ///   elevation) look straighter into the star's glare, top-down views less;
  /// * [angularSpeed]: orbit-camera rotation speed (rad/s) – fly-ins and pans
  ///   flare up;
  /// * [pulse]: the core star's celebration flare 0..1;
  /// * [daylight]: daylight veils the flare a little; [dark] false (Pearl)
  ///   damps it (additive light on a pale sky washes out);
  /// * [zoom]: fly-in progress 0..1 (the star leaves the frame).
  static double coreIntensity({
    required double elevation,
    double angularSpeed = 0,
    double pulse = 0,
    double daylight = 0,
    bool dark = true,
    double zoom = 0,
  }) {
    final grazing = 1 - (elevation.abs() / 0.9).clamp(0.0, 1.0);
    final motion = (angularSpeed.abs() / 1.2).clamp(0.0, 1.0);
    var i = coreRest * (0.75 + 0.5 * grazing) + 0.4 * motion + 0.25 * pulse.clamp(0.0, 1.0);
    i *= 1 - 0.35 * daylight.clamp(0.0, 1.0);
    if (!dark) i *= 0.35;
    // A fly-in leaves the star behind: the flare is gone by the landing (it
    // is drawn over everything, so it must never sit on the focused world).
    final z = 1 - zoom.clamp(0.0, 1.0);
    i *= z * z;
    return i.clamp(0.0, 1.0);
  }

  /// Sun flare strength 0..1 (0 unless the sun is up and on or near the
  /// screen).
  static double sunIntensity({
    required double sunAltitude,
    required Offset? sunScreen,
    required Size viewport,
    bool dark = true,
    double zoom = 0,
  }) {
    if (sunScreen == null || sunAltitude < -1 || zoom >= 1) return 0;
    final up = SkyModel.smoothstep(-1, 3, sunAltitude);
    final r = Offset.zero & viewport;
    final sc = math.min(viewport.width, viewport.height);
    final dx = math.max(0.0, math.max(r.left - sunScreen.dx, sunScreen.dx - r.right));
    final dy = math.max(0.0, math.max(r.top - sunScreen.dy, sunScreen.dy - r.bottom));
    final outside = math.sqrt(dx * dx + dy * dy);
    final inView = 1 - SkyModel.smoothstep(0, 0.2 * sc, outside);
    // A low sun (golden hour) gives the warmest, strongest flare.
    final low = 1 - SkyModel.smoothstep(8, 40, sunAltitude) * 0.5;
    var i = 0.42 * up * inView * low;
    if (!dark) i *= 0.3;
    // Close to a world the only light that matters is the core star's: the
    // sun's flare (a second, conflicting light cue) fades out on a fly-in.
    final z = 1 - zoom.clamp(0.0, 1.0);
    i *= z * z;
    return i.clamp(0.0, 1.0);
  }

  /// Sun flare tint: amber near the horizon, warm white high up.
  static Color sunTint(double sunAltitude) =>
      SkyColors.lerp(const Color(0xFFFFB067), const Color(0xFFFFF0D2), SkyModel.smoothstep(0, 25, sunAltitude));

  /// Core-star flare tint from the theme gold (lifted toward the star tint).
  static Color coreTint(SkyTone tone) => SkyColors.lighten(SkyColors.lerp(tone.gold, tone.starTint, 0.45), 0.05);

  /// Whether a flare source is close enough to the viewport to be drawn
  /// (lens_flare.frag fades sources 0.2 × the short side outside).
  static bool withinReach(Offset p, Size viewport) {
    final m = 0.2 * math.min(viewport.width, viewport.height);
    return p.dx >= -m && p.dy >= -m && p.dx <= viewport.width + m && p.dy <= viewport.height + m;
  }
}
