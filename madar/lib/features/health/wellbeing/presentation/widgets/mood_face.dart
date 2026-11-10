import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/design/tokens.dart';
import '../../../../../core/motion/motion_kit.dart';
import '../../../../../core/sound/sound_api.dart';
import 'wb_palette.dart';

/// Madar's own mood glyphs (1 = heavy … 5 = bright): a brass-ringed disc
/// like a small astrolabe plate, two eyes and a mouth whose curve lifts from
/// a gentle frown to a wide smile. Soft on purpose – a low mood is drawn
/// quiet and cool, never distressed.
class MoodFacePainter extends CustomPainter {
  MoodFacePainter({required this.mood, required this.color, required this.ink, this.fill = 0.0, this.ring});

  /// 1–5.
  final int mood;
  final Color color;

  /// Features (eyes, mouth).
  final Color ink;

  /// 0 = outline only, 1 = filled disc (selected).
  final double fill;
  final Color? ring;

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.min(size.width, size.height) / 2;
    final c = size.center(Offset.zero);
    final m = mood.clamp(1, 5);

    // Disc.
    final disc = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.18 + 0.55 * fill),
          color.withValues(alpha: 0.06 + 0.32 * fill),
        ],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r * 0.94, disc);
    canvas.drawCircle(
      c,
      r * 0.94,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, r * 0.06)
        ..color = (ring ?? color).withValues(alpha: 0.55 + 0.45 * fill),
    );
    // Four tiny ticks at the cardinal points (the astrolabe nod).
    final tick = Paint()
      ..color = (ring ?? color).withValues(alpha: 0.4 + 0.3 * fill)
      ..strokeWidth = math.max(0.8, r * 0.04)
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + dir * r * 0.94, c + dir * r * 0.82, tick);
    }

    final feature = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.4, r * 0.09)
      ..strokeCap = StrokeCap.round;

    // Eyes: soft dots, closed happy arcs at 5, gently lowered lids at 1.
    final eyeY = c.dy - r * 0.18;
    for (final sx in [-1.0, 1.0]) {
      final e = Offset(c.dx + sx * r * 0.32, eyeY);
      if (m == 5) {
        final p = Path()
          ..moveTo(e.dx - r * 0.12, e.dy + r * 0.03)
          ..quadraticBezierTo(e.dx, e.dy - r * 0.12, e.dx + r * 0.12, e.dy + r * 0.03);
        canvas.drawPath(p, feature);
      } else if (m == 1) {
        final p = Path()
          ..moveTo(e.dx - r * 0.11, e.dy - r * 0.01)
          ..quadraticBezierTo(e.dx, e.dy + r * 0.08, e.dx + r * 0.11, e.dy - r * 0.01);
        canvas.drawPath(p, feature);
      } else {
        canvas.drawCircle(e, r * 0.075, Paint()..color = ink);
      }
    }

    // Mouth: curvature from −1 (frown) to +1 (smile).
    final curve = (m - 3) / 2.0;
    final mouthY = c.dy + r * 0.3;
    final half = r * (0.3 + 0.05 * curve.abs());
    final bend = r * 0.24 * curve;
    final mouth = Path()
      ..moveTo(c.dx - half, mouthY - bend * 0.35)
      ..quadraticBezierTo(c.dx, mouthY + bend, c.dx + half, mouthY - bend * 0.35);
    canvas.drawPath(mouth, feature);
  }

  @override
  bool shouldRepaint(MoodFacePainter old) =>
      old.mood != mood || old.color != color || old.ink != ink || old.fill != fill || old.ring != ring;
}

/// A mood face, optionally selectable (springs up when chosen).
class MoodFace extends StatelessWidget {
  const MoodFace({super.key, required this.mood, this.size = 40, this.selected = false, this.dimmed = false});

  final int mood;
  final double size;
  final bool selected;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = WbPalette.mood(t, mood);
    final ink = Color.lerp(color, t.textPrimary, t.isDark ? 0.35 : 0.55)!;
    return SpringBuilder(
      value: selected ? 1 : 0,
      spring: MadarMotion.bouncy,
      builder: (context, v, _) {
        final fill = v.clamp(0.0, 1.0);
        return Opacity(
          opacity: dimmed && !selected ? 0.55 : 1,
          child: Transform.scale(
            scale: 1 + 0.12 * v,
            child: SizedBox.square(
              dimension: size,
              child: CustomPaint(
                painter: MoodFacePainter(
                  mood: mood,
                  color: color,
                  ink: ink,
                  fill: fill,
                  ring: selected ? t.gold : null,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Five faces in a row; tapping one selects it (tap again to clear).
class MoodFacePicker extends StatelessWidget {
  const MoodFacePicker({
    super.key,
    required this.value,
    required this.onChanged,
    required this.labels,
    this.size = 48,
    this.allowClear = true,
    this.showLabels = true,
  });

  final int? value;
  final ValueChanged<int?> onChanged;

  /// Labels for moods 1–5 (screen reader + caption).
  final List<String> labels;
  final double size;
  final bool allowClear;
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var m = 1; m <= 5; m++)
          Expanded(
            child: Semantics(
              button: true,
              selected: value == m,
              label: labels[m - 1],
              excludeSemantics: true,
              child: SpringPress(
                sfx: null,
                onTap: () {
                  final next = value == m && allowClear ? null : m;
                  Fx.fire(next == null ? Sfx.toggleOff : Sfx.toggleOn, pitch: 0.9 + m * 0.05);
                  onChanged(next);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.xs),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MoodFace(mood: m, size: size, selected: value == m, dimmed: value != null),
                      if (showLabels) ...[
                        const SizedBox(height: Space.xs),
                        AnimatedDefaultTextStyle(
                          duration: context.motion(MadarMotion.short),
                          style: (text.labelSmall ?? const TextStyle()).copyWith(
                            color: value == m ? t.textPrimary : t.textTertiary,
                            fontWeight: value == m ? FontWeight.w600 : FontWeight.w400,
                          ),
                          child: Text(labels[m - 1], maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
