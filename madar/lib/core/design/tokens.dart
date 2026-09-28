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
    this._metalGold,
    this._metalBrass,
    this._glassLit,
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

  /// Astrolabe metals. [gold] is also a text colour on every surface (a
  /// deep "ink" gold on a light theme); [brass] draws rings and rules
  /// (graphic contrast, 3:1), never text.
  final Color gold, brass, brassDark;

  final Color? _metalGold, _metalBrass;

  /// The polished metal of rendered objects (the astrolabe's brass body and
  /// highlights). Same as [gold] / [brass] on the night themes; brighter than
  /// the text-safe [gold] / [brass] on a light theme. Never use for text.
  Color get metalGold => _metalGold ?? gold;
  Color get metalBrass => _metalBrass ?? brass;

  final Color? _glassLit;

  /// The hardest ground text really meets on this theme: on the night
  /// themes, glass lit by the nebula behind it (its rim light and a passing
  /// sheen included) – measured on rendered screens, far brighter than the
  /// token surfaces; on Pearl, the raised [space2]. For contrast checks
  /// only (custom accents are fitted to it); never paint with it.
  Color get glassLit => _glassLit ?? space2;

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
      metalGold: _metalGold,
      metalBrass: _metalBrass,
      glassLit: _glassLit,
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
      metalGold: c(metalGold, other.metalGold),
      metalBrass: c(metalBrass, other.metalBrass),
      glassLit: c(glassLit, other.glassLit),
    );
  }

  List<Object> get _props => [
    brightness,
    space0, space1, space2, space3, //
    glassFill, glassBorder, glassHighlight, glassShadow,
    textPrimary, textSecondary, textTertiary, textOnAccent,
    accent, accentSoft, accentGlow,
    secondary, highlight,
    gold, brass, brassDark,
    success, warning, danger, info,
    nebulaA, nebulaB, starTint, dust,
    radiusS, radiusM, radiusL, radiusXL,
    blurSigma, grainOpacity,
    metalGold, metalBrass, glassLit,
  ];

  /// Value equality: `ThemeData ==` compares extensions, so two themes built
  /// from the same inputs (a custom accent makes a new instance through
  /// [copyWith]) must be equal, or every rebuild restarts the app-wide
  /// theme animation.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MadarTokens || other.runtimeType != runtimeType) return false;
    final a = _props;
    final b = other._props;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_props);
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
