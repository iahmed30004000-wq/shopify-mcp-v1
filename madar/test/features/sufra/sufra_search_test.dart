// «السفرة» in the global search: her own words indexed, on her own world,
// every record leading back to a screen – and nothing paid for an empty
// kitchen.
import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/routing/life_route_pages.dart';
import 'package:madar/features/search/search.dart';

import '../../core/db/fixtures.dart';

MadarDatabase _memoryDb() =>
    MadarDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));

SearchLoadContext _context(MadarDatabase db, {String language = 'ar'}) => SearchLoadContext(
  repos: Repositories(db),
  l10n: lookupL10n(Locale(language)),
  formatter: MadarFormatter(languageCode: language),
  surahName: (_) => null,
);

const Set<String> _sufraSources = {'pantry_items', 'recipes', 'recipe_ingredients', 'cooked_meals', 'kitchen_rules'};

Future<Map<String, List<SearchDoc>>> _load(MadarDatabase db, {String language = 'ar'}) async {
  final ctx = _context(db, language: language);
  return {
    for (final s in BuiltInSearchSources.all())
      if (_sufraSources.contains(s.id)) s.id: (await s.load(ctx)).map((d) => d.withSource(s.id)).toList(),
  };
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
    await initializeDateFormatting('en');
  });

  group('the kitchen\'s sources', () {
    late MadarDatabase db;
    late Map<String, List<SearchDoc>> bySource;

    setUpAll(() async {
      db = _memoryDb();
      await populateAllTables(db);
      bySource = await _load(db);
    });

    tearDownAll(() => db.close());

    test('every kitchen table with her own words has a source, all on her world', () {
      for (final id in _sufraSources) {
        expect(bySource[id], isNotEmpty, reason: id);
        for (final d in bySource[id]!) {
          expect(d.planetKey, 'sufra', reason: id);
          expect(d.refId, isNotEmpty);
          expect(d.refTable, id);
          // Every record leads back to a screen.
          expect(LifeRecordLinks.locationOf(d.refTable, d.refId, extra: d.extra), isNotNull, reason: id);
        }
      }
    });

    test('an item of the house carries her name, her other names, the place and her note', () {
      final rice = bySource['pantry_items']!.singleWhere((d) => d.refId == 'pantry-rice');
      expect(rice.title, 'رز');
      expect(rice.subtitle, contains('رز بسمتي'));
      expect(rice.subtitle, contains('خزانة المونة'));
      expect(rice.body, 'من عند أبو علي');
      // Never how much is left: that changes every day and lives on the
      // pantry screen.
      expect('${rice.title}${rice.subtitle}${rice.body}', isNot(contains('كيلو')));
    });

    test('a dish carries her tags, whose it is, her method and her notes', () {
      final dish = bySource['recipes']!.singleWhere((d) => d.refId == 'recipe-mloukhieh');
      expect(dish.title, 'ملوخية');
      expect(dish.subtitle, contains('رمضان'));
      expect(dish.subtitle, contains('خالتي أم محمد'));
      expect(dish.body, contains('سخّني الزيت'));
      expect(dish.body, contains('بتصير أطيب تاني يوم'));
    });

    test('an ingredient line says which dish it belongs to and opens it', () {
      final line = bySource['recipe_ingredients']!.singleWhere((d) => d.refId == 'ingredient-1');
      expect(line.title, 'رز');
      expect(line.subtitle, contains('ملوخية'));
      expect(line.extra['recipeId'], 'recipe-mloukhieh');
      expect(
        LifeRecordLinks.locationOf('recipe_ingredients', line.refId, extra: line.extra),
        '/sufra/recipe/recipe-mloukhieh',
      );
    });

    test('the cooked log keeps the dish\'s name of that day, and says when she overrode the window', () {
      final meal = bySource['cooked_meals']!.singleWhere((d) => d.refId == 'cooked-1');
      expect(meal.title, 'ملوخية');
      expect(meal.subtitle, contains(lookupL10n(const Locale('ar')).sufraCookedAnyway));
      expect(meal.body, 'ضيوف');
    });

    test('a constraint carries her word and whose it is – never a diagnosis', () {
      final rule = bySource['kitchen_rules']!.singleWhere((d) => d.refId == 'rule-1');
      expect(rule.title, 'فول سوداني');
      expect(rule.subtitle, contains(lookupL10n(const Locale('ar')).sufraRuleAllergy));
      expect(rule.subtitle, contains('أحمد'));
      expect(rule.subtitle, contains(lookupL10n(const Locale('ar')).sufraRuleOff));
    });
  });

  // Part 3b's lesson: a source that has to preload another table to
  // describe its rows asks whether there is anything to index first, or an
  // empty feature is paid for on every first query.
  test('an empty kitchen indexes nothing, and the ingredient source reads no dish to find out', () async {
    final db = _memoryDb();
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();
    expect((await _load(db)).values.every((docs) => docs.isEmpty), isTrue);

    // One dish, no ingredient line yet: still nothing, and still no table
    // of dish names built.
    await Repositories(db).recipes.insert(RecipesCompanion.insert(id: const Value('r1'), name: 'مجدرة'));
    final after = await _load(db);
    expect(after['recipes'], hasLength(1));
    expect(after['recipe_ingredients'], isEmpty);
  });

  test('the kitchen is named on her world in both languages', () {
    expect(SearchLabels.builtInPlanet(lookupL10n(const Locale('ar')), 'sufra'), 'السفرة');
    expect(SearchLabels.builtInPlanet(lookupL10n(const Locale('en')), 'sufra'), 'The kitchen');
    for (final lang in ['ar', 'en']) {
      final l = lookupL10n(Locale(lang));
      for (final s in BuiltInSearchSources.all()) {
        if (!_sufraSources.contains(s.id)) continue;
        expect(s.label(l), isNotEmpty);
        expect(s.label(l), isNot(startsWith('sufraSearch')), reason: '${s.id} has no name in $lang');
      }
    }
  });

  test('nothing of the kitchen is in the never-indexed set', () {
    expect(_sufraSources.intersection(BuiltInSearchSources.neverIndexed), isEmpty);
    expect(KitchenRuleKind.values, hasLength(4));
  });
}
