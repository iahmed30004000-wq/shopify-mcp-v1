// Regression test for B1 (APK #15): tab bodies piled up on each other.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/notification_center/notification_center.dart';

import 'nc_harness.dart';

void main() {
  final ar = lookupL10n(const Locale('ar'));

  testWidgets('NotificationCenterScreen: only the selected tab is in the tree', (tester) async {
    await pumpNcApp(tester, home: const NotificationCenterScreen());
    const keys = ['nc.upcoming', 'nc.recent'];
    final labels = [ar.ncTabUpcoming, ar.ncTabRecent];

    void only(String key) {
      for (final k in keys) {
        expect(find.byKey(ValueKey(k)), k == key ? findsOneWidget : findsNothing, reason: 'expected only $key, saw $k');
      }
    }

    final first = find.byKey(const ValueKey('nc.upcoming')).evaluate().isNotEmpty ? 0 : 1;
    only(keys[first]);
    final other = 1 - first;
    await tester.tap(find.bySemanticsLabel(labels[other]).first);
    await settleNc(tester);
    only(keys[other]);
    await tester.tap(find.bySemanticsLabel(labels[first]).first);
    await settleNc(tester);
    only(keys[first]);
  });
}
