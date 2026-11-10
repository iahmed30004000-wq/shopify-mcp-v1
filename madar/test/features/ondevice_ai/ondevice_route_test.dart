// `/settings/ondevice` is reachable: by its address, and by the row under
// Settings › AI. Opening it calls nobody.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/features/ondevice_ai/data/ondevice_providers.dart';
import 'package:madar/features/ondevice_ai/ondevice_ai.dart' show OnDeviceSettingsScreen;

import '../../helpers/test_app.dart';
import '../lock/lock_test_utils.dart';
import 'support/ondevice_fakes.dart';

Future<void> _frames(WidgetTester tester, [int n = 24]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  final ar = lookupL10n(const Locale('ar'));
  late Directory tmp;
  setUpAll(() => tmp = Directory.systemTemp.createTempSync('madar-ondevice-route-'));
  tearDownAll(() => tmp.deleteSync(recursive: true));

  test('the address is /settings/ondevice', () => expect(AppRoutes.ondeviceSettings, '/settings/ondevice'));

  testWidgets('by its address', (tester) async {
    final app = await pumpMadarApp(
      tester,
      initialLocation: AppRoutes.ondeviceSettings,
      settle: false,
      overrides: [
        ...LockFixture.empty().overrides,
        onDeviceProbeProvider.overrideWithValue(FakeProbe(capableCaps())),
        modelStorageRootProvider.overrideWithValue(() async => tmp),
      ],
    );
    await _frames(tester);
    expect(find.byType(OnDeviceSettingsScreen), findsOneWidget);
    expect(app.location, AppRoutes.ondeviceSettings);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('from the row in Settings', (tester) async {
    final app = await pumpMadarApp(
      tester,
      initialLocation: AppRoutes.settings,
      settle: false,
      overrides: [
        ...LockFixture.empty().overrides,
        onDeviceProbeProvider.overrideWithValue(FakeProbe(capableCaps())),
        modelStorageRootProvider.overrideWithValue(() async => tmp),
      ],
    );
    await _frames(tester, 20);
    final row = find.text(ar.ondeviceRowSubtitle);
    await tester.scrollUntilVisible(row, 200, scrollable: find.byType(Scrollable).first);
    await _frames(tester, 6);
    await Scrollable.ensureVisible(tester.element(row.last), alignment: 0.5);
    await _frames(tester, 6);
    await tester.tap(row.last);
    await _frames(tester);
    expect(find.byType(OnDeviceSettingsScreen), findsOneWidget);
    expect(app.location, AppRoutes.ondeviceSettings);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });
}
