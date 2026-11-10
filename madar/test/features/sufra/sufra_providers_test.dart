// The Riverpod wiring of «السفرة» over a real in-memory database: the
// streams the screens watch, the board they read, and tonight's choices.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/providers.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/sufra/sufra.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _now = DateTime(2026, 10, 14, 17, 30);
final _today = DateTime(2026, 10, 14);

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  TestWidgetsFlutterBinding.ensureInitialized();

  late MadarDatabase db;
  late Repositories repos;
  late SufraService service;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    db = MadarDatabase(NativeDatabase.memory());
    repos = Repositories(db);
    service = SufraService(repos, clock: () => _now);
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        sufraClockProvider.overrideWithValue(() => _now),
        sufraTodayProvider.overrideWithValue(_today),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// Keeps the row streams subscribed for the whole test.
  void keepAlive() {
    for (final p in [pantryRowsProvider, recipeRowsProvider, kitchenRuleRowsProvider]) {
      container.listen(p, (_, _) {});
    }
    container.listen(recipesProvider, (_, _) {});
    container.listen(cookedLogProvider, (_, _) {});
    container.listen(sufraSettingsProvider, (_, _) {});
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('a fresh install reads as an empty board, with nothing to suggest', () async {
    keepAlive();
    await settle();
    final board = container.read(sufraBoardProvider);
    expect(board.isEmpty, isTrue);
    expect(container.read(recipeMatchesProvider), isEmpty);
    expect(container.read(tonightProvider), isNull);
    expect(container.read(pantryAttentionProvider), isEmpty);
    expect(container.read(noRepeatWindowProvider), 14);
  });

  test('the pantry, the dishes and the ranking all reach the screens', () async {
    keepAlive();
    await service.addPantryItem(const PantryDraft(name: 'رز', quantity: 2, unit: 'كيلو'));
    await service.addPantryItem(const PantryDraft(name: 'عدس', quantity: 0.2, unit: 'كيلو', lowAt: 1));
    await service.addRecipe(
      const RecipeDraft(name: 'مجدرة'),
      ingredients: const [IngredientDraft(name: 'رز'), IngredientDraft(name: 'عدس', quantity: 1, unit: 'كيلو')],
    );
    await settle();
    expect(container.read(pantryBoardProvider).length, 2);
    expect([for (final s in container.read(pantryAttentionProvider)) s.item.name], ['عدس']);
    expect(container.read(recipesProvider).value, hasLength(1));
    final match = container.read(recipeMatchesProvider).single;
    expect(match.verdict, MatchVerdict.nearly);
    expect(match.shopping.single.ingredient.name, 'عدس');
    expect(match.shopping.single.shortBy, 0.8);
    expect(container.read(cookNowProvider), isEmpty);
    expect(container.read(nearlyProvider), hasLength(1));
    expect(container.read(tonightProvider)!.recipe.name, 'مجدرة');
  });

  test('tonight\'s choices are a notifier the screens set, and they re-rank at once', () async {
    keepAlive();
    await service.addPantryItem(const PantryDraft(name: 'رز', quantity: 2, unit: 'كيلو'));
    await service.addRecipe(
      const RecipeDraft(name: 'مقلوبة', minutes: 90),
      ingredients: const [IngredientDraft(name: 'رز')],
    );
    await settle();
    expect(container.read(recipeMatchesProvider).single.hits, isEmpty);
    container.read(kitchenConstraintsProvider.notifier).minutes(30);
    expect(container.read(recipeMatchesProvider).single.hits.single.breach, ConstraintBreach.tooLong);
    container.read(kitchenConstraintsProvider.notifier).clear();
    expect(container.read(recipeMatchesProvider).single.hits, isEmpty);
  });

  test('her constraints and the cooked log reach the board', () async {
    keepAlive();
    await service.addPantryItem(const PantryDraft(name: 'رز', quantity: 2, unit: 'كيلو'));
    final (recipe, _) = await service.addRecipe(
      const RecipeDraft(name: 'مجدرة'),
      ingredients: const [IngredientDraft(name: 'رز')],
    );
    await settle();
    expect(container.read(cookNowProvider), hasLength(1));
    await service.cook(recipe);
    await settle();
    expect(container.read(cookedLogProvider).value, hasLength(1));
    expect(container.read(cookNowProvider), isEmpty, reason: 'the window holds it');
    expect(container.read(recipeMatchProvider(recipe.id))!.hold.held, isTrue);
    await service.addRule(const KitchenRuleDraft(kind: KitchenRuleKind.allergy, term: 'رز'));
    await settle();
    expect(container.read(kitchenRulesProvider), hasLength(1));
    expect(container.read(recipeMatchesProvider), isEmpty, reason: 'a hard constraint keeps it out');
  });

  test('his meal plan is off by default, and the kitchen is handed nothing', () async {
    keepAlive();
    await settle();
    expect(container.read(sufraDietLinkProvider).on, isFalse);
    expect(container.read(sufraDietLinkProvider).isEmpty, isTrue);
    expect(container.read(sufraSettingsProvider).value!.dietMode, isFalse);
  });
}
