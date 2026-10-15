import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../../../core/design/themes.dart';
import '../../../../core/design/tokens.dart';

/// Every colour of the astrolabe, derived from the theme tokens (brass and
/// gold from the astrolabe metals, enamel from the theme's depths and
/// secondary hue, fire and the core star from the Faith planet's palette).
@immutable
class AstrolabePalette {
  const AstrolabePalette({
    required this.light,
    required this.brass,
    required this.brassHi,
    required this.brassLow,
    required this.ink,
    required this.engraveHi,
    required this.enamelCenter,
    required this.enamelMid,
    required this.enamelEdge,
    required this.enamelSheen,
    required this.plateLine,
    required this.daySky,
    required this.twilight,
    required this.halo,
    required this.shadow,
    required this.litArc,
    required this.litHead,
    required this.fireOuter,
    required this.fireInner,
    required this.starCore,
    required this.starCorona,
    required this.labelPrayed,
    required this.labelDue,
    required this.labelUpcoming,
    required this.labelMissed,
    required this.sun,
    required this.sunGlow,
    required this.bevelLight,
    required this.bevelDark,
  });

  factory AstrolabePalette.fromTokens(MadarTokens t) {
    final light = !t.isDark;
    Color mix(Color a, Color b, double k) => Color.lerp(a, b, k)!;
    Color hsl(Color c, {double? l, double? s}) {
      final h = HSLColor.fromColor(c);
      return h
          .withLightness((l ?? h.lightness).clamp(0.0, 1.0))
          .withSaturation((s ?? h.saturation).clamp(0.0, 1.0))
          .toColor();
    }

    const faith = PlanetPalettes.faith;
    // Warm white used for highlights: the star tint in dark themes, the pearl
    // itself in the light theme.
    final warmWhite = light ? t.space0 : t.starTint;
    // Enamel: the theme's night in dark themes; a deep lapis made from the
    // theme's secondary hue on Pearl (the astrolabe is a jewel on the pearl).
    final Color enamelCenter, enamelMid, enamelEdge, enamelSheen;
    if (light) {
      enamelCenter = hsl(t.secondary, l: 0.2, s: 0.62);
      enamelMid = hsl(t.secondary, l: 0.14, s: 0.6);
      enamelEdge = hsl(t.secondary, l: 0.075, s: 0.55);
      enamelSheen = hsl(t.secondary, l: 0.34, s: 0.55);
    } else {
      enamelCenter = mix(t.space3, t.secondary, 0.3);
      enamelMid = mix(t.space2, t.secondary, 0.12);
      enamelEdge = mix(t.space0, t.space1, 0.5);
      enamelSheen = mix(t.space3, t.secondary, 0.55);
    }
    // Real brass, a three-stop ramp: umber lows (the theme's dark brass,
    // ≈ #5A3A12), a warm amber body (≈ #B8893A) and pale-gold highlights
    // (≈ #F3DDA0) – never a flat saturated yellow, never cream.
    // The polished metal (on a light theme brighter than the text-safe
    // gold / brass tokens).
    final gold = t.metalGold;
    final brass = t.metalBrass;
    final brassHi = mix(gold, warmWhite, light ? 0.3 : 0.32);
    return AstrolabePalette(
      light: light,
      brass: light ? mix(brass, gold, 0.12) : brass,
      brassHi: brassHi,
      brassLow: light ? t.brassDark : mix(t.brassDark, t.space0, 0.08),
      ink: mix(t.brassDark, light ? t.textPrimary : t.space0, 0.45),
      engraveHi: mix(gold, warmWhite, 0.55),
      enamelCenter: enamelCenter,
      enamelMid: enamelMid,
      enamelEdge: enamelEdge,
      enamelSheen: enamelSheen,
      plateLine: mix(gold, warmWhite, 0.2),
      daySky: mix(enamelSheen, t.highlight, 0.25),
      twilight: mix(t.warning, t.secondary, 0.35),
      halo: light ? gold : mix(gold, t.accentGlow, 0.3),
      shadow: light ? t.glassShadow : t.space0,
      // The lit window: molten amber (≈ #E9A43A) heating to warm gold
      // (≈ #FFD27A) – never white.
      litArc: mix(t.warning, brass, 0.25),
      litHead: mix(faith.glow, t.warning, 0.4),
      // Gold at the filaments' roots, orange at their tips.
      fireOuter: mix(t.warning, t.danger, 0.3),
      fireInner: mix(faith.glow, gold, 0.25),
      starCore: faith.glow,
      starCorona: faith.surface,
      // Engraved gold, not white UI text: prayed names burn brightest.
      labelPrayed: light ? mix(faith.glow, t.space0, 0.2) : mix(faith.glow, gold, 0.3),
      labelDue: light ? mix(faith.surface, t.space0, 0.3) : mix(gold, faith.glow, 0.4),
      labelUpcoming: light ? mix(gold, t.space0, 0.4) : mix(gold, enamelMid, 0.12),
      labelMissed: light ? mix(t.textTertiary, t.space2, 0.3) : mix(t.textTertiary, enamelMid, 0.3),
      sun: mix(faith.surface, gold, 0.3),
      sunGlow: faith.glow,
      bevelLight: brassHi.withValues(alpha: light ? 0.55 : 0.5),
      bevelDark: mix(t.brassDark, t.space0, light ? 0.2 : 0.5).withValues(alpha: 0.45),
    );
  }

  /// Light theme (Pearl): drop shadow instead of a glow around the limb.
  final bool light;

  /// Brushed brass material (brass.frag uBase / uHi / uLow).
  final Color brass, brassHi, brassLow;

  /// Engraving: the incised line and its lit lower edge.
  final Color ink, engraveHi;

  /// Enamel of the plate, centre → rim, and its sheen.
  final Color enamelCenter, enamelMid, enamelEdge, enamelSheen;

  /// Gold hairlines engraved into the enamel.
  final Color plateLine;

  /// The plate above the horizon and the twilight band.
  final Color daySky, twilight;

  /// Glow around the limb (dark themes) / drop shadow (light).
  final Color halo, shadow;

  /// The current window's lit arc and its luminous head at "now".
  final Color litArc, litHead;

  /// Prayer fire (prayer_fire.frag uColorA / uColorB).
  final Color fireOuter, fireInner;

  /// Core star tints (core_star.frag uColorA / uColorB).
  final Color starCore, starCorona;

  /// Prayer names by status.
  final Color labelPrayed, labelDue, labelUpcoming, labelMissed;

  /// Sun marker glyph and glow.
  final Color sun, sunGlow;

  /// Chamfered metal edges: facing the light / facing away.
  final Color bevelLight, bevelDark;

  /// A copy with other metal colours.
  AstrolabePalette withMetal({Color? brass, Color? brassHi, Color? brassLow}) => AstrolabePalette(
    light: light,
    brass: brass ?? this.brass,
    brassHi: brassHi ?? this.brassHi,
    brassLow: brassLow ?? this.brassLow,
    ink: ink,
    engraveHi: engraveHi,
    enamelCenter: enamelCenter,
    enamelMid: enamelMid,
    enamelEdge: enamelEdge,
    enamelSheen: enamelSheen,
    plateLine: plateLine,
    daySky: daySky,
    twilight: twilight,
    halo: halo,
    shadow: shadow,
    litArc: litArc,
    litHead: litHead,
    fireOuter: fireOuter,
    fireInner: fireInner,
    starCore: starCore,
    starCorona: starCorona,
    labelPrayed: labelPrayed,
    labelDue: labelDue,
    labelUpcoming: labelUpcoming,
    labelMissed: labelMissed,
    sun: sun,
    sunGlow: sunGlow,
    bevelLight: bevelLight,
    bevelDark: bevelDark,
  );

  List<Color> get _all => [
    brass, brassHi, brassLow, ink, engraveHi, enamelCenter, enamelMid, enamelEdge, enamelSheen, plateLine, //
    daySky, twilight, halo, shadow, litArc, litHead, fireOuter, fireInner, starCore, starCorona, //
    labelPrayed, labelDue, labelUpcoming, labelMissed, sun, sunGlow, bevelLight, bevelDark,
  ];

  @override
  bool operator ==(Object other) {
    if (other is! AstrolabePalette || other.light != light) return false;
    final a = _all, b = other._all;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll([light, ..._all]);
}
