// The food routes inside the real app: every screen builds in Arabic and
// English with the app's shared-axis transition, back returns where he came
// from, the record links point at the right page, and a tapped meal
// reminder lands on the food of the day.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/app/life_services.dart';
import 'package:madar/core/motion/transitions.dart';
import 'package:madar/core/notifications/notification_models.dart';
import 'package:madar/core/routing/life_route_pages.dart';
import 'package:madar/core/routing/router.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/body/body.dart';
import 'package:madar/features/nutrition/nutrition.dart';
import 'package:madar/features/nutrition/presentation/nutrition_ui.dart';

import '../../../helpers/test_app.dart';
import '../../lock/lock_test_utils.dart';

void main() {
  group('locations', () {
    test('the food screens have their own paths, and the day lives on the Body planet', () {
      expect(AppRoutes.foodLibrary, '/food/library');
      expect(AppRoutes.foodPlan, '/food/plan');
      expect(AppRoutes.foodRules, '/food/rules');
      expect(AppRoutes.foodInsights, '/food/insights');
      expect(AppRoutes.bodyOf(tab: BodyTab.food.name), '/body?tab=food');
      expect(BodyRoutePage.tabOf('food'), BodyTab.food);
    });

    test('they need onboarding like every other page', () {
      for (final loc in [AppRoutes.foodLibrary, AppRoutes.foodPlan, AppRoutes.foodRules, AppRoutes.foodInsights]) {
        expect(onboardingRedirect(onboarded: false, location: loc), AppRoutes.onboarding);
        expect(onboardingRedirect(onboarded: true, location: loc), isNull);
      }
    });

    test('a food record opens the page that owns it', () {
      expect(LifeRecordLinks.locationOf('food_logs', 'x'), AppRoutes.bodyOf(tab: BodyTab.food.name));
      expect(LifeRecordLinks.locationOf('foods', 'x'), AppRoutes.foodLibrary);
      expect(LifeRecordLinks.locationOf('meal_plans', 'x'), AppRoutes.foodPlan);
      expect(LifeRecordLinks.locationOf('meal_slots', 'x'), AppRoutes.foodPlan);
      expect(LifeRecordLinks.locationOf('meal_slot_foods', 'x'), AppRoutes.foodPlan);
      expect(LifeRecordLinks.locationOf('food_rules', 'x'), AppRoutes.foodRules);
      for (final table in ['foods', 'food_logs', 'meal_plans', 'meal_slots', 'meal_slot_foods', 'food_rules']) {
        expect(LifeRecordLinks.tables, contains(table));
      }
    });

    test('a tapped meal reminder opens the food of that day', () {
      final tap = NotificationTap(
        namespace: MealReminderIds.namespace.name,
        id: MealReminderIds.of(0, 0),
        data: const {'kind': NotificationMealReminderScheduler.kind, 'slotId': 'slot-1'},
      );
      expect(MealReminderTaps.matches(tap), isTrue);
      expect(lifeNotificationLocation(tap), AppRoutes.bodyOf(tab: BodyTab.food.name));
    });
  });

  final routes = <(String, Type)>[
    (AppRoutes.foodLibrary, FoodLibraryScreen),
    (AppRoutes.foodPlan, MealPlanScreen),
    (AppRoutes.foodRules, ConditionsScreen),
    (AppRoutes.foodInsights, NutritionInsightsScreen),
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
        });
      }

      testWidgets('/body?tab=food builds the Body planet on the food tab', (tester) async {
        await pumpMadarApp(
          tester,
          settings: AppSettings(onboarded: true, languageCode: lang),
          initialLocation: AppRoutes.bodyOf(tab: BodyTab.food.name),
          overrides: LockFixture.empty().overrides,
        );
        expect(tester.widget<BodyScreen>(find.byType(BodyScreen)).initialTab, BodyTab.food);
        expect(find.byType(FoodTab), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
