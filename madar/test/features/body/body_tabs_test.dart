// Regression test for B1 (APK #15): tab bodies piled up on each other.
// Only the selected tab's subtree may be in the tree.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/body/body.dart';

import 'body_harness.dart';
import 'body_seed.dart';

void main() {
  final ar = lookupL10n(const Locale('ar'));

  testWidgets('BodyScreen: only the selected tab is in the tree', (tester) async {
    await pumpBodyApp(tester, home: const BodyScreen(animateBackdrop: false), seed: BodySeed.full);
    const keys = ['body.today', 'body.plan', 'body.fasting', 'body.water', 'body.avoid'];
    final labels = [ar.bodyTabToday, ar.bodyTabPlan, ar.bodyTabFasting, ar.bodyTabWater, ar.bodyTabAvoid];

    void only(String key) {
      for (final k in keys) {
        expect(find.byKey(ValueKey(k)), k == key ? findsOneWidget : findsNothing, reason: 'expected only $key, saw $k');
      }
    }

    only(keys.first);
    for (var i = 1; i < keys.length; i++) {
      await tester.tap(find.bySemanticsLabel(labels[i]).first);
      await settleBody(tester);
      only(keys[i]);
    }
    // ... and back to the first one.
    await tester.tap(find.bySemanticsLabel(labels.first).first);
    await settleBody(tester);
    only(keys.first);
  });
}
