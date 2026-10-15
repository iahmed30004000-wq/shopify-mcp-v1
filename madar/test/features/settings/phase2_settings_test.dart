// Settings' Phase 2 entries: prayer times & calculation, the adhan (with its
// permissions card), adhkar reminders (Settings › Reminders, planned through
// the notification service), security (the app lock) and the content
// credits.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/adhan/presentation/adhan_permissions_card.dart';
import 'package:madar/features/adhan/presentation/adhan_settings_screen.dart';
import 'package:madar/features/adhkar/adhkar.dart';
import 'package:madar/features/prayer/prayer.dart';
import 'package:madar/features/settings/licenses_screen.dart';
import 'package:madar/features/settings/security_settings_screen.dart';

import '../../helpers/test_app.dart';
import '../lock/lock_test_utils.dart';

final _ar = lookupL10n(const Locale('ar'));
final _en = lookupL10n(const Locale('en'));

const _english = AppSettings(onboarded: true, languageCode: 'en');

/// Scrolls [finder] to the middle of the settings list (clear of the app
/// bar the list runs under).
Future<void> _show(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);
  await tester.runAsync(() async {});
  await Scrollable.ensureVisible(tester.element(finder.first), alignment: 0.5);
  await tester.pumpAndSettle();
}

Finder _switch(String title) => find.byWidgetPredicate((w) => w is MadarSwitch && w.semanticLabel == title);

void main() {
  testWidgets('the hub lists faith (with the reminders) and privacy & security, in Arabic too', (tester) async {
    await pumpMadarApp(tester, initialLocation: AppRoutes.settings, overrides: LockFixture.empty().overrides);
    for (final title in [_ar.settingsFaithSection, _ar.settingsReminders, _ar.settingsSecuritySection]) {
      await _show(tester, find.text(title));
      expect(find.text(title), findsOneWidget, reason: title);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('prayer times & calculation: where and how, opening the prayer settings', (tester) async {
    final app = await pumpMadarApp(
      tester,
      settings: _english,
      initialLocation: AppRoutes.settings,
      overrides: LockFixture.empty().overrides,
    );
    await _show(tester, find.text(_en.settingsPrayerTimes));
    final summary = _en.orbitUiListSeparator(
      _en.ptLocationDefault(_en.ptDefaultCityName),
      _en.methodName(PrayerMethod.jordan),
    );
    expect(find.text(summary), findsOneWidget);
    app.sound.played.clear();
    await tester.tap(find.text(_en.settingsPrayerTimes));
    await settleApp(tester);
    expect(find.byType(PrayerSettingsScreen), findsOneWidget);
    expect(app.location, AppRoutes.prayerSettings);
    expect(app.sound.played, isNotEmpty);
    await tester.binding.handlePopRoute();
    await settleApp(tester);
    expect(app.location, AppRoutes.settings);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('adhan & notifications: the permissions card inline, the adhan page one tap away', (tester) async {
    final platform = FakeNotificationPlatform(enabled: false);
    final app = await pumpMadarApp(
      tester,
      settings: _english,
      initialLocation: AppRoutes.settings,
      notifications: platform,
      overrides: LockFixture.empty().overrides,
    );
    await _show(tester, find.byType(AdhanPermissionsCard));
    // (Settings › Notifications is a section of its own now, with the same
    // English word, so look inside the card.)
    expect(
      find.descendant(of: find.byType(AdhanPermissionsCard), matching: find.text(_en.adhanPermNotifications)),
      findsOneWidget,
    );
    await tester.tap(find.text(_en.adhanPermAllow).first);
    await settleApp(tester);
    expect(platform.requestNotificationsCalls, 1);

    await _show(tester, find.text(_en.settingsAdhan));
    await tester.tap(find.text(_en.settingsAdhan));
    await settleApp(tester);
    expect(find.byType(AdhanSettingsScreen), findsOneWidget);
    expect(app.location, AppRoutes.adhanSettings);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('adhkar reminders: morning after Fajr is planned with the notification service', (tester) async {
    final app = await pumpMadarApp(
      tester,
      settings: _english,
      initialLocation: AppRoutes.reminders,
      overrides: LockFixture.empty().overrides,
    );
    await _show(tester, find.text(_en.settingsAdhkarMorning));
    expect(find.text(_en.settingsAdhkarOff), findsNWidgets(2), reason: 'both off on a fresh install');
    app.haptics.fired.clear();
    await tester.tap(_switch(_en.settingsAdhkarMorning));
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await settleApp(tester);
    expect(app.haptics.fired, isNotEmpty);
    final stored = await tester.runAsync(() => app.container.read(adhkarReminderServiceProvider).load());
    expect(stored!.morning, isTrue);
    expect(stored.evening, isFalse);
    expect(find.text(_en.settingsAdhkarAfter(_en.adhkarReminderOffset(20))), findsOneWidget);
    // A week of morning reminders, in the adhkar block of ids.
    final ids = app.notifications.scheduled.keys.where(NotificationNamespaces.adhkar.contains).toList();
    expect(ids, isNotEmpty);
    expect(
      app.notifications.scheduled.values
          .where((s) => NotificationNamespaces.adhkar.contains(s.request.id))
          .map((s) => s.request.data['set'])
          .toSet(),
      {'morning'},
    );

    // The offset.
    await _show(tester, find.text(_en.adhkarReminderOffset(30)));
    await tester.tap(find.text(_en.adhkarReminderOffset(30)));
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await settleApp(tester);
    final after = await tester.runAsync(() => app.container.read(adhkarReminderServiceProvider).load());
    expect(after!.morningOffsetMin, 30);
    expect(find.text(_en.settingsAdhkarAfter(_en.adhkarReminderOffset(30))), findsOneWidget);
  });

  testWidgets('adhkar reminders: a refused permission keeps the choice and says why', (tester) async {
    final app = await pumpMadarApp(
      tester,
      settings: _english,
      initialLocation: AppRoutes.reminders,
      notifications: FakeNotificationPlatform(enabled: false),
      overrides: LockFixture.empty().overrides,
    );
    await _show(tester, find.text(_en.settingsAdhkarEvening));
    await tester.tap(_switch(_en.settingsAdhkarEvening));
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await settleApp(tester);
    expect(app.notifications.requestNotificationsCalls, 1);
    expect(app.sound.played, contains(Sfx.notify));
    await _show(tester, find.text(_en.adhkarReminderPermissionDenied));
    expect(find.text(_en.adhkarReminderPermissionDenied), findsOneWidget);
    final stored = await tester.runAsync(() => app.container.read(adhkarReminderServiceProvider).load());
    expect(stored!.evening, isTrue);
  });

  testWidgets('app lock: off on a fresh install, its page one tap away; on once a PIN is set', (tester) async {
    final app = await pumpMadarApp(
      tester,
      settings: _english,
      initialLocation: AppRoutes.settings,
      overrides: LockFixture.empty().overrides,
    );
    await _show(tester, find.text(_en.settingsAppLock));
    expect(find.text(_en.settingsAppLockOff), findsOneWidget);
    await tester.tap(find.text(_en.settingsAppLock));
    await settleApp(tester);
    expect(find.byType(SecuritySettingsScreen), findsOneWidget);
    expect(app.location, AppRoutes.security);
    // The app bar names the page; its one group has no second heading.
    expect(find.text(_en.settingsSecuritySection), findsOneWidget);
    expect(find.text(_en.lockSettingsTitle), findsNothing);
  });

  testWidgets('app lock: the entry says how the lock is set', (tester) async {
    final fx = await LockFixture.configured(biometrics: false);
    await pumpMadarApp(tester, settings: _english, initialLocation: AppRoutes.settings, overrides: fx.overrides);
    // Configured: Madar starts locked.
    for (final c in '2580'.split('')) {
      await tester.tap(find.bySemanticsLabel(c).last);
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    await _show(tester, find.text(_en.settingsAppLock));
    expect(find.text(_en.settingsAppLockOn), findsOneWidget);
  });

  testWidgets('fonts & sources: the content credits open onto their full texts', (tester) async {
    final app = await pumpMadarApp(
      tester,
      settings: _english,
      initialLocation: AppRoutes.settings,
      overrides: [
        ...LockFixture.empty().overrides,
        licenseTextProvider.overrideWith((ref, asset) async => 'Full credits of $asset'),
      ],
    );
    await _show(tester, find.text(_en.settingsCredits));
    await tester.tap(find.text(_en.settingsCredits));
    await settleApp(tester);
    expect(app.location, AppRoutes.licenses);
    expect(find.byType(LicensesScreen), findsOneWidget);
    for (final c in madarContentCredits) {
      await _show(tester, find.text(c.name(_en)));
      expect(find.text(c.role(_en)), findsOneWidget);
    }
    await tester.scrollUntilVisible(find.text(_en.settingsCreditAdhkar), -200, scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(tester.element(find.text(_en.settingsCreditAdhkar)), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(find.text(_en.settingsCreditAdhkar));
    await settleApp(tester);
    expect(find.text('Full credits of assets/licenses/adhkar_credits.txt'), findsOneWidget);
    expect(app.sound.played, contains(Sfx.sheetOpen));
  });
}
