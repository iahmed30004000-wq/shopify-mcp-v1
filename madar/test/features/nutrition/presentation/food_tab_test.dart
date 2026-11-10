// The «الأكل» tab of the Body planet: the day at a glance, the rating only
// where he wrote a rule, the next planned meal, and the quick log.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/interaction/interaction.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/body/body.dart';
import 'package:madar/features/nutrition/nutrition.dart';
import 'package:madar/features/nutrition/presentation/nutrition_ui.dart';

import 'nutrition_ui_harness.dart';
import 'nutrition_ui_seed.dart';

void main() {
  final ar = lookupL10n(const Locale('ar'));
  final en = lookupL10n(const Locale('en'));

  group('the day at a glance', () {
    testWidgets('a fresh install shows a warm empty state and no rating', (tester) async {
      await pumpNutritionApp(tester, home: const BodyScreen(initialTab: BodyTab.food, animateBackdrop: false));
      expect(find.byKey(const ValueKey('nutrition.empty')), findsOneWidget);
      expect(find.text(ar.nutritionEmptyTitle), findsOneWidget);
      // No rules: no rating anywhere, and an invitation instead.
      expect(find.byType(NutritionLevelPill), findsNothing);
      expect(find.byKey(const ValueKey('nutrition.noRules')), findsOneWidget);
      expect(find.text(ar.nutritionWriteFirstRule), findsOneWidget);
    });

    testWidgets("today's entries show with their times and the rating carries its reasons", (tester) async {
      final env = await pumpNutritionApp(
        tester,
        home: const BodyScreen(initialTab: BodyTab.food, animateBackdrop: false),
        seed: NutritionSeed.full,
      );
      // Three things eaten today, each one a row with its time.
      final entries = env.container.read(nutritionTodayEntriesProvider);
      expect(entries.map((e) => e.name), containsAll(<String>['بيض مقلي', 'قهوة', 'منسف']));
      for (final e in entries) {
        expect(find.byKey(ValueKey('nutrition.entry.${e.id}')), findsOneWidget);
      }
      // The rating exists (he has rules) and is shown with its reasons in
      // his own wording – never a bare verdict.
      expect(find.byKey(const ValueKey('nutrition.todayRating')), findsOneWidget);
      expect(find.textContaining('المقلي يوجع قولوني'), findsWidgets);
      expect(find.byKey(const ValueKey('nutrition.noRules')), findsNothing);
      expect(env.container.read(nutritionTodayRiskProvider)!.reasons, isNotEmpty);
    });

    testWidgets('with no rules there is no rating at all, only the invitation', (tester) async {
      final env = await pumpNutritionApp(
        tester,
        home: const BodyScreen(initialTab: BodyTab.food, animateBackdrop: false),
        seed: NutritionSeed.noRules,
      );
      expect(env.container.read(nutritionHasRatingProvider), isFalse);
      expect(env.container.read(nutritionTodayRiskProvider), isNull);
      expect(find.byKey(const ValueKey('nutrition.todayRating')), findsNothing);
      expect(find.byType(NutritionLevelPill), findsNothing);
      expect(find.byKey(const ValueKey('nutrition.noRules')), findsOneWidget);
    });

    testWidgets('the next planned meal is one tap away, in English too', (tester) async {
      final env = await pumpNutritionApp(
        tester,
        home: const BodyScreen(initialTab: BodyTab.food, animateBackdrop: false),
        seed: NutritionSeed.full,
        locale: const Locale('en'),
      );
      expect(find.byKey(const ValueKey('nutrition.nextMeal')), findsOneWidget);
      expect(find.text('Dinner'), findsWidgets);
      final before = env.container.read(nutritionTodayEntriesProvider).length;

      await tester.tap(find.byKey(const ValueKey('nutrition.nextMeal.ate')));
      await nutritionFrames(tester);

      final after = env.container.read(nutritionTodayEntriesProvider);
      expect(after.length, before + 1, reason: 'the planned dinner was logged');
      expect(after.where((e) => e.slotId != null), isNotEmpty);
      expect(find.text(en.nutritionSlotLoggedToast(BidiIsolate.isolate('Dinner'))), findsOneWidget);

      await tester.tap(find.text(en.actionUndo));
      await nutritionFrames(tester);
      expect(env.container.read(nutritionTodayEntriesProvider).length, before);
      await expireNutritionToasts(tester);
    });

    testWidgets('the tool tiles open the other food screens', (tester) async {
      final env = await pumpNutritionApp(
        tester,
        home: const BodyScreen(initialTab: BodyTab.food, animateBackdrop: false),
        seed: NutritionSeed.planOnly,
      );
      for (final (label, destination) in [
        (ar.nutritionOpenLibrary, NutritionDestination.library),
        (ar.nutritionOpenRules, NutritionDestination.rules),
        (ar.nutritionOpenInsights, NutritionDestination.insights),
      ]) {
        final tile = find.text(label);
        await bringIntoView(tester, tile);
        await tester.tap(tile.first);
        await nutritionFrames(tester, n: 4);
        expect(env.went, contains(destination), reason: label);
      }
    });
  });

  group('quick log', () {
    testWidgets('one tap on a frequent food logs it, and undo takes it back', (tester) async {
      final env = await pumpNutritionApp(
        tester,
        home: const BodyScreen(initialTab: BodyTab.food, animateBackdrop: false),
        seed: NutritionSeed.full,
      );
      final before = env.container.read(nutritionTodayEntriesProvider).length;

      await tester.tap(find.byKey(const ValueKey('nutrition.quickLog')));
      await settleNutrition(tester);
      expect(find.text(ar.nutritionLogTitle), findsOneWidget);
      expect(find.text(ar.nutritionFrequent), findsOneWidget);

      final chip = find.descendant(of: find.byType(QuickLogSheet), matching: find.text('خبز'));
      await bringIntoView(tester, chip);
      await tester.tap(chip.first);
      await nutritionFrames(tester);

      expect(env.container.read(nutritionTodayEntriesProvider).length, before + 1);
      expect(find.text(ar.nutritionLoggedToast(BidiIsolate.isolate('خبز'))), findsOneWidget);

      await tester.tap(find.text(ar.actionUndo));
      await nutritionFrames(tester);
      expect(env.container.read(nutritionTodayEntriesProvider).length, before);
      await expireNutritionToasts(tester);
    });

    testWidgets('a food he never had is created on the fly and logged', (tester) async {
      final env = await pumpNutritionApp(
        tester,
        home: const BodyScreen(initialTab: BodyTab.food, animateBackdrop: false),
        seed: NutritionSeed.full,
      );
      final foodsBefore = env.container.read(nutritionFoodsProvider).length;

      await tester.tap(find.byKey(const ValueKey('nutrition.quickLog')));
      await settleNutrition(tester);
      await tester.enterText(find.byKey(const ValueKey('nutrition.quickLog.search')), 'كبسة');
      await settleNutrition(tester);
      expect(find.byKey(const ValueKey('nutrition.quickLog.new')), findsOneWidget);
      expect(find.text(ar.nutritionNoResults), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('nutrition.quickLog.save')));
      await nutritionFrames(tester);

      final foods = env.container.read(nutritionFoodsProvider);
      expect(foods.length, foodsBefore + 1, reason: 'the new food joined his library');
      expect(foods.any((f) => f.name == 'كبسة'), isTrue);
      expect(env.container.read(nutritionTodayEntriesProvider).any((e) => e.name == 'كبسة'), isTrue);

      // Undo removes both the entry and the food it created.
      await tester.tap(find.text(ar.actionUndo));
      await nutritionFrames(tester);
      expect(env.container.read(nutritionFoodsProvider).length, foodsBefore);
      expect(env.container.read(nutritionTodayEntriesProvider).any((e) => e.name == 'كبسة'), isFalse);
      await expireNutritionToasts(tester);
    });

    testWidgets('the time defaults to now; a portion is optional', (tester) async {
      final env = await pumpNutritionApp(
        tester,
        home: const BodyScreen(initialTab: BodyTab.food, animateBackdrop: false),
        seed: NutritionSeed.full,
      );
      await tester.tap(find.byKey(const ValueKey('nutrition.quickLog')));
      await settleNutrition(tester);
      // «هلأ» until he touches the time.
      expect(find.text(ar.nutritionLogNow), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('nutrition.quickLog.search')), 'شاي');
      await tester.enterText(find.byKey(const ValueKey('nutrition.quickLog.portion')), '2');
      await settleNutrition(tester);
      await tester.tap(find.byKey(const ValueKey('nutrition.quickLog.save')));
      await nutritionFrames(tester);

      final entry = env.container.read(nutritionTodayEntriesProvider).firstWhere((e) => e.name == 'شاي');
      expect(entry.portion, 2);
      expect(entry.at.hour, env.now.hour, reason: 'logged at the default "now"');
      await expireNutritionToasts(tester);
    });

    testWidgets('the time can be changed before logging', (tester) async {
      final env = await pumpNutritionApp(
        tester,
        home: const BodyScreen(initialTab: BodyTab.food, animateBackdrop: false),
        seed: NutritionSeed.full,
      );
      await tester.tap(find.byKey(const ValueKey('nutrition.quickLog')));
      await settleNutrition(tester);
      await tester.tap(find.text(ar.nutritionLogNow));
      await settleNutrition(tester);
      // The picker is open and the time is now explicit, not «هلأ».
      expect(find.text(ar.nutritionLogNow), findsNothing);
      final clock = MadarFormatter(languageCode: 'ar').formatClock(env.now.hour, env.now.minute);
      expect(find.textContaining(clock.split(' ').first), findsWidgets);

      await tester.enterText(find.byKey(const ValueKey('nutrition.quickLog.search')), 'شاي');
      await settleNutrition(tester);
      await tester.tap(find.byKey(const ValueKey('nutrition.quickLog.save')));
      await nutritionFrames(tester);
      final entry = env.container.read(nutritionTodayEntriesProvider).firstWhere((e) => e.name == 'شاي');
      expect(entry.at.hour, env.now.hour);
      expect(entry.at.minute, env.now.minute);
      await expireNutritionToasts(tester);
    });

    testWidgets('deleting an entry offers undo', (tester) async {
      final env = await pumpNutritionApp(
        tester,
        home: const BodyScreen(initialTab: BodyTab.food, animateBackdrop: false),
        seed: NutritionSeed.full,
      );
      final entry = env.container.read(nutritionTodayEntriesProvider).first;
      final before = env.container.read(nutritionTodayEntriesProvider).length;

      final row = find.byKey(ValueKey('nutrition.entry.${entry.id}'));
      await bringIntoView(tester, row);
      tester.state<ActionableItemState>(row).delete();
      await nutritionFrames(tester);
      expect(env.container.read(nutritionTodayEntriesProvider).length, before - 1);
      expect(find.text(ar.nutritionLogDeleted(BidiIsolate.isolate(entry.name))), findsOneWidget);

      await tester.tap(find.text(ar.actionUndo));
      await nutritionFrames(tester);
      expect(env.container.read(nutritionTodayEntriesProvider).length, before);
      await expireNutritionToasts(tester);
    });
  });

  testWidgets('only the selected Body tab is in the tree (the food tab too)', (tester) async {
    await pumpNutritionApp(
      tester,
      home: const BodyScreen(animateBackdrop: false),
      seed: NutritionSeed.full,
    );
    expect(find.byKey(const ValueKey('body.today')), findsOneWidget);
    expect(find.byKey(const ValueKey('body.food')), findsNothing);
    await tester.tap(find.bySemanticsLabel(ar.nutritionTabFood).first);
    await settleNutrition(tester);
    expect(find.byKey(const ValueKey('body.food')), findsOneWidget);
    expect(find.byKey(const ValueKey('body.today')), findsNothing);
  });
}
