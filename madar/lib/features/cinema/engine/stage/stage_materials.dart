import 'dart:ui';

import '../core/era.dart';
import '../core/era_skin.dart';

/// The materials of an era's theatre, derived from its palette: gilt (the
/// "gold" of mouldings, rope and fringe), the proscenium's wall, bulbs and
/// neon. Shared by the stage frame, the HUD, the overlays and the hall so
/// everything in one era is cut from the same cloth.
///
/// Monochrome eras keep every material inside the ink → paper range (the
/// film grade maps the frame to that duotone anyway); the colour eras get
/// real gold, lacquer and neon.
class StageMaterials {
  const StageMaterials({
    required this.era,
    required this.ink,
    required this.paper,
    required this.gilt,
    required this.giltLight,
    required this.giltDark,
    required this.wall,
    required this.wallLight,
    required this.wallDark,
    required this.bulb,
    required this.bulbOff,
    required this.glow,
    required this.neonA,
    required this.neonB,
    required this.plaque,
    required this.plaqueText,
    this.velvet,
    this.velvetShade,
  });

  final Era era;
  final Color ink;
  final Color paper;

  /// Moulding gold (mid, lit, shadow).
  final Color gilt;
  final Color giltLight;
  final Color giltDark;

  /// The proscenium body (plaster, lacquer, paint) – mid, lit, shadow.
  final Color wall;
  final Color wallLight;
  final Color wallDark;

  /// A lit marquee bulb, an unlit one, and the halo around a lit one.
  final Color bulb;
  final Color bulbOff;
  final Color glow;

  /// The two neon tube colours (80s; other eras reuse them as accents).
  final Color neonA;
  final Color neonB;

  /// HUD / menu plaque fill and its text.
  final Color plaque;
  final Color plaqueText;

  /// The house curtains' velvet when it differs from the palette's
  /// `curtain` / `curtainShade` (noir lifts it so the drape reads in the
  /// dark).
  final Color? velvet;
  final Color? velvetShade;

  bool get isNeon => era == Era.vhs;

  static final Expando<StageMaterials> _cache = Expando('StageMaterials');

  /// The materials of [skin] (cached per skin instance).
  static StageMaterials of(EraSkin skin) => _cache[skin] ??= _build(skin);

  static StageMaterials _build(EraSkin skin) {
    final p = skin.palette;
    Color mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;
    return switch (skin.era) {
      Era.silent => StageMaterials(
        era: skin.era,
        ink: p.ink,
        paper: p.paper,
        gilt: const Color(0xFFB8905A),
        giltLight: const Color(0xFFF1DDAE),
        giltDark: const Color(0xFF6A4A2C),
        wall: const Color(0xFF5E4130),
        wallLight: const Color(0xFF8A6A4E),
        wallDark: const Color(0xFF2E1D12),
        bulb: const Color(0xFFFFF0C8),
        bulbOff: const Color(0xFF7A5E44),
        glow: p.footlight,
        neonA: p.accent,
        neonB: p.footlight,
        plaque: p.paper,
        plaqueText: p.ink,
      ),
      Era.rubberHose => StageMaterials(
        era: skin.era,
        ink: p.ink,
        paper: p.paper,
        gilt: const Color(0xFFCFC8B8),
        giltLight: const Color(0xFFFFFFFF),
        giltDark: const Color(0xFF6E6A62),
        wall: const Color(0xFF2E2C29),
        wallLight: const Color(0xFF55524C),
        wallDark: const Color(0xFF161514),
        bulb: const Color(0xFFFFFBEF),
        bulbOff: const Color(0xFF6A665F),
        glow: p.footlight,
        neonA: p.highlight,
        neonB: p.footlight,
        plaque: p.paper,
        plaqueText: p.ink,
      ),
      Era.noir => StageMaterials(
        era: skin.era,
        ink: p.ink,
        paper: p.paper,
        gilt: const Color(0xFF85858D),
        giltLight: const Color(0xFFD9D9DE),
        giltDark: const Color(0xFF2C2C31),
        wall: const Color(0xFF17171B),
        wallLight: const Color(0xFF33333A),
        wallDark: const Color(0xFF060607),
        bulb: const Color(0xFFF6F0DC),
        bulbOff: const Color(0xFF3A3A40),
        glow: p.footlight,
        neonA: p.highlight,
        neonB: p.footlight,
        plaque: const Color(0xFF1B1B20),
        plaqueText: p.paper,
        velvet: const Color(0xFF4C4C55),
        velvetShade: const Color(0xFF0C0C0F),
      ),
      Era.technicolor => StageMaterials(
        era: skin.era,
        ink: p.ink,
        paper: p.paper,
        gilt: const Color(0xFFE2AE45),
        giltLight: const Color(0xFFFFE9A8),
        giltDark: const Color(0xFF8C5518),
        wall: const Color(0xFF1C5563),
        wallLight: const Color(0xFF2E8C8A),
        wallDark: const Color(0xFF0C2A35),
        bulb: const Color(0xFFFFF4C9),
        bulbOff: const Color(0xFF8C6A3C),
        glow: p.footlight,
        neonA: p.accent,
        neonB: p.accent2,
        plaque: p.paper,
        plaqueText: p.ink,
      ),
      Era.grindhouse => StageMaterials(
        era: skin.era,
        ink: p.ink,
        paper: p.paper,
        gilt: const Color(0xFFB07C3A),
        giltLight: const Color(0xFFE6C387),
        giltDark: const Color(0xFF5A3717),
        wall: const Color(0xFF4A2A1B),
        wallLight: const Color(0xFF7A4A2E),
        wallDark: const Color(0xFF200F08),
        bulb: const Color(0xFFFFE2A6),
        bulbOff: const Color(0xFF5E3E26),
        glow: p.footlight,
        neonA: p.accent,
        neonB: p.accent2,
        plaque: mix(p.paper, p.midtone, 0.25),
        plaqueText: p.ink,
      ),
      Era.vhs => StageMaterials(
        era: skin.era,
        ink: p.ink,
        paper: p.paper,
        gilt: p.accent2,
        giltLight: const Color(0xFFD6FBFF),
        giltDark: const Color(0xFF0B5C73),
        wall: const Color(0xFF0E0820),
        wallLight: const Color(0xFF24124A),
        wallDark: const Color(0xFF040209),
        bulb: const Color(0xFFFFD6F4),
        bulbOff: const Color(0xFF3A1650),
        glow: p.accent,
        neonA: p.accent,
        neonB: p.accent2,
        plaque: const Color(0xE60B0618),
        plaqueText: p.accent2,
      ),
    };
  }
}
