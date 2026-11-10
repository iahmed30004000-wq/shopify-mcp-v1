import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'geometry_pattern_painter.dart';
import 'pattern_spec.dart';

/// The motion curve and reduced-motion rule of the bloom, kept pure.
abstract final class PatternBloom {
  /// Fraction (0..1) of the full radius revealed at [progress]; monotonic.
  static double radiusFraction(double progress) {
    final p = progress.isNaN ? 0.0 : progress.clamp(0.0, 1.0);
    final q = 1 - p;
    return 1 - q * q * q; // ease-out cubic: the bloom opens fast, settles soft
  }

  /// With reduced motion the bloom skips straight to its end state as soon
  /// as it starts (progress 0 stays hidden, anything above shows it all).
  static double effectiveProgress(double progress, {required bool reducedMotion}) {
    final p = progress.isNaN ? 0.0 : progress.clamp(0.0, 1.0);
    if (!reducedMotion) return p;
    return p > 0 ? 1.0 : 0.0;
  }
}

/// Reveals a tiled pattern radiating outward from [origin] as [progress]
/// goes 0 to 1 (planet-open transitions). Drive [progress] from an
/// animation; the widget never animates by itself.
class PatternBloomReveal extends StatelessWidget {
  const PatternBloomReveal({
    super.key,
    required this.progress,
    required this.spec,
    required this.color,
    this.origin = Alignment.center,
    this.waveColor,
    this.opacity = 1,
    this.child,
  });

  final double progress;
  final PatternSpec spec;
  final Color color;

  /// Where the bloom starts, as an alignment of the box.
  final AlignmentGeometry origin;

  /// Colour of the thin wavefront ring (defaults to [color]).
  final Color? waveColor;
  final double opacity;

  /// Drawn underneath the pattern.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final p = PatternBloom.effectiveProgress(progress, reducedMotion: reduced);
    final alignment = origin.resolve(Directionality.maybeOf(context) ?? TextDirection.ltr);
    return CustomPaint(
      foregroundPainter: p <= 0
          ? null
          : PatternBloomPainter(progress: p, spec: spec, color: color, origin: alignment, waveColor: waveColor, opacity: opacity),
      child: child ?? const SizedBox.expand(),
    );
  }
}

class PatternBloomPainter extends CustomPainter {
  PatternBloomPainter({
    required this.progress,
    required this.spec,
    required this.color,
    this.origin = Alignment.center,
    this.waveColor,
    this.opacity = 1,
  }) : _tile = GeometryPatternPainter(spec: spec, color: color, opacity: opacity, alignment: origin);

  /// Already passed through [PatternBloom.effectiveProgress].
  final double progress;
  final PatternSpec spec;
  final Color color;
  final Alignment origin;
  final Color? waveColor;
  final double opacity;
  final GeometryPatternPainter _tile;

  static final Paint _wave = Paint()
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || progress <= 0) return;
    final centre = origin.alongSize(size);
    final far = math.max(
      math.max(centre.distance, (Offset(size.width, 0) - centre).distance),
      math.max((Offset(0, size.height) - centre).distance, (size.bottomRight(Offset.zero) - centre).distance),
    );
    final r = far * PatternBloom.radiusFraction(progress) + 0.001;
    if (progress >= 1) {
      _tile.paint(canvas, size);
      return;
    }
    canvas.save();
    canvas.clipRRect(RRect.fromRectXY(Rect.fromCircle(center: centre, radius: r), r, r));
    _tile.paint(canvas, size);
    canvas.restore();

    // A thin wavefront that fades in and out with the bloom.
    final bell = 4 * progress * (1 - progress);
    final c = waveColor ?? color;
    _wave
      ..color = c.withValues(alpha: c.a * bell * opacity.clamp(0.0, 1.0))
      ..strokeWidth = spec.resolvedLineWidth * 1.6;
    canvas.drawCircle(centre, r, _wave);
  }

  @override
  bool shouldRepaint(PatternBloomPainter old) =>
      old.progress != progress ||
      old.spec != spec ||
      old.color != color ||
      old.origin != origin ||
      old.waveColor != waveColor ||
      old.opacity != opacity;
}
