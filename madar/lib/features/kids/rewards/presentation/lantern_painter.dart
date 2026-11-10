import 'package:flutter/material.dart';

import 'play_kit.dart';

/// The colours of lantern 1, 2, 3 ... on the shelf.
const List<Color> lanternColors = [
  KidsColors.sun500,
  KidsColors.teal500,
  KidsColors.rose500,
  KidsColors.night500,
  KidsColors.sun300,
  KidsColors.teal200,
  KidsColors.rose300,
  KidsColors.night300,
  KidsColors.sun100,
];

/// A lantern: cap, hexagonal glass body with a flame, base and hook. Lit ones
/// glow in their colour; the ones still to come are a quiet sand silhouette.
/// Static: it paints once and never allocates again.
class LanternPainter extends CustomPainter {
  LanternPainter({required this.color, required this.lit});

  final Color color;
  final bool lit;

  static const _outline = KidsColors.night900;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = w / 2;
    // Proportions follow docs/kids/png/11-rewards.png.
    final top = h * 0.14, bodyTop = h * 0.22, bodyBottom = h * 0.80;
    final bodyHalf = w * 0.40, waist = w * 0.24;
    final body = Path()
      ..moveTo(cx - waist, bodyTop)
      ..lineTo(cx + waist, bodyTop)
      ..lineTo(cx + bodyHalf, (bodyTop + bodyBottom) / 2)
      ..lineTo(cx + waist, bodyBottom)
      ..lineTo(cx - waist, bodyBottom)
      ..lineTo(cx - bodyHalf, (bodyTop + bodyBottom) / 2)
      ..close();
    final cap = RRect.fromLTRBR(cx - w * 0.30, top, cx + w * 0.30, bodyTop, const Radius.circular(4));
    final base = RRect.fromLTRBR(cx - w * 0.30, bodyBottom, cx + w * 0.30, h * 0.90, const Radius.circular(4));

    if (!lit) {
      final p = Paint()..color = KidsColors.sand2;
      canvas.drawPath(body, p);
      canvas.drawRRect(cap, p);
      canvas.drawRRect(base, p);
      canvas.drawRect(Rect.fromLTWH(cx - 2, 0, 4, top), p);
      return;
    }

    // The glow behind the glass.
    final glowCentre = Offset(cx, (bodyTop + bodyBottom) / 2);
    canvas.drawCircle(
      glowCentre,
      w * 0.95,
      Paint()
        ..shader = RadialGradient(colors: [color.withValues(alpha: .38), color.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: glowCentre, radius: w * 0.95)),
    );
    canvas.drawRect(Rect.fromLTWH(cx - 2, 0, 4, top), Paint()..color = _outline);
    canvas.drawPath(body, Paint()..color = color);
    // Glass ribs.
    final rib = Paint()
      ..color = _outline.withValues(alpha: .28)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(cx - w * 0.14, bodyTop), Offset(cx - w * 0.2, bodyBottom), rib);
    canvas.drawLine(Offset(cx + w * 0.14, bodyTop), Offset(cx + w * 0.2, bodyBottom), rib);
    canvas.drawPath(
      body,
      Paint()
        ..color = _outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawRRect(cap, Paint()..color = _outline);
    canvas.drawRRect(base, Paint()..color = _outline);
    // The flame.
    final fy = (bodyTop + bodyBottom) / 2;
    final flame = Path()
      ..moveTo(cx, fy - h * 0.17)
      ..quadraticBezierTo(cx + w * 0.17, fy - h * 0.02, cx, fy + h * 0.13)
      ..quadraticBezierTo(cx - w * 0.17, fy - h * 0.02, cx, fy - h * 0.17)
      ..close();
    canvas.drawPath(flame, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(LanternPainter old) => old.color != color || old.lit != lit;
}

/// [LanternPainter] as a widget, with a spoken label.
class LanternView extends StatelessWidget {
  const LanternView({super.key, required this.color, required this.lit, required this.semanticLabel, this.width = 56});

  final Color color;
  final bool lit;
  final String semanticLabel;
  final double width;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    image: true,
    excludeSemantics: true,
    child: RepaintBoundary(
      child: CustomPaint(
        size: Size(width, width * 1.75),
        painter: LanternPainter(color: color, lit: lit),
      ),
    ),
  );
}
