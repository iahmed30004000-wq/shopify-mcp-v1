import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../painters/arabesque_border_painter.dart';
import '../painters/astrolabe_ticks_painter.dart';
import '../painters/girih_rosette_painter.dart';
import '../painters/islamic_star_painter.dart';
import '../tokens.dart';
import '../typography.dart';

/// Small decorative Islamic star (brass-to-gold gradient by default).
/// Decorative: excluded from semantics.
class IslamicStar extends StatelessWidget {
  const IslamicStar({
    super.key,
    this.size = 16,
    this.points = 8,
    this.style = IslamicStarStyle.star,
    this.color,
    this.filled = true,
    this.glow = false,
    this.rotation = 0,
    this.strokeWidth = 1.2,
  });

  final double size;
  final int points;
  final IslamicStarStyle style;

  /// Solid colour; defaults to the gold → brass gradient.
  final Color? color;
  final bool filled;
  final bool glow;
  final double rotation;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = color;
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: IslamicStarPainter(
          points: points,
          style: style,
          rotation: rotation,
          fillGradient: filled && c == null ? [t.gold, t.brass] : null,
          fillColor: filled ? c : null,
          strokeColor: filled ? null : (c ?? t.brass),
          strokeWidth: strokeWidth,
          glowColor: glow ? t.accentGlow : null,
          glowSigma: size * 0.25,
        ),
      ),
    );
  }
}

/// Interlaced girih rosette in the theme's metals.
class GirihRosette extends StatelessWidget {
  const GirihRosette({super.key, this.size = 120, this.folds = 8, this.rotation = 0});

  final double size;
  final int folds;
  final double rotation;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: GirihRosettePainter(
          folds: folds,
          rotation: rotation,
          strandColor: t.gold,
          strandInnerColor: t.brassDark.withValues(alpha: t.isDark ? 0.9 : 0.55),
          ringColor: t.brass,
          fillColor: t.accentSoft,
          centerColor: t.gold,
        ),
      ),
    );
  }
}

/// A full-width arabesque border band; flows in the reading direction.
class ArabesqueBorder extends StatelessWidget {
  const ArabesqueBorder({super.key, this.height = 24, this.color, this.phase = 0});

  final double height;
  final Color? color;

  /// 0..1 – scroll the vine (drive from an animation for ambient motion).
  final double phase;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = color ?? t.brass;
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: ArabesqueBorderPainter(
            color: c,
            leafColor: Color.lerp(c, t.gold, 0.5),
            railColor: c.withValues(alpha: c.a * 0.8),
            textDirection: Directionality.of(context),
            phase: phase,
          ),
        ),
      ),
    );
  }
}

/// Brass astrolabe degree ring. Numerals use Arabic-Indic digits in Arabic
/// locales unless [arabicIndic] says otherwise.
class AstrolabeRing extends StatelessWidget {
  const AstrolabeRing({
    super.key,
    this.size = 160,
    this.rotation = 0,
    this.showNumerals = true,
    this.arabicIndic,
    this.child,
  });

  final double size;
  final double rotation;
  final bool showNumerals;
  final bool? arabicIndic;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final arabic = arabicIndic ?? Localizations.maybeLocaleOf(context)?.languageCode == 'ar';
    return ExcludeSemantics(
      excluding: child == null,
      child: CustomPaint(
        painter: AstrolabeTicksPainter(
          color: t.brass,
          majorColor: t.gold,
          numeralColor: t.gold,
          rotation: rotation,
          showNumerals: showNumerals,
          arabicIndic: arabic,
          fontFamily: MadarTypography.uiFamily,
        ),
        child: SizedBox.square(
          dimension: size,
          child: child == null ? null : Center(child: child),
        ),
      ),
    );
  }
}

/// Hairline divider; with [ornament] a small Rub el Hizb flanked by
/// diamonds sits in the middle and the rule fades toward both ends.
class MadarDivider extends StatelessWidget {
  const MadarDivider({super.key, this.ornament = true, this.color, this.height = 28, this.indent = 0});

  final bool ornament;
  final Color? color;
  final double height;

  /// Horizontal inset on both sides.
  final double indent;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ExcludeSemantics(
      child: Padding(
        padding: EdgeInsetsDirectional.symmetric(horizontal: indent),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: MadarDividerPainter(
              color: color ?? t.brass,
              accent: t.gold,
              glow: t.accentGlow,
              ornament: ornament,
            ),
          ),
        ),
      ),
    );
  }
}

class MadarDividerPainter extends CustomPainter {
  const MadarDividerPainter({required this.color, required this.accent, required this.glow, this.ornament = true});

  final Color color;
  final Color accent;
  final Color glow;
  final bool ornament;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final y = size.height / 2;
    final cx = size.width / 2;
    final line = Paint()..strokeWidth = 0.8;
    if (!ornament) {
      line.shader = ui.Gradient.linear(
        Offset(0, y),
        Offset(size.width, y),
        [color.withValues(alpha: 0), color, color.withValues(alpha: 0)],
        const [0, 0.5, 1],
      );
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
      return;
    }
    final r = math.min(size.height * 0.26, 7.5);
    final gap = r * 3.6;
    // Rules fading outward.
    line.shader = ui.Gradient.linear(Offset(cx - gap, y), Offset(0, y), [color, color.withValues(alpha: 0)]);
    canvas.drawLine(Offset(cx - gap, y), Offset(0, y), line);
    line.shader = ui.Gradient.linear(Offset(cx + gap, y), Offset(size.width, y), [color, color.withValues(alpha: 0)]);
    canvas.drawLine(Offset(cx + gap, y), Offset(size.width, y), line);

    // Diamonds.
    final diamond = Paint()..color = color;
    for (final dx in [-gap * 0.72, gap * 0.72]) {
      final c = Offset(cx + dx, y);
      final d = r * 0.32;
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - d)
          ..lineTo(c.dx + d * 1.4, c.dy)
          ..lineTo(c.dx, c.dy + d)
          ..lineTo(c.dx - d * 1.4, c.dy)
          ..close(),
        diamond,
      );
    }
    // Centre Rub el Hizb with a soft glow.
    final center = Offset(cx, y);
    canvas.drawCircle(
      center,
      r * 1.3,
      Paint()
        ..color = glow.withValues(alpha: glow.a * 0.5)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.9),
    );
    final squares = IslamicGeometry.rubElHizbSquares(center: center, radius: r);
    final stroke = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeJoin = StrokeJoin.miter;
    canvas.drawPath(
      IslamicGeometry.rubElHizbOutline(center: center, radius: r),
      Paint()..color = color.withValues(alpha: color.a * 0.25),
    );
    for (final sq in squares) {
      canvas.drawPath(IslamicGeometry.polygon(sq), stroke);
    }
    canvas.drawCircle(center, r * 0.22, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(MadarDividerPainter old) =>
      old.color != color || old.accent != accent || old.glow != glow || old.ornament != ornament;
}
