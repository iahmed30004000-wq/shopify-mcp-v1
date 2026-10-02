import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/interaction/src/pressable.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import '../../domain/goal_math.dart';
import '../../domain/growth_days.dart';
import '../../domain/growth_goal.dart';
import '../../domain/growth_streaks.dart';
import '../growth_texts.dart';

/// A goal's progress ring in its colour: the percentage inside (or a check
/// once complete, a pause mark while paused, the unit's icon when small).
class GoalRing extends StatelessWidget {
  const GoalRing({super.key, required this.goal, this.size = 52, this.strokeWidth = 4.5, this.iconOnly = false});

  final GrowthGoal goal;
  final double size;
  final double strokeWidth;

  /// The unit's icon instead of the percentage.
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final texts = GrowthTexts.of(context);
    final text = Theme.of(context).textTheme;
    final color = GrowthColors.goal(t, goal.color);
    final s = goal.stats;
    final paused = s.pace == GoalPace.paused;
    final Widget child;
    if (s.completed) {
      child = Icon(Icons.check_rounded, size: size * 0.42, color: t.success);
    } else if (paused) {
      child = Icon(Icons.pause_rounded, size: size * 0.4, color: t.textTertiary);
    } else if (iconOnly || size < 44) {
      child = Icon(GrowthColors.unitIcon(goal.unit), size: size * 0.42, color: color);
    } else {
      child = FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: EdgeInsets.all(strokeWidth + 2),
          child: Text(
            texts.percent(s.fraction),
            maxLines: 1,
            style: (size >= 64 ? text.titleMedium : text.labelMedium)!.copyWith(
              color: t.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      );
    }
    return ProgressRing(
      value: s.progress,
      size: size,
      strokeWidth: strokeWidth,
      color: paused ? t.textTertiary : color,
      gradientEnd: paused ? null : GrowthColors.glow(t, color),
      glow: s.completed,
      semanticLabel: goal.name,
      semanticValue: texts.percent(s.fraction),
      child: child,
    );
  }
}

/// A small tinted label ("على المسار", "٥ أيام متتالية").
class GrowthPill extends StatelessWidget {
  const GrowthPill({super.key, required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.s, Space.xxs, Space.m, Space.xxs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: t.isDark ? 0.16 : 0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: Space.xs)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelMedium!.copyWith(color: t.isDark ? color : Color.lerp(color, t.textPrimary, 0.25)),
            ),
          ),
        ],
      ),
    );
  }
}

/// The pace pill of a goal.
class PacePill extends StatelessWidget {
  const PacePill({super.key, required this.pace});

  final GoalPace pace;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GrowthPill(
      label: GrowthTexts.of(context).paceLabel(pace),
      color: GrowthColors.pace(t, pace),
      icon: GrowthColors.paceIcon(pace),
    );
  }
}

/// The last seven days as lanterns: lit where progress was logged; today's
/// is ringed. Oldest on the reading-direction start.
class WeekStrip extends StatelessWidget {
  const WeekStrip({super.key, required this.streak, this.color, this.dotSize = 26});

  final GrowthStreak streak;
  final Color? color;
  final double dotSize;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final texts = GrowthTexts.of(context);
    final text = Theme.of(context).textTheme;
    final lang = Localizations.localeOf(context).languageCode;
    final c = color ?? GrowthColors.planet(t);
    final days = streak.lastDays(7);
    final narrow = DateFormat('EEEEE', lang);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < 7; i++)
          Builder(
            builder: (context) {
              final day = GrowthDays.add(streak.today, i - 6);
              final lit = days[i];
              final isToday = i == 6;
              final name = texts.dayLabel(day, streak.today);
              return Semantics(
                label: lit ? texts.l.growthDayActive(name) : texts.l.growthDayIdle(name),
                excludeSemantics: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: context.motion(MadarMotion.medium),
                      width: dotSize,
                      height: dotSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: lit
                            ? RadialGradient(colors: [GrowthColors.glow(t, c), c], stops: const [0.1, 1])
                            : null,
                        color: lit ? null : t.glassFill,
                        border: Border.all(
                          color: isToday ? (lit ? t.textPrimary.withValues(alpha: 0.7) : c) : t.glassBorder,
                          width: isToday ? 1.6 : 1,
                        ),
                        boxShadow: lit
                            ? [BoxShadow(color: c.withValues(alpha: t.isDark ? 0.45 : 0.25), blurRadius: 10)]
                            : null,
                      ),
                      child: lit ? Icon(Icons.check_rounded, size: dotSize * 0.55, color: t.space0) : null,
                    ),
                    const SizedBox(height: Space.xs),
                    Text(
                      narrow.format(day),
                      style: text.labelSmall!.copyWith(
                        color: isToday ? t.textPrimary : t.textTertiary,
                        fontWeight: isToday ? FontWeight.w700 : null,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

/// One-tap "+amount" chips.
class QuickAmountChips extends StatelessWidget {
  const QuickAmountChips({
    super.key,
    required this.goal,
    required this.onLog,
    this.onOther,
    this.selected,
    this.dense = false,
  });

  final GrowthGoal goal;
  final ValueChanged<double> onLog;

  /// Shows an "other amount" chip.
  final VoidCallback? onOther;

  /// Highlights the chip of this amount (the log sheet).
  final double? selected;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final texts = GrowthTexts.of(context);
    final color = GrowthColors.goal(t, goal.color);
    return Wrap(
      spacing: Space.s,
      runSpacing: Space.s,
      children: [
        for (final a in goal.quickAmounts)
          AmountChip(
            label: texts.signed(a),
            semanticLabel: texts.l.growthLogQuick(texts.amount(goal.unit, a)),
            color: color,
            selected: selected != null && (selected! - a).abs() < 1e-9,
            dense: dense,
            onTap: () => onLog(a),
          ),
        if (onOther != null)
          AmountChip(
            label: texts.l.growthLogOther,
            icon: Icons.tune_rounded,
            color: t.textSecondary,
            dense: dense,
            onTap: onOther!,
            sfx: null,
          ),
      ],
    );
  }
}

/// A glass pill for an amount.
class AmountChip extends StatelessWidget {
  const AmountChip({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
    this.semanticLabel,
    this.icon,
    this.selected = false,
    this.dense = false,
    this.sfx = Sfx.tap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;
  final String? semanticLabel;
  final IconData? icon;
  final bool selected;
  final bool dense;
  final Sfx? sfx;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return KitPressable(
      onTap: onTap,
      sfx: sfx,
      selected: selected,
      semanticLabel: semanticLabel ?? label,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: context.motion(MadarMotion.short),
        constraints: BoxConstraints(minHeight: dense ? 36 : 44, minWidth: dense ? 48 : 56),
        padding: EdgeInsetsDirectional.symmetric(horizontal: dense ? Space.m : Space.l),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: t.isDark ? 0.26 : 0.16) : t.glassFill,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? color : color.withValues(alpha: 0.45), width: selected ? 1.5 : 1),
          boxShadow: selected ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 12)] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, size: 16, color: color), const SizedBox(width: Space.xs)],
            Text(
              label,
              style: (dense ? text.labelLarge : text.titleSmall)!.copyWith(
                color: t.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A figure with its label and caption (stats strips).
class GrowthStat extends StatelessWidget {
  const GrowthStat({
    super.key,
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    this.caption,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: [label, value, ?caption].join(', '),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.xs),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: Space.xs),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, maxLines: 1, style: text.titleLarge!.copyWith(color: t.textPrimary)),
            ),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.labelMedium),
            if (caption != null)
              Text(
                caption!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: text.labelSmall,
              ),
          ],
        ),
      ),
    );
  }
}

/// Header row of a card: icon, title and an optional trailing link.
class GrowthCardHeader extends StatelessWidget {
  const GrowthCardHeader({super.key, required this.icon, required this.title, this.trailing, this.color});

  final IconData icon;
  final String title;
  final Widget? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: color ?? t.accent),
        const SizedBox(width: Space.s),
        Expanded(
          child: Semantics(header: true, child: Text(title, style: text.titleMedium)),
        ),
        ?trailing,
      ],
    );
  }
}

/// A tappable "see all ›" link.
class GrowthLink extends StatelessWidget {
  const GrowthLink({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return MadarPressable(
      onTap: onTap,
      sfx: null,
      semanticLabel: label,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: Space.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: text.labelLarge!.copyWith(color: t.accent)),
            // Mirrored automatically in RTL.
            Icon(Icons.chevron_right_rounded, size: 18, color: t.accent),
          ],
        ),
      ),
    );
  }
}
