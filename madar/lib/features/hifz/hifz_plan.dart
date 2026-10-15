/// «الحفظ» – memorisation at full strength (PLAN.md Part 14), **step 2:
/// the screens**.
///
/// Import `package:madar/features/hifz/hifz_plan.dart`.
///
/// Step 1 (`hifz_memorisation.dart`) finished the engine and left nothing
/// of it reachable. This is the way in:
///
/// | screen | route | what it is |
/// |---|---|---|
/// | [HifzPlanScreen] | `/hifz/plan` | the morning screen: the three portions, the backlog, one tap to start |
/// | [HifzDrillScreen] | pushed | one method on one stretch, and the result written into Part 13's log |
/// | [HifzMapScreen] | `/hifz/plan/map` | the mushaf coloured by strength, with the legend that reads it |
/// | [HifzGoalsScreen] | `/hifz/plan/goals` | «الكهف كل جمعة» and the rest, their reminders hung off the prayers |
/// | [HifzFindScreen] | `/hifz/find` | «شازام القرآن», typed – offline, tonight |
///
/// plus [HifzPlanTodayCard] on the Faith world's page.
///
/// **What runs on this phone tonight.** Six of the seven methods: writing
/// from memory, fill in the blank, the hidden page, linking, listen and
/// repeat, and chunking. The seventh, «سمّع بصوتك», needs an on-device
/// speech model this build does not have – so every screen asks
/// `hifzMethodsProvider` **before** it offers a method, and says plainly
/// that it is not ready yet instead of showing a button that does nothing.
///
/// **Nothing religious is generated.** Every letter drawn in the Quran
/// face came out of the engines, which read the app's own verified
/// Uthmani text. What he types is drawn as his own writing, labelled
/// «مكتوب منك على الكيبورد», and is never styled as Quran.
library;

export 'hifz_memorisation.dart';
export 'presentation/plan/hifz_drill_screen.dart';
export 'presentation/plan/hifz_find_screen.dart';
export 'presentation/plan/hifz_goals_screen.dart';
export 'presentation/plan/hifz_map_screen.dart';
export 'presentation/plan/hifz_plan_nav.dart';
export 'presentation/plan/hifz_plan_screen.dart';
export 'presentation/plan/hifz_plan_texts.dart';
export 'presentation/plan/hifz_plan_widgets.dart';
