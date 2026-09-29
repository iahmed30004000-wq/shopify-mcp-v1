import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import '../../domain/goal_math.dart';
import '../../domain/growth_goal.dart';
import '../../domain/growth_units.dart';
import '../growth_texts.dart';
import 'growth_widgets.dart';

/// The goal page's hero: a large ring with the rolling percentage, the
/// status pill, what is left (or exceeded), the one-tap amounts and "log
/// progress" (or "resume" while paused).
class GoalHero extends StatelessWidget {
  const GoalHero({
    super.key,
    required this.goal,
    required this.onQuickLog,
    required this.onLog,
    required this.onResume,
  });

  final GrowthGoal goal;
  final ValueChanged<double> onQuickLog;
  final VoidCallback onLog;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final texts = GrowthTexts.of(context);
    final text = Theme.of(context).textTheme;
    final s = goal.stats;
    final color = GrowthColors.goal(t, goal.color);
    final paused = s.pace == GoalPace.paused;
    final unitName = goal.unit.isEmpty ? null : texts.unitName(goal.unit);
    final String line;
    if (s.completed && s.overshoot > 0) {
      line = l.growthExceeded(texts.amount(goal.unit, s.overshoot));
    } else if (s.completed) {
      line = l.growthLineCompleted(texts.date(s.completedOn ?? s.today, today: s.today));
    } else {
      line = l.growthRemaining(texts.amount(goal.unit, s.remaining));
    }

    return GlassPanel(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.xl, Space.l, Space.l),
      glowColor: color.withValues(alpha: 0.55),
      seed: 2.6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: ProgressRing(
              value: s.progress,
              size: 168,
              strokeWidth: 12,
              color: paused ? t.textTertiary : color,
              gradientEnd: paused ? null : GrowthColors.glow(t, color),
              glow: !paused,
              semanticLabel: goal.name,
              semanticValue: '${texts.percent(s.fraction)}, ${texts.progressOf(goal)}',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    // Counts up to the new percentage (instant under reduced motion).
                    tween: Tween(end: s.fraction),
                    duration: context.motion(MadarMotion.long),
                    curve: MadarMotion.emphasized,
                    builder: (context, v, _) => Text(
                      texts.percent(v),
                      style: text.titleLarge!.copyWith(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  Text(
                    l.growthProgressOf(texts.number(s.current), texts.number(goal.row.target)),
                    style: text.labelLarge!.copyWith(color: t.textSecondary),
                  ),
                  if (unitName != null)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 110),
                      child: Text(
                        unitName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: text.labelSmall,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Space.l),
          Center(child: PacePill(pace: s.pace)),
          const SizedBox(height: Space.s),
          Text(
            line,
            textAlign: TextAlign.center,
            style: text.bodyMedium!.copyWith(color: t.textSecondary),
          ),
          const SizedBox(height: Space.l),
          if (paused)
            MadarButton(
              label: l.growthResume,
              icon: Icons.play_arrow_rounded,
              variant: MadarButtonVariant.secondary,
              expand: true,
              sfx: Sfx.toggleOn,
              onPressed: onResume,
            )
          else ...[
            Center(
              child: QuickAmountChips(goal: goal, onLog: onQuickLog),
            ),
            const SizedBox(height: Space.m),
            MadarButton(
              label: l.growthLogProgress,
              icon: Icons.add_rounded,
              expand: true,
              sfx: Sfx.tap,
              onPressed: onLog,
            ),
          ],
        ],
      ),
    );
  }
}

/// Streak, active days and deadline of a goal.
class GoalStatsStrip extends StatelessWidget {
  const GoalStatsStrip({super.key, required this.goal});

  final GrowthGoal goal;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final texts = GrowthTexts.of(context);
    final s = goal.stats;
    final streak = goal.streak;
    final deadline = s.deadline;
    final String? deadlineCaption;
    if (deadline == null) {
      deadlineCaption = l.growthStartedOn(texts.date(s.start, today: s.today));
    } else if (s.completed) {
      deadlineCaption = null;
    } else if ((s.daysLeft ?? 0) > 0) {
      deadlineCaption = l.growthDaysLeft(texts.days(s.daysLeft!));
    } else {
      deadlineCaption = l.growthPaceOverdue;
    }
    return GlassCard(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.s, Space.m, Space.s, Space.m),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: GrowthStat(
                icon: Icons.local_fire_department_rounded,
                color: t.warning,
                value: texts.fmt.formatInt(streak.current),
                label: l.growthStreakLabel,
                caption: l.growthBestStreak(texts.days(streak.best)),
              ),
            ),
            VerticalDivider(color: t.glassBorder, width: 1),
            Expanded(
              child: GrowthStat(
                icon: Icons.event_available_rounded,
                color: t.success,
                value: texts.fmt.formatInt(streak.days.length),
                label: l.growthActiveDaysLabel,
                caption: l.growthOfDays(texts.days(s.elapsedDays)),
              ),
            ),
            VerticalDivider(color: t.glassBorder, width: 1),
            Expanded(
              child: GrowthStat(
                icon: Icons.flag_circle_rounded,
                color: t.accent,
                value: deadline == null ? l.growthStatsDeadlineNone : texts.date(deadline, today: s.today),
                label: l.growthDeadlineLabel,
                caption: deadlineCaption,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Needed vs actual pace, the projected finish and the position against
/// the straight-line plan.
class GoalPaceCard extends StatelessWidget {
  const GoalPaceCard({super.key, required this.goal});

  final GrowthGoal goal;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final texts = GrowthTexts.of(context);
    final text = Theme.of(context).textTheme;
    final s = goal.stats;
    final u = goal.unit;
    final paceColor = GrowthColors.pace(t, s.pace);
    final color = GrowthColors.goal(t, goal.color);
    final today = s.today;

    final children = <Widget>[
      GrowthCardHeader(icon: Icons.speed_rounded, title: l.growthPaceTitle, color: color),
      const SizedBox(height: Space.m),
    ];

    if (s.completed) {
      children.add(
        _InfoRow(
          icon: Icons.verified_rounded,
          color: t.success,
          text: l.growthPaceDoneHint,
          caption: s.overshoot > 0 ? l.growthExceeded(texts.amount(u, s.overshoot)) : null,
        ),
      );
    } else {
      final actual = s.actualPerDay > 0 ? texts.rate(u, s.actualPerDay) : l.growthNoPaceYet;
      // The weekly equivalent too, unless the rate is already weekly.
      String? weekly(double perDay, {bool needed = false}) {
        if (perDay <= 0 || GrowthRate.of(perDay, u, roundUp: needed).perWeek) return null;
        return texts.weekly(u, perDay, needed: needed);
      }

      final actualCaption = [?weekly(s.actualPerDay), l.growthActualWindow(texts.days(s.paceWindow))].join(l.growthSep);
      final deadline = s.deadline;
      if (deadline == null) {
        children.add(
          Row(
            children: [
              Expanded(
                child: _RateBlock(label: l.growthActualLabel, value: actual, caption: actualCaption, color: paceColor),
              ),
            ],
          ),
        );
      } else {
        final overdue = s.pace == GoalPace.overdue;
        final needed = overdue
            ? l.growthRemaining(texts.amount(u, s.remaining))
            : texts.rate(u, s.neededPerDay ?? 0, needed: true);
        final neededCaption = overdue
            ? l.growthOverdueBy(texts.days(s.daysOverdue))
            : [
                ?weekly(s.neededPerDay ?? 0, needed: true),
                l.growthNeededUntil(texts.date(deadline, today: today)),
              ].join(l.growthSep);
        children
          ..add(
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _RateBlock(
                      label: l.growthNeededLabel,
                      value: needed,
                      caption: neededCaption,
                      color: t.textSecondary,
                    ),
                  ),
                  VerticalDivider(color: t.glassBorder, width: Space.xl),
                  Expanded(
                    child: _RateBlock(
                      label: l.growthActualLabel,
                      value: actual,
                      caption: actualCaption,
                      color: paceColor,
                    ),
                  ),
                ],
              ),
            ),
          )
          ..add(const SizedBox(height: Space.m));
        if (!overdue && s.neededPerDay != null) {
          children.add(_CompareBars(needed: s.neededPerDay!, actual: s.actualPerDay, color: paceColor));
        }
      }
      children.add(const SizedBox(height: Space.m));
      final finish = s.projectedFinish;
      final slip = s.projectedSlip;
      String? caption;
      Color captionColor = t.textTertiary;
      if (finish != null && slip != null) {
        if (slip < 0) {
          caption = l.growthProjectionEarly(texts.days(-slip));
          captionColor = t.success;
        } else if (slip > 0) {
          caption = l.growthProjectionLate(texts.days(slip));
          captionColor = t.warning;
        } else {
          caption = l.growthProjectionOnDay;
          captionColor = t.success;
        }
      }
      children.add(
        _InfoRow(
          icon: Icons.flag_rounded,
          color: color,
          label: l.growthProjectedLabel,
          text: finish == null
              ? l.growthProjectionNone
              : texts.fmt.formatDate(finish, style: _dateStyle(finish, today)),
          caption: caption,
          captionColor: captionColor,
        ),
      );
      final vs = s.vsPlan;
      if (vs != null && s.pace != GoalPace.overdue && vs.abs() >= goal.unit.granularity) {
        children
          ..add(const SizedBox(height: Space.s))
          ..add(
            _InfoRow(
              icon: vs < 0 ? Icons.south_east_rounded : Icons.north_east_rounded,
              color: vs < 0 ? t.warning : t.success,
              text: vs < 0 ? l.growthPlanBehind(texts.approx(u, -vs)) : l.growthPlanAhead(texts.approx(u, vs)),
            ),
          );
      }
      if (deadline == null) {
        children
          ..add(const SizedBox(height: Space.s))
          ..add(Text(l.growthPaceNoDeadlineHint, style: text.labelSmall));
      }
    }

    return GlassCard(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.l),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }

  static MadarDateStyle _dateStyle(DateTime d, DateTime today) =>
      d.year == today.year ? MadarDateStyle.weekdayDayMonth : MadarDateStyle.medium;
}

class _RateBlock extends StatelessWidget {
  const _RateBlock({required this.label, required this.value, required this.color, this.caption});

  final String label;
  final String value;
  final String? caption;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: [label, value, ?caption].join(', '),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.labelMedium),
          const SizedBox(height: Space.xxs),
          Text(value, style: text.titleMedium!.copyWith(color: color == t.textSecondary ? t.textPrimary : color)),
          if (caption != null) Text(caption!, style: text.labelSmall, maxLines: 2),
        ],
      ),
    );
  }
}

/// Two bars on one scale: the pace needed and the pace kept.
class _CompareBars extends StatelessWidget {
  const _CompareBars({required this.needed, required this.actual, required this.color});

  final double needed;
  final double actual;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scale = math.max(needed, actual) * 1.08;
    Widget bar(double v, Color c, {bool glow = false}) => LayoutBuilder(
      builder: (context, box) => Stack(
        children: [
          Container(
            height: 8,
            decoration: BoxDecoration(color: t.glassFill, borderRadius: BorderRadius.circular(4)),
          ),
          AnimatedContainer(
            duration: context.motion(MadarMotion.long),
            curve: MadarMotion.emphasized,
            height: 8,
            width: scale <= 0 ? 0 : box.maxWidth * (v / scale).clamp(0.0, 1.0),
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(4),
              boxShadow: glow ? [BoxShadow(color: c.withValues(alpha: 0.45), blurRadius: 8)] : null,
            ),
          ),
        ],
      ),
    );
    return ExcludeSemantics(
      child: Column(
        children: [
          bar(needed, t.textTertiary.withValues(alpha: 0.7)),
          const SizedBox(height: Space.xs),
          bar(actual, color, glow: true),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.color,
    required this.text,
    this.label,
    this.caption,
    this.captionColor,
  });

  final IconData icon;
  final Color color;
  final String? label;
  final String text;
  final String? caption;
  final Color? captionColor;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: [?label, text, ?caption].join(', '),
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: t.isDark ? 0.16 : 0.1),
              border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (label != null) Text(label!, style: theme.labelMedium),
                Text(text, style: theme.bodyMedium!.copyWith(color: t.textPrimary)),
                if (caption != null)
                  Text(caption!, style: theme.labelMedium!.copyWith(color: captionColor ?? t.textTertiary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
