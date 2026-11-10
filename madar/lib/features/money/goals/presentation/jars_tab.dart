import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import '../data/goals_providers.dart';
import '../domain/goals_snapshot.dart';
import 'astrolabe_ring.dart';
import 'goals_actions.dart';
import 'goals_tiles.dart';
import 'goals_ui.dart';

/// Savings jars: the overall ring, then every active jar (drag to reorder),
/// then the archived ones.
class JarsTab extends ConsumerStatefulWidget {
  const JarsTab({super.key});

  @override
  ConsumerState<JarsTab> createState() => _JarsTabState();
}

class _JarsTabState extends ConsumerState<JarsTab> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final snap = ref.watch(goalsSnapshotProvider);
    if (snap == null) return const Center(child: OrbitLoader());
    final jars = snap.jars;
    final archived = snap.archivedJars;
    return ReorderableGlassList<JarView>(
      items: jars,
      itemKey: (j) => j.id,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, goalsTabBottomPadding),
      spacing: Space.s,
      itemBorderRadius: BorderRadius.circular(context.tokens.radiusL),
      header: jars.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: Space.m),
              child: JarsSummary(snapshot: snap),
            ),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (jars.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Space.l),
              child: AnimatedEmptyState(
                kind: EmptyStateKind.emptyList,
                title: l.goalsJarsEmptyTitle,
                body: l.goalsJarsEmptyBody,
                actionLabel: l.goalsJarNew,
                actionIcon: Icons.add_rounded,
                onAction: () => GoalsActions(context, ref).addJar(),
              ),
            ),
          if (archived.isNotEmpty) ...[
            const SizedBox(height: Space.s),
            GoalsSectionTitle(
              l.goalsArchivedJars,
              count: MadarFormatter.of(context).formatInt(archived.length),
              color: context.tokens.textSecondary,
              trailing: MadarButton(
                label: _showArchived ? l.goalsHide : l.goalsShow,
                variant: MadarButtonVariant.ghost,
                size: MadarButtonSize.small,
                sfx: _showArchived ? Sfx.toggleOff : Sfx.toggleOn,
                onPressed: () => setState(() => _showArchived = !_showArchived),
              ),
            ),
            AnimatedSize(
              duration: context.motion(MadarMotion.medium),
              curve: MadarMotion.emphasized,
              alignment: AlignmentDirectional.topCenter,
              child: _showArchived
                  ? Column(
                      children: [
                        for (final j in archived)
                          Padding(
                            padding: const EdgeInsets.only(bottom: Space.s),
                            child: JarTile(jar: j),
                          ),
                      ],
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
          if (jars.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Space.m),
              child: Text(
                l.goalsJarsHint,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.tokens.textTertiary),
              ),
            ),
        ],
      ),
      onReorder: (order) => ref.read(goalsServiceProvider).reorderJars([for (final j in order) j.id]),
      itemBuilder: (context, jar, index, grip) => JarTile(jar: jar, grip: grip),
    );
  }
}

/// The jars' headline: an astrolabe ring of everything saved against every
/// target (base currency), and what the deadlines ask for this month.
class JarsSummary extends ConsumerWidget {
  const JarsSummary({super.key, required this.snapshot});

  final GoalsSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final texts = goalsTexts(context, ref);
    final saved = snapshot.jarsSavedBaseMilli;
    final target = snapshot.jarsTargetBaseMilli;
    final need = snapshot.jarsMonthlyNeedBaseMilli;
    final progress = snapshot.jarsProgress;
    final reached = snapshot.jars.where((j) => j.plan.reached).length;
    return GoalsHeaderCard(
      seed: 1.7,
      child: Row(
        children: [
          AstrolabeProgressRing(
            progress: progress,
            size: 112,
            reached: target > 0 && progress >= 1,
            semanticLabel: l.goalsOverallProgress(texts.percent(progress)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  texts.percent(progress),
                  style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: t.textPrimary),
                ),
                Text(l.goalsOfTargets, style: text.labelSmall?.copyWith(color: t.textTertiary)),
              ],
            ),
          ),
          const SizedBox(width: Space.l),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GoalsFigure(
                  label: l.goalsSavedInJars,
                  value: texts.base(saved),
                  large: true,
                  caption: target > 0 ? l.goalsOfTotal(texts.base(target)) : null,
                ),
                const SizedBox(height: Space.m),
                if (need > 0)
                  GoalsFigure(label: l.goalsNeededThisMonth, value: texts.base(need), color: t.gold)
                else if (reached > 0)
                  GoalsPill(
                    label: texts.fmt.localizeDigits(l.goalsJarsReachedCount(reached, texts.fmt.formatInt(reached))),
                    color: t.gold,
                    icon: Icons.emoji_events_rounded,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
