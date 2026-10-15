// Every Phase 2 route builds its screen in Arabic and English inside the
// full app (router, gates, adhan host, app lock), and the parameters reach
// the screens.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/routing/router.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/adhan/presentation/adhan_settings_screen.dart';
import 'package:madar/features/adhkar/adhkar.dart';
import 'package:madar/features/prayer/prayer.dart';
import 'package:madar/features/prayer_tracker/prayer_tracker.dart';
import 'package:madar/features/settings/security_settings_screen.dart';

import '../../features/lock/lock_test_utils.dart';
import '../../helpers/test_app.dart';

final _ar = lookupL10n(const Locale('ar'));

void main() {
  final routes = <(String, Type)>[
    (AppRoutes.prayerTimes, PrayerTimesScreen),
    (AppRoutes.prayerSettings, PrayerSettingsScreen),
    (AppRoutes.adhanSettings, AdhanSettingsScreen),
    (AppRoutes.security, SecuritySettingsScreen),
    (AppRoutes.prayerTracker, PrayerTrackerScreen),
    (AppRoutes.prayerTrackerHistory, PrayerTrackerScreen),
    (AppRoutes.adhkar, AdhkarHomeScreen),
    (AppRoutes.adhkarSetOf('morning'), AdhkarReaderScreen),
    (AppRoutes.adhkarSetOf('afterPrayer', prayer: 'asr'), AdhkarReaderScreen),
    (AppRoutes.tasbeeh, TasbeehScreen),
  ];

  for (final lang in ['ar', 'en']) {
    group(lang, () {
      for (final (location, type) in routes) {
        testWidgets('$location builds $type', (tester) async {
          final app = await pumpMadarApp(
            tester,
            settings: AppSettings(onboarded: true, languageCode: lang),
            initialLocation: location,
            overrides: LockFixture.empty().overrides,
          );
          expect(find.byType(type), findsOneWidget);
          expect(tester.takeException(), isNull);
          expect(app.router.state.uri.toString(), location);
          expect(
            Directionality.of(tester.element(find.byType(type))),
            lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          );
          // Nested below home: back leaves the page.
          await tester.binding.handlePopRoute();
          await settleApp(tester);
          expect(find.byType(type), findsNothing);
          // The undo toasts / timers of the pages end.
          await tester.pump(const Duration(seconds: 6));
        });
      }
    });
  }

  testWidgets('the parameters reach the screens', (tester) async {
    final app = await pumpMadarApp(
      tester,
      initialLocation: AppRoutes.adhkarSetOf('afterPrayer', prayer: 'asr'),
      overrides: LockFixture.empty().overrides,
    );
    final reader = tester.widget<AdhkarReaderScreen>(find.byType(AdhkarReaderScreen));
    expect(reader.category, AdhkarCategoryId.afterPrayer);
    expect(reader.prayer, Prayer.asr);

    app.router.go(AppRoutes.prayerTrackerHistory);
    await settleApp(tester);
    expect(tester.widget<PrayerTrackerScreen>(find.byType(PrayerTrackerScreen)).initialTab, TrackerTab.history);
    app.router.go(AppRoutes.prayerTracker);
    await settleApp(tester);
    expect(tester.widget<PrayerTrackerScreen>(find.byType(PrayerTrackerScreen)).initialTab, TrackerTab.today);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('an unknown adhkar set falls back to the adhkar home', (tester) async {
    final app = await pumpMadarApp(
      tester,
      initialLocation: '/adhkar/nonsense',
      overrides: LockFixture.empty().overrides,
    );
    expect(app.location, AppRoutes.adhkar);
    expect(find.byType(AdhkarHomeScreen), findsOneWidget);
    expect(find.byType(AdhkarReaderScreen), findsNothing);
  });

  testWidgets('the adhkar home opens sets and the tasbeeh as routes; back returns', (tester) async {
    final app = await pumpMadarApp(tester, initialLocation: AppRoutes.adhkar, overrides: LockFixture.empty().overrides);
    // The set card's label starts with the set's name (the hero's with a
    // sentence), so the last match is the card.
    await tester.tap(find.bySemanticsLabel(RegExp('^${_ar.adhkarCategoryMorning}, ')).last);
    await settleApp(tester);
    expect(app.router.state.uri.toString(), AppRoutes.adhkarSetOf('morning'));
    expect(find.byType(AdhkarReaderScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await settleApp(tester);
    expect(app.location, AppRoutes.adhkar);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('prayer times opens its settings through the router', (tester) async {
    final app = await pumpMadarApp(
      tester,
      initialLocation: AppRoutes.prayerTimes,
      overrides: LockFixture.empty().overrides,
    );
    await tester.tap(find.bySemanticsLabel(_ar.ptOpenSettings).first);
    await settleApp(tester);
    expect(find.byType(PrayerSettingsScreen), findsOneWidget);
    expect(app.router.state.uri.toString(), AppRoutes.prayerSettings);
    await tester.binding.handlePopRoute();
    await settleApp(tester);
    expect(find.byType(PrayerTimesScreen), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });
}
