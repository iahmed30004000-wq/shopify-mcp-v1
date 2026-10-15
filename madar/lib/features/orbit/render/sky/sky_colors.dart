import 'dart:math' as math;
import 'dart:ui' show Color;

/// A colour in Björn Ottosson's OKLab space (perceptually uniform), used to
/// interpolate sky keyframes and to harmonise the sky with the theme without
/// the muddy greys a straight RGB mix produces.
class OkLab {
  const OkLab(this.l, this.a, this.b);

  /// Lightness 0..1, green–red and blue–yellow opponent axes.
  final double l, a, b;

  double get chroma => math.sqrt(a * a + b * b);

  factory OkLab.fromColor(Color c) {
    final r = _toLinear(c.r), g = _toLinear(c.g), bl = _toLinear(c.b);
    final lc = _cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * bl);
    final mc = _cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * bl);
    final sc = _cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * bl);
    return OkLab(
      0.2104542553 * lc + 0.7936177850 * mc - 0.0040720468 * sc,
      1.9779984951 * lc - 2.4285922050 * mc + 0.4505937099 * sc,
      0.0259040371 * lc + 0.7827717662 * mc - 0.8086757660 * sc,
    );
  }

  /// Back to an opaque sRGB colour (gamut-clipped per channel).
  Color toColor([double opacity = 1]) {
    final lc = l + 0.3963377774 * a + 0.2158037573 * b;
    final mc = l - 0.1055613458 * a - 0.0638541728 * b;
    final sc = l - 0.0894841775 * a - 1.2914855480 * b;
    final l3 = lc * lc * lc, m3 = mc * mc * mc, s3 = sc * sc * sc;
    final r = 4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3;
    final g = -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3;
    final bl = -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3;
    return Color.from(alpha: opacity, red: _toSrgb(r), green: _toSrgb(g), blue: _toSrgb(bl));
  }

  OkLab withL(double v) => OkLab(v, a, b);

  static OkLab lerp(OkLab x, OkLab y, double t) =>
      OkLab(x.l + (y.l - x.l) * t, x.a + (y.a - x.a) * t, x.b + (y.b - x.b) * t);

  static double _cbrt(double v) => v <= 0 ? 0 : math.pow(v, 1 / 3).toDouble();

  static double _toLinear(double c) => c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

  static double _toSrgb(double c) {
    final v = c <= 0.0031308 ? 12.92 * c : 1.055 * math.pow(c, 1 / 2.4) - 0.055;
    return v.clamp(0.0, 1.0);
  }
}

/// Colour helpers for the sky.
abstract final class SkyColors {
  /// Perceptual (OKLab) interpolation between two opaque colours.
  static Color lerp(Color a, Color b, double t) {
    if (t <= 0) return a;
    if (t >= 1) return b;
    return OkLab.lerp(OkLab.fromColor(a), OkLab.fromColor(b), t).toColor();
  }

  /// Moves [c]'s hue/chroma toward [toward] by [amount] while keeping [c]'s
  /// lightness: the sky keeps its time-of-day brightness structure but takes
  /// on the theme's colour.
  static Color harmonize(Color c, Color toward, double amount) {
    if (amount <= 0) return c;
    final x = OkLab.fromColor(c);
    final y = OkLab.fromColor(toward);
    final t = amount.clamp(0.0, 1.0);
    return OkLab(x.l, x.a + (y.a - x.a) * t, x.b + (y.b - x.b) * t).toColor();
  }

  /// Adds OKLab lightness (moonlight lift) keeping the hue.
  static Color lighten(Color c, double dl) {
    if (dl == 0) return c;
    final x = OkLab.fromColor(c);
    return x.withL((x.l + dl).clamp(0.0, 1.0)).toColor();
  }

  // --- the sky shader's colour pipeline --------------------------------------
  //
  // sky.frag reads palette colours with `toLinear(c) = pow(c, 2.2)`, adds the
  // light terms and writes `toGamma(tonemapACES(x))`. Passing a display colour
  // straight through would come out darker in the shadows and brighter in the
  // mid-tones; [encodeForShader] applies the exact inverse so the flat parts
  // of the sky show precisely the designed colour.

  static const double _a = 2.51, _b = 0.03, _c = 2.43, _d = 0.59, _e = 0.14;

  /// The ACES fit used by shaders/orbit/lib/common.glsl (per channel).
  static double aces(double x) {
    final v = (x * (_a * x + _b)) / (x * (_c * x + _d) + _e);
    return v.clamp(0.0, 1.0);
  }

  /// Inverse of [aces] for y in [0, 0.995].
  static double acesInverse(double y) {
    final v = y.clamp(0.0, 0.995);
    final qa = _a - _c * v;
    final qb = _b - _d * v;
    final qc = -_e * v;
    return (-qb + math.sqrt(qb * qb - 4 * qa * qc)) / (2 * qa);
  }

  /// Display values above this are not inverted exactly: near white the
  /// ACES inverse explodes (0.92 → 2.5 linear) and such a horizon would
  /// bleed far up the shader's linear horizon→zenith mix.
  static const double encodeCeiling = 0.86;

  /// One channel of a display colour → the uniform value that sky.frag turns
  /// back into that display value (exact up to [encodeCeiling]).
  static double encodeChannel(double display) {
    final d = display.clamp(0.0, 1.0);
    final target = d <= encodeCeiling ? d : encodeCeiling + (d - encodeCeiling) * 0.35;
    final linearOut = math.pow(target, 2.2).toDouble();
    return math.pow(acesInverse(linearOut), 1 / 2.2).toDouble();
  }

  /// What sky.frag displays for a uniform channel value (no light terms).
  static double decodeChannel(double uniform) =>
      math.pow(aces(math.pow(math.max(uniform, 0.0), 2.2).toDouble()), 1 / 2.2).toDouble();
}
