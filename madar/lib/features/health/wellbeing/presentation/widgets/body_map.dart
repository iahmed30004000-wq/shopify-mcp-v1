import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../../core/design/tokens.dart';
import '../../../../../core/motion/motion_kit.dart';
import '../../../../../core/sound/sound_api.dart';
import '../../domain/body_map.dart';
import 'wb_palette.dart';

/// Colours of a body-map drawing.
@immutable
class BodyMapColors {
  const BodyMapColors({
    required this.fillTop,
    required this.fillBottom,
    required this.outline,
    required this.guide,
    required this.glow,
  });

  factory BodyMapColors.of(MadarTokens t) => BodyMapColors(
    fillTop: Color.lerp(t.glassFill, t.accentSoft, 0.55)!.withValues(alpha: t.isDark ? 0.55 : 0.75),
    fillBottom: Color.lerp(t.glassFill, t.accent, 0.08)!.withValues(alpha: t.isDark ? 0.3 : 0.5),
    outline: t.metalBrass.withValues(alpha: t.isDark ? 0.75 : 0.85),
    guide: t.metalBrass.withValues(alpha: 0.32),
    glow: t.accentGlow.withValues(alpha: t.isDark ? 0.22 : 0.12),
  );

  final Color fillTop;
  final Color fillBottom;
  final Color outline;
  final Color guide;
  final Color glow;

  @override
  bool operator ==(Object other) =>
      other is BodyMapColors &&
      other.fillTop == fillTop &&
      other.fillBottom == fillBottom &&
      other.outline == outline &&
      other.guide == guide &&
      other.glow == glow;

  @override
  int get hashCode => Object.hash(fillTop, fillBottom, outline, guide, glow);
}

/// A marker drawn on the figure.
@immutable
class BodyMark {
  const BodyMark(this.point, this.color, {this.radius = 7, this.pulse = 0});

  final BodyPoint point;
  final Color color;
  final double radius;

  /// 0–1 extra glow (a freshly dropped point).
  final double pulse;
}

/// Paints Madar's original gender-neutral silhouette ([BodyFigure]) seen
/// from the [side], with heat spots and markers. The figure keeps a 1 × 2
/// box centred in the canvas.
class BodyMapPainter extends CustomPainter {
  BodyMapPainter({
    required this.side,
    required this.colors,
    this.marks = const [],
    this.heat = const [],
    this.heatColor,
    this.maxHeatCount = 1,
  });

  final BodySide side;
  final BodyMapColors colors;
  final List<BodyMark> marks;
  final List<HeatSpot> heat;
  final Color Function(double meanScore)? heatColor;
  final int maxHeatCount;

  static Path? _cachedFigure;

  /// Path units per figure width. The outline is built at this scale: path
  /// operations lose precision on unit-sized geometry.
  static const double units = 1000;

  /// The figure's outline in [units] (x 0–1000, y 0–2000).
  static Path figurePath() => _cachedFigure ??= _buildFigure();

  static Path _buildFigure() {
    final up = Matrix4.diagonal3Values(units, units, 1).storage;
    Path? union;
    for (final s in BodyFigure.shapes) {
      final p = _shapePath(s).transform(up);
      union = union == null ? p : Path.combine(PathOperation.union, union, p);
    }
    return union!;
  }

  static Path _shapePath(BodyShape s) {
    const a = BodyFigure.aspect;
    switch (s.kind) {
      case BodyShapeKind.ellipse:
        return Path()..addOval(Rect.fromCenter(center: Offset(s.cx, s.cy * a), width: s.rx * 2, height: s.ry * a * 2));
      case BodyShapeKind.limb:
        final p1 = Offset(s.cx, s.cy * a);
        final p2 = Offset(s.x2, s.y2 * a);
        final d = p2 - p1;
        final len = d.distance;
        final n = Offset(-d.dy / len, d.dx / len);
        final quad = Path()
          ..moveTo(p1.dx + n.dx * s.rx, p1.dy + n.dy * s.rx)
          ..lineTo(p2.dx + n.dx * s.r2, p2.dy + n.dy * s.r2)
          ..lineTo(p2.dx - n.dx * s.r2, p2.dy - n.dy * s.r2)
          ..lineTo(p1.dx - n.dx * s.rx, p1.dy - n.dy * s.rx)
          ..close();
        // Separate unions, so the parts' windings can never cancel out.
        final withStart = Path.combine(
          PathOperation.union,
          quad,
          Path()..addOval(Rect.fromCircle(center: p1, radius: s.rx)),
        );
        return Path.combine(PathOperation.union, withStart, Path()..addOval(Rect.fromCircle(center: p2, radius: s.r2)));
      case BodyShapeKind.trunk:
        final top = s.cy * a, bottom = s.y2 * a, mid = (top + bottom) / 2;
        final path = Path()
          ..moveTo(0.5 - s.rx, top + 0.02)
          ..quadraticBezierTo(0.5 - s.rx, top, 0.5 - s.rx + 0.04, top)
          ..lineTo(0.5 + s.rx - 0.04, top)
          ..quadraticBezierTo(0.5 + s.rx, top, 0.5 + s.rx, top + 0.02)
          ..quadraticBezierTo(0.5 + s.ry - 0.012, mid, 0.5 + s.r2, bottom - 0.03)
          ..quadraticBezierTo(0.5 + s.r2 + 0.004, bottom, 0.5 + s.r2 - 0.03, bottom)
          ..lineTo(0.5 - s.r2 + 0.03, bottom)
          ..quadraticBezierTo(0.5 - s.r2 - 0.004, bottom, 0.5 - s.r2, bottom - 0.03)
          ..quadraticBezierTo(0.5 - s.ry + 0.012, mid, 0.5 - s.rx, top + 0.02)
          ..close();
        return path;
    }
  }

  /// The rectangle the figure occupies inside [size].
  static Rect figureRect(Size size) {
    final h = math.min(size.height, size.width * BodyFigure.aspect);
    final w = h / BodyFigure.aspect;
    return Rect.fromCenter(center: size.center(Offset.zero), width: w, height: h);
  }

  /// Canvas position of a normalised point.
  static Offset toCanvas(Size size, double x, double y) {
    final r = figureRect(size);
    return Offset(r.left + x * r.width, r.top + y * r.height);
  }

  /// Normalised position of a canvas point (may fall outside 0–1).
  static Offset toFigure(Size size, Offset p) {
    final r = figureRect(size);
    return Offset((p.dx - r.left) / r.width, (p.dy - r.top) / r.height);
  }

  /// Whether a normalised point is on the silhouette (with a small margin).
  static bool hits(double x, double y) {
    final p = Offset(x, y * BodyFigure.aspect) * units;
    if (figurePath().contains(p)) return true;
    for (final d in const [Offset(20, 0), Offset(-20, 0), Offset(0, 20), Offset(0, -20)]) {
      if (figurePath().contains(p + d)) return true;
    }
    return false;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final r = figureRect(size);
    final scale = r.width;
    final m = Matrix4.identity()
      ..translateByDouble(r.left, r.top, 0, 1)
      ..scaleByDouble(scale / units, scale / units, 1, 1);
    final figure = figurePath().transform(m.storage);

    // Halo.
    canvas.drawOval(
      Rect.fromCenter(center: r.center, width: r.width * 1.25, height: r.height * 0.95),
      Paint()
        ..shader = RadialGradient(colors: [colors.glow, colors.glow.withValues(alpha: 0)])
            .createShader(Rect.fromCenter(center: r.center, width: r.width * 1.25, height: r.height * 0.95)),
    );

    // Body.
    canvas.drawPath(
      figure,
      Paint()..shader = ui.Gradient.linear(r.topCenter, r.bottomCenter, [colors.fillTop, colors.fillBottom]),
    );

    // Heat (clipped to the figure, soft radial blooms).
    if (heat.isNotEmpty) {
      canvas.save();
      canvas.clipPath(figure);
      for (final h in heat) {
        if (h.side != side) continue;
        final c = toCanvas(size, h.x, h.y);
        final weight = (h.count / math.max(1, maxHeatCount)).clamp(0.0, 1.0);
        final radius = scale * (0.075 + 0.085 * math.sqrt(weight));
        final col = heatColor?.call(h.meanScore) ?? colors.outline;
        canvas.drawCircle(
          c,
          radius,
          Paint()
            ..shader = RadialGradient(
              colors: [
                col.withValues(alpha: 0.7 + 0.25 * weight),
                col.withValues(alpha: 0.35 + 0.25 * weight),
                col.withValues(alpha: 0),
              ],
              stops: const [0, 0.45, 1],
            ).createShader(Rect.fromCircle(center: c, radius: radius)),
        );
      }
      canvas.restore();
    }

    // Guides: collarbones on the front, spine and shoulder blades on the back.
    final guide = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, scale * 0.006)
      ..strokeCap = StrokeCap.round
      ..color = colors.guide;
    Offset at(double x, double y) => toCanvas(size, x, y);
    if (side == BodySide.front) {
      for (final sx in [-1.0, 1.0]) {
        canvas.drawPath(
          Path()
            ..moveTo(at(0.5 + sx * 0.035, 0.185).dx, at(0.5, 0.185).dy)
            ..quadraticBezierTo(
              at(0.5 + sx * 0.1, 0.178).dx,
              at(0.5, 0.178).dy,
              at(0.5 + sx * 0.17, 0.184).dx,
              at(0.5, 0.184).dy,
            ),
          guide,
        );
      }
      canvas.drawCircle(at(0.5, 0.41), scale * 0.008, Paint()..color = colors.guide);
    } else {
      final spine = Path();
      for (var y = 0.18; y < 0.46; y += 0.018) {
        final a = at(0.5, y), b = at(0.5, y + 0.009);
        spine
          ..moveTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy);
      }
      canvas.drawPath(spine, guide);
      for (final sx in [-1.0, 1.0]) {
        canvas.drawPath(
          Path()
            ..moveTo(at(0.5 + sx * 0.06, 0.215).dx, at(0.5, 0.215).dy)
            ..quadraticBezierTo(
              at(0.5 + sx * 0.15, 0.22).dx,
              at(0.5, 0.22).dy,
              at(0.5 + sx * 0.12, 0.29).dx,
              at(0.5, 0.29).dy,
            ),
          guide,
        );
      }
    }

    // Outline.
    canvas.drawPath(
      figure,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, scale * 0.008)
        ..strokeJoin = StrokeJoin.round
        ..color = colors.outline,
    );

    // Markers.
    for (final mark in marks) {
      if (mark.point.side != side) continue;
      final c = toCanvas(size, mark.point.x, mark.point.y);
      final rr = mark.radius;
      canvas.drawCircle(
        c,
        rr * (2.2 + mark.pulse),
        Paint()..color = mark.color.withValues(alpha: 0.18 + 0.2 * mark.pulse),
      );
      canvas.drawCircle(c, rr, Paint()..color = mark.color);
      canvas.drawCircle(
        c,
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = colors.fillTop.withValues(alpha: 1),
      );
    }
  }

  @override
  bool shouldRepaint(BodyMapPainter old) =>
      old.side != side ||
      old.colors != colors ||
      old.marks != marks ||
      old.heat != heat ||
      old.maxHeatCount != maxHeatCount;
}

/// Front and back figures side by side (front first in the reading
/// direction). Tap the silhouette to drop a point; tap a point again to lift
/// it. Read-only when [onChanged] is null (the heat map). Each figure is a
/// picture and is never mirrored.
class BodyMapView extends StatefulWidget {
  const BodyMapView({
    super.key,
    this.points = const [],
    this.onChanged,
    this.onRegionTapped,
    this.pointColor,
    this.heat = const [],
    this.height = 300,
    required this.frontLabel,
    required this.backLabel,
    this.semanticLabel,
  });

  final List<BodyPoint> points;
  final ValueChanged<List<BodyPoint>>? onChanged;

  /// A new point landed in this named area.
  final ValueChanged<BodyRegion>? onRegionTapped;
  final Color? pointColor;
  final List<HeatSpot> heat;
  final double height;
  final String frontLabel;
  final String backLabel;
  final String? semanticLabel;

  @override
  State<BodyMapView> createState() => _BodyMapViewState();
}

class _BodyMapViewState extends State<BodyMapView> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  BodyPoint? _fresh;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _tap(BodySide side, Size size, Offset local) {
    final onChanged = widget.onChanged;
    if (onChanged == null) return;
    final f = BodyMapPainter.toFigure(size, local);
    final tapped = BodyPoint(f.dx.clamp(0.0, 1.0), f.dy.clamp(0.0, 1.0), side);
    // Lift an existing point near the tap.
    final hitRadius = 22 / BodyMapPainter.figureRect(size).width;
    for (final p in widget.points) {
      if (p.side == side && p.distanceTo(tapped) <= hitRadius) {
        Fx.fire(Sfx.toggleOff);
        onChanged([
          for (final q in widget.points)
            if (q != p) q,
        ]);
        return;
      }
    }
    if (!BodyMapPainter.hits(f.dx, f.dy)) {
      Fx.fire(Sfx.error, volume: 0.4);
      return;
    }
    Fx.fire(Sfx.drop);
    _fresh = tapped;
    if (!context.reducedMotion) _pulse.forward(from: 0);
    onChanged([...widget.points, tapped]);
    final region = BodyFigure.regionAt(tapped.x, tapped.y, side);
    if (region != null) widget.onRegionTapped?.call(region);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final colors = BodyMapColors.of(t);
    final pointColor = widget.pointColor ?? t.accent;
    final maxHeat = widget.heat.fold<int>(1, (m, h) => math.max(m, h.count));
    Widget figure(BodySide side, String label) => Expanded(
      child: Column(
        children: [
          SizedBox(
            height: widget.height,
            child: LayoutBuilder(
              builder: (context, c) {
                final size = Size(c.maxWidth, widget.height);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: widget.onChanged == null ? null : (d) => _tap(side, size, d.localPosition),
                  child: AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, _) => CustomPaint(
                      size: size,
                      painter: BodyMapPainter(
                        side: side,
                        colors: colors,
                        heat: widget.heat,
                        maxHeatCount: maxHeat,
                        heatColor: (s) => WbPalette.painGlow(t, s),
                        marks: [
                          for (final p in widget.points)
                            BodyMark(
                              p,
                              pointColor,
                              radius: 6.5,
                              pulse: p == _fresh && _pulse.isAnimating ? 1 - Curves.easeOut.transform(_pulse.value) : 0,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: Space.xs),
          Text(label, style: text.labelMedium?.copyWith(color: t.textSecondary)),
        ],
      ),
    );
    // Front first in the reading direction; the figures themselves are
    // pictures and are never mirrored.
    return Semantics(
      label: widget.semanticLabel,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          figure(BodySide.front, widget.frontLabel),
          const SizedBox(width: Space.s),
          figure(BodySide.back, widget.backLabel),
        ],
      ),
    );
  }
}
