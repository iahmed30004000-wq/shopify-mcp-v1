// «بدون تكرار»: the window she sets, at its boundaries, and her override.
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/sufra/sufra.dart';

import 'sufra_fixtures.dart';

void main() {
  DateTime daysAgo(int n) => today.subtract(Duration(days: n));

  group('the window', () {
    test('two weeks is the default, and 0 turns it off', () {
      expect(NoRepeat.window(null), 14);
      expect(NoRepeat.window(0), 0);
      expect(NoRepeat.window(-5), 0);
      expect(NoRepeat.window(7), 7);
      expect(NoRepeat.window(100000), NoRepeat.maxWindowDays);
    });

    test('a dish she never cooked is free', () {
      final hold = NoRepeat.check(const [], recipeId: 'r1', today: today);
      expect(hold.held, isFalse);
      expect(hold.lastCooked, isNull);
      expect(hold.daysAgo, isNull);
    });

    test('inside the window it is held, with how long ago and from which day it is free', () {
      final hold = NoRepeat.check([cooked('r1', daysAgo(3))], recipeId: 'r1', today: today, windowDays: 14);
      expect(hold.held, isTrue);
      expect(hold.daysAgo, 3);
      expect(hold.lastCooked, daysAgo(3));
      expect(hold.freeFrom, daysAgo(3).add(const Duration(days: 14)));
    });

    test('the boundary: one day short of the window holds, the window itself is free', () {
      expect(NoRepeat.check([cooked('r1', daysAgo(13))], recipeId: 'r1', today: today, windowDays: 14).held, isTrue);
      expect(NoRepeat.check([cooked('r1', daysAgo(14))], recipeId: 'r1', today: today, windowDays: 14).held, isFalse);
      expect(NoRepeat.check([cooked('r1', daysAgo(15))], recipeId: 'r1', today: today, windowDays: 14).held, isFalse);
    });

    test('cooked today is held by any window at all, and free with none', () {
      expect(NoRepeat.check([cooked('r1', today)], recipeId: 'r1', today: today, windowDays: 1).held, isTrue);
      expect(NoRepeat.check([cooked('r1', today)], recipeId: 'r1', today: today, windowDays: 0).held, isFalse);
    });

    test('the window reads the last time she cooked it, not the first', () {
      final hold = NoRepeat.check(
        [cooked('r1', daysAgo(20)), cooked('r1', daysAgo(2)), cooked('r1', daysAgo(30))],
        recipeId: 'r1',
        today: today,
        windowDays: 7,
      );
      expect(hold.held, isTrue);
      expect(hold.daysAgo, 2);
    });

    test('another dish in the log never holds this one', () {
      expect(NoRepeat.check([cooked('r2', today)], recipeId: 'r1', today: today).held, isFalse);
    });

    test('a day in the future is not history', () {
      final hold = NoRepeat.check([cooked('r1', today.add(const Duration(days: 2)))], recipeId: 'r1', today: today);
      expect(hold.held, isFalse);
    });

    test('checkAll agrees with check, dish by dish', () {
      final log = [cooked('r1', daysAgo(2)), cooked('r2', daysAgo(30))];
      final all = NoRepeat.checkAll(log, recipeIds: ['r1', 'r2', 'r3'], today: today, windowDays: 14);
      expect(all['r1']!.held, isTrue);
      expect(all['r1']!.daysAgo, 2);
      expect(all['r2']!.held, isFalse);
      expect(all['r2']!.daysAgo, 30);
      expect(all['r3']!.held, isFalse);
      expect(all['r3']!.lastCooked, isNull);
      for (final id in ['r1', 'r2', 'r3']) {
        expect(all[id]!.held, NoRepeat.check(log, recipeId: id, today: today, windowDays: 14).held, reason: id);
      }
    });

    test('it counts how many times each dish was cooked', () {
      final counts = NoRepeat.counts([cooked('r1', daysAgo(1)), cooked('r1', daysAgo(9)), cooked('r2', daysAgo(2))]);
      expect(counts['r1'], 2);
      expect(counts['r2'], 1);
      expect(counts['r3'], isNull);
    });
  });

  group('in the ranking', () {
    final recipes = [
      dish('fresh', 'مجدرة', ingredients: [ing('رز')]),
      dish('recent', 'ملوخية', ingredients: [ing('رز')]),
    ];
    final pantry = board([item('رز')]);
    final log = [cooked('recent', today.subtract(const Duration(days: 2)))];

    test('a dish cooked inside the window is pushed to the end and never cookable', () {
      final ranked = PantryMatcher.rank(recipes, pantry: pantry, cookedLog: log);
      expect([for (final m in ranked) m.recipe.id], ['fresh', 'recent']);
      final recent = ranked.last;
      expect(recent.hold.held, isTrue);
      expect(recent.verdict, MatchVerdict.cookNow, reason: 'the house can cook it – the window is what holds it');
      expect(recent.cookable, isFalse);
      expect(recent.heldBack, isTrue);
      expect([for (final m in PantryMatcher.cookNow(ranked)) m.recipe.id], ['fresh']);
      expect(PantryMatcher.tonight(ranked)!.recipe.id, 'fresh');
    });

    test('her override brings it back as a normal suggestion', () {
      final ranked = PantryMatcher.rank(
        recipes,
        pantry: pantry,
        cookedLog: log,
        constraints: const KitchenConstraints(ignoreNoRepeat: true),
      );
      expect(ranked.every((m) => m.cookable), isTrue);
      expect([for (final m in PantryMatcher.cookNow(ranked)) m.recipe.id], ['fresh', 'recent']);
    });

    test('her own window is used, so a shorter one frees it', () {
      final held = PantryMatcher.rank(recipes, pantry: pantry, cookedLog: log, constraints: const KitchenConstraints(windowDays: 14));
      expect(held.last.hold.held, isTrue);
      final free = PantryMatcher.rank(recipes, pantry: pantry, cookedLog: log, constraints: const KitchenConstraints(windowDays: 1));
      expect(free.every((m) => m.cookable), isTrue);
    });
  });
}
