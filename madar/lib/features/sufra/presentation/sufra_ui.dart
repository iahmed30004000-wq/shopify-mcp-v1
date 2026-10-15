/// «السفرة»'s screens, built on the Part 5 engine: the kitchen world's own
/// hub card, what is in the house, her dishes, one dish, «شو نطبخ اليوم»,
/// her constraints and the cooked log.
///
/// Import `package:madar/features/sufra/presentation/sufra_ui.dart`.
///
/// Three rules every screen in here keeps, straight from the engine's
/// handoff (`sufra.dart`):
///
/// 1. a dish Madar is **unsure** about is never presented as cookable – it
///    says which ingredient it could not compare and offers the one tap
///    that fixes it;
/// 2. a dish held back always shows the reason, with the override;
/// 3. a missing amount Madar does not know is shown **without a number**.
///
/// And one of its own: a write that did nothing says so. `useUp` is silent
/// when it cannot convert, so [SufraActions.useSome] asks first and
/// answers «ما قدرت أنقّص الكمية…» instead of a toast that pretends.
///
/// Nothing in here reads Health or Money.
library;

export 'screens/history_screen.dart';
export 'screens/pantry_screen.dart';
export 'screens/recipe_screen.dart';
export 'screens/recipes_screen.dart';
export 'screens/rules_screen.dart';
export 'screens/tonight_screen.dart';
export 'sufra_actions.dart' show SufraActions, sufraBottomPadding;
export 'sufra_nav.dart';
export 'sufra_texts.dart';
export 'widgets/sufra_dish.dart';
export 'widgets/sufra_today_card.dart';
export 'widgets/sufra_widgets.dart';
