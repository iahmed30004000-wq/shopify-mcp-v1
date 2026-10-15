@Tags(['screenshot'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/tokens.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/body/body.dart';
import 'package:madar/features/nutrition/nutrition.dart';
import 'package:madar/features/nutrition/presentation/nutrition_ui.dart';

import '../../../helpers/screenshot_harness.dart';
import 'nutrition_ui_harness.dart';
import 'nutrition_ui_seed.dart';

const _dir = 'nutrition';

/// Shows [behind] and opens a sheet over it on the first frame.
class OpenOnStart extends ConsumerStatefulWidget {
  const OpenOnStart({super.key, required this.behind, required this.open});

  final Widget behind;
  final Future<void> Function(BuildContext context, WidgetRef ref) open;

  @override
  ConsumerState<OpenOnStart> createState() => _OpenOnStartState();
}

class _OpenOnStartState extends ConsumerState<OpenOnStart> {
  bool _opened = false;

  @override
  Widget build(BuildContext context) {
    if (!_opened) {
      _opened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Let the database rows reach the providers before the sheet reads
        // them (its pickers are built from his library once, on open).
        await Future<void>.delayed(const Duration(milliseconds: 400));
        if (mounted) await widget.open(context, ref);
      });
    }
    return widget.behind;
  }
}

/// The food card as the Body hub places it.
class HubPreview extends StatelessWidget {
  const HubPreview({super.key});

  @override
  Widget build(BuildContext context) => MadarScaffold(
    title: L10n.of(context).bodyTitle,
    body: ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.xl),
      children: const [NutritionTodayCard()],
    ),
  );
}

void main() {
  Future<void> shot(
    WidgetTester tester,
    String name,
    Widget home, {
    MadarThemeId theme = MadarThemeId.lapis,
    Locale locale = const Locale('ar'),
    NutritionSeed? seed = NutritionSeed.full,
    double textScale = 1,
    Future<void> Function(WidgetTester tester)? beforeCapture,
    int trailingFrames = 14,
  }) async {
    final (app, _) = await buildNutritionApp(
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
      trailingFrames: trailingFrames,
      beforeCapture: (tester) async {
        for (var i = 0; i < 5; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
          await tester.pump(const Duration(milliseconds: 50));
        }
        if (beforeCapture != null) await beforeCapture(tester);
      },
    );
  }

  // ------------------------------------------------------- the food tab ----

  testWidgets('food tab – Arabic, Lapis', (tester) async {
    await shot(tester, 'today_ar_lapis', const BodyScreen(initialTab: BodyTab.food));
  });

  testWidgets('food tab – English, Pearl', (tester) async {
    await shot(
      tester,
      'today_en_pearl',
      const BodyScreen(initialTab: BodyTab.food),
      theme: MadarThemeId.pearl,
      locale: const Locale('en'),
    );
  });

  testWidgets('food tab – fresh install, Arabic, Aurora', (tester) async {
    await shot(
      tester,
      'today_empty_ar_aurora',
      const BodyScreen(initialTab: BodyTab.food),
      theme: MadarThemeId.aurora,
      seed: null,
    );
  });

  testWidgets('food tab – no rules, no rating, Arabic, Pearl', (tester) async {
    await shot(
      tester,
      'today_norules_ar_pearl',
      const BodyScreen(initialTab: BodyTab.food),
      theme: MadarThemeId.pearl,
      seed: NutritionSeed.noRules,
    );
  });

  testWidgets('food tab – text scale 1.3, Arabic, Lapis', (tester) async {
    await shot(tester, 'today_ar_lapis_scale130', const BodyScreen(initialTab: BodyTab.food), textScale: 1.3);
  });

  testWidgets('food tab – text scale 1.3, English, Aurora', (tester) async {
    await shot(
      tester,
      'today_en_aurora_scale130',
      const BodyScreen(initialTab: BodyTab.food),
      theme: MadarThemeId.aurora,
      locale: const Locale('en'),
      textScale: 1.3,
    );
  });

  // -------------------------------------------------------- the quick log ----

  testWidgets('quick log – Arabic, Lapis', (tester) async {
    await shot(
      tester,
      'quicklog_ar_lapis',
      OpenOnStart(
        behind: const BodyScreen(initialTab: BodyTab.food),
        open: (context, ref) => NutritionActions.quickLog(context, ref),
      ),
      trailingFrames: 26,
    );
  });

  testWidgets('quick log – English, Pearl', (tester) async {
    await shot(
      tester,
      'quicklog_en_pearl',
      OpenOnStart(
        behind: const BodyScreen(initialTab: BodyTab.food),
        open: (context, ref) => NutritionActions.quickLog(context, ref),
      ),
      theme: MadarThemeId.pearl,
      locale: const Locale('en'),
      trailingFrames: 26,
    );
  });

  // ---------------------------------------------------------- the library ----

  testWidgets('library – Arabic, Pearl', (tester) async {
    await shot(tester, 'library_ar_pearl', const FoodLibraryScreen(), theme: MadarThemeId.pearl);
  });

  testWidgets('library – English, Lapis', (tester) async {
    await shot(tester, 'library_en_lapis', const FoodLibraryScreen(), locale: const Locale('en'));
  });

  testWidgets('library – empty, Arabic, Aurora', (tester) async {
    await shot(tester, 'library_empty_ar_aurora', const FoodLibraryScreen(), theme: MadarThemeId.aurora, seed: null);
  });

  // ------------------------------------------------------- the meal plan ----

  testWidgets('plan – Arabic, Lapis', (tester) async {
    await shot(tester, 'plan_ar_lapis', const MealPlanScreen());
  });

  testWidgets('plan – English, Pearl', (tester) async {
    await shot(tester, 'plan_en_pearl', const MealPlanScreen(), theme: MadarThemeId.pearl, locale: const Locale('en'));
  });

  testWidgets('planned vs eaten – Arabic, Aurora', (tester) async {
    await shot(tester, 'compare_ar_aurora', const MealPlanScreen(initialTab: MealPlanTab.compare), theme: MadarThemeId.aurora);
  });

  testWidgets('planned vs eaten – English, Lapis, text scale 1.3', (tester) async {
    await shot(
      tester,
      'compare_en_lapis_scale130',
      const MealPlanScreen(initialTab: MealPlanTab.compare),
      locale: const Locale('en'),
      textScale: 1.3,
    );
  });

  testWidgets('plan – empty, Arabic, Pearl', (tester) async {
    await shot(tester, 'plan_empty_ar_pearl', const MealPlanScreen(), theme: MadarThemeId.pearl, seed: null);
  });

  // ------------------------------------------- conditions and his rules ----

  testWidgets('conditions and rules – Arabic, Lapis', (tester) async {
    await shot(tester, 'rules_ar_lapis', const ConditionsScreen());
  });

  testWidgets('conditions and rules – English, Aurora', (tester) async {
    await shot(tester, 'rules_en_aurora', const ConditionsScreen(), theme: MadarThemeId.aurora, locale: const Locale('en'));
  });

  testWidgets('conditions and rules – empty, Arabic, Pearl', (tester) async {
    await shot(tester, 'rules_empty_ar_pearl', const ConditionsScreen(), theme: MadarThemeId.pearl, seed: null);
  });

  testWidgets('rule editor with its live preview – Arabic, Lapis', (tester) async {
    await shot(
      tester,
      'rule_editor_ar_lapis',
      OpenOnStart(
        behind: const ConditionsScreen(),
        open: (context, ref) async {
          final condition = ref.read(nutritionConditionsProvider).firstOrNull;
          final rule = ref.read(nutritionRulesProvider).firstOrNull;
          if (rule != null) {
            await showRuleSheet(context, ref, rule: rule);
          } else {
            await showRuleSheet(context, ref, conditionId: condition?.id);
          }
        },
      ),
      trailingFrames: 40,
    );
  });

  // --------------------------------------------------------- the insights ----

  testWidgets('observations – Arabic, Lapis', (tester) async {
    await shot(tester, 'insights_ar_lapis', const NutritionInsightsScreen());
  });

  testWidgets('observations – English, Pearl', (tester) async {
    await shot(
      tester,
      'insights_en_pearl',
      const NutritionInsightsScreen(),
      theme: MadarThemeId.pearl,
      locale: const Locale('en'),
    );
  });

  testWidgets('observations – not ready yet, Arabic, Aurora', (tester) async {
    await shot(
      tester,
      'insights_notready_ar_aurora',
      const NutritionInsightsScreen(),
      theme: MadarThemeId.aurora,
      seed: NutritionSeed.earlyDays,
    );
  });

  testWidgets('observations – not ready yet, English, Pearl, text scale 1.3', (tester) async {
    await shot(
      tester,
      'insights_notready_en_pearl_scale130',
      const NutritionInsightsScreen(),
      theme: MadarThemeId.pearl,
      locale: const Locale('en'),
      seed: NutritionSeed.earlyDays,
      textScale: 1.3,
    );
  });

  // ------------------------------------------------------------- the hub ----

  testWidgets('hub card – Arabic, Lapis', (tester) async {
    await shot(tester, 'hub_ar_lapis', const HubPreview());
  });

  testWidgets('hub card – English, Pearl', (tester) async {
    await shot(tester, 'hub_en_pearl', const HubPreview(), theme: MadarThemeId.pearl, locale: const Locale('en'));
  });
}
