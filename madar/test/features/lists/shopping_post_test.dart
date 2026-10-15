// The shopping list under a budget envelope becomes ONE expense on that
// envelope – read back from the database – and never twice.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/budget_math.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/domain/money.dart';
import 'package:madar/features/lists/lists.dart';
import 'package:madar/features/money/budget/budget.dart';
import 'package:madar/features/money/budget/data/shopping_post_service.dart';
import 'package:madar/features/money/ledger/ledger.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late MadarDatabase db;
  late Repositories repos;
  late ListService lists;
  late LedgerService ledger;
  late ShoppingPostService posting;
  final now = DateTime(2026, 10, 13, 19, 20);
  const envelope = ListHost(ListHost.budgetItems, 'food');

  setUp(() async {
    db = MadarDatabase(NativeDatabase.memory(), seed: const SeedOptions());
    repos = Repositories(db);
    // Seeding happens on the first query (beforeOpen).
    await db.customSelect('SELECT 1').get();
    lists = ListService(repos, clock: () => now);
    ledger = LedgerService(repos, clock: () => now);
    posting = ShoppingPostService(
      lists: lists,
      ledger: ledger,
      repos: repos,
      clock: () => now,
      currencies: const ListCurrencies(base: 'JOD', decimals: {'JOD': 3, 'USD': 2}),
    );
    await repos.budgetItems.insert(
      BudgetItemsCompanion.insert(id: const Value('food'), name: 'بقالة', amountMilli: const Value(200000)),
    );
    await repos.wallets.insert(WalletsCompanion.insert(id: const Value('cash'), name: 'كاش', currency: 'JOD'));
  });

  tearDown(() => db.close());

  /// «بقالة»: ☐ رز ٢ كيلو × ١٫٥٠٠ ☐ زيت ٢٫٥٠٠ ☐ لبن ٢ × ١٫٢٥٠ ☐ خبز بلا سعر
  /// – the owner's own example: the three of them are ٨٫٠٠٠ د.أ.
  Future<RecordListRow> shoppingList({String name = 'أغراض البقالة', String? currency = 'JOD'}) async {
    final (row, _) = await lists.addList(envelope, ListDraft(name: name, currency: currency));
    await lists.addItem(row.id, const ListItemDraft(title: 'رز', quantity: 2, unit: 'كيلو', priceMilli: 1500));
    await lists.addItem(row.id, const ListItemDraft(title: 'زيت', priceMilli: 2500));
    await lists.addItem(row.id, const ListItemDraft(title: 'لبن', quantity: 2, priceMilli: 1250));
    await lists.addItem(row.id, const ListItemDraft(title: 'خبز'));
    return row;
  }

  Future<void> tick(String listId, Iterable<String> titles) async {
    for (final r in await lists.itemRows(listId)) {
      if (titles.contains(r.title)) await lists.setDone(r, true);
    }
  }

  /// Everything the ledger holds (read back, never from the service).
  Future<List<TransactionRow>> entries() => repos.transactions.getAll();

  /// What the budget says this envelope spent this month, computed the way
  /// the Spending tab computes it.
  Future<int> spentOnFood() async {
    final items = await repos.budgetItems.getAll();
    final txs = await repos.transactions.getAll();
    final wallets = {for (final w in await repos.wallets.getAll()) w.id: w.currency};
    final math = BudgetMath(
      [for (final r in items) budgetNodeOf(r)],
      settings: const BudgetSettings(baseCurrency: 'JOD'),
    );
    final report = math.spend(BudgetRepository.toBudgetTxs(txs, wallets), BudgetWindow.month(now));
    return report.byId['food']?.spentMilli ?? 0;
  }

  group('what the bar shows before he taps', () {
    test('three ticked items of ٨٫٠٠٠ د.أ – the preview he sees', () async {
      final row = await shoppingList();
      await tick(row.id, ['رز', 'زيت', 'لبن']); // ٣٫٠٠٠ + ٢٫٥٠٠ + ٢٫٥٠٠

      final plan = await posting.preview(row.id);
      expect(plan.canPost, isTrue);
      expect(plan.itemCount, 3);
      expect(plan.amountMilli, 8000, reason: '«٣ أغراض — ٨٫٠٠٠ د.أ»');
      expect(plan.currency, 'JOD');
      expect(await entries(), isEmpty, reason: 'a preview never writes anything');
    });

    test('nothing ticked, no price, and no wallet each refuse with their own reason', () async {
      final row = await shoppingList();
      expect((await posting.preview(row.id)).refusal, ListPostRefusal.nothingTicked);

      await tick(row.id, ['خبز']); // ticked, but he gave it no price
      expect((await posting.preview(row.id)).refusal, ListPostRefusal.noAmount);

      await tick(row.id, ['رز']);
      expect((await posting.preview(row.id)).canPost, isTrue);

      // Only a wallet in the list's own currency can pay for it.
      await repos.wallets.setColumn('cash', 'currency', 'USD');
      expect((await posting.preview(row.id)).refusal, ListPostRefusal.noWallet);
      await repos.wallets.setColumn('cash', 'archived', true);
      expect((await posting.preview(row.id)).refusal, ListPostRefusal.noWallet);
    });

    test('a list that is not under an envelope has nothing to post on', () async {
      final (trip, _) = await lists.addList(const ListHost(ListHost.trips, 't1'), const ListDraft(name: 'شنطة'));
      await lists.addItem(trip.id, const ListItemDraft(title: 'جواز', priceMilli: 1000));
      await tick(trip.id, ['جواز']);
      expect((await posting.preview(trip.id)).refusal, ListPostRefusal.notAnEnvelope);
      expect((await posting.post(trip.id)).posted, isFalse);
      expect(await entries(), isEmpty);
    });

    test('a list that is gone refuses instead of throwing', () async {
      expect((await posting.preview('nope')).refusal, ListPostRefusal.listGone);
      expect((await posting.post('nope')).posted, isFalse);
    });
  });

  group('posting the ticked part', () {
    test('writes exactly one expense on that envelope, for the exact amount', () async {
      final row = await shoppingList();
      await tick(row.id, ['رز', 'زيت', 'لبن']);
      expect(await spentOnFood(), 0);

      final result = await posting.post(row.id);
      expect(result.posted, isTrue);
      expect(result.envelopeName, 'بقالة');

      final written = await entries();
      expect(written.length, 1);
      final tx = written.single;
      expect(tx.amountMilli, 8000);
      expect(tx.kind, TxKind.expense);
      expect(tx.budgetItemId, 'food');
      expect(tx.walletId, 'cash');
      expect(tx.note, 'أغراض البقالة', reason: 'the entry says which list it came from');
      expect(tx.date, DateTime(2026, 10, 13));

      // The envelope's spend changed by exactly that, read from the data.
      expect(await spentOnFood(), 8000);

      // And the list says it was posted, with what it posted.
      final posted = (await lists.bundle(row.id))!;
      expect(posted.posted, isTrue);
      expect(posted.row.postedAt, now);
      expect(posted.row.postedTxId, tx.id);
      expect(posted.row.postedAmountMilli, 8000);
      expect(posted.row.postedItemCount, 3);
    });

    test('the un-ticked items stay on the list – he did not buy them', () async {
      final row = await shoppingList();
      await tick(row.id, ['رز', 'زيت', 'لبن']);
      await posting.post(row.id);

      final bundle = (await lists.bundle(row.id))!;
      expect([for (final l in bundle.lines) l.title], ['رز', 'زيت', 'لبن', 'خبز']);
      expect([for (final l in bundle.open) l.title], ['خبز']);
      expect(bundle.totals.done, 3, reason: 'posting never un-ticks what he bought');
    });

    test('the money activity is recorded once, like any other entry', () async {
      final row = await shoppingList();
      await tick(row.id, ['رز']);
      await posting.post(row.id);
      final activity = await repos.activityLog.getAll();
      expect(activity.where((a) => a.refTable == 'transactions').length, 1);
      expect(activity.single.kind, LedgerService.activityKind);
    });

    test('a two-decimal currency keeps its own decimals and its own wallet', () async {
      await repos.budgetItems.insert(
        BudgetItemsCompanion.insert(id: const Value('subs'), name: 'اشتراكات', currency: const Value('USD')),
      );
      await repos.wallets.insert(WalletsCompanion.insert(id: const Value('card'), name: 'كارد', currency: 'USD'));
      final (row, _) = await lists.addList(
        const ListHost(ListHost.budgetItems, 'subs'),
        const ListDraft(name: 'اشتراكات', currency: 'USD'),
      );
      await lists.addItem(row.id, const ListItemDraft(title: 'تخزين', priceMilli: 9990));
      await tick(row.id, ['تخزين']);

      final result = await posting.post(row.id);
      expect(result.posted, isTrue);
      expect(result.plan.currency, 'USD');
      final tx = (await entries()).single;
      expect(tx.walletId, 'card', reason: 'the JOD wallet can never pay a USD list');
      expect(tx.amountMilli, 9990);
    });
  });

  group('it can never charge him twice', () {
    test('a second tap is refused, and no second entry is written', () async {
      final row = await shoppingList();
      await tick(row.id, ['رز', 'زيت', 'لبن']);
      final first = await posting.post(row.id);
      expect(first.posted, isTrue);

      final second = await posting.post(row.id);
      expect(second.posted, isFalse);
      expect(second.plan.refusal, ListPostRefusal.alreadyPosted);
      expect((await entries()).length, 1);
      expect(await spentOnFood(), 8000, reason: 'his envelope was charged once');
    });

    test('ticking more and tapping again is still refused: the list is posted', () async {
      final row = await shoppingList();
      await tick(row.id, ['رز']);
      await posting.post(row.id);
      await tick(row.id, ['زيت']);

      expect((await posting.preview(row.id)).refusal, ListPostRefusal.alreadyPosted);
      final again = await posting.post(row.id);
      expect(again.posted, isFalse);
      expect((await entries()).length, 1);
      expect(await spentOnFood(), 3000, reason: 'only the first post was charged');
    });

    test('two taps at the same instant write one entry, not two', () async {
      final row = await shoppingList();
      await tick(row.id, ['رز', 'زيت', 'لبن']);

      final results = await Future.wait([posting.post(row.id), posting.post(row.id), posting.post(row.id)]);
      expect(results.where((r) => r.posted).length, 1);
      expect((await entries()).length, 1);
      expect(await spentOnFood(), 8000);
    });
  });

  group('undo', () {
    test('takes the entry back, opens the list again and keeps his ticks', () async {
      final row = await shoppingList();
      await tick(row.id, ['رز', 'زيت', 'لبن']);
      final result = await posting.post(row.id);
      expect(await spentOnFood(), 8000);

      await result.undo!();

      expect(await entries(), isEmpty, reason: 'the expense is gone from the ledger');
      expect(await spentOnFood(), 0, reason: 'the envelope is back where it was');
      expect(await repos.activityLog.getAll(), isEmpty);
      final bundle = (await lists.bundle(row.id))!;
      expect(bundle.posted, isFalse);
      expect(bundle.row.postedTxId, isNull);
      expect(bundle.totals.done, 3, reason: 'he still bought those three');
    });

    test('after an undo he can post again, once', () async {
      final row = await shoppingList();
      await tick(row.id, ['رز', 'زيت', 'لبن']);
      final first = await posting.post(row.id);
      await first.undo!();

      final second = await posting.post(row.id);
      expect(second.posted, isTrue);
      expect((await entries()).single.amountMilli, 8000);
      expect((await posting.post(row.id)).posted, isFalse);
      expect((await entries()).length, 1);
    });
  });

  group('the amount is exact', () {
    test('a quantity × a price is rounded once, and the sum is integer arithmetic', () async {
      final (row, _) = await lists.addList(envelope, const ListDraft(name: 'دقّة', currency: 'JOD'));
      // 0.5 × 1 milli → 1 (half away from zero), 0.333 kg × 3.000 → 999,
      // 3 × 0.250 → 750: 1 + 999 + 750 = 1 750.
      await lists.addItem(row.id, const ListItemDraft(title: 'أ', quantity: 0.5, priceMilli: 1));
      await lists.addItem(row.id, const ListItemDraft(title: 'ب', quantity: 0.333, priceMilli: 3000));
      await lists.addItem(row.id, const ListItemDraft(title: 'ج', quantity: 3, priceMilli: 250));
      await tick(row.id, ['أ', 'ب', 'ج']);

      final plan = await posting.preview(row.id);
      expect(plan.amountMilli, 1750);
      await posting.post(row.id);
      expect((await entries()).single.amountMilli, 1750);
      expect(await spentOnFood(), 1750);
    });

    test('a price typed as «٨» is eight dinars on the envelope, not eight fils', () async {
      final (row, _) = await lists.addList(envelope, const ListDraft(name: 'بقالة', currency: 'JOD'));
      // The sheet parses what he typed into milli-units before it ever
      // reaches the engine – «٨» → 8 000.
      final typed = MoneyText.parseMilli('٨');
      await lists.addItem(row.id, ListItemDraft(title: 'لحمة', priceMilli: typed));
      await tick(row.id, ['لحمة']);

      await posting.post(row.id);
      expect((await entries()).single.amountMilli, 8000);
      expect(await spentOnFood(), 8000);
    });
  });
}
