// «السفرة»'s screens inside the real app (router, gates, app lock), in
// Arabic and English: the empty world, the pantry's attention list in the
// right order, a dish she can cook now, a near dish naming exactly what is
// missing, each of the three refusals shown as honesty (and the dish never
// offered as cookable), the held dish with the override, and a hard rule
// blocking next to a soft rule explaining.
//
// The writes are in `sufra_flows_test.dart`, so one test process stays
// small: every test in here pumps the whole app.
@Timeout(Duration(minutes: 4))
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/features/sufra/sufra.dart';

import 'sufra_screen_harness.dart';

L10n _l(String lang) => lookupL10n(Locale(lang));

/// The one dish card on screen.
Finder _dish(String recipeId) => find.byKey(ValueKey('sufra.dish.$recipeId'));

/// Scrolls the screen until [finder] is built and visible (a kitchen
/// screen is a lazy list: a group far below the fold is not in the tree
/// yet).
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 220, scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(finder);
  await sufraFrames(tester, n: 4);
}

/// The kitchen's own words, read off a screen that is on the tree – so a
/// test asserts the sentence `SufraTexts` writes (her digits, her words
/// bidi-isolated) and never a hand-made one.
SufraTexts _tx(WidgetTester tester, Type screen) => SufraTexts.of(tester.element(find.byType(screen)));

void main() {
  setUpAll(() async {
    // A held dish prints a date («بترجع بالاقتراحات يوم …»).
    await initializeDateFormatting('ar');
    await initializeDateFormatting('en');
  });

  for (final lang in ['ar', 'en']) {
    final l = _l(lang);

    group(lang, () {
      // ------------------------------------------------- the empty world

      testWidgets('a fresh install has the world and an empty kitchen', (tester) async {
        final app = await pumpSufra(tester, location: AppRoutes.sufraTonight, seed: SufraSeed.empty, lang: lang);
        // The world is seeded, the kitchen is not.
        final planets = await tester.runAsync(() => Repositories(app.db).planets.getAll());
        expect(planets!.map((p) => p.key), contains('sufra'));
        expect(await tester.runAsync(() => Repositories(app.db).pantryItems.getAll()), isEmpty);
        expect(await tester.runAsync(() => Repositories(app.db).recipes.getAll()), isEmpty);
        // A warm empty state, never an invented dish.
        expect(find.text(l.sufraSuggestionsEmptyTitle), findsWidgets);
        expect(find.byKey(const ValueKey('sufra.tonight.empty')), findsOneWidget);
        expect(find.text(l.sufraAttentionNone), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      testWidgets('the empty pantry invites her to add the first thing', (tester) async {
        await pumpSufra(tester, location: AppRoutes.sufraPantry, seed: SufraSeed.empty, lang: lang);
        expect(find.byKey(const ValueKey('sufra.pantry.empty')), findsOneWidget);
        expect(find.text(l.sufraPantryEmptyTitle), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      // --------------------------------------------------- the pantry

      testWidgets('the attention list is worst first', (tester) async {
        await pumpSufra(tester, location: AppRoutes.sufraPantry, seed: SufraSeed.house, lang: lang);
        final tx = _tx(tester, PantryScreen);
        Finder group(PantryState state, String name) =>
            find.text(l.sufraAttentionGroup(tx.state(state), tx.name(name)));
        final out = group(PantryState.out, 'زيت');
        final expired = group(PantryState.expired, 'لبن');
        final low = group(PantryState.low, 'سكر');
        final soon = group(PantryState.expiringSoon, 'خبز');
        for (final f in [out, expired, low, soon]) {
          expect(f, findsOneWidget, reason: 'a group of the attention list is missing');
        }
        final ys = [
          for (final f in [out, expired, low, soon]) tester.getTopLeft(f).dy,
        ];
        expect(ys, orderedEquals([...ys]..sort()), reason: 'out, then expired, then low, then the date coming up');
        // Her places group the rest, in the order she first used them.
        expect(find.text(tx.name('خزانة المونة')), findsWidgets);
        expect(find.text(tx.name('البراد')), findsWidgets);
      });

      // ------------------------------------------------ what to cook now

      testWidgets('a dish she can cook now says so and offers one tap', (tester) async {
        await pumpSufra(tester, location: AppRoutes.sufraTonight, seed: SufraSeed.cookNow, lang: lang);
        await _reveal(tester, find.text(l.sufraCookNowTitle));
        expect(find.text(l.sufraCookNowTitle), findsOneWidget);
        expect(_dish(mujaddaraId), findsOneWidget);
        expect(find.text(l.sufraVerdictCookNow), findsWidgets);
        expect(find.byKey(const ValueKey('sufra.dish.$mujaddaraId.cook')), findsOneWidget);
      });

      testWidgets('a near dish names exactly what is missing, and how much', (tester) async {
        await pumpSufra(tester, location: AppRoutes.sufraTonight, seed: SufraSeed.nearly, lang: lang);
        await _reveal(tester, find.text(l.sufraNearlyTitle));
        expect(find.text(l.sufraNearlyTitle), findsOneWidget);
        expect(_dish(mloukhiehId), findsOneWidget);
        // «ناقص ٠٫٥ كيلو لحمة» – her amount, in her digits.
        final tx = _tx(tester, TonightScreen);
        expect(
          find.text(tx.fmt.localizeDigits(l.sufraMissingLine(tx.amount(0.5, 'كيلو'), tx.name('لحمة')))),
          findsOneWidget,
        );
        // Nothing offers to cook it.
        expect(find.byKey(const ValueKey('sufra.dish.$mloukhiehId.cook')), findsNothing);
        expect(find.byKey(const ValueKey('sufra.dish.$mloukhiehId.missing')), findsOneWidget);
      });

      // ------------------------------------- the three refusals, as honesty

      testWidgets('a cup against a kilo is a refusal with a way out, never a dish she can cook', (tester) async {
        await pumpSufra(tester, location: AppRoutes.sufraTonight, seed: SufraSeed.unknownUnit, lang: lang);
        await _reveal(tester, find.text(l.sufraUnsureTitle));
        expect(find.text(l.sufraUnsureTitle), findsOneWidget);
        expect(find.text(l.sufraVerdictUnsure), findsWidgets);
        expect(find.text(l.sufraUnsureNote), findsWidgets);
        final tx = _tx(tester, TonightScreen);
        expect(
          find.text(tx.fmt.localizeDigits(l.sufraUnknownUnitLine(tx.amount(2, 'كوب'), tx.name('رز'), tx.name('كيلو')))),
          findsOneWidget,
        );
        // Never cookable, and never in the «cook now» group.
        expect(find.byKey(const ValueKey('sufra.dish.$cupsId.cook')), findsNothing);
        expect(find.text(l.sufraCookNowTitle), findsNothing);
      });

      testWidgets('an amount she never typed is a refusal, never "enough"', (tester) async {
        await pumpSufra(tester, location: AppRoutes.sufraTonight, seed: SufraSeed.unknownAmount, lang: lang);
        await _reveal(tester, find.text(l.sufraUnsureTitle));
        expect(find.text(l.sufraUnsureTitle), findsOneWidget);
        expect(find.text(l.sufraUnknownAmountLine(_tx(tester, TonightScreen).name('زعتر'))), findsOneWidget);
        expect(find.byKey(const ValueKey('sufra.dish.$zaatarDishId.cook')), findsNothing);
        expect(find.text(l.sufraCookNowTitle), findsNothing);
      });

      testWidgets('two things with one name are named, with the alias that settles it', (tester) async {
        await pumpSufra(tester, location: AppRoutes.sufraTonight, seed: SufraSeed.ambiguous, lang: lang);
        await _reveal(tester, find.text(l.sufraUnsureTitle));
        expect(find.text(l.sufraUnsureTitle), findsOneWidget);
        final tx = _tx(tester, TonightScreen);
        expect(
          find.text(
            l.sufraAmbiguousLine(tx.name('رز'), [tx.name('رز بسمتي'), tx.name('رز مصري')].join(l.recordListSeparator)),
          ),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('sufra.dish.$ambiguousDishId.cook')), findsNothing);
        expect(find.text(l.sufraCookNowTitle), findsNothing);
      });

      // ------------------------------------------------- «بدون تكرار»

      testWidgets('a held dish says when she cooked it and when it is back, and the override shows it', (tester) async {
        await pumpSufra(tester, location: AppRoutes.sufraTonight, seed: SufraSeed.held, lang: lang);
        await _reveal(tester, find.text(l.sufraHeldTitle));
        expect(find.text(l.sufraHeldTitle), findsOneWidget);
        expect(_dish(mujaddaraId), findsOneWidget);
        // It is not among the dishes she can cook.
        expect(find.text(l.sufraCookNowTitle), findsNothing);
        expect(find.byKey(const ValueKey('sufra.dish.$mujaddaraId.cook')), findsNothing);
        // «طبختيها قبل يومين · بترجع بالاقتراحات يوم …»
        final tx = _tx(tester, TonightScreen);
        expect(find.textContaining(tx.fmt.localizeDigits(l.sufraHeldByWindow(2))), findsOneWidget);
        // Her override, right above the dishes the window is holding.
        final toggle = find.byKey(const ValueKey('sufra.tonight.showRepeats.inline'));
        await _reveal(tester, toggle);
        await tester.tap(toggle);
        await sufraFrames(tester, n: 16);
        expect(find.text(l.sufraCookNowTitle), findsOneWidget);
        expect(find.byKey(const ValueKey('sufra.dish.$mujaddaraId.cook')), findsOneWidget);
      });

      // ------------------------------------------------------ the cooking

      // ---------------------------------------------------- her constraints

      testWidgets('a hard rule blocks and says whose, a soft rule only explains', (tester) async {
        await pumpSufra(tester, location: AppRoutes.sufraTonight, seed: SufraSeed.rules, lang: lang);
        // «مجدرة» has بندورة, which أحمد is allergic to: not on offer.
        // The group sits last, under everything she can cook – and the
        // dish's own line says «ممنوعة اليوم» instead of a verdict about
        // the house, so nothing on it reads as "you can cook this".
        final blocked = find.text(l.sufraBlockedTitle);
        await _reveal(tester, blocked.first);
        expect(blocked, findsNWidgets(2));
        expect(find.text(l.sufraVerdictCookNow), findsOneWidget, reason: 'only «مقلوبة» says it');
        final tx = _tx(tester, TonightScreen);
        await _reveal(tester, find.text(l.sufraBreachAllergy(tx.name('بندورة'), tx.name('أحمد'))));
        expect(find.text(l.sufraBreachAllergy(tx.name('بندورة'), tx.name('أحمد'))), findsOneWidget);
        expect(find.byKey(const ValueKey('sufra.dish.$mujaddaraId.cook')), findsNothing);
        // «مقلوبة» only has رز, which she would rather avoid: still there,
        // with the reason.
        expect(_dish(maqloubaId), findsOneWidget);
        expect(find.text(l.sufraBreachAvoid(tx.name('رز'))), findsWidgets);
      });

      testWidgets('her constraints screen explains hard and soft in her own words', (tester) async {
        await pumpSufra(tester, location: AppRoutes.sufraRules, seed: SufraSeed.rules, lang: lang);
        expect(find.text(l.sufraRuleHardNote), findsWidgets);
        expect(find.text('بندورة'), findsWidgets);
        expect(find.byKey(const ValueKey('sufra.rule.k-allergy')), findsOneWidget);
        expect(find.byKey(const ValueKey('sufra.rule.k-avoid')), findsOneWidget);
        expect(find.byKey(const ValueKey('sufra.settings')), findsOneWidget);
      });
    });
  }

  // -------------------------------------------------- her dishes and photos

  testWidgets('a dish that arrived from an answer says so', (tester) async {
    await pumpSufra(tester, location: AppRoutes.sufraRecipes, seed: SufraSeed.full);
    final l = _l('ar');
    expect(find.textContaining(l.sufraSourceImported), findsWidgets);
    expect(find.textContaining('خالتي'), findsWidgets);
  });

  testWidgets('the kitchen never shows anything of Health or Money', (tester) async {
    final app = await pumpSufra(tester, location: AppRoutes.sufraTonight, seed: SufraSeed.full);
    // Nothing of his is even read: the board's own tables only.
    expect(find.textContaining('د.أ'), findsNothing);
    expect(app.location, AppRoutes.sufraTonight);
  });
}
