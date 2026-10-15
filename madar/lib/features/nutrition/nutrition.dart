/// Nutrition: the food library, the food log, the meal plan, the user's own
/// food rules, the risk rating computed **only** from those rules, and local
/// observations over his own data.
///
/// Import `package:madar/features/nutrition/nutrition.dart`.
///
/// What this package is and is not:
/// * it **tracks and shows**. It holds no nutrition database, no medical
///   knowledge and no advice; every tag, rule and weight is the user's own;
/// * a rating exists only where he has written a rule, and it always carries
///   its reasons – `RiskEngine.rateEntry` returns null when no rule applies;
/// * everything is on device, in the encrypted database, and a fresh install
///   starts completely empty.
///
/// Where to start:
/// * `nutritionServiceProvider` – every write, each returning an undo;
/// * `nutritionSummaryProvider` – one object for a card or the planet score;
/// * `nutritionTodayPlanProvider` – planned vs eaten today;
/// * `nutritionFoodSearchProvider(query)` – Arabic-aware quick entry;
/// * `nutritionDayRiskProvider(day)` / `nutritionEntryRiskProvider(entry)`;
/// * `nutritionInsightsProvider(lateLabel)` – the honest observations.
library;

export 'data/nutrition_providers.dart';
export 'data/nutrition_reminders.dart';
export 'data/nutrition_service.dart';
export 'domain/food_library.dart';
export 'domain/food_log.dart';
export 'domain/food_rules.dart';
export 'domain/meal_plan.dart';
export 'domain/meal_reminders.dart';
export 'domain/nutrition_insights.dart';
export 'domain/nutrition_summary.dart';
export 'domain/plan_compare.dart';
export 'domain/risk.dart';

/// The day and time helpers Nutrition shares with the Body planet it lives
/// on (calendar-day arithmetic that survives a zone change, and `"HH:mm"`
/// parsing).
export '../body/domain/body_clock.dart' show BodyDays, BodyTimes, BodyWallClock, LocalBodyWallClock;
