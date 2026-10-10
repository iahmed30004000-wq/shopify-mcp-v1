/// The Work planet: kanban boards per country / business (editable
/// columns with a done column, cards that drag between columns and swipe
/// forward / back), today's Top 3 across cards and tasks with the morning
/// carry-over, cards placed in prayer windows (kept in step with the task
/// the home panel lists), and projects with checklists and countdowns.
///
/// Screens: [WorkScreen], [BoardScreen], [ProjectsScreen], [ProjectScreen];
/// cards for hubs: [Top3Card], [WorkTodayCard]; sheets: [CardSheet]
/// (`showCardSheet`), board / columns / project editors. The service and
/// providers are in `data/`; pure logic (columns, kanban geometry, card ⇄
/// task sync, Top 3 rules, countdowns, filters) in `domain/`.
library;

export 'data/work_focus.dart';
export 'data/work_models.dart';
export 'data/work_providers.dart';
export 'data/work_service.dart';
export 'domain/board_columns.dart';
export 'domain/card_filter.dart';
export 'domain/card_task_sync.dart';
export 'domain/countdown.dart';
export 'domain/kanban.dart';
export 'domain/project_math.dart';
export 'domain/top3.dart';
export 'domain/work_days.dart';
export 'presentation/board_screen.dart';
export 'presentation/board_sheet.dart';
export 'presentation/card_sheet.dart';
export 'presentation/columns_sheet.dart';
export 'presentation/top3_sheet.dart';
export 'presentation/widgets/kanban_board.dart' show KanbanBoard, KanbanBoardState;
export 'presentation/widgets/kanban_card.dart' show KanbanCard, KanbanCardView;
export 'presentation/work_actions.dart';
export 'presentation/work_labels.dart';
export 'presentation/project_screen.dart';
export 'presentation/project_sheet.dart';
export 'presentation/projects_screen.dart';
export 'presentation/top3_card.dart';
export 'presentation/widgets/project_widgets.dart';
export 'presentation/widgets/work_widgets.dart';
export 'presentation/work_navigation.dart';
export 'presentation/work_screen.dart';
export 'presentation/work_today_card.dart';
