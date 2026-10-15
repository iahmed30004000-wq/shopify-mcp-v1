import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart' show AppliedPlanItemRow;
import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/motion/motion_kit.dart';
import '../data/ai_bridge_providers.dart';
import '../domain/plan_contract.dart' show PlanItemKind;
import '../domain/plan_preview.dart' show PlanItemPreview;
import 'ai_bridge_texts.dart';
import 'plan_actions.dart';
import 'plan_after.dart';
import 'widgets/plan_widgets.dart';

/// The owner's own ask: the suggestions he approved, gathered under the
/// plan's name as one list he ticks off, with «٢ من ٤» above it.
///
/// A line is a record of an approved suggestion – never a task in the home
/// panel's task list. Ticking and un-ticking undo like everything else in
/// Madar, and only an approved line can be ticked at all (the engine
/// refuses the rest).
///
/// Each line also carries its before/after, measured against his data as
/// it is **now**: when a number moved afterwards for a reason of his own,
/// the line says so instead of taking the credit ([PlanAfter]).
class PlanChecklistView extends ConsumerWidget {
  const PlanChecklistView({super.key, required this.planId});

  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final tx = AiBridgeTexts.of(context);
    final rows = ref.watch(planChecklistProvider(planId)).value;
    final progress = ref.watch(planProgressProvider(planId)).value;
    final data = ref.watch(planReviewProvider(planId)).value;

    if (rows == null) return const Center(child: OrbitLoader());
    if (rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(Space.gutter),
          child: AnimatedEmptyState(
            key: const ValueKey('aiPlan.list.empty'),
            kind: EmptyStateKind.emptyList,
            title: l.aiPlanChecklistEmpty,
            body: l.aiPlanChecklistHint,
          ),
        ),
      );
    }

    final header = GlassPanel(
      padding: const EdgeInsetsDirectional.all(Space.l),
      seed: 9.6,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.aiPlanTabList, style: text.titleMedium?.copyWith(color: t.textPrimary)),
                const SizedBox(height: Space.xxs),
                Text(
                  progress != null && progress.isComplete ? l.aiPlanChecklistAllDone : l.aiPlanChecklistHint,
                  style: text.bodySmall?.copyWith(color: t.textTertiary, height: 1.45),
                ),
              ],
            ),
          ),
          if (progress != null) ...[
            const SizedBox(width: Space.m),
            ProgressRing(
              key: const ValueKey('aiPlan.list.progress'),
              value: progress.fraction,
              size: 52,
              strokeWidth: 4.5,
              color: t.success,
              glow: progress.isComplete,
              semanticLabel: tx.progress(progress),
              child: Text(
                tx.progress(progress),
                maxLines: 1,
                textAlign: TextAlign.center,
                style: text.labelSmall?.copyWith(color: t.textPrimary, height: 1, fontSize: 11),
              ),
            ),
          ],
        ],
      ),
    );

    return ListView.separated(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, 120),
      itemCount: rows.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: Space.s),
      itemBuilder: (context, i) => StaggerItem(
        index: i,
        child: i == 0
            ? header
            : PlanChecklistTile(
                row: rows[i - 1],
                preview: data?.import.preview(rows[i - 1].itemKey),
              ),
      ),
    );
  }
}

/// One line of a plan's checklist: the tick, his own short sentence, and
/// the honest before/after beneath it.
class PlanChecklistTile extends ConsumerWidget {
  const PlanChecklistTile({super.key, required this.row, this.preview});

  final AppliedPlanItemRow row;

  /// The same suggestion re-previewed against his data as it is now (null
  /// when the plan can no longer be read).
  final PlanItemPreview? preview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final tx = AiBridgeTexts.of(context);
    final done = row.done;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final line = tx.checklistLine(row.title);

    final live = preview;
    final beforeText = tx.refLine(PlanAfter.beforeOf(row));
    final afterText = live == null ? null : tx.refLine(live.before);
    final state = PlanAfter.of(row, live);
    // A pair is only honest when there are two sides to it: a line whose
    // record reads the same today as it did before the apply says nothing
    // worth a sentence, so it says nothing at all.
    final moved = beforeText != null && afterText != null && afterText != beforeText;
    final pair = <String>[
      if (moved) l.aiPlanAfterBefore(beforeText),
      if (moved) l.aiPlanAfterNow(afterText),
    ];
    final drift = switch (state) {
      PlanAfterState.moved => l.aiPlanAfterMoved,
      PlanAfterState.gone => l.aiPlanAfterGone,
      _ => null,
    };

    return ActionableItem(
      key: ValueKey('aiPlan.line.${row.itemKey}'),
      semanticLabel: [
        line,
        ?_kindOf(row.kind) == null ? null : tx.kind(_kindOf(row.kind)!),
        if (done) l.aiPlanBadgeApplied,
      ].join(l.recordListSeparator),
      borderRadius: BorderRadius.circular(t.radiusL),
      onTap: () => PlanActions.setDone(context, ref, row, !done),
      child: GlassCard(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.m, Space.m),
        borderRadius: BorderRadius.circular(t.radiusL),
        child: ExcludeSemantics(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Tick(done: done),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedOpacity(
                      opacity: done ? 0.62 : 1,
                      duration: context.motion(MadarMotion.short),
                      child: Text(
                        line,
                        textDirection: BidiIsolate.directionOf(line),
                        textAlign: rtl ? TextAlign.right : TextAlign.left,
                        style: text.titleSmall?.copyWith(
                          color: done ? t.textSecondary : t.textPrimary,
                          decoration: done ? TextDecoration.lineThrough : null,
                          decorationColor: t.textTertiary,
                          height: 1.4,
                        ),
                      ),
                    ),
                    if (pair.isNotEmpty) ...[
                      const SizedBox(height: Space.xs),
                      PlanLines(lines: pair, color: t.textTertiary, bullet: false),
                    ],
                    if (drift != null) ...[
                      const SizedBox(height: Space.xs),
                      PlanLines(lines: [drift], color: t.warning, bullet: false),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The row stores the kind as plain text (a plan written against a newer
  /// contract still shows in the history), so an unknown one is simply not
  /// named rather than guessed at.
  static PlanItemKind? _kindOf(String raw) => PlanItemKind.parse(raw);
}

/// The round tick of a checklist line.
class _Tick extends StatelessWidget {
  const _Tick({required this.done});

  final bool done;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AnimatedContainer(
      duration: context.motion(MadarMotion.short),
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? t.success.withValues(alpha: 0.18) : t.glassFill,
        border: Border.all(
          color: done ? t.success.withValues(alpha: 0.9) : t.glassBorder,
          width: done ? 1.4 : 1,
        ),
      ),
      child: done ? Icon(Icons.check_rounded, size: 17, color: t.success) : null,
    );
  }
}
