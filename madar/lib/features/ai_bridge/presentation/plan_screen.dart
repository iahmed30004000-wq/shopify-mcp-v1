import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/domain/enums.dart' show PlanItemState;
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/sound/sound_api.dart';
import '../data/ai_bridge_providers.dart';
import '../domain/plan_contract.dart';
import '../domain/plan_preview.dart';
import 'ai_bridge_texts.dart';
import 'plan_actions.dart';
import 'plan_checklist_view.dart';
import 'widgets/plan_item_card.dart';
import 'widgets/plan_widgets.dart';

/// The two halves of one plan.
enum PlanTab {
  /// Every suggestion as a card, decided one at a time.
  items,

  /// The suggestions he approved, as the list he ticks off.
  list,
}

/// One «خطة مدار»: the AI's answer read against his own data, card by
/// card, and the named list the approved ones become.
///
/// The screen re-opens the plan through [PlanApplyService.reopen] on every
/// decision, so what he sees is always measured against his data **as it
/// is now** – a suggestion that was waiting for the one he just approved
/// turns green in front of him, and a before/after is never a stale
/// number.
///
/// Nothing on this screen applies anything by itself. There is one Approve
/// button per card and no "approve everything" in any wording.
class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({
    super.key,
    required this.planId,
    this.initialTab = PlanTab.items,
    this.animateBackdrop = true,
    this.onOpenMealPlan,
  });

  final String planId;
  final PlanTab initialTab;
  final bool animateBackdrop;

  /// Opens the meal plan, for the one blocker a sheet cannot settle.
  final VoidCallback? onOpenMealPlan;

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  late PlanTab _tab = widget.initialTab;

  /// What he settled on a suggestion before approving it, by item id. Kept
  /// on the screen only: an edit writes nothing until he taps Approve.
  final Map<String, PlanItem> _edits = {};

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final tx = AiBridgeTexts.of(context);
    final data = ref.watch(planReviewProvider(widget.planId)).value;
    final rows = ref.watch(planItemRowsProvider(widget.planId)).value ?? const [];
    final plan = data?.plan;
    final states = {for (final r in rows) r.itemKey: r.state};

    if (plan == null) {
      return MadarScaffold(
        title: l.aiPlanHistoryTitle,
        backdropSeed: 9.2,
        animateBackdrop: widget.animateBackdrop,
        body: Center(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(Space.gutter),
            child: AnimatedEmptyState(
              key: const ValueKey('aiPlan.missing'),
              kind: EmptyStateKind.emptyList,
              title: l.aiPlanMissing,
            ),
          ),
        ),
      );
    }

    return MadarScaffold(
      title: tx.planName(plan),
      backdropSeed: 9.2,
      animateBackdrop: widget.animateBackdrop,
      actions: [
        MadarButton.icon(
          key: const ValueKey('aiPlan.rename'),
          icon: Icons.drive_file_rename_outline_rounded,
          semanticLabel: l.aiPlanRenameAction,
          variant: MadarButtonVariant.ghost,
          sfx: Sfx.sheetOpen,
          onPressed: () => PlanActions.rename(context, ref, plan),
        ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.xs, Space.gutter, Space.s),
            // A Wrap, not a Row: at text scale 1.3 (and in English) the two
            // labels no longer fit on one line, and a clipped tab is worse
            // than a second row.
            child: Wrap(
              spacing: Space.s,
              runSpacing: Space.xs,
              children: [
                for (final tab in PlanTab.values)
                  MadarChip(
                    key: ValueKey('aiPlan.tab.${tab.name}'),
                    label: tab == PlanTab.items ? l.aiPlanTabItems : l.aiPlanTabList,
                    icon: tab == PlanTab.items ? Icons.auto_awesome_rounded : Icons.checklist_rounded,
                    selected: _tab == tab,
                    onSelected: (_) {
                      if (_tab != tab) setState(() => _tab = tab);
                    },
                  ),
              ],
            ),
          ),
          Expanded(
            child: EntranceChoreo(
              id: ('aiPlan', widget.planId, _tab),
              child: _FadeStack(
                index: _tab.index,
                children: [
                  _ItemsView(
                    key: const ValueKey('aiPlan.items'),
                    planId: widget.planId,
                    states: states,
                    edits: _edits,
                    onEdited: (id, item) => setState(() {
                      if (item == null) {
                        _edits.remove(id);
                      } else {
                        _edits[id] = item;
                      }
                    }),
                    onOpenMealPlan: widget.onOpenMealPlan,
                  ),
                  PlanChecklistView(key: const ValueKey('aiPlan.list'), planId: widget.planId),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows the selected tab only and cross-fades between them: a thin name
/// for [MadarFadeStack] (see it for why nothing is kept hidden behind).
class _FadeStack extends StatelessWidget {
  const _FadeStack({required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => MadarFadeStack(index: index, children: children);
}

/// The suggestions: the plan's own header (what the AI wrote, where the
/// answer came from, what it flagged) and one card per suggestion.
class _ItemsView extends ConsumerWidget {
  const _ItemsView({
    super.key,
    required this.planId,
    required this.states,
    required this.edits,
    required this.onEdited,
    this.onOpenMealPlan,
  });

  final String planId;
  final Map<String, PlanItemState> states;
  final Map<String, PlanItem> edits;
  final void Function(String id, PlanItem? item) onEdited;
  final VoidCallback? onOpenMealPlan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final data = ref.watch(planReviewProvider(planId)).value;
    final plan = data?.plan;
    if (data == null || plan == null) return const Center(child: OrbitLoader());

    // His edits re-judged against the same data and the same validation.
    final previews = [
      for (final p in data.previews) (edits[p.id] == null ? null : data.preview(edits[p.id]!)) ?? p,
    ];

    final children = <Widget>[
      _PlanHeader(planId: planId),
      if (previews.isEmpty)
        Padding(
          padding: const EdgeInsetsDirectional.only(top: Space.l),
          child: AnimatedEmptyState(
            key: const ValueKey('aiPlan.items.empty'),
            kind: EmptyStateKind.emptyList,
            title: l.aiPlanItemsEmpty,
          ),
        ),
      for (final preview in previews)
        PlanItemCard(
          preview: preview,
          decided: states[preview.id] ?? PlanItemState.pending,
          edited: edits.containsKey(preview.id),
          waitingNames: [for (final id in preview.waitingFor) data.titleOf(id)],
          onApprove: () => unawaited(_approve(context, ref, data, preview)),
          onEdit: () => unawaited(_edit(context, ref, data, preview)),
          onReject: () => unawaited(PlanActions.reject(context, ref, plan, preview)),
          onOpenMealPlan: onOpenMealPlan,
        ),
    ];

    return ListView.separated(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, 120),
      itemCount: children.length,
      separatorBuilder: (_, _) => const SizedBox(height: Space.m),
      itemBuilder: (context, i) => StaggerItem(index: i, child: children[i]),
    );
  }

  Future<void> _approve(BuildContext context, WidgetRef ref, PlanReviewData data, PlanItemPreview preview) async {
    final plan = data.plan;
    if (plan == null) return;
    final ok = await PlanActions.approve(context, ref, plan, preview);
    // Applied: his edit is stored on the row now, so the screen stops
    // carrying it.
    if (ok) onEdited(preview.id, null);
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, PlanReviewData data, PlanItemPreview preview) async {
    final before = edits[preview.id];
    final edited = await PlanActions.edit(context, ref, preview, catalog: data.catalog);
    if (edited == null) return;
    onEdited(preview.id, edited);
    if (!context.mounted) return;
    Fx.fire(Sfx.complete);
    // An edit writes nothing to his data – so its undo is simply the value
    // the card carried before, back on the card.
    unawaited(
      showUndoToast(
        context,
        UndoableAction(
          label: L10n.of(context).aiPlanEditedToast(AiBridgeTexts.of(context).name(preview.item.title)),
          undo: () async => onEdited(preview.id, before),
        ),
      ),
    );
  }
}

/// The plan's own header: what the AI wrote, how the answer reached the
/// phone, how far the list has got, and the provenance – including the
/// claims the AI flagged, which are a **warning** and never an item.
class _PlanHeader extends ConsumerWidget {
  const _PlanHeader({required this.planId});

  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final tx = AiBridgeTexts.of(context);
    final data = ref.watch(planReviewProvider(planId)).value;
    final plan = data?.plan;
    if (data == null || plan == null) return const SizedBox.shrink();
    final progress = ref.watch(planProgressProvider(planId)).value;
    final madarPlan = data.import.validation.plan;
    final source = madarPlan?.source ?? const PlanSource();
    final sourceLines = tx.sourceLines(source);
    final summary = plan.summary?.trim();
    // The AI's own words about the plan as a whole: its title (which he
    // may have renamed away) and its one-paragraph overview.
    final aiTitle = plan.title?.trim();
    final own = [
      if (aiTitle != null && aiTitle.isNotEmpty && aiTitle != plan.name) tx.name(aiTitle),
      if (summary != null && summary.isNotEmpty) summary,
    ];

    return GlassPanel(
      padding: const EdgeInsetsDirectional.all(Space.l),
      seed: 9.2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
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
                      style: text.titleLarge?.copyWith(color: t.textPrimary),
                    ),
                    const SizedBox(height: Space.xxs),
                    Text(
                      [
                        tx.suggestionCount(plan.itemCount),
                        tx.origin(plan.origin),
                        tx.importedOn(plan.importedAt.toLocal()),
                      ].join(l.recordListSeparator),
                      style: text.bodySmall?.copyWith(color: t.textTertiary, height: 1.45),
                    ),
                  ],
                ),
              ),
              if (progress != null && progress.total > 0) ...[
                const SizedBox(width: Space.m),
                ProgressRing(
                  value: progress.fraction,
                  size: 46,
                  strokeWidth: 4,
                  color: t.success,
                  glow: progress.isComplete,
                  semanticLabel: tx.progress(progress),
                  child: Text(
                    tx.progress(progress),
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: text.labelSmall?.copyWith(color: t.textPrimary, height: 1, fontSize: 10),
                  ),
                ),
              ],
            ],
          ),
          if (own.isNotEmpty) ...[
            const SizedBox(height: Space.l),
            PlanLabel(l.aiPlanSummaryTitle, icon: Icons.format_quote_rounded, color: t.secondary),
            PlanLines(lines: own, bullet: false),
          ],
          if (sourceLines.isNotEmpty) ...[
            const SizedBox(height: Space.l),
            PlanLabel(l.aiPlanSourceTitle, icon: Icons.menu_book_rounded, color: t.gold),
            PlanLines(lines: sourceLines, color: t.textTertiary),
          ],
          if (source.claimsFlagged.isNotEmpty) ...[
            const SizedBox(height: Space.l),
            PlanLabel(l.aiPlanClaimsTitle, icon: Icons.warning_amber_rounded, color: t.warning),
            PlanLines(lines: [for (final c in source.claimsFlagged) tx.name(c)], color: t.warning),
            const SizedBox(height: Space.s),
            Text(
              l.aiPlanClaimsBody,
              style: text.bodySmall?.copyWith(color: t.textTertiary, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}
