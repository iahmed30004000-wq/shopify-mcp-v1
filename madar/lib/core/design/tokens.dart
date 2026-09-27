import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Madar design tokens. Every screen, chart, shader palette and game HUD reads
/// colours and shape values from here – never from literals.
///
/// Access with `context.tokens`.
@immutable
class MadarTokens extends ThemeExtension<MadarTokens> {
  const MadarTokens({
    required this.brightness,
    required this.space0,
    required this.space1,
    required this.space2,
    required this.space3,
    required this.glassFill,
    required this.glassBorder,
    required this.glassHighlight,
    required this.glassShadow,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textOnAccent,
    required this.accent,
    required this.accentSoft,
    required this.accentGlow,
    required this.secondary,
    required this.highlight,
    required this.gold,
    required this.brass,
    required this.brassDark,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.nebulaA,
    required this.nebulaB,
    required this.starTint,
    required this.dust,
    this.radiusS = 10,
    this.radiusM = 16,
    this.radiusL = 24,
    this.radiusXL = 34,
    this.blurSigma = 22,
    this.grainOpacity = 0.06,
  });

  final Brightness brightness;

  /// Backgrounds from the deepest cosmos (space0) to raised surfaces (space3).
  final Color space0, space1, space2, space3;

  /// Glass panel fill / border / specular edge / drop glow.
  final Color glassFill, glassBorder, glassHighlight, glassShadow;

  final Color textPrimary, textSecondary, textTertiary, textOnAccent;

  /// Theme accent (overridable by the user's custom accent colour).
  final Color accent, accentSoft, accentGlow;

  /// Secondary brand hue of the theme and a cool/contrasting highlight.
  final Color secondary, highlight;

  /// Astrolabe metals.
  final Color gold, brass, brassDark;

  final Color success, warning, danger, info;

  /// Shader palette for backdrops (nebula clouds, star tint, dust).
  final Color nebulaA, nebulaB, starTint, dust;

  final double radiusS, radiusM, radiusL, radiusXL;
  final double blurSigma;
  final double grainOpacity;

  bool get isDark => brightness == Brightness.dark;

  @override
  MadarTokens copyWith({
    Color? accent,
    Color? accentSoft,
    Color? accentGlow,
    Color? textOnAccent,
  }) {
    return MadarTokens(
      brightness: brightness,
      space0: space0,
      space1: space1,
      space2: space2,
      space3: space3,
      glassFill: glassFill,
      glassBorder: glassBorder,
      glassHighlight: glassHighlight,
      glassShadow: glassShadow,
      textPrimary: textPrimary,
      textSecondary: textSecondary,
      textTertiary: textTertiary,
      textOnAccent: textOnAccent ?? this.textOnAccent,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      accentGlow: accentGlow ?? this.accentGlow,
      secondary: secondary,
      highlight: highlight,
      gold: gold,
      brass: brass,
      brassDark: brassDark,
      success: success,
      warning: warning,
      danger: danger,
      info: info,
      nebulaA: nebulaA,
      nebulaB: nebulaB,
      starTint: starTint,
      dust: dust,
      radiusS: radiusS,
      radiusM: radiusM,
      radiusL: radiusL,
      radiusXL: radiusXL,
      blurSigma: blurSigma,
      grainOpacity: grainOpacity,
    );
  }

  @override
  MadarTokens lerp(covariant MadarTokens? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    double d(double a, double b) => lerpDouble(a, b, t)!;
    return MadarTokens(
      brightness: t < 0.5 ? brightness : other.brightness,
      space0: c(space0, other.space0),
      space1: c(space1, other.space1),
      space2: c(space2, other.space2),
      space3: c(space3, other.space3),
      glassFill: c(glassFill, other.glassFill),
      glassBorder: c(glassBorder, other.glassBorder),
      glassHighlight: c(glassHighlight, other.glassHighlight),
      glassShadow: c(glassShadow, other.glassShadow),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textTertiary: c(textTertiary, other.textTertiary),
      textOnAccent: c(textOnAccent, other.textOnAccent),
      accent: c(accent, other.accent),
      accentSoft: c(accentSoft, other.accentSoft),
      accentGlow: c(accentGlow, other.accentGlow),
      secondary: c(secondary, other.secondary),
      highlight: c(highlight, other.highlight),
      gold: c(gold, other.gold),
      brass: c(brass, other.brass),
      brassDark: c(brassDark, other.brassDark),
      success: c(success, other.success),
      warning: c(warning, other.warning),
      danger: c(danger, other.danger),
      info: c(info, other.info),
      nebulaA: c(nebulaA, other.nebulaA),
      nebulaB: c(nebulaB, other.nebulaB),
      starTint: c(starTint, other.starTint),
      dust: c(dust, other.dust),
      radiusS: d(radiusS, other.radiusS),
      radiusM: d(radiusM, other.radiusM),
      radiusL: d(radiusL, other.radiusL),
      radiusXL: d(radiusXL, other.radiusXL),
      blurSigma: d(blurSigma, other.blurSigma),
      grainOpacity: d(grainOpacity, other.grainOpacity),
    );
  }
}

/// Spacing scale (logical pixels). Use `Gap.m` etc. or the `Gaps` widgets.
abstract final class Space {
  static const double xxs = 2;
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Standard horizontal page gutter.
  static const double gutter = 20;
}

extension MadarTokensContext on BuildContext {
  MadarTokens get tokens => Theme.of(this).extension<MadarTokens>()!;
}
