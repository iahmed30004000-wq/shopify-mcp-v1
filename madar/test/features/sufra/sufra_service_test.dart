// Every write of «السفرة» against a real in-memory database: the undo of
// each one, a fresh install that is empty, the shopping list going through
// Part 3b's engine, and the board that ties it all together.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/lists/lists.dart';
import 'package:madar/features/sufra/sufra.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late MadarDatabase db;
  late Repositories repos;
  late SufraService service;
  late ListService lists;
  final now = DateTime(2026, 10, 14, 17, 30);

  setUp(() {
    db = MadarDatabase(NativeDatabase.memory());
    repos = Repositories(db);
    lists = ListService(repos, clock: () => now);
    service = SufraService(repos, clock: () => now, lists: lists);
  });

  tearDown(() => db.close());

  group('a fresh install', () {
    test('is completely empty: no pantry, no recipes, no log, no rules, no list', () async {
      expect(await repos.pantryItems.count(), 0);
      expect(await repos.recipes.count(), 0);
      expect(await repos.recipeIngredients.count(), 0);
      expect(await repos.cookedMeals.count(), 0);
      expect(await repos.kitchenRules.count(), 0);
      expect(await repos.recordLists.count(), 0);
      final board = await service.board();
      expect(board.isEmpty, isTrue);
      expect(board.matches, isEmpty);
      expect(board.tonight, isNull, reason: 'the warm empty state, never an invented dish');
      expect(board.settings, const SufraSettings());
    });
  });

  group('the pantry', () {
    test('a fast add, and its undo', () async {
      final (row, undo) = await service.quickAdd('حمص');
      expect(row.name, 'حمص');
      expect(row.quantity, isNull);
      expect(row.low, isFalse);
      await undo();
      expect(await repos.pantryItems.count(), 0);
    });

    test('several at once, blank lines skipped, one undo for all', () async {
      final (rows, undo) = await service.addPantryItems(['رز', '  ', 'زيت', 'سكر'], place: 'خزانة المونة');
      expect(rows, hasLength(3));
      expect(rows.first.place, 'خزانة المونة');
      await undo();
      expect(await repos.pantryItems.count(), 0);
    });

    test('editing undoes back to the exact row', () async {
      final (row, _) = await service.addPantryItem(
        const PantryDraft(name: 'رز', quantity: 2, unit: 'كيلو', place: 'المونة'),
      );
      final undo = await service.updatePantryItem(
        row,
        const PantryDraft(name: 'رز بسمتي', quantity: 5, unit: 'كيلو', place: 'الفريزر', lowAt: 1, staple: true),
      );
      var after = (await service.pantryItem(row.id))!;
      expect(after.name, 'رز بسمتي');
      expect(after.quantity, 5);
      expect(after.staple, isTrue);
      await undo();
      after = (await service.pantryItem(row.id))!;
      expect(after.name, 'رز');
      expect(after.quantity, 2);
      expect(after.place, 'المونة');
      expect(after.staple, isFalse);
    });

    test('deleting undoes, bringing the whole row back', () async {
      final (row, _) = await service.addPantryItem(
        const PantryDraft(name: 'زيت', quantity: 1, unit: 'لتر', note: 'زيت زيتون'),
      );
      final undo = await service.deletePantryItem(row);
      expect(await repos.pantryItems.count(), 0);
      await undo();
      final back = (await service.pantryItem(row.id))!;
      expect(back.name, 'زيت');
      expect(back.note, 'زيت زيتون');
      expect(back.quantity, 1);
    });

    test('marking low works with no quantity at all, and undoes', () async {
      final (row, _) = await service.quickAdd('زيت');
      final undo = await service.setLow(row, true);
      expect((await service.pantryItem(row.id))!.low, isTrue);
      await undo();
      expect((await service.pantryItem(row.id))!.low, isFalse);
    });

    test('«خلص» is stored as zero, never as a negative', () async {
      final (row, _) = await service.addPantryItem(const PantryDraft(name: 'رز', quantity: 2, unit: 'كيلو'));
      await service.setQuantity(row, -5);
      expect((await service.pantryItem(row.id))!.quantity, 0);
    });

    test('using some takes it out of the stock, converting only where it is certain', () async {
      final (row, _) = await service.addPantryItem(const PantryDraft(name: 'رز', quantity: 2, unit: 'كيلو'));
      final undo = await service.useUp(row, 500, unit: 'غرام');
      expect((await service.pantryItem(row.id))!.quantity, 1.5);
      await undo();
      expect((await service.pantryItem(row.id))!.quantity, 2);
    });

    test('using a cup of something kept in kilos changes NOTHING', () async {
      final (row, _) = await service.addPantryItem(const PantryDraft(name: 'رز', quantity: 2, unit: 'كيلو'));
      await service.useUp(row, 1, unit: 'كوب');
      expect((await service.pantryItem(row.id))!.quantity, 2, reason: 'out of date beats wrong');
    });

    test('the board judges the pantry on today', () async {
      await service.addPantryItem(const PantryDraft(name: 'رز', quantity: 0.5, unit: 'كيلو', lowAt: 1));
      await service.addPantryItem(PantryDraft(name: 'لبن', expires: now.subtract(const Duration(days: 2))));
      final board = await service.pantryBoard();
      expect([for (final s in board.attention) s.item.name], ['لبن', 'رز']);
    });
  });

  group('her recipes', () {
    test('a dish with its ingredients in one go, and one undo for both', () async {
      final (row, undo) = await service.addRecipe(
        const RecipeDraft(name: 'مجدرة', steps: ['اغلي العدس', 'ضيفي الرز'], servings: 4, minutes: 40, tags: ['سهلة']),
        ingredients: const [
          IngredientDraft(name: 'رز', quantity: 2, unit: 'كيلو'),
          IngredientDraft(name: 'عدس', quantity: 500, unit: 'غرام'),
          IngredientDraft(name: '   '),
        ],
      );
      expect(row.source, RecipeSource.mine);
      expect(row.steps, ['اغلي العدس', 'ضيفي الرز']);
      expect(await repos.recipeIngredients.count(), 2, reason: 'the blank line is skipped');
      final recipe = (await service.recipe(row.id))!;
      expect(recipe.ingredients, hasLength(2));
      expect(recipe.required, hasLength(2));
      await undo();
      expect(await repos.recipes.count(), 0);
      expect(await repos.recipeIngredients.count(), 0);
    });

    test('deleting a dish takes its ingredients with it, and the undo restores them in order', () async {
      final (row, _) = await service.addRecipe(
        const RecipeDraft(name: 'ملوخية'),
        ingredients: const [
          IngredientDraft(name: 'ملوخية', quantity: 1, unit: 'كيس'),
          IngredientDraft(name: 'ثوم', quantity: 5, unit: 'حبة'),
          IngredientDraft(name: 'كزبرة', optional: true),
        ],
      );
      final undo = await service.deleteRecipe(row);
      expect(await repos.recipes.count(), 0);
      expect(await repos.recipeIngredients.count(), 0);
      await undo();
      final back = (await service.recipe(row.id))!;
      expect(back.name, 'ملوخية');
      expect([for (final i in back.ingredients) i.name], ['ملوخية', 'ثوم', 'كزبرة']);
      expect(back.ingredients.last.optional, isTrue);
    });

    test('a copy is a new dish with the same ingredients', () async {
      final (row, _) = await service.addRecipe(
        const RecipeDraft(name: 'مجدرة', servings: 4),
        ingredients: const [IngredientDraft(name: 'رز')],
      );
      final (copy, undo) = await service.duplicateRecipe(row, name: 'مجدرة بالبرغل');
      expect(copy.name, 'مجدرة بالبرغل');
      expect(copy.servings, 4);
      expect((await service.recipe(copy.id))!.ingredients, hasLength(1));
      await undo();
      expect(await repos.recipes.count(), 1);
    });

    test('an imported dish records whose it is', () async {
      final (row, _) = await service.addRecipe(
        const RecipeDraft(name: 'ملوخية', source: RecipeSource.imported, sourceName: 'خالتي أم محمد'),
      );
      expect(row.source, RecipeSource.imported);
      expect(row.sourceName, 'خالتي أم محمد');
      expect((await service.recipe(row.id))!.isImported, isTrue);
    });

    test('ingredient lines add, edit and delete with their own undo', () async {
      final (row, _) = await service.addRecipe(const RecipeDraft(name: 'مجدرة'));
      final (line, addUndo) = await service.addIngredient(row.id, const IngredientDraft(name: 'رز', quantity: 1));
      expect((await service.recipe(row.id))!.ingredients, hasLength(1));
      final editUndo = await service.updateIngredient(
        line,
        const IngredientDraft(name: 'رز بسمتي', quantity: 2, unit: 'كيلو'),
      );
      expect((await service.ingredientRow(line.id))!.name, 'رز بسمتي');
      await editUndo();
      expect((await service.ingredientRow(line.id))!.name, 'رز');
      await addUndo();
      expect(await repos.recipeIngredients.count(), 0);
      final (again, _) = await service.addIngredient(row.id, const IngredientDraft(name: 'عدس'));
      final deleteUndo = await service.deleteIngredient(again);
      expect(await repos.recipeIngredients.count(), 0);
      await deleteUndo();
      expect(await repos.recipeIngredients.count(), 1);
    });

    test('photos she adds are replaced wholesale and undo', () async {
      final (row, _) = await service.addRecipe(const RecipeDraft(name: 'مجدرة'));
      final undo = await service.setPhotos(row, ['sufra/a.jpg', '  ', 'sufra/b.jpg']);
      expect((await service.recipeRow(row.id))!.photos, ['sufra/a.jpg', 'sufra/b.jpg']);
      await undo();
      expect((await service.recipeRow(row.id))!.photos, isEmpty);
    });
  });

  group('the cooked log', () {
    test('cooking records the day and the name, and undoes', () async {
      final (recipe, _) = await service.addRecipe(const RecipeDraft(name: 'ملوخية', servings: 5));
      final (log, undo) = await service.cook(recipe);
      expect(log.name, 'ملوخية');
      expect(log.day, DateTime(2026, 10, 14));
      expect(log.servings, 5);
      expect(log.overrode, isFalse);
      await undo();
      expect(await repos.cookedMeals.count(), 0);
    });

    test('something cooked without a recipe is still history', () async {
      final (log, _) = await service.cookFreeText('بيض ومقدوس');
      expect(log.recipeId, isNull);
      expect(log.name, 'بيض ومقدوس');
      final hold = NoRepeat.check(await service.cookedLog(), recipeId: 'whatever', today: service.today);
      expect(hold.held, isFalse);
    });

    test('cooking holds the dish back, and her window frees it again', () async {
      final (recipe, _) = await service.addRecipe(
        const RecipeDraft(name: 'ملوخية'),
        ingredients: const [IngredientDraft(name: 'ملوخية')],
      );
      await service.addPantryItem(const PantryDraft(name: 'ملوخية', quantity: 1, unit: 'كيس'));
      var board = await service.board();
      expect(board.cookNow, hasLength(1));
      await service.cook(recipe);
      board = await service.board();
      expect(board.cookNow, isEmpty);
      expect(board.matches.single.hold.held, isTrue);
      expect(board.matches.single.hold.daysAgo, 0);
      // She turns the rule off.
      await service.setSettings(const SufraSettings(noRepeatDays: 0));
      board = await service.board();
      expect(board.cookNow, hasLength(1));
    });

    test('cooking from a match deducts only what it could compare, and the undo puts it all back', () async {
      await service.addPantryItem(const PantryDraft(name: 'رز', quantity: 2, unit: 'كيلو'));
      await service.addPantryItem(const PantryDraft(name: 'سمنة', quantity: 1, unit: 'كيلو'));
      final (recipe, _) = await service.addRecipe(
        const RecipeDraft(name: 'مجدرة'),
        ingredients: const [
          IngredientDraft(name: 'رز', quantity: 500, unit: 'غرام'),
          IngredientDraft(name: 'سمنة', quantity: 1, unit: 'كوب'),
        ],
      );
      final board = await service.board();
      final match = board.matchOf(recipe.id)!;
      expect(match.verdict, MatchVerdict.unsure, reason: 'the cup of ghee cannot be compared');
      final (_, undo) = await service.cookFromMatch(match);
      final rice = (await repos.pantryItems.getAll()).firstWhere((i) => i.name == 'رز');
      final ghee = (await repos.pantryItems.getAll()).firstWhere((i) => i.name == 'سمنة');
      expect(rice.quantity, 1.5);
      expect(ghee.quantity, 1, reason: 'the cup was never guessed at');
      expect(await repos.cookedMeals.count(), 1);
      await undo();
      expect(await repos.cookedMeals.count(), 0);
      expect((await repos.pantryItems.getAll()).firstWhere((i) => i.name == 'رز').quantity, 2);
    });

    test('a cooked row deletes and undoes', () async {
      final (log, _) = await service.cookFreeText('عدس');
      final undo = await service.deleteCooked(log);
      expect(await repos.cookedMeals.count(), 0);
      await undo();
      expect(await repos.cookedMeals.count(), 1);
    });
  });

  group('her constraints', () {
    test('a rule adds, switches off and deletes, each with its undo', () async {
      final (row, addUndo) = await service.addRule(
        const KitchenRuleDraft(kind: KitchenRuleKind.allergy, term: 'فول سوداني', who: 'أحمد'),
      );
      expect(row.kind, KitchenRuleKind.allergy);
      expect(row.active, isTrue);
      final offUndo = await service.setRuleActive(row, false);
      expect((await repos.kitchenRules.byId(row.id))!.active, isFalse);
      await offUndo();
      expect((await repos.kitchenRules.byId(row.id))!.active, isTrue);
      final editUndo = await service.updateRule(
        row,
        const KitchenRuleDraft(kind: KitchenRuleKind.avoid, term: 'حار'),
      );
      expect((await repos.kitchenRules.byId(row.id))!.term, 'حار');
      await editUndo();
      expect((await repos.kitchenRules.byId(row.id))!.term, 'فول سوداني');
      await addUndo();
      expect(await repos.kitchenRules.count(), 0);
    });

    test('an allergy keeps the dish out of the board', () async {
      await service.addPantryItem(const PantryDraft(name: 'فول سوداني', quantity: 1, unit: 'كيس'));
      await service.addRecipe(
        const RecipeDraft(name: 'كيك'),
        ingredients: const [IngredientDraft(name: 'فول سوداني')],
      );
      expect((await service.board()).matches, hasLength(1));
      await service.addRule(const KitchenRuleDraft(kind: KitchenRuleKind.allergy, term: 'فول سوداني', who: 'أحمد'));
      final board = await service.board();
      expect(board.matches, isEmpty);
      expect(board.tonight, isNull);
    });

    test('his meal plan is dropped on the floor while the owner has not turned it on', () async {
      await service.addPantryItem(const PantryDraft(name: 'رز', quantity: 2, unit: 'كيلو'));
      await service.addRecipe(const RecipeDraft(name: 'مجدرة'), ingredients: const [IngredientDraft(name: 'رز')]);
      const diet = DietLink(on: true, avoid: ['رز'], label: 'خطة الأكل');
      var board = await service.board(diet: diet);
      expect(board.matches.single.hits, isEmpty, reason: 'dietMode is off');
      await service.setSettings(const SufraSettings(dietMode: true));
      board = await service.board(diet: diet);
      expect(board.matches.single.hits.single.breach, ConstraintBreach.diet);
    });
  });

  group('the shopping list, through Part 3b', () {
    test('the house has one standing list, created once', () async {
      final first = await service.houseList(name: 'اللي ناقص البيت');
      final again = await service.houseList(name: 'اسم ثاني');
      expect(again.id, first.id);
      expect(first.hostTable, PantryLists.houseTable);
      expect(first.hostId, PantryLists.houseId);
      expect(await repos.recordLists.count(), 1);
    });

    test('what is low or finished flows into it, and never twice', () async {
      await service.addPantryItem(const PantryDraft(name: 'زيت', quantity: 0, unit: 'لتر'));
      await service.addPantryItem(const PantryDraft(name: 'رز', quantity: 0.5, unit: 'كيلو', lowAt: 2));
      await service.addPantryItem(const PantryDraft(name: 'بندورة', quantity: 5, unit: 'حبة'));
      final (list, added, undo) = await service.lowToHouseList(listName: 'اللي ناقص البيت');
      expect(added, 2);
      final lines = await lists.lines(list.id);
      expect([for (final l in lines) l.title], ['زيت', 'رز']);
      expect(lines.last.quantity, 2);
      expect(lines.last.unit, 'كيلو');
      final (_, again, _) = await service.lowToHouseList(listName: 'اللي ناقص البيت');
      expect(again, 0, reason: 'already on the list');
      await undo();
      expect(await lists.lines(list.id), isEmpty);
    });

    test('a near match becomes that dish\'s own list, which she ticks in the shop', () async {
      await service.addPantryItem(const PantryDraft(name: 'رز', quantity: 1200, unit: 'غرام'));
      final (recipe, _) = await service.addRecipe(
        const RecipeDraft(name: 'مقلوبة'),
        ingredients: const [
          IngredientDraft(name: 'رز', quantity: 2, unit: 'كيلو'),
          IngredientDraft(name: 'دجاج', quantity: 1, unit: 'فرخة'),
        ],
      );
      final match = (await service.board()).matchOf(recipe.id)!;
      expect(match.verdict, MatchVerdict.nearly);
      final (list, added, undo) = await service.missingToList(match, listName: 'ناقص لـمقلوبة');
      expect(list.hostTable, PantryLists.recipesTable);
      expect(list.hostId, recipe.id);
      expect(added, 2);
      final lines = await lists.lines(list.id);
      expect([for (final l in lines) l.title], ['رز', 'دجاج']);
      expect(lines.first.quantity, 0.8);
      // She ticks one in the shop – the list engine's own ticking, unchanged.
      final rows = await lists.itemRows(list.id);
      await lists.setDone(rows.first, true);
      expect((await lists.totals(list.id)).done, 1);
      await undo();
      expect(await lists.lines(list.id), isEmpty);
    });

    test('deleting the dish takes its missing-list with it, and the undo brings both back', () async {
      await service.addPantryItem(const PantryDraft(name: 'رز', quantity: 1, unit: 'كيلو'));
      final (recipe, _) = await service.addRecipe(
        const RecipeDraft(name: 'مقلوبة'),
        ingredients: const [IngredientDraft(name: 'رز'), IngredientDraft(name: 'دجاج')],
      );
      final match = (await service.board()).matchOf(recipe.id)!;
      final (list, _, _) = await service.missingToList(match, listName: 'ناقص');
      expect(await repos.recordLists.count(), 1);
      final undo = await service.deleteRecipe(recipe);
      expect(await repos.recordLists.count(), 0);
      expect(await repos.recordListItems.count(), 0);
      await undo();
      expect(await repos.recipes.count(), 1);
      expect((await lists.list(list.id))!.name, 'ناقص');
      expect(await lists.lines(list.id), hasLength(1));
    });

    test('«السفرة» writes no list rows of its own', () async {
      final list = await service.houseList(name: 'اللي ناقص البيت');
      final rows = await lists.listsOf(const ListHost(PantryLists.houseTable, PantryLists.houseId));
      expect(rows.single.id, list.id, reason: 'it is the shared engine, addressed by a host');
    });
  });

  group('the whole board', () {
    test('tonight is the dish she can cook, and the near one says what is missing', () async {
      await service.addPantryItem(const PantryDraft(name: 'رز', quantity: 2, unit: 'كيلو'));
      await service.addPantryItem(const PantryDraft(name: 'عدس', quantity: 1, unit: 'كيلو'));
      await service.addRecipe(
        const RecipeDraft(name: 'مجدرة', servings: 4, minutes: 40),
        ingredients: const [
          IngredientDraft(name: 'رز', quantity: 2, unit: 'كيلو'),
          IngredientDraft(name: 'عدس', quantity: 500, unit: 'غرام'),
        ],
      );
      await service.addRecipe(
        const RecipeDraft(name: 'مقلوبة'),
        ingredients: const [IngredientDraft(name: 'رز'), IngredientDraft(name: 'دجاج', quantity: 1, unit: 'فرخة')],
      );
      final board = await service.board();
      expect(board.tonight!.recipe.name, 'مجدرة');
      expect(board.cookNow, hasLength(1));
      expect(board.nearly, hasLength(1));
      final near = board.nearly.single;
      expect(near.recipe.name, 'مقلوبة');
      expect(near.shopping.single.ingredient.name, 'دجاج');
      expect(near.shopping.single.shortBy, 1);
      expect(near.shopping.single.shortUnit, 'فرخة');
    });

    test('tonight\'s choices are layered on her stored settings', () async {
      await service.addPantryItem(const PantryDraft(name: 'رز', quantity: 4, unit: 'كيلو'));
      await service.addRecipe(
        const RecipeDraft(name: 'مجدرة', servings: 4),
        ingredients: const [IngredientDraft(name: 'رز', quantity: 1, unit: 'كيلو')],
      );
      await service.setSettings(const SufraSettings(defaultPeople: 4));
      var board = await service.board();
      expect(board.matches.single.scaledFor, isNull);
      board = await service.board(extra: const KitchenConstraints(people: 12));
      expect(board.matches.single.scaledFor, 12);
      expect(board.matches.single.verdict, MatchVerdict.cookNow, reason: 'three kilos of the four she has');
      board = await service.board(extra: const KitchenConstraints(people: 20));
      expect(board.matches.single.scaledFor, 20);
      expect(board.matches.single.verdict, MatchVerdict.nearly);
      expect(board.matches.single.shopping.single.shortBy, 1, reason: 'five kilos needed, four in the house');
    });

    test('her settings round-trip through the key/value store, and undo', () async {
      final undo = await service.setSettings(const SufraSettings(noRepeatDays: 7, defaultPeople: 6));
      expect((await service.settings()).noRepeatDays, 7);
      expect((await service.settings()).defaultPeople, 6);
      await undo();
      expect(await service.settings(), const SufraSettings());
    });
  });
}
