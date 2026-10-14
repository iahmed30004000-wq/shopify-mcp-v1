// Every «السفرة» route (Part 5) builds its screen in Arabic and English
// inside the full app (router, gates, app lock), with the app's shared-axis
// transition; `/sufra` lands on «شو نطبخ اليوم»; back leaves each page; and
// every one of the kitchen's five tables has a deep link that never
// dead-ends.
@Timeout(Duration(minutes: 4))
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/motion/transitions.dart';
import 'package:madar/core/routing/life_route_pages.dart';
import 'package:madar/core/routing/router.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/sufra/sufra.dart';

import '../../features/lock/lock_test_utils.dart';
import '../../helpers/test_app.dart';

void main() {
  group('locations', () {
    test('the kitchen has its own paths and encodes a dish id', () {
      expect(AppRoutes.sufraTonight, '/sufra/tonight');
      expect(AppRoutes.sufraPantry, '/sufra/pantry');
      expect(AppRoutes.sufraRecipes, '/sufra/recipes');
      expect(AppRoutes.sufraRules, '/sufra/rules');
      expect(AppRoutes.sufraHistory, '/sufra/history');
      expect(AppRoutes.sufraRecipeOf('r 1/2'), '/sufra/recipe/r%201%2F2');
      expect(AppRoutes.sufraRecipeOf('ملوخية'), '/sufra/recipe/%D9%85%D9%84%D9%88%D8%AE%D9%8A%D8%A9');
      // Never Money's lists or the Body's food screens.
      expect(AppRoutes.sufraRecipes, isNot(startsWith(AppRoutes.foodLibrary)));
    });

    test('the kitchen needs onboarding like every page', () {
      for (final loc in [
        AppRoutes.sufraTonight,
        AppRoutes.sufraPantry,
        AppRoutes.sufraRecipes,
        AppRoutes.sufraRules,
        AppRoutes.sufraHistory,
      ]) {
        expect(onboardingRedirect(onboarded: false, location: loc), AppRoutes.onboarding);
        expect(onboardingRedirect(onboarded: true, location: loc), isNull);
      }
    });
  });

  group('deep links', () {
    test('every kitchen table leads somewhere, with or without an id', () {
      expect(LifeRecordLinks.locationOf('pantry_items', 'p1'), AppRoutes.sufraPantry);
      expect(LifeRecordLinks.locationOf('pantry_items', null), AppRoutes.sufraPantry);
      expect(LifeRecordLinks.locationOf('recipes', 'r1'), AppRoutes.sufraRecipeOf('r1'));
      expect(LifeRecordLinks.locationOf('recipes', null), AppRoutes.sufraRecipes);
      // An ingredient line opens the dish it belongs to (the search
      // documents carry the dish's id).
      expect(
        LifeRecordLinks.locationOf('recipe_ingredients', 'i1', extra: const {'recipeId': 'r1'}),
        AppRoutes.sufraRecipeOf('r1'),
      );
      expect(LifeRecordLinks.locationOf('recipe_ingredients', 'i1'), AppRoutes.sufraRecipes);
      expect(LifeRecordLinks.locationOf('cooked_meals', 'c1'), AppRoutes.sufraHistory);
      expect(LifeRecordLinks.locationOf('kitchen_rules', 'k1'), AppRoutes.sufraRules);
      // And the tables are declared, so a search hit is never dropped.
      expect(
        LifeRecordLinks.tables,
        containsAll(['pantry_items', 'recipes', 'recipe_ingredients', 'cooked_meals', 'kitchen_rules']),
      );
      for (final table in LifeRecordLinks.tables) {
        expect(LifeRecordLinks.locationOf(table, 'x'), isNotNull, reason: table);
      }
    });
  });

  final routes = <(String, Type)>[
    (AppRoutes.sufraTonight, TonightScreen),
    (AppRoutes.sufraPantry, PantryScreen),
    (AppRoutes.sufraRecipes, RecipesScreen),
    (AppRoutes.sufraRecipeOf('missing'), RecipeScreen),
    (AppRoutes.sufraRules, KitchenRulesScreen),
    (AppRoutes.sufraHistory, CookedHistoryScreen),
  ];

  for (final lang in ['ar', 'en']) {
    group(lang, () {
      for (final (location, type) in routes) {
        testWidgets('$location builds $type', (tester) async {
          final app = await pumpMadarApp(
            tester,
            settings: AppSettings(onboarded: true, languageCode: lang),
            initialLocation: location,
            overrides: LockFixture.empty().overrides,
          );
          expect(find.byType(type), findsOneWidget);
          expect(tester.takeException(), isNull);
          expect(app.router.state.uri.toString(), location);
          expect(
            Directionality.of(tester.element(find.byType(type))),
            lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          );
          expect(ModalRoute.of(tester.element(find.byType(type)))!.settings, isA<MadarTransitionPage<void>>());
          // Nested below home: back leaves the page.
          await tester.binding.handlePopRoute();
          await settleApp(tester);
          expect(find.byType(type), findsNothing);
          await tester.pump(const Duration(seconds: 6));
        });
      }

      testWidgets('/sufra lands on what to cook today', (tester) async {
        final app = await pumpMadarApp(
          tester,
          settings: AppSettings(onboarded: true, languageCode: lang),
          initialLocation: '/sufra',
          overrides: LockFixture.empty().overrides,
        );
        expect(find.byType(TonightScreen), findsOneWidget);
        expect(app.location, AppRoutes.sufraTonight);
        await tester.pump(const Duration(seconds: 6));
      });
    });
  }
}
