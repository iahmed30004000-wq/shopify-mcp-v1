/// Wellbeing (Health, phase 4): pain tracker with body map, mood & stress
/// check-ins, stress-reduction habits, the worry window, guided breathing,
/// local insights and the gentle support banner. Tracking only – no advice.
library;

export 'data/phone_dialer.dart';
export 'data/wellbeing_providers.dart';
export 'data/wellbeing_service.dart';
export 'data/worry_reminders.dart';
export 'domain/body_map.dart';
export 'domain/breathing.dart';
export 'domain/habit_streaks.dart';
export 'domain/insights.dart';
export 'domain/support_rule.dart';
export 'domain/wellbeing_data.dart';
export 'domain/wellbeing_drafts.dart';
export 'domain/wellbeing_settings.dart';
export 'domain/wellbeing_stats.dart';
export 'domain/worry_window.dart';
export 'presentation/breathing_screen.dart' show BreathingScreen, BreathRing;
export 'presentation/sheets/mood_check_in_sheet.dart';
export 'presentation/sheets/pain_log_sheet.dart';
export 'presentation/sheets/tag_manager_sheet.dart';
export 'presentation/sheets/worry_sheets.dart';
export 'presentation/wellbeing_texts.dart';
export 'presentation/wellbeing_screen.dart' show WellbeingScreen, WellbeingTab, WellbeingTabBar;
export 'presentation/widgets/body_map.dart' show BodyMapView, BodyMapPainter, BodyMapColors, BodyMark;
export 'presentation/widgets/mood_face.dart';
export 'presentation/widgets/support_banner.dart';
export 'presentation/widgets/today_card.dart';
