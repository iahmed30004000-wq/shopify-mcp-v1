import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../data/body_providers.dart';
import '../body_actions.dart';
import '../widgets/body_widgets.dart';

/// The user's own "avoid" list: movements and foods with their reasons.
/// Drag to reorder, tap to edit, delete with undo. No advice of our own.
class BodyAvoidTab extends ConsumerWidget {
  const BodyAvoidTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final p = BodyPalette(t);
    final items = ref.watch(bodyAvoidRowsProvider).value ?? const <AvoidItemRow>[];
    return ReorderableGlassList<AvoidItemRow>(
      items: items,
      itemKey: (a) => a.id,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, bodyTabBottomPadding),
      spacing: Space.s,
      header: Padding(
        padding: const EdgeInsets.only(bottom: Space.m),
        child: BodyCard(
          title: l.bodyAvoidTitle,
          icon: Icons.do_not_disturb_on_outlined,
          iconColor: p.avoid,
          seed: 9.1,
          child: Text(l.bodyAvoidSubtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textSecondary)),
        ),
      ),
      footer: items.isEmpty
          ? Padding(
              padding: const EdgeInsets.only(top: Space.l),
              child: AnimatedEmptyState(
                kind: EmptyStateKind.emptyList,
                title: l.bodyAvoidEmptyTitle,
                body: l.bodyAvoidEmptyBody,
                actionLabel: l.bodyAvoidAdd,
                actionIcon: Icons.add_rounded,
                onAction: () => BodyActions.addAvoid(context, ref),
              ),
            )
          : Padding(
              padding: const EdgeInsets.only(top: Space.m),
              child: BodyHint(l.bodyPlanHint, icon: Icons.drag_indicator_rounded),
            ),
      onReorder: (order) => ref.read(bodyServiceProvider).reorderAvoid([for (final a in order) a.id]),
      itemBuilder: (context, a, index, grip) => AvoidTile(item: a, grip: grip),
    );
  }
}

/// One item of the avoid list.
class AvoidTile extends ConsumerWidget {
  const AvoidTile({super.key, required this.item, this.grip});

  final AvoidItemRow item;
  final Widget? grip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final p = BodyPalette(t);
    final text = Theme.of(context).textTheme;
    final reason = item.reason;
    return ActionableItem(
      key: ValueKey('body.avoid.${item.id}'),
      // No semanticLabel: the item and its reason are read once each.
      borderRadius: BorderRadius.circular(t.radiusL),
      onTap: () => BodyActions.editAvoid(context, ref, item),
      actions: ItemActions(
        onEdit: () => BodyActions.editAvoid(context, ref, item),
        onDelete: () => BodyActions.deleteAvoid(context, ref, item),
      ),
      quickActions: [
        QuickAction(
          icon: Icons.delete_outline_rounded,
          label: l.bodyDelete,
          tone: ActionTone.danger,
          onPressed: () => BodyActions.deleteAvoid(context, ref, item),
        ),
      ],
      child: GlassCard(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.xs, Space.m),
        borderRadius: BorderRadius.circular(t.radiusL),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: p.avoid.withValues(alpha: t.isDark ? 0.14 : 0.10),
                border: Border.all(color: p.avoid.withValues(alpha: 0.45)),
              ),
              child: Icon(Icons.block_rounded, size: 18, color: p.avoid),
            ),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.body, style: text.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    reason ?? l.bodyAvoidNoReason,
                    style: text.bodySmall?.copyWith(color: reason == null ? t.textTertiary : t.textSecondary),
                  ),
                ],
              ),
            ),
            ?grip,
          ],
        ),
      ),
    );
  }
}
