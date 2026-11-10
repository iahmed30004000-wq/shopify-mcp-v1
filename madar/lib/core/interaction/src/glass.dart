import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../design/tokens.dart';

/// Self-contained glass surface for the interaction kit (menus, toasts,
/// trays, sheets). Paints: soft outer glow, frosted fill with a top light
/// falloff and a start-corner sheen, and a gradient hairline that is brightest
/// along the top edge.
///
/// [blur] adds a real backdrop blur – only for overlays (sheets, toasts),
/// never inside list rows.
class InteractionGlass extends StatelessWidget {
  const InteractionGlass({
    super.key,
    required this.child,
    this.borderRadius,
    this.padding = EdgeInsets.zero,
    this.blur = false,
    this.dense = true,
    this.glowColor,
    this.glowSigma = 18,
    this.tint,
    this.borderColor,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry padding;
  final bool blur;

  /// Denser frosted fill for surfaces that sit on already-blurred content.
  final bool dense;
  final Color? glowColor;
  final double glowSigma;
  final Color? tint;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final radius = borderRadius ?? BorderRadius.circular(t.radiusL);
    final dir = Directionality.of(context);
    Widget body = CustomPaint(
      painter: InteractionGlassFillPainter(
        tokens: t,
        radius: radius,
        dense: dense || !blur,
        tint: tint,
        direction: dir,
      ),
      child: Padding(padding: padding, child: child),
    );
    if (blur) {
      body = BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: t.blurSigma, sigmaY: t.blurSigma, tileMode: TileMode.mirror),
        child: body,
      );
    }
    return CustomPaint(
      painter: InteractionGlowPainter(radius: radius, color: glowColor ?? t.glassShadow, sigma: glowSigma),
      foregroundPainter: InteractionHairlinePainter(
        radius: radius,
        highlight: t.glassHighlight,
        border: borderColor ?? t.glassBorder,
      ),
      child: ClipRRect(borderRadius: radius, child: body),
    );
  }
}

/// Fill of [InteractionGlass].
class InteractionGlassFillPainter extends CustomPainter {
  InteractionGlassFillPainter({
    required this.tokens,
    required this.radius,
    required this.dense,
    required this.direction,
    this.tint,
  });

  final MadarTokens tokens;
  final BorderRadius radius;
  final bool dense;
  final Color? tint;
  final TextDirection direction;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = tokens;
    final rect = Offset.zero & size;
    final glass = tint ?? t.glassFill;
    final base = dense ? Color.alphaBlend(glass, t.space2.withValues(alpha: t.isDark ? 0.86 : 0.8)) : glass;
    canvas.drawRect(rect, Paint()..color = base);
    final top = t.glassHighlight.withValues(alpha: t.glassHighlight.a * (t.isDark ? 0.16 : 0.32));
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topCenter,
          rect.bottomCenter,
          [
            top,
            top.withValues(alpha: 0),
            t.space0.withValues(alpha: 0),
            t.space0.withValues(alpha: t.isDark ? 0.18 : 0.04),
          ],
          const [0, 0.42, 0.7, 1],
        ),
    );
    final start = direction == TextDirection.rtl ? rect.topRight : rect.topLeft;
    final sheen = t.glassHighlight.withValues(alpha: t.glassHighlight.a * 0.12);
    canvas.drawRect(
      rect,
      Paint()..shader = ui.Gradient.radial(start, size.longestSide * 0.8, [sheen, sheen.withValues(alpha: 0)]),
    );
  }

  @override
  bool shouldRepaint(InteractionGlassFillPainter old) =>
      old.tokens != tokens ||
      old.radius != radius ||
      old.dense != dense ||
      old.tint != tint ||
      old.direction != direction;
}

/// Soft outer glow under a rounded rectangle.
class InteractionGlowPainter extends CustomPainter {
  const InteractionGlowPainter({
    required this.radius,
    required this.color,
    this.sigma = 18,
    this.offset = const Offset(0, 6),
  });

  final BorderRadius radius;
  final Color color;
  final double sigma;
  final Offset offset;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || color.a == 0 || sigma <= 0) return;
    final rrect = radius.toRRect(Offset.zero & size).shift(offset);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.outer, sigma),
    );
  }

  @override
  bool shouldRepaint(InteractionGlowPainter old) =>
      old.radius != radius || old.color != color || old.sigma != sigma || old.offset != offset;
}

/// Gradient hairline: bright along the top edge, fading down the sides.
class InteractionHairlinePainter extends CustomPainter {
  const InteractionHairlinePainter({
    required this.radius,
    required this.highlight,
    required this.border,
    this.width = 1,
  });

  final BorderRadius radius;
  final Color highlight;
  final Color border;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = (Offset.zero & size).deflate(width / 2);
    canvas.drawRRect(
      radius.toRRect(rect),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..shader = ui.Gradient.linear(
          rect.topCenter,
          rect.bottomCenter,
          [highlight.withValues(alpha: highlight.a * 0.9), border, border.withValues(alpha: border.a * 0.45)],
          const [0, 0.35, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(InteractionHairlinePainter old) =>
      old.radius != radius || old.highlight != highlight || old.border != border || old.width != width;
}

/// An eight-pointed star (Rub el Hizb) engraved in brass – the kit's small
/// ornament for sheet headers and empty states.
class StarOrnamentPainter extends CustomPainter {
  const StarOrnamentPainter({required this.color, this.rotation = 0, this.strokeWidth = 1});

  final Color color;
  final double rotation;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - strokeWidth;
    if (r <= 0) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color
      ..isAntiAlias = true;
    Path square(double angle, double radius) {
      final p = Path();
      for (var i = 0; i < 4; i++) {
        final a = angle + i * math.pi / 2;
        final o = c + Offset(math.cos(a), math.sin(a)) * radius;
        if (i == 0) {
          p.moveTo(o.dx, o.dy);
        } else {
          p.lineTo(o.dx, o.dy);
        }
      }
      return p..close();
    }

    canvas.drawPath(square(rotation, r), paint);
    canvas.drawPath(square(rotation + math.pi / 4, r), paint);
    canvas.drawCircle(c, r * 0.42, paint..strokeWidth = strokeWidth * 0.8);
    canvas.drawCircle(c, r * 0.12, Paint()..color = color);
  }

  @override
  bool shouldRepaint(StarOrnamentPainter old) =>
      old.color != color || old.rotation != rotation || old.strokeWidth != strokeWidth;
}
