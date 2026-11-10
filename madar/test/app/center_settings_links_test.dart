// The notification centre's «إعدادات التذكير» link for a Prayer-group row goes
// to the screen that owns that row's switches: «الإقامة», «صيامي» and «رمضان»
// share the Prayer group (so its mute holds them) but each has its own screen.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/app/system_services.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/features/notification_center/notification_center.dart';

import '../helpers/test_app.dart';

void main() {
  CenterNotice notice(String namespace) => CenterNotice(
    id: 1,
    namespace: namespace,
    at: testNow.toUtc(),
    data: const {},
    title: 't',
    body: 'b',
  );

  final cases = <(String, String)>[
    (NotificationNamespaces.iqama.name, AppRoutes.iqamaSettings),
    (NotificationNamespaces.fasting.name, AppRoutes.fasting),
    (NotificationNamespaces.ramadan.name, AppRoutes.ramadan),
    (NotificationNamespaces.adhan.name, AppRoutes.adhanSettings),
  ];
  for (final (namespace, route) in cases) {
    testWidgets('a $namespace row opens $route', (tester) async {
      final app = await pumpMadarApp(tester);
      final context = tester.element(find.byType(Scaffold).first);
      // push() completes when the pushed page is popped: never await it.
      unawaited(Future.sync(() => centerSettingsLinks[NotificationGroup.prayer]!(context, NotificationGroup.prayer, notice(namespace))));
      await settleApp(tester);
      expect(app.location, route);
    });
  }
}
