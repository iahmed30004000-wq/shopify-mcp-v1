import 'package:flutter/material.dart';

import '../../../../../core/design/tokens.dart';
import '../../domain/wellbeing_data.dart';

/// Wellbeing colours, all derived from the theme tokens (every theme,
/// Pearl included).
abstract final class WbPalette {
  /// The calm pain scale: a cool, quiet 0 through the theme's gold to a
  /// softened coral at 10 – never an alarm red.
  static Color pain(MadarTokens t, num score) {
    final s = score.clamp(0, 10).toDouble();
    final calm = Color.lerp(t.info, t.success, 0.35)!;
    final mid = Color.lerp(t.gold, t.warning, 0.45)!;
    final high = Color.lerp(t.danger, t.warning, 0.22)!;
    if (s <= 5) return Color.lerp(calm, mid, s / 5)!;
    return Color.lerp(mid, high, (s - 5) / 5)!;
  }

  /// [pain] as a glow: on the light theme the text-safe (dark) status
  /// colours are lifted so a bloom reads as light, not as a smudge.
  static Color painGlow(MadarTokens t, num score) {
    final c = pain(t, score);
    if (t.isDark) return c;
    final h = HSLColor.fromColor(c);
    return h.withLightness(0.6).withSaturation((h.saturation + 0.25).clamp(0.0, 1.0)).toColor();
  }

  /// A gentle gradient across the whole pain scale (slider track).
  static List<Color> painScale(MadarTokens t) => [for (var i = 0; i <= 10; i += 2) pain(t, i)];

  /// Mood 1 (low) … 5 (bright): cool blue through the accent to gold.
  static Color mood(MadarTokens t, int mood) {
    final m = mood.clamp(1, 5);
    const stops = [0.0, 0.25, 0.5, 0.75, 1.0];
    final colors = [
      Color.lerp(t.info, t.secondary, 0.35)!,
      Color.lerp(t.info, t.highlight, 0.5)!,
      Color.lerp(t.textSecondary, t.brass, 0.5)!,
      Color.lerp(t.success, t.gold, 0.35)!,
      t.gold,
    ];
    return colors[stops.indexOf((m - 1) / 4)];
  }

  static Color metric(MadarTokens t, WellMetric m) => switch (m) {
    WellMetric.mood => t.gold,
    WellMetric.stress => Color.lerp(t.warning, t.danger, 0.25)!,
    WellMetric.anxiety => Color.lerp(t.secondary, t.highlight, 0.3)!,
    WellMetric.energy => t.success,
    WellMetric.sleep => t.info,
    WellMetric.caffeine => Color.lerp(t.brass, t.warning, 0.3)!,
    WellMetric.pain => pain(t, 7),
  };

  /// Text drawn on a [pain] / [metric] colour chip.
  static Color on(MadarTokens t, Color c) {
    final darkInk = t.isDark ? t.space0 : t.textPrimary;
    final lightInk = t.isDark ? t.textPrimary : t.space0;
    return c.computeLuminance() > 0.4 ? darkInk : lightInk;
  }
}
