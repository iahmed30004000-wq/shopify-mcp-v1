import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart' show AppliedPlanRow;
import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/sound/sound_api.dart';
import '../data/ai_bridge_providers.dart';
import 'ai_bridge_texts.dart';
import 'widgets/plan_widgets.dart';

/// The plans he brought back, newest first.
///
/// Opening one re-reads its original payload against his data **as it is
/// now** ([PlanApplyService.reopen]), which is why an old plan is honest:
/// a suggestion he never decided may have become ready, a before/after is
/// measured against today's number, and nothing is replayed from a cache.
class PlanHistoryScreen extends ConsumerWidget {
  const PlanHistoryScreen({super.key, this.animateBackdrop = true, this.onOpenPlan, this.onImport});

  final bool animateBackdrop;
  final void Function(String planId)? onOpenPlan;
  final VoidCallback? onImport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final plans = ref.watch(planHistoryProvider).value;

    return MadarScaffold(
      title: l.aiPlanHistoryTitle,
      backdropSeed: 9,
      animateBackdrop: animateBackdrop,
      floatingAction: onImport == null
          ? null
          : MadarButton.icon(
              key: const ValueKey('aiPlan.history.import'),
              icon: Icons.move_to_inbox_rounded,
              semanticLabel: l.aiPlanImportTitle,
              variant: MadarButtonVariant.primary,
              size: MadarButtonSize.large,
              sfx: Sfx.navigate,
              onPressed: onImport,
            ),
      body: plans == null
          ? const Center(child: OrbitLoader())
          : EntranceChoreo(
              id: 'aiPlan-history',
              child: plans.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.all(Space.gutter),
                        child: AnimatedEmptyState(
                          key: const ValueKey('aiPlan.history.empty'),
                          kind: EmptyStateKind.emptyList,
                          title: l.aiPlanHistoryEmptyTitle,
                          body: l.aiPlanHistoryEmptyBody,
                          actionLabel: onImport == null ? null : l.aiPlanImportTitle,
                          actionIcon: Icons.move_to_inbox_rounded,
                          onAction: onImport,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, 120),
                      itemCount: plans.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(height: Space.s),
                      itemBuilder: (context, i) => StaggerItem(
                        index: i,
                        child: i == 0
                            ? Padding(
                                padding: const EdgeInsetsDirectional.only(bottom: Space.xs),
                                child: SectionHeader(
                                  title: l.aiPlanHistoryTitle,
                                  subtitle: l.aiPlanHistoryBody,
                                  padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, 0, Space.xs, Space.s),
                                ),
                              )
                            : _PlanRow(plan: plans[i - 1], onOpen: onOpenPlan),
                      ),
                    ),
            ),
    );
  }
}

class _PlanRow extends ConsumerWidget {
  const _PlanRow({required this.plan, this.onOpen});

  final AppliedPlanRow plan;
  final void Function(String planId)? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final tx = AiBridgeTexts.of(context);
    final progress = ref.watch(planProgressProvider(plan.id)).value;
    final detail = [
      tx.suggestionCount(plan.itemCount),
      tx.origin(plan.origin),
      tx.importedOn(plan.importedAt.toLocal()),
    ].join(l.recordListSeparator);

    return GlassCard(
      key: ValueKey('aiPlan.history.${plan.id}'),
      padding: const EdgeInsetsDirectional.all(Space.l),
      semanticLabel: [
        tx.planName(plan),
        detail,
        if (progress != null && progress.total > 0) tx.progress(progress),
      ].join(l.recordListSeparator),
      onTap: onOpen == null ? null : () => onOpen!(plan.id),
      child: ExcludeSemantics(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tx.planName(plan),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall?.copyWith(color: t.textPrimary),
                  ),
                  const SizedBox(height: Space.xxs),
                  Text(detail, style: text.bodySmall?.copyWith(color: t.textTertiary, height: 1.45)),
                  if (progress != null && progress.total > 0) ...[
                    const SizedBox(height: Space.s),
                    PlanPill(
                      label: tx.progress(progress),
                      color: progress.isComplete ? t.success : t.accent,
                      icon: Icons.checklist_rounded,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: Space.s),
            // `chevron_right_rounded` carries `matchTextDirection`, so
            // Flutter mirrors it in Arabic by itself: choosing the left
            // one here would mirror it a second time and point it back
            // the wrong way.
            Icon(Icons.chevron_right_rounded, size: 20, color: t.textTertiary),
          ],
        ),
      ),
    );
  }
}
