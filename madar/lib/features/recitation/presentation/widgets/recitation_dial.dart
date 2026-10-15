import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../../core/design/painters/astrolabe_ticks_painter.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/motion/motion.dart';

/// The full player's astrolabe: an engraved brass degree ring (slowly
/// turning like a rete while reciting), the passage's progress as a gold
/// arc with a brass alidade pointer at its head, the current ayah's own
/// progress on an inner arc, and – for short passages – one bead per ayah
/// (heard ones gilded).
class RecitationDial extends StatefulWidget {
  const RecitationDial({
    super.key,
    required this.progress,
    this.ayahProgress = 0,
    this.beads = 0,
    this.bead = 0,
    this.size = 240,
    this.spinning = false,
    this.semanticLabel,
    this.child,
  });

  /// Passage progress 0..1.
  final double progress;

  /// Current ayah's progress 0..1.
  final double ayahProgress;

  /// Ayat in the passage (beads are drawn up to [maxBeads]).
  final int beads;

  /// 0-based index of the current ayah.
  final int bead;
  final double size;

  /// Turn the ring (only while reciting; never with reduced motion).
  final bool spinning;
  final String? semanticLabel;
  final Widget? child;

  static const maxBeads = 60;

  @override
  State<RecitationDial> createState() => _RecitationDialState();
}

class _RecitationDialState extends State<RecitationDial> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final ValueNotifier<double> _rotation = ValueNotifier(0);
  Duration _last = Duration.zero;

  /// One turn in four minutes: alive, never busy.
  static const _radiansPerSecond = 2 * math.pi / 240;

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _rotation.value = (_rotation.value + dt * _radiansPerSecond) % (2 * math.pi);
  }

  void _sync() {
    final spin = widget.spinning && !context.reducedMotion;
    if (spin && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!spin && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(RecitationDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final arabic = Localizations.maybeLocaleOf(context)?.languageCode == 'ar';
    final duration = context.motion(MadarMotion.long);
    return Semantics(
      label: widget.semanticLabel,
      child: SizedBox.square(
        dimension: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: ExcludeSemantics(
                child: ValueListenableBuilder<double>(
                  valueListenable: _rotation,
                  builder: (context, rotation, _) => CustomPaint(
                    painter: AstrolabeTicksPainter(
                      color: t.brass.withValues(alpha: 0.75),
                      majorColor: t.metalGold,
                      numeralColor: t.gold,
                      rotation: rotation,
                      showNumerals: widget.size >= 200,
                      arabicIndic: arabic,
                      fontFamily: MadarTypography.uiFamily,
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: ExcludeSemantics(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: widget.progress.clamp(0.0, 1.0)),
                  duration: duration,
                  curve: MadarMotion.orbital,
                  builder: (context, progress, _) => TweenAnimationBuilder<double>(
                    tween: Tween(end: widget.ayahProgress.clamp(0.0, 1.0)),
                    duration: context.motion(MadarMotion.short),
                    builder: (context, ayah, _) => CustomPaint(
                      painter: RecitationDialPainter(
                        progress: progress,
                        ayahProgress: ayah,
                        beads: widget.beads,
                        bead: widget.bead,
                        track: t.brassDark.withValues(alpha: 0.55),
                        arc: t.metalGold,
                        arcEnd: t.accent,
                        inner: t.accent.withValues(alpha: 0.85),
                        brass: t.metalBrass,
                        beadColor: t.brass.withValues(alpha: 0.6),
                        glow: t.accentGlow,
                        direction: Directionality.of(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.child != null) Padding(padding: EdgeInsets.all(widget.size * 0.2), child: widget.child),
          ],
        ),
      ),
    );
  }
}

/// Draws the dial's arcs, beads and alidade (see [RecitationDial]). Angles
/// start at the top; the arc runs clockwise (like the app's astrolabe).
class RecitationDialPainter extends CustomPainter {
  const RecitationDialPainter({
    required this.progress,
    required this.ayahProgress,
    required this.beads,
    required this.bead,
    required this.track,
    required this.arc,
    required this.arcEnd,
    required this.inner,
    required this.brass,
    required this.beadColor,
    required this.glow,
    required this.direction,
  });

  final double progress;
  final double ayahProgress;
  final int beads;
  final int bead;
  final Color track, arc, arcEnd, inner, brass, beadColor, glow;
  final TextDirection direction;

  static const _start = -math.pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final arcR = r * 0.67;
    final innerR = r * 0.575;
    final stroke = math.max(2.0, r * 0.035);

    // Track and passage arc.
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 0.5
      ..color = track;
    canvas.drawCircle(c, arcR, trackPaint);
    final sweep = 2 * math.pi * progress;
    final rect = Rect.fromCircle(center: c, radius: arcR);
    if (sweep > 0.001) {
      final gradient = SweepGradient(
        startAngle: 0,
        endAngle: math.max(sweep, 0.01),
        colors: [arc.withValues(alpha: 0.65), arc, arcEnd],
        stops: const [0, 0.6, 1],
        transform: const GradientRotation(_start),
      );
      canvas.drawArc(
        rect,
        _start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke * 2.4
          ..strokeCap = StrokeCap.round
          ..color = glow.withValues(alpha: 0.35)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke * 1.6),
      );
      canvas.drawArc(
        rect,
        _start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..shader = gradient.createShader(rect),
      );
    }

    // Beads, one per ayah.
    if (beads > 1 && beads <= RecitationDial.maxBeads) {
      final beadR = math.max(1.4, r * 0.014);
      for (var i = 0; i < beads; i++) {
        final a = _start + 2 * math.pi * (i + 0.5) / beads;
        final p = c + Offset(math.cos(a), math.sin(a)) * (arcR - stroke * 2.6);
        final heard = i < bead;
        final now = i == bead;
        if (now) {
          canvas.drawCircle(
            p,
            beadR * 3,
            Paint()
              ..color = glow.withValues(alpha: 0.5)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, beadR * 2),
          );
        }
        canvas.drawCircle(
          p,
          now ? beadR * 1.6 : beadR,
          Paint()
            ..style = heard || now ? PaintingStyle.fill : PaintingStyle.stroke
            ..strokeWidth = 0.8
            ..color = now ? arcEnd : (heard ? arc : beadColor),
        );
      }
    }

    // The current ayah, on the inner arc.
    if (ayahProgress > 0.002) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: innerR),
        _start,
        2 * math.pi * ayahProgress,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke * 0.45
          ..strokeCap = StrokeCap.round
          ..color = inner,
      );
    }

    // The alidade: a brass pointer across the rim at the arc's head.
    final a = _start + sweep;
    final dir = Offset(math.cos(a), math.sin(a));
    final normal = Offset(-dir.dy, dir.dx);
    final tip = c + dir * (arcR + r * 0.12);
    final heel = c + dir * (arcR - r * 0.08);
    final half = r * 0.028;
    final pointer = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(heel.dx + normal.dx * half, heel.dy + normal.dy * half)
      ..lineTo(heel.dx - normal.dx * half, heel.dy - normal.dy * half)
      ..close();
    canvas.drawPath(
      pointer.shift(const Offset(0, 1.2)),
      Paint()
        ..color = const Color(0x55000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
    canvas.drawPath(
      pointer,
      Paint()..shader = LinearGradient(colors: [arc, brass]).createShader(Rect.fromPoints(heel, tip)),
    );
    final hub = c + dir * arcR;
    canvas.drawCircle(hub, stroke * 1.05, Paint()..color = brass);
    canvas.drawCircle(hub, stroke * 0.5, Paint()..color = arcEnd);
  }

  @override
  bool shouldRepaint(RecitationDialPainter old) =>
      old.progress != progress ||
      old.ayahProgress != ayahProgress ||
      old.beads != beads ||
      old.bead != bead ||
      old.track != track ||
      old.arc != arc ||
      old.arcEnd != arcEnd ||
      old.inner != inner ||
      old.brass != brass ||
      old.beadColor != beadColor ||
      old.glow != glow;
}
