// The food library: his own words as a filter, favourite, archive, edit
// and delete – every destructive action with an undo.
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

  testWidgets('an empty library invites him to add his first food', (tester) async {
    await pumpNutritionApp(tester, home: const FoodLibraryScreen(animateBackdrop: false));
    expect(find.byKey(const ValueKey('nutrition.library.empty')), findsOneWidget);
    expect(find.text(ar.nutritionLibraryEmptyTitle), findsOneWidget);
  });

  testWidgets('his foods and his tag vocabulary show, in English too', (tester) async {
    await pumpNutritionApp(
      tester,
      home: const FoodLibraryScreen(animateBackdrop: false),
      seed: NutritionSeed.libraryOnly,
      locale: const Locale('en'),
    );
    expect(find.text('Dates'), findsWidgets);
    expect(find.text(en.nutritionTagsTitle), findsOneWidget);
    // The vocabulary comes from his foods, not from us.
    expect(find.byKey(const ValueKey('nutrition.library.tag.fried')), findsOneWidget);
    expect(find.byKey(const ValueKey('nutrition.library.tag.all')), findsOneWidget);
  });

  testWidgets('a tag narrows the list to the foods carrying it', (tester) async {
    final env = await pumpNutritionApp(
      tester,
      home: const FoodLibraryScreen(animateBackdrop: false),
      seed: NutritionSeed.libraryOnly,
    );
    final eggs = env.container.read(nutritionFoodsProvider).firstWhere((f) => f.name == 'بيض مقلي');
    final bread = env.container.read(nutritionFoodsProvider).firstWhere((f) => f.name == 'خبز');
    expect(find.byKey(ValueKey('nutrition.food.${bread.id}')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nutrition.library.tag.مقلي')));
    await settleNutrition(tester);
    expect(find.byKey(ValueKey('nutrition.food.${eggs.id}')), findsOneWidget);
    expect(find.byKey(ValueKey('nutrition.food.${bread.id}')), findsNothing);

    // And back to everything.
    await tester.tap(find.byKey(const ValueKey('nutrition.library.tag.all')));
    await settleNutrition(tester);
    expect(find.byKey(ValueKey('nutrition.food.${bread.id}')), findsOneWidget);
  });

  testWidgets('favourite, archive and delete each offer an undo', (tester) async {
    final env = await pumpNutritionApp(
      tester,
      home: const FoodLibraryScreen(animateBackdrop: false),
      seed: NutritionSeed.libraryOnly,
    );
    Food foodNamed(String name) => env.container.read(nutritionFoodsProvider).firstWhere((f) => f.name == name);
    final bread = foodNamed('خبز');

    // Favourite, from the swipe tray.
    final row = find.byKey(ValueKey('nutrition.food.${bread.id}'));
    await bringIntoView(tester, row);
    tester.state<ActionableItemState>(row).openTray();
    await settleNutrition(tester);
    await tester.tap(find.bySemanticsLabel(ar.nutritionFavorite).first);
    await nutritionFrames(tester);
    expect(foodNamed('خبز').favorite, isTrue);
    expect(find.text(ar.nutritionFavoritedToast(BidiIsolate.isolate('خبز'))), findsOneWidget);
    await tester.tap(find.text(ar.actionUndo));
    await nutritionFrames(tester);
    expect(foodNamed('خبز').favorite, isFalse);
    await expireNutritionToasts(tester);

    // Archive: the food stays, the picker stops offering it.
    final row2 = find.byKey(ValueKey('nutrition.food.${bread.id}'));
    await bringIntoView(tester, row2);
    tester.state<ActionableItemState>(row2).openTray();
    await settleNutrition(tester);
    await tester.tap(find.bySemanticsLabel(ar.nutritionArchive).first);
    await nutritionFrames(tester);
    expect(foodNamed('خبز').archived, isTrue);
    expect(find.byKey(ValueKey('nutrition.food.${bread.id}')), findsNothing, reason: 'hidden until the archive is shown');
    await tester.tap(find.text(ar.actionUndo));
    await nutritionFrames(tester);
    expect(foodNamed('خبز').archived, isFalse);
    await expireNutritionToasts(tester);

    // Delete, from the long-press menu's own action.
    final row3 = find.byKey(ValueKey('nutrition.food.${bread.id}'));
    await bringIntoView(tester, row3);
    tester.state<ActionableItemState>(row3).delete();
    await nutritionFrames(tester);
    expect(env.container.read(nutritionFoodsProvider).any((f) => f.name == 'خبز'), isFalse);
    expect(find.text(ar.nutritionFoodDeleted(BidiIsolate.isolate('خبز'))), findsOneWidget);
    await tester.tap(find.text(ar.actionUndo));
    await nutritionFrames(tester);
    expect(env.container.read(nutritionFoodsProvider).any((f) => f.name == 'خبز'), isTrue);
    await expireNutritionToasts(tester);
  });

  testWidgets('the archive switch brings archived foods back into view', (tester) async {
    final env = await pumpNutritionApp(
      tester,
      home: const FoodLibraryScreen(animateBackdrop: false),
      seed: NutritionSeed.libraryOnly,
    );
    final bread = env.container.read(nutritionFoodsProvider).firstWhere((f) => f.name == 'خبز');
    await nutritionWork(tester, () async {
      final row = await env.repos.foods.byId(bread.id);
      await env.service().setFoodArchived(row!, true);
    });
    expect(find.byKey(ValueKey('nutrition.food.${bread.id}')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('nutrition.library.archivedSwitch')));
    await settleNutrition(tester);
    final row = find.byKey(ValueKey('nutrition.food.${bread.id}'));
    expect(row, findsOneWidget);
    await bringIntoView(tester, row);
    expect(find.descendant(of: row, matching: find.text(ar.nutritionArchivedLabel)), findsOneWidget);
  });

  testWidgets('adding a food writes his words onto it', (tester) async {
    final env = await pumpNutritionApp(
      tester,
      home: const FoodLibraryScreen(animateBackdrop: false),
      seed: NutritionSeed.libraryOnly,
    );
    await tester.tap(find.byKey(const ValueKey('nutrition.library.fab')));
    await settleNutrition(tester);
    expect(find.text(ar.nutritionAddFood), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'شوربة عدس');
    await settleNutrition(tester);
    await tester.tap(find.widgetWithText(SheetButton, ar.nutritionSave).first);
    await nutritionFrames(tester);
    expect(env.container.read(nutritionFoodsProvider).any((f) => f.name == 'شوربة عدس'), isTrue);
    await expireNutritionToasts(tester);
  });
}
