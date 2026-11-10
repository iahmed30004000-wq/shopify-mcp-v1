// Illustrations for steps and stories: places, light and objects only.
//
// The widget takes a list of [KidsArt]; that enum is the closed allow-list in
// domain/kids_art.dart and has no value for a person, so a face or a figure
// (of a prophet or a companion) cannot be requested, let alone drawn. The
// painter reuses two Paint objects and allocates no objects of its own per
// frame (it is static: it repaints only when the list changes).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/kids_art.dart';
import 'kids_faith_ui.dart';

class KidsSceneArt extends StatelessWidget {
  const KidsSceneArt({super.key, required this.art, this.height = 260, this.radius = 32, this.dayTone = false});

  final List<KidsArt> art;
  final double height;
  final double radius;

  /// A teal daylight sky (steps) instead of the indigo night (stories).
  final bool dayTone;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: KidsScenePainter(Set.unmodifiable(art), dayTone)),
      ),
    ),
  );
}

class KidsScenePainter extends CustomPainter {
  KidsScenePainter(this.art, this.dayTone);

  final Set<KidsArt> art;
  final bool dayTone;

  static final Paint _fill = Paint()..isAntiAlias = true;
  static final Paint _line = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  Paint _f(Color c) => _fill..color = c;
  Paint _l(Color c, double w) => _line
    ..color = c
    ..strokeWidth = w;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final sky = dayTone ? const [KP.teal700, KP.teal500] : const [KP.night900, Color(0xFF6A3F8C)];
    canvas.drawRect(
      Offset.zero & s,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: sky,
        ).createShader(Offset.zero & s),
    );
    bool has(KidsArt a) => art.contains(a);

    if (has(KidsArt.stars)) {
      for (var i = 0; i < 26; i++) {
        final x = (i * 0.6180339 % 1) * w;
        final y = ((i * 0.3819660 + 0.11) % 1) * h * 0.55;
        canvas.drawCircle(Offset(x, y), 1.2 + (i % 3) * 0.8, _f(Colors.white.withValues(alpha: 0.75)));
      }
    }
    if (has(KidsArt.moon)) {
      canvas.drawCircle(Offset(w * 0.78, h * 0.2), 30, _f(KP.sun100));
      canvas.drawCircle(Offset(w * 0.78 + 12, h * 0.2 - 6), 26, _f(dayTone ? KP.teal700 : KP.night800));
    }
    if (has(KidsArt.sun)) {
      canvas.drawCircle(Offset(w * 0.78, h * 0.22), 46, _f(KP.sun300.withValues(alpha: 0.35)));
      canvas.drawCircle(Offset(w * 0.78, h * 0.22), 28, _f(KP.sun500));
    }
    if (has(KidsArt.cloud)) {
      for (final o in const [Offset(0.2, 0.18), Offset(0.28, 0.15), Offset(0.35, 0.19)]) {
        canvas.drawCircle(Offset(w * o.dx, h * o.dy), 22, _f(Colors.white.withValues(alpha: 0.8)));
      }
    }
    if (has(KidsArt.lightColumn)) {
      final x = w / 2;
      final p = Path()
        ..moveTo(x - 18, h * 0.12)
        ..lineTo(x + 18, h * 0.12)
        ..lineTo(x + 46, h * 0.78)
        ..lineTo(x - 46, h * 0.78)
        ..close();
      canvas.drawPath(
        p,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [KP.sun300.withValues(alpha: 0.85), KP.sun300.withValues(alpha: 0)],
          ).createShader(Offset.zero & s),
      );
      canvas.drawCircle(Offset(x, h * 0.12), 22, _f(KP.sun100));
    }
    if (has(KidsArt.mountain)) {
      final p = Path()
        ..moveTo(0, h * 0.78)
        ..lineTo(w * 0.28, h * 0.38)
        ..lineTo(w * 0.5, h * 0.66)
        ..lineTo(w * 0.72, h * 0.3)
        ..lineTo(w, h * 0.78)
        ..close();
      canvas.drawPath(p, _f(KP.night700));
    }
    if (has(KidsArt.sea) || has(KidsArt.ship)) {
      canvas.drawRect(Rect.fromLTWH(0, h * 0.7, w, h * 0.3), _f(KP.teal700));
      for (var i = 0; i < 4; i++) {
        final y = h * (0.76 + i * 0.06);
        final p = Path()..moveTo(0, y);
        for (var x = 0.0; x < w; x += 40) {
          p.quadraticBezierTo(x + 10, y - 6, x + 20, y);
          p.quadraticBezierTo(x + 30, y + 6, x + 40, y);
        }
        canvas.drawPath(p, _l(KP.teal200.withValues(alpha: 0.7), 2));
      }
    }
    if (has(KidsArt.ship)) {
      final p = Path()
        ..moveTo(w * 0.34, h * 0.68)
        ..lineTo(w * 0.66, h * 0.68)
        ..lineTo(w * 0.6, h * 0.78)
        ..lineTo(w * 0.4, h * 0.78)
        ..close();
      canvas.drawPath(p, _f(KP.sand2));
      canvas.drawLine(Offset(w / 2, h * 0.68), Offset(w / 2, h * 0.4), _l(KP.sand2, 4));
      canvas.drawPath(
        Path()
          ..moveTo(w / 2, h * 0.42)
          ..lineTo(w * 0.62, h * 0.64)
          ..lineTo(w / 2, h * 0.64)
          ..close(),
        _f(KP.paper),
      );
    }
    if (has(KidsArt.dunes)) {
      canvas.drawPath(_dune(w, h, 0.66, 0.08), _f(KP.rose700));
      canvas.drawPath(_dune(w, h, 0.8, -0.06), _f(const Color(0xFF5A2455)));
    }
    if (has(KidsArt.path)) {
      final p = Path()
        ..moveTo(w * 0.46, h * 0.62)
        ..lineTo(w * 0.54, h * 0.62)
        ..lineTo(w * 0.8, h)
        ..lineTo(w * 0.2, h)
        ..close();
      canvas.drawPath(p, _f(KP.sun100.withValues(alpha: 0.75)));
    }
    if (has(KidsArt.palm)) _palm(canvas, Offset(w * 0.16, h * 0.7), h * 0.42);
    if (has(KidsArt.tree)) {
      canvas.drawLine(Offset(w * 0.8, h * 0.82), Offset(w * 0.8, h * 0.58), _l(const Color(0xFF5A3A2A), 8));
      canvas.drawCircle(Offset(w * 0.8, h * 0.5), 34, _f(KP.teal500));
      canvas.drawCircle(Offset(w * 0.74, h * 0.56), 24, _f(KP.teal700));
    }
    if (has(KidsArt.cave)) {
      canvas.drawPath(
        Path()
          ..moveTo(w * 0.62, h * 0.8)
          ..quadraticBezierTo(w * 0.7, h * 0.46, w * 0.84, h * 0.8)
          ..close(),
        _f(KP.night900),
      );
    }
    if (has(KidsArt.tent)) {
      canvas.drawPath(
        Path()
          ..moveTo(w * 0.62, h * 0.8)
          ..lineTo(w * 0.72, h * 0.56)
          ..lineTo(w * 0.82, h * 0.8)
          ..close(),
        _f(KP.sand),
      );
    }
    if (has(KidsArt.well)) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.4, h * 0.66, w * 0.2, h * 0.14), const Radius.circular(8)),
        _f(KP.sand2),
      );
      canvas.drawOval(Rect.fromLTWH(w * 0.4, h * 0.62, w * 0.2, h * 0.08), _f(KP.night900));
    }
    if (has(KidsArt.stone)) {
      canvas.drawOval(Rect.fromLTWH(w * 0.1, h * 0.8, 58, 26), _f(KP.night800));
      canvas.drawOval(Rect.fromLTWH(w * 0.2, h * 0.85, 34, 16), _f(KP.night800));
    }
    if (has(KidsArt.water)) {
      for (var i = 0; i < 2; i++) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(w / 2, h * (0.86 - i * 0.03)),
            width: w * (0.62 - i * 0.14),
            height: 26 - i * 8,
          ),
          _l(KP.teal200, 2),
        );
      }
      final jet = RRect.fromRectAndRadius(Rect.fromLTWH(w / 2 - 12, h * 0.28, 24, h * 0.5), const Radius.circular(12));
      canvas.drawRRect(jet, _f(KP.teal200.withValues(alpha: 0.9)));
    }
    if (has(KidsArt.drops) || has(KidsArt.rain)) {
      final n = has(KidsArt.rain) ? 14 : 5;
      for (var i = 0; i < n; i++) {
        _drop(canvas, Offset(w * ((i * 0.37 + 0.1) % 0.9 + 0.05), h * ((i * 0.23 + 0.2) % 0.6 + 0.2)), 9);
      }
    }
    if (has(KidsArt.lantern)) {
      final c = Offset(w * 0.86, h * 0.72);
      canvas.drawCircle(c, 34, _f(KP.sun300.withValues(alpha: 0.28)));
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: 28, height: 42), const Radius.circular(8)),
        _f(KP.sun500),
      );
      canvas.drawLine(c + const Offset(0, -21), c + const Offset(0, -32), _l(KP.night900, 3));
      canvas.drawRect(Rect.fromCenter(center: c + const Offset(0, 24), width: 20, height: 6), _f(KP.night900));
    }
    if (has(KidsArt.khatam)) {
      final c = Offset(w / 2, h * 0.16);
      for (var k = 0; k < 2; k++) {
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(k * math.pi / 4);
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: 44, height: 44), _f(KP.sun300));
        canvas.restore();
      }
    }
  }

  Path _dune(double w, double h, double y, double lean) => Path()
    ..moveTo(0, h * (y + lean))
    ..cubicTo(w * 0.3, h * (y - 0.1), w * 0.6, h * (y + 0.1), w, h * (y - lean))
    ..lineTo(w, h)
    ..lineTo(0, h)
    ..close();

  void _palm(Canvas canvas, Offset base, double height) {
    final top = base + Offset(6, -height);
    canvas.drawLine(base, top, _l(KP.night900, 7));
    for (var i = 0; i < 5; i++) {
      final a = -math.pi * (0.1 + i * 0.2);
      final tip = top + Offset(math.cos(a) * 46, math.sin(a) * 30 + 14);
      canvas.drawPath(
        Path()
          ..moveTo(top.dx, top.dy)
          ..quadraticBezierTo(top.dx + math.cos(a) * 26, top.dy - 22, tip.dx, tip.dy),
        _l(KP.night900, 5),
      );
    }
  }

  void _drop(Canvas canvas, Offset c, double r) {
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy - r * 1.6)
        ..quadraticBezierTo(c.dx + r * 1.2, c.dy, c.dx, c.dy + r)
        ..quadraticBezierTo(c.dx - r * 1.2, c.dy, c.dx, c.dy - r * 1.6),
      _f(KP.teal100),
    );
  }

  @override
  bool shouldRepaint(KidsScenePainter old) => old.dayTone != dayTone || !_same(old.art, art);

  bool _same(Set<KidsArt> a, Set<KidsArt> b) => a.length == b.length && a.containsAll(b);
}
