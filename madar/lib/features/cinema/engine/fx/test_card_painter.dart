import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// An original calibration card (drawn in code) for judging a film look:
/// grey step wedge and ramp, colour bars, memory colours (skin, sky,
/// foliage, sunset), fine gratings, a lit sphere, a bright lamp (bloom and
/// halation), ink line work and a cartoon face, plus bilingual labels.
///
/// Used by the FX screenshot tests and handy as an in-app "projector check"
/// card. Text is passed in already localised.
class FilmTestCardPainter {
  FilmTestCardPainter({required this.title, required this.subtitle, this.caption, this.direction = TextDirection.rtl});

  final String title;
  final String subtitle;
  final String? caption;
  final TextDirection direction;

  final Paint _fill = Paint();
  final Paint _stroke = Paint()..style = PaintingStyle.stroke;
  final Path _path = Path();

  static const _bars = [
    Color(0xFFBFBFBF),
    Color(0xFFBFBF00),
    Color(0xFF00BFBF),
    Color(0xFF00BF00),
    Color(0xFFBF00BF),
    Color(0xFFBF0000),
    Color(0xFF0000BF),
    Color(0xFF101010),
  ];

  static const _memory = [
    Color(0xFFE8B996), // skin light
    Color(0xFFA86B48), // skin deep
    Color(0xFF6FA8DC), // sky
    Color(0xFF4F7F3A), // foliage
    Color(0xFFF08A24), // sunset
    Color(0xFFC8102E), // lipstick red
  ];

  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final ink = const Color(0xFF111111);
    // Field and grid.
    _fill
      ..shader = null
      ..color = const Color(0xFF7F7F7F);
    canvas.drawRect(Offset.zero & size, _fill);
    _stroke
      ..color = const Color(0xFFD8D8D8)
      ..strokeWidth = 1;
    final cell = w / 10;
    for (var x = cell; x < w; x += cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), _stroke);
    }
    for (var y = cell; y < h; y += cell) {
      canvas.drawLine(Offset(0, y), Offset(w, y), _stroke);
    }

    // Titles.
    _text(canvas, title, Offset(w / 2, h * 0.05), w * 0.075, const Color(0xFFF5F0E6), 'Amiri', FontWeight.w700);
    _text(canvas, subtitle, Offset(w / 2, h * 0.105), w * 0.04, const Color(0xFFF5F0E6), 'PlexArabic', FontWeight.w600, spacing: 3);

    // The big circle.
    final c = Offset(w / 2, h * 0.43);
    final r = w * 0.44;
    canvas.save();
    canvas.clipPath(_path
      ..reset()
      ..addOval(Rect.fromCircle(center: c, radius: r)));
    // Colour bars across the top of the circle.
    final barTop = c.dy - r;
    final barH = r * 0.5;
    final bw = 2 * r / _bars.length;
    for (var i = 0; i < _bars.length; i++) {
      _fill.color = _bars[i];
      canvas.drawRect(Rect.fromLTWH(c.dx - r + i * bw, barTop, bw + 0.5, barH), _fill);
    }
    // Sky-to-ground scene band with the lit sphere and a lamp.
    final band = Rect.fromLTWH(c.dx - r, barTop + barH, 2 * r, r * 0.95);
    _fill.shader = ui.Gradient.linear(band.topCenter, band.bottomCenter, const [
      Color(0xFF3E6FB0),
      Color(0xFF9CC7EA),
      Color(0xFFF2D5A0),
    ], const [0, 0.62, 1]);
    canvas.drawRect(band, _fill);
    _fill.shader = null;
    // Hills.
    _path
      ..reset()
      ..moveTo(band.left, band.bottom)
      ..lineTo(band.left, band.bottom - r * 0.25)
      ..quadraticBezierTo(band.center.dx - r * 0.3, band.bottom - r * 0.55, band.center.dx + r * 0.1, band.bottom - r * 0.28)
      ..quadraticBezierTo(band.right - r * 0.3, band.bottom - r * 0.1, band.right, band.bottom - r * 0.3)
      ..lineTo(band.right, band.bottom)
      ..close();
    _fill.color = const Color(0xFF4F7F3A);
    canvas.drawPath(_path, _fill);
    _stroke
      ..color = ink
      ..strokeWidth = 2.5;
    canvas.drawPath(_path, _stroke);
    // Lit sphere.
    final sphere = Offset(band.left + r * 0.55, band.top + r * 0.42);
    final sr = r * 0.26;
    _fill.shader = ui.Gradient.radial(sphere + Offset(-sr * 0.35, -sr * 0.4), sr * 1.3, const [
      Color(0xFFFFF4E0),
      Color(0xFFE0703A),
      Color(0xFF5A1A0A),
    ], const [0, 0.45, 1]);
    canvas.drawCircle(sphere, sr, _fill);
    _fill.shader = null;
    canvas.drawCircle(sphere, sr, _stroke);
    // A bright lamp for bloom / halation.
    final lamp = Offset(band.right - r * 0.45, band.top + r * 0.3);
    _fill.color = const Color(0xFFFFFFFF);
    canvas.drawCircle(lamp, r * 0.07, _fill);
    _fill.color = const Color(0xFFFFF6D8);
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      canvas.drawLine(
        lamp + Offset(math.cos(a), math.sin(a)) * r * 0.1,
        lamp + Offset(math.cos(a), math.sin(a)) * r * 0.17,
        _stroke
          ..color = const Color(0xFFFFFFFF)
          ..strokeWidth = 3,
      );
    }
    // Grey step wedge.
    final wedgeTop = band.bottom;
    final wedgeH = r * 0.32;
    for (var i = 0; i < 11; i++) {
      final v = (i * 25.5).round();
      _fill.color = Color.fromARGB(255, v, v, v);
      canvas.drawRect(Rect.fromLTWH(c.dx - r + i * 2 * r / 11, wedgeTop, 2 * r / 11 + 0.5, wedgeH), _fill);
    }
    // Continuous ramp.
    final ramp = Rect.fromLTWH(c.dx - r, wedgeTop + wedgeH, 2 * r, r * 0.16);
    _fill.shader = ui.Gradient.linear(ramp.centerLeft, ramp.centerRight, const [Color(0xFF000000), Color(0xFFFFFFFF)]);
    canvas.drawRect(ramp, _fill);
    _fill.shader = null;
    // Gratings.
    final grid = Rect.fromLTWH(c.dx - r, ramp.bottom, 2 * r, c.dy + r - ramp.bottom);
    _fill.color = const Color(0xFFF0F0F0);
    canvas.drawRect(grid, _fill);
    _fill.color = ink;
    var x = grid.left + r * 0.35;
    for (final pitch in [8.0, 5.0, 3.0, 2.0]) {
      for (var k = 0; k < 7; k++) {
        canvas.drawRect(Rect.fromLTWH(x, grid.top + 4, pitch / 2, grid.height - 8), _fill);
        x += pitch;
      }
      x += 10;
    }
    canvas.restore();
    _stroke
      ..color = ink
      ..strokeWidth = 3;
    canvas.drawCircle(c, r, _stroke);
    _stroke
      ..color = const Color(0xFFF0F0F0)
      ..strokeWidth = 1.5;
    canvas.drawCircle(c, r + 5, _stroke);

    // Memory colours.
    final sw = w * 0.8 / _memory.length;
    final sy = c.dy + r + h * 0.03;
    for (var i = 0; i < _memory.length; i++) {
      final rect = Rect.fromLTWH(w * 0.1 + i * sw + 3, sy, sw - 6, h * 0.05);
      _fill.color = _memory[i];
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), _fill);
      _stroke
        ..color = ink
        ..strokeWidth = 2;
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), _stroke);
    }

    // A cartoon face (original bean character) for ink line work.
    _face(canvas, Offset(w / 2, sy + h * 0.17), w * 0.14);

    // Corner registration marks.
    for (final p in [
      Offset(w * 0.08, h * 0.16),
      Offset(w * 0.92, h * 0.16),
      Offset(w * 0.08, h * 0.94),
      Offset(w * 0.92, h * 0.94),
    ]) {
      _stroke
        ..color = const Color(0xFFF0F0F0)
        ..strokeWidth = 1.5;
      canvas
        ..drawCircle(p, 12, _stroke)
        ..drawLine(p - const Offset(18, 0), p + const Offset(18, 0), _stroke)
        ..drawLine(p - const Offset(0, 18), p + const Offset(0, 18), _stroke);
    }
    if (caption != null) {
      _text(canvas, caption!, Offset(w / 2, h * 0.955), w * 0.04, const Color(0xFFF5F0E6), 'PlexArabic', FontWeight.w500);
    }
  }

  void _face(Canvas canvas, Offset c, double s) {
    const ink = Color(0xFF111111);
    final body = Rect.fromCenter(center: c, width: s * 1.6, height: s * 1.9);
    _fill.color = const Color(0xFFF7F1E3);
    canvas.drawOval(body, _fill);
    _stroke
      ..color = ink
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawOval(body, _stroke);
    // Pie-cut eyes.
    for (final dx in [-0.28, 0.28]) {
      final e = Rect.fromCenter(center: c + Offset(dx * s, -s * 0.25), width: s * 0.36, height: s * 0.55);
      _fill.color = const Color(0xFFFFFFFF);
      canvas.drawOval(e, _fill);
      canvas.drawOval(e, _stroke..strokeWidth = 2.5);
      final pupil = Rect.fromCenter(center: e.center + Offset(0, s * 0.06), width: s * 0.22, height: s * 0.36);
      _fill.color = ink;
      canvas.drawArc(pupil, -math.pi / 2 + 0.5, 2 * math.pi - 1.0, true, _fill);
    }
    // Grin and cheeks.
    _path
      ..reset()
      ..moveTo(c.dx - s * 0.45, c.dy + s * 0.2)
      ..quadraticBezierTo(c.dx, c.dy + s * 0.75, c.dx + s * 0.45, c.dy + s * 0.2);
    canvas.drawPath(_path, _stroke..strokeWidth = 3.5);
    _fill.color = const Color(0xFFE88A8A);
    canvas
      ..drawCircle(c + Offset(-s * 0.55, s * 0.25), s * 0.1, _fill)
      ..drawCircle(c + Offset(s * 0.55, s * 0.25), s * 0.1, _fill);
  }

  void _text(Canvas canvas, String text, Offset centre, double size, Color color, String family, FontWeight weight, {double spacing = 0}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontFamily: family, fontSize: size, fontWeight: weight, color: color, letterSpacing: spacing, height: 1.2),
      ),
      textDirection: direction,
      textAlign: TextAlign.center,
    )..layout();
    tp.paint(canvas, centre - Offset(tp.width / 2, tp.height / 2));
    tp.dispose();
  }
}
