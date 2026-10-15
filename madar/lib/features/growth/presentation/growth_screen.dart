import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/sound/sound_api.dart';
import '../data/growth_providers.dart';
import '../domain/growth_goal.dart';
import 'growth_actions.dart';
import 'growth_navigation.dart';
import 'widgets/goal_tile.dart';
import 'widgets/growth_overview_panel.dart';

/// The Growth planet's learning goals: an overview (average progress,
/// streak, the last seven days), the goals in progress (drag to reorder;
/// tap to open, "+" to log, swipe to log the usual amount, long-press for
/// edit / duplicate / pause / delete – all with undo), then the completed
/// and paused ones.
class GrowthScreen extends ConsumerWidget {
  const GrowthScreen({super.key, this.animateBackdrop = true});

  /// Pass false in battery-saver mode (also follows the power setting).
  final bool animateBackdrop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final overview = ref.watch(growthOverviewProvider);
    return MadarScaffold(
      title: l.growthTitle,
      backdropSeed: 5.3,
      animateBackdrop:
          animateBackdrop && ref.watch(appSettingsProvider.select((s) => s.powerMode != PowerMode.batterySaver)),
      actions: [
        MadarButton.icon(
          icon: Icons.add_rounded,
          onPressed: () => GrowthActions.create(context, ref),
          semanticLabel: l.growthNewGoal,
          variant: MadarButtonVariant.ghost,
        ),
      ],
      body: switch (overview) {
        AsyncData(:final value) when value.isEmpty => Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: AnimatedEmptyState(
              kind: EmptyStateKind.emptyList,
              title: l.growthEmptyTitle,
              body: MadarFormatter.of(context).localizeDigits(l.growthEmptyBody),
              actionLabel: l.growthEmptyAction,
              actionIcon: Icons.spa_rounded,
              onAction: () => GrowthActions.create(context, ref),
            ),
          ),
        ),
        AsyncData(:final value) => _GoalsList(overview: value),
        AsyncError() => Center(
          child: AnimatedEmptyState(kind: EmptyStateKind.noData, title: l.growthGoalMissing, body: ''),
        ),
        _ => const Center(child: OrbitLoader(size: 40)),
      },
    );
  }
}

class _GoalsList extends ConsumerWidget {
  const _GoalsList({required this.overview});

  final GrowthOverview overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final active = overview.active;
    final completed = overview.completed;
    final paused = overview.paused;

    Widget tile(GrowthGoal g, {Widget? grip}) => GoalTile(
      key: ValueKey(g.id),
      goal: g,
      grip: grip,
      onOpen: () => unawaited(GrowthNavigation.openGoal(context, ref, g.id)),
      onLog: () => GrowthActions.log(context, ref, g),
      onQuickLog: () => GrowthActions.quickLog(context, ref, g, g.usualAmount, toast: false),
      onEdit: () => GrowthActions.edit(context, ref, g),
      onDuplicate: () => GrowthActions.duplicate(context, ref, g),
      onDelete: () => GrowthActions.delete(context, ref, g),
      onTogglePause: () => GrowthActions.togglePause(context, ref, g),
    );

    Widget section(String title, List<GrowthGoal> goals, int start) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: title, padding: const EdgeInsetsDirectional.fromSTEB(0, Space.xl, 0, Space.m)),
        for (final (i, g) in goals.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s),
            child: StaggerItem(index: start + i, child: tile(g)),
          ),
      ],
    );

    return EntranceChoreo(
      id: 'growth',
      child: ReorderableGlassList<GrowthGoal>(
        items: active,
        itemKey: (g) => g.id,
        padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.xxxl + Space.xl),
        spacing: Space.s,
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StaggerItem(index: 0, child: GrowthOverviewPanel(overview: overview)),
            if (active.isNotEmpty)
              StaggerItem(
                index: 1,
                child: SectionHeader(
                  title: l.growthSectionActive,
                  subtitle: active.length > 1 ? l.growthSectionHint : null,
                  actionLabel: l.growthNewGoal,
                  onAction: () => GrowthActions.create(context, ref),
                  padding: const EdgeInsetsDirectional.fromSTEB(0, Space.xl, 0, Space.m),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: Space.l),
                child: StaggerItem(index: 1, child: _NextGoalCard(onCreate: () => GrowthActions.create(context, ref))),
              ),
          ],
        ),
        footer: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (completed.isNotEmpty) section(l.growthSectionCompleted, completed, active.length + 2),
            if (paused.isNotEmpty) section(l.growthSectionPaused, paused, active.length + completed.length + 3),
          ],
        ),
        onReorder: (order) {
          Fx.fire(Sfx.drop);
          unawaited(GrowthActions.reorder(ref, order, rest: [...completed, ...paused]));
        },
        itemBuilder: (context, g, index, grip) => tile(g, grip: grip),
      ),
    );
  }
}

class _NextGoalCard extends StatelessWidget {
  const _NextGoalCard({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    return GlassCard(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.m, Space.m),
      child: Row(
        children: [
          Icon(Icons.explore_rounded, color: t.accent),
          const SizedBox(width: Space.m),
          Expanded(child: Text(l.growthAllActiveDone, style: text.bodyMedium)),
          const SizedBox(width: Space.s),
          MadarButton(
            label: l.growthNewGoal,
            icon: Icons.add_rounded,
            size: MadarButtonSize.small,
            onPressed: onCreate,
          ),
        ],
      ),
    );
  }
}
