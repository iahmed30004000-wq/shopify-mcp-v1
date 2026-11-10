import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/repositories/repositories.dart';
import '../../lists/data/list_providers.dart';
import '../../orbit/data/orbit_providers.dart';
import '../domain/constraints.dart';
import '../domain/no_repeat.dart';
import '../domain/pantry.dart';
import '../domain/pantry_match.dart';
import '../domain/recipe.dart';
import '../domain/sufra_settings.dart';
import 'sufra_service.dart';

/// «السفرة»'s wall clock (follows the orbit's, so a test freezes them all
/// at once).
final sufraClockProvider = Provider<DateTime Function()>((ref) => ref.watch(orbitClockProvider));

/// Today as a calendar day (follows the orbit's, which rolls over at local
/// midnight). A test overrides this one provider to pin the day.
final sufraTodayProvider = Provider<DateTime>((ref) => ref.watch(orbitTodayProvider));

/// Every read and write of «السفرة».
final sufraServiceProvider = Provider<SufraService>(
  (ref) => SufraService(
    ref.watch(repositoriesProvider),
    clock: ref.watch(sufraClockProvider),
    lists: ref.watch(listServiceProvider),
  ),
);

/// Her settings (the no-repeat window, the expiry warning, how many
/// usually eat, and the owner's diet switch).
final sufraSettingsProvider = StreamProvider<SufraSettings>(
  (ref) => ref.watch(sufraServiceProvider).watchSettings(),
);

// ------------------------------------------------------------- the rows ----

/// What is in the house, as rows (a write needs the row).
final pantryRowsProvider = StreamProvider<List<PantryItemRow>>(
  (ref) => ref.watch(sufraServiceProvider).watchPantryRows(),
);

final recipeRowsProvider = StreamProvider<List<RecipeRow>>(
  (ref) => ref.watch(sufraServiceProvider).watchRecipeRows(),
);

final kitchenRuleRowsProvider = StreamProvider<List<KitchenRuleRow>>(
  (ref) => ref.watch(sufraServiceProvider).watchRuleRows(),
);

/// The cooked log as rows – deleting one entry needs its row.
final cookedRowsProvider = StreamProvider<List<CookedMealRow>>(
  (ref) => ref.watch(repositoriesProvider).cookedMeals.watchAll(),
);

// ----------------------------------------------------------- the models ----

/// Her recipes with their ingredients, in her own order.
final recipesProvider = StreamProvider<List<Recipe>>((ref) => ref.watch(sufraServiceProvider).watchRecipes());

/// One dish with its ingredients (null once it is gone).
final recipeProvider = StreamProvider.family<Recipe?, String>(
  (ref, id) => ref.watch(sufraServiceProvider).watchRecipe(id),
);

/// Her cooked log, newest day first – the real history «بدون تكرار» reads.
final cookedLogProvider = StreamProvider<List<CookedMeal>>(
  (ref) => ref.watch(sufraServiceProvider).watchCookedLog(),
);

/// Her standing constraints.
final kitchenRulesProvider = Provider<List<KitchenRule>>(
  (ref) => SufraRows.rules(ref.watch(kitchenRuleRowsProvider).value ?? const <KitchenRuleRow>[]),
);

/// What is in the house, judged on today.
final pantryBoardProvider = Provider<PantryBoard>((ref) {
  final settings = ref.watch(sufraSettingsProvider).value ?? const SufraSettings();
  return PantryBoard.of(
    SufraRows.pantryAll(ref.watch(pantryRowsProvider).value ?? const <PantryItemRow>[]),
    today: ref.watch(sufraTodayProvider),
    warningDays: settings.expiryWarningDays,
  );
});

/// What is low, finished or near its expiry – the running view she opens
/// first, worst first.
final pantryAttentionProvider = Provider<List<PantryStock>>((ref) => ref.watch(pantryBoardProvider).attention);

// ------------------------------------------------------- her constraints ----

/// Part 4's meal plan, as «السفرة» is allowed to see it.
///
/// It is [DietLink.off] on a fresh install and stays off: the Body planet
/// overrides this provider with his planned and avoided **words** only
/// after he turns [SufraSettings.dietMode] on, and `SufraBoard.build`
/// drops it on the floor while that switch is off. Two locks, so a mistake
/// on one side cannot leak his plan into her kitchen.
final sufraDietLinkProvider = Provider<DietLink>((ref) => DietLink.off);

/// Tonight's extra choices: how many are eating, how long she has, a tag
/// she wants, and whether she asked to see the repeats too.
///
/// Not stored, because it is about tonight. The screens set it with
/// `ref.read(kitchenConstraintsProvider.notifier).set(...)`.
final kitchenConstraintsProvider = NotifierProvider<KitchenConstraintsNotifier, KitchenConstraints>(
  KitchenConstraintsNotifier.new,
);

class KitchenConstraintsNotifier extends Notifier<KitchenConstraints> {
  @override
  KitchenConstraints build() => KitchenConstraints.none;

  /// Replaces tonight's choices wholesale.
  void set(KitchenConstraints constraints) => state = constraints;

  /// How many are eating (null = she did not say, and nothing is scaled).
  void people(int? count) =>
      state = count == null ? state.copyWith(clearPeople: true) : state.copyWith(people: count);

  /// How long she has, in minutes (null = no limit).
  void minutes(int? limit) =>
      state = limit == null ? state.copyWith(clearMinutes: true) : state.copyWith(maxMinutes: limit);

  /// Tags a dish must carry tonight.
  void tags(List<String> tags) => state = state.copyWith(mustTags: tags);

  /// Her override: show the dishes the no-repeat window holds back too.
  void showRepeats(bool show) => state = state.copyWith(ignoreNoRepeat: show);

  /// Back to nothing asked for.
  void clear() => state = KitchenConstraints.none;
}

// ----------------------------------------------------------- the board ----

/// Everything «السفرة» shows: the pantry judged on today, every dish
/// ranked, the cooked log and her constraints. Rebuilds whenever any of
/// them changes.
final sufraBoardProvider = Provider<SufraBoard>((ref) {
  return SufraBoard.build(
    settings: ref.watch(sufraSettingsProvider).value ?? const SufraSettings(),
    pantryItems: SufraRows.pantryAll(ref.watch(pantryRowsProvider).value ?? const <PantryItemRow>[]),
    recipes: ref.watch(recipesProvider).value ?? const <Recipe>[],
    rules: ref.watch(kitchenRulesProvider),
    log: ref.watch(cookedLogProvider).value ?? const <CookedMeal>[],
    today: ref.watch(sufraTodayProvider),
    extra: ref.watch(kitchenConstraintsProvider),
    diet: ref.watch(sufraDietLinkProvider),
  );
});

/// Every dish ranked, best first.
final recipeMatchesProvider = Provider<List<RecipeMatch>>((ref) => ref.watch(sufraBoardProvider).matches);

/// The dishes she can cook right now.
final cookNowProvider = Provider<List<RecipeMatch>>((ref) => ref.watch(sufraBoardProvider).cookNow);

/// The near misses – what is missing is known and short.
final nearlyProvider = Provider<List<RecipeMatch>>((ref) => ref.watch(sufraBoardProvider).nearly);

/// One suggestion for tonight, or null (and then the screen shows the warm
/// empty state – never an invented dish).
final tonightProvider = Provider<RecipeMatch?>((ref) => ref.watch(sufraBoardProvider).tonight);

/// The dishes a hard rule blocks today, each with the word and the person
/// behind it. Never offered as cookable – only shown, so nothing vanishes
/// without a reason.
final blockedMatchesProvider = Provider<List<RecipeMatch>>((ref) => ref.watch(sufraBoardProvider).blocked);

/// One dish's match, by recipe id (null while it is not in the board).
final recipeMatchProvider = Provider.family<RecipeMatch?, String>(
  (ref, id) => ref.watch(sufraBoardProvider).matchOf(id),
);

/// Her no-repeat window in days (0 = she turned the rule off).
final noRepeatWindowProvider = Provider<int>(
  (ref) => ref.watch(sufraSettingsProvider).value?.noRepeatDays ?? NoRepeat.defaultWindowDays,
);
