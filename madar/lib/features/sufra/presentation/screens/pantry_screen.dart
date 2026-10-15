import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/sound/sound_api.dart';
import '../../data/sufra_providers.dart';
import '../../domain/pantry.dart';
import '../sufra_actions.dart';
import '../sufra_nav.dart';
import '../sufra_texts.dart';
import '../widgets/sufra_dish.dart';
import '../widgets/sufra_widgets.dart';

/// «شو في بالبيت» – what is in the house.
///
/// The top of the screen is what she actually acts on: «خلص: زيت · فات
/// تاريخه: لبن · قلّ: رز», worst first, straight off
/// `pantryAttentionProvider`. Under it, her things grouped by the place she
/// keeps them in, in her own order inside a group, every write undoable.
class PantryScreen extends ConsumerStatefulWidget {
  const PantryScreen({super.key, this.animateBackdrop = true});

  final bool animateBackdrop;

  @override
  ConsumerState<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends ConsumerState<PantryScreen> {
  bool _archived = false;

  /// One place's new order, written back into the whole pantry's order:
  /// the items of that place take their new order in the places they
  /// already held, so dragging inside «الفريزر» never moves anything in
  /// «خزانة المونة».
  void _reorderPlace(List<PantryStock> all, List<PantryStock> ordered) {
    final queue = [for (final s in ordered) s.item.id];
    final moved = queue.toSet();
    final ids = <String>[];
    for (final s in all) {
      ids.add(moved.contains(s.item.id) ? queue.removeAt(0) : s.item.id);
    }
    unawaited(ref.read(sufraServiceProvider).reorderPantry(ids));
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final tx = SufraTexts.of(context);
    final p = SufraPalette.of(context);
    final board = ref.watch(pantryBoardProvider);
    final attention = ref.watch(pantryAttentionProvider);
    final rows = {for (final r in ref.watch(pantryRowsProvider).value ?? const <PantryItemRow>[]) r.id: r};
    final live = board.live;
    final shown = [
      ...live,
      if (_archived)
        for (final s in board.stocks)
          if (s.item.archived) s,
    ];
    final places = <String, List<PantryStock>>{};
    for (final s in shown) {
      final place = s.item.place?.trim();
      (places[place == null || place.isEmpty ? PantryBoard.noPlace : place] ??= []).add(s);
    }

    return MadarScaffold(
      title: l.sufraPantryTitle,
      backdropSeed: 9.1,
      animateBackdrop: widget.animateBackdrop,
      floatingAction: MadarButton.icon(
        key: const ValueKey('sufra.pantry.add'),
        icon: Icons.add_rounded,
        semanticLabel: l.sufraAddPantryItem,
        variant: MadarButtonVariant.primary,
        size: MadarButtonSize.large,
        sfx: Sfx.sheetOpen,
        onPressed: () => SufraActions.addItem(context, ref),
      ),
      body: ListView(
        key: const PageStorageKey('sufra.pantry'),
        padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, sufraBottomPadding),
        children: [
          SufraCard(
            key: const ValueKey('sufra.pantry.attention'),
            title: l.sufraAttentionTitle,
            icon: Icons.priority_high_rounded,
            iconColor: p.out,
            seed: 9.1,
            trailing: SufraPill(label: tx.pantryCount(live.length), color: p.pantry, dense: true),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SufraAttentionLines(attention: attention),
                if (board.toBuy.isNotEmpty) ...[
                  const SizedBox(height: Space.m),
                  MadarButton(
                    key: const ValueKey('sufra.pantry.toList'),
                    label: l.sufraLowToList,
                    icon: Icons.add_shopping_cart_rounded,
                    variant: MadarButtonVariant.secondary,
                    size: MadarButtonSize.small,
                    expand: true,
                    onPressed: () async {
                      final listId = await SufraActions.lowToHouseList(context, ref);
                      if (listId != null && context.mounted) sufraOpenList(context, ref, listId);
                    },
                  ),
                ],
              ],
            ),
          ),
          if (board.stocks.any((s) => s.item.archived))
            Padding(
              padding: const EdgeInsets.only(top: Space.m),
              child: Row(
                children: [
                  Expanded(child: Text(l.sufraShowArchived, style: Theme.of(context).textTheme.labelLarge)),
                  MadarSwitch(
                    key: const ValueKey('sufra.pantry.archivedSwitch'),
                    value: _archived,
                    semanticLabel: l.sufraShowArchived,
                    onChanged: (v) => setState(() => _archived = v),
                  ),
                ],
              ),
            ),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Space.l),
              child: AnimatedEmptyState(
                key: const ValueKey('sufra.pantry.empty'),
                kind: EmptyStateKind.emptyList,
                title: l.sufraPantryEmptyTitle,
                body: l.sufraPantryEmptyBody,
                actionLabel: l.sufraAddPantryItem,
                actionIcon: Icons.add_rounded,
                onAction: () => SufraActions.addItem(context, ref),
              ),
            ),
          // Her places, in the order she first used them, and inside a
          // place her own order – which she changes by dragging, without
          // the groups ever renumbering one another.
          for (final MapEntry(key: place, value: stocks) in places.entries) ...[
            SufraSectionTitle(
              place == PantryBoard.noPlace ? l.sufraNoPlace : tx.name(place),
              icon: Icons.kitchen_outlined,
              trailing: Text(
                tx.pantryCount(stocks.length),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.textTertiary),
              ),
            ),
            ReorderableGlassList<PantryStock>(
              key: ValueKey('sufra.pantry.group.$place'),
              items: stocks,
              itemKey: (s) => s.item.id,
              padding: EdgeInsets.zero,
              spacing: Space.s,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBorderRadius: BorderRadius.circular(t.radiusL),
              onReorder: (ordered) => _reorderPlace(board.stocks, ordered),
              itemBuilder: (context, stock, index, grip) {
                final row = rows[stock.item.id];
                if (row == null) return const SizedBox.shrink();
                return PantryTile(stock: stock, row: row, grip: grip);
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// One thing in the house: how much is left, where it is, what its date
/// says – and every write she can make on it, each with its undo.
class PantryTile extends ConsumerWidget {
  const PantryTile({super.key, required this.stock, required this.row, this.grip});

  final PantryStock stock;
  final PantryItemRow row;
  final Widget? grip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final tx = SufraTexts.of(context);
    final p = SufraPalette.of(context);
    final text = Theme.of(context).textTheme;
    final item = stock.item;
    final amount = tx.amount(item.quantity, item.unit);
    final expiry = tx.expiry(stock);
    final line = [
      if (amount.isNotEmpty) amount,
      if (amount.isEmpty) l.sufraNoAmount,
      ?expiry,
      if (item.archived) l.sufraArchivedLabel,
    ].join(l.commonFactSeparator);

    return ActionableItem(
      key: ValueKey('sufra.pantry.item.${item.id}'),
      semanticLabel: '${item.name}, ${tx.state(stock.state)}, $line',
      borderRadius: BorderRadius.circular(t.radiusL),
      onTap: () => SufraActions.editItem(context, ref, row),
      actions: ItemActions(
        onEdit: () => SufraActions.editItem(context, ref, row),
        onDelete: () => SufraActions.deleteItem(context, ref, row),
        extra: [
          ItemAction(
            icon: Icons.remove_circle_outline_rounded,
            label: l.sufraUsedSome,
            onSelected: () async {
              await SufraActions.useSome(context, ref, row);
              return null;
            },
          ),
          ItemAction(
            icon: Icons.remove_shopping_cart_rounded,
            label: l.sufraMarkOut,
            onSelected: () => SufraActions.markOut(context, ref, row),
          ),
          ItemAction(
            icon: Icons.trending_down_rounded,
            label: row.low ? l.sufraUnmarkLow : l.sufraMarkLow,
            onSelected: () => SufraActions.toggleLow(context, ref, row),
          ),
          ItemAction(
            icon: row.staple ? Icons.push_pin_rounded : Icons.push_pin_outlined,
            label: l.sufraItemStaple,
            onSelected: () => SufraActions.toggleStaple(context, ref, row),
          ),
          ItemAction(
            icon: row.archived ? Icons.unarchive_outlined : Icons.archive_outlined,
            label: row.archived ? l.sufraUnarchiveItem : l.sufraArchiveItem,
            onSelected: () => SufraActions.toggleArchivedItem(context, ref, row),
          ),
        ],
      ),
      quickActions: [
        QuickAction(
          icon: Icons.remove_circle_outline_rounded,
          label: l.sufraUsedSome,
          onPressed: () async {
            await SufraActions.useSome(context, ref, row);
            return null;
          },
        ),
        QuickAction(
          icon: Icons.trending_down_rounded,
          label: row.low ? l.sufraUnmarkLow : l.sufraMarkLow,
          onPressed: () => SufraActions.toggleLow(context, ref, row),
        ),
        QuickAction(
          icon: Icons.delete_outline_rounded,
          label: l.sufraDelete,
          tone: ActionTone.danger,
          onPressed: () => SufraActions.deleteItem(context, ref, row),
        ),
      ],
      child: GlassCard(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.xs, Space.m),
        borderRadius: BorderRadius.circular(t.radiusL),
        child: ExcludeSemantics(
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.state(stock.state).withValues(alpha: t.isDark ? 0.14 : 0.10),
                  border: Border.all(color: p.state(stock.state).withValues(alpha: 0.45)),
                ),
                child: Icon(
                  sufraStateIcon(stock.state),
                  size: 18,
                  color: item.archived ? t.textTertiary : p.state(stock.state),
                ),
              ),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.name,
                            style: text.titleSmall?.copyWith(color: item.archived ? t.textTertiary : t.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.staple) ...[
                          const SizedBox(width: Space.xs),
                          Icon(Icons.push_pin_rounded, size: 12, color: t.textTertiary),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(line, style: text.bodySmall?.copyWith(color: t.textTertiary)),
                  ],
                ),
              ),
              if (stock.needsAttention)
                SufraPill(label: tx.state(stock.state), color: p.state(stock.state), dense: true),
              ?grip,
            ],
          ),
        ),
      ),
    );
  }
}
