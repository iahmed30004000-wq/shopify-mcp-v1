// Regression test for B1 (APK #15): tab bodies piled up on each other.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/travel/travel.dart';

import 'travel_harness.dart';

void main() {
  final ar = lookupL10n(const Locale('ar'));

  testWidgets('TravelScreen: only the selected tab is in the tree', (tester) async {
    await pumpTravelApp(tester, home: const TravelScreen(animateBackdrop: false));
    const keys = ['travel.trips', 'travel.documents', 'travel.templates'];
    final labels = [ar.travelTabTrips, ar.travelTabDocuments, ar.travelTabTemplates];

    void only(String key) {
      for (final k in keys) {
        expect(find.byKey(ValueKey(k)), k == key ? findsOneWidget : findsNothing, reason: 'expected only $key, saw $k');
      }
    }

    only(keys.first);
    for (var i = 1; i < keys.length; i++) {
      await tester.tap(find.bySemanticsLabel(labels[i]).first);
      await settleTravel(tester);
      only(keys[i]);
    }
    await tester.tap(find.bySemanticsLabel(labels.first).first);
    await settleTravel(tester);
    only(keys.first);
  });
}
