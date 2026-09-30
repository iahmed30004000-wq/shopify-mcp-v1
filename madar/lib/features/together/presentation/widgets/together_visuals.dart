import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/design/painters/painters.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../domain/player_profile.dart';
import '../../domain/trophies.dart';

/// Colours and icons of Together Mode.
abstract final class TogetherLook {
  static Color colorOf(TogetherProfile p) => Color(p.colorValue);

  static Color paletteColor(int index) => Color(TogetherPalette.colors[TogetherPalette.clampIndex(index)]);

  /// Readable ink on a player colour.
  static Color inkOn(Color c) =>
      ThemeData.estimateBrightnessForColor(c) == Brightness.dark ? Colors.white : const Color(0xFF14121C);

  static IconData gameIcon(String id) => switch (id) {
    'tarneeb' || 'trix' || 'basra' || 'konkan' => Icons.style_rounded,
    'backgammon' || 'ludo' => Icons.casino_rounded,
    'chess' => Icons.castle_rounded,
    'dominoes' => Icons.view_agenda_rounded,
    'fourInARow' => Icons.grid_view_rounded,
    'wordDuel' => Icons.abc_rounded,
    'quizDuel' => Icons.quiz_rounded,
    'drawGuess' => Icons.brush_rounded,
    'miniGolf' => Icons.golf_course_rounded,
    'knowMe' => Icons.favorite_rounded,
    'airHockey' => Icons.sports_hockey_rounded,
    'beachVolley' => Icons.sports_volleyball_rounded,
    'kartDash' => Icons.directions_car_filled_rounded,
    'snowballFight' => Icons.ac_unit_rounded,
    'paddleDuel' => Icons.sports_tennis_rounded,
    'tankDuel' => Icons.shield_rounded,
    'metropolisCoop' => Icons.precision_manufacturing_rounded,
    _ => Icons.sports_esports_rounded,
  };

  static IconData trophyIcon(TrophyId id) => switch (id) {
    TrophyId.firstMatch => Icons.handshake_rounded,
    TrophyId.matches10 || TrophyId.matches50 || TrophyId.matches100 || TrophyId.matches250 => Icons.emoji_events_rounded,
    TrophyId.dayStreak3 || TrophyId.dayStreak7 || TrophyId.dayStreak30 => Icons.local_fire_department_rounded,
    TrophyId.winStreak3 || TrophyId.winStreak5 || TrophyId.winStreak10 => Icons.bolt_rounded,
    TrophyId.explorer5 || TrophyId.explorer10 => Icons.explore_rounded,
    TrophyId.coopWins5 || TrophyId.coopWins25 => Icons.diversity_1_rounded,
    TrophyId.marathon => Icons.timer_rounded,
    TrophyId.photoFinish => Icons.compare_arrows_rounded,
    TrophyId.nailBiter => Icons.flash_on_rounded,
    TrophyId.perfectBalance => Icons.balance_rounded,
    TrophyId.gameMaster => Icons.workspace_premium_rounded,
  };

  /// Metal of a tier: (light, deep).
  static (Color, Color) tierMetal(TrophyTier tier, MadarTokens t) => switch (tier) {
    TrophyTier.bronze => (const Color(0xFFE7A56B), const Color(0xFF8A4B22)),
    TrophyTier.silver => (const Color(0xFFEFF2F7), const Color(0xFF7C8594)),
    TrophyTier.gold => (Color.lerp(t.metalGold, Colors.white, 0.25)!, Color.lerp(t.metalGold, Colors.black, 0.35)!),
    TrophyTier.legendary => (const Color(0xFFB9F3FF), const Color(0xFF6D4BD8)),
  };
}

// ------------------------------------------------------------------ avatar

/// A player's avatar: an original generated emblem (Islamic star +
/// constellation from the seed), an emoji or an initial – on the player's
/// colour, with an optional glowing ring.
class TogetherAvatarView extends StatelessWidget {
  const TogetherAvatarView({
    super.key,
    required this.profile,
    required this.displayName,
    this.size = 56,
    this.ring = true,
    this.glow = false,
    this.dim = false,
  });

  final TogetherProfile profile;

  /// The name shown for [AvatarKind.initials] (the localised default when
  /// the player has none).
  final String displayName;
  final double size;
  final bool ring;
  final bool glow;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = TogetherLook.colorOf(profile);
    final avatar = profile.avatar;
    Widget face = CustomPaint(
      size: Size.square(size),
      painter: _AvatarDiscPainter(
        color: color,
        base: t.space0,
        gold: t.metalGold,
        avatar: avatar,
        drawEmblem: avatar.kind == AvatarKind.constellation,
      ),
    );
    final glyph = switch (avatar.kind) {
      AvatarKind.constellation => null,
      AvatarKind.emoji => Text(
        avatar.emoji ?? '⭐',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: size * 0.5, height: 1.1),
      ),
      AvatarKind.initials => Text(
        _initial(displayName),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: MadarTypography.displayFamily,
          fontSize: size * 0.46,
          height: 1.15,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          shadows: [Shadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 6)],
        ),
      ),
    };
    if (glyph != null) {
      face = Stack(
        alignment: Alignment.center,
        children: [
          face,
          ExcludeSemantics(child: glyph),
        ],
      );
    }
    return Semantics(
      label: displayName,
      image: true,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: dim ? 0.45 : 1,
        child: Container(
          width: size,
          height: size,
          padding: EdgeInsets.all(ring ? math.max(2.0, size * 0.045) : 0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: ring
                ? SweepGradient(
                    colors: [color, Color.lerp(color, t.metalGold, 0.6)!, color, Color.lerp(color, Colors.white, 0.4)!, color],
                  )
                : null,
            boxShadow: glow ? [BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: size * 0.35)] : null,
          ),
          child: ClipOval(child: face),
        ),
      ),
    );
  }

  static String _initial(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.characters.first.toUpperCase();
  }
}

class _AvatarDiscPainter extends CustomPainter {
  _AvatarDiscPainter({
    required this.color,
    required this.base,
    required this.gold,
    required this.avatar,
    required this.drawEmblem,
  });

  final Color color;
  final Color base;
  final Color gold;
  final TogetherAvatar avatar;
  final bool drawEmblem;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final rng = math.Random(avatar.seed * 7919 + 17);
    // The disc: lit from the upper start, deepening towards the rim.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.45),
          radius: 1.1,
          colors: [
            Color.lerp(color, Colors.white, 0.28)!,
            color,
            Color.lerp(color, base, 0.62)!,
          ],
          stops: const [0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    if (!drawEmblem) return;

    // A faint star field behind the emblem.
    final dust = Paint()..color = Colors.white.withValues(alpha: 0.35);
    for (var i = 0; i < 14; i++) {
      final a = rng.nextDouble() * math.pi * 2;
      final d = r * (0.25 + rng.nextDouble() * 0.7);
      canvas.drawCircle(c + Offset(math.cos(a) * d, math.sin(a) * d), r * (0.008 + rng.nextDouble() * 0.014), dust);
    }

    // The constellation: 4–6 stars on a ring, joined in order.
    final count = 4 + rng.nextInt(3);
    final start = rng.nextDouble() * math.pi * 2;
    final stars = <Offset>[
      for (var i = 0; i < count; i++)
        c +
            Offset.fromDirection(
              start + i * (math.pi * 2 / count) + (rng.nextDouble() - 0.5) * 0.6,
              r * (0.6 + rng.nextDouble() * 0.2),
            ),
    ];
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.42)
      ..strokeWidth = math.max(0.8, r * 0.025)
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(stars.first.dx, stars.first.dy);
    for (final s in stars.skip(1)) {
      path.lineTo(s.dx, s.dy);
    }
    if (rng.nextBool()) path.close();
    canvas.drawPath(path, line);
    for (final s in stars) {
      canvas.drawCircle(
        s,
        r * 0.075,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.25)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.05),
      );
      canvas.drawCircle(s, r * 0.04, Paint()..color = Colors.white.withValues(alpha: 0.95));
    }

    // The emblem: an n-point Islamic star with a gilded edge and a core.
    const pointsChoices = [5, 6, 7, 8, 8, 10, 12];
    final points = pointsChoices[rng.nextInt(pointsChoices.length)];
    final rotation = rng.nextDouble() * math.pi / points;
    final starR = r * (0.36 + rng.nextDouble() * 0.06);
    final star = IslamicGeometry.starPath(center: c, radius: starR, points: points, rotation: rotation);
    canvas.drawPath(
      star,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.06),
    );
    canvas.drawPath(
      star,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withValues(alpha: 0.95), Color.lerp(color, Colors.white, 0.55)!],
        ).createShader(Rect.fromCircle(center: c, radius: starR)),
    );
    canvas.drawPath(
      star,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, r * 0.03)
        ..color = gold,
    );
    canvas.drawCircle(c, starR * 0.3, Paint()..color = Color.lerp(color, base, 0.25)!);
    canvas.drawCircle(
      c,
      starR * 0.3,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.6, r * 0.02)
        ..color = gold.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(_AvatarDiscPainter old) =>
      old.color != color || old.base != base || old.gold != gold || old.avatar != avatar || old.drawEmblem != drawEmblem;
}

// ------------------------------------------------------------------ trophy

/// A trophy medallion: a metal disc of its tier with an eight-pointed star
/// and the trophy's icon. Locked trophies are engraved in dim glass.
class TrophyMedal extends StatelessWidget {
  const TrophyMedal({super.key, required this.id, this.size = 64, this.earned = true, this.holderColor});

  final TrophyId id;
  final double size;
  final bool earned;

  /// A player trophy's holder colour (a small jewel on the rim).
  final Color? holderColor;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (light, deep) = TogetherLook.tierMetal(id.tier, t);
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _MedalPainter(
          light: earned ? light : t.glassHighlight,
          deep: earned ? deep : t.space2,
          rim: earned ? light : t.glassBorder,
          glow: earned ? light.withValues(alpha: t.isDark ? 0.45 : 0.3) : null,
          jewel: earned ? holderColor : null,
          legendary: earned && id.tier == TrophyTier.legendary,
        ),
        child: Center(
          child: Icon(
            TogetherLook.trophyIcon(id),
            size: size * 0.36,
            color: earned ? TogetherLook.inkOn(Color.lerp(light, deep, 0.5)!) : t.textTertiary,
            shadows: earned ? [Shadow(color: deep.withValues(alpha: 0.8), blurRadius: 4)] : null,
          ),
        ),
      ),
    );
  }
}

class _MedalPainter extends CustomPainter {
  _MedalPainter({
    required this.light,
    required this.deep,
    required this.rim,
    required this.glow,
    required this.jewel,
    required this.legendary,
  });

  final Color light;
  final Color deep;
  final Color rim;
  final Color? glow;
  final Color? jewel;
  final bool legendary;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final g = glow;
    if (g != null) {
      canvas.drawCircle(
        c,
        r * 0.92,
        Paint()
          ..color = g
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.22),
      );
    }
    // Eight-pointed star plate behind the disc.
    final star = IslamicGeometry.starPath(center: c, radius: r * 0.98, points: 8, innerRatio: 0.78);
    canvas.drawPath(
      star,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: legendary ? [const Color(0xFFB9F3FF), const Color(0xFFE6B8FF), deep] : [light, deep],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawPath(
      star,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, r * 0.035)
        ..color = rim.withValues(alpha: 0.9),
    );
    // The disc.
    final disc = r * 0.7;
    canvas.drawCircle(
      c,
      disc,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: [Color.lerp(light, Colors.white, 0.2)!, Color.lerp(light, deep, 0.55)!, deep],
          stops: const [0, 0.55, 1],
        ).createShader(Rect.fromCircle(center: c, radius: disc)),
    );
    canvas.drawCircle(
      c,
      disc,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, r * 0.04)
        ..color = Color.lerp(deep, Colors.black, 0.2)!,
    );
    canvas.drawCircle(
      c,
      disc * 0.86,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.5, r * 0.018)
        ..color = Colors.white.withValues(alpha: 0.35),
    );
    final j = jewel;
    if (j != null) {
      final at = c + Offset(0, disc * 0.98);
      canvas.drawCircle(at, r * 0.13, Paint()..color = Color.lerp(deep, Colors.black, 0.2)!);
      canvas.drawCircle(at, r * 0.1, Paint()..color = j);
      canvas.drawCircle(at + Offset(-r * 0.03, -r * 0.03), r * 0.03, Paint()..color = Colors.white.withValues(alpha: 0.8));
    }
  }

  @override
  bool shouldRepaint(_MedalPainter old) =>
      old.light != light ||
      old.deep != deep ||
      old.rim != rim ||
      old.glow != glow ||
      old.jewel != jewel ||
      old.legendary != legendary;
}
