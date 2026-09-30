import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/painters/painters.dart';
import '../../../core/design/tokens.dart';
import '../../../core/i18n/formatters.dart';
import '../domain/saved_web_game.dart';

/// Aligns user text (a game title, which carries its own direction) to the
/// reading start of the surrounding UI, so a wrapped English title in an
/// Arabic card lines up with the Arabic caption under it.
TextAlign uiStartAlign(BuildContext context) =>
    Directionality.of(context) == TextDirection.rtl ? TextAlign.right : TextAlign.left;

/// Glyphs and colours of generated game icons (Madar's own, original art).
abstract final class GameArtPalette {
  static const List<IconData> glyphs = [
    Icons.sports_esports_rounded,
    Icons.extension_rounded,
    Icons.rocket_launch_rounded,
    Icons.casino_rounded,
    Icons.auto_awesome_rounded,
    Icons.movie_filter_rounded,
    Icons.emoji_events_rounded,
    Icons.theater_comedy_rounded,
    Icons.psychology_rounded,
    Icons.bolt_rounded,
    Icons.diamond_rounded,
    Icons.castle_rounded,
    Icons.style_rounded,
    Icons.grid_on_rounded,
    Icons.music_note_rounded,
    Icons.pets_rounded,
  ];

  /// Hues (degrees) and saturations of the eight poster colours: lapis,
  /// emerald, terracotta, amethyst, teal, amber, rose, steel.
  static const List<(double, double)> _hues = [
    (224, 0.62),
    (158, 0.55),
    (14, 0.62),
    (272, 0.5),
    (188, 0.6),
    (38, 0.72),
    (340, 0.55),
    (210, 0.22),
  ];

  static IconData glyph(int i) => glyphs[i % glyphs.length];

  static GameColors colors(int hue) {
    final (h, s) = _hues[hue % _hues.length];
    Color c(double sat, double light) => HSLColor.fromAHSL(1, h, sat.clamp(0, 1), light).toColor();
    return GameColors(deep: c(s * 0.9, 0.13), base: c(s, 0.3), light: c(s, 0.52), glow: c(s + 0.25, 0.78));
  }
}

@immutable
class GameColors {
  const GameColors({required this.deep, required this.base, required this.light, required this.glow});

  final Color deep, base, light, glow;

  @override
  bool operator ==(Object other) =>
      other is GameColors && other.deep == deep && other.base == base && other.light == light && other.glow == glow;

  @override
  int get hashCode => Object.hash(deep, base, light, glow);
}

/// Small rounded icon of a game: its site icon on a soft tile, or the
/// generated glyph on its colour.
class GameIconTile extends StatelessWidget {
  const GameIconTile({super.key, required this.art, this.size = 52, this.radius});

  final GameArt art;
  final double size;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final colors = GameArtPalette.colors(art.hue);
    final r = BorderRadius.circular(radius ?? size * 0.28);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: r,
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [colors.light, colors.base, colors.deep],
          ),
          border: Border.all(color: colors.glow.withValues(alpha: 0.35), width: 0.8),
          boxShadow: [BoxShadow(color: colors.base.withValues(alpha: 0.35), blurRadius: size * 0.22)],
        ),
        alignment: Alignment.center,
        child: art.favicon != null
            ? _FaviconBadge(bytes: art, size: size * 0.64)
            : Icon(
                GameArtPalette.glyph(art.glyph),
                size: size * 0.52,
                color: Colors.white,
                shadows: [Shadow(color: colors.glow.withValues(alpha: 0.8), blurRadius: size * 0.2)],
              ),
      ),
    );
  }
}

class _FaviconBadge extends StatelessWidget {
  const _FaviconBadge({required this.bytes, required this.size});

  final GameArt bytes;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.1),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(size * 0.26),
      ),
      child: Image.memory(
        bytes.favicon!,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        errorBuilder: (context, _, _) => Icon(GameArtPalette.glyph(bytes.glyph), size: size * 0.7),
      ),
    );
  }
}

/// A cinema-poster card face for a game: film-strip edges, a projector
/// beam, an eight-point star and the game's glyph or site icon. The title
/// and caption sit on a scrim at the bottom.
class GamePoster extends StatelessWidget {
  const GamePoster({
    super.key,
    required this.art,
    required this.seed,
    this.title,
    this.caption,
    this.badge,
    this.titleMaxLines = 2,
    this.glyphScale = 1,
  });

  final GameArt art;

  /// Varies the star rotation and dust (usually the game id).
  final String seed;
  final String? title;
  final String? caption;

  /// Small chip over the top corner (e.g. "New").
  final String? badge;
  final int titleMaxLines;
  final double glyphScale;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final colors = GameArtPalette.colors(art.hue);
    final text = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth.isFinite ? box.maxWidth : 140.0;
        final h = box.maxHeight.isFinite ? box.maxHeight : w * 1.4;
        final glyphSize = math.min(w, h) * 0.34 * glyphScale;
        return ClipRRect(
          borderRadius: BorderRadius.circular(t.radiusM),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: GamePosterPainter(colors: colors, seed: fnv1a32(seed), frame: t.metalGold),
              ),
              Align(
                alignment: const Alignment(0, -0.28),
                child: art.favicon != null
                    ? DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(glyphSize * 0.3),
                          boxShadow: [
                            BoxShadow(color: colors.glow.withValues(alpha: 0.45), blurRadius: glyphSize * 0.5),
                          ],
                        ),
                        child: _FaviconBadge(bytes: art, size: glyphSize * 1.15),
                      )
                    : Icon(
                        GameArtPalette.glyph(art.glyph),
                        size: glyphSize,
                        color: Colors.white,
                        shadows: [
                          Shadow(color: colors.glow, blurRadius: glyphSize * 0.35),
                          Shadow(color: colors.glow.withValues(alpha: 0.6), blurRadius: glyphSize * 0.8),
                        ],
                      ),
              ),
              if (title != null || caption != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [colors.deep.withValues(alpha: 0), colors.deep.withValues(alpha: 0.92)],
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(w * 0.1, h * 0.14, w * 0.1, h * 0.06),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (title != null)
                            Text(
                              title!,
                              maxLines: titleMaxLines,
                              overflow: TextOverflow.ellipsis,
                              textDirection: BidiIsolate.directionOf(title!),
                              textAlign: uiStartAlign(context),
                              style: text.titleMedium?.copyWith(
                                color: Colors.white,
                                height: 1.25,
                                shadows: [Shadow(color: colors.deep, blurRadius: 6)],
                              ),
                            ),
                          if (caption != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                caption!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.78)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (badge != null)
                PositionedDirectional(
                  top: h * 0.07,
                  end: w * 0.1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: t.gold.withValues(alpha: t.isDark ? 0.92 : 1),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      badge!,
                      style: text.labelSmall?.copyWith(
                        color: t.isDark ? t.space0 : Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Paints a poster background (see [GamePoster]).
class GamePosterPainter extends CustomPainter {
  GamePosterPainter({required this.colors, required this.seed, required this.frame});

  final GameColors colors;
  final int seed;
  final Color frame;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final w = size.width, h = size.height;
    // Night-sky gradient in the game's colour.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.light, colors.base, colors.deep],
          stops: const [0, 0.45, 1],
        ).createShader(rect),
    );
    // Projector beam from the top.
    final beam = Path()
      ..moveTo(w * 0.44, 0)
      ..lineTo(w * 0.56, 0)
      ..lineTo(w * 1.05, h * 0.9)
      ..lineTo(-w * 0.05, h * 0.9)
      ..close();
    canvas.drawPath(
      beam,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.glow.withValues(alpha: 0.30), colors.glow.withValues(alpha: 0)],
        ).createShader(rect),
    );
    // Eight-point star rosette behind the glyph.
    final center = Offset(w / 2, h * 0.36);
    final r = math.min(w, h) * 0.36;
    final rotation = (seed % 360) * math.pi / 180 / 8;
    final star = IslamicGeometry.starPath(center: center, radius: r, points: 8, rotation: rotation);
    canvas.drawPath(star, Paint()..color = Colors.white.withValues(alpha: 0.07));
    canvas.drawPath(
      star,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = colors.glow.withValues(alpha: 0.45),
    );
    canvas.drawCircle(
      center,
      r * 0.62,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = colors.glow.withValues(alpha: 0.28),
    );
    // Star dust.
    final rnd = math.Random(seed);
    final dust = Paint()..color = Colors.white;
    for (var i = 0; i < 18; i++) {
      final p = Offset(w * (0.08 + rnd.nextDouble() * 0.84), h * rnd.nextDouble() * 0.7);
      dust.color = Colors.white.withValues(alpha: 0.25 + rnd.nextDouble() * 0.5);
      canvas.drawCircle(p, 0.5 + rnd.nextDouble() * 1.1, dust);
    }
    // Film-strip sprockets down both edges.
    final hole = Paint()..color = Colors.black.withValues(alpha: 0.32);
    final holeW = math.max(3.0, w * 0.035), holeH = holeW * 1.35, gap = holeH * 1.25;
    for (var y = gap * 0.6; y < h - holeH; y += gap) {
      for (final x in [w * 0.02, w - w * 0.02 - holeW]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x, y, holeW, holeH), Radius.circular(holeW * 0.3)),
          hole,
        );
      }
    }
    // Brass hairline frame.
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(w * 0.07), Radius.circular(w * 0.04)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = frame.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(GamePosterPainter old) => old.colors != colors || old.seed != seed || old.frame != frame;
}
