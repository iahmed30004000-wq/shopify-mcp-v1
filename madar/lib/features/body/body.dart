/// The Body planet: training plan by weekday, workout log with progress,
/// the "avoid" list, intermittent fasting and water.
///
/// Import `package:madar/features/body/body.dart`.
library;

export 'data/body_providers.dart';
export 'data/body_reminders.dart';
export 'data/body_service.dart';
export 'domain/body_clock.dart';
export 'domain/body_reminder_plan.dart';
export 'domain/body_week.dart';
export 'domain/fasting.dart';
export 'domain/training.dart';
export 'domain/water.dart';
export 'presentation/body_actions.dart' show BodyActions, bodyTabBottomPadding;
export 'presentation/body_screen.dart';
export 'presentation/body_texts.dart';
export 'presentation/sheets/exercise_history_sheet.dart';
export 'presentation/sheets/exercise_sheet.dart';
export 'presentation/sheets/workout_log_sheet.dart';
export 'presentation/tabs/avoid_tab.dart';
export 'presentation/tabs/fasting_tab.dart';
export 'presentation/tabs/plan_tab.dart';
export 'presentation/tabs/today_tab.dart';
export 'presentation/tabs/water_tab.dart';
export 'presentation/widgets/body_charts.dart';
export 'presentation/widgets/body_today_card.dart';
export 'presentation/widgets/body_widgets.dart';
export 'presentation/widgets/fasting_card.dart';
export 'presentation/widgets/fasting_ring.dart';
export 'presentation/widgets/water_card.dart';
