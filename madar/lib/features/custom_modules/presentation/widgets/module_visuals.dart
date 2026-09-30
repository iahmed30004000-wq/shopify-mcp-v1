import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/interaction/interaction.dart';
import '../../domain/module_schema.dart';

/// Icons of the Custom Modules Builder.
abstract final class ModuleIcons {
  static IconData module(String key) => InteractionIcons.resolve(key, fallback: Icons.auto_awesome_rounded);

  static IconData field(FieldType type) => switch (type) {
    FieldType.text => Icons.short_text_rounded,
    FieldType.number => Icons.tag_rounded,
    FieldType.date => Icons.event_rounded,
    FieldType.time => Icons.schedule_rounded,
    FieldType.checkbox => Icons.check_circle_outline_rounded,
    FieldType.singleSelect => Icons.radio_button_checked_rounded,
    FieldType.multiSelect => Icons.checklist_rounded,
    FieldType.rating => Icons.star_rounded,
    FieldType.currency => Icons.payments_rounded,
  };

  static IconData chart(ModuleChartType type) => switch (type) {
    ModuleChartType.line => Icons.show_chart_rounded,
    ModuleChartType.bar => Icons.bar_chart_rounded,
    ModuleChartType.heat => Icons.calendar_view_month_rounded,
    ModuleChartType.streak => Icons.local_fire_department_rounded,
  };

  static IconData kind(CustomModuleKind kind) =>
      kind == CustomModuleKind.tracker ? Icons.insights_rounded : Icons.checklist_rtl_rounded;
}

/// A module's colour, softened for text on the theme (a pale yellow module
/// would vanish on Pearl): the raw colour for fills and glows, [ink] for
/// text and icons on glass.
class ModuleColors {
  ModuleColors(this.base, MadarTokens t)
    : ink = t.isDark ? _lift(base, 0.72) : _deepen(base, 0.42),
      soft = base.withValues(alpha: t.isDark ? 0.18 : 0.16),
      glow = base.withValues(alpha: t.isDark ? 0.55 : 0.35);

  factory ModuleColors.of(int argb, MadarTokens t) => ModuleColors(Color(argb), t);

  final Color base;
  final Color ink;
  final Color soft;
  final Color glow;

  /// Text / icon colour on a filled [base] surface.
  Color get onBase => base.computeLuminance() > 0.45 ? const Color(0xFF14110C) : Colors.white;

  static Color _lift(Color c, double minLightness) {
    final hsl = HSLColor.fromColor(c);
    return hsl.lightness >= minLightness ? c : hsl.withLightness(minLightness).toColor();
  }

  static Color _deepen(Color c, double maxLightness) {
    final hsl = HSLColor.fromColor(c);
    final s = math.min(1.0, hsl.saturation * 1.05);
    return hsl.lightness <= maxLightness ? c : hsl.withLightness(maxLightness).withSaturation(s).toColor();
  }
}

/// A module's glowing orb: a lit sphere in its colour with its icon, and an
/// optional progress ring (list progress, today's check-in).
class ModuleOrb extends StatelessWidget {
  const ModuleOrb({
    super.key,
    required this.iconKey,
    required this.colorArgb,
    this.size = 48,
    this.progress,
    this.glow = true,
  });

  ModuleOrb.of(ModuleDefinition m, {Key? key, double size = 48, double? progress, bool glow = true})
    : this(key: key, iconKey: m.iconKey, colorArgb: m.colorArgb, size: size, progress: progress, glow: glow);

  final String iconKey;
  final int colorArgb;
  final double size;

  /// 0…1 drawn as a ring around the orb (null = no ring).
  final double? progress;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = ModuleColors.of(colorArgb, t);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _OrbPainter(
            base: c.base,
            glow: glow ? c.glow : null,
            track: t.glassBorder,
            progress: progress,
            dark: t.isDark,
          ),
          child: Center(
            child: Icon(ModuleIcons.module(iconKey), size: size * 0.44, color: c.onBase.withValues(alpha: 0.92)),
          ),
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter({required this.base, required this.glow, required this.track, required this.progress, required this.dark});

  final Color base;
  final Color? glow;
  final Color track;
  final double? progress;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final ring = progress != null;
    final r = size.shortestSide / 2 - (ring ? 5 : 1);
    if (glow != null) {
      canvas.drawCircle(
        center,
        r * 0.98,
        Paint()
          ..color = glow!
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.42),
      );
    }
    final hsl = HSLColor.fromColor(base);
    final light = hsl.withLightness(math.min(0.86, hsl.lightness + 0.2)).toColor();
    final deep = hsl.withLightness(math.max(0.12, hsl.lightness - 0.26)).toColor();
    final sphere = Rect.fromCircle(center: center, radius: r);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.45),
          radius: 1.05,
          colors: [light, base, deep],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(sphere),
    );
    // Specular glint.
    canvas.drawCircle(
      center + Offset(-r * 0.36, -r * 0.42),
      r * 0.2,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.28)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.12),
    );
    // Hairline rim.
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: dark ? 0.18 : 0.35),
    );
    if (ring) {
      final rr = size.shortestSide / 2 - 1.5;
      final rect = Rect.fromCircle(center: center, radius: rr);
      canvas.drawCircle(
        center,
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = track,
      );
      final p = progress!.clamp(0.0, 1.0);
      if (p > 0) {
        canvas.drawArc(
          rect,
          -math.pi / 2,
          math.pi * 2 * p,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.6
            ..strokeCap = StrokeCap.round
            ..color = base,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_OrbPainter old) =>
      old.base != base || old.glow != glow || old.progress != progress || old.track != track || old.dark != dark;
}

/// A small pill: an icon and a short label.
class ModuleBadge extends StatelessWidget {
  const ModuleBadge({super.key, required this.label, required this.color, this.icon, this.filled = false});

  final String label;
  final Color color;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.s, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: filled ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: filled ? 0.5 : 0.28), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelSmall!.copyWith(color: color, fontWeight: FontWeight.w600, height: 1.2),
            ),
          ),
        ],
      ),
    );
  }
}

/// A tiny area sparkline of daily values, oldest → newest in the reading
/// direction (newest at the reading end).
class ModuleSparkline extends StatelessWidget {
  const ModuleSparkline({
    super.key,
    required this.values,
    required this.color,
    this.width = 64,
    this.height = 26,
    this.line = true,
  });

  final List<double> values;
  final Color color;
  final double width;
  final double height;

  /// Draw the stroke and today's dot (false: a soft filled tide only).
  final bool line;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(painter: _SparkPainter(values: values, color: color, rtl: rtl, line: line)),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({required this.values, required this.color, required this.rtl, required this.line});

  final List<double> values;
  final Color color;
  final bool rtl;
  final bool line;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final max = values.fold<double>(0, math.max);
    final n = values.length;
    Offset at(int i) {
      final fx = n == 1 ? 1.0 : i / (n - 1);
      final x = (rtl ? 1 - fx : fx) * (size.width - 4) + 2;
      final y = max <= 0 ? size.height - 3 : size.height - 3 - (values[i] / max) * (size.height - 7);
      return Offset(x, y);
    }

    final stroke = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < n; i++) {
      final p0 = at(i - 1), p1 = at(i);
      final mid = (p0.dx + p1.dx) / 2;
      stroke.cubicTo(mid, p0.dy, mid, p1.dy, p1.dx, p1.dy);
    }
    final area = Path.from(stroke)
      ..lineTo(at(n - 1).dx, size.height)
      ..lineTo(at(0).dx, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: line ? 0.32 : 0.2), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    if (!line) return;
    canvas.drawPath(
      stroke,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
    final last = at(n - 1);
    canvas.drawCircle(last, 3.2, Paint()..color = color);
    canvas.drawCircle(last, 6, Paint()..color = color.withValues(alpha: 0.22));
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.values != values || old.color != color || old.rtl != rtl || old.line != line;
}

/// A section heading inside Custom Modules pages: brass title, optional
/// count and trailing action.
class ModuleSectionTitle extends StatelessWidget {
  const ModuleSectionTitle({super.key, required this.title, this.count, this.trailing, this.color});

  final String title;
  final String? count;
  final Widget? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final c = color ?? t.metalBrass;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: Space.l, bottom: Space.s, start: Space.xs),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle, boxShadow: [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 6)]),
          ),
          const SizedBox(width: Space.s),
          Flexible(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: text.titleSmall!.copyWith(color: c, letterSpacing: 0.3, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: Space.s),
            Text(count!, style: text.labelMedium!.copyWith(color: t.textTertiary)),
          ],
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}
