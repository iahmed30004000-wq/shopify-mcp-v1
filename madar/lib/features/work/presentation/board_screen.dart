import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/sound/sound_api.dart';
import '../data/work_models.dart';
import '../data/work_providers.dart';
import '../domain/card_filter.dart';
import '../domain/top3.dart';
import 'widgets/kanban_board.dart';
import 'widgets/work_widgets.dart';
import 'work_actions.dart';
import 'work_labels.dart';

/// One board as a kanban: column tabs, horizontally scrolling columns
/// (right-to-left in Arabic), cards to drag / swipe / long-press, a filter
/// by assignee and due date, and a button to add a card.
class BoardScreen extends ConsumerStatefulWidget {
  const BoardScreen({super.key, required this.boardId, this.onDeleted});

  final String boardId;

  /// Called after the board was deleted from its menu (default: pop).
  final VoidCallback? onDeleted;

  @override
  ConsumerState<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends ConsumerState<BoardScreen> {
  CardFilter _filter = CardFilter.all;
  bool _showFilter = false;
  String? _visibleColumn;
  final _kanban = GlobalKey<KanbanBoardState>();

  Future<void> _options(WorkBoard board, WorkTexts texts) async {
    final l = texts.l;
    final target = await showMoveSheet(
      context,
      title: l.workBoardOptions,
      subtitle: board.name,
      icon: Icons.tune_rounded,
      targets: [
        MoveTarget(id: 'edit', label: l.workEditBoard, icon: Icons.edit_rounded),
        MoveTarget(id: 'columns', label: l.workEditColumns, icon: Icons.view_column_rounded),
        MoveTarget(
          id: 'archive',
          label: board.archived ? l.workUnarchive : l.workArchive,
          icon: board.archived ? Icons.unarchive_rounded : Icons.archive_rounded,
        ),
        MoveTarget(id: 'delete', label: l.actionDelete, icon: Icons.delete_outline_rounded),
      ],
    );
    if (target == null || !mounted) return;
    UndoableAction? action;
    switch (target.id) {
      case 'edit':
        action = await WorkActions.editBoard(context, ref, board);
      case 'columns':
        await WorkActions.editColumns(context, board);
      case 'archive':
        action = await WorkActions.setArchived(context, ref, board, !board.archived);
      case 'delete':
        Fx.fire(Sfx.delete);
        action = await WorkActions.deleteBoard(context, ref, board);
        if (mounted) {
          if (widget.onDeleted != null) {
            widget.onDeleted!();
          } else {
            Navigator.of(context).maybePop();
          }
        }
    }
    if (action != null && mounted) unawaited(showUndoToast(context, action));
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(workCardTaskSyncProvider);
    final t = context.tokens;
    final texts = WorkTexts.of(context);
    final l = texts.l;
    final text = Theme.of(context).textTheme;
    final board = ref.watch(workBoardProvider(widget.boardId));
    final cards = ref.watch(workBoardCardsProvider(widget.boardId));
    final today = ref.watch(workTodayProvider);
    final items = ref.watch(workFocusItemsProvider).value ?? const <FocusItem>[];
    final windowDays = {
      for (final i in items)
        if (i.kind == FocusKind.card && i.boardId == widget.boardId) i.id: i.date,
    };
    final b = board.value;
    final list = cards.value;

    if (b == null || list == null) {
      return MadarScaffold(
        title: l.workTitle,
        body: board.isLoading || cards.isLoading
            ? const Center(child: OrbitLoader())
            : AnimatedEmptyState(kind: EmptyStateKind.noData, title: l.workBoardMissing),
      );
    }

    final assignees = <String>{
      for (final c in list)
        if ((c.assignee ?? '').trim().isNotEmpty) c.assignee!.trim(),
    }.toList()..sort();
    final country = texts.country(b.country);

    return MadarScaffold(
      titleWidget: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ColorOrb(color: workColor(t, b.color), size: 12),
          const SizedBox(width: Space.s),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleMedium!.copyWith(height: 1.25)),
                if (country != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.flag_rounded, size: 11, color: t.textTertiary),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          country,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelSmall!.copyWith(height: 1.2),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        _FilterButton(
          active: _filter.isActive,
          open: _showFilter,
          label: l.workFilter,
          onTap: () => setState(() => _showFilter = !_showFilter),
        ),
        MadarButton.icon(
          icon: Icons.add_rounded,
          semanticLabel: l.workAddCard,
          variant: MadarButtonVariant.ghost,
          sfx: Sfx.sheetOpen,
          onPressed: () => WorkActions.newCard(context, ref, b, columnId: _visibleColumn ?? b.columns.first.id),
        ),
        MadarButton.icon(
          icon: Icons.more_horiz_rounded,
          semanticLabel: l.workBoardOptions,
          variant: MadarButtonVariant.ghost,
          sfx: Sfx.sheetOpen,
          onPressed: () => _options(b, texts),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedSize(
            duration: context.motion(MadarMotion.medium),
            curve: MadarMotion.emphasized,
            alignment: AlignmentDirectional.topStart,
            child: _showFilter || _filter.isActive
                ? _FilterBar(
                    filter: _filter,
                    assignees: assignees,
                    onChanged: (f) => setState(() => _filter = f),
                  )
                : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: Space.xs),
          Expanded(
            child: KanbanBoard(
              key: _kanban,
              board: b,
              cards: list,
              today: today,
              filter: _filter,
              windowDays: windowDays,
              onVisibleColumn: (id) => _visibleColumn = id,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.active, required this.open, required this.label, required this.onTap});

  final bool active, open;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        MadarButton.icon(
          icon: Icons.filter_list_rounded,
          semanticLabel: label,
          variant: open || active ? MadarButtonVariant.secondary : MadarButtonVariant.ghost,
          sfx: open ? Sfx.toggleOff : Sfx.toggleOn,
          onPressed: onTap,
        ),
        if (active)
          PositionedDirectional(
            top: 8,
            end: 8,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: t.accent, shape: BoxShape.circle),
            ),
          ),
      ],
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.filter, required this.assignees, required this.onChanged});

  final CardFilter filter;
  final List<String> assignees;
  final ValueChanged<CardFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final texts = WorkTexts.of(context);
    final l = texts.l;
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    Widget label(String s) => Padding(
      padding: const EdgeInsetsDirectional.only(end: Space.s),
      child: Text(s, style: text.labelMedium!.copyWith(color: t.textTertiary)),
    );
    final dues = {
      DueFilter.overdue: l.workFilterOverdue,
      DueFilter.today: l.workFilterToday,
      DueFilter.week: l.workFilterWeek,
      DueFilter.noDate: l.workFilterNoDate,
    };
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: Space.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.l),
            child: Row(
              children: [
                // Clearing sits first so it is always in reach (the rows
                // scroll; the end of a row is usually off-screen).
                if (filter.isActive)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: Space.m),
                    child: MadarChip(
                      label: l.workFilterClear,
                      icon: Icons.close_rounded,
                      dense: true,
                      sfx: Sfx.toggleOff,
                      onSelected: (_) => onChanged(CardFilter.all),
                    ),
                  ),
                label(l.workFilterDue),
                for (final e in dues.entries)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: Space.s),
                    child: MadarChip(
                      label: e.value,
                      dense: true,
                      selected: filter.due == e.key,
                      onSelected: (on) => onChanged(filter.withDue(on ? e.key : DueFilter.any)),
                    ),
                  ),
              ],
            ),
          ),
          if (assignees.isNotEmpty) ...[
            const SizedBox(height: Space.s),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.l),
              child: Row(
                children: [
                  label(l.workFilterAssignee),
                  for (final a in [...assignees, CardFilter.unassigned])
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: Space.s),
                      child: MadarChip(
                        label: a == CardFilter.unassigned ? l.workUnassigned : a,
                        icon: a == CardFilter.unassigned ? Icons.person_off_outlined : Icons.person_outline_rounded,
                        dense: true,
                        selected: filter.assignee == a,
                        onSelected: (on) => onChanged(filter.withAssignee(on ? a : null)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
