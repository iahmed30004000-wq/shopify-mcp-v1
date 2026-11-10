import 'dart:math' as math;
import 'dart:ui' show Color;

/// WCAG 2.x colour contrast maths (pure – no widgets, unit-tested).
///
/// Used to keep every theme – and any custom accent the user picks – legible:
/// text needs 4.5:1 against what it sits on ([MadarContrast.text]), large
/// text and meaningful graphics 3:1 ([MadarContrast.graphic]).
abstract final class MadarContrast {
  /// WCAG AA for body text.
  static const double text = 4.5;

  /// WCAG AA for large text (≥ 18.66 px bold / 24 px) and UI graphics.
  static const double graphic = 3.0;

  /// Relative luminance (WCAG 2.x, sRGB), ignoring alpha.
  static double luminance(Color c) {
    double channel(double v) => v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
  }

  /// Contrast ratio between two opaque colours, 1 … 21.
  static double ratio(Color a, Color b) {
    final la = luminance(a);
    final lb = luminance(b);
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  /// [fg] (possibly translucent) composited over an opaque [bg].
  static Color over(Color fg, Color bg) => Color.alphaBlend(fg, bg.withValues(alpha: 1));

  /// The smallest contrast of [fg] against any of [backgrounds].
  static double minRatio(Color fg, Iterable<Color> backgrounds) =>
      backgrounds.fold(double.infinity, (m, bg) => math.min(m, ratio(fg, bg)));

  /// Whether [fg] reaches [min] against every one of [backgrounds].
  static bool passes(Color fg, Iterable<Color> backgrounds, {double min = text}) => minRatio(fg, backgrounds) >= min;

  /// [fg] with its HSL lightness moved as little as possible so it reaches
  /// [min] against every colour in [backgrounds] (all of similar brightness –
  /// e.g. a theme's surfaces). Keeps hue and saturation; lightens on dark
  /// backgrounds, darkens on light ones. Returns [fg] unchanged when it
  /// already passes, and the extreme (black / white end) when nothing on
  /// that side of the lightness axis passes.
  static Color ensure(Color fg, Iterable<Color> backgrounds, {double min = text}) {
    final bgs = backgrounds.toList(growable: false);
    if (bgs.isEmpty || passes(fg, bgs, min: min)) return fg;
    // The mean brightness of the backgrounds decides the direction.
    final bgLum = bgs.map(luminance).reduce((a, b) => a + b) / bgs.length;
    final lighten = bgLum < 0.18;
    final hsl = _Hsl.of(fg);
    // Binary search the lightness between the colour and the extreme.
    final extreme = lighten ? 1.0 : 0.0;
    var lo = hsl.l;
    var hi = extreme;
    for (var i = 0; i < 24; i++) {
      final mid = (lo + hi) / 2;
      if (passes(hsl.withLightness(mid).toColor(1), bgs, min: min)) {
        hi = mid;
      } else {
        lo = mid;
      }
    }
    // Settle on a plain 8-bit colour that still passes (rounding can cost a
    // hair of contrast: step on towards the extreme until it holds).
    var l = hi;
    var c = _quantize(hsl.withLightness(l).toColor(fg.a));
    while (!passes(c, bgs, min: min) && l != extreme) {
      l = lighten ? math.min(1.0, l + 0.002) : math.max(0.0, l - 0.002);
      c = _quantize(hsl.withLightness(l).toColor(fg.a));
    }
    return c;
  }

  /// [c] rounded to 8 bits per channel.
  static Color _quantize(Color c) =>
      Color.fromARGB((c.a * 255).round(), (c.r * 255).round(), (c.g * 255).round(), (c.b * 255).round());

  /// Whichever of [candidates] reads best on [fill] (the highest contrast).
  static Color bestOn(Color fill, List<Color> candidates) {
    var best = candidates.first;
    var bestRatio = ratio(best, fill);
    for (final c in candidates.skip(1)) {
      final r = ratio(c, fill);
      if (r > bestRatio) {
        best = c;
        bestRatio = r;
      }
    }
    return best;
  }
}

/// Minimal HSL round trip in doubles (Flutter's HSLColor clamps and rounds
/// through 8-bit channels at every step; the search above needs smooth
/// lightness).
class _Hsl {
  const _Hsl(this.h, this.s, this.l);

  factory _Hsl.of(Color c) {
    final r = c.r, g = c.g, b = c.b;
    final max = math.max(r, math.max(g, b));
    final min = math.min(r, math.min(g, b));
    final l = (max + min) / 2;
    final d = max - min;
    if (d == 0) return _Hsl(0, 0, l);
    final s = d / (1 - (2 * l - 1).abs());
    double h;
    if (max == r) {
      h = 60 * (((g - b) / d) % 6);
    } else if (max == g) {
      h = 60 * ((b - r) / d + 2);
    } else {
      h = 60 * ((r - g) / d + 4);
    }
    return _Hsl(h < 0 ? h + 360 : h, s.clamp(0.0, 1.0), l);
  }

  final double h, s, l;

  _Hsl withLightness(double lightness) => _Hsl(h, s, lightness.clamp(0.0, 1.0));

  Color toColor(double alpha) {
    final c = (1 - (2 * l - 1).abs()) * s;
    final x = c * (1 - ((h / 60) % 2 - 1).abs());
    final m = l - c / 2;
    final (r, g, b) = switch (h) {
      < 60 => (c, x, 0.0),
      < 120 => (x, c, 0.0),
      < 180 => (0.0, c, x),
      < 240 => (0.0, x, c),
      < 300 => (x, 0.0, c),
      _ => (c, 0.0, x),
    };
    return Color.from(
      alpha: alpha,
      red: (r + m).clamp(0.0, 1.0),
      green: (g + m).clamp(0.0, 1.0),
      blue: (b + m).clamp(0.0, 1.0),
    );
  }
}
