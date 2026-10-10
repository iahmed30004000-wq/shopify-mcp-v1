/// The food screens built on the Nutrition engine: the «الأكل» tab of the
/// Body planet, the quick log, the food library, the meal plan (built and
/// compared against what he ate), his conditions with his own rules, and
/// the plain observations.
///
/// Import `package:madar/features/nutrition/presentation/nutrition_ui.dart`.
///
/// Nothing in here judges, diagnoses or advises: a rating appears only
/// where he wrote a rule, and it is always shown with its reasons in his
/// own wording.
library;

export 'nutrition_actions.dart' show NutritionActions, nutritionBottomPadding;
export 'nutrition_nav.dart';
export 'nutrition_texts.dart';
export 'screens/conditions_screen.dart';
export 'screens/food_library_screen.dart';
export 'screens/insights_screen.dart';
export 'screens/meal_plan_screen.dart';
export 'sheets/quick_log_sheet.dart';
export 'sheets/rule_sheet.dart';
export 'tabs/food_tab.dart';
export 'widgets/nutrition_today_card.dart';
export 'widgets/nutrition_widgets.dart';
