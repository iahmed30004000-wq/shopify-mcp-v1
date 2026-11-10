import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/domain/enums.dart' show PlanItemState;
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/sound/sound_api.dart';
import '../../domain/plan_preview.dart';
import '../ai_bridge_texts.dart';
import 'plan_widgets.dart';

/// One suggestion, as he reads it: what it would change, why the AI says
/// so, what his data says today, and the one decision that is his.
///
/// The three buttons are the only way anything is written, and the card
/// draws them from the engine's own verdict:
///
/// * `ready` → **Approve** (and Refuse);
/// * `needsEdit` → **Edit** first (Approve is not drawn at all, so the
///   screen cannot offer what the engine would refuse);
/// * `blocked` → the suggestion it is waiting for, **by name**;
/// * `deferred` → kept for a later part of Madar;
/// * `rejected` → the reasons, in his words, and no Approve anywhere. A
///   health refusal quotes the words that tripped it ([L10n.aiPlanProblemHealth]),
///   because the refusal has to be readable, not mysterious.
class PlanItemCard extends ConsumerWidget {
  const PlanItemCard({
    super.key,
    required this.preview,
    required this.decided,
    this.waitingNames = const [],
    this.edited = false,
    this.onApprove,
    this.onEdit,
    this.onReject,
    this.onOpenMealPlan,
  });

  final PlanItemPreview preview;

  /// What is stored about this suggestion (pending until he decides).
  final PlanItemState decided;

  /// The titles of the suggestions this one waits for – never their ids.
  final List<String> waitingNames;

  /// True when he already settled what it left open.
  final bool edited;

  final VoidCallback? onApprove;
  final VoidCallback? onEdit;
  final VoidCallback? onReject;

  /// Opens the meal plan (the only blocker a sheet cannot settle).
  final VoidCallback? onOpenMealPlan;

  bool get _settled => decided == PlanItemState.applied || decided == PlanItemState.rejected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final tx = AiBridgeTexts.of(context);
    final item = preview.item;
    final applied = decided == PlanItemState.applied;
    final rejected = decided == PlanItemState.rejected || preview.status == PlanItemStatus.rejected;
    final statusColor = applied
        ? t.success
        : rejected
        ? t.danger
        : decided == PlanItemState.undone
        ? t.textTertiary
        : planStatusColor(t, preview.status);
    final blockers = tx.blockers(preview);
    final changes = tx.changeLines(preview);
    final before = tx.beforeLines(preview);
    final evidence = item.evidence?.trim();

    // The one word for where the card stands. The validator's own refusal
    // comes first and reads «مرفوض»: he did not refuse it, Madar did, and
    // saying «رفضته» over a health refusal would put it on him.
    final stateWord = applied
        ? l.aiPlanBadgeApplied
        : preview.status == PlanItemStatus.rejected
        ? tx.status(PlanItemStatus.rejected)
        : decided == PlanItemState.rejected
        ? l.aiPlanBadgeRejected
        : decided == PlanItemState.undone
        ? l.aiPlanBadgeUndone
        : tx.status(preview.status);

    // What TalkBack reads in one breath: the kind, the line, the state.
    final semantics = [tx.kind(item.kind), tx.name(item.title), stateWord].join(l.recordListSeparator);

    return GlassCard(
      key: ValueKey('aiPlan.card.${item.id}'),
      padding: const EdgeInsetsDirectional.all(Space.l),
      borderColor: statusColor.withValues(alpha: 0.30),
      glowColor: statusColor.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ------------------------------------------------- what and how --
          Semantics(
            container: true,
            label: semantics,
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: Space.s,
                  runSpacing: Space.xs,
                  children: [
                    PlanPill(label: tx.kind(item.kind), color: t.accent, icon: Icons.auto_awesome_rounded),
                    PlanPill(
                      label: stateWord,
                      color: statusColor,
                      icon: applied
                          ? Icons.check_rounded
                          : rejected
                          ? Icons.block_rounded
                          : decided == PlanItemState.undone
                          ? Icons.undo_rounded
                          : planStatusIcon(preview.status),
                    ),
                    if (edited) PlanPill(label: l.aiPlanEditAction, color: t.gold, icon: Icons.edit_rounded),
                  ],
                ),
                const SizedBox(height: Space.m),
                Text(
                  item.title,
                  textDirection: BidiIsolate.directionOf(item.title),
                  textAlign: Directionality.of(context) == TextDirection.rtl ? TextAlign.right : TextAlign.left,
                  style: text.titleMedium?.copyWith(color: t.textPrimary, height: 1.4),
                ),
              ],
            ),
          ),

          // ----------------------------------------------- what it changes --
          if (changes.isNotEmpty) ...[
            const SizedBox(height: Space.m),
            PlanLabel(l.aiPlanChangeTitle, icon: Icons.swap_horiz_rounded, color: t.accent),
            PlanLines(lines: changes),
          ],

          // ----------------------------------------------------- the reason --
          const SizedBox(height: Space.m),
          PlanLabel(l.aiPlanReasonTitle, icon: Icons.psychology_alt_rounded, color: t.secondary),
          PlanLines(lines: [item.reason], bullet: false),
          if (evidence != null && evidence.isNotEmpty) ...[
            const SizedBox(height: Space.s),
            PlanLabel(l.aiPlanEvidenceTitle, icon: Icons.insights_rounded, color: t.gold),
            PlanLines(lines: [evidence], bullet: false, color: t.textTertiary),
          ],

          // ------------------------------------------------- what it is today --
          const SizedBox(height: Space.m),
          PlanLabel(l.aiPlanBeforeTitle, icon: Icons.history_rounded),
          PlanLines(lines: before, color: t.textTertiary),

          // ------------------------------------------------------- blockers --
          if (preview.isChecklistOnly && !rejected) ...[
            const SizedBox(height: Space.m),
            _Note(text: l.aiPlanChecklistOnly, icon: Icons.checklist_rounded, color: t.textTertiary),
          ],
          if (waitingNames.isNotEmpty) ...[
            const SizedBox(height: Space.m),
            _Note(text: tx.waitingFor(waitingNames), icon: Icons.lock_clock_rounded, color: t.info),
          ],
          if (preview.status == PlanItemStatus.deferred) ...[
            const SizedBox(height: Space.m),
            _Note(text: l.aiPlanChangeDeferred, icon: Icons.schedule_rounded, color: t.textTertiary),
          ],
          // What still stands in the way – but never under a suggestion he
          // has already approved: `reopen` reads the plan as it arrived, so
          // an edit he made before approving reads as "needs an edit"
          // again, and saying that over an applied card would be a lie.
          if (!applied)
            for (final line in blockers) ...[
              const SizedBox(height: Space.s),
              _Note(
                text: line,
                icon: rejected ? Icons.block_rounded : Icons.edit_note_rounded,
                color: rejected ? t.danger : t.warning,
              ),
            ],
          if (rejected) ...[
            const SizedBox(height: Space.s),
            _Note(text: l.aiPlanCannotApprove, icon: Icons.shield_rounded, color: t.danger),
          ],
          if (preview.editReasons.contains(PlanEditReason.mealPlanMissing) && onOpenMealPlan != null) ...[
            const SizedBox(height: Space.m),
            MadarButton(
              key: ValueKey('aiPlan.mealPlan.${item.id}'),
              label: l.aiPlanMealPlanFirst,
              icon: Icons.restaurant_menu_rounded,
              variant: MadarButtonVariant.secondary,
              size: MadarButtonSize.small,
              expand: true,
              sfx: Sfx.navigate,
              onPressed: onOpenMealPlan,
            ),
          ],

          // ------------------------------------------------- his decision --
          if (applied) ...[
            const SizedBox(height: Space.m),
            _Note(text: l.aiPlanAlreadyApplied, icon: Icons.check_circle_rounded, color: t.success),
          ] else if (!_settled && !rejected)
            ..._buttons(context, l, t),
        ],
      ),
    );
  }

  /// Approve is drawn **only** for a suggestion the engine calls ready.
  List<Widget> _buttons(BuildContext context, L10n l, MadarTokens t) {
    final id = preview.item.id;
    final canApprove = preview.canApply && onApprove != null;
    final canEdit = preview.status == PlanItemStatus.needsEdit && onEdit != null && !preview.editReasons.contains(PlanEditReason.mealPlanMissing);
    return [
      const SizedBox(height: Space.l),
      Row(
        children: [
          if (canApprove)
            Expanded(
              child: MadarButton(
                key: ValueKey('aiPlan.approve.$id'),
                label: l.aiPlanApproveAction,
                icon: Icons.check_rounded,
                size: MadarButtonSize.small,
                expand: true,
                sfx: Sfx.complete,
                onPressed: onApprove,
              ),
            ),
          if (canEdit) ...[
            if (canApprove) const SizedBox(width: Space.s),
            Expanded(
              child: MadarButton(
                key: ValueKey('aiPlan.edit.$id'),
                label: l.aiPlanEditAction,
                icon: Icons.edit_rounded,
                variant: MadarButtonVariant.secondary,
                size: MadarButtonSize.small,
                expand: true,
                sfx: Sfx.sheetOpen,
                onPressed: onEdit,
              ),
            ),
          ],
          if (onReject != null) ...[
            if (canApprove || canEdit) const SizedBox(width: Space.s),
            Expanded(
              child: MadarButton(
                key: ValueKey('aiPlan.reject.$id'),
                label: l.aiPlanRejectAction,
                icon: Icons.close_rounded,
                variant: MadarButtonVariant.ghost,
                size: MadarButtonSize.small,
                expand: true,
                sfx: Sfx.tap,
                onPressed: onReject,
              ),
            ),
          ],
        ],
      ),
    ];
  }
}

/// One plain notice inside a card (a blocker, a refusal, a reassurance).
class _Note extends StatelessWidget {
  const _Note({required this.text, required this.icon, required this.color});

  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.m, vertical: Space.s),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(t.radiusS),
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.22), width: 0.8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 1),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: Space.s),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
