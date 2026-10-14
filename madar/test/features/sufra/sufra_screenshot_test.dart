// Visual critic pass for «السفرة» (Part 5): the real screens with the real
// fonts and shaders, in Arabic and English, across Lapis, Pearl and Aurora,
// plus text scale 1.3. PNGs land in madar/screenshots/sufra/.
//
//   flutter test --tags screenshot test/features/sufra/sufra_screenshot_test.dart
@Tags(['screenshot'])
@Timeout(Duration(minutes: 20))
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/features/sufra/sufra.dart';

import '../../helpers/screenshot_harness.dart';
import 'sufra_screen_harness.dart';

const _dir = 'sufra';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
    await initializeDateFormatting('en');
  });

  Future<void> shot(
    WidgetTester tester,
    String name,
    Widget home, {
    MadarThemeId theme = MadarThemeId.lapis,
    Locale locale = const Locale('ar'),
    SufraSeed seed = SufraSeed.full,
    double textScale = 1,
    Future<void> Function(WidgetTester tester)? beforeCapture,
  }) async {
    final (app, _) = await buildSufraApp(
      tester,
      home: home,
      theme: theme,
      locale: locale,
      seed: seed,
      textScale: textScale,
    );
    await captureScreen(
      tester,
      app,
      '$_dir/$name',
      beforeCapture: (tester) async {
        for (var i = 0; i < 8; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
          await tester.pump(const Duration(milliseconds: 50));
        }
        if (beforeCapture != null) await beforeCapture(tester);
      },
    );
  }

  // --------------------------------------------------- «شو نطبخ اليوم»

  testWidgets('what to cook today – Arabic, Lapis', (tester) async {
    await shot(tester, 'tonight_ar_lapis', const TonightScreen(animateBackdrop: false));
  });

  testWidgets('what to cook today – English, Pearl', (tester) async {
    await shot(
      tester,
      'tonight_en_pearl',
      const TonightScreen(animateBackdrop: false),
      theme: MadarThemeId.pearl,
      locale: const Locale('en'),
    );
  });

  testWidgets('what to cook today – Arabic, Aurora, text scale 1.3', (tester) async {
    await shot(
      tester,
      'tonight_ar_aurora_x13',
      const TonightScreen(animateBackdrop: false),
      theme: MadarThemeId.aurora,
      textScale: 1.3,
    );
  });

  testWidgets('a refusal she can fix – Arabic, Lapis', (tester) async {
    await shot(tester, 'unsure_ar_lapis', const RecipeScreen(recipeId: cupsId, animateBackdrop: false));
  });

  testWidgets('a dish held by the window – English, Aurora', (tester) async {
    await shot(
      tester,
      'held_en_aurora',
      const TonightScreen(animateBackdrop: false),
      theme: MadarThemeId.aurora,
      locale: const Locale('en'),
      seed: SufraSeed.held,
    );
  });

  testWidgets('a hard rule and a soft rule – Arabic, Pearl', (tester) async {
    await shot(
      tester,
      'rules_ar_pearl',
      const TonightScreen(animateBackdrop: false),
      theme: MadarThemeId.pearl,
      seed: SufraSeed.rules,
    );
  });

  // ---------------------------------------------------- «شو في بالبيت»

  testWidgets('the pantry – Arabic, Lapis', (tester) async {
    await shot(tester, 'pantry_ar_lapis', const PantryScreen(animateBackdrop: false));
  });

  testWidgets('the pantry – English, Pearl', (tester) async {
    await shot(
      tester,
      'pantry_en_pearl',
      const PantryScreen(animateBackdrop: false),
      theme: MadarThemeId.pearl,
      locale: const Locale('en'),
    );
  });

  testWidgets('the pantry – Arabic, Aurora, text scale 1.3', (tester) async {
    await shot(
      tester,
      'pantry_ar_aurora_x13',
      const PantryScreen(animateBackdrop: false),
      theme: MadarThemeId.aurora,
      textScale: 1.3,
    );
  });

  testWidgets('an empty pantry – Arabic, Lapis', (tester) async {
    await shot(tester, 'pantry_empty_ar_lapis', const PantryScreen(animateBackdrop: false), seed: SufraSeed.empty);
  });

  // ------------------------------------------------------- «طبخاتي»

  testWidgets('her dishes – Arabic, Lapis', (tester) async {
    await shot(tester, 'recipes_ar_lapis', const RecipesScreen(animateBackdrop: false));
  });

  testWidgets('her dishes – English, Aurora', (tester) async {
    await shot(
      tester,
      'recipes_en_aurora',
      const RecipesScreen(animateBackdrop: false),
      theme: MadarThemeId.aurora,
      locale: const Locale('en'),
    );
  });

  testWidgets('one dish – Arabic, Lapis', (tester) async {
    await shot(tester, 'recipe_ar_lapis', const RecipeScreen(recipeId: mujaddaraId, animateBackdrop: false));
  });

  testWidgets('one dish – English, Pearl, text scale 1.3', (tester) async {
    await shot(
      tester,
      'recipe_en_pearl_x13',
      const RecipeScreen(recipeId: mloukhiehId, animateBackdrop: false),
      theme: MadarThemeId.pearl,
      locale: const Locale('en'),
      textScale: 1.3,
    );
  });

  testWidgets('an empty list of dishes – Arabic, Pearl', (tester) async {
    await shot(
      tester,
      'recipes_empty_ar_pearl',
      const RecipesScreen(animateBackdrop: false),
      theme: MadarThemeId.pearl,
      seed: SufraSeed.empty,
    );
  });

  // ------------------------------------------- «محدداتي» and «اللي طبخناه»

  testWidgets('her constraints – Arabic, Lapis', (tester) async {
    await shot(
      tester,
      'rules_screen_ar_lapis',
      const KitchenRulesScreen(animateBackdrop: false),
      seed: SufraSeed.rules,
    );
  });

  testWidgets('her constraints – English, Aurora, text scale 1.3', (tester) async {
    await shot(
      tester,
      'rules_screen_en_aurora_x13',
      const KitchenRulesScreen(animateBackdrop: false),
      theme: MadarThemeId.aurora,
      locale: const Locale('en'),
      seed: SufraSeed.rules,
      textScale: 1.3,
    );
  });

  testWidgets('the cooked log – Arabic, Pearl', (tester) async {
    await shot(
      tester,
      'history_ar_pearl',
      const CookedHistoryScreen(animateBackdrop: false),
      theme: MadarThemeId.pearl,
      seed: SufraSeed.held,
    );
  });

  testWidgets('an empty cooked log – English, Lapis', (tester) async {
    await shot(
      tester,
      'history_empty_en_lapis',
      const CookedHistoryScreen(animateBackdrop: false),
      locale: const Locale('en'),
      seed: SufraSeed.empty,
    );
  });

  // -------------------------------------------------- the world's own card

  testWidgets('the world\'s card – Arabic, Lapis', (tester) async {
    await shot(
      tester,
      'hub_card_ar_lapis',
      Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SufraTodayCard(onOpen: () {}),
          ),
        ),
      ),
    );
  });

  testWidgets('the world\'s card on a fresh install – English, Pearl', (tester) async {
    await shot(
      tester,
      'hub_card_empty_en_pearl',
      Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SufraTodayCard(onOpen: () {}),
          ),
        ),
      ),
      theme: MadarThemeId.pearl,
      locale: const Locale('en'),
      seed: SufraSeed.empty,
    );
  });
}
