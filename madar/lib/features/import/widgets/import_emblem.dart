import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/motion/motion.dart';

/// The import hero: a brass astrolabe rete slowly turning around a girih
/// rosette, three tilted orbits carrying glowing "record" moons, and a
/// comet of data spiralling in from outside – your data entering orbit.
///
/// Ambient: loops only while [AmbientMotion.enabled], motion is not reduced
/// and the ticker is enabled (tickers mute with [TickerMode]); otherwise a
/// still, fully composed frame.
class ImportEmblem extends StatefulWidget {
  const ImportEmblem({super.key, this.size = 196});

  final double size;

  @override
  State<ImportEmblem> createState() => _ImportEmblemState();
}

class _ImportEmblemState extends State<ImportEmblem> with SingleTickerProviderStateMixin {
  static const _still = 0.18;
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 40),
    value: _still,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final run = AmbientMotion.enabled && !context.reducedMotion;
    if (run && !_loop.isAnimating) {
      _loop.repeat();
    } else if (!run && _loop.isAnimating) {
      _loop
        ..stop()
        ..value = _still;
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final s = widget.size;
    final reduced = context.reducedMotion;
    ImportEmblemPainter painter({required bool front}) => ImportEmblemPainter(
      progress: _loop,
      front: front,
      orbit: t.brass,
      moon: t.gold,
      glow: t.accentGlow,
      star: t.starTint,
      comet: t.highlight,
      reduced: reduced,
    );
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: s,
          child: Stack(
            alignment: Alignment.center,
            children: [
              RotationTransition(
                turns: _loop,
                child: Opacity(opacity: 0.55, child: AstrolabeRing(size: s * 0.92, showNumerals: false)),
              ),
              CustomPaint(
                size: Size.square(s),
                painter: painter(front: false),
                foregroundPainter: painter(front: true),
                child: SizedBox.square(
                  dimension: s,
                  child: Center(
                    child: RotationTransition(
                      turns: ReverseAnimation(_loop),
                      child: GirihRosette(size: s * 0.34),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Paints the orbits (back half behind the rosette, front half over it),
/// the record moons, the twinkling stars and the inbound comet.
class ImportEmblemPainter extends CustomPainter {
  ImportEmblemPainter({
    required this.progress,
    required this.front,
    required this.orbit,
    required this.moon,
    required this.glow,
    required this.star,
    required this.comet,
    this.reduced = false,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final bool front;
  final Color orbit, moon, glow, star, comet;
  final bool reduced;

  // (tilt, laps per loop, phase, moon size)
  static const _orbits = <(double, int, double, double)>[
    (-0.52, 3, 0.05, 1.0),
    (0.38, 2, 0.45, 0.8),
    (1.21, 4, 0.72, 0.62),
  ];

  static const _stars = <(double, double, double)>[
    (0.08, 0.14, 0.1), (0.9, 0.2, 0.4), (0.15, 0.82, 0.7), (0.86, 0.78, 0.2), //
    (0.5, 0.04, 0.55), (0.03, 0.5, 0.85), (0.97, 0.52, 0.33), (0.62, 0.95, 0.12),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = progress.value;
    final s = size.shortestSide;
    final c = size.center(Offset.zero);
    final rx = s * 0.47;
    final ry = s * 0.155;

    Offset onOrbit(double tilt, double a) {
      final p = Offset(math.cos(a) * rx, math.sin(a) * ry);
      return c + Offset(p.dx * math.cos(tilt) - p.dy * math.sin(tilt), p.dx * math.sin(tilt) + p.dy * math.cos(tilt));
    }

    if (!front) {
      // Twinkling stars (behind everything).
      for (final (x, y, phase) in _stars) {
        final tw = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(2 * math.pi * (t * 6 + phase)));
        final p = Offset(x * size.width, y * size.height);
        canvas.drawCircle(p, s * 0.006, Paint()..color = star.withValues(alpha: star.a * tw));
      }
    }

    // Orbits: the half behind the rosette first, the front half on top.
    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, s * 0.004)
      ..color = orbit.withValues(alpha: orbit.a * (front ? 0.55 : 0.28));
    for (final o in _orbits) {
      final path = Path();
      for (var i = 0; i <= 48; i++) {
        final a = (front ? 0 : math.pi) + math.pi * i / 48;
        final p = onOrbit(o.$1, a);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, orbitPaint);
    }

    // Record moons.
    for (final o in _orbits) {
      final a = 2 * math.pi * (t * o.$2 + o.$3);
      final isFront = math.sin(a) >= 0;
      if (isFront != front) continue;
      final p = onOrbit(o.$1, a);
      final r = s * 0.022 * o.$4 * (isFront ? 1 : 0.8);
      final depth = isFront ? 1.0 : 0.55;
      canvas.drawCircle(
        p,
        r * 3.2,
        Paint()
          ..color = glow.withValues(alpha: glow.a * 0.45 * depth)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 1.6),
      );
      canvas.drawCircle(p, r, Paint()..color = Color.lerp(moon, star, 0.35)!.withValues(alpha: depth));
    }

    // Inbound comet: a logarithmic spiral from the rim into the rosette.
    if (front && !reduced) {
      final phase = (t * 5) % 1.0;
      Offset spiral(double u) {
        final radius = s * 0.5 * math.pow(1 - u, 1.35).toDouble();
        final a = -math.pi / 3 + u * math.pi * 2.4;
        return c + Offset(math.cos(a) * radius, math.sin(a) * radius * 0.62);
      }

      const steps = 18;
      for (var i = 0; i < steps; i++) {
        final u0 = (phase - i * 0.012).clamp(0.0, 1.0);
        final u1 = (phase - (i + 1) * 0.012).clamp(0.0, 1.0);
        if (u0 <= 0) break;
        final fade = (1 - i / steps) * (1 - math.pow(phase, 6).toDouble());
        canvas.drawLine(
          spiral(u0),
          spiral(u1),
          Paint()
            ..color = comet.withValues(alpha: comet.a * 0.8 * fade)
            ..strokeWidth = s * 0.012 * (1 - i / steps)
            ..strokeCap = StrokeCap.round,
        );
      }
      final head = spiral(phase);
      final hr = s * 0.014 * (1 - phase * 0.6);
      canvas.drawCircle(
        head,
        hr * 3,
        Paint()
          ..color = comet.withValues(alpha: comet.a * 0.5 * (1 - phase))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, hr * 1.5),
      );
      canvas.drawCircle(head, hr, Paint()..color = star.withValues(alpha: 1 - phase * 0.7));
    }
  }

  @override
  bool shouldRepaint(ImportEmblemPainter old) =>
      old.front != front ||
      old.orbit != orbit ||
      old.moon != moon ||
      old.glow != glow ||
      old.star != star ||
      old.comet != comet ||
      old.reduced != reduced;
}
