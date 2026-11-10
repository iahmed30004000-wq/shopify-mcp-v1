// The lists inside the real app (router, gates, app lock): he builds a
// list under the «بقالة» envelope at home, ticks it in the shop, turns the
// ticked part into one expense on that envelope – read back from the
// database – undoes it, is refused a second post, and keeps whatever he
// did not tick. Plus the packing list on a trip, the empty states, and
// finding an item by an Arabic word.
//
// A hang (a future waiting on fake time) fails fast instead of after 10 min.
@Timeout(Duration(minutes: 2))
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/budget_math.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/interaction/interaction.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/lists/lists.dart';
import 'package:madar/features/money/budget/budget.dart';

import '../../helpers/test_app.dart';
import '../lock/lock_test_utils.dart';

final _now = DateTime(2026, 10, 13, 18, 30);
final _ar = lookupL10n(const Locale('ar'));
final _fmt = MadarFormatter(languageCode: 'ar');

/// «باقي ٣ أغراض» – what the screen really shows (counts are written in
/// his digits, which the ICU plural itself does not do).
String _remaining(int count) => _fmt.localizeDigits(_ar.listsRemainingCount(count));
final _en = lookupL10n(const Locale('en'));

const _envelope = ListHost(ListHost.budgetItems, 'food');

/// His budget («بقالة», 200 JOD a month) and one wallet.
Future<void> _seedMoney(MadarDatabase db) async {
  final r = Repositories(db);
  await r.budgetItems.insert(
    BudgetItemsCompanion.insert(id: const Value('food'), name: 'بقالة', amountMilli: const Value(200000)),
  );
  await r.wallets.insert(WalletsCompanion.insert(id: const Value('cash'), name: 'كاش', currency: 'JOD'));
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
  group('the lists of an envelope', () {
    testWidgets('ar: a fresh envelope has no list and invites him to make one', (tester) async {
      final app = await pumpMadarApp(
        tester,
        initialLocation: AppRoutes.recordListsOf(_envelope.table, _envelope.id),
        now: _now,
        settle: false,
        beforePump: _seedMoney,
        overrides: LockFixture.empty().overrides,
      );
      await _frames(tester, 20);

      expect(find.byType(HostListsScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('lists.empty')), findsOneWidget);
      expect(find.text(_ar.listsEmptyTitle), findsOneWidget);
      // The envelope's own name is the title – he knows where he is.
      expect(find.text(_ar.listsOfHost('بقالة')), findsOneWidget);
      expect(await _work(tester, () => app.repos.recordLists.count()), 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ar: he makes a list, it opens, and what he types lands in the database', (tester) async {
      final app = await pumpMadarApp(
        tester,
        initialLocation: AppRoutes.recordListsOf(_envelope.table, _envelope.id),
        now: _now,
        settle: false,
        beforePump: _seedMoney,
        overrides: LockFixture.empty().overrides,
      );
      await _frames(tester, 20);

      // The one button on the screen: a new list.
      await tester.tap(find.bySemanticsLabel(_ar.listsNewList).first);
      await _frames(tester, 16);
      await tester.enterText(find.byType(TextField).first, 'أغراض البقالة');
      await _frames(tester, 6);
      await tester.tap(find.text(_ar.actionSave).last);
      await _until(tester, 'the list to be stored', () => find.byType(ListScreen).evaluate().isNotEmpty);

      final rows = await _work(tester, () => app.repos.recordLists.getAll());
      expect(rows.length, 1);
      expect(rows.single.name, 'أغراض البقالة');
      expect(rows.single.hostTable, 'budget_items');
      expect(rows.single.hostId, 'food');
      expect(app.location, AppRoutes.recordListOf(rows.single.id), reason: 'it opens straight away');

      // Inside the list: the warm empty state, then three items from the
      // add row – ☐ رز ☐ زيت ☐ لبن.
      expect(find.byKey(const ValueKey('lists.itemsEmpty')), findsOneWidget);
      for (final title in ['رز', 'زيت', 'لبن']) {
        await tester.enterText(find.byKey(const ValueKey('lists.add.field')), title);
        await _frames(tester, 4);
        await tester.tap(find.byKey(const ValueKey('lists.add.button')));
        await _frames(tester, 10);
      }
      await _until(
        tester,
        'the three items to be stored',
        () => find.byType(ListItemTile).evaluate().length == 3,
      );

      final items = await _work(tester, () => ListService(app.repos).lines(rows.single.id));
      expect([for (final l in items) l.title], ['رز', 'زيت', 'لبن']);
      expect(items.every((l) => !l.done), isTrue, reason: 'nothing is ticked before he shops');
      await _expireToasts(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('en: the same screens read in English', (tester) async {
      await pumpMadarApp(
        tester,
        settings: const AppSettings(onboarded: true, languageCode: 'en'),
        initialLocation: AppRoutes.recordListsOf(_envelope.table, _envelope.id),
        now: _now,
        settle: false,
        beforePump: (db) async {
          await _seedMoney(db);
          await _seedShoppingList(db);
        },
        overrides: LockFixture.empty().overrides,
      );
      await _frames(tester, 20);

      expect(find.byType(HostListsScreen), findsOneWidget);
      expect(find.text('أغراض البقالة'), findsOneWidget, reason: 'his own words are never translated');
      expect(find.text(_en.listsRemainingCount(4)), findsWidgets);
      expect(
        Directionality.of(tester.element(find.byType(HostListsScreen))),
        TextDirection.ltr,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('what a thing costs', () {
    testWidgets('ar: a price per kilo and a quantity make the line\'s exact total', (tester) async {
      late String listId;
      final app = await pumpMadarApp(
        tester,
        initialLocation: AppRoutes.home,
        now: _now,
        settle: false,
        beforePump: (db) async {
          await _seedMoney(db);
          final service = ListService(Repositories(db), clock: () => _now);
          final (row, _) = await service.addList(_envelope, const ListDraft(name: 'أغراض البقالة', currency: 'JOD'));
          listId = row.id;
        },
        overrides: LockFixture.empty().overrides,
      );
      app.router.go(AppRoutes.recordListOf(listId));
      await _frames(tester, 20);

      // The "+" in the app bar opens the item sheet.
      await tester.tap(find.bySemanticsLabel(_ar.listsNewItemTitle).first);
      await _until(tester, 'the sheet', () => find.byType(EditSheet).evaluate().isNotEmpty);

      // Its fields, in order: the item, how much, the unit, the price.
      Finder field(int i) =>
          find.descendant(of: find.byType(EditSheet), matching: find.byType(TextField)).at(i);
      await tester.enterText(field(0), 'رز');
      await tester.enterText(field(1), '٢');
      await tester.enterText(field(2), 'كيلو');
      await tester.enterText(field(3), '١٫٥');
      await _frames(tester, 6);
      // The sheet says what the line will cost before he saves it.
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('lists.item.total'))).data,
        contains('٣'),
        reason: '٢ كيلو × ١٫٥٠٠ = ٣٫٠٠٠ د.أ',
      );

      await tester.tap(find.text(_ar.actionSave).last);
      await _until(tester, 'the item to be stored', () => find.byType(ListItemTile).evaluate().isNotEmpty);

      final lines = await _work(tester, () => ListService(app.repos).lines(listId));
      final rice = lines.single;
      expect(rice.title, 'رز');
      expect(rice.quantity, 2);
      expect(rice.unit, 'كيلو');
      expect(rice.priceMilli, 1500, reason: '«١٫٥» is one and a half dinars, not one and a half fils');
      expect(rice.totalMilli, 3000);
      await _expireToasts(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('in the shop', () {
    testWidgets('ar: a tap ticks an item, and the database says so', (tester) async {
      late String listId;
      final app = await pumpMadarApp(
        tester,
        initialLocation: AppRoutes.home,
        now: _now,
        settle: false,
        beforePump: (db) async {
          await _seedMoney(db);
          listId = await _seedShoppingList(db);
        },
        overrides: LockFixture.empty().overrides,
      );
      app.router.go(AppRoutes.recordListOf(listId));
      await _frames(tester, 20);

      expect(find.byType(ListItemTile), findsNWidgets(4));
      expect(find.text(_remaining(4)), findsWidgets);

      await tester.tap(find.text('رز'));
      await _until(
        tester,
        'the tick to be stored',
        () => find.text(_remaining(3)).evaluate().isNotEmpty,
      );

      final service = ListService(app.repos);
      final lines = await _work(tester, () => service.lines(listId));
      final rice = lines.firstWhere((l) => l.title == 'رز');
      expect(rice.done, isTrue);
      expect(rice.doneAt, isNotNull, reason: 'the moment he ticked it is kept');
      expect(lines.where((l) => l.done).length, 1);
      await _expireToasts(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('turning the ticked part into one expense', () {
    testWidgets('ar: he posts it, the envelope\'s spend changes, and the undo takes it back', (tester) async {
      late String listId;
      final app = await pumpMadarApp(
        tester,
        initialLocation: AppRoutes.home,
        now: _now,
        settle: false,
        beforePump: (db) async {
          await _seedMoney(db);
          listId = await _seedShoppingList(db, ticked: true);
        },
        overrides: LockFixture.empty().overrides,
      );
      app.router.go(AppRoutes.recordListOf(listId));
      await _frames(tester, 24);

      // The preview, in his words and his digits: «٣ أغراض — ٨٫٠٠٠ د.أ».
      final summary = tester.widget<Text>(find.byKey(const ValueKey('lists.post.summary')));
      expect(summary.data, contains('٨'));
      expect(find.byKey(const ValueKey('lists.post.button')), findsOneWidget);
      expect(await _work(tester, () => app.repos.transactions.count()), 0);

      await tester.tap(find.byKey(const ValueKey('lists.post.button')));
      await _until(
        tester,
        'the expense to be written',
        () => find.byKey(const ValueKey('lists.post.button')).evaluate().isEmpty,
      );

      // Read back from the database: one expense of exactly 8.000 on «بقالة».
      var txs = await _work(tester, () => app.repos.transactions.getAll());
      expect(txs.length, 1);
      expect(txs.single.amountMilli, 8000);
      expect(txs.single.budgetItemId, 'food');
      expect(txs.single.walletId, 'cash');
      expect(await _spentOnFood(tester, app), 8000);

      // The list says it was posted, and the button is gone.
      expect(find.byKey(const ValueKey('lists.post.button')), findsNothing);
      expect(find.text(_ar.listsPostedKeepsOpen), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('lists.post.summary'))).data,
        contains('بقالة'),
        reason: 'it says what was posted and where',
      );

      // Undo from the toast.
      await tester.tap(find.text(_ar.actionUndo).last);
      await _until(
        tester,
        'the expense to be taken back',
        () => find.byKey(const ValueKey('lists.post.button')).evaluate().isNotEmpty,
      );
      txs = await _work(tester, () => app.repos.transactions.getAll());
      expect(txs, isEmpty);
      expect(await _spentOnFood(tester, app), 0);

      // His ticks survived the undo.
      final lines = await _work(tester, () => ListService(app.repos).lines(listId));
      expect(lines.where((l) => l.done).length, 3);
      await _expireToasts(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ar: a posted list can never be posted again, and the rest stays on it', (tester) async {
      late String listId;
      final app = await pumpMadarApp(
        tester,
        initialLocation: AppRoutes.home,
        now: _now,
        settle: false,
        beforePump: (db) async {
          await _seedMoney(db);
          listId = await _seedShoppingList(db, ticked: true);
        },
        overrides: LockFixture.empty().overrides,
      );
      app.router.go(AppRoutes.recordListOf(listId));
      await _frames(tester, 24);

      await tester.tap(find.byKey(const ValueKey('lists.post.button')));
      await _until(
        tester,
        'the expense to be written',
        () => find.byKey(const ValueKey('lists.post.button')).evaluate().isEmpty,
      );
      await _expireToasts(tester);

      // Leaving and coming back: still posted, still no button, and the
      // bar says why instead of charging him again.
      app.router.go(AppRoutes.home);
      await _frames(tester, 10);
      app.router.go(AppRoutes.recordListOf(listId));
      await _frames(tester, 24);

      expect(find.byKey(const ValueKey('lists.post.button')), findsNothing);
      final summary = tester.widget<Text>(find.byKey(const ValueKey('lists.post.summary')));
      expect(summary.data, contains('بقالة'));
      expect(await _work(tester, () => app.repos.transactions.count()), 1, reason: 'charged once, not twice');
      expect(await _spentOnFood(tester, app), 8000);

      // What he did not buy is still on the list, still open.
      final bundle = await _work(tester, () => ListService(app.repos).bundle(listId));
      expect([for (final l in bundle!.open) l.title], ['خبز']);
      expect(find.text('خبز'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('en: the same posting in English writes the same one expense', (tester) async {
      late String listId;
      final app = await pumpMadarApp(
        tester,
        settings: const AppSettings(onboarded: true, languageCode: 'en'),
        initialLocation: AppRoutes.home,
        now: _now,
        settle: false,
        beforePump: (db) async {
          await _seedMoney(db);
          listId = await _seedShoppingList(db, ticked: true);
        },
        overrides: LockFixture.empty().overrides,
      );
      app.router.go(AppRoutes.recordListOf(listId));
      await _frames(tester, 24);

      expect(find.text(_en.listsPostButton), findsOneWidget);
      // The amount is bidi-isolated and the currency is joined to it with
      // a non-breaking space, so the preview is read in pieces.
      final summary = BidiIsolate.strip(
        tester.widget<Text>(find.byKey(const ValueKey('lists.post.summary'))).data ?? '',
      );
      expect(summary, startsWith('3 items'));
      expect(summary.replaceAll('\u00a0', ' '), endsWith('8.000 JOD'));

      await tester.tap(find.byKey(const ValueKey('lists.post.button')));
      await _until(
        tester,
        'the expense to be written',
        () => find.byKey(const ValueKey('lists.post.button')).evaluate().isEmpty,
      );
      final txs = await _work(tester, () => app.repos.transactions.getAll());
      expect(txs.single.amountMilli, 8000);
      expect(txs.single.budgetItemId, 'food');
      expect(find.text(_en.listsPostedKeepsOpen), findsOneWidget);
      await _expireToasts(tester);
      expect(tester.takeException(), isNull);
    });
  });
}

/// What the budget says «بقالة» spent this month – computed the way the
/// Spending tab computes it, from the rows in the database.
Future<int> _spentOnFood(WidgetTester tester, TestApp app) async {
  return _work(tester, () async {
    final repos = app.repos;
    final items = await repos.budgetItems.getAll();
    final txs = await repos.transactions.getAll();
    final wallets = {for (final w in await repos.wallets.getAll()) w.id: w.currency};
    final math = BudgetMath(
      [for (final r in items) budgetNodeOf(r)],
      settings: const BudgetSettings(baseCurrency: 'JOD'),
    );
    final report = math.spend(BudgetRepository.toBudgetTxs(txs, wallets), BudgetWindow.month(_now));
    return report.byId['food']?.spentMilli ?? 0;
  });
}
