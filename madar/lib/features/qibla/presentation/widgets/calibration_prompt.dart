import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/sound/sound_api.dart';

/// The figure-eight calibration prompt: an animated phone tracing an "8",
/// what to do, and a "later" button.
class QiblaCalibrationPrompt extends StatelessWidget {
  const QiblaCalibrationPrompt({super.key, required this.interference, required this.onLater});

  /// The field is far from the model (metal / magnets nearby).
  final bool interference;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final eight = fmt.formatInt(8);
    return GlassPanel(
      key: const ValueKey('qibla-calibration'),
      glowColor: t.warning,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.l, Space.l, Space.m),
      child: Semantics(
        liveRegion: true,
        container: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 76, height: 96, child: FigureEightAnimation()),
                const SizedBox(width: Space.l),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.qiblaCalibrateTitle, style: text.titleMedium?.copyWith(color: t.textPrimary)),
                      const SizedBox(height: Space.xs),
                      Text(
                        interference ? l.qiblaInterferenceBody(eight) : l.qiblaCalibrateBody(eight),
                        style: text.bodyMedium?.copyWith(color: t.textSecondary, height: 1.45),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: MadarButton(
                label: l.qiblaCalibrateLater,
                variant: MadarButtonVariant.ghost,
                size: MadarButtonSize.small,
                sfx: Sfx.sheetClose,
                onPressed: onLater,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A phone tracing a figure-eight (static under reduced motion, battery
/// saver and in tests).
class FigureEightAnimation extends StatefulWidget {
  const FigureEightAnimation({super.key});

  @override
  State<FigureEightAnimation> createState() => _FigureEightAnimationState();
}

class _FigureEightAnimationState extends State<FigureEightAnimation> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate = context.ambientMotion && TickerMode.valuesOf(context).enabled;
    if (animate && !_c.isAnimating) {
      _c.repeat();
    } else if (!animate) {
      _c
        ..stop()
        ..value = 0.14;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ExcludeSemantics(
      child: CustomPaint(
        painter: _FigureEightPainter(_c, trail: t.accent, phone: t.textPrimary, screen: t.space2, glow: t.accentGlow),
      ),
    );
  }
}

class _FigureEightPainter extends CustomPainter {
  _FigureEightPainter(
    this.progress, {
    required this.trail,
    required this.phone,
    required this.screen,
    required this.glow,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final Color trail, phone, screen, glow;

  /// A vertical lemniscate (Gerono): x = sin t·cos t, y = sin t.
  static Offset point(double u, Size s) {
    final a = u * 2 * math.pi;
    return Offset(
      s.width / 2 + math.sin(a) * math.cos(a) * s.width * 0.78,
      s.height / 2 - math.sin(a) * s.height * 0.4,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    const n = 96;
    final path = Path();
    for (var i = 0; i <= n; i++) {
      final p = point(i / n, size);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = trail.withValues(alpha: 0.35),
    );
    // A bright trail behind the phone.
    final u = progress.value;
    for (var i = 0; i < 24; i++) {
      final a = point(u - i * 0.008, size);
      final b = point(u - (i + 1) * 0.008, size);
      canvas.drawLine(
        a,
        b,
        Paint()
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..color = trail.withValues(alpha: (1 - i / 24) * 0.9),
      );
    }
    final p = point(u, size);
    final q = point(u + 0.004, size);
    final angle = math.atan2(q.dy - p.dy, q.dx - p.dx) + math.pi / 2;
    canvas
      ..save()
      ..translate(p.dx, p.dy)
      ..rotate(angle * 0.35);
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 16, height: 27),
      const Radius.circular(3.5),
    );
    canvas
      ..drawRRect(
        body.inflate(3),
        Paint()
          ..color = glow.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      )
      ..drawRRect(body, Paint()..color = phone)
      ..drawRRect(body.deflate(1.8), Paint()..color = screen)
      ..restore();
  }

  @override
  bool shouldRepaint(_FigureEightPainter old) =>
      old.trail != trail || old.phone != phone || old.screen != screen || old.progress != progress;
}
