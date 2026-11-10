/// The Growth planet: learning goals with targets and units, progress
/// logging, pace and projections, streaks and a per-goal chart.
///
/// * [GrowthScreen] – all goals; [GoalScreen] – one goal.
/// * [showGoalSheet] / [GoalSheet], [showLogProgressSheet] /
///   [LogProgressSheet] – the editors.
/// * [GrowthTodayCard] – the compact card for the Growth planet hub.
/// * [GrowthService] (+ providers) – reads and undoable writes; every log
///   is mirrored in the activity stream (planet `growth`).
library;

export 'data/growth_providers.dart';
export 'data/growth_service.dart';
export 'domain/goal_chart_data.dart';
export 'domain/goal_math.dart';
export 'domain/growth_days.dart';
export 'domain/growth_goal.dart';
export 'domain/growth_streaks.dart';
export 'domain/growth_units.dart';
export 'presentation/goal_celebration.dart';
export 'presentation/goal_screen.dart';
export 'presentation/goal_sheet.dart';
export 'presentation/growth_actions.dart';
export 'presentation/growth_navigation.dart';
export 'presentation/growth_screen.dart';
export 'presentation/growth_texts.dart';
export 'presentation/growth_today_card.dart';
export 'presentation/log_progress_sheet.dart';
export 'presentation/widgets/goal_chart.dart';
export 'presentation/widgets/goal_tile.dart';
