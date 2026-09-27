import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/themes.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/gen/app_localizations.dart';

/// Placeholder for the Neglect Radar (arrives with the living orbit in
/// Phase 1): a small engraved radar scope with the eight planets as blips,
/// a title, one line of explanation and a "soon" badge.
class NeglectRadarCard extends StatelessWidget {
  const NeglectRadarCard({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: '${l.homeRadarTitle}. ${l.homeRadarBody}. ${l.homeRadarBadge}',
      child: ExcludeSemantics(
        child: GlassCard(
          padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s + 2, Space.m, Space.s + 2),
          child: Row(
            children: [
              RepaintBoundary(
                child: CustomPaint(
                  size: const Size.square(40),
                  painter: RadarScopePainter(
                    ring: t.brass,
                    sweep: t.accent,
                    blips: [for (final p in PlanetPalettes.byKey.values) p.surface],
                  ),
                ),
              ),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l.homeRadarTitle, style: text.titleSmall!.copyWith(color: t.textPrimary, height: 1.3)),
                    Text(
                      l.homeRadarBody,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall!.copyWith(color: t.textTertiary, height: 1.35, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Space.s),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: t.accentSoft,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: t.accent.withValues(alpha: 0.45), width: 0.8),
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.s + 2, vertical: 3),
                  child: Text(l.homeRadarBadge, style: text.labelSmall!.copyWith(color: t.accent)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A still radar scope: three rings, cross-hairs, a fading sweep wedge and
/// planet blips at fixed, pleasant positions.
class RadarScopePainter extends CustomPainter {
  const RadarScopePainter({required this.ring, required this.sweep, required this.blips});

  final Color ring;
  final Color sweep;
  final List<Color> blips;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 1;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = ring.withValues(alpha: 0.7);
    for (final f in const [1.0, 0.66, 0.33]) {
      canvas.drawCircle(c, r * f, line);
    }
    canvas.drawLine(c - Offset(r, 0), c + Offset(r, 0), line..color = ring.withValues(alpha: 0.35));
    canvas.drawLine(c - Offset(0, r), c + Offset(0, r), line);
    const start = -math.pi / 2;
    const span = math.pi / 2.2;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      start,
      span,
      true,
      Paint()
        ..shader = SweepGradient(
          startAngle: start,
          endAngle: start + span,
          colors: [sweep.withValues(alpha: 0.0), sweep.withValues(alpha: 0.45)],
          transform: const GradientRotation(0),
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawLine(
      c,
      c + Offset(math.cos(start + span), math.sin(start + span)) * r,
      Paint()
        ..strokeWidth = 1.1
        ..color = sweep,
    );
    for (var i = 0; i < blips.length; i++) {
      final a = i * 2 * math.pi / blips.length + 0.4;
      final d = r * (0.3 + 0.6 * ((i * 37) % 10) / 10);
      final p = c + Offset(math.cos(a), math.sin(a)) * d;
      canvas.drawCircle(p, 1.9, Paint()..color = blips[i]);
    }
  }

  @override
  bool shouldRepaint(RadarScopePainter old) => old.ring != ring || old.sweep != sweep || !_sameColors(old.blips, blips);

  static bool _sameColors(List<Color> a, List<Color> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
