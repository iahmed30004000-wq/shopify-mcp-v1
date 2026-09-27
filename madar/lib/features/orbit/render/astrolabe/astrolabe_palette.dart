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
  });

  factory AstrolabePalette.fromTokens(MadarTokens t) {
    final light = !t.isDark;
    Color mix(Color a, Color b, double k) => Color.lerp(a, b, k)!;
    Color hsl(Color c, {double? l, double? s}) {
      final h = HSLColor.fromColor(c);
      return h.withLightness((l ?? h.lightness).clamp(0.0, 1.0)).withSaturation((s ?? h.saturation).clamp(0.0, 1.0)).toColor();
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
    final brassHi = mix(t.gold, warmWhite, light ? 0.62 : 0.5);
    return AstrolabePalette(
      light: light,
      brass: light ? mix(t.brass, t.gold, 0.45) : mix(t.brass, t.gold, 0.25),
      brassHi: brassHi,
      brassLow: t.brassDark,
      ink: mix(t.brassDark, light ? t.textPrimary : t.space0, 0.45),
      engraveHi: mix(t.gold, warmWhite, 0.55),
      enamelCenter: enamelCenter,
      enamelMid: enamelMid,
      enamelEdge: enamelEdge,
      enamelSheen: enamelSheen,
      plateLine: mix(t.gold, warmWhite, 0.2),
      daySky: mix(enamelSheen, t.highlight, 0.25),
      twilight: mix(t.warning, t.secondary, 0.35),
      halo: light ? t.gold : mix(t.gold, t.accentGlow, 0.3),
      shadow: light ? t.glassShadow : t.space0,
      litArc: mix(faith.surface, t.gold, 0.4),
      litHead: mix(faith.glow, warmWhite, 0.5),
      fireOuter: mix(t.warning, t.danger, 0.22),
      fireInner: mix(faith.glow, warmWhite, 0.45),
      starCore: faith.glow,
      starCorona: faith.surface,
      labelPrayed: mix(faith.glow, warmWhite, 0.35),
      labelDue: mix(t.gold, faith.glow, 0.4),
      labelUpcoming: mix(t.gold, enamelMid, 0.18),
      labelMissed: mix(t.textTertiary, enamelMid, light ? 0.1 : 0.35),
      sun: mix(faith.surface, t.gold, 0.3),
      sunGlow: faith.glow,
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

  List<Color> get _all => [
    brass, brassHi, brassLow, ink, engraveHi, enamelCenter, enamelMid, enamelEdge, enamelSheen, plateLine, //
    daySky, twilight, halo, shadow, litArc, litHead, fireOuter, fireInner, starCore, starCorona, //
    labelPrayed, labelDue, labelUpcoming, labelMissed, sun, sunGlow,
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
