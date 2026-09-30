import 'dart:ui';

import '../../core/era_skin.dart';

/// The colours a drawing uses, derived once per skin (not per frame).
///
/// Art names [PaletteRole]s; this maps them for the era's ink style. In
/// [ShadingMode.neon] (1980s) fills sink toward the dark and the ink line
/// becomes a glowing tube in the palette's accent colours.
final class InkColors {
  EraSkin? _skin;
  final List<Color> _fills = List<Color>.filled(PaletteRole.values.length, const Color(0xFF000000));

  bool neon = false;

  /// Outline / pupils-free ink (neon: the glowing line colour).
  Color ink = const Color(0xFF000000);

  /// Second line colour (neon: the other accent; otherwise = [ink]).
  Color ink2 = const Color(0xFF000000);

  /// Neon glow halo colour (transparent when not neon).
  Color glow = const Color(0x00000000);

  /// Dark solids that must stay dark in every era: pupils, mouth interior.
  Color dark = const Color(0xFF000000);
  Color eyeWhite = const Color(0xFFFFFFFF);
  Color tongue = const Color(0xFF808080);
  Color teeth = const Color(0xFFFFFFFF);

  /// Specular shine on black shoes, noses and hats.
  Color shine = const Color(0xFFFFFFFF);

  /// Whole-body hit flash.
  Color flash = const Color(0xFFFFFFFF);

  /// Flat cel shadow (Technicolor gradient mode) and the halftone/hatch ink.
  Color cel = const Color(0x40000000);
  Color shadeInk = const Color(0xFF000000);

  /// Pale fill for smoke, steam, clouds and glints.
  Color puff = const Color(0xFFFFFFFF);

  /// Glowing parts (furnace mouths, lamps, thrusters).
  Color hot = const Color(0xFFFFE0A0);

  /// Palette straight through (for custom art).
  late EraPalette palette;
  late InkStyle style;

  /// Recomputes when [skin] is not the one seen last (identity check).
  bool update(EraSkin skin) {
    if (identical(skin, _skin)) return false;
    _skin = skin;
    palette = skin.palette;
    style = skin.ink;
    final p = skin.palette;
    neon = skin.ink.shading == ShadingMode.neon;
    for (final r in PaletteRole.values) {
      final c = p.resolve(r);
      _fills[r.index] = neon ? _neonFill(c, p) : c;
    }
    if (neon) {
      ink = p.accent2;
      ink2 = p.accent;
      glow = p.accent2.withValues(alpha: 0.55);
      dark = p.ink;
      eyeWhite = p.paper;
      tongue = p.accent;
      teeth = p.paper;
      shine = p.paper;
      flash = p.paper;
      cel = p.ink.withValues(alpha: 0.35);
      shadeInk = p.ink;
      puff = Color.lerp(p.midtone, p.paper, 0.35)!;
      hot = p.accent;
    } else {
      ink = p.ink;
      ink2 = p.ink;
      glow = const Color(0x00000000);
      dark = p.ink;
      eyeWhite = p.highlight;
      tongue = Color.lerp(p.accent, p.midtone, skin.era.isMonochrome ? 0.4 : 0.15)!;
      teeth = p.highlight;
      shine = p.highlight;
      flash = Color.lerp(p.highlight, p.footlight, 0.25)!;
      cel = p.shadow.withValues(alpha: (skin.ink.shadeStrength * 0.55).clamp(0.12, 0.6));
      shadeInk = Color.lerp(p.ink, p.shadow, 0.25)!;
      puff = Color.lerp(p.paper, p.highlight, 0.5)!;
      hot = p.footlight;
    }
    return true;
  }

  static Color _neonFill(Color c, EraPalette p) {
    // Keep a whisper of the hue, sink the value: neon tubes on a dark body.
    final lum = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
    return Color.lerp(c, p.shadow, lum > 0.85 ? 0.82 : 0.62)!;
  }

  Color fill(PaletteRole role) => _fills[role.index];
}
