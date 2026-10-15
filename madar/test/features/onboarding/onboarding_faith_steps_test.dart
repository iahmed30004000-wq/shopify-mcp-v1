// Onboarding's Phase 2 steps: where you pray (the prayer package's location
// flow), the adhan's permissions (the adhan package's card) and the optional
// app lock (the lock package's PIN sheet) – each skippable, with back
// navigation.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/adhan/presentation/adhan_permissions_card.dart';
import 'package:madar/features/home/home_screen.dart';
import 'package:madar/features/lock/application/lock_controller.dart';
import 'package:madar/features/lock/data/biometric_auth.dart';
import 'package:madar/features/lock/domain/lock_session.dart';
import 'package:madar/features/lock/presentation/lock_screen.dart';
import 'package:madar/features/onboarding/onboarding_screen.dart';
import 'package:madar/features/orbit/data/orbit_providers.dart';
import 'package:madar/features/prayer/prayer.dart';

import '../../helpers/test_app.dart';
import '../lock/lock_test_utils.dart';

final _en = lookupL10n(const Locale('en'));
final _ar = lookupL10n(const Locale('ar'));

/// Walks from the welcome page to [step] with the on-screen buttons.
Future<void> _walkTo(WidgetTester tester, L10n l, int step) async {
  for (var i = 0; i < step; i++) {
    await tester.tap(find.text(i == 0 ? l.onboardingBegin : l.actionContinue));
    await settleApp(tester);
  }
}

Future<void> _typePin(WidgetTester tester, String digits) async {
  for (final c in digits.split('')) {
    await tester.tap(find.bySemanticsLabel(c).last);
    await tester.pump(const Duration(milliseconds: 30));
  }
}

void main() {
  testWidgets('six steps, the faith steps between the look and the start', (tester) async {
    await pumpMadarApp(tester, settings: const AppSettings(), overrides: LockFixture.empty().overrides);
    expect(OnboardingScreen.stepCount, 6);
    await _walkTo(tester, _ar, OnboardingScreen.locationStep);
    expect(find.text(_ar.onboardingLocationTitle), findsOneWidget);
    expect(find.bySemanticsLabel(_ar.onboardingStep('٣', '٦')), findsOneWidget);
    await tester.tap(find.text(_ar.actionContinue));
    await settleApp(tester);
    expect(find.text(_ar.onboardingAdhanTitle), findsOneWidget);
    expect(find.byType(AdhanPermissionsCard), findsOneWidget);
    await tester.tap(find.text(_ar.actionContinue));
    await settleApp(tester);
    expect(find.text(_ar.onboardingLockTitle), findsOneWidget);
    expect(find.text(_ar.onboardingOptional), findsOneWidget);
  });

  testWidgets('where you pray: the default city until one is chosen from the offline list', (tester) async {
    final app = await pumpMadarApp(
      tester,
      settings: const AppSettings(languageCode: 'en'),
      overrides: LockFixture.empty().overrides,
    );
    await _walkTo(tester, _en, OnboardingScreen.locationStep);
    expect(find.text(_en.onboardingLocationFor(_en.ptLocationDefault(_en.ptDefaultCityName))), findsOneWidget);
    expect(find.text(_en.onboardingLocationSet), findsOneWidget);

    await tester.tap(find.text(_en.onboardingLocationSet));
    await settleApp(tester);
    expect(find.text(_en.ptLocationTitle), findsOneWidget, reason: "the prayer package's location sheet");
    await tester.tap(find.text(_en.ptChooseCity));
    await settleApp(tester);
    await tester.enterText(find.byType(TextField), 'mecca');
    await settleApp(tester);
    await tester.tap(find.text('Makkah').first);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final stored = await tester.runAsync(() => app.container.read(orbitRepositoryProvider).prayerSettings());
    expect(stored!.cityId, 'sa-makkah');
    expect(find.text(_en.onboardingLocationFor('Makkah, Saudi Arabia')), findsOneWidget);
    expect(find.text(_en.onboardingLocationChange), findsOneWidget);
    // The undo toast times out.
    await tester.pump(const Duration(seconds: 6));
    await settleApp(tester);
  });

  testWidgets('the adhan step asks Android for what is missing', (tester) async {
    final platform = FakeNotificationPlatform(enabled: false);
    await pumpMadarApp(
      tester,
      settings: const AppSettings(languageCode: 'en'),
      notifications: platform,
      overrides: LockFixture.empty().overrides,
    );
    await _walkTo(tester, _en, OnboardingScreen.adhanStep);
    expect(find.text(_en.adhanPermNotifications), findsOneWidget);
    // The step's heading says what the card is for; the card doesn't repeat it.
    expect(find.text(_en.adhanPermTitle), findsNothing);
    await tester.tap(find.text(_en.adhanPermAllow).first);
    await settleApp(tester);
    expect(platform.requestNotificationsCalls, 1);
  });

  testWidgets('the optional lock: a PIN set here arms the app lock, then Madar opens', (tester) async {
    final fx = LockFixture.empty(available: BiometricAvailability.noHardware);
    final app = await pumpMadarApp(
      tester,
      settings: const AppSettings(languageCode: 'en'),
      overrides: fx.overrides,
    );
    await _walkTo(tester, _en, OnboardingScreen.lockStep);
    await tester.tap(find.text(_en.onboardingLockSet));
    await settleApp(tester);
    await _typePin(tester, '2580');
    await tester.tap(find.bySemanticsLabel(_en.lockKeyDone));
    await settleApp(tester);
    await _typePin(tester, '2580');
    await settleApp(tester);
    final lock = app.container.read(lockControllerProvider);
    expect(lock.armed, isTrue);
    expect(lock.phase, LockPhase.open, reason: 'setting a PIN does not lock you out of onboarding');
    expect(find.text(_en.onboardingLockOn), findsOneWidget);

    await tester.tap(find.text(_en.actionContinue));
    await settleApp(tester);
    await tester.tap(find.text(_en.onboardingStartFresh));
    await settleApp(tester);
    expect(app.location, AppRoutes.home);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(LockScreen), findsNothing);
  });

  testWidgets('skip from a faith step lands on the start; back walks back through them', (tester) async {
    await pumpMadarApp(
      tester,
      settings: const AppSettings(languageCode: 'en'),
      overrides: LockFixture.empty().overrides,
    );
    await _walkTo(tester, _en, OnboardingScreen.locationStep);
    await tester.tap(find.text(_en.onboardingSkip));
    await settleApp(tester);
    expect(find.text(_en.onboardingStartTitle), findsOneWidget);
    for (final title in [_en.onboardingLockTitle, _en.onboardingAdhanTitle, _en.onboardingLocationTitle]) {
      await tester.tap(find.bySemanticsLabel(_en.actionBack));
      await settleApp(tester);
      expect(find.text(title), findsOneWidget);
    }
    // System back too.
    await tester.binding.handlePopRoute();
    await settleApp(tester);
    expect(find.text(_en.onboardingStyleTitle), findsOneWidget);
  });

  testWidgets('the location step reads the live prayer settings', (tester) async {
    final app = await pumpMadarApp(
      tester,
      settings: const AppSettings(languageCode: 'en'),
      overrides: LockFixture.empty().overrides,
    );
    await _walkTo(tester, _en, OnboardingScreen.locationStep);
    final cities = await tester.runAsync(() => app.container.read(cityDatabaseProvider.future));
    final amman = cities!.byId('jo-amman')!;
    await tester.runAsync(() => app.container.read(prayerSettingsControllerProvider.notifier).setCity(amman));
    await settleApp(tester);
    expect(find.text(_en.onboardingLocationFor('Amman, Jordan')), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(ProviderScope.containerOf(tester.element(find.byType(OnboardingScreen))), same(app.container));
  });
}
