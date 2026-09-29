import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/travel/travel.dart';

import 'travel_harness.dart';

void main() {
  Future<void> frames(WidgetTester tester, [int n = 20]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> idle(WidgetTester tester) async {
    await settleTravel(tester);
    // Let undo toasts and debounced syncs run out.
    await tester.pump(const Duration(seconds: 6));
    await settleTravel(tester);
  }

  group('trip screen', () {
    testWidgets('checking an item packs it with a haptic; the last one completes the list', (tester) async {
      late TravelScenario s;
      final env = await pumpTravelApp(
        tester,
        home: Builder(builder: (_) => TripScreen(tripId: s.cairo)),
        beforePump: (db) async {
          s = await seedTravelScenario(db);
          // Unpack one of Cairo's three items.
          final items = await Repositories(db).tripItems.getAll(where: (t) => t.tripId.equals(s.cairo));
          await Repositories(db).tripItems.setColumn(items.last.id, 'packed', false);
        },
      );
      final repos = env.repos;
      final items = await tester.runAsync(() => repos.tripItems.getAll(where: (t) => t.tripId.equals(s.cairo)));
      final open = items!.firstWhere((i) => !i.packed);
      await tester.scrollUntilVisible(find.text(open.body), 300, scrollable: find.byType(Scrollable).first);
      await settleTravel(tester);
      env.haptics.fired.clear();
      await tester.tap(find.text(open.body).last);
      await settleTravel(tester);
      final after = await tester.runAsync(() => repos.tripItems.byId(open.id));
      expect(after!.packed, isTrue);
      expect(env.haptics.fired, contains(Haptic.light));
      final activity = await tester.runAsync(() => repos.activity.since(DateTime(2000), planetKey: 'travel'));
      expect(activity!.map((a) => a.kind), containsAll([TravelActivity.itemPacked, TravelActivity.allPacked]));
      await idle(tester);
    });

    testWidgets('shows the destination prayer times in its own time and offers the prayer location', (tester) async {
      late TravelScenario s;
      TripPlace? used;
      await pumpTravelApp(
        tester,
        home: Builder(builder: (_) => TripScreen(tripId: s.cairo)),
        overrides: [
          travelUsePrayerLocationProvider.overrideWithValue((context, place) async => used = place),
        ],
        beforePump: (db) async => s = await seedTravelScenario(db),
      );
      expect(find.byType(DestinationPrayerCard), findsOneWidget);
      expect(find.byType(QiblaMiniDial), findsOneWidget);
      expect(find.textContaining('Africa/Cairo'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('اعتمدها موقعًا لصلاتي أثناء السفر'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('اعتمدها موقعًا لصلاتي أثناء السفر'));
      await settleTravel(tester);
      expect(used, isNotNull);
      expect(used!.city?.id, 'eg-cairo');
      expect(used!.timeZone, 'Africa/Cairo');
      await idle(tester);
    });

    testWidgets('a deleted trip says so', (tester) async {
      await pumpTravelApp(tester, home: const TripScreen(tripId: 'missing'));
      expect(find.text('لم تعد هذه الرحلة موجودة'), findsOneWidget);
      await idle(tester);
    });
  });

  group('travel screen', () {
    testWidgets('lists trips by phase and switches to documents sorted by expiry', (tester) async {
      await pumpTravelApp(
        tester,
        home: const TravelScreen(),
        locale: const Locale('en'),
        beforePump: (db) => seedTravelScenario(db, lang: 'en'),
      );
      expect(find.text('Under way'), findsWidgets);
      expect(find.text('Coming up'), findsOneWidget);
      expect(find.textContaining('Cairo', findRichText: true), findsWidgets);
      // Past trips start collapsed while trips are ahead.
      expect(find.textContaining('Show past trips'), findsOneWidget);

      await tester.tap(find.text('Documents'));
      await frames(tester);
      final visa = tester.getTopLeft(find.textContaining('Turkey e-visa'));
      final passport = tester.getTopLeft(find.textContaining('Passport'));
      final licence = tester.getTopLeft(find.textContaining('Driving licence'));
      expect(visa.dy, lessThan(passport.dy));
      expect(passport.dy, lessThan(licence.dy));
      expect(find.textContaining('Affects the trip to'), findsOneWidget);
      expect(find.textContaining('Makkah'), findsWidgets);
      await idle(tester);
    });

    testWidgets('empty: an invitation to plan a trip (nothing seeded)', (tester) async {
      await pumpTravelApp(tester, home: const TravelScreen());
      expect(find.text('لا رحلات بعد'), findsOneWidget);
      await idle(tester);
    });

    testWidgets('opening the travel screen schedules document reminders', (tester) async {
      final env = await pumpTravelApp(
        tester,
        home: const TravelScreen(),
        beforePump: (db) => seedTravelScenario(db),
      );
      await tester.pump(const Duration(seconds: 1));
      await settleTravel(tester);
      final ids = env.notifications.scheduled.keys.where(TravelReminderIds.owns).toList();
      // Passport (180 days ahead is past; on the day), visa (14 days ahead
      // + on the day), licence (30 days ahead + on the day).
      expect(ids.length, 5);
      await idle(tester);
    });
  });

  group('trip sheet', () {
    testWidgets('picks a listed city (coordinates and country) or keeps free text', (tester) async {
      TripDraft? result;
      await pumpTravelApp(
        tester,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async => result = await showTripSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        locale: const Locale('en'),
      );
      await tester.tap(find.text('open'));
      await frames(tester, 20);
      await tester.enterText(find.byType(TextField).first, 'Istanb');
      await frames(tester, 10);
      expect(find.text('Istanbul'), findsWidgets);
      await tester.tap(find.text('Istanbul').first);
      await frames(tester, 10);
      expect(find.text('Change'), findsOneWidget);
      await tester.tap(find.text('Add trip'));
      await frames(tester, 20);
      expect(result, isNotNull);
      expect(result!.destination, 'Istanbul');
      expect(result!.country, 'TR');
      expect(result!.latitude, closeTo(41.0, 0.2));
      expect(result!.status, isNull);

      // Free text: no coordinates.
      await tester.tap(find.text('open'));
      await frames(tester, 20);
      await tester.enterText(find.byType(TextField).first, 'Grandma\'s farm');
      await frames(tester, 10);
      await tester.tap(find.textContaining('as typed'));
      await frames(tester, 10);
      await tester.tap(find.text('Add trip'));
      await frames(tester, 20);
      expect(result!.destination, 'Grandma\'s farm');
      expect(result!.latitude, isNull);
      await idle(tester);
    });

    testWidgets('requires a destination', (tester) async {
      TripDraft? result;
      await pumpTravelApp(
        tester,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(onPressed: () async => result = await showTripSheet(context), child: const Text('open')),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await frames(tester, 20);
      await tester.tap(find.text('أضف الرحلة'));
      await frames(tester, 10);
      expect(find.text('اكتب الوجهة'), findsOneWidget);
      expect(result, isNull);
      await idle(tester);
    });
  });

  group('hub card', () {
    testWidgets('shows the trip under way, its packing and documents needing attention', (tester) async {
      await pumpTravelApp(
        tester,
        home: const Scaffold(body: Padding(padding: EdgeInsets.all(16), child: TravelTodayCard())),
        locale: const Locale('en'),
        beforePump: (db) => seedTravelScenario(db, lang: 'en'),
      );
      expect(find.textContaining('Cairo'), findsOneWidget);
      expect(find.text('Day 3 of 6'), findsOneWidget);
      expect(find.text('3/3 packed'), findsOneWidget);
      expect(find.textContaining('Passport'), findsOneWidget);
      await idle(tester);
    });

    testWidgets('with no trips it offers to plan one', (tester) async {
      await pumpTravelApp(
        tester,
        home: const Scaffold(body: TravelTodayCard()),
        beforePump: (MadarDatabase db) async {},
      );
      expect(find.text('لا رحلات قادمة'), findsOneWidget);
      await idle(tester);
    });
  });

  group('status sync', () {
    testWidgets('stores the date-derived status the orbit reads', (tester) async {
      late String id;
      final env = await pumpTravelApp(
        tester,
        home: const TravelScreen(),
        beforePump: (db) async {
          final service = TravelService(Repositories(db), clock: () => travelTestNow);
          final row = await service.addTrip(
            TripDraft(destination: 'x', startDate: DateTime(2026, 9, 20), endDate: DateTime(2026, 9, 25)),
          );
          id = row.id;
          // Stored as still planned (the app was closed when it ended).
          await Repositories(db).trips.setColumn(id, 'status', TripStatus.planned);
        },
      );
      await tester.pump(const Duration(seconds: 1));
      await settleTravel(tester);
      final row = await tester.runAsync(() => env.repos.trips.byId(id));
      expect(row!.status, TripStatus.done);
      await idle(tester);
    });
  });
}
