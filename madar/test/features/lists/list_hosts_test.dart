// The other hosts of the same engine, inside the real app (router, gates,
// app lock): the packing list hanging on a trip, and finding a list or one
// of its items again by an Arabic word he wrote.
//
// A hang (a future waiting on fake time) fails fast instead of after 10 min.
@Timeout(Duration(minutes: 2))
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/routing/life_route_pages.dart' show LifeRecordLinks;
import 'package:madar/core/routing/routes.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/lists/lists.dart';
import 'package:madar/features/search/search.dart';
import 'package:madar/features/travel/travel.dart' show TripScreen;

import '../../helpers/test_app.dart';
import '../lock/lock_test_utils.dart';
import '../travel/travel_harness.dart';

final _now = DateTime(2026, 10, 13, 18, 30);
final _ar = lookupL10n(const Locale('ar'));
final _fmt = MadarFormatter(languageCode: 'ar');

/// «باقي ٣ أغراض» – what the screen really shows (counts are written in
/// his digits, which the ICU plural itself does not do).
String _remaining(int count) => _fmt.localizeDigits(_ar.listsRemainingCount(count));

const _envelope = ListHost(ListHost.budgetItems, 'food');
const _trip = ListHost(ListHost.trips, 'trip-1');

/// His budget («بقالة», 200 JOD a month) and one wallet.
Future<void> _seedMoney(MadarDatabase db) async {
  final r = Repositories(db);
  await r.budgetItems.insert(
    BudgetItemsCompanion.insert(id: const Value('food'), name: 'بقالة', amountMilli: const Value(200000)),
  );
  await r.wallets.insert(WalletsCompanion.insert(id: const Value('cash'), name: 'كاش', currency: 'JOD'));
}

Future<void> _seedTrip(MadarDatabase db) async {
  await Repositories(db).trips.insert(
    TripsCompanion.insert(
      id: const Value('trip-1'),
      destination: 'عمّان',
      startDate: Value(DateTime(2026, 11, 2)),
      endDate: Value(DateTime(2026, 11, 9)),
    ),
  );
}

/// A ready shopping list: ☐ رز ٢ × ١٫٥٠٠ ☐ زيت ٢٫٥٠٠ ☐ لبن ٢ × ١٫٢٥٠ ☐ خبز
/// (the three with a price are the owner's «٣ أغراض — ٨٫٠٠٠ د.أ»).
Future<String> _seedShoppingList(MadarDatabase db, {bool ticked = false}) async {
  final service = ListService(Repositories(db), clock: () => _now);
  final (row, _) = await service.addList(_envelope, const ListDraft(name: 'أغراض البقالة', currency: 'JOD'));
  await service.addItem(row.id, const ListItemDraft(title: 'رز', quantity: 2, unit: 'كيلو', priceMilli: 1500));
  await service.addItem(row.id, const ListItemDraft(title: 'زيت', priceMilli: 2500));
  await service.addItem(row.id, const ListItemDraft(title: 'لبن', quantity: 2, priceMilli: 1250));
  await service.addItem(row.id, const ListItemDraft(title: 'خبز'));
  if (ticked) {
    for (final item in await service.itemRows(row.id)) {
      if (item.title != 'خبز') await service.setDone(item, true);
    }
  }
  return row.id;
}

List<Override> _searchOverrides() => [
  searchWorkerFactoryProvider.overrideWithValue(() async => InlineSearchWorker()),
  searchDebounceProvider.overrideWithValue(const Duration(milliseconds: 10)),
];

/// Pumps frames, letting database work in between (never `pumpAndSettle`:
/// the empty states' illustrations and the glass sheen loop for ever, and
/// an undo toast counts down for five seconds).
Future<void> _frames(WidgetTester tester, [int n = 20]) async {
  for (var i = 0; i < n; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 2)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Waits until [ready] holds, bounded by the work it is really waiting for
/// (database round trips), never by a fixed number of steps.
Future<void> _until(WidgetTester tester, String what, bool Function() ready, {int roundTrips = 40}) async {
  for (var i = 0; i < roundTrips && !ready(); i++) {
    await _frames(tester, 3);
  }
  expect(ready(), isTrue, reason: 'waited for $what');
}

/// Lets the undo toasts leave, so no test ends with a pending timer.
Future<void> _expireToasts(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 2)));
    await tester.pump(const Duration(seconds: 1));
  }
}

Future<T> _work<T>(WidgetTester tester, Future<T> Function() work) async {
  final result = await tester.runAsync(work);
  await _frames(tester, 6);
  return result as T;
}

void main() {
  group('locations', () {
    test('a host\'s lists and one list each have their own path', () {
      expect(AppRoutes.recordListsOf('budget_items', 'food'), '/lists/budget_items/food');
      expect(AppRoutes.recordListsOf('trips', 'trip-1'), '/lists/trips/trip-1');
      expect(AppRoutes.recordListOf('l-1'), '/list/l-1');
      expect(AppRoutes.recordListOf('a b'), '/list/a%20b', reason: 'ids are escaped');
    });

    test('they need onboarding like every other page', () {
      for (final loc in [AppRoutes.recordListsOf('trips', 't'), AppRoutes.recordListOf('l')]) {
        expect(onboardingRedirect(onboarded: false, location: loc), AppRoutes.onboarding);
        expect(onboardingRedirect(onboarded: true, location: loc), isNull);
      }
    });

    test('a list record opens the list it is, and an item the list it is on', () {
      expect(LifeRecordLinks.locationOf('record_lists', 'l-1'), AppRoutes.recordListOf('l-1'));
      expect(
        LifeRecordLinks.locationOf('record_lists', null, extra: {'hostTable': 'trips', 'hostId': 't1'}),
        AppRoutes.recordListsOf('trips', 't1'),
      );
      expect(
        LifeRecordLinks.locationOf('record_list_items', 'i-1', extra: {'listId': 'l-1'}),
        AppRoutes.recordListOf('l-1'),
      );
      expect(LifeRecordLinks.locationOf('record_list_items', 'i-1'), isNull, reason: 'without its list, nowhere');
      for (final table in ['record_lists', 'record_list_items']) {
        expect(LifeRecordLinks.tables, contains(table));
      }
    });
  });

  group('the packing list on a trip', () {
    testWidgets('ar: the trip\'s own screen carries the tile that opens its lists', (tester) async {
      // The trip screen is pumped in the Travel package's own harness, the
      // way every other trip test is: inside the whole app it waits for
      // the offline city list to be decoded in an isolate, which a
      // fake-async test never finishes.
      late TravelScenario scenario;
      await pumpTravelApp(
        tester,
        home: Builder(builder: (_) => TripScreen(tripId: scenario.cairo)),
        beforePump: (db) async {
          scenario = await seedTravelScenario(db);
          final service = ListService(Repositories(db), clock: () => travelTestNow);
          final (row, _) = await service.addList(
            ListHost(ListHost.trips, scenario.cairo),
            const ListDraft(name: 'شنطة السفر'),
          );
          await service.addItems(row.id, ['جواز', 'شاحن', 'دوا']);
        },
      );
      await settleTravel(tester);
      // A tall surface instead of dragging: the whole trip page is laid
      // out at once, so the tile under the packing list is built.
      tester.view.physicalSize = const Size(412, 2600) * 2;
      await settleTravel(tester);

      expect(
        find.byKey(const ValueKey('travel.trip.lists')),
        findsOneWidget,
        reason: 'it hangs where the trip is already shown',
      );
      expect(find.text(_ar.listsTripTile), findsOneWidget);
      expect(find.text(_fmt.localizeDigits(_ar.listsListsCount(1))), findsOneWidget, reason: 'and it counts his lists');
      // It opens the trip's lists, which is where the list itself lives.
      expect(AppRoutes.recordListsOf(ListHost.trips, scenario.cairo), '/lists/trips/${scenario.cairo}');
      await tester.pump(const Duration(seconds: 6));
      await settleTravel(tester);
    });

    testWidgets('ar: ☐ جواز ☐ شاحن ☐ دوا tick on the trip, with no money bar in sight', (tester) async {
      late String listId;
      final app = await pumpMadarApp(
        tester,
        initialLocation: AppRoutes.recordListsOf(_trip.table, _trip.id),
        now: _now,
        settle: false,
        beforePump: (db) async {
          await _seedTrip(db);
          final service = ListService(Repositories(db), clock: () => _now);
          final (row, _) = await service.addList(_trip, const ListDraft(name: 'شنطة السفر'));
          await service.addItems(row.id, ['جواز', 'شاحن', 'دوا']);
          listId = row.id;
        },
        overrides: LockFixture.empty().overrides,
      );
      await _frames(tester, 20);

      // The host screen is the trip's: its destination is the title.
      expect(find.byType(HostListsScreen), findsOneWidget);
      expect(find.text(_ar.listsOfHost('عمّان')), findsOneWidget);

      await tester.tap(find.text('شنطة السفر'));
      await _frames(tester, 20);
      expect(find.byType(ListScreen), findsOneWidget);
      expect(app.location, AppRoutes.recordListOf(listId));
      expect(find.byType(ListItemTile), findsNWidgets(3));
      // A trip's list is not money: nothing offers to post it.
      expect(find.byKey(const ValueKey('lists.post.summary')), findsNothing);
      expect(find.byKey(const ValueKey('lists.post.button')), findsNothing);

      await tester.tap(find.text('جواز'));
      await _until(
        tester,
        'the tick to be stored',
        () => find.text(_remaining(2)).evaluate().isNotEmpty,
      );
      final lines = await _work(tester, () => ListService(app.repos).lines(listId));
      expect(lines.firstWhere((l) => l.title == 'جواز').done, isTrue);
      expect(
        await _work(tester, () => app.repos.tripItems.count()),
        0,
        reason: "the trip's own packing list is untouched",
      );
      await _expireToasts(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('finding it again', () {
    for (final lang in ['ar', 'en']) {
      testWidgets('$lang: an Arabic word he wrote finds the item, and it opens its list', (tester) async {
        late String listId;
        final app = await pumpMadarApp(
          tester,
          settings: AppSettings(onboarded: true, languageCode: lang),
          initialLocation: AppRoutes.search,
          now: _now,
          settle: false,
          beforePump: (db) async {
            await _seedMoney(db);
            listId = await _seedShoppingList(db);
          },
          overrides: [...LockFixture.empty().overrides, ..._searchOverrides()],
        );
        await _frames(tester, 20);

        await tester.enterText(find.byType(TextField).first, 'زيت');
        await _until(
          tester,
          'the search to answer',
          () => find.byType(SearchResultTile).evaluate().isNotEmpty,
        );
        final tables = tester
            .widgetList<SearchResultTile>(find.byType(SearchResultTile))
            .map((t) => t.hit.doc.refTable)
            .toSet();
        expect(tables, contains('record_list_items'), reason: 'the item he wrote on his list');

        await tester.tap(find.byType(SearchResultTile).first);
        await _frames(tester, 24);
        expect(app.location, AppRoutes.recordListOf(listId), reason: 'a found item opens the list it is on');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 6));
      });
    }

    testWidgets('ar: the list itself is found by its own name', (tester) async {
      final app = await pumpMadarApp(
        tester,
        initialLocation: AppRoutes.search,
        now: _now,
        settle: false,
        beforePump: (db) async {
          await _seedMoney(db);
          await _seedShoppingList(db);
        },
        overrides: [...LockFixture.empty().overrides, ..._searchOverrides()],
      );
      await _frames(tester, 20);
      await tester.enterText(find.byType(TextField).first, 'البقالة');
      await _until(
        tester,
        'the search to answer',
        () => find.byType(SearchResultTile).evaluate().isNotEmpty,
      );
      final docs = tester.widgetList<SearchResultTile>(find.byType(SearchResultTile)).map((t) => t.hit.doc).toList();
      final list = docs.firstWhere((d) => d.refTable == 'record_lists');
      expect(list.title, 'أغراض البقالة');
      expect(list.subtitle, contains('بقالة'), reason: 'the envelope it hangs on');
      expect(app, isNotNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    });
  });
}
