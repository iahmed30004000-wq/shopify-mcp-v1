// Model-sheet harness: lays characters and props out on an animator's
// sheet (blue-pencil guides, title block, labels) and paints them with the
// real rig code, so screenshot tests show exactly what the engine draws.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:madar/features/cinema/engine/cinema_engine.dart';

/// One drawing on the sheet.
class SheetCell {
  SheetCell({required this.label, required this.paint, this.guide = true, this.height = 100});

  final String label;

  /// Paints the drawing at the origin (feet / centre) in local units.
  final void Function(Canvas canvas, RigPaintContext ctx) paint;

  /// Draws blue construction guides behind the drawing.
  final bool guide;

  /// Nominal height (local units) used to fit the cell.
  final double height;
}

/// A titled row of cells.
class SheetRow {
  SheetRow(this.title, this.cells, {this.scale, this.era});

  final String title;

  /// Era of this row (default: the sheet's).
  final Era? era;
  final List<SheetCell> cells;

  /// Fixed local → px scale for the row (default: fit).
  final double? scale;
}

/// A model sheet page.
class ModelSheet extends StatelessWidget {
  const ModelSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.rows,
    this.era = Era.rubberHose,
    this.boilFrame = 3,
    this.dark = false,
  });

  final String title;
  final String subtitle;
  final List<SheetRow> rows;
  final Era era;
  final int boilFrame;

  /// Dark sheet (for neon characters).
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: dark ? const Color(0xFF14101E) : const Color(0xFFF1EADB),
      child: SizedBox.expand(child: CustomPaint(painter: _SheetPainter(this))),
    );
  }
}

class _SheetPainter extends CustomPainter {
  _SheetPainter(this.sheet);

  final ModelSheet sheet;

  @override
  void paint(Canvas canvas, Size size) {
    final skin = EraSkins.of(sheet.era);
    final clock = FilmClock(boilFps: 12, projectionFps: skin.grade.projectionFps);
    // Land on a chosen boil frame.
    clock.advance(sheet.boilFrame / 12 + 0.01);
    final ctx = RigPaintContext(skin: skin, clock: clock);
    final ink = sheet.dark ? const Color(0xFFE8E0FF) : const Color(0xFF2A2622);
    final pencil = sheet.dark ? const Color(0x5539C6FF) : const Color(0x664A7FC1);

    // Sheet grid.
    final grid = Paint()
      ..color = pencil.withValues(alpha: 0.12)
      ..strokeWidth = 0.6;
    for (var x = 0.0; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Title block.
    _text(canvas, sheet.title, Offset(size.width / 2, 22), 22, ink, bold: true, center: true);
    _text(canvas, sheet.subtitle, Offset(size.width / 2, 52), 12, ink.withValues(alpha: 0.7), center: true);
    final frame = Paint()
      ..style = PaintingStyle.stroke
      ..color = ink.withValues(alpha: 0.6)
      ..strokeWidth = 1.4;
    canvas.drawRect(Rect.fromLTWH(8, 8, size.width - 16, size.height - 16), frame);
    canvas.drawLine(const Offset(8, 74), Offset(size.width - 8, 74), frame);

    final top = 84.0;
    final rowH = (size.height - top - 16) / sheet.rows.length;
    for (var r = 0; r < sheet.rows.length; r++) {
      final row = sheet.rows[r];
      ctx.skin = EraSkins.of(row.era ?? sheet.era);
      final y0 = top + r * rowH;
      _text(canvas, row.title, Offset(18, y0 + 4), 11, pencil.withValues(alpha: 1), bold: true);
      final n = row.cells.length;
      final cellW = (size.width - 24) / n;
      final maxH = row.cells.fold<double>(1, (m, c) => math.max(m, c.height));
      final scale = row.scale ?? math.min((rowH - 44) / (maxH * 1.12), cellW / (maxH * 0.95));
      final base = y0 + rowH - 26;
      for (var i = 0; i < n; i++) {
        final cell = row.cells[i];
        final cx = 12 + cellW * (i + 0.5);
        if (cell.guide) {
          final g = Paint()
            ..style = PaintingStyle.stroke
            ..color = pencil
            ..strokeWidth = 0.9;
          canvas.drawLine(Offset(cx - cellW * 0.42, base), Offset(cx + cellW * 0.42, base), g);
          canvas.drawLine(Offset(cx, base + 4), Offset(cx, base - cell.height * scale * 1.08), g..strokeWidth = 0.5);
          canvas.drawLine(
            Offset(cx - cellW * 0.2, base - cell.height * scale),
            Offset(cx + cellW * 0.2, base - cell.height * scale),
            g,
          );
        }
        ctx.pixelScale = scale;
        canvas
          ..save()
          ..translate(cx, base)
          ..scale(scale);
        cell.paint(canvas, ctx);
        canvas.restore();
        _text(canvas, cell.label, Offset(cx, base + 6), 10, ink.withValues(alpha: 0.85), center: true);
      }
    }
  }

  void _text(Canvas canvas, String s, Offset at, double size, Color color, {bool bold = false, bool center = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontFamily: 'PlexArabic',
          fontSize: size,
          color: color,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center ? at - Offset(tp.width / 2, 0) : at);
    tp.dispose();
  }

  @override
  bool shouldRepaint(covariant _SheetPainter old) => true;
}

/// Advances [rig] by [seconds] in 60 Hz steps.
void run(RigCharacter rig, double seconds) {
  var t = 0.0;
  while (t < seconds - 1e-9) {
    final dt = math.min(1 / 60, seconds - t);
    rig.update(dt);
    t += dt;
  }
}
