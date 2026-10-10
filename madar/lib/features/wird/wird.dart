/// The daily wird: plans (a khatma in N days, or N pages / juz / hizb /
/// ayat a day), today's portion with catch-up, streaks, projected finish,
/// history, and reminders after the plan's prayer.
///
/// Screens: [WirdScreen]; the compact [WirdTodayCard] for the Faith planet
/// page. Providers, the service and the reminder scheduler are in `data/`;
/// pure logic (Quran axis, the day-by-day engine, reminder planning) in
/// `domain/`.
library;

export 'data/wird_notifications.dart';
export 'data/wird_providers.dart';
export 'data/wird_service.dart';
export 'domain/calendar_days.dart';
export 'domain/quran_axis.dart';
export 'domain/wird_engine.dart';
export 'domain/wird_plan.dart';
export 'domain/wird_reminders.dart';
export 'presentation/surah_picker_sheet.dart' show showSurahPicker, surahSearchKey;
export 'presentation/wird_actions.dart';
export 'presentation/wird_labels.dart';
export 'presentation/wird_navigation.dart';
export 'presentation/wird_plan_sheet.dart' show showWirdPlanSheet, WirdPlanSheet, wirdTemplateIcon;
export 'presentation/wird_progress_sheet.dart';
export 'presentation/wird_screen.dart';
export 'presentation/wird_today_card.dart';
export 'presentation/widgets/wird_history_calendar.dart';
export 'presentation/widgets/wird_plan_tile.dart';
export 'presentation/widgets/wird_target_panel.dart';
