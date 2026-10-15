// The heart of «السفرة». The four cases the brief asks for: a pantry that
// covers a dish exactly, one that misses a thing, one that misses an
// amount, and one where a unit cannot be converted – and that last one
// must say "unknown", never guess.
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/sufra/sufra.dart';

import 'sufra_fixtures.dart';

void main() {
  group('one dish against the house', () {
    test('a pantry that covers it exactly: she can cook it now', () {
      final recipe = dish(
        'r1',
        'مجدرة',
        ingredients: [ing('رز', quantity: 2, unit: 'كيلو'), ing('عدس', quantity: 500, unit: 'غرام')],
      );
      final m = PantryMatcher.match(
        recipe,
        pantry: board([item('رز', quantity: 2, unit: 'كيلو'), item('عدس', quantity: 1, unit: 'كيلو')]),
      );
      expect(m.verdict, MatchVerdict.cookNow);
      expect(m.cookable, isTrue);
      expect(m.coverage, 1);
      expect(m.missingCount, 0);
      expect(m.shopping, isEmpty);
      expect([for (final c in m.checks) c.verdict], everyElement(IngredientVerdict.have));
    });

    test('one thing missing: it says which, and how much', () {
      final recipe = dish(
        'r1',
        'مجدرة',
        ingredients: [ing('رز', quantity: 2, unit: 'كيلو'), ing('عدس', quantity: 500, unit: 'غرام')],
      );
      final m = PantryMatcher.match(recipe, pantry: board([item('رز', quantity: 2, unit: 'كيلو')]));
      expect(m.verdict, MatchVerdict.nearly);
      expect(m.cookable, isFalse);
      expect(m.missingCount, 1);
      final lentils = m.shopping.single;
      expect(lentils.ingredient.name, 'عدس');
      expect(lentils.verdict, IngredientVerdict.missing);
      expect(lentils.shortBy, 500);
      expect(lentils.shortUnit, 'غرام');
      expect(m.coverage, 0.5);
    });

    test('a quantity missing: the gap, in the unit the dish asked for', () {
      final recipe = dish('r1', 'مجدرة', ingredients: [ing('رز', quantity: 2, unit: 'كيلو')]);
      final m = PantryMatcher.match(recipe, pantry: board([item('رز', quantity: 1200, unit: 'غرام')]));
      expect(m.verdict, MatchVerdict.nearly);
      final rice = m.shopping.single;
      expect(rice.verdict, IngredientVerdict.short);
      expect(rice.shortBy, 0.8);
      expect(rice.shortUnit, 'كيلو');
      expect(rice.comparison!.match, UnitMatch.converted);
    });

    test('a unit it cannot convert: unknown, never a guess, and never cookable', () {
      final recipe = dish('r1', 'مجدرة', ingredients: [ing('رز', quantity: 2, unit: 'كوب')]);
      final m = PantryMatcher.match(recipe, pantry: board([item('رز', quantity: 5, unit: 'كيلو')]));
      expect(m.verdict, MatchVerdict.unsure);
      expect(m.cookable, isFalse);
      final rice = m.unsureChecks.single;
      expect(rice.verdict, IngredientVerdict.unknownUnit);
      expect(rice.shortBy, isNull, reason: 'no number may be invented');
      expect(rice.comparison!.isKnown, isFalse);
      expect(rice.stock!.item.name, 'رز', reason: 'the thing it was compared against is still named');
      expect(m.coverage, 0);
    });

    test('an amount she never typed: unknown too, not "enough"', () {
      final recipe = dish('r1', 'مجدرة', ingredients: [ing('رز', quantity: 2, unit: 'كيلو')]);
      final m = PantryMatcher.match(recipe, pantry: board([item('رز', unit: 'كيلو')]));
      expect(m.verdict, MatchVerdict.unsure);
      expect(m.unsureChecks.single.verdict, IngredientVerdict.unknownAmount);
      expect(m.unsureChecks.single.shortBy, isNull);
    });

    test('a dish that asks for no amount only needs the thing to be there', () {
      final recipe = dish('r1', 'سلطة', ingredients: [ing('ملح'), ing('بندورة', quantity: 2, unit: 'حبة')]);
      final m = PantryMatcher.match(
        recipe,
        pantry: board([item('ملح'), item('بندورة', quantity: 4, unit: 'حبة')]),
      );
      expect(m.verdict, MatchVerdict.cookNow);
      expect(m.cookable, isTrue);
    });

    test('a finished thing is missing even though it is in the list', () {
      final recipe = dish('r1', 'مجدرة', ingredients: [ing('رز', quantity: 1, unit: 'كيلو')]);
      final m = PantryMatcher.match(recipe, pantry: board([item('رز', quantity: 0, unit: 'كيلو')]));
      expect(m.shopping.single.verdict, IngredientVerdict.missing);
      expect(m.shopping.single.shortBy, 1);
    });

    test('an optional ingredient never stops a dish, and never reaches the shopping list', () {
      final recipe = dish(
        'r1',
        'مجدرة',
        ingredients: [ing('رز', quantity: 1, unit: 'كيلو'), ing('صنوبر', quantity: 50, unit: 'غرام', optional: true)],
      );
      final m = PantryMatcher.match(recipe, pantry: board([item('رز', quantity: 1, unit: 'كيلو')]));
      expect(m.verdict, MatchVerdict.cookNow);
      expect(m.cookable, isTrue);
      expect(m.shopping, isEmpty);
      expect(m.checks.last.verdict, IngredientVerdict.missing, reason: 'it is still reported, just not blocking');
    });

    test('two things in the house could be it: ambiguous, and it names both', () {
      final recipe = dish('r1', 'مجدرة', ingredients: [ing('رز', quantity: 1, unit: 'كيلو')]);
      final m = PantryMatcher.match(
        recipe,
        pantry: board([
          item('رز بسمتي', quantity: 2, unit: 'كيلو', id: 'p1'),
          item('رز مصري', quantity: 2, unit: 'كيلو', id: 'p2'),
        ]),
      );
      expect(m.verdict, MatchVerdict.unsure);
      final check = m.unsureChecks.single;
      expect(check.verdict, IngredientVerdict.ambiguous);
      expect([for (final s in check.candidates) s.item.name], ['رز بسمتي', 'رز مصري']);
      expect(check.shortBy, isNull);
    });

    test('exactly one candidate matches loosely, and the match says so', () {
      final recipe = dish('r1', 'مجدرة', ingredients: [ing('رز', quantity: 1, unit: 'كيلو')]);
      final m = PantryMatcher.match(recipe, pantry: board([item('رز بسمتي', quantity: 2, unit: 'كيلو')]));
      expect(m.verdict, MatchVerdict.cookNow);
      expect(m.checks.single.loose, isTrue);
      expect(m.checks.single.stock!.item.name, 'رز بسمتي');
    });

    test('too much missing is far, not near', () {
      final recipe = dish(
        'r1',
        'مقلوبة',
        ingredients: [ing('رز'), ing('دجاج'), ing('زهرة'), ing('بهار'), ing('لوز')],
      );
      final m = PantryMatcher.match(recipe, pantry: board([item('رز')]));
      expect(m.verdict, MatchVerdict.far);
      expect(m.missingCount, 4);
    });

    test('it scales for how many are eating, and only when the dish says how many it feeds', () {
      final recipe = dish('r1', 'مجدرة', servings: 4, ingredients: [ing('رز', quantity: 1, unit: 'كيلو')]);
      final eight = PantryMatcher.match(
        recipe,
        pantry: board([item('رز', quantity: 1.5, unit: 'كيلو')]),
        constraints: const KitchenConstraints(people: 8),
      );
      expect(eight.scaledFor, 8);
      expect(eight.verdict, MatchVerdict.nearly);
      expect(eight.shopping.single.shortBy, 0.5);

      final noBase = dish('r2', 'ملوخية', ingredients: [ing('رز', quantity: 1, unit: 'كيلو')]);
      final unscaled = PantryMatcher.match(
        noBase,
        pantry: board([item('رز', quantity: 1, unit: 'كيلو')]),
        constraints: const KitchenConstraints(people: 8),
      );
      expect(unscaled.scaledFor, isNull, reason: 'scaling without a base would be inventing one');
      expect(unscaled.verdict, MatchVerdict.cookNow);
    });

    test('it flags the things it would use up before they go off', () {
      final recipe = dish('r1', 'عجة', ingredients: [ing('بيض', quantity: 3, unit: 'حبة')]);
      final m = PantryMatcher.match(
        recipe,
        pantry: board([item('بيض', quantity: 6, unit: 'حبة', expires: today.add(const Duration(days: 1)))]),
      );
      expect([for (final s in m.usesExpiring) s.item.name], ['بيض']);
    });
  });

  group('ranking', () {
    Recipe r(String id, String name, List<RecipeIngredient> ing, {int? minutes, bool favorite = false}) =>
        dish(id, name, ingredients: ing, minutes: minutes, favorite: favorite);

    test('cookable first, then the near ones by how little is missing, then the unsure', () {
      final pantry = board([
        item('رز', quantity: 2, unit: 'كيلو'),
        item('عدس', quantity: 1, unit: 'كيلو'),
        item('زيت', unit: 'لتر'),
      ]);
      final ranked = PantryMatcher.rank(
        [
          r('far', 'مقلوبة', [ing('دجاج'), ing('زهرة'), ing('لوز'), ing('بهار')]),
          r('unsure', 'كبسة', [ing('رز', quantity: 2, unit: 'كوب')]),
          r('near2', 'شوربة', [ing('رز'), ing('دجاج'), ing('بصل')]),
          r('now', 'مجدرة', [ing('رز'), ing('عدس')]),
          r('near1', 'يخنة', [ing('رز'), ing('بصل')]),
        ],
        pantry: pantry,
      );
      expect([for (final m in ranked) m.recipe.id], ['now', 'near1', 'near2', 'unsure', 'far']);
      expect([for (final m in PantryMatcher.cookNow(ranked)) m.recipe.id], ['now']);
      expect([for (final m in PantryMatcher.nearly(ranked)) m.recipe.id], ['near1', 'near2']);
      expect(PantryMatcher.tonight(ranked)!.recipe.id, 'now');
    });

    test('with nothing cookable, tonight falls back to the nearest miss', () {
      final ranked = PantryMatcher.rank(
        [r('a', 'يخنة', [ing('رز'), ing('بصل')])],
        pantry: board([item('رز')]),
      );
      expect(PantryMatcher.cookNow(ranked), isEmpty);
      expect(PantryMatcher.tonight(ranked)!.recipe.id, 'a');
    });

    test('with an empty pantry and no recipes there is simply nothing to suggest', () {
      final ranked = PantryMatcher.rank(const <Recipe>[], pantry: board(const []));
      expect(ranked, isEmpty);
      expect(PantryMatcher.tonight(ranked), isNull);
    });

    test('an archived dish is never suggested', () {
      final ranked = PantryMatcher.rank(
        [dish('a', 'مجدرة', ingredients: [ing('رز')], archived: true)],
        pantry: board([item('رز')]),
      );
      expect(ranked, isEmpty);
    });

    test('a dish that uses something about to go off comes before an equal one', () {
      final pantry = board([
        item('بيض', quantity: 6, unit: 'حبة', expires: today.add(const Duration(days: 1))),
        item('رز', quantity: 2, unit: 'كيلو'),
      ]);
      final ranked = PantryMatcher.rank(
        [r('rice', 'رز بحليب', [ing('رز')]), r('eggs', 'عجة', [ing('بيض')])],
        pantry: pantry,
      );
      expect(ranked.first.recipe.id, 'eggs');
    });

    test('one dish\'s match can be read back out of a ranking', () {
      final ranked = PantryMatcher.rank(
        [r('a', 'مجدرة', [ing('رز')])],
        pantry: board([item('رز')]),
      );
      expect(ranked.single.recipe.name, 'مجدرة');
    });
  });

  group('her constraints', () {
    test('an allergy blocks the dish and says whose it is', () {
      final recipe = dish('r1', 'كيك', ingredients: [ing('زبدة فول سوداني', quantity: 1, unit: 'كوب')]);
      final m = PantryMatcher.match(
        recipe,
        pantry: board([item('زبدة فول سوداني', quantity: 1, unit: 'كوب')]),
        constraints: KitchenConstraints(rules: [rule(KitchenRuleKind.allergy, 'فول سوداني', who: 'أحمد')]),
      );
      expect(m.blocked, isTrue);
      expect(m.cookable, isFalse);
      final hit = m.hits.single;
      expect(hit.breach, ConstraintBreach.allergy);
      expect(hit.term, 'فول سوداني');
      expect(hit.who, 'أحمد');
      expect(hit.hard, isTrue);
    });

    test('a blocked dish is left out of the ranking unless she asks to see it', () {
      final recipes = [dish('r1', 'كيك', ingredients: [ing('فول سوداني')])];
      final pantry = board([item('فول سوداني')]);
      final constraints = KitchenConstraints(rules: [rule(KitchenRuleKind.allergy, 'فول سوداني')]);
      expect(PantryMatcher.rank(recipes, pantry: pantry, constraints: constraints), isEmpty);
      expect(
        PantryMatcher.rank(recipes, pantry: pantry, constraints: constraints, includeBlocked: true),
        hasLength(1),
      );
    });

    test('an inactive rule does nothing', () {
      final m = PantryMatcher.match(
        dish('r1', 'كيك', ingredients: [ing('فول سوداني')]),
        pantry: board([item('فول سوداني')]),
        constraints: KitchenConstraints(rules: [rule(KitchenRuleKind.allergy, 'فول سوداني', active: false)]),
      );
      expect(m.hits, isEmpty);
      expect(m.cookable, isTrue);
    });

    test('«أبعد عنه» is soft: the dish stays, sorted after the clean ones', () {
      final constraints = KitchenConstraints(rules: [rule(KitchenRuleKind.avoid, 'حار')]);
      final ranked = PantryMatcher.rank(
        [
          dish('hot', 'شطة', ingredients: [ing('رز')], tags: ['حار']),
          dish('mild', 'مجدرة', ingredients: [ing('رز')]),
        ],
        pantry: board([item('رز')]),
        constraints: constraints,
      );
      expect([for (final m in ranked) m.recipe.id], ['mild', 'hot']);
      expect(ranked.last.blocked, isFalse);
      expect(ranked.last.hits.single.breach, ConstraintBreach.avoid);
    });

    test('«أفضّل» only nudges a dish up', () {
      final ranked = PantryMatcher.rank(
        [
          dish('plain', 'مجدرة', ingredients: [ing('رز')]),
          dish('liked', 'ملوخية', ingredients: [ing('رز')], tags: ['للأولاد']),
        ],
        pantry: board([item('رز')]),
        constraints: KitchenConstraints(rules: [rule(KitchenRuleKind.prefer, 'للأولاد')]),
      );
      expect(ranked.first.recipe.id, 'liked');
      expect(ranked.first.preferred, isTrue);
      expect(ranked.first.hits, isEmpty);
    });

    test('a request for tonight is a hard no', () {
      final m = PantryMatcher.match(
        dish('r1', 'يخنة', ingredients: [ing('بصل')]),
        pantry: board([item('بصل')]),
        constraints: KitchenConstraints(rules: [rule(KitchenRuleKind.request, 'بصل', who: 'الكل')]),
      );
      expect(m.hits.single.breach, ConstraintBreach.request);
      expect(m.blocked, isTrue);
    });

    test('time filters only a dish that says how long it takes', () {
      final pantry = board([item('رز')]);
      final timed = PantryMatcher.match(
        dish('r1', 'مقلوبة', ingredients: [ing('رز')], minutes: 90),
        pantry: pantry,
        constraints: const KitchenConstraints(maxMinutes: 30),
      );
      expect(timed.hits.single.breach, ConstraintBreach.tooLong);
      final untimed = PantryMatcher.match(
        dish('r2', 'مجدرة', ingredients: [ing('رز')]),
        pantry: pantry,
        constraints: const KitchenConstraints(maxMinutes: 30),
      );
      expect(untimed.hits, isEmpty, reason: 'Madar does not know how long it takes, so it does not pretend');
    });

    test('a tag she asked for tonight is required', () {
      final pantry = board([item('رز')]);
      final has = PantryMatcher.match(
        dish('r1', 'مجدرة', ingredients: [ing('رز')], tags: ['سريع']),
        pantry: pantry,
        constraints: const KitchenConstraints(mustTags: ['سريع']),
      );
      expect(has.hits, isEmpty);
      final hasNot = PantryMatcher.match(
        dish('r2', 'مقلوبة', ingredients: [ing('رز')]),
        pantry: pantry,
        constraints: const KitchenConstraints(mustTags: ['سريع']),
      );
      expect(hasNot.hits.single.breach, ConstraintBreach.missingTag);
    });

    test('his meal plan reaches nothing while the owner has not turned it on', () {
      final recipe = dish('r1', 'مقلوبة', ingredients: [ing('رز')]);
      final off = PantryMatcher.match(
        recipe,
        pantry: board([item('رز')]),
        constraints: const KitchenConstraints(diet: DietLink(avoid: ['رز'])),
      );
      expect(off.hits, isEmpty, reason: 'DietLink.on is false, so the kitchen knows nothing of his plan');
      final on = PantryMatcher.match(
        recipe,
        pantry: board([item('رز')]),
        constraints: const KitchenConstraints(diet: DietLink(on: true, avoid: ['رز'], label: 'خطة الأكل')),
      );
      expect(on.hits.single.breach, ConstraintBreach.diet);
      expect(on.hits.single.hard, isFalse, reason: 'a plan is never an allergy');
    });
  });
}
