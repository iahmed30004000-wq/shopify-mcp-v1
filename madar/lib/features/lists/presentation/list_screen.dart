import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/sound/sound_api.dart';
import '../data/list_providers.dart';
import '../data/list_service.dart';
import '../domain/list_money.dart';
import '../domain/record_list.dart';
import 'list_actions.dart';
import 'list_texts.dart';
import 'widgets/list_widgets.dart';

/// The lists of one host record – a budget envelope, a trip, (Part 5) the
/// pantry. One screen for every host: it only ever knows the pair
/// `(hostTable, hostId)`.
///
/// Reached from the host's own screen, never from a corner of the app.
class HostListsScreen extends ConsumerWidget {
  const HostListsScreen({
    super.key,
    required this.host,
    required this.onOpenList,
    this.title,
    this.animateBackdrop = true,
  });

  final ListHost host;

  /// Opens one list (the route pushes `/list/<id>`).
  final void Function(BuildContext context, String listId) onOpenList;

  /// Overrides the title (the host's name by default).
  final String? title;

  /// Pass false in battery-saver mode.
  final bool animateBackdrop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final texts = ListTexts.of(context, ref.watch(listCurrenciesProvider).value ?? ListCurrencies.fallback);
    final rows = ref.watch(hostListsProvider(host)).value;
    final totals = ref.watch(hostListTotalsProvider(host)).value ?? const <String, ListTotals>{};
    final hostName = ref.watch(hostNameProvider(host));
    final name = hostName.value;
    final gone = hostName.hasValue && name == null;

    Future<void> add() async {
      final id = await ListActions.editList(context, ref, host: host);
      if (id != null && context.mounted) {
        Fx.fire(Sfx.navigate);
        onOpenList(context, id);
      }
    }

    final lists = rows ?? const <RecordListRow>[];
    return MadarScaffold(
      title: title ?? (name == null ? l.listsTitle : l.listsOfHost(name)),
      backdropSeed: 6.3,
      animateBackdrop: animateBackdrop,
      floatingAction: MadarButton.icon(
        icon: Icons.add_rounded,
        variant: MadarButtonVariant.primary,
        size: MadarButtonSize.large,
        semanticLabel: l.listsNewList,
        sfx: Sfx.sheetOpen,
        onPressed: add,
      ),
      body: rows == null
          ? const Center(child: OrbitLoader())
          : ReorderableGlassList<RecordListRow>(
              key: const PageStorageKey('lists.host'),
              items: lists,
              itemKey: (row) => row.id,
              padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, 96),
              spacing: Space.s,
              header: gone
                  ? Padding(
                      padding: const EdgeInsetsDirectional.only(bottom: Space.m),
                      child: _HostGoneCard(key: const ValueKey('lists.hostGone')),
                    )
                  : null,
              footer: lists.isEmpty
                  ? Padding(
                      padding: const EdgeInsetsDirectional.only(top: Space.m),
                      child: AnimatedEmptyState(
                        key: const ValueKey('lists.empty'),
                        kind: EmptyStateKind.emptyList,
                        title: l.listsEmptyTitle,
                        body: l.listsEmptyBody,
                        actionLabel: l.listsNewList,
                        actionIcon: Icons.add_rounded,
                        onAction: add,
                      ),
                    )
                  : null,
              onReorder: (ordered) => unawaited(ListActions.reorderLists(ref, [for (final r in ordered) r.id])),
              itemBuilder: (context, row, index, grip) => _ListRow(
                row: row,
                totals: totals[row.id] ?? ListTotals.empty,
                texts: texts,
                grip: grip,
                onOpen: () => onOpenList(context, row.id),
              ),
            ),
    );
  }
}

/// Every list he has, grouped by the record it hangs on – and, at the
/// end, the ones whose record was deleted, which this screen is the only
/// way to reach.
///
/// Where a list link with nothing to point at lands (`/lists`): a search
/// result, a reason or a moon about lists can never dead-end.
/// A host that is a **place** rather than a record, and so has no row to
/// read a name from: «السفرة»'s standing list of the house hangs on
/// `('pantry', 'house')`, because the pantry is one place and not one of
/// her items. Named here (and not in the kitchen) so the all-lists screen
/// stays the one screen that knows every host, and so the lists engine
/// keeps depending on nothing.
String? _placeHostTitle(L10n l, ListHost host) =>
    host.table == 'pantry' && host.id == 'house' ? l.sufraHouseListHost : null;

class AllListsScreen extends ConsumerWidget {
  const AllListsScreen({super.key, required this.onOpenList, this.animateBackdrop = true});

  /// Opens one list (the route pushes `/list/<id>`).
  final void Function(BuildContext context, String listId) onOpenList;

  /// Pass false in battery-saver mode.
  final bool animateBackdrop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final texts = ListTexts.of(context, ref.watch(listCurrenciesProvider).value ?? ListCurrencies.fallback);
    final rows = ref.watch(allListsProvider).value;
    final totals = ref.watch(allListTotalsProvider).value ?? const <String, ListTotals>{};

    // His own order, grouped by host: each host keeps the place of its
    // first list, and the records that are gone come last.
    final groups = <ListHost, List<RecordListRow>>{};
    for (final row in rows ?? const <RecordListRow>[]) {
      (groups[ListHost(row.hostTable, row.hostId)] ??= []).add(row);
    }
    final named = <(String, List<RecordListRow>)>[];
    final orphans = <RecordListRow>[];
    for (final MapEntry(key: host, value: lists) in groups.entries) {
      final name = ref.watch(hostNameProvider(host));
      if (!name.hasValue) continue; // one frame, while the record is read
      final title = name.value ?? _placeHostTitle(l, host);
      if (title == null) {
        orphans.addAll(lists);
      } else {
        named.add((title, lists));
      }
    }

    Widget row(RecordListRow r) => Padding(
      padding: const EdgeInsetsDirectional.only(bottom: Space.s),
      child: _ListRow(
        row: r,
        totals: totals[r.id] ?? ListTotals.empty,
        texts: texts,
        onOpen: () => onOpenList(context, r.id),
      ),
    );

    return MadarScaffold(
      title: l.listsAllTitle,
      backdropSeed: 6.9,
      animateBackdrop: animateBackdrop,
      body: rows == null
          ? const Center(child: OrbitLoader())
          : ListView(
              key: const PageStorageKey('lists.all'),
              padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.xl),
              children: [
                if (rows.isEmpty)
                  AnimatedEmptyState(
                    key: const ValueKey('lists.all.empty'),
                    kind: EmptyStateKind.emptyList,
                    title: l.listsAllEmptyTitle,
                    body: l.listsAllEmptyBody,
                  ),
                for (final (title, lists) in named) ...[
                  SectionHeader(
                    title: title,
                    subtitle: texts.lists(lists.length),
                    padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.m, Space.xs, Space.s),
                  ),
                  for (final r in lists) row(r),
                ],
                if (orphans.isNotEmpty) ...[
                  SectionHeader(
                    key: const ValueKey('lists.all.orphans'),
                    title: l.listsOrphanGroup,
                    subtitle: l.listsOrphanGroupBody,
                    padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.m, Space.xs, Space.s),
                  ),
                  for (final r in orphans) row(r),
                ],
              ],
            ),
    );
  }
}

class _HostGoneCard extends StatelessWidget {
  const _HostGoneCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return GlassCard(
      glow: false,
      borderColor: t.warning.withValues(alpha: 0.45),
      padding: const EdgeInsetsDirectional.all(Space.l),
      child: Row(
        children: [
          Icon(Icons.link_off_rounded, size: 20, color: t.warning),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.listsHostGoneTitle, style: text.titleSmall),
                const SizedBox(height: 2),
                Text(l.listsHostGoneBody, style: text.bodySmall!.copyWith(color: t.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ListRow extends ConsumerWidget {
  const _ListRow({
    required this.row,
    required this.totals,
    required this.texts,
    required this.onOpen,
    this.grip,
  });

  final RecordListRow row;
  final ListTotals totals;
  final ListTexts texts;

  /// The drag handle, where the lists can be reordered (one host's
  /// screen); null where they cannot (all of them together).
  final Widget? grip;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final posted = row.postedAt != null;
    return ActionableItem(
      key: ValueKey('lists.list.${row.id}'),
      semanticLabel: [
        texts.name(row.name),
        texts.progress(totals),
        if (posted) l.listsPostedBadge,
      ].join(', '),
      onTap: () {
        Fx.fire(Sfx.navigate);
        onOpen();
      },
      swipeEnabled: false,
      actions: ItemActions(
        onEdit: () => ListActions.editList(context, ref, row: row),
        onDuplicate: () => ListActions.duplicateList(context, ref, row),
        onDelete: () => ListActions.deleteList(context, ref, row),
      ),
      child: GlassCard(
        glow: false,
        seed: row.id.hashCode % 89 / 10,
        padding: EdgeInsetsDirectional.zero,
        child: Row(
          children: [
            Expanded(
              child: ListCard(
                name: row.name,
                totals: totals,
                texts: texts,
                currency: row.currency,
                posted: posted,
                amountMilli: posted ? row.postedAmountMilli : (totals.doneAmountMilli == 0 ? null : totals.doneAmountMilli),
              ),
            ),
            if (grip != null)
              SizedBox(width: 40, height: 48, child: Center(child: grip))
            else
              const SizedBox(width: Space.s),
          ],
        ),
      ),
    );
  }
}

/// One list: its ring, the add row, the lines he ticks, and – when the
/// host gives it one – a bar underneath (the budget's «سجّلها مصروف»).
class ListScreen extends ConsumerStatefulWidget {
  const ListScreen({super.key, required this.listId, this.bottomBar, this.animateBackdrop = true});

  final String listId;

  /// A host's own action under the list (money's post bar); null for a
  /// plain list.
  final Widget? bottomBar;

  /// Pass false in battery-saver mode.
  final bool animateBackdrop;

  @override
  ConsumerState<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends ConsumerState<ListScreen> {
  final _ringKey = GlobalKey();
  final _heroKey = GlobalKey<ActionableItemState>();

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final texts = ListTexts.of(context, ref.watch(listCurrenciesProvider).value ?? ListCurrencies.fallback);
    final async = ref.watch(listBundleProvider(widget.listId));
    final bundle = async.value;

    if (bundle == null) {
      return MadarScaffold(
        title: l.listsTitle,
        animateBackdrop: widget.animateBackdrop,
        body: Center(
          child: async.hasValue
              ? AnimatedEmptyState(
                  key: const ValueKey('lists.gone'),
                  kind: EmptyStateKind.noResults,
                  title: l.listsGoneTitle,
                  body: '',
                )
              : const OrbitLoader(size: 36),
        ),
      );
    }

    final totals = bundle.totals;
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ActionableItem(
          key: _heroKey,
          semanticLabel: [texts.name(bundle.name), texts.progress(totals)].join(', '),
          onTap: () => ListActions.editList(context, ref, row: bundle.row),
          swipeEnabled: false,
          actions: ItemActions(
            onEdit: () => ListActions.editList(context, ref, row: bundle.row),
            onDuplicate: () => ListActions.duplicateList(context, ref, bundle.row),
            onDelete: () async {
              final action = await ListActions.deleteList(context, ref, bundle.row);
              if (context.mounted) unawaited(Navigator.of(context).maybePop());
              return action;
            },
            extra: [
              if (totals.done > 0)
                ItemAction(
                  icon: Icons.undo_rounded,
                  label: l.listsUntickAll,
                  onSelected: () async {
                    await ListActions.untickAll(context, ref, bundle.id);
                    return null;
                  },
                ),
              if (totals.done > 0)
                ItemAction(
                  icon: Icons.playlist_remove_rounded,
                  label: l.listsClearDone,
                  tone: ActionTone.danger,
                  onSelected: () async {
                    await ListActions.clearDone(context, ref, bundle.id);
                    return null;
                  },
                ),
            ],
          ),
          child: _ListHeadCard(
            bundle: bundle,
            texts: texts,
            ringKey: _ringKey,
            // The bar underneath already says what the ticked part is
            // worth; one number, in one place.
            showTickedAmount: widget.bottomBar == null,
          ),
        ),
        const SizedBox(height: Space.s),
        ListAddRow(onAdd: (title) => unawaited(ListActions.addItem(context, ref, bundle.id, title))),
        if (bundle.lines.isEmpty) ...[
          const SizedBox(height: Space.s),
          AnimatedEmptyState(
            key: const ValueKey('lists.itemsEmpty'),
            kind: EmptyStateKind.emptyList,
            title: l.listsItemsEmptyTitle,
            body: l.listsItemsEmptyBody,
            illustrationSize: 96,
          ),
        ],
      ],
    );

    return MadarScaffold(
      title: bundle.name,
      backdropSeed: 5.1,
      animateBackdrop: widget.animateBackdrop,
      bottomBar: widget.bottomBar,
      actions: [
        MadarButton.icon(
          icon: Icons.add_rounded,
          semanticLabel: l.listsNewItemTitle,
          variant: MadarButtonVariant.ghost,
          sfx: Sfx.sheetOpen,
          onPressed: () => ListActions.editItem(context, ref, listId: bundle.id, currency: bundle.currency),
        ),
        MadarButton.icon(
          icon: Icons.more_vert_rounded,
          semanticLabel: MaterialLocalizations.of(context).showMenuTooltip,
          variant: MadarButtonVariant.ghost,
          sfx: Sfx.tap,
          onPressed: () => _heroKey.currentState?.openMenu(),
        ),
      ],
      body: ReorderableGlassList<ListLine>(
        key: const PageStorageKey('lists.items'),
        items: bundle.lines,
        itemKey: (line) => line.id,
        padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, 48),
        spacing: Space.xs,
        header: header,
        footer: bundle.lines.length > 1
            ? Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, 0),
                child: Text(
                  l.listsDragHint,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.tokens.textTertiary),
                ),
              )
            : null,
        onReorder: (ordered) => unawaited(ListActions.reorderItems(ref, [for (final x in ordered) x.id])),
        itemBuilder: (context, line, index, grip) =>
            _ItemRow(line: line, row: bundle.itemById(line.id), bundle: bundle, texts: texts, grip: grip),
      ),
    );
  }
}

/// The list's head: the ring, its name, what is left, the two amounts and
/// – once it was posted – what was posted.
class _ListHeadCard extends ConsumerWidget {
  const _ListHeadCard({
    required this.bundle,
    required this.texts,
    required this.ringKey,
    this.showTickedAmount = true,
  });

  final ListBundle bundle;
  final ListTexts texts;
  final GlobalKey ringKey;

  /// False when a host's own bar underneath shows that amount instead.
  final bool showTickedAmount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = texts.l;
    final text = Theme.of(context).textTheme;
    final totals = bundle.totals;
    final note = bundle.row.note?.trim();
    // The record it hangs on («بقالة», «عمّان»); null once that record is
    // gone, and the card simply says nothing about it.
    final host = ref.watch(hostNameProvider(bundle.host)).value;
    return GlassCard(
      glow: totals.complete,
      glowColor: t.success,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.l, Space.m, Space.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              KeyedSubtree(
                key: ringKey,
                child: ListRing(
                  totals: totals,
                  size: 76,
                  label: totals.isEmpty ? null : texts.progress(totals),
                  semanticLabel: texts.progress(totals),
                ),
              ),
              const SizedBox(width: Space.l),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // What is left, not the list's name again (the name is
                    // already the screen's title) – except on an empty
                    // list, where the invitation below says the rest.
                    Text(
                      totals.isEmpty ? bundle.name : texts.status(totals),
                      key: const ValueKey('lists.status'),
                      style: text.titleLarge!.copyWith(color: totals.complete ? t.success : t.textPrimary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (host != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        l.listsUnder(texts.name(host)),
                        key: const ValueKey('lists.host'),
                        style: text.bodyMedium!.copyWith(color: t.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: Space.m),
            Text(note, style: text.bodySmall!.copyWith(color: t.textSecondary, height: 1.45)),
          ],
          if (totals.hasAmounts && (showTickedAmount || totals.openAmountMilli != 0)) ...[
            const SizedBox(height: Space.m),
            Wrap(
              spacing: Space.m,
              runSpacing: Space.xs,
              children: [
                if (showTickedAmount && totals.doneAmountMilli != 0)
                  Text(
                    l.listsTickedAmount(texts.money(totals.doneAmountMilli, bundle.currency)),
                    key: const ValueKey('lists.tickedAmount'),
                    style: text.labelLarge!.copyWith(color: t.gold),
                  ),
                if (totals.openAmountMilli != 0)
                  Text(
                    l.listsOpenAmount(texts.money(totals.openAmountMilli, bundle.currency)),
                    style: text.labelMedium!.copyWith(color: t.textSecondary),
                  ),
              ],
            ),
          ],
          // A posted list says so in the bar underneath, which is where
          // the posting lives – never twice on one screen.
        ],
      ),
    );
  }
}

class _ItemRow extends ConsumerWidget {
  const _ItemRow({required this.line, required this.row, required this.bundle, required this.texts, required this.grip});

  final ListLine line;
  final RecordListItemRow? row;
  final ListBundle bundle;
  final ListTexts texts;
  final Widget grip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final item = row;
    Future<UndoableAction?> toggle() async {
      final fresh = item ?? await ref.read(listServiceProvider).item(line.id);
      if (fresh == null || !context.mounted) return null;
      return ListActions.toggle(context, ref, fresh);
    }

    return ActionableItem(
      key: ValueKey('lists.item.${line.id}'),
      // No semanticLabel: the row's own texts say it once.
      onTap: () async {
        await toggle();
      },
      onCompleteSwipe: toggle,
      completeIcon: line.done ? Icons.undo_rounded : Icons.check_rounded,
      completeLabel: line.done ? l.listsUntick : l.listsTick,
      actions: ItemActions(
        onEdit: item == null
            ? null
            : () => ListActions.editItem(context, ref, listId: bundle.id, row: item, currency: bundle.currency),
        onDelete: item == null ? null : () => ListActions.deleteItem(context, ref, item),
      ),
      quickActions: [
        if (item != null)
          QuickAction(
            icon: Icons.edit_rounded,
            label: l.actionEdit,
            tone: ActionTone.info,
            onPressed: () async {
              await ListActions.editItem(context, ref, listId: bundle.id, row: item, currency: bundle.currency);
              return null;
            },
          ),
        if (item != null)
          QuickAction(
            icon: Icons.delete_outline_rounded,
            label: MaterialLocalizations.of(context).deleteButtonTooltip,
            tone: ActionTone.danger,
            onPressed: () => ListActions.deleteItem(context, ref, item),
          ),
      ],
      child: ListItemTile(
        line: line,
        texts: texts,
        listCurrency: bundle.currency,
        dragHandle: grip,
      ),
    );
  }
}
