import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/app/lock_gate.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/lock/application/lock_controller.dart';
import 'package:madar/features/lock/domain/lock_session.dart';
import 'package:madar/features/lock/presentation/lock_gate_host.dart';
import 'package:madar/features/lock/presentation/lock_screen.dart';
import 'package:madar/features/settings/settings_screen.dart';

import '../features/lock/lock_test_utils.dart';
import '../helpers/test_app.dart';

Future<void> _type(WidgetTester tester, String western) async {
  for (final c in western.split('')) {
    await tester.tap(find.bySemanticsLabel('٠١٢٣٤٥٦٧٨٩'[int.parse(c)]).last);
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _leave(WidgetTester tester) async {
  for (final s in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
  await tester.pump();
}

Future<void> _return(WidgetTester tester) async {
  for (final s in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
  await tester.pump();
}

void main() {
  testWidgets('the real gate is installed; a fresh install opens straight into the app', (tester) async {
    final app = await pumpMadarApp(tester, overrides: LockFixture.empty().overrides);
    expect(app.container.read(lockGateProvider), isA<BiometricLockGate>());
    expect(find.byType(LockGateHost), findsOneWidget);
    expect(find.byType(LockScreen), findsNothing);
    expect(app.settings.lockEnabled, isTrue, reason: 'on by default, active once a PIN exists');
  });

  testWidgets('configured: locked from the first frame, unlock keeps the navigation', (tester) async {
    final fx = await LockFixture.configured(biometrics: false);
    final app = await pumpMadarApp(tester, overrides: fx.overrides, initialLocation: '/settings', settle: false);
    await tester.pump();
    expect(find.byType(LockScreen), findsOneWidget);
    expect(find.byType(SettingsScreen), findsNothing, reason: 'nothing of the app is painted');
    expect(find.byType(SettingsScreen, skipOffstage: false), findsOneWidget, reason: 'but it stays mounted');
    await settleApp(tester);
    await _type(tester, '2580');
    await tester.pumpAndSettle();
    expect(find.byType(LockScreen), findsNothing);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(app.location, '/settings');
  });

  testWidgets('after 2 minutes in the background it locks again; a short visit does not', (tester) async {
    final fx = await LockFixture.configured(biometrics: false);
    final app = await pumpMadarApp(tester, overrides: fx.overrides);
    await _type(tester, '2580');
    await tester.pumpAndSettle();

    await _leave(tester);
    expect(find.byType(PrivacyShield), findsOneWidget, reason: 'recents thumbnail stays private');
    fx.clock.advance(const Duration(seconds: 70));
    await _return(tester);
    expect(find.byType(PrivacyShield), findsNothing);
    expect(find.byType(LockScreen), findsNothing);

    await _leave(tester);
    fx.clock.advance(const Duration(minutes: 2));
    await _return(tester);
    expect(find.byType(LockScreen), findsOneWidget);
    expect(app.container.read(lockControllerProvider).phase, LockPhase.locked);
  });

  testWidgets('"lock after: immediately" locks on every return', (tester) async {
    final fx = await LockFixture.configured(biometrics: false);
    await pumpMadarApp(
      tester,
      overrides: fx.overrides,
      settings: const AppSettings(onboarded: true, lockAfterSeconds: 0),
    );
    await _type(tester, '2580');
    await tester.pumpAndSettle();
    await _leave(tester);
    await _return(tester);
    expect(find.byType(LockScreen), findsOneWidget);
  });

  testWidgets('system back while locked never pops the hidden routes', (tester) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call.method);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final fx = await LockFixture.configured(biometrics: false);
    final app = await pumpMadarApp(tester, overrides: fx.overrides, initialLocation: '/settings');
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(app.location, '/settings');
    expect(calls, contains('SystemNavigator.pop'));

    // Unlocked, back pops as usual.
    await _type(tester, '2580');
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(app.location, '/');
  });

  testWidgets('NoLockGate still works as an override', (tester) async {
    final fx = await LockFixture.configured();
    await pumpMadarApp(tester, overrides: [...fx.overrides, lockGateProvider.overrideWithValue(const NoLockGate())]);
    expect(find.byType(LockScreen), findsNothing);
    expect(find.byType(LockGateHost), findsNothing);
  });
}
