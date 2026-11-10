// «السفرة»'s write flows inside the real app (router, gates, app lock), in
// Arabic and English: adding to the pantry, a «استعملت منها» that cannot be
// converted, what is low becoming the list of the house, the missing
// becoming the dish's own list, the alias that turns a refusal into an
// answer, cooking a dish (logged, and only what was certain deducted), and
// a photo she adds becoming Madar's own copy.
//
// Split from `sufra_screens_test.dart` so one test process stays small:
// every one of these pumps the whole app.
@Timeout(Duration(minutes: 4))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/features/sufra/sufra.dart';

import 'sufra_screen_harness.dart';

L10n _l(String lang) => lookupL10n(Locale(lang));

/// The kitchen's own words, read off a screen that is on the tree – so a
/// test asserts the sentence `SufraTexts` writes (her digits, her words
/// bidi-isolated) and never a hand-made one.
SufraTexts _tx(WidgetTester tester, Type screen) => SufraTexts.of(tester.element(find.byType(screen)));

/// Scrolls the screen until [finder] is on it and settled, then leaves it
/// where a tap lands on it (a kitchen screen is a lazy list and the
/// floating button sits over its last rows).
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  final scrollable = find.byType(Scrollable).first;
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 220, scrollable: scrollable);
  }
  await tester.ensureVisible(finder);
  await sufraFrames(tester, n: 4);
  await tester.drag(scrollable, const Offset(0, -80));
  await sufraFrames(tester, n: 4);
}

/// Waits until [ready] holds, bounded by the database round trips it is
/// really waiting for – never by a fixed number of frames.
Future<void> _until(WidgetTester tester, String what, bool Function() ready, {int roundTrips = 40}) async {
  for (var i = 0; i < roundTrips && !ready(); i++) {
    await sufraFrames(tester, n: 3);
  }
  expect(ready(), isTrue, reason: 'waited for $what');
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
    await initializeDateFormatting('en');
  });

  for (final lang in ['ar', 'en']) {
    final l = _l(lang);

    group(lang, () {
      testWidgets('she adds something to the house', (tester) async {
        final app = await pumpSufra(tester, location: AppRoutes.sufraPantry, seed: SufraSeed.empty, lang: lang);
        await tester.tap(find.byKey(const ValueKey('sufra.pantry.add')));
        await sufraFrames(tester, n: 12);
        await tester.enterText(find.byType(TextField).first, 'عدس');
        await sufraFrames(tester, n: 6);
        // The sheet's save button.
        await tester.tap(find.text(l.actionSave).last);
        await _until(tester, 'the item to be stored', () => find.text('عدس').evaluate().isNotEmpty);
        final rows = await tester.runAsync(() => Repositories(app.db).pantryItems.getAll());
        expect(rows!.map((r) => r.name), ['عدس']);
        expect(find.text('عدس'), findsWidgets);
        await letToastsExpire(tester);
      });

      testWidgets('«استعملت منها» that cannot be converted says so and writes nothing', (tester) async {
        final app = await pumpSufra(tester, location: AppRoutes.sufraPantry, seed: SufraSeed.house, lang: lang);
        final before = (await tester.runAsync(() => Repositories(app.db).pantryItems.byId(riceId)))!;
        expect(before.quantity, 2.5);
        // «رز» is in the house in kilos; she used two cups of it.
        await tester.longPress(find.byKey(const ValueKey('sufra.pantry.item.$riceId')));
        await sufraFrames(tester, n: 12);
        await tester.tap(find.text(l.sufraUsedSome).last);
        await sufraFrames(tester, n: 12);
        await tester.enterText(find.byType(TextField).first, '2');
        await tester.enterText(find.byType(TextField).at(1), 'كوب');
        await sufraFrames(tester, n: 6);
        await tester.tap(find.text(l.actionSave).last);
        await sufraFrames(tester, n: 16);
        // The one sentence that matters: it did not happen, and why.
        final tx = _tx(tester, PantryScreen);
        expect(find.text(l.sufraCouldNotDeductUnit(tx.name('رز'), tx.name('كيلو'))), findsOneWidget);
        final after = (await tester.runAsync(() => Repositories(app.db).pantryItems.byId(riceId)))!;
        expect(after.quantity, 2.5, reason: 'nothing was written');
        await letToastsExpire(tester);
      });

      testWidgets('what is low becomes the list of the house', (tester) async {
        final app = await pumpSufra(tester, location: AppRoutes.sufraPantry, seed: SufraSeed.house, lang: lang);
        await tester.tap(find.byKey(const ValueKey('sufra.pantry.toList')));
        await _until(tester, 'the list to open', () => app.location != AppRoutes.sufraPantry);
        final lists = await tester.runAsync(() => Repositories(app.db).recordLists.getAll());
        expect(lists, hasLength(1));
        expect(lists!.single.hostTable, 'pantry');
        expect(lists.single.hostId, 'house');
        expect(lists.single.name, l.sufraHouseListName);
        final items = await tester.runAsync(() => Repositories(app.db).recordListItems.getAll());
        // Finished, low, and the staple that finished – never the thing
        // whose date has passed (that is a decision to throw out).
        expect(items!.map((i) => i.title), containsAll(['زيت', 'سكر']));
        expect(items.map((i) => i.title), isNot(contains('لبن')));
        // Part 3b's own screen opened on it.
        expect(app.location, AppRoutes.recordListOf(lists.single.id));
        await letToastsExpire(tester);
      });

      testWidgets('the missing becomes the dish\'s own list', (tester) async {
        final app = await pumpSufra(tester, location: AppRoutes.sufraTonight, seed: SufraSeed.nearly, lang: lang);
        await _reveal(tester, find.byKey(const ValueKey('sufra.dish.$mloukhiehId.missing')));
        await tester.tap(find.byKey(const ValueKey('sufra.dish.$mloukhiehId.missing')));
        await _until(tester, 'the dish\'s list to open', () => app.location != AppRoutes.sufraTonight);
        final lists = await tester.runAsync(() => Repositories(app.db).recordLists.getAll());
        expect(lists, hasLength(1));
        expect(lists!.single.hostTable, 'recipes');
        expect(lists.single.hostId, mloukhiehId);
        final items = await tester.runAsync(() => Repositories(app.db).recordListItems.getAll());
        expect(items!.map((i) => i.title), ['لحمة']);
        expect(items.single.quantity, 0.5);
        expect(items.single.unit, 'كيلو');
        expect(app.location, AppRoutes.recordListOf(lists.single.id));
        await letToastsExpire(tester);
      });

      testWidgets('the alias on the dish\'s own screen turns a refusal into an answer', (tester) async {
        final app = await pumpSufra(
          tester,
          location: AppRoutes.sufraRecipeOf(ambiguousDishId),
          seed: SufraSeed.ambiguous,
          lang: lang,
        );
        expect(find.text(l.sufraUnsureNote), findsWidgets);
        final chip = find.byKey(const ValueKey('sufra.fix.alias.i-$ambiguousDishId-0.p-rice-basmati'));
        expect(chip, findsOneWidget);
        await _reveal(tester, chip);
        await tester.tap(chip);
        await _until(
          tester,
          'the alias to settle the dish',
          () => find.text(l.sufraVerdictCookNow).evaluate().isNotEmpty,
        );
        final row = (await tester.runAsync(() => Repositories(app.db).pantryItems.byId('p-rice-basmati')))!;
        expect(row.aliases, contains('رز'));
        // And now the dish is one she can cook.
        expect(find.text(l.sufraVerdictCookNow), findsWidgets);
        await letToastsExpire(tester);
      });

      testWidgets('cooking logs it and takes out only what was certain', (tester) async {
        final app = await pumpSufra(tester, location: AppRoutes.sufraTonight, seed: SufraSeed.cookNow, lang: lang);
        final cook = find.byKey(const ValueKey('sufra.dish.$mujaddaraId.cook'));
        await _reveal(tester, cook);
        await tester.tap(cook);
        await _until(
          tester,
          'the cooking to be logged',
          () => find.byKey(const ValueKey('sufra.dish.$mujaddaraId.cook')).evaluate().isEmpty,
        );
        final log = await tester.runAsync(() => Repositories(app.db).cookedMeals.getAll());
        expect(log, hasLength(1));
        expect(log!.single.recipeId, mujaddaraId);
        expect(log.single.name, 'مجدرة');
        final rice = (await tester.runAsync(() => Repositories(app.db).pantryItems.byId(riceId)))!;
        final tomato = (await tester.runAsync(() => Repositories(app.db).pantryItems.byId(tomatoId)))!;
        expect(rice.quantity, 1.5, reason: 'a kilo of rice came out');
        expect(tomato.quantity, 1.0, reason: 'two tomatoes came out');
        // The thing it could not compare is untouched.
        final sugar = (await tester.runAsync(() => Repositories(app.db).pantryItems.byId(sugarId)))!;
        expect(sugar.quantity, 0.5);
        await letToastsExpire(tester);
      });
    });
  }

  testWidgets('a photo she adds becomes Madar\'s own copy, and the dish takes it with it', (tester) async {
    final store = photoStore();
    final app = await pumpSufra(
      tester,
      location: AppRoutes.sufraRecipeOf(mujaddaraId),
      seed: SufraSeed.cookNow,
      overrides: store.overrides,
    );
    await tester.tap(find.byKey(const ValueKey('sufra.recipe.addPhoto')));
    await _until(tester, 'the photo to be copied in', () => store.folder.listSync().isNotEmpty);
    final row = (await tester.runAsync(() => Repositories(app.db).recipes.byId(mujaddaraId)))!;
    expect(row.photos, hasLength(1));
    expect(row.photos.single, endsWith('.png'));
    expect(row.photos.single, isNot(contains('/')), reason: 'a file name, never a path into the gallery');
    final copied = store.folder.listSync().whereType<File>().toList();
    expect(copied, hasLength(1));
    await letToastsExpire(tester);
  });
}
