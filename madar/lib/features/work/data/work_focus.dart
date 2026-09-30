import '../../../core/db/database.dart';
import '../domain/card_task_sync.dart';
import '../domain/top3.dart';
import '../domain/work_days.dart';
import 'work_models.dart';

/// Turns rows into Top 3 [FocusItem]s and card ⇄ task sync states.
abstract final class WorkFocus {
  /// Every card of the non-archived [boards] and every task in [tasks] as a
  /// focus item. A task placed for a card is represented by that card (its
  /// window and day are carried on the card's item); a task pointing at a
  /// card that no longer exists counts as a task.
  static List<FocusItem> collect({
    required List<WorkBoard> boards,
    required List<BoardCardRow> cards,
    required List<TaskRow> tasks,
  }) {
    final boardById = {for (final b in boards) b.id: b};
    final cardIds = <String>{};
    final placed = <String, TaskRow>{};
    for (final t in tasks) {
      final c = t.cardId;
      if (c == null) continue;
      final prev = placed[c];
      if (prev == null || (prev.done && !t.done)) placed[c] = t;
    }
    final out = <FocusItem>[];
    for (final c in cards) {
      final b = boardById[c.boardId];
      if (b == null || b.archived) continue;
      cardIds.add(c.id);
      final task = placed[c.id];
      out.add(
        FocusItem(
          kind: FocusKind.card,
          id: c.id,
          title: c.title,
          done: b.isDone(c),
          flagged: c.isTop3,
          boardId: b.id,
          boardName: b.name,
          color: b.color,
          window: c.window,
          date: task?.date,
          dueDate: c.dueDate,
          assignee: c.assignee,
          sortKey: c.sortOrder,
        ),
      );
    }
    final allCardIds = {for (final c in cards) c.id};
    for (final t in tasks) {
      final c = t.cardId;
      // Placed for a card: shown as the card (or hidden with its archived board).
      if (c != null && allCardIds.contains(c)) continue;
      out.add(
        FocusItem(
          kind: FocusKind.task,
          id: t.id,
          title: t.title,
          done: t.done,
          flagged: t.isTop3,
          projectId: t.projectId,
          window: t.window,
          date: t.date,
          sortKey: 1000000 + t.sortOrder,
        ),
      );
    }
    return out;
  }

  /// Tasks worth loading for the Top 3: open ones, flagged ones and those
  /// done on [today] (so a finished focus item still shows as done).
  static bool taskRelevant(TaskRow t, DateTime today) =>
      !t.done || t.isTop3 || (t.doneAt != null && WorkDays.same(WorkDays.dateOnly(t.doneAt!.toLocal()), today));

  static CardState cardState(BoardCardRow c, WorkBoard board) => CardState(
    id: c.id,
    title: c.title,
    columnId: c.columnId,
    window: c.window,
    isTop3: c.isTop3,
    updatedAt: c.updatedAt,
    doneColumnId: board.doneColumnId,
    openColumnId: board.openColumnId,
  );

  static LinkedTaskState taskState(TaskRow t) => LinkedTaskState(
    id: t.id,
    title: t.title,
    window: t.window,
    done: t.done,
    isTop3: t.isTop3,
    updatedAt: t.updatedAt,
    date: t.date,
  );
}
