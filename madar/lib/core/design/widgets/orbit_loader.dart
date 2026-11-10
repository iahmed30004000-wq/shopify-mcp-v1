import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../i18n/gen/app_localizations.dart';
import '../../motion/motion.dart';
import '../tokens.dart';

/// Madar's loading indicator: a glowing body with three moons on tilted
/// orbits, each trailing a fading wake. Under reduced motion the moons hold
/// still and the body breathes instead.
class OrbitLoader extends StatefulWidget {
  const OrbitLoader({super.key, this.size = 32, this.color, this.secondaryColor, this.semanticLabel});

  final double size;

  /// Defaults to the theme accent.
  final Color? color;

  /// Moon colour; defaults to [MadarTokens.starTint] (ink [MadarTokens.secondary]
  /// in the light theme).
  final Color? secondaryColor;

  /// Defaults to the localised "Loading".
  final String? semanticLabel;

  @override
  State<OrbitLoader> createState() => _OrbitLoaderState();
}

class _OrbitLoaderState extends State<OrbitLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final label = widget.semanticLabel ?? Localizations.of<L10n>(context, L10n)?.designLoading;
    return Semantics(
      label: label,
      liveRegion: true,
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: OrbitLoaderPainter(
            progress: _c,
            color: widget.color ?? t.accent,
            moonColor: widget.secondaryColor ?? (t.isDark ? t.starTint : t.secondary),
            reduced: context.reducedMotion,
          ),
        ),
      ),
    );
  }
}

class OrbitLoaderPainter extends CustomPainter {
  OrbitLoaderPainter({required this.progress, required this.color, required this.moonColor, this.reduced = false})
    : super(repaint: progress);

  final Animation<double> progress;
  final Color color;
  final Color moonColor;
  final bool reduced;

  // (tilt, laps per loop, phase, size factor)
  static const _moons = <(double, int, double, double)>[
    (-0.45, 2, 0.0, 1.0),
    (0.62, 1, 0.33, 0.8),
    (1.65, 3, 0.66, 0.65),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = progress.value;
    final s = size.shortestSide;
    final c = size.center(Offset.zero);
    final rx = s * 0.44;
    final ry = s * 0.15;

    Offset onOrbit(double tilt, double a) {
      final p = Offset(math.cos(a) * rx, math.sin(a) * ry);
      return c + Offset(p.dx * math.cos(tilt) - p.dy * math.sin(tilt), p.dx * math.sin(tilt) + p.dy * math.cos(tilt));
    }

    final orbitPaint = Paint()
      ..color = color.withValues(alpha: color.a * 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.5, s * 0.018);
    for (final m in _moons) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(m.$1);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2), orbitPaint);
      canvas.restore();
    }

    void drawMoon((double, int, double, double) m, {required bool back}) {
      final a = reduced ? 2 * math.pi * m.$3 + 0.9 : 2 * math.pi * (t * m.$2 + m.$3);
      final isBack = math.sin(a) < 0;
      if (isBack != back) return;
      final depth = isBack ? 0.55 : 1.0;
      final r = s * 0.065 * m.$4 * (isBack ? 0.85 : 1);
      if (!reduced) {
        // Wake: a tapered comet tail of short overlapping segments.
        const steps = 16;
        for (var i = steps; i >= 1; i--) {
          final f = i / steps;
          canvas.drawLine(
            onOrbit(m.$1, a - i * 0.06),
            onOrbit(m.$1, a - (i - 1) * 0.06),
            Paint()
              ..color = color.withValues(alpha: color.a * (1 - f) * 0.5 * depth)
              ..strokeWidth = r * 1.7 * (1 - f * 0.85)
              ..strokeCap = StrokeCap.round,
          );
        }
      }
      final p = onOrbit(m.$1, a);
      canvas.drawCircle(
        p,
        r * 1.9,
        Paint()
          ..color = color.withValues(alpha: color.a * 0.35 * depth)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r),
      );
      canvas.drawCircle(p, r, Paint()..color = moonColor.withValues(alpha: moonColor.a * depth));
    }

    for (final m in _moons) {
      drawMoon(m, back: true);
    }

    final breathe = reduced ? 0.85 + 0.15 * math.sin(2 * math.pi * t) : 1.0;
    final coreR = s * 0.13 * breathe;
    canvas.drawCircle(
      c,
      coreR * 2.4,
      Paint()
        ..shader = ui.Gradient.radial(c, coreR * 2.4, [
          color.withValues(alpha: color.a * 0.5),
          color.withValues(alpha: 0),
        ]),
    );
    canvas.drawCircle(
      c,
      coreR,
      Paint()
        ..shader = ui.Gradient.radial(c - Offset(coreR * 0.35, coreR * 0.35), coreR * 1.3, [
          Color.lerp(color, moonColor, 0.55)!,
          color,
        ]),
    );

    for (final m in _moons) {
      drawMoon(m, back: false);
    }
  }

  @override
  bool shouldRepaint(OrbitLoaderPainter old) =>
      old.progress != progress || old.color != color || old.moonColor != moonColor || old.reduced != reduced;
}
