import 'dart:async';

import 'package:drift/drift.dart';

import '../../../core/db/database.dart';
import '../../../core/db/repositories/repositories.dart';
import '../../../core/domain/enums.dart';
import '../domain/board_columns.dart';
import '../domain/card_filter.dart';
import '../domain/card_task_sync.dart';
import '../domain/project_math.dart';
import '../domain/top3.dart';
import '../domain/work_days.dart';
import 'work_focus.dart';
import 'work_models.dart';

/// Reverts a change made by [WorkService].
typedef WorkUndo = Future<void> Function();

/// Records a completion for a planet (the orbit's pulse hub in the app:
/// logs the activity and pulses the planet).
typedef WorkRecorder = Future<void> Function(String planetKey, String kind, String? refTable, String? refId, DateTime at);

/// Everything the Work planet writes: boards and their columns, kanban
/// cards (moves, Top 3, placement in prayer windows kept in step with the
/// placed task), the Top 3 day and its morning carry-over, projects with
/// checklists and project tasks. Every change returns a [WorkUndo] that
/// restores the exact previous rows and side effects (activity entries,
/// placed tasks). No Flutter dependencies.
class WorkService {
  WorkService(this.repos, {DateTime Function()? clock, WorkRecorder? recorder})
    : _clock = clock ?? DateTime.now,
      _record = recorder;

  final Repositories repos;
  final DateTime Function() _clock;
  final WorkRecorder? _record;

  static const String planetKey = 'work';

  /// Activity kinds.
  static const String cardDoneKind = 'card.done';
  static const String itemDoneKind = 'projectItem.done';
  static const String projectDoneKind = 'project.done';

  /// Same kind as the home panel writes for a finished task.
  static const String taskDoneKind = 'task.done';

  /// Key-value keys: archived board ids (JSON list) and the day the Top 3
  /// flags were set for (`yyyy-MM-dd`).
  static const String archivedKey = 'work.archivedBoards';
  static const String top3DayKey = 'work.top3Day';

  MadarDatabase get _db => repos.db;
  EntityRepository<$BoardsTable, BoardRow> get _boards => repos.boards;
  EntityRepository<$BoardCardsTable, BoardCardRow> get _cards => repos.boardCards;
  EntityRepository<$TasksTable, TaskRow> get _tasks => repos.tasks;
  EntityRepository<$ProjectsTable, ProjectRow> get _projects => repos.projects;
  EntityRepository<$ProjectItemsTable, ProjectItemRow> get _items => repos.projectItems;

  String get cardsTable => _cards.tableName;
  String get itemsTable => _items.tableName;
  String get tasksTable => _tasks.tableName;
  String get projectsTable => _projects.tableName;

  DateTime get _today => WorkDays.dateOnly(_clock());

  Future<void> _log(String planet, String kind, String table, String id, DateTime at) async {
    final r = _record;
    if (r != null) {
      await r(planet, kind, table, id, at);
    } else {
      await repos.activity.log(planetKey: planet, kind: kind, refTable: table, refId: id, at: at);
    }
  }

  static String? _blank(String? s) {
    final v = s?.trim();
    return v == null || v.isEmpty ? null : v;
  }

  // ================================================================ reads

  Stream<List<BoardRow>> watchBoardRows() => _boards.watchAll();

  Stream<Set<String>> watchArchivedIds() => repos.keyValues.watchJson(archivedKey).map(_idSet);

  Future<Set<String>> archivedIds() async => _idSet(await repos.keyValues.getJson(archivedKey));

  static Set<String> _idSet(Object? json) => json is List ? {for (final e in json) if (e is String) e} : <String>{};

  Future<List<WorkBoard>> boards() async {
    final archived = await archivedIds();
    return [for (final r in await _boards.getAll()) WorkBoard(r, archived: archived.contains(r.id))];
  }

  Future<WorkBoard?> board(String id) async {
    final r = await _boards.byId(id);
    return r == null ? null : WorkBoard(r, archived: (await archivedIds()).contains(id));
  }

  Stream<List<BoardCardRow>> watchCards({String? boardId}) =>
      _cards.watchAll(where: boardId == null ? null : (c) => c.boardId.equals(boardId));

  /// Tasks the Top 3 and the sync look at: open, flagged, placed for a
  /// card or finished recently.
  Stream<List<TaskRow>> watchFocusTasks() {
    final since = WorkDays.add(_today, -1);
    return _tasks.watchAll(
      where: (t) =>
          t.done.equals(false) |
          t.isTop3.equals(true) |
          t.cardId.isNotNull() |
          t.doneAt.julianday.isBiggerOrEqual(Variable<DateTime>(since).julianday),
    );
  }

  Stream<DateTime?> watchTop3Day() => repos.keyValues.watchJson(top3DayKey).map(WorkDays.parse);

  Future<DateTime?> top3Day() async => WorkDays.parse(await repos.keyValues.getJson(top3DayKey));

  /// Past assignees of every card (for suggestions).
  Stream<List<AssigneeUse>> watchAssigneeUses() => _cards
      .watchAll(where: (c) => c.assignee.isNotNull())
      .map((rows) => [for (final c in rows) AssigneeUse(c.assignee!, c.updatedAt)]);

  Stream<List<ProjectRow>> watchProjects() => _projects.watchAll();

  Stream<List<ProjectItemRow>> watchItems({String? projectId}) =>
      _items.watchAll(where: projectId == null ? null : (i) => i.projectId.equals(projectId));

  Stream<List<TaskRow>> watchProjectTasks(String projectId) =>
      _tasks.watchAll(where: (t) => t.projectId.equals(projectId));

  // =============================================================== boards

  Future<BoardRow> createBoard({required String name, String? country, int? color, List<BoardColumn>? columns}) {
    return _boards.insert(
      BoardsCompanion.insert(
        name: name.trim(),
        country: Value(_blank(country)),
        color: Value(color),
        columns: Value(BoardColumns.encode(columns ?? BoardColumns.defaults())),
      ),
    );
  }

  Future<WorkUndo> updateBoard(String id, {required String name, String? country, int? color}) async {
    final before = await _boards.byId(id);
    if (before == null) return () async {};
    await _boards.setColumns(id, {'name': name.trim(), 'country': _blank(country), 'color': color});
    return () => _boards.restore(before);
  }

  Future<WorkUndo> setArchived(String id, bool archived) async {
    final before = await archivedIds();
    final next = {...before};
    archived ? next.add(id) : next.remove(id);
    await repos.keyValues.setJson(archivedKey, next.toList()..sort());
    return () => repos.keyValues.setJson(archivedKey, before.toList()..sort());
  }

  Future<void> reorderBoards(List<String> idsInOrder) => _boards.reorder(idsInOrder);

  /// Deletes a board with its cards, the tasks that place them and their
  /// completion activity.
  Future<WorkUndo> deleteBoard(String id) async {
    late final BoardRow? board;
    late final List<BoardCardRow> cards;
    late final List<TaskRow> tasks;
    final activity = <ActivityRow>[];
    final archivedBefore = await archivedIds();
    await _db.transaction(() async {
      cards = await _cards.deleteWhere((c) => c.boardId.equals(id));
      final ids = [for (final c in cards) c.id];
      tasks = ids.isEmpty ? const [] : await _tasks.deleteWhere((t) => t.cardId.isIn(ids));
      for (final c in cards) {
        activity.addAll(await repos.activity.removeFor(refTable: cardsTable, refId: c.id));
      }
      board = await _boards.delete(id);
    });
    if (archivedBefore.contains(id)) await setArchived(id, false);
    return () async {
      await _db.transaction(() async {
        if (board != null) await _boards.restore(board!);
        await _cards.restoreAll(cards);
        await _tasks.restoreAll(tasks);
        await repos.activityLog.restoreAll(activity);
      });
      if (archivedBefore.contains(id)) await setArchived(id, true);
    };
  }

  /// Applies a column edit: the new columns and, all at once, the cards
  /// that follow a re-keyed or removed column. A card leaving or entering
  /// the done column that way is not a completion (no activity) – the
  /// board's meaning changed, not the work.
  Future<WorkUndo> editColumns(String boardId, ColumnsEdit edit) async {
    final before = await _boards.byId(boardId);
    if (before == null) return () async {};
    final moved = <BoardCardRow>[];
    await _db.transaction(() async {
      await _boards.setColumn(boardId, 'columns', BoardColumns.encode(edit.columns));
      if (edit.changesCards) {
        final cards = await _cards.getAll(where: (c) => c.boardId.equals(boardId) & c.columnId.isIn(edit.remap.keys));
        moved.addAll(cards);
        for (final c in cards) {
          await _cards.setColumn(c.id, 'columnId', BoardColumns.remapped(edit.remap, c.columnId));
        }
      }
    });
    await syncAll();
    return () async {
      await _db.transaction(() async {
        await _boards.restore(before);
        await _cards.restoreAll(moved);
      });
      await syncAll();
    };
  }

  // ================================================================ cards

  Future<WorkBoard> _boardOf(String boardId) async {
    final b = await board(boardId);
    if (b == null) throw StateError('No board $boardId');
    return b;
  }

  Future<List<TaskRow>> _linkedTasks(String cardId) => _tasks.getAll(where: (t) => t.cardId.equals(cardId));

  /// Creates a card at the end of its column (the first one by default),
  /// placing it in a prayer window when the draft asks.
  Future<BoardCardRow> addCard(String boardId, CardDraft draft) async {
    final board = await _boardOf(boardId);
    final column = draft.columnId != null && BoardColumns.indexOf(board.columns, draft.columnId!) >= 0
        ? draft.columnId!
        : board.columns.first.id;
    var flag = draft.isTop3;
    if (flag) flag = (await _prepareFlag()).items.length < Top3Rules.max;
    final row = await _cards.insert(
      BoardCardsCompanion.insert(
        boardId: boardId,
        title: draft.title.trim(),
        columnId: Value(column),
        notes: Value(_blank(draft.notes)),
        assignee: Value(_blank(draft.assignee)),
        dueDate: Value(draft.dueDate == null ? null : WorkDays.dateOnly(draft.dueDate!)),
        isTop3: Value(flag),
      ),
    );
    if (board.isDone(row)) await _log(planetKey, cardDoneKind, cardsTable, row.id, _clock());
    if (draft.window != null) {
      await placeCard(row, draft.window, day: draft.windowDay);
      return (await _cards.byId(row.id))!;
    }
    return row;
  }

  /// Applies an edited card: fields, column (to the end of it), Top 3 flag
  /// (within the limit) and placement. The placed task follows.
  Future<WorkUndo> editCard(BoardCardRow card, CardDraft draft) async {
    final board = await _boardOf(card.boardId);
    final cardBefore = card;
    final tasksBefore = await _linkedTasks(card.id);
    final undos = <WorkUndo>[];
    final title = draft.title.trim().isEmpty ? card.title : draft.title.trim();
    await _db.transaction(() async {
      await _cards.setColumns(card.id, {
        'title': title,
        'notes': _blank(draft.notes),
        'assignee': _blank(draft.assignee),
        'dueDate': draft.dueDate == null ? null : WorkDays.dateOnly(draft.dueDate!),
      });
      for (final t in tasksBefore) {
        if (t.title != title) await _tasks.setColumn(t.id, 'title', title);
      }
    });
    if (draft.isTop3 != card.isTop3) {
      final (_, u) = await setCardTop3(card.id, draft.isTop3);
      if (u != null) undos.add(u);
    }
    final column = draft.columnId;
    if (column != null && column != board.columnOf(card) && BoardColumns.indexOf(board.columns, column) >= 0) {
      final (u, _) = await moveCard(card.id, column);
      undos.add(u);
    }
    final day = draft.windowDay == null ? null : WorkDays.dateOnly(draft.windowDay!);
    final open = CardTaskSync.primary([for (final t in tasksBefore) WorkFocus.taskState(t)]);
    final windowChanged = draft.window != card.window || (draft.window != null && day != null && !WorkDays.same(open?.date, day));
    if (windowChanged) undos.add(await placeCard((await _cards.byId(card.id))!, draft.window, day: day));
    return () async {
      for (final u in undos.reversed) {
        await u();
      }
      await _cards.restore(cardBefore);
      await _tasks.restoreAll(tasksBefore);
    };
  }

  /// Moves a card to [toColumn]. With [orderInColumn] (the destination's
  /// card ids top to bottom, the card included) the column is reordered;
  /// otherwise the card goes to the end. Entering the done column records
  /// the completion and finishes the placed task; leaving it reopens both.
  Future<(WorkUndo, CardMoveResult)> moveCard(String cardId, String toColumn, {List<String>? orderInColumn}) async {
    final card = await _cards.byId(cardId);
    if (card == null) return (() async {}, CardMoveResult.none);
    final board = await _boardOf(card.boardId);
    final from = board.columnOf(card);
    final affected = await _cards.getAll(
      where: (c) => c.boardId.equals(card.boardId) & c.columnId.isIn({card.columnId, toColumn}),
    );
    final tasksBefore = await _linkedTasks(cardId);
    final wasDone = board.isDone(card);
    final nowDone = board.doneColumnId != null && toColumn == board.doneColumnId;
    final now = _clock();
    var removed = const <ActivityRow>[];
    await _db.transaction(() async {
      if (from != toColumn || card.columnId != toColumn) {
        await _cards.setColumn(cardId, 'columnId', toColumn, moveToEnd: orderInColumn == null);
      }
      if (orderInColumn != null) await _cards.reorder(orderInColumn);
      if (!wasDone && nowDone) {
        for (final t in tasksBefore) {
          if (!t.done) await _tasks.setColumns(t.id, {'done': true, 'doneAt': now});
        }
      } else if (wasDone && !nowDone) {
        for (final t in tasksBefore) {
          if (t.done) await _tasks.setColumns(t.id, {'done': false, 'doneAt': null});
        }
      }
    });
    if (!wasDone && nowDone) await _log(planetKey, cardDoneKind, cardsTable, cardId, now);
    if (wasDone && !nowDone) removed = await repos.activity.removeFor(refTable: cardsTable, refId: cardId, kind: cardDoneKind);
    final result = CardMoveResult(completed: !wasDone && nowDone, reopened: wasDone && !nowDone);
    return (
      () async {
        await _db.transaction(() async {
          await _cards.restoreAll(affected);
          await _tasks.restoreAll(tasksBefore);
        });
        if (result.completed) await repos.activity.removeFor(refTable: cardsTable, refId: cardId, kind: cardDoneKind);
        if (removed.isNotEmpty) await repos.activityLog.restoreAll(removed);
      },
      result,
    );
  }

  /// Moves a finished card to the done column (end), or a finished one back
  /// to the first open column.
  Future<(WorkUndo, CardMoveResult)> toggleCardDone(String cardId) async {
    final card = await _cards.byId(cardId);
    if (card == null) return (() async {}, CardMoveResult.none);
    final board = await _boardOf(card.boardId);
    if (board.isDone(card)) return moveCard(cardId, board.openColumnId);
    final done = board.doneColumnId;
    if (done == null) return (() async {}, CardMoveResult.none);
    return moveCard(cardId, done);
  }

  /// Moves a card to another board (same column id when it has one, else
  /// its first open column – or its done column when the card was done).
  Future<WorkUndo> moveCardToBoard(String cardId, String boardId) async {
    final card = await _cards.byId(cardId);
    if (card == null || card.boardId == boardId) return () async {};
    final from = await _boardOf(card.boardId);
    final to = await _boardOf(boardId);
    final wasDone = from.isDone(card);
    String column;
    if (wasDone && to.doneColumnId != null) {
      column = to.doneColumnId!;
    } else if (BoardColumns.indexOf(to.columns, card.columnId) >= 0 && card.columnId != BoardColumns.doneId) {
      column = card.columnId;
    } else {
      column = to.openColumnId;
    }
    final nowDone = to.doneColumnId != null && column == to.doneColumnId;
    final tasksBefore = await _linkedTasks(cardId);
    var removed = const <ActivityRow>[];
    await _db.transaction(() async {
      await _cards.setColumns(cardId, {'boardId': boardId, 'columnId': column}, moveToEnd: true);
      if (wasDone && !nowDone) {
        for (final t in tasksBefore) {
          if (t.done) await _tasks.setColumns(t.id, {'done': false, 'doneAt': null});
        }
      }
    });
    if (wasDone && !nowDone) removed = await repos.activity.removeFor(refTable: cardsTable, refId: cardId, kind: cardDoneKind);
    return () async {
      await _db.transaction(() async {
        await _cards.restore(card);
        await _tasks.restoreAll(tasksBefore);
      });
      if (removed.isNotEmpty) await repos.activityLog.restoreAll(removed);
    };
  }

  /// Copies a card right after the original (not placed, not in the Top 3).
  Future<(BoardCardRow, WorkUndo)> duplicateCard(String cardId) async {
    final copy = await _cards.duplicate(cardId, overrides: const {'isTop3': false, 'window': null});
    return (copy, () async => _cards.delete(copy.id).then((_) {}));
  }

  /// Deletes a card with the tasks that place it and its activity.
  Future<WorkUndo> deleteCard(String cardId) async {
    BoardCardRow? row;
    var tasks = const <TaskRow>[];
    var activity = const <ActivityRow>[];
    await _db.transaction(() async {
      tasks = await _tasks.deleteWhere((t) => t.cardId.equals(cardId));
      activity = await repos.activity.removeFor(refTable: cardsTable, refId: cardId);
      row = await _cards.delete(cardId);
    });
    return () async {
      await _db.transaction(() async {
        if (row != null) await _cards.restore(row!);
        await _tasks.restoreAll(tasks);
        await repos.activityLog.restoreAll(activity);
      });
    };
  }

  /// Places a card in a prayer [window] on [day] (today by default): the
  /// task that carries it into the home panel's window list is created or
  /// moved (to the end of that window's list). A null [window] takes it out
  /// of every window: open placed tasks are removed, finished ones kept
  /// (unlinked) as history.
  Future<WorkUndo> placeCard(BoardCardRow card, PrayerWindow? window, {DateTime? day}) async {
    final board = await _boardOf(card.boardId);
    final cardBefore = (await _cards.byId(card.id)) ?? card;
    final tasksBefore = await _linkedTasks(card.id);
    final date = WorkDays.dateOnly(day ?? _clock());
    final created = <String>[];
    await _db.transaction(() async {
      await _cards.setColumn(card.id, 'window', window);
      if (window == null) {
        for (final t in tasksBefore) {
          if (t.done) {
            await _tasks.setColumn(t.id, 'cardId', null);
          } else {
            await _tasks.delete(t.id);
          }
        }
        return;
      }
      final open = [for (final t in tasksBefore) if (!t.done) t];
      final primary = CardTaskSync.primary([for (final t in open) WorkFocus.taskState(t)]);
      if (primary != null) {
        final t = open.firstWhere((x) => x.id == primary.id);
        final moveToEnd = t.window != window || !WorkDays.same(t.date, date);
        await _tasks.setColumns(t.id, {'window': window, 'date': date, 'title': cardBefore.title}, moveToEnd: moveToEnd);
      } else {
        final done = board.isDone(cardBefore);
        final t = await _tasks.insert(
          TasksCompanion.insert(
            title: cardBefore.title,
            window: Value(window),
            date: Value(date),
            planetKey: const Value(planetKey),
            isTop3: Value(cardBefore.isTop3),
            cardId: Value(card.id),
            done: Value(done),
            doneAt: Value(done ? _clock() : null),
          ),
        );
        created.add(t.id);
      }
    });
    return () async {
      await _db.transaction(() async {
        for (final id in created) {
          await _tasks.delete(id);
        }
        await _cards.restore(cardBefore);
        await _tasks.restoreAll(tasksBefore);
      });
    };
  }

  // ================================================================ Top 3

  /// Today's Top 3 from the database, once.
  Future<Top3State> top3State() async {
    final today = _today;
    final boardList = await boards();
    final cards = await _cards.getAll();
    final tasks = [for (final t in await _tasks.getAll()) if (WorkFocus.taskRelevant(t, today)) t];
    final items = WorkFocus.collect(boards: boardList, cards: cards, tasks: tasks);
    return Top3Rules.evaluate(flagged: [for (final i in items) if (i.flagged) i], storedDay: await top3Day(), today: today);
  }

  /// Settles an earlier day's flags before a new one is set (keeping the
  /// unfinished ones, as "carry over" would) and stamps today.
  Future<Top3State> _prepareFlag() async {
    var state = await top3State();
    if (state.needsRollover) {
      await _applyRollover(state.needsCarryOver ? Top3Rules.carryOver(state) : Top3Rules.silent(state));
      await _setTop3Day(state.today);
      state = await top3State();
    } else if (!WorkDays.same(state.storedDay, state.today)) {
      await _setTop3Day(state.today);
    }
    return state;
  }

  Future<void> _setTop3Day(DateTime day) => repos.keyValues.setJson(top3DayKey, WorkDays.key(day));

  Future<void> _applyRollover(Top3Rollover r) async {
    await _db.transaction(() async {
      for (final i in r.unflag) {
        await _setFlagRaw(i.kind, i.id, false);
      }
      for (final i in r.redate) {
        await _tasks.setColumn(i.id, 'date', _today);
      }
    });
  }

  Future<void> _setFlagRaw(FocusKind kind, String id, bool on) async {
    if (kind == FocusKind.card) {
      await _cards.setColumn(id, 'isTop3', on);
      for (final t in await _linkedTasks(id)) {
        if (t.isTop3 != on) await _tasks.setColumn(t.id, 'isTop3', on);
      }
    } else {
      await _tasks.setColumn(id, 'isTop3', on);
    }
  }

  /// Flags / unflags a card for today's Top 3. Adding to a full Top 3 does
  /// nothing and answers [Top3AddResult.full].
  Future<(Top3AddResult, WorkUndo?)> setCardTop3(String cardId, bool on) =>
      _setFlag(FocusKind.card, cardId, on);

  /// Flags / unflags a task (a task placed for a card flags the card).
  Future<(Top3AddResult, WorkUndo?)> setTaskTop3(String taskId, bool on) async {
    final t = await _tasks.byId(taskId);
    if (t == null) return (Top3AddResult.alreadyIn, null);
    final card = t.cardId == null ? null : await _cards.byId(t.cardId!);
    return card != null ? _setFlag(FocusKind.card, card.id, on) : _setFlag(FocusKind.task, taskId, on);
  }

  /// Flags / unflags a focus item.
  Future<(Top3AddResult, WorkUndo?)> setFocusTop3(FocusItem item, bool on) => _setFlag(item.kind, item.id, on);

  Future<(Top3AddResult, WorkUndo?)> _setFlag(FocusKind kind, String id, bool on) async {
    final cardsBefore = await _cards.getAll(where: (c) => c.isTop3.equals(true) | c.id.equals(id));
    final tasksBefore = await _tasks.getAll(
      where: (t) => t.isTop3.equals(true) | t.id.equals(id) | t.cardId.equals(id),
    );
    final dayBefore = await repos.keyValues.getJson(top3DayKey);
    WorkUndo undo() => () async {
      await _db.transaction(() async {
        final nowCards = await _cards.getAll(where: (c) => c.isTop3.equals(true));
        for (final c in nowCards) {
          if (!cardsBefore.any((b) => b.id == c.id)) await _cards.setColumn(c.id, 'isTop3', false);
        }
        final nowTasks = await _tasks.getAll(where: (t) => t.isTop3.equals(true));
        for (final t in nowTasks) {
          if (!tasksBefore.any((b) => b.id == t.id)) await _tasks.setColumn(t.id, 'isTop3', false);
        }
        await _cards.restoreAll(cardsBefore);
        await _tasks.restoreAll(tasksBefore);
      });
      if (dayBefore == null) {
        await repos.keyValues.remove(top3DayKey);
      } else {
        await repos.keyValues.setJson(top3DayKey, dayBefore);
      }
    };

    if (!on) {
      await _setFlagRaw(kind, id, false);
      return (Top3AddResult.added, undo());
    }
    final state = await _prepareFlag();
    final key = '${kind.name}:$id';
    if (state.items.any((i) => i.key == key)) return (Top3AddResult.alreadyIn, null);
    if (state.items.length >= Top3Rules.max) return (Top3AddResult.full, null);
    await _db.transaction(() => _setFlagRaw(kind, id, true));
    return (Top3AddResult.added, undo());
  }

  /// Replaces [out] with [incoming] in today's Top 3.
  Future<WorkUndo> swapTop3(FocusItem out, FocusItem incoming) async {
    final (_, u1) = await setFocusTop3(out, false);
    final (_, u2) = await setFocusTop3(incoming, true);
    return () async {
      if (u2 != null) await u2();
      if (u1 != null) await u1();
    };
  }

  /// Morning carry-over: keeps yesterday's unfinished focus for today.
  Future<WorkUndo> carryOverTop3() => _rollover(Top3Rules.carryOver);

  /// Morning carry-over: starts today with an empty Top 3.
  Future<WorkUndo> startFreshTop3() => _rollover(Top3Rules.startFresh);

  /// Clears an earlier day's finished flags when nothing needs asking.
  Future<void> settleTop3() async {
    final state = await top3State();
    if (state.needsRollover && !state.needsCarryOver) {
      await _applyRollover(Top3Rules.silent(state));
      await _setTop3Day(state.today);
    }
  }

  Future<WorkUndo> _rollover(Top3Rollover Function(Top3State) plan) async {
    final state = await top3State();
    final cardsBefore = await _cards.getAll(where: (c) => c.isTop3.equals(true));
    final tasksBefore = await _tasks.getAll(where: (t) => t.isTop3.equals(true) | t.cardId.isNotNull());
    final dayBefore = await repos.keyValues.getJson(top3DayKey);
    await _applyRollover(plan(state));
    await _setTop3Day(state.today);
    return () async {
      await _db.transaction(() async {
        await _cards.restoreAll(cardsBefore);
        await _tasks.restoreAll(tasksBefore);
      });
      if (dayBefore == null) {
        await repos.keyValues.remove(top3DayKey);
      } else {
        await repos.keyValues.setJson(top3DayKey, dayBefore);
      }
    };
  }

  /// Completes / reopens a focus item (a card through its board's done
  /// column; a task like the home panel does).
  Future<(WorkUndo, bool done)> toggleFocusDone(FocusItem item) async {
    if (item.kind == FocusKind.card) {
      final (u, r) = await toggleCardDone(item.id);
      return (u, r.completed);
    }
    final t = await _tasks.byId(item.id);
    if (t == null) return (() async {}, false);
    return (await toggleTaskDone(t), !t.done);
  }

  // ================================================================= sync

  /// Brings every card placed in a window and its task back in step (see
  /// [CardTaskSync]). Returns how many cards or tasks were written.
  Future<int> syncAll() async {
    final linked = await _tasks.getAll(where: (t) => t.cardId.isNotNull());
    final placedCards = await _cards.getAll(where: (c) => c.window.isNotNull());
    final byCard = <String, List<TaskRow>>{};
    for (final t in linked) {
      byCard.putIfAbsent(t.cardId!, () => []).add(t);
    }
    final cardIds = {...byCard.keys, for (final c in placedCards) c.id};
    if (cardIds.isEmpty) return 0;
    final cards = await _cards.getAll(where: (c) => c.id.isIn(cardIds));
    final boardsById = {for (final b in await boards()) b.id: b};
    var writes = 0;
    final now = _clock();
    for (final c in cards) {
      final board = boardsById[c.boardId];
      if (board == null) continue;
      final tasks = byCard[c.id] ?? const <TaskRow>[];
      final primary = CardTaskSync.primary([for (final t in tasks) WorkFocus.taskState(t)]);
      final plan = CardTaskSync.reconcile(WorkFocus.cardState(c, board), primary);
      if (plan.isEmpty) continue;
      await _db.transaction(() async {
        if (plan.card.isNotEmpty) {
          await _cards.setColumns(c.id, plan.card, moveToEnd: plan.card.containsKey('columnId'));
          writes++;
        }
        if (plan.task.isNotEmpty && primary != null) {
          final values = {...plan.task};
          if (values.containsKey('done')) values['doneAt'] = values['done'] == true ? now : null;
          await _tasks.setColumns(primary.id, values);
          writes++;
        }
      });
      // The task's own completion was already recorded by whoever finished
      // it; a card finished from Work and reopened from home drops its entry.
      if (plan.cardReopened) await repos.activity.removeFor(refTable: cardsTable, refId: c.id, kind: cardDoneKind);
    }
    return writes;
  }

  // ============================================================= projects

  Future<ProjectRow> createProject(ProjectDraft d) => _projects.insert(
    ProjectsCompanion.insert(
      name: d.name.trim(),
      description: Value(_blank(d.description)),
      deadline: Value(d.deadline == null ? null : WorkDays.dateOnly(d.deadline!)),
      status: Value(d.status),
      planetKey: Value(ProjectRules.planetOf(d.planetKey)),
      color: Value(d.color),
    ),
  );

  Future<WorkUndo> editProject(ProjectRow p, ProjectDraft d) async {
    final before = (await _projects.byId(p.id)) ?? p;
    await _projects.setColumns(p.id, {
      'name': d.name.trim().isEmpty ? p.name : d.name.trim(),
      'description': _blank(d.description),
      'deadline': d.deadline == null ? null : WorkDays.dateOnly(d.deadline!),
      'planetKey': ProjectRules.planetOf(d.planetKey),
      'color': d.color,
    });
    final undoStatus = d.status != before.status ? await setProjectStatus(p.id, d.status) : null;
    return () async {
      if (undoStatus != null) await undoStatus();
      await _projects.restore(before);
    };
  }

  /// Sets a project's status; finishing it records the completion on its
  /// planet.
  Future<WorkUndo> setProjectStatus(String projectId, ProjectStatus status) async {
    final before = await _projects.byId(projectId);
    if (before == null || before.status == status) return () async {};
    await _projects.setColumn(projectId, 'status', status);
    var removed = const <ActivityRow>[];
    if (status == ProjectStatus.done) {
      await _log(ProjectRules.planetOf(before.planetKey), projectDoneKind, projectsTable, projectId, _clock());
    } else if (before.status == ProjectStatus.done) {
      removed = await repos.activity.removeFor(refTable: projectsTable, refId: projectId, kind: projectDoneKind);
    }
    return () async {
      await _projects.restore(before);
      if (status == ProjectStatus.done) {
        await repos.activity.removeFor(refTable: projectsTable, refId: projectId, kind: projectDoneKind);
      }
      if (removed.isNotEmpty) await repos.activityLog.restoreAll(removed);
    };
  }

  Future<void> reorderProjects(List<String> ids) => _projects.reorder(ids);

  /// Deletes a project and its checklist; its tasks stay, unlinked.
  Future<WorkUndo> deleteProject(String projectId) async {
    ProjectRow? row;
    var items = const <ProjectItemRow>[];
    var tasks = const <TaskRow>[];
    await _db.transaction(() async {
      items = await _items.deleteWhere((i) => i.projectId.equals(projectId));
      tasks = await _tasks.getAll(where: (t) => t.projectId.equals(projectId));
      for (final t in tasks) {
        await _tasks.setColumn(t.id, 'projectId', null);
      }
      row = await _projects.delete(projectId);
    });
    return () async {
      await _db.transaction(() async {
        if (row != null) await _projects.restore(row!);
        await _items.restoreAll(items);
        await _tasks.restoreAll(tasks);
      });
    };
  }

  /// Copies a project (right after it) with its checklist unticked.
  Future<(ProjectRow, WorkUndo)> duplicateProject(String projectId) async {
    final copy = await _projects.duplicate(projectId, overrides: {'status': ProjectStatus.active});
    final items = await _items.getAll(where: (i) => i.projectId.equals(projectId));
    await _db.transaction(() async {
      for (final i in items) {
        await _items.insert(
          ProjectItemsCompanion.insert(projectId: copy.id, body: i.body, dueDate: Value(i.dueDate)),
        );
      }
    });
    return (
      copy,
      () async {
        await _items.deleteWhere((i) => i.projectId.equals(copy.id));
        await _projects.delete(copy.id);
      },
    );
  }

  Future<ProjectItemRow> addItem(String projectId, String body, {DateTime? dueDate}) => _items.insert(
    ProjectItemsCompanion.insert(
      projectId: projectId,
      body: body.trim(),
      dueDate: Value(dueDate == null ? null : WorkDays.dateOnly(dueDate)),
    ),
  );

  Future<WorkUndo> editItem(ProjectItemRow item, {required String body, DateTime? dueDate}) async {
    final before = (await _items.byId(item.id)) ?? item;
    await _items.setColumns(item.id, {
      'body': body.trim().isEmpty ? item.body : body.trim(),
      'dueDate': dueDate == null ? null : WorkDays.dateOnly(dueDate),
    });
    return () => _items.restore(before);
  }

  /// Ticks / unticks a checklist item, recording the completion on the
  /// project's planet; reports whether the checklist just reached 100 %.
  Future<(ItemToggle, WorkUndo)> toggleItem(ProjectItemRow item) async {
    final before = (await _items.byId(item.id)) ?? item;
    final project = await _projects.byId(item.projectId);
    final planet = ProjectRules.planetOf(project?.planetKey);
    final siblingsBefore = await _items.getAll(where: (i) => i.projectId.equals(item.projectId));
    final progressBefore = ProjectProgress.of(siblingsBefore.map((i) => i.done));
    final done = !before.done;
    await _items.setColumn(item.id, 'done', done);
    var removed = const <ActivityRow>[];
    if (done) {
      await _log(planet, itemDoneKind, itemsTable, item.id, _clock());
    } else {
      removed = await repos.activity.removeFor(refTable: itemsTable, refId: item.id, kind: itemDoneKind);
    }
    final progress = ProjectProgress.of([for (final i in siblingsBefore) i.id == item.id ? done : i.done]);
    return (
      ItemToggle(done: done, progress: progress, completedProject: progress.reachedFullFrom(progressBefore)),
      () async {
        await _items.restore(before);
        if (done) await repos.activity.removeFor(refTable: itemsTable, refId: item.id, kind: itemDoneKind);
        if (removed.isNotEmpty) await repos.activityLog.restoreAll(removed);
      },
    );
  }

  Future<void> reorderItems(List<String> ids) => _items.reorder(ids);

  Future<WorkUndo> deleteItem(String itemId) async {
    ProjectItemRow? row;
    var activity = const <ActivityRow>[];
    await _db.transaction(() async {
      activity = await repos.activity.removeFor(refTable: itemsTable, refId: itemId);
      row = await _items.delete(itemId);
    });
    return () async {
      if (row != null) await _items.restore(row!);
      await repos.activityLog.restoreAll(activity);
    };
  }

  /// Adds a task to a project, in [window] on [date] (both optional).
  Future<TaskRow> addProjectTask(
    ProjectRow project, {
    required String title,
    PrayerWindow window = PrayerWindow.anytime,
    DateTime? date,
  }) => _tasks.insert(
    TasksCompanion.insert(
      title: title.trim(),
      window: Value(window),
      date: Value(date == null ? null : WorkDays.dateOnly(date)),
      planetKey: Value(ProjectRules.planetOf(project.planetKey)),
      projectId: Value(project.id),
    ),
  );

  /// Finishes / reopens a task exactly as the home panel does (same
  /// activity kind), so either screen can undo the other.
  Future<WorkUndo> toggleTaskDone(TaskRow task) async {
    final before = (await _tasks.byId(task.id)) ?? task;
    if (before.done) {
      final removed = await repos.activity.removeFor(refTable: tasksTable, refId: task.id, kind: taskDoneKind);
      await _tasks.setColumns(task.id, {'done': false, 'doneAt': null});
      await syncAll();
      return () async {
        await _tasks.restore(before);
        await repos.activityLog.restoreAll(removed);
        await syncAll();
      };
    }
    final now = _clock();
    await _tasks.setColumns(task.id, {'done': true, 'doneAt': now});
    final planet = before.planetKey;
    if (planet != null) await _log(planet, taskDoneKind, tasksTable, task.id, now);
    await syncAll();
    return () async {
      await _tasks.restore(before);
      await repos.activity.removeFor(refTable: tasksTable, refId: task.id, kind: taskDoneKind);
      await syncAll();
    };
  }

  /// Moves a task to another window (end of its list).
  Future<WorkUndo> moveTask(TaskRow task, PrayerWindow window, {DateTime? date}) async {
    final before = (await _tasks.byId(task.id)) ?? task;
    await _tasks.setColumns(task.id, {'window': window, if (date != null) 'date': WorkDays.dateOnly(date)}, moveToEnd: true);
    await syncAll();
    return () async {
      await _tasks.restore(before);
      await syncAll();
    };
  }

  /// Deletes a task with its completion activity (reminders are the home
  /// panel's; tasks created here have none).
  Future<WorkUndo> deleteTask(String taskId) async {
    final activity = await repos.activity.removeFor(refTable: tasksTable, refId: taskId);
    final row = await _tasks.delete(taskId);
    await syncAll();
    return () async {
      if (row != null) await _tasks.restore(row);
      await repos.activityLog.restoreAll(activity);
      await syncAll();
    };
  }
}

/// Runs [WorkService.syncAll] whenever tasks or cards change (coalesced,
/// timer-free), so a card placed in a window follows what the home panel
/// does to its task.
class WorkSyncRunner {
  WorkSyncRunner(this.service);

  final WorkService service;
  StreamSubscription<Set<TableUpdate>>? _sub;
  bool _running = false, _again = false, _disposed = false;

  void start() {
    if (_sub != null || _disposed) return;
    final db = service.repos.db;
    _sub = db
        .tableUpdates(TableUpdateQuery.onAllTables([db.tasks, db.boardCards]))
        .listen((_) => _kick(), onError: (Object _) {});
    _kick();
  }

  void _kick() {
    if (_disposed) return;
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    scheduleMicrotask(_run);
  }

  Future<void> _run() async {
    try {
      do {
        _again = false;
        if (_disposed) return;
        await service.syncAll();
      } while (_again);
    } catch (_) {
      // A closed database during teardown; the next change retries.
    } finally {
      _running = false;
    }
  }

  void dispose() {
    _disposed = true;
    unawaited(_sub?.cancel());
    _sub = null;
  }
}
