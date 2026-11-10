import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../rewards/presentation/lantern_painter.dart';
import '../../rewards/presentation/play_kit.dart';

/// The twelve original pictures on the faces of the cards (ids match
/// `PairsGame.deck`). Plain shapes, no characters, no faces.
class PairSymbolPainter extends CustomPainter {
  PairSymbolPainter(this.symbol);

  final int symbol;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = size.center(Offset.zero);
    final fill = Paint()..isAntiAlias = true;
    switch (symbol % 12) {
      case 0: // lantern
        canvas.save();
        canvas.translate(c.dx - s * 0.28, c.dy - s * 0.5);
        LanternPainter(color: KidsColors.sun500, lit: true).paint(canvas, Size(s * 0.56, s));
        canvas.restore();
      case 1: // khatam star
        canvas.drawPath(khatamPath(c, s * 0.46), fill..color = KidsColors.sun500);
        canvas.drawPath(khatamPath(c, s * 0.2, innerRatio: 0.6), fill..color = KidsColors.night800);
      case 2: // sun
        final ray = Paint()
          ..color = KidsColors.sun500
          ..strokeWidth = s * 0.07
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          canvas.drawLine(
            c + Offset(math.cos(a), math.sin(a)) * (s * 0.32),
            c + Offset(math.cos(a), math.sin(a)) * (s * 0.46),
            ray,
          );
        }
        canvas.drawCircle(c, s * 0.24, fill..color = KidsColors.sun500);
      case 3: // moon
        final moon = Path.combine(
          PathOperation.difference,
          Path()..addOval(Rect.fromCircle(center: c, radius: s * 0.4)),
          Path()..addOval(Rect.fromCircle(center: c + Offset(s * 0.17, -s * 0.07), radius: s * 0.34)),
        );
        canvas.drawPath(moon, fill..color = KidsColors.night500);
      case 4: // tree
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: c + Offset(0, s * 0.3), width: s * 0.12, height: s * 0.3),
            Radius.circular(s * 0.04),
          ),
          fill..color = KidsColors.sun700,
        );
        fill.color = KidsColors.teal500;
        canvas.drawCircle(c + Offset(0, -s * 0.1), s * 0.24, fill);
        canvas.drawCircle(c + Offset(-s * 0.18, s * 0.06), s * 0.19, fill);
        canvas.drawCircle(c + Offset(s * 0.18, s * 0.06), s * 0.19, fill);
      case 5: // flower
        fill.color = KidsColors.rose500;
        for (var i = 0; i < 6; i++) {
          final a = i * math.pi / 3;
          canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * (s * 0.22), s * 0.15, fill);
        }
        canvas.drawCircle(c, s * 0.13, fill..color = KidsColors.sun500);
      case 6: // drop
        final drop = Path()
          ..moveTo(c.dx, c.dy - s * 0.42)
          ..quadraticBezierTo(c.dx + s * 0.4, c.dy + s * 0.05, c.dx, c.dy + s * 0.4)
          ..quadraticBezierTo(c.dx - s * 0.4, c.dy + s * 0.05, c.dx, c.dy - s * 0.42)
          ..close();
        canvas.drawPath(drop, fill..color = KidsColors.teal500);
        canvas.drawCircle(c + Offset(-s * 0.1, s * 0.12), s * 0.06, fill..color = Colors.white.withValues(alpha: .7));
      case 7: // leaf
        final leaf = Path()
          ..moveTo(c.dx - s * 0.4, c.dy + s * 0.38)
          ..quadraticBezierTo(c.dx - s * 0.35, c.dy - s * 0.4, c.dx + s * 0.4, c.dy - s * 0.38)
          ..quadraticBezierTo(c.dx + s * 0.35, c.dy + s * 0.4, c.dx - s * 0.4, c.dy + s * 0.38)
          ..close();
        canvas.drawPath(leaf, fill..color = KidsColors.teal700);
        canvas.drawLine(
          Offset(c.dx - s * 0.36, c.dy + s * 0.34),
          Offset(c.dx + s * 0.2, c.dy - s * 0.2),
          Paint()
            ..color = KidsColors.teal200
            ..strokeWidth = s * 0.04
            ..strokeCap = StrokeCap.round,
        );
      case 8: // heart
        final heart = Path()
          ..moveTo(c.dx, c.dy + s * 0.38)
          ..cubicTo(c.dx - s * 0.62, c.dy - s * 0.05, c.dx - s * 0.3, c.dy - s * 0.5, c.dx, c.dy - s * 0.15)
          ..cubicTo(c.dx + s * 0.3, c.dy - s * 0.5, c.dx + s * 0.62, c.dy - s * 0.05, c.dx, c.dy + s * 0.38)
          ..close();
        canvas.drawPath(heart, fill..color = KidsColors.rose500);
      case 9: // cloud
        fill.color = KidsColors.night300;
        canvas.drawCircle(c + Offset(-s * 0.18, s * 0.06), s * 0.2, fill);
        canvas.drawCircle(c + Offset(s * 0.02, -s * 0.08), s * 0.24, fill);
        canvas.drawCircle(c + Offset(s * 0.22, s * 0.08), s * 0.18, fill);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: c + Offset(0, s * 0.12), width: s * 0.7, height: s * 0.24),
            Radius.circular(s * 0.12),
          ),
          fill,
        );
      case 10: // kite
        final kite = Path()
          ..moveTo(c.dx, c.dy - s * 0.42)
          ..lineTo(c.dx + s * 0.26, c.dy - s * 0.05)
          ..lineTo(c.dx, c.dy + s * 0.2)
          ..lineTo(c.dx - s * 0.26, c.dy - s * 0.05)
          ..close();
        canvas.drawPath(kite, fill..color = KidsColors.rose300);
        final tail = Paint()
          ..color = KidsColors.night500
          ..strokeWidth = s * 0.035
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        canvas.drawPath(
          Path()
            ..moveTo(c.dx, c.dy + s * 0.2)
            ..quadraticBezierTo(c.dx + s * 0.18, c.dy + s * 0.32, c.dx - s * 0.02, c.dy + s * 0.44),
          tail,
        );
        canvas.drawLine(Offset(c.dx, c.dy - s * 0.42), Offset(c.dx, c.dy + s * 0.2), tail..strokeWidth = s * 0.02);
      default: // gem
        final gem = Path()
          ..moveTo(c.dx - s * 0.28, c.dy - s * 0.18)
          ..lineTo(c.dx - s * 0.14, c.dy - s * 0.38)
          ..lineTo(c.dx + s * 0.14, c.dy - s * 0.38)
          ..lineTo(c.dx + s * 0.28, c.dy - s * 0.18)
          ..lineTo(c.dx, c.dy + s * 0.4)
          ..close();
        canvas.drawPath(gem, fill..color = KidsColors.night500);
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - s * 0.28, c.dy - s * 0.18)
            ..lineTo(c.dx + s * 0.28, c.dy - s * 0.18)
            ..moveTo(c.dx - s * 0.1, c.dy - s * 0.18)
            ..lineTo(c.dx, c.dy + s * 0.4)
            ..moveTo(c.dx + s * 0.1, c.dy - s * 0.18)
            ..lineTo(c.dx, c.dy + s * 0.4),
          Paint()
            ..color = Colors.white.withValues(alpha: .6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.025,
        );
    }
  }

  @override
  bool shouldRepaint(PairSymbolPainter old) => old.symbol != symbol;
}
