// Regression tests for B1 (APK #15): the Money "savings and commitments"
// screen painted the empty states of all three tabs on top of each other.
// Only the selected tab's content may be in the tree.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/money/goals/goals.dart';

import 'goals_harness.dart';

void main() {
  final ar = lookupL10n(const Locale('ar'));

  group('GoalsScreen tabs', () {
    testWidgets('only the selected tab is in the tree (fresh install, three empty states)', (tester) async {
      await pumpGoalsApp(tester, home: const GoalsScreen(animateBackdrop: false), seed: false);

      void onlyTab(String visible) {
        for (final title in [ar.goalsJarsEmptyTitle, ar.goalsDebtsEmptyTitle, ar.goalsObligationsEmptyTitle]) {
          expect(
            find.text(title),
            title == visible ? findsOneWidget : findsNothing,
            reason: 'expected only "$visible" to be built, found "$title" too',
          );
        }
      }

      onlyTab(ar.goalsJarsEmptyTitle);

      await tester.tap(find.text(ar.goalsTabDebts));
      await settleGoals(tester);
      onlyTab(ar.goalsDebtsEmptyTitle);

      await tester.tap(find.text(ar.goalsTabObligations));
      await settleGoals(tester);
      onlyTab(ar.goalsObligationsEmptyTitle);

      // Back to the first tab: still one, not three.
      await tester.tap(find.text(ar.goalsTabJars));
      await settleGoals(tester);
      onlyTab(ar.goalsJarsEmptyTitle);
    });

    testWidgets('with real data, a switched-away tab leaves no rows behind', (tester) async {
      await pumpGoalsApp(tester, home: const GoalsScreen(animateBackdrop: false));
      expect(find.text('سفر العائلة'), findsOneWidget, reason: 'a jar row');

      await tester.tap(find.text(ar.goalsTabDebts));
      await settleGoals(tester);
      expect(find.text('سفر العائلة'), findsNothing, reason: 'the jars tab is gone, not just transparent');
      expect(find.text('المورّد'), findsOneWidget, reason: 'a debt row');

      await tester.tap(find.text(ar.goalsTabObligations));
      await settleGoals(tester);
      expect(find.text('المورّد'), findsNothing);
      expect(find.text('الإيجار'), findsOneWidget, reason: 'an obligation row');
    });
  });
}
