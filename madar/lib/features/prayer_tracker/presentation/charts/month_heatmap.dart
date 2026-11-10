import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../../core/design/tokens.dart';
import '../../domain/tracker_days.dart';
import '../../domain/tracker_stats.dart';
import '../tracker_actions.dart';

/// One day of the heatmap.
@immutable
class HeatCell {
  const HeatCell({
    required this.day,
    required this.label,
    required this.semanticLabel,
    this.completion = 0,
    this.jamaahShare = 0,
    this.jamaah = 0,
    this.missed = 0,
    this.logged = false,
    this.today = false,
    this.future = false,
  });

  final DateTime day;

  /// The day number (digits already localised).
  final String label;
  final String semanticLabel;

  /// Obligatory prayers prayed / 5.
  final double completion;

  /// Share of those in jamaah.
  final double jamaahShare;

  /// Obligatory prayers prayed in jamaah (0..5): one dot each.
  final int jamaah;

  /// Prayers still owed that day.
  final int missed;
  final bool logged;
  final bool today;
  final bool future;

  @override
  bool operator ==(Object other) =>
      other is HeatCell &&
      other.day == day &&
      other.label == label &&
      other.semanticLabel == semanticLabel &&
      other.completion == completion &&
      other.jamaahShare == jamaahShare &&
      other.jamaah == jamaah &&
      other.missed == missed &&
      other.logged == logged &&
      other.today == today &&
      other.future == future;

  @override
  int get hashCode =>
      Object.hash(day, label, semanticLabel, completion, jamaahShare, jamaah, missed, logged, today, future);
}

/// Where the cells of a month grid sit (7 columns, reading direction
/// aware). Pure geometry, shared by the painter and the tap handler.
@immutable
class HeatmapLayout {
  const HeatmapLayout({required this.size, required this.rows, required this.textDirection, this.gap = 6});

  final Size size;
  final int rows;
  final TextDirection textDirection;
  final double gap;

  static const columns = 7;

  double get cell => math.max(0, (size.width - gap * (columns - 1)) / columns);

  /// The height a grid of [rows] needs at [width].
  static double heightFor(double width, int rows, {double gap = 6}) {
    final cell = math.max(0.0, (width - gap * (columns - 1)) / columns);
    return rows * cell + math.max(0, rows - 1) * gap;
  }

  /// Rectangle of the cell at [index] (row-major in reading order).
  Rect rectOf(int index) {
    final row = index ~/ columns;
    final col = index % columns;
    final visualCol = textDirection == TextDirection.rtl ? columns - 1 - col : col;
    final c = cell;
    return Rect.fromLTWH(visualCol * (c + gap), row * (c + gap), c, c);
  }

  /// The tap / screen-reader target of the cell at [index]: its tile plus
  /// half of each gap around it, so the grid has no dead spots between days
  /// and every target is a gap larger than the tile it covers.
  Rect targetOf(int index) => rectOf(index).inflate(gap / 2);

  /// The cell index under [position] (a gap belongs half to each of its
  /// neighbours), or null outside the grid.
  int? indexAt(Offset position) {
    final c = cell;
    if (c <= 0) return null;
    final pitch = c + gap;
    final visualCol = ((position.dx + gap / 2) / pitch).floor();
    final row = ((position.dy + gap / 2) / pitch).floor();
    if (visualCol < 0 || visualCol >= columns || row < 0 || row >= rows) return null;
    final col = textDirection == TextDirection.rtl ? columns - 1 - visualCol : visualCol;
    return row * columns + col;
  }
}

/// A month of prayer days as a grid of tiles: a complete day (all five
/// prayed or made up) glows full gold; a partial day is a muted amber that
/// deepens with the prayers prayed; dots along the bottom count the
/// prayers in jamaah; a small ember marks prayers still owed; today is
/// outlined in the accent.
class MonthHeatmapPainter extends CustomPainter {
  MonthHeatmapPainter({
    required this.cells,
    required this.tokens,
    required this.textDirection,
    required this.textStyle,
    this.gap = 6,
    this.onTap,
    this.reveal = 1,
  });

  /// Row-major, reading order; null = padding.
  final List<HeatCell?> cells;
  final MadarTokens tokens;
  final TextDirection textDirection;
  final TextStyle textStyle;
  final double gap;
  final ValueChanged<DateTime>? onTap;

  /// Entrance (0..1): cells fade and scale in along the reading order.
  final double reveal;

  int get rows => (cells.length / 7).ceil();

  HeatmapLayout layoutFor(Size size) => HeatmapLayout(size: size, rows: rows, textDirection: textDirection, gap: gap);

  @override
  void paint(Canvas canvas, Size size) {
    final layout = layoutFor(size);
    final c = TrackerColors.from(tokens);
    final radius = Radius.circular(math.min(tokens.radiusS, layout.cell * 0.3));
    for (var i = 0; i < cells.length; i++) {
      final cell = cells[i];
      if (cell == null) continue;
      final local = ((reveal * 1.4) - i / math.max(1, cells.length) * 0.4).clamp(0.0, 1.0);
      if (local <= 0) continue;
      var rect = layout.rectOf(i);
      if (local < 1) {
        rect = Rect.fromCenter(
          center: rect.center,
          width: rect.width * (0.85 + 0.15 * local),
          height: rect.height * (0.85 + 0.15 * local),
        );
      }
      final rrect = RRect.fromRectAndRadius(rect, radius);
      final alpha = local;

      // Fill.
      final complete = cell.completion >= 1;
      final Color fill;
      if (cell.future) {
        fill = tokens.glassFill.withValues(alpha: tokens.glassFill.a * 0.5);
      } else if (complete) {
        fill = c.onTime;
      } else if (cell.completion > 0) {
        fill = Color.lerp(tokens.space2, c.onTime, strengthOf(cell.completion))!;
      } else if (cell.logged) {
        fill = Color.lerp(tokens.space2, c.missed, 0.22)!;
      } else {
        fill = tokens.isDark ? tokens.space2.withValues(alpha: 0.55) : tokens.space3.withValues(alpha: 0.45);
      }
      if (complete && tokens.isDark) {
        canvas.drawRRect(
          rrect.inflate(1),
          Paint()
            ..color = c.onTime.withValues(alpha: 0.35 * alpha)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
      }
      canvas.drawRRect(rrect, Paint()..color = fill.withValues(alpha: fill.a * alpha));
      canvas.drawRRect(
        rrect.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = (cell.future ? tokens.glassBorder : tokens.glassHighlight).withValues(alpha: 0.35 * alpha),
      );

      // Ink (numbers, dots) that reads on this fill: the darkest or the
      // lightest of the theme's ink colours, whichever contrasts more.
      final onGold = !cell.future && cell.completion > 0 && _contrastsWithDark(fill, tokens);
      if (cell.jamaah > 0 && !cell.future) {
        final r = math.max(1.4, rect.shortestSide * 0.042);
        final step = r * 3;
        final n = cell.jamaah.clamp(0, 5);
        final y = rect.bottom - rect.height * 0.16;
        final dotColor = onGold ? _inkOn(fill, tokens).withValues(alpha: 0.7) : c.jamaah;
        for (var k = 0; k < n; k++) {
          final x = rect.center.dx + (k - (n - 1) / 2) * step;
          canvas.drawCircle(Offset(x, y), r, Paint()..color = dotColor.withValues(alpha: dotColor.a * alpha));
        }
      }

      // Day number.
      final strong = onGold && !cell.future;
      final color = cell.future
          ? tokens.textTertiary.withValues(alpha: 0.6)
          : strong
          ? _inkOn(fill, tokens)
          : cell.logged
          ? tokens.textPrimary
          : tokens.textSecondary;
      final tp = TextPainter(
        text: TextSpan(
          text: cell.label,
          style: textStyle.copyWith(
            color: color.withValues(alpha: color.a * alpha),
            fontSize: math.min(textStyle.fontSize ?? 12, rect.shortestSide * 0.36),
            fontWeight: cell.today || strong ? FontWeight.w700 : FontWeight.w500,
            height: 1,
          ),
        ),
        textDirection: textDirection,
        maxLines: 1,
      )..layout(maxWidth: rect.width);
      tp.paint(canvas, rect.center - Offset(tp.width / 2, tp.height / 2 + (cell.jamaah > 0 ? rect.height * 0.05 : 0)));
      tp.dispose();

      // Ember: prayers still owed.
      if (cell.missed > 0 && !cell.future) {
        final corner = textDirection == TextDirection.rtl ? rect.topLeft : rect.topRight;
        final dx = textDirection == TextDirection.rtl ? 1.0 : -1.0;
        final dot = corner + Offset(dx * rect.width * 0.17, rect.height * 0.17);
        canvas.drawCircle(
          dot,
          math.max(2, rect.shortestSide * 0.075),
          Paint()..color = c.missed.withValues(alpha: alpha),
        );
      }

      // Today.
      if (cell.today) {
        canvas.drawRRect(
          rrect.inflate(1.5),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = tokens.accent.withValues(alpha: alpha),
        );
      }
    }
  }

  /// Whether ink on [fill] should differ from the page's primary text (the
  /// fill has moved far enough toward gold that textPrimary no longer
  /// reads on it).
  static bool _contrastsWithDark(Color fill, MadarTokens t) {
    final page = _contrast(t.textPrimary, fill);
    final other = _contrast(_inkOn(fill, t), fill);
    return other > page;
  }

  /// The more legible of the theme's darkest and lightest inks on [fill].
  static Color _inkOn(Color fill, MadarTokens t) {
    final dark = t.isDark ? t.space0 : t.textPrimary;
    final light = t.isDark ? t.textPrimary : t.space0;
    return _contrast(dark, fill) >= _contrast(light, fill) ? dark : light;
  }

  static double _contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  /// How far a partial day's fill moves toward gold (a complete day is
  /// full gold; 4 of 5 stays clearly short of it).
  static double strengthOf(double completion) => completion >= 1 ? 1 : 0.14 + 0.5 * completion.clamp(0.0, 1.0);

  @override
  SemanticsBuilderCallback get semanticsBuilder => (size) {
    final layout = layoutFor(size);
    return [
      for (var i = 0; i < cells.length; i++)
        if (cells[i] case final cell?)
          CustomPainterSemantics(
            key: ValueKey<DateTime>(cell.day),
            rect: layout.targetOf(i),
            properties: SemanticsProperties(
              label: cell.semanticLabel,
              textDirection: textDirection,
              button: !cell.future && onTap != null,
              selected: cell.today,
              onTap: cell.future || onTap == null ? null : () => onTap!(cell.day),
            ),
          ),
    ];
  };

  @override
  bool shouldRebuildSemantics(MonthHeatmapPainter oldDelegate) =>
      !_sameCells(oldDelegate.cells, cells) || oldDelegate.textDirection != textDirection;

  @override
  bool shouldRepaint(MonthHeatmapPainter old) =>
      old.tokens != tokens ||
      old.textDirection != textDirection ||
      old.textStyle != textStyle ||
      old.gap != gap ||
      old.reveal != reveal ||
      !_sameCells(old.cells, cells);

  static bool _sameCells(List<HeatCell?> a, List<HeatCell?> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Heat cells of [month] from [history].
  static List<HeatCell?> cellsFor({
    required DateTime month,
    required TrackerHistory history,
    required int firstDayOfWeek,
    required String Function(DateTime day) label,
    required String Function(DateTime day, DaySummary summary) semantics,
  }) {
    final today = history.today;
    return [
      for (final d in MonthGrid.cells(month.year, month.month, firstDayOfWeek: firstDayOfWeek))
        if (d == null)
          null
        else
          () {
            final s = history.dayOf(d);
            return HeatCell(
              day: d,
              label: label(d),
              semanticLabel: semantics(d, s),
              completion: s.completion,
              jamaahShare: s.jamaahShare,
              jamaah: s.jamaah,
              missed: s.missed,
              logged: !s.isEmpty,
              today: TrackerDays.sameDay(d, today),
              future: d.isAfter(today),
            );
          }(),
    ];
  }
}
