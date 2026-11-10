import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/interaction/sheets/field_inputs.dart' show kitInputDecoration;
import '../../../core/sound/sound_api.dart';
import '../data/work_models.dart';
import '../data/work_providers.dart';
import '../domain/board_columns.dart';
import 'work_labels.dart';

/// Edits a board's columns live: add, rename, drag to reorder, delete (its
/// cards move to the neighbour) and choose the done column. Every change
/// is saved at once with an undo toast.
Future<void> showColumnsSheet(BuildContext context, {required String boardId}) =>
    showInteractionSheet<void>(context, builder: (_) => ColumnsSheet(boardId: boardId));

class ColumnsSheet extends ConsumerStatefulWidget {
  const ColumnsSheet({super.key, required this.boardId});

  final String boardId;

  @override
  ConsumerState<ColumnsSheet> createState() => _ColumnsSheetState();
}

class _ColumnsSheetState extends ConsumerState<ColumnsSheet> {
  final _add = TextEditingController();

  @override
  void dispose() {
    _add.dispose();
    super.dispose();
  }

  Future<void> _apply(WorkBoard board, ColumnsEdit edit, String label, {Sfx sfx = Sfx.tap}) async {
    if (listEquals(edit.columns, board.columns) && edit.remap.isEmpty) return;
    final undo = await ref.read(workServiceProvider).editColumns(board.id, edit);
    if (!mounted) return;
    Fx.fire(sfx);
    unawaited(showUndoToast(context, UndoableAction(label: label, undo: undo)));
  }

  Future<void> _rename(WorkBoard board, BoardColumn c, WorkTexts texts) async {
    final l = texts.l;
    final res = await showEditSheet(
      context,
      title: l.workRenameColumn,
      icon: Icons.edit_rounded,
      fields: [FieldSpec.text('label', l.workColumnName, required: true, maxLength: BoardColumns.maxLabelLength)],
      initial: {'label': texts.column(c)},
    );
    final label = res?['label'] as String?;
    if (label == null || !mounted) return;
    await _apply(board, BoardColumns.rename(board.columns, c.id, label), l.workColumnsSaved);
  }

  Future<void> _delete(WorkBoard board, BoardColumn c, WorkTexts texts) async {
    if (board.columns.length <= 1) {
      Fx.fire(Sfx.error);
      return;
    }
    final edit = BoardColumns.remove(board.columns, c.id);
    final target = BoardColumns.byId(edit.columns, edit.remap[c.id]!)!;
    await _apply(board, edit, texts.l.workColumnDeleted(texts.name(texts.column(target))), sfx: Sfx.delete);
  }

  Future<void> _addColumn(WorkBoard board, WorkTexts texts) async {
    final label = _add.text.trim();
    if (label.isEmpty || board.columns.length >= BoardColumns.maxColumns) {
      Fx.fire(Sfx.error);
      return;
    }
    _add.clear();
    await _apply(board, BoardColumns.add(board.columns, label), texts.l.workColumnsSaved, sfx: Sfx.complete);
  }

  @override
  Widget build(BuildContext context) {
    final texts = WorkTexts.of(context);
    final l = texts.l;
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final board = ref.watch(workBoardProvider(widget.boardId)).value;
    final counts = ref.watch(workBoardCardsProvider(widget.boardId)).value ?? const [];
    if (board == null) return InteractionSheetFrame(title: l.workEditColumns, body: const SizedBox(height: 80));
    int countOf(String id) => counts.where((c) => board.columnOf(c) == id).length;

    return InteractionSheetFrame(
      title: l.workEditColumns,
      subtitle: l.workEditColumnsHint,
      icon: Icons.view_column_rounded,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ReorderableGlassList<BoardColumn>(
            items: board.columns,
            itemKey: (c) => c.id,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsetsDirectional.zero,
            animateEntrance: false,
            onReorder: (order) => _apply(
              board,
              BoardColumns.reorder(board.columns, [for (final c in order) c.id]),
              l.workColumnsSaved,
              sfx: Sfx.drop,
            ),
            itemBuilder: (context, c, index, grip) {
              final name = texts.column(c);
              return GlassCard(
                padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.xs, Space.xs, Space.xs),
                borderColor: c.isDone ? t.success.withValues(alpha: 0.5) : null,
                child: Row(
                  children: [
                    grip,
                    Expanded(
                      child: MadarPressable(
                        onTap: () => _rename(board, c, texts),
                        sfx: Sfx.sheetOpen,
                        semanticLabel: '${l.workRenameColumn}: $name',
                        child: Padding(
                          padding: const EdgeInsetsDirectional.symmetric(vertical: Space.s),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleSmall),
                              Text(
                                c.isDone ? l.workDoneColumn : texts.cards(countOf(c.id)),
                                style: text.labelSmall!.copyWith(color: c.isDone ? t.success : t.textTertiary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: c.isDone ? l.workDoneColumn : l.workMakeDoneColumn,
                      isSelected: c.isDone,
                      icon: Icon(Icons.task_alt_rounded, color: c.isDone ? t.success : t.textTertiary),
                      onPressed: () => _apply(
                        board,
                        BoardColumns.markDone(board.columns, c.isDone ? null : c.id),
                        l.workColumnsSaved,
                        sfx: c.isDone ? Sfx.toggleOff : Sfx.toggleOn,
                      ),
                    ),
                    IconButton(
                      tooltip: l.workDeleteColumn,
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: board.columns.length > 1 ? t.danger.withValues(alpha: 0.85) : t.textTertiary,
                      ),
                      onPressed: board.columns.length > 1 ? () => _delete(board, c, texts) : null,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: Space.s),
          Text(l.workDoneColumnHint, style: text.labelSmall),
          const SizedBox(height: Space.l),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _add,
                  maxLength: BoardColumns.maxLabelLength,
                  enabled: board.columns.length < BoardColumns.maxColumns,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addColumn(board, texts),
                  decoration: kitInputDecoration(context, hint: l.workColumnName),
                ),
              ),
              const SizedBox(width: Space.s),
              MadarButton.icon(
                icon: Icons.add_rounded,
                semanticLabel: l.workAddColumn,
                variant: MadarButtonVariant.primary,
                sfx: Sfx.tap,
                onPressed: board.columns.length < BoardColumns.maxColumns ? () => _addColumn(board, texts) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
