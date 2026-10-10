// His chronic conditions and his own rules: the list, the rule editor that
// reads like his sentence, its live preview, and an undo on everything
// destructive.
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

  testWidgets('nothing recorded yet: an invitation, in English too', (tester) async {
    await pumpNutritionApp(
      tester,
      home: const ConditionsScreen(animateBackdrop: false),
      locale: const Locale('en'),
    );
    expect(find.byKey(const ValueKey('nutrition.conditions.empty')), findsOneWidget);
    expect(find.text(en.nutritionConditionsEmptyTitle), findsOneWidget);
  });

  testWidgets('his condition and his rules read as his own sentences', (tester) async {
    final env = await pumpNutritionApp(
      tester,
      home: const ConditionsScreen(animateBackdrop: false),
      seed: NutritionSeed.full,
    );
    final condition = env.container.read(nutritionConditionsProvider).single;
    expect(find.byKey(ValueKey('nutrition.condition.${condition.id}')), findsOneWidget);
    expect(find.text('قولون'), findsWidgets);
    // Each rule is his own wording first.
    expect(find.textContaining('المقلي يوجع قولوني'), findsWidgets);
    expect(find.textContaining('الأكل المتأخر يتعبني'), findsWidgets);
    for (final r in env.container.read(nutritionRulesProvider)) {
      expect(find.byKey(ValueKey('nutrition.rule.${r.id}')), findsOneWidget);
    }
  });

  testWidgets('switching a condition off stops its rules counting, and undo brings it back', (tester) async {
    final env = await pumpNutritionApp(
      tester,
      home: const ConditionsScreen(animateBackdrop: false),
      seed: NutritionSeed.full,
    );
    final condition = env.container.read(nutritionConditionsProvider).single;
    expect(env.container.read(nutritionHasRatingProvider), isTrue);

    final sw = find.byKey(ValueKey('nutrition.condition.${condition.id}.active'));
    await bringIntoView(tester, sw);
    await tester.tap(sw);
    await nutritionFrames(tester);
    expect(env.container.read(nutritionConditionsProvider).single.active, isFalse);
    // Nothing was thrown away: the rules are still there, they just stop.
    expect(env.container.read(nutritionRulesProvider), hasLength(2));
    expect(env.container.read(nutritionHasRatingProvider), isFalse);
    expect(env.container.read(nutritionTodayRiskProvider), isNull);

    await tester.tap(find.text(ar.actionUndo));
    await nutritionFrames(tester);
    expect(env.container.read(nutritionConditionsProvider).single.active, isTrue);
    expect(env.container.read(nutritionHasRatingProvider), isTrue);
    await expireNutritionToasts(tester);
  });

  testWidgets('a rule can be switched off and deleted, both with undo', (tester) async {
    final env = await pumpNutritionApp(
      tester,
      home: const ConditionsScreen(animateBackdrop: false),
      seed: NutritionSeed.full,
    );
    final rule = env.container.read(nutritionRulesProvider).first;
    final sw = find.byKey(ValueKey('nutrition.rule.${rule.id}.active'));
    await bringIntoView(tester, sw);
    await tester.tap(sw);
    await nutritionFrames(tester);
    expect(env.container.read(nutritionRulesProvider).firstWhere((r) => r.id == rule.id).active, isFalse);
    expect(find.text(ar.nutritionRuleTurnedOff), findsOneWidget);
    await tester.tap(find.text(ar.actionUndo));
    await nutritionFrames(tester);
    expect(env.container.read(nutritionRulesProvider).firstWhere((r) => r.id == rule.id).active, isTrue);
    await expireNutritionToasts(tester);

    final row = find.byKey(ValueKey('nutrition.rule.${rule.id}'));
    await bringIntoView(tester, row);
    tester.state<ActionableItemState>(row).delete();
    await nutritionFrames(tester);
    expect(env.container.read(nutritionRulesProvider), hasLength(1));
    expect(find.text(ar.nutritionRuleDeleted), findsOneWidget);
    await tester.tap(find.text(ar.actionUndo));
    await nutritionFrames(tester);
    expect(env.container.read(nutritionRulesProvider), hasLength(2));
    await expireNutritionToasts(tester);
  });

  group('the rule editor', () {
    testWidgets('reads like his sentence and previews what it would have matched', (tester) async {
      final env = await pumpNutritionApp(
        tester,
        home: const ConditionsScreen(animateBackdrop: false),
        seed: NutritionSeed.full,
      );
      final condition = env.container.read(nutritionConditionsProvider).single;
      final add = find.byKey(ValueKey('nutrition.condition.${condition.id}.addRule'));
      await bringIntoView(tester, add);
      await tester.tap(add);
      await settleNutrition(tester);

      // Every part of the sentence is on the sheet.
      expect(find.text(ar.nutritionAddRule), findsWidgets);
      expect(find.text(ar.nutritionRuleTarget), findsOneWidget);
      expect(find.text(ar.nutritionRuleMinPortion), findsOneWidget);
      expect(find.text(ar.nutritionRuleFrom), findsOneWidget);
      expect(find.text(ar.nutritionRuleMaxPerDay), findsOneWidget);
      expect(find.text(ar.nutritionRuleWeight), findsOneWidget);
      expect(find.text(ar.nutritionRuleCondition), findsOneWidget);
      expect(find.text(ar.nutritionRuleNote), findsOneWidget);

      // The preview starts at "nothing" (no subject picked yet).
      final preview = find.byKey(const ValueKey('nutrition.rule.preview'));
      expect(preview, findsOneWidget);
      expect(tester.widget<Text>(preview).data, ar.nutritionRulePreview(0, '٠'));

      // Pick his own word «دسم» (one entry today, one a month of them).
      final tag = find.text('دسم');
      await bringIntoView(tester, tag);
      await tester.tap(tag.first);
      await settleNutrition(tester);

      final hits = RiskEngine.entriesHit(
        const FoodRule(id: '', target: FoodRuleTarget.tag, weight: RiskWeight.medium, tag: 'دسم'),
        env.container.read(nutritionEntriesProvider),
        foodsById: env.container.read(nutritionFoodsByIdProvider),
      ).length;
      expect(hits, greaterThan(0), reason: 'the seed logged «منسف», which carries «دسم»');
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('nutrition.rule.preview'))).data,
        ar.nutritionRulePreview(hits, MadarFormatter(languageCode: 'ar').formatInt(hits)),
        reason: 'the preview counts his own past entries',
      );

      // Save it: it lands under the condition it was opened from.
      await tester.tap(find.widgetWithText(SheetButton, ar.nutritionSave).first);
      await nutritionFrames(tester);
      final rules = env.container.read(nutritionRulesProvider);
      expect(rules, hasLength(3));
      final added = rules.firstWhere((r) => r.tag == 'دسم');
      expect(added.conditionId, condition.id);
      expect(added.target, FoodRuleTarget.tag);
      expect(find.text(ar.nutritionRuleSaved), findsOneWidget);
      await expireNutritionToasts(tester);
    });

    testWidgets('a half-written rule cannot be saved', (tester) async {
      final env = await pumpNutritionApp(
        tester,
        home: const ConditionsScreen(animateBackdrop: false),
        seed: NutritionSeed.full,
      );
      await bringIntoView(tester, find.byKey(const ValueKey('nutrition.rules.addGeneral')));
      await tester.tap(find.byKey(const ValueKey('nutrition.rules.addGeneral')));
      await settleNutrition(tester);
      // The default target is a tag, and none is picked.
      await tester.tap(find.widgetWithText(SheetButton, ar.nutritionSave).first);
      await settleNutrition(tester);
      expect(find.text(ar.nutritionRuleNeedsTag), findsOneWidget);
      expect(env.container.read(nutritionRulesProvider), hasLength(2), reason: 'nothing was written');
    });
  });

  testWidgets('a condition can be deleted with undo, and its rules survive', (tester) async {
    final env = await pumpNutritionApp(
      tester,
      home: const ConditionsScreen(animateBackdrop: false),
      seed: NutritionSeed.full,
    );
    final condition = env.container.read(nutritionConditionsProvider).single;
    final del = find.byKey(ValueKey('nutrition.condition.${condition.id}.delete'));
    await bringIntoView(tester, del);
    await tester.tap(del);
    await nutritionFrames(tester);
    expect(env.container.read(nutritionConditionsProvider), isEmpty);
    expect(env.container.read(nutritionRulesProvider), hasLength(2), reason: 'his wording is never thrown away');
    expect(env.container.read(nutritionHasRatingProvider), isFalse, reason: 'they stop counting though');
    expect(find.text(ar.nutritionConditionDeleted(BidiIsolate.isolate('قولون'))), findsOneWidget);
    await tester.tap(find.text(ar.actionUndo));
    await nutritionFrames(tester);
    expect(env.container.read(nutritionConditionsProvider), hasLength(1));
    expect(env.container.read(nutritionHasRatingProvider), isTrue);
    await expireNutritionToasts(tester);
  });
}
