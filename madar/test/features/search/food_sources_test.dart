// Food is searchable: the five new sources over the nutrition tables index
// HIS words (the food's name, his tags, a meal's name and time, the rule he
// wrote) and never a raw key, and inside the real app typing an Arabic word
// finds the meal he logged and opens the food of that day.
//
// A hang (a future waiting on fake time) fails fast instead of after 10 min.
@Timeout(Duration(minutes: 5))
library;

import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/core/routing/system_route_pages.dart' show searchTargetOf;
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/search/search.dart';

import '../../helpers/test_app.dart';
import '../lock/lock_test_utils.dart';

final _now = DateTime(2026, 9, 30, 10);

MadarDatabase _db() => MadarDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));

/// What he wrote about his own eating.
Future<void> seedFood(MadarDatabase db) async {
  final r = Repositories(db);
  await r.conditions.insert(ConditionsCompanion.insert(id: const Value('c1'), name: 'الضغط'));
  await r.foods.insert(
    FoodsCompanion.insert(
      id: const Value('f1'),
      name: 'مقلوبة',
      tags: const Value(['نشويات', 'مقلي']),
      defaultPortion: const Value(1.5),
      unit: const Value('طبق'),
      notes: const Value('تعجبني مع اللبن'),
    ),
  );
  await r.mealPlans.insert(
    MealPlansCompanion.insert(id: const Value('p1'), name: 'خطة رمضان', active: const Value(true)),
  );
  await r.mealSlots.insert(
    MealSlotsCompanion.insert(
      id: const Value('s1'),
      planId: 'p1',
      name: 'سحور',
      timeMinutes: 240,
      weekdays: const Value([1, 3, 5]),
      notes: const Value('بعد ما أصحى'),
    ),
  );
  await r.mealSlotFoods.insert(MealSlotFoodsCompanion.insert(slotId: 's1', foodId: const Value('f1'), name: 'مقلوبة'));
  await r.foodLogs.insert(
    FoodLogsCompanion.insert(
      id: const Value('l1'),
      foodId: const Value('f1'),
      name: 'مقلوبة',
      at: DateTime(2026, 9, 29, 13, 30),
      portion: const Value(2),
      unit: const Value('طبق'),
      tags: const Value(['زيارة']),
      note: const Value('بيت الوالدة'),
      slotId: const Value('s1'),
    ),
  );
  await r.foodRules.insert(
    FoodRulesCompanion.insert(
      id: const Value('r1'),
      conditionId: const Value('c1'),
      target: const Value(FoodRuleTarget.tag),
      tag: const Value('مقلي'),
      weight: const Value(RiskWeight.high),
      note: const Value('المقلي يتعبني'),
    ),
  );
}

List<Override> _searchOverrides() => [
  searchWorkerFactoryProvider.overrideWithValue(() async => InlineSearchWorker()),
  searchDebounceProvider.overrideWithValue(const Duration(milliseconds: 10)),
];

Iterable<String> _texts(WidgetTester tester) =>
    tester.widgetList<RichText>(find.byType(RichText)).map((r) => r.text.toPlainText(includeSemanticsLabels: false));

Future<void> _frames(WidgetTester tester, [int n = 20]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  group('the sources', () {
    late MadarDatabase db;
    late Map<String, List<SearchDoc>> bySource;

    setUpAll(() async {
      await initializeDateFormatting('ar');
      db = _db();
      await db.customSelect('SELECT 1').get();
      await seedFood(db);
      final ctx = SearchLoadContext(
        repos: Repositories(db),
        l10n: lookupL10n(const Locale('ar')),
        formatter: const MadarFormatter(languageCode: 'ar'),
        surahName: (_) => null,
      );
      bySource = {
        for (final s in BuiltInSearchSources.all()) s.id: (await s.load(ctx)).map((d) => d.withSource(s.id)).toList(),
      };
    });
    tearDownAll(() => db.close());

    SearchDoc one(String source) => bySource[source]!.single;

    test('every food table with his own words has a source, and the join table has none', () {
      for (final id in ['foods', 'food_logs', 'meal_plans', 'meal_slots', 'food_rules']) {
        expect(bySource[id], hasLength(1), reason: id);
        expect(bySource[id]!.single.planetKey, 'body', reason: id);
      }
      expect(bySource.containsKey('meal_slot_foods'), isFalse, reason: 'a planned food is its food\'s own text');
      expect(BuiltInSearchSources.neverIndexed, contains('meal_slot_foods'));
      final indexed = {
        for (final docs in bySource.values)
          for (final d in docs) d.refTable,
      };
      expect(indexed.intersection(BuiltInSearchSources.neverIndexed), isEmpty);
    });

    test('a food carries his name, his tags, his portion and his note', () {
      final food = one('foods');
      expect(food.title, 'مقلوبة');
      expect(food.subtitle, contains('نشويات'));
      expect(food.subtitle, contains('مقلي'));
      expect(food.subtitle, contains('طبق'));
      expect(food.body, 'تعجبني مع اللبن');
    });

    test('an entry keeps its own name and his word for that one time', () {
      final log = one('food_logs');
      expect(log.title, 'مقلوبة');
      expect(log.subtitle, contains('زيارة'));
      expect(log.body, 'بيت الوالدة');
      expect(log.date, DateTime(2026, 9, 29, 13, 30));
      expect(log.extra['foodId'], 'f1');
    });

    test('a meal reads with its time and its plan; a plan says it is the active one', () {
      final slot = one('meal_slots');
      expect(slot.title, 'سحور');
      expect(slot.subtitle, contains('خطة رمضان'));
      expect(slot.subtitle, contains('٤'), reason: 'four in the morning, in his digits');
      expect(slot.body, 'بعد ما أصحى');
      expect(slot.extra['planId'], 'p1');
      final plan = one('meal_plans');
      expect(plan.title, 'خطة رمضان');
      expect(plan.subtitle, lookupL10n(const Locale('ar')).nutritionActiveLabel);
    });

    test('a rule reads as his words, never as a stored key', () {
      final rule = one('food_rules');
      expect(rule.title, 'مقلي', reason: 'the tag he marked');
      expect(rule.subtitle, contains('الضغط'), reason: 'the condition it is about, by name');
      expect(rule.body, 'المقلي يتعبني', reason: 'his own reason');
      final everything = [rule.title, rule.subtitle, rule.body, ...rule.extra.values].join('\n');
      for (final key in ['tag', 'anyFood', 'high', 'food_rules']) {
        expect(everything, isNot(contains(key)), reason: key);
      }
    });

    test('every food result has a screen to open', () {
      expect(searchTargetOf(one('foods')), AppRoutes.foodLibrary);
      expect(searchTargetOf(one('food_logs')), AppRoutes.bodyOf(tab: 'food'));
      expect(searchTargetOf(one('meal_plans')), AppRoutes.foodPlan);
      expect(searchTargetOf(one('meal_slots')), AppRoutes.foodPlan);
      expect(searchTargetOf(one('food_rules')), AppRoutes.foodRules);
    });
  });

  group('in the real app', () {
    for (final lang in ['ar', 'en']) {
      testWidgets('$lang: an Arabic word finds the meal he logged, and it opens the food of that day', (tester) async {
        final app = await pumpMadarApp(
          tester,
          settings: AppSettings(onboarded: true, languageCode: lang),
          initialLocation: AppRoutes.search,
          now: _now,
          settle: false,
          beforePump: seedFood,
          overrides: [...LockFixture.empty().overrides, ..._searchOverrides()],
        );
        await _frames(tester, 20);
        await tester.enterText(find.byType(TextField).first, 'مقلوبة');
        await _frames(tester, 30);

        expect(find.byType(SearchResultTile), findsWidgets);
        expect(_texts(tester).any((t) => t.contains('مقلوبة')), isTrue, reason: 'his own word finds it');
        // The food library's name and the entry both answer.
        final titles = tester
            .widgetList<SearchResultTile>(find.byType(SearchResultTile))
            .map((t) => t.hit.doc.refTable)
            .toSet();
        expect(titles, containsAll(['foods', 'food_logs']));

        await tester.tap(find.byType(SearchResultTile).first);
        await _frames(tester, 24);
        expect(
          app.location,
          anyOf(AppRoutes.foodLibrary, AppRoutes.body),
          reason: 'a food opens the library, an entry the food of its day',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 6));
      });
    }

    testWidgets('his own word on a food finds it too', (tester) async {
      await pumpMadarApp(
        tester,
        initialLocation: AppRoutes.search,
        now: _now,
        settle: false,
        beforePump: seedFood,
        overrides: [...LockFixture.empty().overrides, ..._searchOverrides()],
      );
      await _frames(tester, 20);
      await tester.enterText(find.byType(TextField).first, 'مقلي');
      await _frames(tester, 30);
      final tables = tester
          .widgetList<SearchResultTile>(find.byType(SearchResultTile))
          .map((t) => t.hit.doc.refTable)
          .toSet();
      expect(tables, contains('food_rules'), reason: 'the rule he wrote about fried food');
      expect(tables, contains('foods'), reason: 'and the food he tagged with it');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    });
  });
}
