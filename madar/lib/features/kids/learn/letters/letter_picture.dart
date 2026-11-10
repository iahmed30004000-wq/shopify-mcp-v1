// Twenty-eight small original pictures, drawn in code on a 100 x 100 board
// (no assets, nothing traced from anyone). One per example word.
//
// Shapes are flat and friendly in the section's palette. Every picture is a
// handful of circles, ovals and paths. All 28 letters have a picture; the
// khatam star tile ([KhatamStarPainter]) is the fallback a future letter
// without a drawing would get (never an empty box).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/arabic_letters.dart';
import '../ui/kids_tokens.dart';

/// How many pictures are drawn (one per [LetterPicture]; asserted by a test).
int get letterPictureCount => LetterPicture.values.length;

class LetterPictureView extends StatelessWidget {
  const LetterPictureView({super.key, required this.picture, this.size = 96});

  final LetterPicture picture;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: LetterPicturePainter(picture),
      ),
    ),
  );
}

class LetterPicturePainter extends CustomPainter {
  const LetterPicturePainter(this.picture);

  final LetterPicture picture;

  static const _ink = KidsColors.night900;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.width / 100, size.height / 100);
    final p = Paint()..isAntiAlias = true;
    void oval(double cx, double cy, double rx, double ry, Color c) {
      p
        ..style = PaintingStyle.fill
        ..color = c;
      canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2), p);
    }

    void circle(double cx, double cy, double r, Color c) => oval(cx, cy, r, r, c);
    void rect(double l, double t, double w, double h, Color c, [double r = 3]) {
      p
        ..style = PaintingStyle.fill
        ..color = c;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(l, t, w, h), Radius.circular(r)), p);
    }

    void poly(List<double> pts, Color c) {
      final path = Path()..moveTo(pts[0], pts[1]);
      for (var i = 2; i < pts.length; i += 2) {
        path.lineTo(pts[i], pts[i + 1]);
      }
      path.close();
      p
        ..style = PaintingStyle.fill
        ..color = c;
      canvas.drawPath(path, p);
    }

    void line(double x1, double y1, double x2, double y2, Color c, [double w = 3]) {
      p
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round
        ..color = c;
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), p);
      p.style = PaintingStyle.fill;
    }

    void arc(double cx, double cy, double r, double a0, double sweep, Color c, [double w = 3]) {
      p
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round
        ..color = c;
      canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), a0, sweep, false, p);
      p.style = PaintingStyle.fill;
    }

    void petals(double cx, double cy, int n, double dist, double rx, double ry, Color c, {double start = 0}) {
      for (var i = 0; i < n; i++) {
        final a = start + i * 2 * math.pi / n;
        canvas
          ..save()
          ..translate(cx + dist * math.cos(a), cy + dist * math.sin(a))
          ..rotate(a);
        oval(0, 0, rx, ry, c);
        canvas.restore();
      }
    }

    void eye(double x, double y, [double r = 2.6]) => circle(x, y, r, _ink);

    switch (picture) {
      case LetterPicture.rabbit:
        oval(40, 24, 7, 20, KidsColors.night100);
        oval(60, 24, 7, 20, KidsColors.night100);
        oval(40, 25, 3.5, 14, KidsColors.rose300);
        oval(60, 25, 3.5, 14, KidsColors.rose300);
        oval(50, 70, 28, 24, KidsColors.night100);
        circle(50, 50, 20, KidsColors.night100);
        eye(43, 48);
        eye(57, 48);
        circle(50, 56, 3, KidsColors.rose500);
        circle(70, 86, 7, Colors.white);
      case LetterPicture.house:
        rect(22, 46, 56, 40, KidsColors.sun300, 4);
        poly([14, 48, 50, 16, 86, 48], KidsColors.rose500);
        rect(43, 60, 16, 26, KidsColors.night500, 4);
        rect(28, 54, 11, 11, KidsColors.teal200, 2);
        rect(66, 54, 8, 11, KidsColors.teal200, 2);
        rect(66, 22, 8, 16, KidsColors.night300, 2);
      case LetterPicture.apple:
        circle(38, 58, 24, KidsColors.rose500);
        circle(62, 58, 24, KidsColors.rose500);
        circle(50, 64, 24, KidsColors.rose500);
        line(50, 38, 54, 20, KidsColors.sun700, 4);
        oval(64, 24, 12, 6, KidsColors.teal500);
        circle(38, 52, 4, KidsColors.rose300);
      case LetterPicture.snowflake:
        for (var i = 0; i < 3; i++) {
          final a = i * math.pi / 3;
          final dx = 38 * math.cos(a), dy = 38 * math.sin(a);
          line(50 - dx, 50 - dy, 50 + dx, 50 + dy, KidsColors.night500, 4);
        }
        circle(50, 50, 8, KidsColors.night100);
        for (var i = 0; i < 6; i++) {
          final a = i * math.pi / 3;
          circle(50 + 38 * math.cos(a), 50 + 38 * math.sin(a), 5, KidsColors.night300);
        }
      case LetterPicture.carrot:
        poly([34, 36, 66, 36, 54, 90], KidsColors.sun500);
        line(40, 50, 52, 50, KidsColors.sun700, 2.5);
        line(44, 64, 55, 64, KidsColors.sun700, 2.5);
        oval(42, 24, 6, 14, KidsColors.teal500);
        oval(58, 24, 6, 14, KidsColors.teal500);
        oval(50, 20, 6, 16, KidsColors.teal700);
      case LetterPicture.bag:
        arc(50, 36, 14, math.pi, math.pi, KidsColors.night700, 6);
        rect(24, 36, 52, 46, KidsColors.rose500, 10);
        rect(24, 50, 52, 8, KidsColors.rose300, 0);
        circle(50, 54, 5, KidsColors.sun500);
      case LetterPicture.tent:
        poly([50, 16, 90, 82, 10, 82], KidsColors.teal500);
        poly([50, 16, 62, 82, 38, 82], KidsColors.teal700);
        poly([50, 44, 60, 82, 40, 82], KidsColors.sun300);
        line(50, 8, 50, 20, KidsColors.night700, 3);
      case LetterPicture.bicycle:
        arc(26, 66, 17, 0, 2 * math.pi, KidsColors.night800, 5);
        arc(74, 66, 17, 0, 2 * math.pi, KidsColors.night800, 5);
        line(26, 66, 44, 40, KidsColors.rose500, 5);
        line(44, 40, 66, 40, KidsColors.rose500, 5);
        line(66, 40, 74, 66, KidsColors.rose500, 5);
        line(44, 40, 52, 66, KidsColors.rose500, 5);
        line(52, 66, 26, 66, KidsColors.rose500, 5);
        line(66, 40, 62, 30, KidsColors.night800, 5);
        line(38, 36, 48, 36, KidsColors.night800, 5);
        circle(52, 66, 4, KidsColors.sun500);
      case LetterPicture.corn:
        oval(50, 54, 16, 34, KidsColors.sun500);
        for (var r = 0; r < 4; r++) {
          for (var c = 0; c < 2; c++) {
            circle(44 + c * 12, 38 + r * 10, 3.2, KidsColors.sun100);
          }
        }
        poly([50, 90, 22, 44, 36, 50, 44, 76], KidsColors.teal500);
        poly([50, 90, 78, 44, 64, 50, 56, 76], KidsColors.teal700);
      case LetterPicture.pomegranate:
        circle(50, 56, 31, KidsColors.rose500);
        circle(40, 46, 8, KidsColors.rose300);
        poly([38, 28, 44, 20, 50, 28, 56, 20, 62, 28, 58, 34, 42, 34], KidsColors.rose700);
        circle(50, 62, 4, KidsColors.rose300);
        circle(60, 70, 3, KidsColors.rose300);
        circle(40, 70, 3, KidsColors.rose300);
      case LetterPicture.daisy:
        petals(50, 46, 8, 20, 12, 6.5, Colors.white);
        circle(50, 46, 11, KidsColors.sun500);
        line(50, 58, 50, 92, KidsColors.teal700, 4);
        oval(64, 80, 12, 5, KidsColors.teal500);
      case LetterPicture.fish:
        poly([68, 50, 94, 30, 94, 70], KidsColors.sun500);
        oval(44, 50, 30, 21, KidsColors.teal500);
        oval(40, 60, 20, 8, KidsColors.teal200);
        circle(30, 44, 4.5, Colors.white);
        eye(29, 44, 2.4);
        arc(52, 50, 10, -1.2, 2.4, KidsColors.teal700, 2.5);
      case LetterPicture.sun:
        petals(50, 50, 12, 36, 7, 3, KidsColors.sun500);
        circle(50, 50, 24, KidsColors.sun500);
        circle(50, 50, 24, KidsColors.sun300.withValues(alpha: 0.6));
        eye(42, 46, 2.5);
        eye(58, 46, 2.5);
        arc(50, 52, 9, 0.4, 2.3, KidsColors.sun700, 2.5);
      case LetterPicture.rocket:
        poly([36, 74, 22, 90, 40, 82], KidsColors.rose500);
        poly([64, 74, 78, 90, 60, 82], KidsColors.rose500);
        oval(50, 48, 15, 32, KidsColors.night100);
        poly([35, 40, 50, 12, 65, 40], KidsColors.rose500);
        circle(50, 50, 8, KidsColors.night500);
        circle(50, 50, 4.5, KidsColors.teal200);
        poly([42, 78, 50, 98, 58, 78], KidsColors.sun500);
      case LetterPicture.frog:
        circle(34, 34, 12, KidsColors.teal500);
        circle(66, 34, 12, KidsColors.teal500);
        oval(50, 62, 34, 26, KidsColors.teal500);
        circle(34, 33, 6, Colors.white);
        circle(66, 33, 6, Colors.white);
        eye(35, 34, 3);
        eye(65, 34, 3);
        arc(50, 58, 16, 0.3, 2.5, KidsColors.teal700, 3);
        oval(22, 84, 11, 5, KidsColors.teal700);
        oval(78, 84, 11, 5, KidsColors.teal700);
      case LetterPicture.bird:
        poly([86, 52, 98, 42, 96, 62], KidsColors.night500);
        oval(50, 56, 30, 22, KidsColors.night500);
        circle(32, 44, 14, KidsColors.night500);
        poly([20, 42, 8, 47, 20, 52], KidsColors.sun500);
        eye(30, 40, 2.6);
        oval(52, 60, 16, 10, KidsColors.night300);
        line(44, 78, 44, 90, KidsColors.sun700, 3);
        line(58, 78, 58, 90, KidsColors.sun700, 3);
      case LetterPicture.envelope:
        rect(10, 26, 80, 54, KidsColors.sun300, 6);
        poly([10, 30, 50, 58, 90, 30, 90, 26, 10, 26], KidsColors.sun500);
        line(10, 78, 40, 52, KidsColors.sun700, 2.5);
        line(90, 78, 60, 52, KidsColors.sun700, 2.5);
        circle(50, 60, 7, KidsColors.rose500);
      case LetterPicture.grapes:
        line(52, 18, 62, 10, KidsColors.sun700, 4);
        oval(70, 14, 12, 6, KidsColors.teal500);
        const cols = [3, 4, 3, 2, 1];
        for (var r = 0; r < cols.length; r++) {
          final n = cols[r];
          for (var c = 0; c < n; c++) {
            circle(50 + (c - (n - 1) / 2) * 17, 30 + r * 15.0, 8.4, r.isEven ? KidsColors.night500 : KidsColors.night700);
          }
        }
        circle(40, 28, 2.6, Colors.white.withValues(alpha: 0.5));
      case LetterPicture.cloud:
        circle(32, 58, 18, KidsColors.night300);
        circle(52, 44, 24, KidsColors.night300);
        circle(72, 58, 18, KidsColors.night300);
        rect(26, 56, 52, 20, KidsColors.night300, 10);
        line(34, 86, 30, 94, KidsColors.teal500, 3);
        line(52, 86, 48, 94, KidsColors.teal500, 3);
        line(70, 86, 66, 94, KidsColors.teal500, 3);
      case LetterPicture.butterfly:
        oval(30, 36, 20, 22, KidsColors.rose500);
        oval(70, 36, 20, 22, KidsColors.rose500);
        oval(34, 68, 15, 17, KidsColors.sun500);
        oval(66, 68, 15, 17, KidsColors.sun500);
        circle(28, 34, 6, KidsColors.rose300);
        circle(72, 34, 6, KidsColors.rose300);
        oval(50, 54, 5, 28, KidsColors.night800);
        line(48, 28, 40, 14, KidsColors.night800, 2.5);
        line(52, 28, 60, 14, KidsColors.night800, 2.5);
      case LetterPicture.moon:
        final moon = Path()
          ..addOval(Rect.fromCircle(center: const Offset(48, 50), radius: 34))
          ..fillType = PathFillType.nonZero;
        final bite = Path()..addOval(Rect.fromCircle(center: const Offset(64, 42), radius: 28));
        p.color = KidsColors.sun500;
        canvas.drawPath(Path.combine(PathOperation.difference, moon, bite), p);
        _sparkle(canvas, p, 76, 66, 6, KidsColors.sun300);
        _sparkle(canvas, p, 82, 28, 4, KidsColors.sun300);
      case LetterPicture.ball:
        circle(50, 50, 36, KidsColors.teal500);
        arc(50, 50, 36, -0.6, 1.4, KidsColors.teal100, 6);
        arc(50, 50, 36, 2.4, 1.4, KidsColors.teal100, 6);
        line(50, 14, 50, 86, KidsColors.teal100, 4);
        circle(38, 36, 5, Colors.white.withValues(alpha: 0.45));
      case LetterPicture.lemon:
        oval(50, 54, 38, 27, KidsColors.sun500);
        oval(10, 54, 6, 5, KidsColors.sun500);
        oval(90, 54, 6, 5, KidsColors.sun500);
        oval(40, 44, 14, 6, KidsColors.sun300);
        oval(70, 28, 12, 6, KidsColors.teal500);
        line(60, 34, 66, 30, KidsColors.sun700, 3);
      case LetterPicture.umbrella:
        final dome = Path()
          ..moveTo(8, 52)
          ..arcToPoint(const Offset(92, 52), radius: const Radius.circular(42), clockwise: true)
          ..quadraticBezierTo(80, 44, 71, 52)
          ..quadraticBezierTo(60, 44, 50, 52)
          ..quadraticBezierTo(40, 44, 29, 52)
          ..quadraticBezierTo(18, 44, 8, 52)
          ..close();
        p.color = KidsColors.rose500;
        canvas.drawPath(dome, p);
        arc(50, 52, 42, math.pi * 1.25, math.pi * 0.2, KidsColors.rose300, 5);
        line(50, 52, 50, 82, KidsColors.night800, 4);
        arc(58, 82, 8, math.pi / 2, math.pi, KidsColors.night800, 4);
      case LetterPicture.star:
        poly(_starPoints(50, 52, 40, 17, 5), KidsColors.sun500);
        poly(_starPoints(50, 52, 24, 10, 5), KidsColors.sun300);
      case LetterPicture.pyramid:
        poly([50, 14, 94, 82, 6, 82], KidsColors.sun500);
        poly([50, 14, 94, 82, 58, 82], KidsColors.sun700);
        line(24, 62, 70, 62, KidsColors.sun300, 2.5);
        line(36, 44, 62, 44, KidsColors.sun300, 2.5);
        circle(84, 22, 8, KidsColors.rose300);
      case LetterPicture.rose:
        line(50, 58, 50, 94, KidsColors.teal700, 4);
        oval(34, 80, 12, 5, KidsColors.teal500);
        circle(50, 40, 28, KidsColors.rose500);
        circle(50, 42, 20, KidsColors.rose300);
        arc(50, 42, 12, 0.5, 4.5, KidsColors.rose500, 3.5);
        arc(50, 42, 5.5, 3.5, 4.5, KidsColors.rose700, 3);
      case LetterPicture.sailboat:
        poly([30, 68, 70, 68, 62, 84, 38, 84], KidsColors.night700);
        line(50, 14, 50, 68, KidsColors.night900, 3);
        poly([54, 16, 84, 60, 54, 60], KidsColors.sun500);
        poly([46, 24, 46, 60, 22, 60], KidsColors.rose300);
        arc(50, 92, 40, math.pi * 1.2, math.pi * 0.6, KidsColors.teal500, 4);
    }
    canvas.restore();
  }

  static List<double> _starPoints(double cx, double cy, double outer, double inner, int n) {
    final pts = <double>[];
    for (var i = 0; i < n * 2; i++) {
      final r = i.isEven ? outer : inner;
      final a = -math.pi / 2 + i * math.pi / n;
      pts
        ..add(cx + r * math.cos(a))
        ..add(cy + r * math.sin(a));
    }
    return pts;
  }

  static void _sparkle(Canvas canvas, Paint p, double cx, double cy, double r, Color c) {
    p.color = c;
    final path = Path();
    final pts = _starPoints(cx, cy, r, r * 0.35, 4);
    path.moveTo(pts[0], pts[1]);
    for (var i = 2; i < pts.length; i += 2) {
      path.lineTo(pts[i], pts[i + 1]);
    }
    canvas.drawPath(path..close(), p);
  }

  @override
  bool shouldRepaint(LetterPicturePainter old) => old.picture != picture;
}
