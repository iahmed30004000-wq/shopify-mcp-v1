// The shared list engine (Part 3b): one list on any host record, ordered
// lines he ticks, exact money, and an undo for every write.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/money.dart';
import 'package:madar/features/lists/lists.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late MadarDatabase db;
  late Repositories repos;
  late ListService service;
  final now = DateTime(2026, 10, 13, 18, 30);
  const food = ListHost(ListHost.budgetItems, 'budget-food');
  const trip = ListHost(ListHost.trips, 'trip-amman');

  setUp(() {
    db = MadarDatabase(NativeDatabase.memory());
    repos = Repositories(db);
    service = ListService(repos, clock: () => now);
  });

  tearDown(() => db.close());

  /// A list on [host] with [titles] in order.
  Future<RecordListRow> seed(ListHost host, {String name = 'أغراض البقالة', List<String> titles = const []}) async {
    final (row, _) = await service.addList(host, ListDraft(name: name, currency: 'JOD'));
    await service.addItems(row.id, titles);
    return row;
  }

  group('a fresh install', () {
    test('starts with no list and no item at all – nothing is ever suggested', () async {
      expect(await repos.recordLists.count(), 0);
      expect(await repos.recordListItems.count(), 0);
      expect(await service.listsOf(food), isEmpty);
      expect(await service.bundle('whatever'), isNull);
    });
  });

  group('a list belongs to a host record', () {
    test('two hosts never see each other\'s lists, whatever the table', () async {
      await seed(food, name: 'بقالة');
      await seed(trip, name: 'شنطة');
      await seed(const ListHost(ListHost.budgetItems, 'budget-fuel'), name: 'بنزين');

      expect([for (final r in await service.listsOf(food)) r.name], ['بقالة']);
      expect([for (final r in await service.listsOf(trip)) r.name], ['شنطة']);
      expect(await repos.recordLists.count(), 3);
    });

    test('the host pair is stored as written, so a new host costs nothing', () async {
      final row = await seed(const ListHost('pantry_items', 'p1'), name: 'المونة');
      final bundle = await service.bundle(row.id);
      expect(bundle!.host, const ListHost('pantry_items', 'p1'));
    });

    test('a list whose host was deleted still reads, ticks and keeps its name', () async {
      await repos.budgetItems.insert(BudgetItemsCompanion.insert(id: const Value('budget-food'), name: 'بقالة'));
      final row = await seed(food, titles: ['رز', 'زيت']);
      await repos.budgetItems.delete('budget-food');

      final bundle = await service.bundle(row.id);
      expect(bundle, isNotNull, reason: 'nothing cascades: the list is his, not the envelope\'s');
      expect(bundle!.name, 'أغراض البقالة');
      expect(bundle.lines.length, 2);
      expect(await repos.budgetItems.byId('budget-food'), isNull);

      // And it still ticks.
      final undo = await service.setDone(bundle.items.first, true);
      expect((await service.totals(row.id)).done, 1);
      await undo();
      expect((await service.totals(row.id)).done, 0);
    });

    test('deleting a host\'s lists takes their items with them, and the undo brings both back', () async {
      final a = await seed(food, name: 'بقالة', titles: ['رز', 'زيت']);
      final b = await seed(food, name: 'خضرة', titles: ['بندورة']);
      await seed(trip, name: 'شنطة', titles: ['جواز']);

      final undo = await service.deleteForHost(food);
      expect(await service.listsOf(food), isEmpty);
      expect(await repos.recordListItems.count(), 1, reason: 'the trip\'s item stays');

      await undo();
      expect([for (final r in await service.listsOf(food)) r.name], ['بقالة', 'خضرة']);
      expect((await service.totals(a.id)).total, 2);
      expect((await service.totals(b.id)).total, 1);
    });
  });

  group('order', () {
    test('items come back in the order he added them', () async {
      final row = await seed(food, titles: ['رز', 'زيت', 'لبن']);
      expect([for (final l in await service.lines(row.id)) l.title], ['رز', 'زيت', 'لبن']);
    });

    test('a new item always lands at the end, even after a reorder', () async {
      final row = await seed(food, titles: ['رز', 'زيت', 'لبن']);
      var lines = await service.lines(row.id);
      await service.reorderItems([lines[2].id, lines[0].id, lines[1].id]);
      expect([for (final l in await service.lines(row.id)) l.title], ['لبن', 'رز', 'زيت']);

      await service.addItem(row.id, const ListItemDraft(title: 'خبز'));
      expect([for (final l in await service.lines(row.id)) l.title], ['لبن', 'رز', 'زيت', 'خبز']);
    });

    test('reordering one list never moves another list\'s items', () async {
      final a = await seed(food, name: 'بقالة', titles: ['رز', 'زيت']);
      final b = await seed(food, name: 'خضرة', titles: ['بندورة', 'خيار']);
      final lines = await service.lines(a.id);
      await service.reorderItems([lines[1].id, lines[0].id]);

      expect([for (final l in await service.lines(a.id)) l.title], ['زيت', 'رز']);
      expect([for (final l in await service.lines(b.id)) l.title], ['بندورة', 'خيار']);
    });

    test('lists themselves reorder on their host', () async {
      final a = await seed(food, name: 'بقالة');
      final b = await seed(food, name: 'خضرة');
      await service.reorderLists([b.id, a.id]);
      expect([for (final r in await service.listsOf(food)) r.name], ['خضرة', 'بقالة']);
    });
  });

  group('ticking', () {
    test('a tick stamps the moment, an un-tick clears it, and undo restores both', () async {
      final row = await seed(food, titles: ['رز']);
      final item = (await service.itemRows(row.id)).single;
      expect(item.done, isFalse);
      expect(item.doneAt, isNull);

      final undoTick = await service.setDone(item, true);
      var fresh = (await service.itemRows(row.id)).single;
      expect(fresh.done, isTrue);
      expect(fresh.doneAt, now);

      await undoTick();
      fresh = (await service.itemRows(row.id)).single;
      expect(fresh.done, isFalse);
      expect(fresh.doneAt, isNull, reason: 'the undo of a tick takes the stamp away too');

      // Un-ticking something ticked earlier, and undoing that.
      final earlier = DateTime(2026, 10, 1, 9);
      await service.setDone(fresh, true, at: earlier);
      fresh = (await service.itemRows(row.id)).single;
      final undoUntick = await service.setDone(fresh, false);
      expect((await service.itemRows(row.id)).single.doneAt, isNull);
      await undoUntick();
      expect((await service.itemRows(row.id)).single.doneAt, earlier, reason: 'his original moment comes back');
    });

    test('un-ticking the whole list is one undo, and leaves the untouched lines alone', () async {
      final row = await seed(food, titles: ['رز', 'زيت', 'لبن']);
      final items = await service.itemRows(row.id);
      await service.setDone(items[0], true, at: DateTime(2026, 10, 2, 8));
      await service.setDone(items[1], true);
      expect((await service.totals(row.id)).done, 2);

      final undo = await service.setAllDone(row.id, false);
      expect((await service.totals(row.id)).done, 0);

      await undo();
      final after = await service.itemRows(row.id);
      expect(after[0].done, isTrue);
      expect(after[0].doneAt, DateTime(2026, 10, 2, 8));
      expect(after[1].done, isTrue);
      expect(after[2].done, isFalse);
      expect(after[2].doneAt, isNull);
    });

    test('clearing the ticked lines keeps the open ones, and the undo puts them back in place', () async {
      final row = await seed(food, titles: ['رز', 'زيت', 'لبن']);
      final items = await service.itemRows(row.id);
      await service.setDone(items[0], true);
      await service.setDone(items[2], true);

      final (count, undo) = await service.deleteDone(row.id);
      expect(count, 2);
      expect([for (final l in await service.lines(row.id)) l.title], ['زيت']);

      await undo();
      expect([for (final l in await service.lines(row.id)) l.title], ['رز', 'زيت', 'لبن']);
      expect((await service.totals(row.id)).done, 2);
    });
  });

  group('quantities, units and prices', () {
    test('what he typed is kept, and blank or impossible values become nothing', () async {
      final row = await seed(food);
      await service.addItem(
        row.id,
        const ListItemDraft(title: '  رز  ', quantity: 2.5, unit: '  كيلو ', priceMilli: 1500, note: '  من أبو علي '),
      );
      await service.addItem(row.id, const ListItemDraft(title: 'زيت', quantity: 0, unit: '   ', priceMilli: -5));

      final lines = await service.lines(row.id);
      expect(lines[0].title, 'رز');
      expect(lines[0].quantity, 2.5);
      expect(lines[0].unit, 'كيلو');
      expect(lines[0].priceMilli, 1500);
      expect(lines[0].note, 'من أبو علي');
      expect(lines[1].quantity, isNull, reason: 'a quantity of zero is no quantity');
      expect(lines[1].unit, isNull);
      expect(lines[1].priceMilli, isNull, reason: 'a price is never negative');
    });

    test('a line with a quantity costs price × quantity, exactly', () {
      // «٢٫٥ كيلو رز بـ ١٫٥٠٠ د.أ للكيلو» = ٣٫٧٥٠ د.أ
      expect(const ListLine(id: 'a', listId: 'l', title: 'رز', quantity: 2.5, priceMilli: 1500).totalMilli, 3750);
      // Three tins at 2.500 each.
      expect(const ListLine(id: 'b', listId: 'l', title: 'زيت', quantity: 3, priceMilli: 2500).totalMilli, 7500);
      // No quantity: the price is the line.
      expect(const ListLine(id: 'c', listId: 'l', title: 'لبن', priceMilli: 800).totalMilli, 800);
      // No price at all (a packing list).
      expect(const ListLine(id: 'd', listId: 'l', title: 'جواز').totalMilli, isNull);
      expect(const ListLine(id: 'e', listId: 'l', title: 'شاحن', quantity: 2).totalMilli, isNull);
    });

    test('a fraction of a fils rounds once, half away from zero', () {
      // 0.5 × 1 milli = 0.5 → 1 (the single rounding rule of Madar money).
      expect(const ListLine(id: 'a', listId: 'l', title: 'x', quantity: 0.5, priceMilli: 1).totalMilli, 1);
      // 1.5 × 1 = 1.5 → 2, and 2.5 × 1 = 2.5 → 3.
      expect(const ListLine(id: 'b', listId: 'l', title: 'x', quantity: 1.5, priceMilli: 1).totalMilli, 2);
      expect(const ListLine(id: 'c', listId: 'l', title: 'x', quantity: 2.5, priceMilli: 1).totalMilli, 3);
      // 0.333 kg × 3.000 = 0.999 → 999 milli, not 1 000.
      expect(const ListLine(id: 'd', listId: 'l', title: 'x', quantity: 0.333, priceMilli: 3000).totalMilli, 999);
      // A third of a kilo of something at 1 fil: 0.333 → 0 (not half yet).
      expect(const ListLine(id: 'e', listId: 'l', title: 'x', quantity: 0.333, priceMilli: 1).totalMilli, 0);
      // A quantity of zero costs nothing, whatever the price.
      expect(const ListLine(id: 'f', listId: 'l', title: 'x', quantity: 0, priceMilli: 9999).totalMilli, 0);
    });

    test('the price he types is read as whole dinars, in his own digits', () {
      // «٨» is 8 JOD = 8 000 milli, never 8 milli.
      expect(MoneyText.parseMilli('٨'), 8000);
      expect(MoneyText.parseMilli('8'), 8000);
      expect(MoneyText.parseMilli('١٫٥'), 1500);
      expect(MoneyText.parseMilli('0.250'), 250);
      expect(Money.tryParse('٨ د.أ')!.milli, 8000);
    });

    test('the totals of a list add the ticked and the open apart, exactly', () async {
      final row = await seed(food);
      await service.addItem(row.id, const ListItemDraft(title: 'رز', quantity: 2.5, unit: 'كيلو', priceMilli: 1500));
      await service.addItem(row.id, const ListItemDraft(title: 'زيت', priceMilli: 2500));
      await service.addItem(row.id, const ListItemDraft(title: 'لبن')); // no price
      await service.addItem(row.id, const ListItemDraft(title: 'خبز', priceMilli: 1000));

      final items = await service.itemRows(row.id);
      await service.setDone(items[0], true); // 3.750
      await service.setDone(items[1], true); // 2.500
      await service.setDone(items[2], true); // nothing

      final totals = (await service.bundle(row.id))!.totals;
      expect(totals.total, 4);
      expect(totals.done, 3);
      expect(totals.pricedDone, 2);
      expect(totals.doneAmountMilli, 6250, reason: '٣٫٧٥٠ + ٢٫٥٠٠');
      expect(totals.openAmountMilli, 1000);
      expect(totals.allAmountMilli, 7250);
      expect(totals.remaining, 1);
      expect(totals.complete, isFalse);
      expect(totals.fraction, closeTo(0.75, 0.0001));
    });

    test('an empty list is never complete and adds up to nothing', () {
      expect(ListTotals.of(const []), ListTotals.empty);
      expect(ListTotals.empty.complete, isFalse);
      expect(ListTotals.empty.fraction, 0);
      expect(ListTotals.empty.hasAmounts, isFalse);
    });
  });

  group('writing', () {
    test('adding an item returns the undo that removes exactly it', () async {
      final row = await seed(food, titles: ['رز']);
      final (added, undo) = await service.addItem(row.id, const ListItemDraft(title: 'زيت'));
      expect((await service.lines(row.id)).length, 2);
      await undo();
      expect([for (final l in await service.lines(row.id)) l.title], ['رز']);
      expect(await service.item(added.id), isNull);
    });

    test('pasting several lines at once is one undo, and blank lines are skipped', () async {
      final row = await seed(food);
      final (rows, undo) = await service.addItems(row.id, ['رز', '   ', 'زيت', '']);
      expect(rows.length, 2);
      expect([for (final l in await service.lines(row.id)) l.title], ['رز', 'زيت']);
      await undo();
      expect(await service.lines(row.id), isEmpty);
    });

    test('editing a line keeps its place and its tick; undo restores every field', () async {
      final row = await seed(food, titles: ['رز', 'زيت']);
      final items = await service.itemRows(row.id);
      await service.setDone(items[0], true);
      final before = (await service.itemRows(row.id)).first;

      final undo = await service.updateItem(
        before,
        const ListItemDraft(title: 'رز بسمتي', quantity: 5, unit: 'كيلو', priceMilli: 2000),
      );
      var lines = await service.lines(row.id);
      expect(lines.first.title, 'رز بسمتي');
      expect(lines.first.totalMilli, 10000);
      expect(lines.first.done, isTrue, reason: 'editing never un-ticks');
      expect([for (final l in lines) l.title], ['رز بسمتي', 'زيت']);

      await undo();
      lines = await service.lines(row.id);
      expect(lines.first.title, 'رز');
      expect(lines.first.quantity, isNull);
      expect(lines.first.priceMilli, isNull);
      expect(lines.first.done, isTrue);
    });

    test('deleting a list deletes its items; the undo restores them with their ticks and order', () async {
      final row = await seed(food, titles: ['رز', 'زيت', 'لبن']);
      final items = await service.itemRows(row.id);
      await service.setDone(items[1], true);

      final undo = await service.deleteList(row.id);
      expect(await service.list(row.id), isNull);
      expect(await repos.recordListItems.count(), 0);

      await undo();
      final bundle = await service.bundle(row.id);
      expect(bundle!.name, 'أغراض البقالة');
      expect([for (final l in bundle.lines) l.title], ['رز', 'زيت', 'لبن']);
      expect(bundle.lines[1].done, isTrue);
    });

    test('a copy starts un-ticked and never posted – next week\'s shopping', () async {
      final row = await seed(food, titles: ['رز', 'زيت']);
      final items = await service.itemRows(row.id);
      await service.setDone(items[0], true);
      await service.claimPost(row.id, amountMilli: 1500, itemCount: 1);

      final (copy, undo) = await service.duplicateList(row, name: 'بقالة الأسبوع الجاي');
      final copied = await service.bundle(copy.id);
      expect(copied!.name, 'بقالة الأسبوع الجاي');
      expect(copied.currency, 'JOD');
      expect(copied.posted, isFalse);
      expect([for (final l in copied.lines) l.title], ['رز', 'زيت']);
      expect(copied.totals.done, 0, reason: 'he has bought none of it yet');

      await undo();
      expect(await service.list(copy.id), isNull);
      expect(await service.list(row.id), isNotNull);
    });

    test('a line moves to another list and lands at its end; undo puts it back', () async {
      final pantry = await seed(const ListHost('pantry_items', 'p1'), name: 'المونة', titles: ['رز', 'سكر']);
      final shopping = await seed(food, titles: ['زيت']);
      final rice = (await service.itemRows(pantry.id)).first;

      final undo = await service.moveItem(rice, shopping.id);
      expect([for (final l in await service.lines(pantry.id)) l.title], ['سكر']);
      expect([for (final l in await service.lines(shopping.id)) l.title], ['زيت', 'رز']);

      await undo();
      expect([for (final l in await service.lines(pantry.id)) l.title], ['رز', 'سكر']);
      expect([for (final l in await service.lines(shopping.id)) l.title], ['زيت']);
    });

    test('renaming a list never touches the currency its prices were typed in', () async {
      final row = await seed(food);
      final undo = await service.updateList(row, const ListDraft(name: 'بقالة الشهر', currency: 'USD'));
      var fresh = await service.list(row.id);
      expect(fresh!.name, 'بقالة الشهر');
      expect(fresh.currency, 'JOD');
      await undo();
      fresh = await service.list(row.id);
      expect(fresh!.name, 'أغراض البقالة');
    });
  });

  group('the posted mark (the guard against a double charge)', () {
    test('the first claim wins and is stamped; every later one is refused', () async {
      final row = await seed(food, titles: ['رز']);
      expect(await service.claimPost(row.id, amountMilli: 8000, itemCount: 3), isTrue);

      final stamped = await service.list(row.id);
      expect(stamped!.postedAt, now);
      expect(stamped.postedAmountMilli, 8000);
      expect(stamped.postedItemCount, 3);

      expect(await service.claimPost(row.id, amountMilli: 8000, itemCount: 3), isFalse);
      expect(await service.claimPost(row.id, amountMilli: 1, itemCount: 1), isFalse);
      final again = await service.list(row.id);
      expect(again!.postedAmountMilli, 8000, reason: 'a refused claim changes nothing');
    });

    test('two claims racing each other: exactly one wins', () async {
      final row = await seed(food, titles: ['رز']);
      final results = await Future.wait([
        service.claimPost(row.id, amountMilli: 8000, itemCount: 3),
        service.claimPost(row.id, amountMilli: 8000, itemCount: 3),
        service.claimPost(row.id, amountMilli: 8000, itemCount: 3),
      ]);
      expect(results.where((won) => won).length, 1);
    });

    test('a list that is gone cannot be claimed', () async {
      expect(await service.claimPost('nope', amountMilli: 1, itemCount: 1), isFalse);
    });

    test('clearing the mark opens the list again and keeps every tick', () async {
      final row = await seed(food, titles: ['رز', 'زيت']);
      final items = await service.itemRows(row.id);
      await service.setDone(items[0], true);
      await service.claimPost(row.id, amountMilli: 1500, itemCount: 1, txId: 'tx-1');
      expect((await service.bundle(row.id))!.posted, isTrue);

      await service.clearPost(row.id);
      final bundle = await service.bundle(row.id);
      expect(bundle!.posted, isFalse);
      expect(bundle.row.postedTxId, isNull);
      expect(bundle.row.postedAmountMilli, isNull);
      expect(bundle.totals.done, 1, reason: 'the undo of a post never un-ticks what he bought');
      expect(await service.claimPost(row.id, amountMilli: 1500, itemCount: 1), isTrue);
    });
  });

  group('what posting would do (pure)', () {
    ListTotals totals({int total = 3, int done = 2, int amount = 8000, int priced = 2}) =>
        ListTotals(total: total, done: done, doneAmountMilli: amount, openAmountMilli: 0, pricedDone: priced);

    test('the ticked part, its count and its amount', () {
      final plan = ListPostPlan.of(totals: totals(), currency: 'jod', posted: false, hasWallet: true);
      expect(plan.canPost, isTrue);
      expect(plan.itemCount, 2);
      expect(plan.amountMilli, 8000);
      expect(plan.currency, 'JOD');
      expect(plan.unpricedCount, 0);
    });

    test('a posted list is refused first, whatever else changed', () {
      final plan = ListPostPlan.of(totals: totals(), currency: 'JOD', posted: true, hasWallet: true);
      expect(plan.refusal, ListPostRefusal.alreadyPosted);
      expect(plan.canPost, isFalse);
    });

    test('nothing ticked, no price, no wallet – each says why', () {
      expect(
        ListPostPlan.of(totals: totals(done: 0, amount: 0, priced: 0), currency: 'JOD', posted: false, hasWallet: true)
            .refusal,
        ListPostRefusal.nothingTicked,
      );
      expect(
        ListPostPlan.of(totals: totals(amount: 0, priced: 0), currency: 'JOD', posted: false, hasWallet: true).refusal,
        ListPostRefusal.noAmount,
      );
      expect(
        ListPostPlan.of(totals: totals(), currency: 'JOD', posted: false, hasWallet: false).refusal,
        ListPostRefusal.noWallet,
      );
    });

    test('ticked lines without a price travel with the entry but add nothing', () {
      final plan = ListPostPlan.of(
        totals: const ListTotals(total: 4, done: 3, doneAmountMilli: 6250, openAmountMilli: 1000, pricedDone: 2),
        currency: 'JOD',
        posted: false,
        hasWallet: true,
      );
      expect(plan.itemCount, 3);
      expect(plan.pricedCount, 2);
      expect(plan.unpricedCount, 1);
      expect(plan.amountMilli, 6250);
    });
  });

  group('live views', () {
    test('a list\'s bundle follows every write, and ends as null when it is deleted', () async {
      final row = await seed(food, titles: ['رز']);
      final seen = <String>[];
      final sub = service.watchBundle(row.id).listen((b) => seen.add(b == null ? 'gone' : '${b.totals.done}/${b.totals.total}'));
      await pumpEventQueue();

      await service.addItem(row.id, const ListItemDraft(title: 'زيت'));
      await pumpEventQueue();
      await service.setDone((await service.itemRows(row.id)).first, true);
      await pumpEventQueue();
      await service.deleteList(row.id);
      await pumpEventQueue();
      await sub.cancel();

      expect(seen.first, '0/1');
      expect(seen, contains('0/2'));
      expect(seen, contains('1/2'));
      expect(seen.last, 'gone');
    });

    test('a host\'s totals come keyed by list, and a host with no list sees an empty map', () async {
      final a = await seed(food, name: 'بقالة', titles: ['رز', 'زيت']);
      final b = await seed(food, name: 'خضرة', titles: ['بندورة']);
      await service.setDone((await service.itemRows(a.id)).first, true);

      final totals = await service.watchHostTotals(food).first;
      expect(totals[a.id]!.done, 1);
      expect(totals[a.id]!.total, 2);
      expect(totals[b.id]!.total, 1);
      expect(await service.watchHostTotals(trip).first, isEmpty);
    });

    test('a host\'s row knows how many lists it carries', () async {
      await seed(food, name: 'بقالة');
      await seed(food, name: 'خضرة');
      await seed(const ListHost(ListHost.budgetItems, 'budget-fuel'), name: 'بنزين');
      final counts = await service.watchHostCounts(ListHost.budgetItems).first;
      expect(counts['budget-food'], 2);
      expect(counts['budget-fuel'], 1);
      expect(counts['budget-rent'], isNull);
    });
  });
}
