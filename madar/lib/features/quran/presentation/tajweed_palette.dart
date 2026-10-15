import 'package:flutter/material.dart';

import '../../../core/design/contrast.dart';
import '../../../core/design/tokens.dart';
import '../domain/tajweed.dart';

/// Tajweed colours for a theme, derived from its tokens: the madd family
/// from [MadarTokens.danger] (reds to amber, like the printed tajweed
/// mushafs), the ghunnah family from [MadarTokens.success] (greens), qalqalah
/// from [MadarTokens.info] (blue) and the unpronounced letters from
/// [MadarTokens.textTertiary] (grey). Every colour is then moved along its
/// lightness axis until it reads on the theme's reading surfaces (WCAG 4.5:1
/// on the page, 3:1 on lit glass), so the rules stay legible in all themes,
/// night and Pearl alike.
class TajweedPalette {
  TajweedPalette._(this._colors);

  static final Map<MadarTokens, TajweedPalette> _cache = {};

  factory TajweedPalette.of(MadarTokens t) {
    if (_cache.length > 16) _cache.clear();
    return _cache.putIfAbsent(t, () => TajweedPalette._(_derive(t)));
  }

  final Map<TajweedRule, Color> _colors;

  Color operator [](TajweedRule rule) => _colors[rule]!;

  /// The surfaces Quran text is read on.
  static List<Color> surfaces(MadarTokens t) => [t.space1, t.space2];

  static Map<TajweedRule, Color> _derive(MadarTokens t) {
    final dark = t.isDark;
    Color tone(Color base, {double hue = 0, double? saturation, double lightness = 0}) {
      final h = HSLColor.fromColor(base);
      final shifted = h
          .withHue((h.hue + hue) % 360)
          .withSaturation((saturation ?? h.saturation).clamp(0.0, 1.0))
          .withLightness((h.lightness + lightness).clamp(0.0, 1.0));
      var c = shifted.toColor();
      c = MadarContrast.ensure(c, surfaces(t));
      return MadarContrast.ensure(c, [t.glassLit], min: MadarContrast.graphic);
    }

    final red = t.danger;
    final green = t.success;
    final blue = t.info;
    // Night themes lighten colours to reach contrast, which washes hues out;
    // start them saturated so the families stay apart.
    final sat = dark ? 0.9 : 0.75;
    final grey = t.textTertiary;
    return {
      TajweedRule.hamzatWasl: tone(grey, lightness: dark ? -0.06 : 0.06),
      TajweedRule.lamShamsiyyah: tone(grey, lightness: dark ? -0.06 : 0.06),
      TajweedRule.silent: tone(grey, lightness: dark ? -0.06 : 0.06),
      TajweedRule.idghamNoGhunnah: tone(blue, saturation: 0.18, lightness: dark ? -0.1 : 0.05),
      TajweedRule.idghamMutajanisayn: tone(blue, saturation: 0.18, lightness: dark ? -0.1 : 0.05),
      TajweedRule.idghamMutaqaribayn: tone(blue, saturation: 0.18, lightness: dark ? -0.1 : 0.05),
      TajweedRule.maddNatural: tone(red, hue: 40, saturation: sat * 0.8),
      TajweedRule.maddPermissible: tone(red, hue: 26, saturation: sat),
      TajweedRule.maddSeparated: tone(red, hue: 12, saturation: sat),
      TajweedRule.maddConnected: tone(red, hue: -6, saturation: sat),
      TajweedRule.maddNecessary: tone(red, hue: -26, saturation: 1, lightness: dark ? -0.08 : -0.1),
      TajweedRule.ghunnah: tone(green, hue: -4, saturation: sat),
      TajweedRule.ikhfa: tone(green, hue: 16, saturation: sat),
      TajweedRule.ikhfaShafawi: tone(green, hue: 34, saturation: sat),
      TajweedRule.idghamGhunnah: tone(green, hue: -24, saturation: sat),
      TajweedRule.idghamShafawi: tone(green, hue: -42, saturation: sat),
      TajweedRule.iqlab: tone(green, hue: 54, saturation: sat),
      TajweedRule.qalqalah: tone(blue, hue: -4, saturation: sat),
    };
  }
}
