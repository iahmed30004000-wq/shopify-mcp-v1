import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/design/tokens.dart';
import '../../../../../core/design/typography.dart';
import '../../../../../core/design/widgets/widgets.dart';
import '../../../../../core/motion/motion_kit.dart';
import '../../../../../core/sound/sound_api.dart';
import '../../domain/budget_plan.dart';

/// Colours of top-level items when they have none of their own: theme
/// tokens only, never status colours (red / amber mean warnings here).
/// The empty part of bars: a neutral veil of the text colour.
Color budgetTrack(MadarTokens t) => t.textPrimary.withValues(alpha: t.isDark ? 0.09 : 0.07);

/// The specular highlight colour of orbs and bars (opaque glass highlight).
Color budgetShine(MadarTokens t) => t.glassHighlight.withValues(alpha: 1);

List<Color> budgetSeriesColors(MadarTokens t) => [
  t.accent,
  t.highlight,
  t.secondary,
  Color.lerp(t.secondary, t.danger, 0.45)!,
  t.info,
  Color.lerp(t.accent, t.highlight, 0.5)!,
];

/// A glass segmented control whose accent thumb springs between the
/// segments (follows the reading direction).
class BudgetSegmented<T> extends StatelessWidget {
  const BudgetSegmented({
    super.key,
    required this.values,
    required this.value,
    required this.labels,
    required this.onChanged,
    this.height = 50,
    this.icons,
  });

  final List<T> values;
  final T value;
  final Map<T, String> labels;
  final Map<T, IconData>? icons;
  final ValueChanged<T> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final dir = Directionality.of(context);
    final index = math.max(0, values.indexOf(value));
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Container(
        height: height,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          color: t.glassFill,
          border: Border.all(color: t.glassBorder),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth / values.length;
            return Stack(
              children: [
                SpringBuilder(
                  value: index.toDouble(),
                  spring: MadarMotion.snappy,
                  builder: (context, v, _) {
                    final x = dir == TextDirection.rtl ? constraints.maxWidth - w * (v + 1) : w * v;
                    return Positioned(
                      left: x,
                      top: 0,
                      bottom: 0,
                      width: w,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color.lerp(t.accent, t.starTint, 0.18)!, t.accent],
                          ),
                          boxShadow: t.isDark
                              ? [BoxShadow(color: t.accentGlow.withValues(alpha: 0.35), blurRadius: 14)]
                              : null,
                        ),
                      ),
                    );
                  },
                ),
                Row(
                  children: [
                    for (final v in values)
                      Expanded(
                        child: MadarPressable(
                          onTap: v == value ? null : () => onChanged(v),
                          sfx: Sfx.navigate,
                          selected: v == value,
                          semanticLabel: labels[v],
                          excludeChildSemantics: true,
                          focusRadius: BorderRadius.circular(99),
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: context.motion(MadarMotion.short),
                              style: text.labelLarge!.copyWith(
                                color: v == value ? t.textOnAccent : t.textSecondary,
                                height: 1.2,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (icons?[v] case final icon?) ...[
                                    Icon(icon, size: 17, color: v == value ? t.textOnAccent : t.textSecondary),
                                    const SizedBox(width: Space.xs + 2),
                                  ],
                                  Flexible(child: Text(labels[v] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A small rounded badge (warnings, statuses) tinted with [color].
class BudgetBadge extends StatelessWidget {
  const BudgetBadge({super.key, required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.s, 3, Space.s + 2, 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        color: color.withValues(alpha: t.isDark ? 0.16 : 0.12),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: Space.xs)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelSmall?.copyWith(
                color: t.isDark ? Color.lerp(color, t.textPrimary, 0.25) : color,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A glowing orb marking an item's colour (roots) or a small dot (sub-items).
class BudgetOrb extends StatelessWidget {
  const BudgetOrb({super.key, required this.color, this.size = 12, this.glow = true});

  final Color color;
  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.4),
          colors: [Color.lerp(color, budgetShine(t), t.isDark ? 0.45 : 0.3)!, color],
        ),
        boxShadow: glow && t.isDark ? [BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: size * 0.8)] : null,
      ),
    );
  }
}

/// One segment of an [AllocationStrip].
typedef AllocationSegment = ({String id, double share, Color color});

/// A horizontal bar split into the top-level items' shares of the plan
/// (starts at the reading-direction start).
class AllocationStrip extends StatelessWidget {
  const AllocationStrip({super.key, required this.segments, this.height = 10, this.semanticLabel});

  final List<AllocationSegment> segments;
  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      label: semanticLabel,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: context.motion(MadarMotion.long),
          curve: MadarMotion.decelerate,
          builder: (context, p, _) => CustomPaint(
            painter: _AllocationPainter(
              segments: segments,
              progress: p,
              track: budgetTrack(t),
              rtl: Directionality.of(context) == TextDirection.rtl,
              glow: t.isDark,
              shine: budgetShine(t),
            ),
          ),
        ),
      ),
    );
  }
}

class _AllocationPainter extends CustomPainter {
  _AllocationPainter({
    required this.segments,
    required this.progress,
    required this.track,
    required this.rtl,
    required this.glow,
    required this.shine,
  });

  final List<AllocationSegment> segments;
  final double progress;
  final Color track;
  final bool rtl;
  final bool glow;
  final Color shine;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(size.height / 2);
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, r), Paint()..color = track);
    const gap = 2.0;
    final total = segments.fold<double>(0, (a, s) => a + s.share);
    if (total <= 0) return;
    var x = 0.0;
    final usable = size.width * progress;
    for (final s in segments) {
      final w = usable * s.share / math.max(total, 1);
      if (w <= 0.5) continue;
      final left = rtl ? size.width - x - w : x;
      final rect = Rect.fromLTWH(left + gap / 2, 0, math.max(0, w - gap), size.height);
      final rr = RRect.fromRectAndRadius(rect, r);
      if (glow) {
        canvas.drawRRect(
          rr,
          Paint()
            ..color = s.color.withValues(alpha: 0.45)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }
      canvas.drawRRect(
        rr,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(s.color, shine, 0.18)!, s.color],
          ).createShader(rect),
      );
      x += w;
    }
  }

  @override
  bool shouldRepaint(_AllocationPainter old) =>
      old.progress != progress || old.segments != segments || old.track != track || old.rtl != rtl;
}

/// Spend vs plan bar: the spent part (in [color]), a tick at the plan when
/// the spend or projection runs past it, and a faint projected tail.
class SpendBar extends StatelessWidget {
  const SpendBar({
    super.key,
    required this.plannedMilli,
    required this.spentMilli,
    required this.color,
    this.projectedMilli,
    this.height = 8,
  });

  final int plannedMilli;
  final int spentMilli;
  final int? projectedMilli;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: context.motion(MadarMotion.long),
        curve: MadarMotion.decelerate,
        builder: (context, p, _) => CustomPaint(
          painter: _SpendBarPainter(
            planned: plannedMilli.toDouble(),
            spent: spentMilli.toDouble(),
            projected: projectedMilli?.toDouble(),
            progress: p,
            color: color,
            track: budgetTrack(t),
            tick: t.textPrimary.withValues(alpha: 0.75),
            rtl: Directionality.of(context) == TextDirection.rtl,
            glow: t.isDark,
            shine: budgetShine(t),
          ),
        ),
      ),
    );
  }
}

class _SpendBarPainter extends CustomPainter {
  _SpendBarPainter({
    required this.planned,
    required this.spent,
    required this.projected,
    required this.progress,
    required this.color,
    required this.track,
    required this.tick,
    required this.rtl,
    required this.glow,
    required this.shine,
  });

  final double planned;
  final double spent;
  final double? projected;
  final double progress;
  final Color color;
  final Color track;
  final Color tick;
  final bool rtl;
  final bool glow;
  final Color shine;

  Rect _span(Size size, double from, double to) {
    final a = from * size.width;
    final b = to * size.width;
    return rtl ? Rect.fromLTRB(size.width - b, 0, size.width - a, size.height) : Rect.fromLTRB(a, 0, b, size.height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(size.height / 2);
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, r), Paint()..color = track);
    final scale = [planned, spent, projected ?? 0].reduce(math.max);
    if (scale <= 0) return;
    final spentF = spent / scale * progress;
    final projF = projected == null ? null : projected! / scale * progress;
    if (projF != null && projF > spentF) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(_span(size, 0, projF), r),
        Paint()..color = color.withValues(alpha: 0.22),
      );
    }
    if (spentF > 0) {
      final rect = _span(size, 0, math.max(spentF, size.height / size.width));
      final rr = RRect.fromRectAndRadius(rect, r);
      if (glow) {
        canvas.drawRRect(
          rr,
          Paint()
            ..color = color.withValues(alpha: 0.5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }
      canvas.drawRRect(
        rr,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(color, shine, 0.2)!, color],
          ).createShader(rect),
      );
    }
    if (planned > 0 && planned < scale) {
      final x = planned / scale * size.width;
      final dx = rtl ? size.width - x : x;
      canvas.drawLine(
        Offset(dx, -2),
        Offset(dx, size.height + 2),
        Paint()
          ..color = tick
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_SpendBarPainter old) =>
      old.planned != planned ||
      old.spent != spent ||
      old.projected != projected ||
      old.progress != progress ||
      old.color != color ||
      old.rtl != rtl;
}

/// Big tabular amount text (numerals style).
class BudgetAmountText extends StatelessWidget {
  const BudgetAmountText(this.text, {super.key, this.size = 16, this.color, this.weight = FontWeight.w600});

  final String text;
  final double size;
  final Color? color;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.fade,
      softWrap: false,
      style: MadarTypography.numerals(t, size: size, color: color ?? t.textPrimary).copyWith(fontWeight: weight),
    );
  }
}

/// A pill showing a status with its colour dot (spending states).
class BudgetStatusPill extends StatelessWidget {
  const BudgetStatusPill({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final t = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BudgetOrb(color: color, size: 8),
        const SizedBox(width: Space.xs + 2),
        Text(label, style: text.labelMedium?.copyWith(color: t.textSecondary)),
      ],
    );
  }
}

/// Glass icon button used for the period navigator (mirrors in RTL).
class BudgetNavButton extends StatelessWidget {
  const BudgetNavButton({super.key, required this.icon, required this.onTap, required this.semanticLabel});

  final IconData icon;
  final VoidCallback? onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final enabled = onTap != null;
    return MadarPressable(
      onTap: onTap,
      enabled: enabled,
      sfx: Sfx.navigate,
      semanticLabel: semanticLabel,
      focusRadius: BorderRadius.circular(99),
      child: SizedBox.square(
        dimension: 44,
        child: Center(
          child: AnimatedOpacity(
            duration: context.motion(MadarMotion.short),
            opacity: enabled ? 1 : 0.3,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.glassFill,
                border: Border.all(color: t.glassBorder),
              ),
              child: Icon(icon, size: 20, color: t.gold),
            ),
          ),
        ),
      ),
    );
  }
}

/// The colour of every line: a stored colour, else the theme series by
/// top-level position; sub-items inherit their parent's colour.
Map<String, Color> budgetLineColors(BudgetPlan plan, MadarTokens t, {Map<String, int> stored = const {}}) {
  final series = budgetSeriesColors(t);
  final out = <String, Color>{};
  var i = 0;
  for (final l in plan.lines) {
    final own = stored[l.id];
    if (l.depth == 0) {
      out[l.id] = own != null ? Color(own) : series[i % series.length];
      i++;
    } else {
      out[l.id] = own != null ? Color(own) : out[l.parentId] ?? series.first;
    }
  }
  return out;
}
