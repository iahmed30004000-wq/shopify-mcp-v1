/// «السفرة» – the kitchen planet (Part 5), for the owner's wife.
///
/// Import `package:madar/features/sufra/sufra.dart`.
///
/// Her words, through him: «بدو تكون محطوط عندها شو في بالبيت / وتعمل طبخات
/// من المكونات الي بالبيت / يوبدلها طبخة بدون تكرار بتلعيارات وطريقة
/// التحضير / ويحطلها محددات اذا في طلب خاص».
///
/// ## What this package is, and is not
///
/// * It **holds nothing of ours**: no recipe library is bundled, no
///   ingredient dictionary, no cup-to-gram table of the world. A fresh
///   install is empty and every word in it is hers.
/// * It **shows nothing from Health or Money** – no table in here points at
///   `foods`, `conditions`, `food_logs` or any money table. Not for
///   privacy: because a kitchen screen should stay a kitchen screen. The
///   one tie to Part 4's meal plan is [DietLink], which stays
///   [DietLink.off] unless the **owner** turns `SufraSettings.dietMode` on.
/// * It **tracks and suggests food**. It never gives a diagnosis, a
///   treatment or a dose; a constraint is her own word plus who it is for.
/// * It is **offline**. An AI recipe arrives only through Part 3's file
///   round trip, on an explicit tap, and goes through the same validator
///   and the same `HealthGuard` as everything else.
/// * It **never guesses a unit**. Kilo ↔ gram and litre ↔ millilitre are
///   arithmetic; a cup of rice in grams is not, and the matcher says «ما
///   بعرف» rather than putting a dish she cannot cook on her table.
///
/// ## The data (schema v6)
///
/// | table | what it is |
/// |---|---|
/// | `pantry_items` | what is in the house: quantity, unit, place, expiry, low mark, staple |
/// | `recipes` | her dishes: steps, servings, minutes, tags, photos, source |
/// | `recipe_ingredients` | one ingredient line: name, quantity, unit, optional |
/// | `cooked_meals` | the cooked log «بدون تكرار» reads – real history |
/// | `kitchen_rules` | her standing constraints: allergy, avoid, prefer, request |
///
/// The **shopping list is Part 3b's engine**, unchanged: a standing list of
/// the house on `ListHost(PantryLists.houseTable, PantryLists.houseId)` and
/// a per-dish «ناقص لهذي الطبخة» on `ListHost('recipes', recipeId)`. The
/// pantry itself is its own table and not a list, because a pantry item is
/// stock (a quantity that goes down, a unit the matcher computes in, a
/// place, an expiry, a threshold) and a list line is a tick.
///
/// ## Where a screen starts
///
/// Reads (all providers in `data/sufra_providers.dart`):
/// * `sufraBoardProvider` – **the one object a screen needs**: the pantry
///   judged on today, every dish ranked, the cooked log, her rules
///   ([SufraBoard]);
/// * `pantryBoardProvider` / `pantryAttentionProvider` – what is in the
///   house, and «شو قلّ أو خلص» worst first;
/// * `recipesProvider` / `recipeProvider(id)` – her dishes with their
///   ingredients;
/// * `recipeMatchesProvider`, `cookNowProvider`, `nearlyProvider`,
///   `tonightProvider` – the ranking, the two lists she browses, and the
///   one suggestion for tonight (null ⇒ show the warm empty state);
/// * `cookedLogProvider`, `kitchenRulesProvider`, `sufraSettingsProvider`,
///   `noRepeatWindowProvider`;
/// * `kitchenConstraintsProvider` – a `StateProvider` the screens set for
///   tonight (how many are eating, how long she has, a tag, "show the
///   repeats too"). Not stored: it is about tonight.
///
/// Writes (`sufraServiceProvider`, every one returning a [SufraUndo] the
/// UI wraps in an undo toast):
/// * pantry – `addPantryItem`, `quickAdd`, `addPantryItems`,
///   `updatePantryItem`, `setLow`, `setStaple`, `setQuantity`, `useUp`,
///   `setPantryArchived`, `deletePantryItem`, `reorderPantry`;
/// * recipes – `addRecipe` (with its ingredients in one go),
///   `updateRecipe`, `setRecipeFavorite`, `setRecipeArchived`, `setPhotos`,
///   `duplicateRecipe`, `deleteRecipe`, `addIngredient`,
///   `updateIngredient`, `deleteIngredient`, `reorderIngredients`,
///   `reorderRecipes`;
/// * the log – `cook`, `cookFreeText`, `cookFromMatch` (records it **and**
///   deducts only the quantities it could compare with certainty),
///   `deleteCooked`;
/// * constraints – `addRule`, `updateRule`, `setRuleActive`, `deleteRule`,
///   `reorderRules`;
/// * settings – `setSettings`;
/// * shopping – `houseList`, `recipeList`, `addLines`, `missingToList`,
///   `lowToHouseList`. All four write through `ListService`; «السفرة» owns
///   no list rows of its own.
///
/// ## Reading a match on screen
///
/// A [RecipeMatch] is everything a card needs: `verdict`
/// ([MatchVerdict.cookNow] / `nearly` / `unsure` / `far`), `cookable`,
/// `coverage`, `checks` (one [IngredientCheck] per ingredient with its
/// [IngredientVerdict], `shortBy` + `shortUnit` when the amount is known
/// and **null when it is not**), `shopping` (what to buy), `unsureChecks`
/// (what Madar refused to judge, with the pantry item it was compared
/// against), `hold` ([RepeatHold] – why «بدون تكرار» holds it and from
/// which day it is free), `hits` ([ConstraintHit] – which word of hers and
/// whose), `usesExpiring` (what it would use up in time) and `scaledFor`.
///
/// `SufraTexts.of(context)` (in `presentation/`) already writes every one
/// of those sentences in her digits, with her words bidi-isolated – use it
/// rather than composing a new one, so the engine's refusals reach her in
/// the words they were meant in.
///
/// Three rules for the screens:
/// 1. never present an `unsure` dish as cookable – say what could not be
///    computed, and offer the alias that fixes it;
/// 2. always show the reason a dish is held back, with the override;
/// 3. a missing amount of `null` is shown **without a number**.
library;

export 'data/sufra_providers.dart';
export 'data/sufra_service.dart';
export 'domain/constraints.dart';
export 'domain/kitchen_units.dart';
export 'domain/no_repeat.dart';
export 'domain/pantry.dart';
export 'domain/pantry_match.dart';
export 'domain/recipe.dart';
export 'domain/shopping_lines.dart';
export 'domain/sufra_settings.dart';
export 'presentation/sufra_texts.dart';
