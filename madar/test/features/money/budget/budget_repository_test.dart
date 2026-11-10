import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/budget_math.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/money/budget/budget.dart';

import 'budget_fixtures.dart';

void main() {
  late MadarDatabase db;
  late Repositories repos;
  late BudgetRepository repo;

  setUp(() async {
    db = MadarDatabase(NativeDatabase.memory(), seed: const SeedOptions());
    repos = Repositories(db);
    repo = BudgetRepository(repos, clock: () => budgetToday);
    await insertNodes(repos, specNodes());
  });
  tearDown(() => db.close());

  Future<List<String>> order(String? parent) async {
    final m = await repo.math();
    return [for (final c in m.childrenOf(parent)) c.node.id];
  }

  test('reads the whole budget with the seeded base currency and rates', () async {
    final math = await repo.math();
    expect(math.settings.baseCurrency, 'JOD');
    expect(math.settings.ratesToBase['USD'], 0.709);
    expect(math.settings.weeksPerMonth, 4);
    expect(math.totalMonthlyMilli, 350000);
    final cur = await repo.currencies();
    expect(cur.decimalsOf('JOD'), 3);
    expect(cur.decimalsOf('USD'), 2);
    expect(cur.codes.first, 'JOD');
  });

  test('add places a new item after a sibling and logs on the Money world', () async {
    const nuts = BudgetNode(id: 'nuts', parentId: 'food', name: 'Nuts', amountMilli: 10000);
    final undo = await repo.add(nuts, afterId: 'prot');
    expect(await order('food'), ['prot', 'nuts', 'spice', 'treat', 'fv']);
    final log = await repos.activity.since(DateTime(2026), planetKey: 'money');
    expect(log.single.kind, BudgetRepository.activityKind);
    expect(log.single.refId, 'nuts');
    await undo();
    expect(await order('food'), ['prot', 'spice', 'treat', 'fv']);
    // Without a sibling it goes last.
    await repo.add(const BudgetNode(id: 'z', name: 'Z', amountMilli: 1000));
    expect((await order(null)).last, 'z');
  });

  test('save writes the node; a new parent moves it to the end; undo restores it exactly', () async {
    final before = await repos.budgetItems.byId('treat');
    final math = await repo.math();
    final moved = BudgetEdits.moveTo(math, 'treat', 'fuel');
    final undo = await repo.save(moved);
    final after = await repos.budgetItems.byId('treat');
    expect(after!.parentId, 'fuel');
    expect(after.percent, closeTo(30, 1e-9));
    expect(await order('food'), ['prot', 'spice', 'fv']);
    expect(await order('fuel'), ['treat']);
    await undo();
    expect(await repos.budgetItems.byId('treat'), before);
    expect(await order('food'), ['prot', 'spice', 'treat', 'fv']);
  });

  test('delete removes the subtree, re-points expenses and obligations, and undo restores all', () async {
    await insertWallets(repos);
    await addExpense(repos, item: 'prot', milli: 5000, date: DateTime(2026, 9, 2));
    await addExpense(repos, item: 'food', milli: 7000, date: DateTime(2026, 9, 3));
    await addExpense(repos, item: 'fuel', milli: 9000, date: DateTime(2026, 9, 3));
    await repos.obligations.insert(
      ObligationsCompanion.insert(
        id: const Value('ob'),
        name: 'Market',
        amountMilli: 1000,
        currency: 'JOD',
        frequency: Recurrence.weekly,
        nextDue: DateTime(2026, 10, 1),
        budgetItemId: const Value('spice'),
      ),
    );
    // A sub-item: expenses move up to its parent.
    final undoSpice = await repo.deleteSubtree('spice');
    expect((await repos.obligations.byId('ob'))!.budgetItemId, 'food');
    await undoSpice();
    expect((await repos.obligations.byId('ob'))!.budgetItemId, 'spice');

    // A top-level item with sub-items: everything goes, expenses become
    // unassigned.
    final undo = await repo.deleteSubtree('food');
    expect(await repos.budgetItems.count(), 3);
    final txs = await repos.transactions.getAll();
    expect({for (final t in txs) t.budgetItemId}, {null, 'fuel'});
    expect((await repos.obligations.byId('ob'))!.budgetItemId, isNull);
    final math = await repo.math();
    expect(math.totalMonthlyMilli, 150000);
    await undo();
    expect(await repos.budgetItems.count(), 8);
    expect([for (final t in await repos.transactions.getAll()) t.budgetItemId], ['prot', 'food', 'fuel']);
    expect((await repos.obligations.byId('ob'))!.budgetItemId, 'spice');
    expect(await order('food'), ['prot', 'spice', 'treat', 'fv']);
    expect((await repo.math()).totalMonthlyMilli, 350000);
    // Unknown ids are a no-op.
    await (await repo.deleteSubtree('nope'))();
  });

  test('reorder one group of siblings with undo', () async {
    final undo = await repo.reorder(['fv', 'treat', 'spice', 'prot']);
    expect(await order('food'), ['fv', 'treat', 'spice', 'prot']);
    expect(await order(null), ['food', 'fuel', 'emerg', 'wife']);
    await undo();
    expect(await order('food'), ['prot', 'spice', 'treat', 'fv']);
  });

  test('weeks per month is stored in key_values and feeds the math', () async {
    expect(await repo.weeksPerMonth(), 4);
    final undo = await repo.setWeeksPerMonth(4.345);
    expect(await repos.keyValues.getJson(BudgetSettings.weeksPerMonthKey), 4.345);
    final math = await repo.math();
    expect(math['wife']!.monthlyMilli, 21725);
    expect(math.totalMonthlyMilli, 351725);
    await undo();
    expect(await repos.keyValues.contains(BudgetSettings.weeksPerMonthKey), isFalse);
    expect(() => repo.setWeeksPerMonth(0), throwsArgumentError);
    expect(weeksPerMonthOf('x'), 4);
    expect(weeksPerMonthOf(-2), 4);
    expect(weeksPerMonthOf(4.33), 4.33);
  });

  test('expenses: only expense rows since a day, in their wallet currency', () async {
    await insertWallets(repos);
    await addExpense(repos, item: 'prot', milli: 5000, date: DateTime(2026, 9, 2));
    await addExpense(repos, item: null, milli: 1999, date: DateTime(2026, 9, 3), wallet: 'usd');
    await addExpense(repos, item: 'prot', milli: 8000, date: DateTime(2026, 8, 31));
    await addExpense(repos, item: 'prot', milli: 90000, date: DateTime(2026, 9, 4), kind: TxKind.income);
    final rows = await repo.watchExpenses(since: DateTime(2026, 9, 1)).first;
    final wallets = await repo.watchWalletCurrencies().first;
    final txs = BudgetRepository.toBudgetTxs(rows, wallets);
    expect([for (final t in txs) (t.amountMilli, t.currency)], [(5000, 'JOD'), (1999, 'USD')]);
    final report = (await repo.math()).spend(txs, BudgetWindow.month(DateTime(2026, 9, 1)));
    expect(report.unassignedMilli, 1417); // 19.99 USD × 0.709, half-up
    expect(report.byId['food']!.spentMilli, 5000);
  });

  test('currencies from rows: base, user symbols and fallbacks', () {
    final c = BudgetCurrencies.fromRows(const []);
    expect(c.base, BudgetCurrencies.fallbackBase);
    expect(c.decimalsOf('LYD'), 3);
    expect(c.settings(weeksPerMonth: 5).weeksPerMonth, 5);
  });
}
