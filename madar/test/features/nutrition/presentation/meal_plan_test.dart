// The meal plan: building it (slots, weekdays, planned foods, a reminder
// per slot) and planned against eaten, with every slot status.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/interaction/interaction.dart';
import 'package:madar/features/nutrition/nutrition.dart';
import 'package:madar/features/nutrition/presentation/nutrition_ui.dart';

import 'nutrition_ui_harness.dart';
import 'nutrition_ui_seed.dart';

void main() {
  final ar = lookupL10n(const Locale('ar'));
  final en = lookupL10n(const Locale('en'));

  group('building the plan', () {
    testWidgets('no plan yet: an empty state that offers to build one', (tester) async {
      await pumpNutritionApp(tester, home: const MealPlanScreen(animateBackdrop: false));
      expect(find.byKey(const ValueKey('nutrition.plan.empty')), findsOneWidget);
      expect(find.text(ar.nutritionPlansEmptyTitle), findsOneWidget);
    });

    testWidgets('the active plan shows its meals with their times and days', (tester) async {
      final env = await pumpNutritionApp(
        tester,
        home: const MealPlanScreen(animateBackdrop: false),
        seed: NutritionSeed.planOnly,
      );
      final plan = env.container.read(nutritionActivePlanProvider);
      expect(plan.name, 'خطتي');
      expect(plan.ordered.map((s) => s.name), ['فطور', 'غدا', 'عشا']);
      for (final s in plan.ordered) {
        expect(find.byKey(ValueKey('nutrition.slot.${s.id}')), findsOneWidget);
      }
      expect(find.text(ar.nutritionActiveLabel), findsOneWidget);
      // The planned foods are chips on their slot.
      expect(find.byKey(ValueKey('nutrition.slotFood.${plan.ordered.first.foods.first.id}')), findsOneWidget);
    });

    testWidgets('the reminder switch per meal asks for the permission and plans a notice', (tester) async {
      final env = await pumpNutritionApp(
        tester,
        home: const MealPlanScreen(animateBackdrop: false),
        seed: NutritionSeed.planOnly,
      );
      final lunch = env.container.read(nutritionActivePlanProvider).ordered[1];
      expect(lunch.remind, isFalse);
      final sw = find.byKey(ValueKey('nutrition.slot.${lunch.id}.remind'));
      await bringIntoView(tester, sw);
      await tester.tap(sw);
      await nutritionFrames(tester);
      expect(
        env.container.read(nutritionActivePlanProvider).ordered[1].remind,
        isTrue,
        reason: 'the switch wrote the slot',
      );
      expect(env.reminders.permissionRequests, greaterThan(0));
      expect(find.text(ar.nutritionRemindOnToast(BidiIsolate.isolate('غدا'))), findsOneWidget);
      // Undo puts it back.
      await tester.tap(find.text(ar.actionUndo));
      await nutritionFrames(tester);
      expect(env.container.read(nutritionActivePlanProvider).ordered[1].remind, isFalse);
      await expireNutritionToasts(tester);
    });

    testWidgets('deleting a meal, and deleting the plan, both offer undo', (tester) async {
      final env = await pumpNutritionApp(
        tester,
        home: const MealPlanScreen(animateBackdrop: false),
        seed: NutritionSeed.planOnly,
      );
      final dinner = env.container.read(nutritionActivePlanProvider).ordered.last;
      final row = find.byKey(ValueKey('nutrition.slot.${dinner.id}'));
      await bringIntoView(tester, row);
      tester.state<ActionableItemState>(row).delete();
      await nutritionFrames(tester);
      expect(env.container.read(nutritionActivePlanProvider).slots.length, 2);
      expect(find.text(ar.nutritionSlotDeleted(BidiIsolate.isolate('عشا'))), findsOneWidget);
      await tester.tap(find.text(ar.actionUndo));
      await nutritionFrames(tester);
      expect(env.container.read(nutritionActivePlanProvider).slots.length, 3);
      // Its planned foods came back with it.
      expect(
        env.container.read(nutritionActivePlanProvider).ordered.last.foods,
        isNotEmpty,
        reason: 'undo restores the slot with its planned foods',
      );
      await expireNutritionToasts(tester);

      final plan = env.container.read(nutritionActivePlanProvider);
      final del = find.byKey(ValueKey('nutrition.plan.delete.${plan.id}'));
      await bringIntoView(tester, del);
      await tester.tap(del);
      await nutritionFrames(tester);
      expect(env.container.read(nutritionPlansProvider), isEmpty);
      expect(find.text(ar.nutritionPlanDeleted(BidiIsolate.isolate('خطتي'))), findsOneWidget);
      await tester.tap(find.text(ar.actionUndo));
      await nutritionFrames(tester);
      expect(env.container.read(nutritionPlansProvider), hasLength(1));
      expect(env.container.read(nutritionActivePlanProvider).slots, hasLength(3));
      await expireNutritionToasts(tester);
    });

    testWidgets('a plan can be made a draft and back, and duplicated', (tester) async {
      final env = await pumpNutritionApp(
        tester,
        home: const MealPlanScreen(animateBackdrop: false),
        seed: NutritionSeed.planOnly,
      );
      final plan = env.container.read(nutritionActivePlanProvider);
      final toggle = find.byKey(ValueKey('nutrition.plan.activate.${plan.id}'));
      await bringIntoView(tester, toggle);
      await tester.tap(toggle);
      await nutritionFrames(tester);
      expect(env.container.read(nutritionActivePlanProvider).isEmpty, isTrue, reason: 'now a draft');
      await tester.tap(find.text(ar.actionUndo));
      await nutritionFrames(tester);
      expect(env.container.read(nutritionActivePlanProvider).id, plan.id);
      await expireNutritionToasts(tester);

      final dup = find.text(ar.nutritionDuplicate);
      await bringIntoView(tester, dup);
      await tester.tap(dup);
      await nutritionFrames(tester);
      expect(env.container.read(nutritionPlansProvider), hasLength(2));
      // The copy is a draft, with the same meals.
      final copy = env.container.read(nutritionPlansProvider).firstWhere((p) => p.id != plan.id);
      expect(copy.active, isFalse);
      expect(copy.slots, hasLength(3));
      await expireNutritionToasts(tester);
    });
  });

  group('planned against eaten', () {
    Future<NutritionTestEnv> openCompare(WidgetTester tester, {Locale locale = const Locale('ar')}) async {
      final env = await pumpNutritionApp(
        tester,
        home: const MealPlanScreen(initialTab: MealPlanTab.compare, animateBackdrop: false),
        seed: NutritionSeed.full,
        locale: locale,
      );
      return env;
    }

    testWidgets("today shows on time, late and still to come, plus what was off plan", (tester) async {
      final env = await openCompare(tester);
      final today = env.container.read(nutritionTodayPlanProvider);
      expect(today.onTime, 1, reason: 'breakfast at 08:10 for an 08:00 meal');
      expect(today.late, 1, reason: 'lunch at 14:05 for a 13:00 meal');
      expect(today.pending, 1, reason: 'dinner is still ahead');
      expect(today.unplanned.map((e) => e.name), ['قهوة']);

      expect(find.text(ar.nutritionStatusOnTime), findsWidgets);
      expect(find.text(ar.nutritionStatusLate), findsWidgets);
      expect(find.text(ar.nutritionStatusPending), findsWidgets);
      // The day's adherence is stated, never a bare zero.
      expect(find.textContaining(ar.nutritionAdherence('').replaceAll('{percent}', '').trim().split(' ').first), findsWidgets);
      // And the coffee shows under "off plan".
      expect(find.text(ar.nutritionUnplannedTitle), findsOneWidget);
    });

    testWidgets('yesterday shows a swapped meal and a missed one', (tester) async {
      final env = await openCompare(tester);
      final yesterday = env.container.read(
        nutritionDayPlanProvider(DateTime(env.now.year, env.now.month, env.now.day - 1)),
      );
      expect(yesterday.swapped, 1, reason: 'dates instead of the planned breakfast');
      expect(yesterday.skipped, 1, reason: 'lunch was missed');
      expect(yesterday.onTime, 1, reason: 'dinner was eaten near its time');

      // The week strip opens that day.
      final week = env.container.read(nutritionWeekPlanProvider);
      expect(week, hasLength(7));
      final cell = find.bySemanticsLabel(RegExp(RegExp.escape(ar.nutritionStatusSwapped)));
      expect(cell, findsNothing, reason: 'the strip shows adherence, not statuses');
      await tester.tap(find.byType(MealPlanScreen).first, warnIfMissed: false);
      await settleNutrition(tester);
    });

    testWidgets('a meal still to come can be logged as planned from the day view', (tester) async {
      final env = await openCompare(tester, locale: const Locale('en'));
      final dinner = env.container.read(nutritionTodayPlanProvider).next!;
      final button = find.byKey(ValueKey('nutrition.slotOutcome.${dinner.slot.id}.ate'));
      await bringIntoView(tester, button);
      await tester.tap(button);
      await nutritionFrames(tester);
      expect(env.container.read(nutritionTodayPlanProvider).onTime, 2);
      expect(find.text(en.nutritionSlotLoggedToast(BidiIsolate.isolate('Dinner'))), findsOneWidget);
      await tester.tap(find.text(en.actionUndo));
      await nutritionFrames(tester);
      expect(env.container.read(nutritionTodayPlanProvider).pending, 1);
      await expireNutritionToasts(tester);
    });

    testWidgets('without an active plan the comparison says so instead of showing zeros', (tester) async {
      await pumpNutritionApp(
        tester,
        home: const MealPlanScreen(initialTab: MealPlanTab.compare, animateBackdrop: false),
        seed: NutritionSeed.libraryOnly,
      );
      expect(find.byKey(const ValueKey('nutrition.compare.noPlan')), findsOneWidget);
      expect(find.text(ar.nutritionCompareNoPlanBody), findsOneWidget);
    });
  });
}
