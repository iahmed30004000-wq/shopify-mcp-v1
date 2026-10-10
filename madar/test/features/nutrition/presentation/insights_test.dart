// The observations: the progress toward the minimum while he is not ready,
// counts (never causes) once he is, and the days behind any number.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/nutrition/nutrition.dart';
import 'package:madar/features/nutrition/presentation/nutrition_ui.dart';

import 'nutrition_ui_harness.dart';
import 'nutrition_ui_seed.dart';

void main() {
  final ar = lookupL10n(const Locale('ar'));
  final en = lookupL10n(const Locale('en'));
  final arFmt = MadarFormatter(languageCode: 'ar');

  testWidgets('before the minimum it shows the progress, never a number', (tester) async {
    final env = await pumpNutritionApp(
      tester,
      home: const NutritionInsightsScreen(animateBackdrop: false),
      seed: NutritionSeed.earlyDays,
    );
    final readiness = env.container.read(nutritionReadinessProvider);
    expect(readiness.ready, isFalse);
    expect(readiness.daysNeeded, NutritionInsights.minDays);
    expect(find.byKey(const ValueKey('nutrition.insights.readiness')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('nutrition.insights.notReady'))).data,
      ar.nutritionNotReadyBody(arFmt.formatInt(readiness.daysNeeded), arFmt.formatInt(readiness.daysLogged)),
    );
    // Nothing is stated yet.
    expect(find.byType(ObservationCard), findsNothing);
    expect(find.text(ar.nutritionWorstDaysTitle), findsNothing);
  });

  testWidgets('a fresh install is not ready either, and says so instead of nothing', (tester) async {
    await pumpNutritionApp(tester, home: const NutritionInsightsScreen(animateBackdrop: false));
    expect(find.byKey(const ValueKey('nutrition.insights.readiness')), findsOneWidget);
    expect(find.byType(ObservationCard), findsNothing);
  });

  testWidgets('once ready it states counts with the window, and never a cause', (tester) async {
    final env = await pumpNutritionApp(
      tester,
      home: const NutritionInsightsScreen(animateBackdrop: false),
      seed: NutritionSeed.full,
    );
    expect(env.container.read(nutritionReadinessProvider).ready, isTrue);
    final set = env.container.read(nutritionInsightsProvider(ar.nutritionLateMealLabel));
    expect(set.isEmpty, isFalse, reason: 'the seed makes the fried evenings stand out');
    expect(find.byType(ObservationCard), findsWidgets);
    // The window is stated on every observation.
    expect(
      find.text(ar.nutritionWindowNote(arFmt.formatInt(NutritionInsights.windowDays))),
      findsWidgets,
    );
    // The lead line says plainly that this is counting, not causation.
    expect(find.text(ar.nutritionInsightsLead), findsOneWidget);
  });

  testWidgets('any number opens the days behind it', (tester) async {
    final env = await pumpNutritionApp(
      tester,
      home: const NutritionInsightsScreen(animateBackdrop: false),
      seed: NutritionSeed.full,
    );
    final set = env.container.read(nutritionInsightsProvider(ar.nutritionLateMealLabel));
    final first = set.overlaps.isNotEmpty ? set.overlaps.first.marker : set.means.first.marker;
    final open = find.text(ar.nutritionOpenDays);
    await bringIntoView(tester, open);
    await tester.tap(open.first);
    await settleNutrition(tester);

    expect(find.byType(InsightDaysSheet), findsOneWidget);
    expect(find.text(ar.nutritionDaysBehindTitle), findsOneWidget);
    expect(find.text(ar.nutritionDaysWith(BidiIsolate.isolate(first.label))), findsOneWidget);
    expect(find.text(ar.nutritionDaysWithout), findsOneWidget);
    // Real days, each one its own row with its number and what he ate.
    final days = env.container.read(nutritionInsightDaysProvider(ar.nutritionLateMealLabel));
    expect(days, isNotEmpty);
    final shown = find.byWidgetPredicate(
      (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('nutrition.insightDay.'),
    );
    expect(shown, findsWidgets);
  });

  testWidgets('English reads the same way: counts, with the window', (tester) async {
    await pumpNutritionApp(
      tester,
      home: const NutritionInsightsScreen(animateBackdrop: false),
      seed: NutritionSeed.full,
      locale: const Locale('en'),
    );
    expect(find.text(en.nutritionInsightsLead), findsOneWidget);
    expect(find.byType(ObservationCard), findsWidgets);
  });
}
