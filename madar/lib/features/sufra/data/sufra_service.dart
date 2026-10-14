import 'dart:async';

import 'package:drift/drift.dart';

import '../../../core/db/database.dart';
import '../../../core/db/repositories/repositories.dart';
import '../../../core/domain/enums.dart';
import '../../lists/data/list_service.dart';
import '../../lists/domain/record_list.dart';
import '../domain/constraints.dart';
import '../domain/kitchen_units.dart';
import '../domain/no_repeat.dart';
import '../domain/pantry.dart';
import '../domain/pantry_match.dart';
import '../domain/recipe.dart';
import '../domain/shopping_lines.dart';
import '../domain/sufra_settings.dart';

/// Reverses one change (the UI wraps it in an undo toast), exactly like
/// `NutritionService`, `ListService` and `BodyService`.
typedef SufraUndo = Future<void> Function();

// --------------------------------------------------------------- drafts ----

/// A new or edited pantry item.
class PantryDraft {
  const PantryDraft({
    required this.name,
    this.aliases = const [],
    this.quantity,
    this.unit,
    this.place,
    this.lowAt,
    this.low = false,
    this.expires,
    this.staple = false,
    this.note,
    this.archived = false,
  });

  /// Straight from one line of a shopping list she has just ticked.
  factory PantryDraft.ofLine(ListLine line, {String? place}) =>
      PantryDraft(name: line.title, quantity: line.quantity, unit: line.unit, place: place);

  final String name;
  final List<String> aliases;
  final double? quantity;
  final String? unit;
  final String? place;
  final double? lowAt;
  final bool low;
  final DateTime? expires;
  final bool staple;
  final String? note;
  final bool archived;
}

/// A new or edited recipe (its ingredients are edited on their own).
class RecipeDraft {
  const RecipeDraft({
    required this.name,
    this.steps = const [],
    this.servings,
    this.minutes,
    this.tags = const [],
    this.photos = const [],
    this.notes,
    this.source = RecipeSource.mine,
    this.sourceName,
    this.favorite = false,
    this.archived = false,
  });

  final String name;
  final List<String> steps;
  final int? servings;
  final int? minutes;
  final List<String> tags;
  final List<String> photos;
  final String? notes;
  final RecipeSource source;
  final String? sourceName;
  final bool favorite;
  final bool archived;
}

/// A new or edited ingredient line.
class IngredientDraft {
  const IngredientDraft({required this.name, this.quantity, this.unit, this.optional = false, this.note});

  final String name;
  final double? quantity;
  final String? unit;
  final bool optional;
  final String? note;
}

/// A new or edited standing constraint.
class KitchenRuleDraft {
  const KitchenRuleDraft({
    required this.kind,
    required this.term,
    this.who,
    this.note,
    this.active = true,
  });

  final KitchenRuleKind kind;
  final String term;
  final String? who;
  final String? note;
  final bool active;
}

// ------------------------------------------------------------- mapping ----

/// Row → pure model.
abstract final class SufraRows {
  static PantryItem pantry(PantryItemRow r) => PantryItem(
    id: r.id,
    name: r.name,
    aliases: r.aliases,
    quantity: r.quantity,
    unit: r.unit,
    place: r.place,
    lowAt: r.lowAt,
    low: r.low,
    expires: r.expires,
    staple: r.staple,
    note: r.note,
    archived: r.archived,
  );

  static List<PantryItem> pantryAll(Iterable<PantryItemRow> rows) => [for (final r in rows) pantry(r)];

  static RecipeIngredient ingredient(RecipeIngredientRow r) => RecipeIngredient(
    id: r.id,
    recipeId: r.recipeId,
    name: r.name,
    quantity: r.quantity,
    unit: r.unit,
    optional: r.optional,
    note: r.note,
    sortOrder: r.sortOrder,
  );

  /// A recipe row plus the ingredient rows that belong to it.
  static Recipe recipe(RecipeRow r, Iterable<RecipeIngredientRow> ingredients) => Recipe(
    id: r.id,
    name: r.name,
    ingredients: [
      for (final i in ingredients)
        if (i.recipeId == r.id) ingredient(i),
    ],
    steps: r.steps,
    servings: r.servings,
    minutes: r.minutes,
    tags: r.tags,
    photos: r.photos,
    notes: r.notes,
    source: r.source,
    sourceName: r.sourceName,
    favorite: r.favorite,
    archived: r.archived,
  );

  /// Every recipe with its own ingredients, in her order (one pass).
  static List<Recipe> recipes(Iterable<RecipeRow> rows, Iterable<RecipeIngredientRow> ingredients) {
    final byRecipe = <String, List<RecipeIngredientRow>>{};
    for (final i in ingredients) {
      (byRecipe[i.recipeId] ??= []).add(i);
    }
    return [for (final r in rows) recipe(r, byRecipe[r.id] ?? const [])];
  }

  static CookedMeal cooked(CookedMealRow r) => CookedMeal(
    id: r.id,
    recipeId: r.recipeId,
    name: r.name,
    day: r.day,
    servings: r.servings,
    overrode: r.overrode,
    note: r.note,
  );

  static List<CookedMeal> cookedAll(Iterable<CookedMealRow> rows) => [for (final r in rows) cooked(r)];

  static KitchenRule rule(KitchenRuleRow r) => KitchenRule(
    id: r.id,
    kind: r.kind,
    term: r.term,
    who: r.who,
    note: r.note,
    active: r.active,
    sortOrder: r.sortOrder,
  );

  static List<KitchenRule> rules(Iterable<KitchenRuleRow> rows) => [for (final r in rows) rule(r)];
}

/// Everything «السفرة» shows at once: the pantry judged on today, her
/// recipes ranked against it, the cooked log and her constraints.
class SufraBoard {
  /// Builds the board from models already read – pure, so the providers
  /// compose it from their streams without a second database round trip
  /// and a test builds one by hand.
  ///
  /// [extra] is layered on top of her stored settings: tonight's choices
  /// (how many are eating, how long she has, a tag she wants, "show the
  /// repeats too"). [diet] is Part 4's plan and is **dropped on the floor**
  /// unless [SufraSettings.dietMode] is on – the second of the two locks
  /// that keep his health data out of her kitchen.
  factory SufraBoard.build({
    required SufraSettings settings,
    required List<PantryItem> pantryItems,
    required List<Recipe> recipes,
    required List<KitchenRule> rules,
    required List<CookedMeal> log,
    required DateTime today,
    KitchenConstraints? extra,
    DietLink diet = DietLink.off,
  }) {
    final day = DateTime(today.year, today.month, today.day);
    final pantry = PantryBoard.of(pantryItems, today: day, warningDays: settings.expiryWarningDays);
    final base = extra ?? KitchenConstraints.none;
    final constraints = base.copyWith(
      rules: rules,
      people: base.people ?? settings.defaultPeople,
      windowDays: base.windowDays ?? settings.noRepeatDays,
      diet: settings.dietMode ? diet : DietLink.off,
    );
    final sorted = [...log]..sort((a, b) => b.day.compareTo(a.day));
    return SufraBoard(
      settings: settings,
      pantry: pantry,
      recipes: recipes,
      cooked: sorted,
      rules: rules,
      matches: PantryMatcher.rank(
        recipes,
        pantry: pantry,
        constraints: constraints,
        cookedLog: sorted,
        nearlyLimit: settings.nearlyLimit,
        today: day,
      ),
    );
  }

  SufraBoard({
    required this.settings,
    required this.pantry,
    required this.recipes,
    required this.cooked,
    required this.rules,
    required this.matches,
  });

  final SufraSettings settings;

  /// What is in the house, judged on today.
  final PantryBoard pantry;

  /// Her recipes with their ingredients, in her order.
  final List<Recipe> recipes;

  /// Her cooked log, newest day first.
  final List<CookedMeal> cooked;

  /// Her standing constraints.
  final List<KitchenRule> rules;

  /// Every dish ranked, best first (see [PantryMatcher.rank]).
  final List<RecipeMatch> matches;

  /// The dishes she can cook right now.
  List<RecipeMatch> get cookNow => PantryMatcher.cookNow(matches);

  /// The near misses.
  List<RecipeMatch> get nearly => PantryMatcher.nearly(matches);

  /// One suggestion for tonight, or null (and then the screen shows the
  /// warm empty state – never an invented dish).
  RecipeMatch? get tonight => PantryMatcher.tonight(matches);

  /// What is low, finished or expired.
  List<PantryStock> get attention => pantry.attention;

  /// A fresh install: nothing in the house and no recipes.
  bool get isEmpty => pantry.isEmpty && recipes.isEmpty;

  RecipeMatch? matchOf(String recipeId) {
    for (final m in matches) {
      if (m.recipe.id == recipeId) return m;
    }
    return null;
  }
}

/// Every read and write of «السفرة»: the pantry, her recipes, the cooked
/// log, her constraints, and the bridge into Part 3b's shopping lists.
///
/// **Undo.** Every write returns a [SufraUndo] that restores the exact
/// prior state – deleting a recipe brings its ingredients back in order,
/// cooking a dish puts the deducted quantities back.
///
/// **What it never touches.** Nothing in here reads or writes `foods`,
/// `food_logs`, `conditions`, `transactions` or any other table of his
/// Health or Money: a kitchen screen stays a kitchen screen. The one tie
/// to Part 4 is [DietLink], which the caller fills **after** the owner
/// turns [SufraSettings.dietMode] on.
///
/// **No network and no bundled data.** A fresh install is empty; an AI
/// recipe arrives only through Part 3's file round trip, on an explicit
/// tap.
class SufraService {
  SufraService(this.repos, {DateTime Function()? clock, ListService? lists})
    : clock = clock ?? DateTime.now,
      lists = lists ?? ListService(repos, clock: clock);

  final Repositories repos;
  final DateTime Function() clock;

  /// Part 3b's shared list engine – «السفرة» writes no list of its own.
  final ListService lists;

  MadarDatabase get _db => repos.db;

  EntityRepository<$PantryItemsTable, PantryItemRow> get _pantry => repos.pantryItems;
  EntityRepository<$RecipesTable, RecipeRow> get _recipes => repos.recipes;
  EntityRepository<$RecipeIngredientsTable, RecipeIngredientRow> get _ingredients => repos.recipeIngredients;
  EntityRepository<$CookedMealsTable, CookedMealRow> get _cooked => repos.cookedMeals;
  EntityRepository<$KitchenRulesTable, KitchenRuleRow> get _rules => repos.kitchenRules;

  /// Today as a calendar day.
  DateTime get today {
    final now = clock();
    return DateTime(now.year, now.month, now.day);
  }

  // ------------------------------------------------------------ settings ----

  static const _settingsKey = KvKey<SufraSettings>(
    SufraSettings.storageKey,
    decode: SufraSettings.fromJson,
    encode: _encodeSettings,
  );

  static Object? _encodeSettings(SufraSettings s) => s.toJson();

  Future<SufraSettings> settings() async => await repos.keyValues.get(_settingsKey) ?? const SufraSettings();

  Stream<SufraSettings> watchSettings() =>
      repos.keyValues.watch(_settingsKey).map((s) => s ?? const SufraSettings()).distinct();

  Future<SufraUndo> setSettings(SufraSettings settings) async {
    final had = await repos.keyValues.contains(SufraSettings.storageKey);
    final before = await repos.keyValues.getJson(SufraSettings.storageKey);
    await repos.keyValues.set(_settingsKey, settings);
    return () async {
      if (had) {
        await repos.keyValues.setJson(SufraSettings.storageKey, before);
      } else {
        await repos.keyValues.remove(SufraSettings.storageKey);
      }
    };
  }

  // --------------------------------------------------------------- reads ----

  Stream<List<PantryItemRow>> watchPantryRows() => _pantry.watchAll();

  Future<List<PantryItemRow>> pantryRows() => _pantry.getAll();

  Future<PantryItemRow?> pantryItem(String id) => _pantry.byId(id);

  Stream<List<RecipeRow>> watchRecipeRows() => _recipes.watchAll();

  Future<RecipeRow?> recipeRow(String id) => _recipes.byId(id);

  Future<RecipeIngredientRow?> ingredientRow(String id) => _ingredients.byId(id);

  Future<List<RecipeIngredientRow>> ingredientRows(String recipeId) =>
      _ingredients.getAll(where: (t) => t.recipeId.equals(recipeId));

  Stream<List<KitchenRuleRow>> watchRuleRows() => _rules.watchAll();

  Future<List<CookedMealRow>> cookedRows() => _cooked.getAll();

  /// The cooked log, newest day first.
  Future<List<CookedMeal>> cookedLog() async {
    final rows = await cookedRows();
    final log = SufraRows.cookedAll(rows)..sort((a, b) => b.day.compareTo(a.day));
    return log;
  }

  Stream<List<CookedMeal>> watchCookedLog() => _cooked.watchAll().map((rows) {
    final log = SufraRows.cookedAll(rows)..sort((a, b) => b.day.compareTo(a.day));
    return log;
  });

  /// Every dish with its own ingredients, in her order.
  Stream<List<Recipe>> watchRecipes() => _combine2(
    watchRecipeRows(),
    _ingredients.watchAll(),
    SufraRows.recipes,
  );

  /// One snapshot of every dish with its ingredients.
  Future<List<Recipe>> recipes() async => SufraRows.recipes(await _recipes.getAll(), await _ingredients.getAll());

  /// One dish with its ingredients (null once it is gone).
  Future<Recipe?> recipe(String id) async {
    final row = await recipeRow(id);
    if (row == null) return null;
    return SufraRows.recipe(row, await ingredientRows(id));
  }

  Stream<Recipe?> watchRecipe(String id) => _combine2(
    _recipes.watchById(id),
    _ingredients.watchAll(where: (t) => t.recipeId.equals(id)),
    (RecipeRow? row, List<RecipeIngredientRow> items) => row == null ? null : SufraRows.recipe(row, items),
  );

  /// The pantry judged on today, with her expiry warning window.
  Future<PantryBoard> pantryBoard() async {
    final s = await settings();
    return PantryBoard.of(
      SufraRows.pantryAll(await pantryRows()),
      today: today,
      warningDays: s.expiryWarningDays,
    );
  }

  Stream<PantryBoard> watchPantryBoard() => _combine2(
    watchSettings(),
    watchPantryRows(),
    (SufraSettings s, List<PantryItemRow> rows) =>
        PantryBoard.of(SufraRows.pantryAll(rows), today: today, warningDays: s.expiryWarningDays),
  );

  /// Everything at once: the pantry, the ranked dishes, the log and her
  /// constraints.
  ///
  /// [extra] is layered on top of her stored constraints – the "tonight"
  /// choices (how many are eating, how long she has, a tag she wants).
  /// [diet] is Part 4's plan and **must** be [DietLink.off] unless the
  /// owner turned [SufraSettings.dietMode] on; the provider does that
  /// check so the engine never reaches into his data.
  Future<SufraBoard> board({KitchenConstraints? extra, DietLink diet = DietLink.off}) async {
    return SufraBoard.build(
      settings: await settings(),
      pantryItems: SufraRows.pantryAll(await pantryRows()),
      recipes: await recipes(),
      rules: SufraRows.rules(await _rules.getAll()),
      log: await cookedLog(),
      today: today,
      extra: extra,
      diet: diet,
    );
  }

  // -------------------------------------------------------------- pantry ----

  PantryItemsCompanion _pantryCompanion(PantryDraft d) => PantryItemsCompanion(
    name: Value(d.name.trim()),
    aliases: Value(_words(d.aliases)),
    quantity: Value(_amount(d.quantity)),
    unit: Value(_clean(d.unit)),
    place: Value(_clean(d.place)),
    lowAt: Value(_amount(d.lowAt)),
    low: Value(d.low),
    expires: Value(d.expires),
    staple: Value(d.staple),
    note: Value(_clean(d.note)),
    archived: Value(d.archived),
  );

  /// Puts something in the house. Returns the row and the undo.
  Future<(PantryItemRow, SufraUndo)> addPantryItem(PantryDraft d) async {
    final row = await _pantry.insert(_pantryCompanion(d));
    return (row, () async => _pantry.delete(row.id).then((_) {}));
  }

  /// The fast add: a word, and nothing else («حمص»).
  Future<(PantryItemRow, SufraUndo)> quickAdd(String name, {double? quantity, String? unit, String? place}) =>
      addPantryItem(PantryDraft(name: name, quantity: quantity, unit: unit, place: place));

  /// Several at once (one pasted line each); blank lines are skipped and
  /// one undo takes all of them back.
  Future<(List<PantryItemRow>, SufraUndo)> addPantryItems(Iterable<String> names, {String? place}) async {
    final rows = <PantryItemRow>[];
    for (final name in names) {
      if (name.trim().isEmpty) continue;
      rows.add(await _pantry.insert(_pantryCompanion(PantryDraft(name: name, place: place))));
    }
    return (
      rows,
      () async {
        for (final r in rows) {
          await _pantry.delete(r.id);
        }
      },
    );
  }

  Future<SufraUndo> updatePantryItem(PantryItemRow row, PantryDraft d) async {
    await _pantry.update(_pantryCompanion(d).copyWith(id: Value(row.id)));
    return () => _pantry.update(row);
  }

  /// Marks it low (or not) by hand – which works even when she never typed
  /// a quantity.
  Future<SufraUndo> setLow(PantryItemRow row, bool low) async {
    await _pantry.setColumn(row.id, 'low', low);
    return () => _pantry.setColumn(row.id, 'low', row.low);
  }

  Future<SufraUndo> setStaple(PantryItemRow row, bool staple) async {
    await _pantry.setColumn(row.id, 'staple', staple);
    return () => _pantry.setColumn(row.id, 'staple', row.staple);
  }

  /// Sets how much is left. A negative amount is stored as zero («خلص»).
  Future<SufraUndo> setQuantity(PantryItemRow row, double? quantity, {String? unit}) async {
    await _pantry.setColumns(row.id, {
      'quantity': quantity == null ? null : (quantity < 0 ? 0.0 : quantity),
      if (unit != null) 'unit': _clean(unit),
    });
    return () => _pantry.setColumns(row.id, {'quantity': row.quantity, 'unit': row.unit});
  }

  /// Takes [amount] out of an item (she used some). Only ever arithmetic
  /// inside one unit: when [unit] is given and it is not comparable with
  /// the item's own, nothing is written and the undo is a no-op – Madar
  /// does not guess how much a cup of it weighs.
  Future<SufraUndo> useUp(PantryItemRow row, double amount, {String? unit}) async {
    final have = row.quantity;
    if (have == null || amount <= 0) return () async {};
    final taken = unit == null
        ? amount
        : KitchenUnits.convert(amount, KitchenUnits.normalize(unit), KitchenUnits.normalize(row.unit));
    if (taken == null) return () async {};
    final left = have - taken;
    await _pantry.setColumn(row.id, 'quantity', left < 0 ? 0.0 : left);
    return () => _pantry.setColumn(row.id, 'quantity', have);
  }

  Future<SufraUndo> setPantryArchived(PantryItemRow row, bool archived) async {
    await _pantry.setColumn(row.id, 'archived', archived);
    return () => _pantry.setColumn(row.id, 'archived', row.archived);
  }

  Future<SufraUndo> deletePantryItem(PantryItemRow row) async {
    final gone = await _pantry.delete(row.id);
    return () async {
      if (gone != null) await _pantry.restore(gone);
    };
  }

  Future<void> reorderPantry(List<String> ids) => _pantry.reorder(ids);

  // ------------------------------------------------------------- recipes ----

  RecipesCompanion _recipeCompanion(RecipeDraft d) => RecipesCompanion(
    name: Value(d.name.trim()),
    steps: Value(_words(d.steps)),
    servings: Value(_count(d.servings)),
    minutes: Value(_count(d.minutes)),
    tags: Value(_words(d.tags)),
    photos: Value(_words(d.photos)),
    notes: Value(_clean(d.notes)),
    source: Value(d.source),
    sourceName: Value(_clean(d.sourceName)),
    favorite: Value(d.favorite),
    archived: Value(d.archived),
  );

  RecipeIngredientsCompanion _ingredientCompanion(String recipeId, IngredientDraft d) => RecipeIngredientsCompanion(
    recipeId: Value(recipeId),
    name: Value(d.name.trim()),
    quantity: Value(_amount(d.quantity)),
    unit: Value(_clean(d.unit)),
    optional: Value(d.optional),
    note: Value(_clean(d.note)),
  );

  /// A new dish, with its ingredients in one go. One undo removes both.
  Future<(RecipeRow, SufraUndo)> addRecipe(RecipeDraft d, {List<IngredientDraft> ingredients = const []}) async {
    return _db.transaction(() async {
      final row = await _recipes.insert(_recipeCompanion(d));
      for (final i in ingredients) {
        if (i.name.trim().isEmpty) continue;
        await _ingredients.insert(_ingredientCompanion(row.id, i));
      }
      return (row, () => deleteRecipe(row).then((_) {}));
    });
  }

  Future<SufraUndo> updateRecipe(RecipeRow row, RecipeDraft d) async {
    await _recipes.update(_recipeCompanion(d).copyWith(id: Value(row.id)));
    return () => _recipes.update(row);
  }

  Future<SufraUndo> setRecipeFavorite(RecipeRow row, bool favorite) async {
    await _recipes.setColumn(row.id, 'favorite', favorite);
    return () => _recipes.setColumn(row.id, 'favorite', row.favorite);
  }

  Future<SufraUndo> setRecipeArchived(RecipeRow row, bool archived) async {
    await _recipes.setColumn(row.id, 'archived', archived);
    return () => _recipes.setColumn(row.id, 'archived', row.archived);
  }

  /// The photos she added, replaced wholesale (the screens own the files).
  Future<SufraUndo> setPhotos(RecipeRow row, List<String> photos) async {
    await _recipes.setColumn(row.id, 'photos', _words(photos));
    return () => _recipes.setColumn(row.id, 'photos', row.photos);
  }

  /// Deletes a dish with its ingredients **and its own missing-list**; the
  /// undo restores the ingredients exactly (the list is a separate undo the
  /// caller can chain, since the list engine owns it).
  Future<SufraUndo> deleteRecipe(RecipeRow row) async {
    final listUndo = await lists.deleteForHost(ListHost(PantryLists.recipesTable, row.id));
    return _db.transaction(() async {
      final ingredients = await _ingredients.deleteWhere((t) => t.recipeId.equals(row.id));
      final gone = await _recipes.delete(row.id);
      return () async {
        await _db.transaction(() async {
          if (gone != null) await _recipes.restore(gone);
          if (ingredients.isNotEmpty) await _ingredients.restoreAll(ingredients);
        });
        await listUndo();
      };
    });
  }

  /// Copies a dish with its ingredients – how she starts a variation.
  Future<(RecipeRow, SufraUndo)> duplicateRecipe(RecipeRow row, {String? name}) async {
    return _db.transaction(() async {
      final copy = await _recipes.insert(
        RecipesCompanion(
          name: Value((name ?? row.name).trim()),
          steps: Value(row.steps),
          servings: Value(row.servings),
          minutes: Value(row.minutes),
          tags: Value(row.tags),
          photos: Value(row.photos),
          notes: Value(row.notes),
          source: Value(row.source),
          sourceName: Value(row.sourceName),
        ),
      );
      for (final i in await ingredientRows(row.id)) {
        await _ingredients.insert(
          RecipeIngredientsCompanion(
            recipeId: Value(copy.id),
            name: Value(i.name),
            quantity: Value(i.quantity),
            unit: Value(i.unit),
            optional: Value(i.optional),
            note: Value(i.note),
          ),
        );
      }
      return (copy, () => deleteRecipe(copy).then((_) {}));
    });
  }

  Future<(RecipeIngredientRow, SufraUndo)> addIngredient(String recipeId, IngredientDraft d) async {
    final row = await _ingredients.insert(_ingredientCompanion(recipeId, d));
    return (row, () async => _ingredients.delete(row.id).then((_) {}));
  }

  Future<SufraUndo> updateIngredient(RecipeIngredientRow row, IngredientDraft d) async {
    await _ingredients.update(_ingredientCompanion(row.recipeId, d).copyWith(id: Value(row.id)));
    return () => _ingredients.update(row);
  }

  Future<SufraUndo> deleteIngredient(RecipeIngredientRow row) async {
    final gone = await _ingredients.delete(row.id);
    return () async {
      if (gone != null) await _ingredients.restore(gone);
    };
  }

  Future<void> reorderIngredients(List<String> ids) => _ingredients.reorder(ids);

  Future<void> reorderRecipes(List<String> ids) => _recipes.reorder(ids);

  // ---------------------------------------------------------- cooked log ----

  /// Records that she cooked a dish, which is what «بدون تكرار» reads.
  ///
  /// [overrode] records that she chose it although the window held it back,
  /// so the history says what she decided rather than hiding it.
  Future<(CookedMealRow, SufraUndo)> cook(
    RecipeRow recipe, {
    DateTime? day,
    int? servings,
    bool overrode = false,
    String? note,
  }) async {
    final row = await _cooked.insert(
      CookedMealsCompanion.insert(
        recipeId: Value(recipe.id),
        name: recipe.name,
        day: day ?? today,
        servings: Value(_count(servings ?? recipe.servings)),
        overrode: Value(overrode),
        note: Value(_clean(note)),
      ),
    );
    return (row, () async => _cooked.delete(row.id).then((_) {}));
  }

  /// Something she cooked without a recipe («بيض ومقدوس»).
  Future<(CookedMealRow, SufraUndo)> cookFreeText(String name, {DateTime? day, String? note}) async {
    final row = await _cooked.insert(
      CookedMealsCompanion.insert(
        name: name.trim(),
        day: day ?? today,
        note: Value(_clean(note)),
      ),
    );
    return (row, () async => _cooked.delete(row.id).then((_) {}));
  }

  /// Records the cooking **and** takes the ingredients out of the pantry –
  /// but only the ones Madar could compare with certainty. An ingredient
  /// whose unit it will not convert, or whose amount she never typed, is
  /// left exactly as it is: the kitchen would rather be out of date than
  /// wrong. The undo puts every quantity back and removes the log row.
  Future<(CookedMealRow, SufraUndo)> cookFromMatch(RecipeMatch match, {DateTime? day, String? note}) async {
    final recipe = await recipeRow(match.recipe.id);
    if (recipe == null) throw StateError('cookFromMatch: the recipe ${match.recipe.id} is gone');
    final undos = <SufraUndo>[];
    for (final check in match.checks) {
      final stock = check.stock;
      final comparison = check.comparison;
      if (stock == null || comparison == null || !comparison.isKnown) continue;
      final row = await pantryItem(stock.item.id);
      if (row == null) continue;
      undos.add(await useUp(row, check.ingredient.quantity ?? 0, unit: check.ingredient.unit));
    }
    final (logRow, logUndo) = await cook(
      recipe,
      day: day,
      servings: match.scaledFor ?? match.recipe.servings,
      overrode: match.heldBack,
      note: note,
    );
    return (
      logRow,
      () async {
        await logUndo();
        for (final undo in undos.reversed) {
          await undo();
        }
      },
    );
  }

  Future<SufraUndo> deleteCooked(CookedMealRow row) async {
    final gone = await _cooked.delete(row.id);
    return () async {
      if (gone != null) await _cooked.restore(gone);
    };
  }

  // --------------------------------------------------------- constraints ----

  KitchenRulesCompanion _ruleCompanion(KitchenRuleDraft d) => KitchenRulesCompanion(
    kind: Value(d.kind),
    term: Value(d.term.trim()),
    who: Value(_clean(d.who)),
    note: Value(_clean(d.note)),
    active: Value(d.active),
  );

  Future<(KitchenRuleRow, SufraUndo)> addRule(KitchenRuleDraft d) async {
    final row = await _rules.insert(_ruleCompanion(d));
    return (row, () async => _rules.delete(row.id).then((_) {}));
  }

  Future<SufraUndo> updateRule(KitchenRuleRow row, KitchenRuleDraft d) async {
    await _rules.update(_ruleCompanion(d).copyWith(id: Value(row.id)));
    return () => _rules.update(row);
  }

  Future<SufraUndo> setRuleActive(KitchenRuleRow row, bool active) async {
    await _rules.setColumn(row.id, 'active', active);
    return () => _rules.setColumn(row.id, 'active', row.active);
  }

  Future<SufraUndo> deleteRule(KitchenRuleRow row) async {
    final gone = await _rules.delete(row.id);
    return () async {
      if (gone != null) await _rules.restore(gone);
    };
  }

  Future<void> reorderRules(List<String> ids) => _rules.reorder(ids);

  // ------------------------------------------------------- shopping list ----

  /// The standing list of the house, creating it the first time with
  /// [name] (the screens own the word). One list, so «اللي ناقص» never
  /// splits in two.
  Future<RecordListRow> houseList({required String name}) async {
    const host = ListHost(PantryLists.houseTable, PantryLists.houseId);
    final existing = await lists.listsOf(host);
    if (existing.isNotEmpty) return existing.first;
    final (row, _) = await lists.addList(host, ListDraft(name: name));
    return row;
  }

  /// A dish's own «ناقص لهذي الطبخة» list, created on first use.
  Future<RecordListRow> recipeList(String recipeId, {required String name}) async {
    final host = ListHost(PantryLists.recipesTable, recipeId);
    final existing = await lists.listsOf(host);
    if (existing.isNotEmpty) return existing.first;
    final (row, _) = await lists.addList(host, ListDraft(name: name));
    return row;
  }

  /// Puts [lines] on a list, skipping anything already on it (folded), and
  /// returns how many were added with one undo for all of them.
  Future<(int, SufraUndo)> addLines(String listId, Iterable<ShoppingLine> lines) async {
    final existing = await lists.lines(listId);
    final fresh = ShoppingLines.without(lines, [for (final l in existing) l.title]);
    if (fresh.isEmpty) return (0, () async {});
    final undos = <ListUndo>[];
    for (final line in fresh) {
      final (_, undo) = await lists.addItem(
        listId,
        ListItemDraft(title: line.title, quantity: line.quantity, unit: line.unit, note: line.note),
      );
      undos.add(undo);
    }
    return (
      fresh.length,
      () async {
        for (final undo in undos.reversed) {
          await undo();
        }
      },
    );
  }

  /// What is missing for a near match → that dish's own list, so she ticks
  /// it in the shop. Part 3b's engine does the storing, the ticking and the
  /// undo; nothing here duplicates it.
  Future<(RecordListRow, int, SufraUndo)> missingToList(
    RecipeMatch match, {
    required String listName,
    bool includeUnsure = true,
  }) async {
    final list = await recipeList(match.recipe.id, name: listName);
    final (added, undo) = await addLines(list.id, ShoppingLines.ofMatch(match, includeUnsure: includeUnsure));
    return (list, added, undo);
  }

  /// What is low or finished in the house → the standing list.
  Future<(RecordListRow, int, SufraUndo)> lowToHouseList({required String listName}) async {
    final list = await houseList(name: listName);
    final (added, undo) = await addLines(list.id, ShoppingLines.ofPantry(await pantryBoard()));
    return (list, added, undo);
  }

  // ------------------------------------------------------------- helpers ----

  static String? _clean(String? s) {
    final t = s?.trim();
    return t == null || t.isEmpty ? null : t;
  }

  static List<String> _words(List<String> raw) => [
    for (final w in raw)
      if (w.trim().isNotEmpty) w.trim(),
  ];

  /// An amount is never negative and never zero-as-null: zero means «خلص»
  /// and is kept, a negative number is not an amount.
  static double? _amount(double? v) => v == null ? null : (v < 0 ? 0 : v);

  static int? _count(int? v) => v == null || v <= 0 ? null : v;
}

/// The latest value of both streams, combined on every change of either
/// (and only once both have arrived) – the same helper the list engine
/// uses, and for the same reason: a drift query stream never completes, so
/// `asyncExpand` would wait forever.
Stream<R> _combine2<A, B, R>(Stream<A> a, Stream<B> b, R Function(A a, B b) combine) {
  late StreamController<R> controller;
  StreamSubscription<A>? subA;
  StreamSubscription<B>? subB;
  var hasA = false, hasB = false;
  late A lastA;
  late B lastB;
  void emit() {
    if (hasA && hasB) controller.add(combine(lastA, lastB));
  }

  controller = StreamController<R>(
    onListen: () {
      subA = a.listen((v) {
        lastA = v;
        hasA = true;
        emit();
      }, onError: controller.addError);
      subB = b.listen((v) {
        lastB = v;
        hasB = true;
        emit();
      }, onError: controller.addError);
    },
    onCancel: () async {
      await subA?.cancel();
      await subB?.cancel();
      subA = null;
      subB = null;
    },
  );
  return controller.stream;
}
