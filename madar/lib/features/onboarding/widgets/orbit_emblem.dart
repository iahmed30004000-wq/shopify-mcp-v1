import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/themes.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/motion/motion.dart';

/// "Your day orbits the five prayers": a brass astrolabe ring around a
/// glowing central star, the five prayer lights on the inner orbit and the
/// eight life planets on the outer one, turning in opposite directions
/// (ambient motion; still under reduced motion / in tests).
class OrbitEmblem extends StatefulWidget {
  const OrbitEmblem({super.key, this.size = 240, this.animate = true});

  final double size;
  final bool animate;

  @override
  State<OrbitEmblem> createState() => _OrbitEmblemState();
}

class _OrbitEmblemState extends State<OrbitEmblem> with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(vsync: this, duration: const Duration(seconds: 90));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(OrbitEmblem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate) _sync();
  }

  void _sync() {
    final run = widget.animate && AmbientMotion.enabled && !context.reducedMotion;
    if (run && !_turn.isAnimating) {
      _turn.repeat();
    } else if (!run && _turn.isAnimating) {
      _turn.stop();
    }
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final s = widget.size;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: s,
        child: Stack(
          alignment: Alignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    t.accentGlow.withValues(alpha: t.accentGlow.a * 0.3),
                    t.accentGlow.withValues(alpha: 0),
                  ],
                ),
              ),
              child: SizedBox.square(dimension: s),
            ),
            RepaintBoundary(child: AstrolabeRing(size: s, showNumerals: false)),
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _turn,
                builder: (context, _) => CustomPaint(
                  size: Size.square(s),
                  painter: OrbitEmblemPainter(
                    phase: _turn.value,
                    gold: t.gold,
                    brass: t.brass,
                    glow: t.accentGlow,
                    core: t.starTint,
                    planets: [for (final p in PlanetPalettes.byKey.values) p.surface],
                  ),
                ),
              ),
            ),
            IslamicStar(size: s * 0.17, glow: true),
          ],
        ),
      ),
    );
  }
}

/// Paints the two orbits of [OrbitEmblem] at a rotation [phase] (0..1).
class OrbitEmblemPainter extends CustomPainter {
  const OrbitEmblemPainter({
    required this.phase,
    required this.gold,
    required this.brass,
    required this.glow,
    required this.core,
    required this.planets,
  });

  final double phase;
  final Color gold, brass, glow, core;
  final List<Color> planets;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final inner = r * 0.36;
    final outer = r * 0.62;
    final orbit = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = brass.withValues(alpha: 0.55);
    canvas.drawCircle(c, inner, orbit);
    canvas.drawCircle(c, outer, orbit..color = brass.withValues(alpha: 0.35));

    // Five prayer lights.
    final a0 = phase * 2 * math.pi;
    for (var i = 0; i < 5; i++) {
      final a = -math.pi / 2 + a0 + i * 2 * math.pi / 5;
      final p = c + Offset(math.cos(a), math.sin(a)) * inner;
      final pr = r * 0.035;
      canvas.drawCircle(
        p,
        pr * 3,
        Paint()
          ..color = glow.withValues(alpha: glow.a * 0.8)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, pr * 1.8),
      );
      canvas.drawCircle(p, pr, Paint()..color = Color.lerp(gold, core, 0.45)!);
    }

    // Eight planets, turning the other way.
    for (var i = 0; i < planets.length; i++) {
      final a = -a0 * 0.6 + i * 2 * math.pi / planets.length + 0.3;
      final p = c + Offset(math.cos(a), math.sin(a)) * outer;
      final pr = r * (0.026 + 0.008 * (i % 3));
      canvas.drawCircle(
        p,
        pr * 2.4,
        Paint()
          ..color = planets[i].withValues(alpha: 0.35)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, pr * 1.5),
      );
      canvas.drawCircle(
        p,
        pr,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.4, -0.4),
            colors: [Color.lerp(planets[i], core, 0.5)!, planets[i]],
          ).createShader(Rect.fromCircle(center: p, radius: pr)),
      );
    }
  }

  @override
  bool shouldRepaint(OrbitEmblemPainter old) =>
      old.phase != phase || old.gold != gold || old.brass != brass || old.glow != glow || old.core != core;
}
