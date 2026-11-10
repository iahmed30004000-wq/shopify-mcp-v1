import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'pattern_geometry.dart';
import 'pattern_picture_cache.dart';
import 'pattern_spec.dart';

/// A mashrabiya (carved wooden lattice) overlay: bars of [barColor], a soft
/// wash of [lightColor] falling through the openings, and a thin lit edge on
/// the bars. One cached picture, so it costs one `drawPicture` per frame:
/// use it where a backdrop blur would otherwise sit.
class MashrabiyaLattice extends StatelessWidget {
  const MashrabiyaLattice({
    super.key,
    required this.barColor,
    required this.lightColor,
    this.child,
    this.family = PatternFamily.square4,
    this.cellSize = 56,
    this.barWidth = 2,
    this.opacity = 1,
  });

  final Color barColor;
  final Color lightColor;
  final PatternFamily family;

  /// Pixel length of one lattice cell.
  final double cellSize;
  final double barWidth;
  final double opacity;

  /// Sits under the lattice; the lattice never takes touches.
  final Widget? child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: MashrabiyaPainter(
      barColor: barColor,
      lightColor: lightColor,
      family: family,
      cellSize: cellSize,
      barWidth: barWidth,
      opacity: opacity,
    ),
    child: child ?? const SizedBox.expand(),
  );
}

class MashrabiyaPainter extends CustomPainter {
  MashrabiyaPainter({
    required this.barColor,
    required this.lightColor,
    this.family = PatternFamily.square4,
    this.cellSize = 56,
    this.barWidth = 2,
    this.opacity = 1,
  }) : _config = ('lattice', family, barColor, lightColor, cellSize, barWidth, opacity);

  final Color barColor, lightColor;
  final PatternFamily family;
  final double cellSize, barWidth, opacity;
  final Object _config;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.drawPicture(
      PatternPictureCache.find(_config, size) ?? PatternPictureCache.record(_config, size, (c) => _draw(c, size)),
    );
  }

  void _draw(Canvas canvas, Size size) {
    final g = PatternGeometry.cached(PatternSpec(family: family));
    final a = opacity.clamp(0.0, 1.0);
    final cell = math.max(8.0, cellSize);
    final path = buildTiledPath(
      g,
      area: (Offset.zero & size).inflate(barWidth * 2),
      cell: cell,
      origin: Offset.zero,
    );

    // Light falls from the top-start corner and fades across the glass.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(size.width, size.height), [
          lightColor.withValues(alpha: lightColor.a * 0.30 * a),
          lightColor.withValues(alpha: lightColor.a * 0.05 * a),
        ]),
    );
    // The openings catch a little light of their own.
    canvas.drawPath(path, Paint()..color = lightColor.withValues(alpha: lightColor.a * 0.10 * a));
    // The bars.
    canvas.drawPath(
      path,
      Paint()
        ..color = barColor.withValues(alpha: barColor.a * a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = barWidth
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true,
    );
    // A lit edge, nudged toward the light.
    canvas.drawPath(
      path.shift(Offset(-barWidth * 0.35, -barWidth * 0.35)),
      Paint()
        ..color = lightColor.withValues(alpha: lightColor.a * 0.45 * a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.5, barWidth * 0.3)
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(MashrabiyaPainter old) => old._config != _config;
}
