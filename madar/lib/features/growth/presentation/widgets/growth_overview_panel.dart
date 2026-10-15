import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../domain/growth_goal.dart';
import '../growth_texts.dart';
import 'growth_widgets.dart';

/// The Growth screen's hero: average progress of the goals in play, how
/// many are active and done, the streak and the last seven days.
class GrowthOverviewPanel extends StatelessWidget {
  const GrowthOverviewPanel({super.key, required this.overview});

  final GrowthOverview overview;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final texts = GrowthTexts.of(context);
    final fmt = texts.fmt;
    final text = Theme.of(context).textTheme;
    final green = GrowthColors.planet(t);
    final avg = overview.averageProgress;
    final streak = overview.streak;
    final active = overview.active.length;
    final completed = overview.completed.length;
    final counts = [
      fmt.localizeDigits(l.growthActiveGoals(active)),
      if (completed > 0) fmt.localizeDigits(l.growthCompletedGoals(completed)),
    ].join(l.growthSep);
    final inPlay = overview.goals.where((g) => g.row.active).length;
    final loggedToday = overview.loggedTodayCount;

    return GlassPanel(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.l, Space.l, Space.m),
      glowColor: green.withValues(alpha: 0.5),
      seed: 4.2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ProgressRing(
                value: avg ?? 0,
                size: 96,
                strokeWidth: 8,
                color: green,
                gradientEnd: t.gold,
                semanticLabel: l.growthAverageLabel,
                semanticValue: texts.percent(avg ?? 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      texts.percent(avg ?? 0),
                      style: text.titleLarge!.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                    ),
                    SizedBox(
                      width: 64,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(l.growthAverageLabel, style: text.labelSmall, maxLines: 1),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Space.l),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(header: true, child: Text(l.growthOverviewTitle, style: text.headlineSmall)),
                    const SizedBox(height: Space.xxs),
                    Text(counts, style: text.bodySmall),
                    const SizedBox(height: Space.s),
                    GrowthPill(
                      label: fmt.localizeDigits(l.growthStreakDays(streak.current)),
                      icon: Icons.local_fire_department_rounded,
                      color: streak.current > 0 ? t.warning : t.textTertiary,
                    ),
                    if (streak.atRisk) ...[
                      const SizedBox(height: Space.xs),
                      Text(l.growthStreakAtRisk, style: text.labelSmall!.copyWith(color: t.warning)),
                    ] else if (streak.best > streak.current && streak.best > 1) ...[
                      const SizedBox(height: Space.xs),
                      Text(l.growthBestStreak(texts.days(streak.best)), style: text.labelSmall),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.l),
          Row(
            children: [
              Expanded(child: Text(l.growthLastSevenDays, style: text.labelMedium)),
              Text(
                loggedToday == 0 || inPlay == 0
                    ? l.growthNothingToday
                    : l.growthLoggedToday(fmt.formatInt(loggedToday), fmt.formatInt(overview.goals.length)),
                style: text.labelMedium!.copyWith(color: loggedToday > 0 ? t.success : t.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: Space.s),
          WeekStrip(streak: streak, color: green),
        ],
      ),
    );
  }
}
