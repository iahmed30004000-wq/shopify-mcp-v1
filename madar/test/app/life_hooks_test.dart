// The Phase 6 life packages wired together in the full app (router, gates,
// app lock, the real providers over the harness's platform fakes):
// * the hooks are installed app-wide (Work's routes, a learning goal's
//   route, the trip's "use as my prayer location");
// * a trip's city becomes the prayer location – the city of the offline
//   list, or bare coordinates with the destination's zone – with an undo
//   toast that restores the settings from before;
// * the trip's prayer card offers the button once the hook is set, and the
//   button really moves the prayer times.
//
// The hooks are read from the app's own container – never passed again
// through `pumpMadarApp(overrides:)` (Riverpod asserts on a provider
// overridden twice).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/routing/life_route_pages.dart';
import 'package:madar/core/routing/router.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/growth/growth.dart' show growthOpenGoalProvider;
import 'package:madar/features/home/home_screen.dart';
import 'package:madar/features/orbit/data/orbit_providers.dart' show prayerSettingsProvider;
import 'package:madar/features/prayer/prayer.dart';
import 'package:madar/features/travel/travel.dart';
import 'package:madar/features/work/work.dart' show workRoutesProvider;

import '../features/lock/lock_test_utils.dart';
import '../features/travel/travel_harness.dart' show travelTestCities;
import '../helpers/test_app.dart';

final _en = lookupL10n(const Locale('en'));
const _english = AppSettings(onboarded: true, languageCode: 'en');
final DateTime _now = DateTime(2026, 9, 29, 13, 10);

/// Lets database writes started outside the fake clock land.
Future<void> _writes(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('the life hooks are installed app-wide', (tester) async {
    final app = await pumpMadarApp(tester, settings: _english, now: _now, overrides: LockFixture.empty().overrides);
    expect(app.container.read(workRoutesProvider), isA<RoutedWorkRoutes>());
    expect(app.container.read(growthOpenGoalProvider), isNotNull);
    expect(app.container.read(travelUsePrayerLocationProvider), isNotNull);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('a trip\'s city becomes the prayer location; undo restores the settings', (tester) async {
    final app = await pumpMadarApp(tester, settings: _english, now: _now, overrides: LockFixture.empty().overrides);
    final istanbul = travelTestCities().byId('tr-istanbul')!;
    final before = app.container.read(prayerSettingsControllerProvider);
    expect(before.cityId, isNot('tr-istanbul'));

    app.sound.played.clear();
    final use = app.container.read(travelUsePrayerLocationProvider)!;
    final done = use(tester.element(find.byType(HomeScreen)), TripPlace.ofCity(istanbul));
    await _writes(tester);
    await tester.runAsync(() => done);
    await tester.pump();
    final now = app.container.read(prayerSettingsControllerProvider);
    expect(now.cityId, 'tr-istanbul');
    expect(now.timeZone, 'Europe/Istanbul');
    expect(now.cityNameEn, 'Istanbul');
    expect(app.container.read(prayerSettingsProvider).value?.cityId, 'tr-istanbul', reason: 'stored');
    expect(app.sound.played, contains(Sfx.complete));
    expect(find.textContaining('Your prayer times now follow'), findsOneWidget);
    expect(find.textContaining('Istanbul'), findsWidgets);

    await tester.tap(find.text(_en.actionUndo));
    await _writes(tester);
    final undone = app.container.read(prayerSettingsControllerProvider);
    expect(undone.cityId, before.cityId);
    expect(undone.latitude, before.latitude);
    expect(undone.timeZone, before.timeZone);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('a place known only by its coordinates keeps the destination\'s zone', (tester) async {
    final app = await pumpMadarApp(tester, settings: _english, now: _now, overrides: LockFixture.empty().overrides);
    final use = app.container.read(travelUsePrayerLocationProvider)!;
    final done = use(
      tester.element(find.byType(HomeScreen)),
      const TripPlace(latitude: 36.2, longitude: 36.16, timeZone: 'Europe/Istanbul'),
    );
    await _writes(tester);
    await tester.runAsync(() => done);
    await tester.pump();
    final s = app.container.read(prayerSettingsControllerProvider);
    expect(s.latitude, closeTo(36.2, 0.001));
    expect(s.longitude, closeTo(36.16, 0.001));
    expect(s.timeZone, 'Europe/Istanbul');
    expect(s.cityId, isNull, reason: 'no city is claimed for bare coordinates');
    expect(s.locationSource, PrayerLocationSource.gps);
    expect(find.text(_en.travelPrayerUsed(_en.lifeHubPrayerDestination)), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets("the trip's prayer card offers the button and it moves the prayer times", (tester) async {
    late String tripId;
    final cities = travelTestCities();
    final makkah = cities.byId('sa-makkah')!;
    final app = await pumpMadarApp(
      tester,
      settings: _english,
      now: _now,
      overrides: [...LockFixture.empty().overrides, cityDatabaseProvider.overrideWith((ref) async => cities)],
      beforePump: (db) async => tripId = (await TravelService(Repositories(db), clock: () => _now).addTrip(
        TripDraft(
          destination: makkah.nameEn,
          country: makkah.countryCode,
          latitude: makkah.latitude,
          longitude: makkah.longitude,
          startDate: DateTime(2026, 12, 20),
          endDate: DateTime(2026, 12, 28),
        ),
      )).id,
    );
    app.router.go(AppRoutes.travelTripOf(tripId));
    await settleApp(tester);
    expect(find.byType(DestinationPrayerCard), findsOneWidget);
    final button = find.text(_en.travelPrayerUseHere);
    await tester.scrollUntilVisible(button, 200, scrollable: find.byType(Scrollable).first);
    await settleApp(tester);
    await tester.tap(button);
    await _writes(tester);
    expect(app.container.read(prayerSettingsControllerProvider).cityId, 'sa-makkah');
    expect(app.container.read(prayerSettingsControllerProvider).timeZone, 'Asia/Riyadh');
    await _writes(tester);
    expect(find.text(_en.travelPrayerIsLocation), findsOneWidget, reason: 'the card now says so');
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 6));
  });
}
