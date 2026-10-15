// `/lists` – every list he has, grouped by the record it hangs on, with
// the ones whose record was deleted at the end. It is where a list link
// with nothing to point at lands, so no result, reason or moon about a
// list can ever dead-end.
//
// A hang (a future waiting on fake time) fails fast instead of after 10 min.
@Timeout(Duration(minutes: 2))
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/routing/life_route_pages.dart' show LifeRecordLinks;
import 'package:madar/core/routing/routes.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/lists/lists.dart';

import '../../helpers/test_app.dart';
import '../lock/lock_test_utils.dart';

final _now = DateTime(2026, 10, 13, 18, 30);
final _ar = lookupL10n(const Locale('ar'));
final _en = lookupL10n(const Locale('en'));

const _envelope = ListHost(ListHost.budgetItems, 'food');
const _trip = ListHost(ListHost.trips, 'trip-1');

/// His budget envelope and a trip, each with a list – plus one list whose
/// record was deleted.
Future<Map<String, String>> _seed(MadarDatabase db) async {
  final repos = Repositories(db);
  final service = ListService(repos, clock: () => _now);
  await repos.budgetItems.insert(
    BudgetItemsCompanion.insert(id: const Value('food'), name: 'بقالة', amountMilli: const Value(200000)),
  );
  await repos.trips.insert(
    TripsCompanion.insert(id: const Value('trip-1'), destination: 'عمّان', startDate: Value(DateTime(2026, 11, 2))),
  );
  final (shopping, _) = await service.addList(_envelope, const ListDraft(name: 'أغراض البقالة', currency: 'JOD'));
  await service.addItems(shopping.id, ['رز', 'زيت']);
  final (trip, _) = await service.addList(_trip, const ListDraft(name: 'شنطة السفر'));
  await service.addItems(trip.id, ['جواز', 'شاحن', 'دوا']);
  final (orphan, _) = await service.addList(
    const ListHost(ListHost.budgetItems, 'gone'),
    const ListDraft(name: 'أغراض العيد', currency: 'JOD'),
  );
  await service.addItems(orphan.id, ['كعك']);
  return {'shopping': shopping.id, 'trip': trip.id, 'orphan': orphan.id};
}

Future<void> _frames(WidgetTester tester, [int n = 20]) async {
  for (var i = 0; i < n; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 2)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Waits for [ready], bounded by database round trips, not by a count of
/// frames that means nothing.
Future<void> _until(WidgetTester tester, String what, bool Function() ready, {int roundTrips = 40}) async {
  for (var i = 0; i < roundTrips && !ready(); i++) {
    await _frames(tester, 3);
  }
  expect(ready(), isTrue, reason: 'waited for $what');
}

void main() {
  group('a list link with nothing to point at', () {
    test('lands on all of his lists instead of nowhere', () {
      expect(AppRoutes.recordListsAll, '/lists');
      expect(LifeRecordLinks.locationOf('record_lists', null), '/lists');
      expect(LifeRecordLinks.locationOf('record_list_items', 'i-1'), '/lists');
      // The precise cases are untouched.
      expect(LifeRecordLinks.locationOf('record_lists', 'l-1'), '/list/l-1');
      expect(
        LifeRecordLinks.locationOf('record_lists', null, extra: {'hostTable': 'trips', 'hostId': 't1'}),
        '/lists/trips/t1',
      );
      expect(LifeRecordLinks.locationOf('record_list_items', 'i-1', extra: {'listId': 'l-1'}), '/list/l-1');
      // Every table Life claims leads somewhere, with no id at all.
      for (final table in LifeRecordLinks.tables) {
        expect(LifeRecordLinks.locationOf(table, null), isNotNull, reason: table);
      }
    });

    test('it needs onboarding like every other page', () {
      expect(onboardingRedirect(onboarded: false, location: AppRoutes.recordListsAll), AppRoutes.onboarding);
      expect(onboardingRedirect(onboarded: true, location: AppRoutes.recordListsAll), isNull);
    });
  });

  group('all of his lists', () {
    testWidgets('ar: a fresh install says so warmly instead of showing an empty frame', (tester) async {
      await pumpMadarApp(
        tester,
        initialLocation: AppRoutes.recordListsAll,
        now: _now,
        settle: false,
        overrides: LockFixture.empty().overrides,
      );
      await _frames(tester, 20);

      expect(find.byType(AllListsScreen), findsOneWidget);
      expect(find.text(_ar.listsAllTitle), findsOneWidget);
      expect(find.byKey(const ValueKey('lists.all.empty')), findsOneWidget);
      expect(find.text(_ar.listsAllEmptyTitle), findsOneWidget);
      expect(find.byType(ListCard), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ar: every list under the record it belongs to, the orphans last, and a tap opens one', (tester) async {
      late Map<String, String> ids;
      final app = await pumpMadarApp(
        tester,
        initialLocation: AppRoutes.recordListsAll,
        now: _now,
        settle: false,
        beforePump: (db) async => ids = await _seed(db),
        overrides: LockFixture.empty().overrides,
      );
      await _until(tester, 'the lists to show', () => find.byType(ListCard).evaluate().length == 3);

      // One group per record, named by that record – and the lists whose
      // record is gone in a group of their own.
      expect(find.text('بقالة'), findsOneWidget);
      expect(find.text('عمّان'), findsOneWidget);
      expect(find.byKey(const ValueKey('lists.all.orphans')), findsOneWidget);
      expect(find.text(_ar.listsOrphanGroup), findsOneWidget);
      expect(find.text('أغراض العيد'), findsOneWidget, reason: 'the only way back to it');
      expect(find.text(_ar.listsRemainingCount(3)), findsNothing, reason: 'counts read in his digits');

      // The orphan group comes after the named ones.
      final orphanY = tester.getTopLeft(find.byKey(const ValueKey('lists.all.orphans'))).dy;
      expect(tester.getTopLeft(find.text('أغراض البقالة')).dy, lessThan(orphanY));
      expect(tester.getTopLeft(find.text('شنطة السفر')).dy, lessThan(orphanY));
      expect(tester.getTopLeft(find.text('أغراض العيد')).dy, greaterThan(orphanY));

      await tester.tap(find.text('شنطة السفر'));
      await _frames(tester, 20);
      expect(find.byType(ListScreen), findsOneWidget);
      expect(app.location, AppRoutes.recordListOf(ids['trip']!));
      expect(find.byType(ListItemTile), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('en: the same screen reads in English, his own names untranslated', (tester) async {
      final app = await pumpMadarApp(
        tester,
        settings: const AppSettings(onboarded: true, languageCode: 'en'),
        initialLocation: AppRoutes.recordListsAll,
        now: _now,
        settle: false,
        beforePump: (db) async => await _seed(db),
        overrides: LockFixture.empty().overrides,
      );
      await _until(tester, 'the lists to show', () => find.byType(ListCard).evaluate().length == 3);

      expect(find.text(_en.listsAllTitle), findsOneWidget);
      expect(find.text(_en.listsOrphanGroup), findsOneWidget);
      expect(find.text('أغراض البقالة'), findsOneWidget, reason: 'his words are never translated');
      expect(find.text(_en.listsListsCount(1)), findsWidgets);
      expect(Directionality.of(tester.element(find.byType(AllListsScreen))), TextDirection.ltr);
      expect(app.location, AppRoutes.recordListsAll);
      expect(tester.takeException(), isNull);
    });
  });
}
