import 'package:flutter/foundation.dart';

import '../../../core/db/database.dart';
import '../../../core/domain/enums.dart';
import '../domain/board_columns.dart';
import '../domain/countdown.dart';
import '../domain/project_math.dart';

/// A board with its parsed columns and archive flag.
@immutable
class WorkBoard {
  WorkBoard(this.row, {this.archived = false}) : columns = BoardColumns.parse(row.columns);

  final BoardRow row;
  final List<BoardColumn> columns;
  final bool archived;

  String get id => row.id;
  String get name => row.name;
  String? get country => row.country;
  int? get color => row.color;

  String? get doneColumnId => BoardColumns.hasDone(columns) ? BoardColumns.doneId : null;
  String get openColumnId => BoardColumns.firstOpenId(columns);

  /// The column a card is shown in (its own, or the first open one when
  /// that column was deleted meanwhile).
  String columnOf(BoardCardRow card) => BoardColumns.resolve(columns, card.columnId);

  bool isDone(BoardCardRow card) => card.columnId == BoardColumns.doneId && doneColumnId != null;

  @override
  bool operator ==(Object other) =>
      other is WorkBoard && other.row == row && other.archived == archived;

  @override
  int get hashCode => Object.hash(row, archived);
}

/// Counts for a board tile.
@immutable
class BoardSummary {
  const BoardSummary({
    required this.board,
    required this.perColumn,
    required this.open,
    required this.done,
    required this.dueToday,
    required this.overdue,
  });

  final WorkBoard board;

  /// Cards per column id (every column present).
  final Map<String, int> perColumn;
  final int open, done, dueToday, overdue;

  int get total => open + done;

  static BoardSummary of(WorkBoard board, Iterable<BoardCardRow> cards, DateTime today) {
    final per = {for (final c in board.columns) c.id: 0};
    var open = 0, done = 0, dueToday = 0, overdue = 0;
    for (final c in cards) {
      if (c.boardId != board.id) continue;
      final col = board.columnOf(c);
      per[col] = (per[col] ?? 0) + 1;
      final isDone = board.isDone(c);
      if (isDone) {
        done++;
      } else {
        open++;
      }
      switch (DueRules.of(c.dueDate, today, done: isDone)) {
        case DueStatus.today:
          dueToday++;
        case DueStatus.overdue:
          overdue++;
        default:
          break;
      }
    }
    return BoardSummary(board: board, perColumn: per, open: open, done: done, dueToday: dueToday, overdue: overdue);
  }
}

/// The editable fields of a card.
@immutable
class CardDraft {
  const CardDraft({
    required this.title,
    this.notes,
    this.assignee,
    this.dueDate,
    this.columnId,
    this.window,
    this.windowDay,
    this.isTop3 = false,
  });

  factory CardDraft.of(BoardCardRow card, {DateTime? windowDay}) => CardDraft(
    title: card.title,
    notes: card.notes,
    assignee: card.assignee,
    dueDate: card.dueDate,
    columnId: card.columnId,
    window: card.window,
    windowDay: windowDay,
    isTop3: card.isTop3,
  );

  final String title;
  final String? notes, assignee;
  final DateTime? dueDate;

  /// Column (a new card: where it is created; null = the first column).
  final String? columnId;

  /// Prayer window the card is placed in (null: not placed) and the day.
  final PrayerWindow? window;
  final DateTime? windowDay;
  final bool isTop3;

  CardDraft copyWith({
    String? title,
    String? notes,
    String? assignee,
    DateTime? dueDate,
    bool clearDue = false,
    String? columnId,
    PrayerWindow? window,
    bool clearWindow = false,
    DateTime? windowDay,
    bool? isTop3,
  }) => CardDraft(
    title: title ?? this.title,
    notes: notes ?? this.notes,
    assignee: assignee ?? this.assignee,
    dueDate: clearDue ? null : dueDate ?? this.dueDate,
    columnId: columnId ?? this.columnId,
    window: clearWindow ? null : window ?? this.window,
    windowDay: windowDay ?? this.windowDay,
    isTop3: isTop3 ?? this.isTop3,
  );
}

/// The editable fields of a project.
@immutable
class ProjectDraft {
  const ProjectDraft({
    required this.name,
    this.description,
    this.deadline,
    this.status = ProjectStatus.active,
    this.planetKey = ProjectRules.defaultPlanet,
    this.color,
  });

  factory ProjectDraft.of(ProjectRow p) => ProjectDraft(
    name: p.name,
    description: p.description,
    deadline: p.deadline,
    status: p.status,
    planetKey: ProjectRules.planetOf(p.planetKey),
    color: p.color,
  );

  final String name;
  final String? description;
  final DateTime? deadline;
  final ProjectStatus status;
  final String planetKey;
  final int? color;
}

/// A project with its checklist progress.
@immutable
class ProjectView {
  const ProjectView(this.row, this.progress);

  final ProjectRow row;
  final ProjectProgress progress;

  String get id => row.id;
}

/// Result of checking / unchecking a checklist item.
@immutable
class ItemToggle {
  const ItemToggle({required this.done, required this.progress, required this.completedProject});

  /// The item's new state.
  final bool done;
  final ProjectProgress progress;

  /// This tick brought the checklist to 100 %.
  final bool completedProject;
}

/// Result of a card move.
@immutable
class CardMoveResult {
  const CardMoveResult({this.completed = false, this.reopened = false});

  static const CardMoveResult none = CardMoveResult();

  /// The card entered / left the done column.
  final bool completed, reopened;
}
