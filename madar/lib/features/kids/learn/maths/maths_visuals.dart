// The pictures that make the sums visible: a dot array (3 x 4 is three rows of
// four), groups for sharing, a pie for fractions. Painters never allocate per
// frame (they only paint when their inputs change).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ui/kids_tokens.dart';

const List<Color> kRowColors = [KidsColors.teal500, KidsColors.sun500, KidsColors.rose500, KidsColors.night500];

/// `rows` rows of `cols` dots, each row in its own colour.
class DotArrayPainter extends CustomPainter {
  const DotArrayPainter({required this.rows, required this.cols});

  final int rows, cols;

  @override
  void paint(Canvas canvas, Size size) {
    if (rows <= 0 || cols <= 0) return;
    final cell = math.min(size.width / cols, size.height / rows);
    final r = cell * 0.40;
    final left = (size.width - cell * cols) / 2, top = (size.height - cell * rows) / 2;
    final p = Paint()..isAntiAlias = true;
    final shine = Paint()..color = const Color(0x66FFFFFF);
    for (var y = 0; y < rows; y++) {
      p.color = kRowColors[y % kRowColors.length];
      for (var x = 0; x < cols; x++) {
        final c = Offset(left + cell * (x + 0.5), top + cell * (y + 0.5));
        canvas
          ..drawCircle(c, r, p)
          ..drawCircle(c.translate(-r * 0.3, -r * 0.3), r * 0.25, shine);
      }
    }
  }

  @override
  bool shouldRepaint(DotArrayPainter old) => old.rows != rows || old.cols != cols;
}

/// `total` dots shared into `groups` boxes (as evenly as they divide); the
/// first [lit] boxes are tinted (used to show "3/4 of 12").
class GroupsPainter extends CustomPainter {
  const GroupsPainter({required this.total, required this.groups, this.lit = 0});

  final int total, groups, lit;

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0 || groups <= 0) return;
    final perRow = groups <= 4 ? groups : (groups + 1) ~/ 2;
    final rowsOfBoxes = (groups / perRow).ceil();
    const gap = 10.0;
    final boxW = (size.width - gap * (perRow - 1)) / perRow;
    final boxH = (size.height - gap * (rowsOfBoxes - 1)) / rowsOfBoxes;
    final each = total ~/ groups;
    final p = Paint()..isAntiAlias = true;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..isAntiAlias = true;
    for (var g = 0; g < groups; g++) {
      final col = g % perRow, row = g ~/ perRow;
      final rect = Rect.fromLTWH(col * (boxW + gap), row * (boxH + gap), boxW, boxH);
      final colour = g < lit ? KidsColors.rose500 : kRowColors[g % kRowColors.length];
      final rr = RRect.fromRectAndRadius(rect, const Radius.circular(14));
      canvas.drawRRect(rr, p..color = colour.withValues(alpha: 0.16));
      canvas.drawRRect(rr, stroke..color = colour);
      // Dots in a small grid inside the box.
      final dc = each <= 3 ? each : (each <= 8 ? 2 : 3);
      final dr = (each / dc).ceil();
      final cell = math.min((rect.width - 10) / dc, (rect.height - 10) / dr);
      final rad = math.min(cell * 0.36, 9.0);
      final ox = rect.left + (rect.width - cell * dc) / 2, oy = rect.top + (rect.height - cell * dr) / 2;
      p.color = colour;
      for (var i = 0; i < each; i++) {
        canvas.drawCircle(Offset(ox + cell * (i % dc + 0.5), oy + cell * (i ~/ dc + 0.5)), rad, p);
      }
    }
  }

  @override
  bool shouldRepaint(GroupsPainter old) => old.total != total || old.groups != groups || old.lit != lit;
}

/// A pie of [den] equal slices, [num] of them coloured.
class PiePainter extends CustomPainter {
  const PiePainter({required this.num, required this.den});

  final int num, den;

  @override
  void paint(Canvas canvas, Size size) {
    if (den <= 0) return;
    final r = size.shortestSide / 2 - 3;
    final c = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: c, radius: r);
    final fill = Paint()..isAntiAlias = true;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round
      ..color = KidsColors.night800
      ..isAntiAlias = true;
    final sweep = 2 * math.pi / den;
    for (var i = 0; i < den; i++) {
      // Slices run clockwise from the top.
      fill.color = i < num ? KidsColors.rose500 : Colors.white;
      canvas.drawArc(rect, -math.pi / 2 + i * sweep, sweep, true, fill);
    }
    canvas.drawCircle(c, r, line);
    if (den > 1) {
      for (var i = 0; i < den; i++) {
        final a = -math.pi / 2 + i * sweep;
        canvas.drawLine(c, c + Offset(math.cos(a), math.sin(a)) * r, line);
      }
    }
  }

  @override
  bool shouldRepaint(PiePainter old) => old.num != num || old.den != den;
}

/// A fraction written as numerator over a line over denominator.
class FractionStack extends StatelessWidget {
  const FractionStack({
    super.key,
    required this.num,
    required this.den,
    this.size = 40,
    this.color = KidsColors.night900,
  });

  /// Already localised digits.
  final String num, den;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = KidsType.title(size, color: color).copyWith(height: 1.05);
    final w = math.max(num.length, den.length) * size * 0.62 + 10;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(num, style: style),
          Container(
            width: w,
            height: size * 0.09,
            margin: EdgeInsets.symmetric(vertical: size * 0.05),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
          ),
          Text(den, style: style),
        ],
      ),
    );
  }
}
