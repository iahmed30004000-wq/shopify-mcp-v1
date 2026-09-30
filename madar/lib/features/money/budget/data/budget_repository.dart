import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

import '../../../../core/db/database.dart';
import '../../../../core/db/repositories/repositories.dart';
import '../../../../core/db/tables/converters.dart' show CalendarDayConverter, newId;
import '../../../../core/domain/budget_math.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/domain/money.dart';
import '../domain/budget_edits.dart';

/// Restores exactly what a budget write changed.
typedef BudgetUndo = Future<void> Function();

/// The currencies the budget converts with: the base currency, the manual
/// rates to it and each currency's decimals and symbol (from the
/// `currencies` table).
@immutable
class BudgetCurrencies {
  const BudgetCurrencies({
    required this.base,
    this.rates = const {},
    this.decimals = const {},
    this.symbols = const {},
    this.codes = const [],
  });

  factory BudgetCurrencies.fromRows(Iterable<CurrencyRow> rows) {
    final list = rows.toList();
    final base = list.where((c) => c.isBase).firstOrNull?.code ?? (list.isEmpty ? fallbackBase : list.first.code);
    return BudgetCurrencies(
      base: base.toUpperCase(),
      rates: {for (final c in list) c.code.toUpperCase(): c.rateToBase},
      decimals: {for (final c in list) c.code.toUpperCase(): c.decimals},
      symbols: {
        for (final c in list)
          if (c.symbol.trim().isNotEmpty) c.code.toUpperCase(): c.symbol.trim(),
      },
      codes: [for (final c in list) c.code.toUpperCase()],
    );
  }

  /// Used before the currencies table is readable.
  static const fallbackBase = 'JOD';
  static const fallback = BudgetCurrencies(base: fallbackBase, codes: [fallbackBase]);

  final String base;

  /// 1 unit of the key currency = value base units.
  final Map<String, num> rates;
  final Map<String, int> decimals;

  /// The user's own symbols (used for currencies Madar does not know).
  final Map<String, String> symbols;

  /// Codes in the user's order.
  final List<String> codes;

  int decimalsOf(String code) => CurrencyCatalog.decimalsFor(code, overrides: decimals);

  BudgetSettings settings({num weeksPerMonth = BudgetSettings.defaultWeeksPerMonth}) =>
      BudgetSettings(weeksPerMonth: weeksPerMonth, baseCurrency: base, ratesToBase: rates);

  @override
  bool operator ==(Object other) =>
      other is BudgetCurrencies &&
      other.base == base &&
      _mapEq(other.rates, rates) &&
      _mapEq(other.decimals, decimals) &&
      _mapEq(other.symbols, symbols) &&
      other.codes.join(',') == codes.join(',');

  @override
  int get hashCode => Object.hash(base, codes.join(','), rates.length);

  static bool _mapEq<K, V>(Map<K, V> a, Map<K, V> b) =>
      a.length == b.length && a.entries.every((e) => b.containsKey(e.key) && b[e.key] == e.value);
}

/// A persisted budget row as a [BudgetNode].
BudgetNode budgetNodeOf(BudgetItemRow row) => BudgetNode(
  id: row.id,
  name: row.name,
  parentId: row.parentId,
  mode: row.mode,
  amountMilli: row.amountMilli,
  percent: row.percent,
  percentOf: row.percentOf,
  period: row.period,
  currency: row.currency,
  sortOrder: row.sortOrder,
);

/// Reads the valid weeks-per-month from a `key_values` JSON value.
num weeksPerMonthOf(Object? json) =>
    json is num && json.isFinite && json > 0 ? json : BudgetSettings.defaultWeeksPerMonth;

/// Budget items, their settings and the expenses booked to them. Every
/// write returns a [BudgetUndo] that restores the exact prior state; plan
/// edits are logged on the Money world (`money.budget`).
class BudgetRepository {
  BudgetRepository(this.repos, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final Repositories repos;
  final DateTime Function() _clock;

  static const planetKey = 'money';
  static const activityKind = 'money.budget';
  static const table = 'budget_items';

  MadarDatabase get _db => repos.db;

  // ------------------------------------------------------------ reads ----

  Stream<List<BudgetItemRow>> watchItems() => repos.budgetItems.watchAll();
  Future<List<BudgetItemRow>> items() => repos.budgetItems.getAll();

  Stream<BudgetCurrencies> watchCurrencies() => repos.currencies.watchAll().map(BudgetCurrencies.fromRows).distinct();
  Future<BudgetCurrencies> currencies() async => BudgetCurrencies.fromRows(await repos.currencies.getAll());

  Stream<num> watchWeeksPerMonth() =>
      repos.keyValues.watchJson(BudgetSettings.weeksPerMonthKey).map(weeksPerMonthOf).distinct();
  Future<num> weeksPerMonth() async => weeksPerMonthOf(await repos.keyValues.getJson(BudgetSettings.weeksPerMonthKey));

  /// The whole budget as [BudgetMath] (one-shot).
  Future<BudgetMath> math() async {
    final rows = await items();
    final cur = await currencies();
    return BudgetMath(rows.map(budgetNodeOf), settings: cur.settings(weeksPerMonth: await weeksPerMonth()));
  }

  /// Expense transactions dated on or after [since] (a calendar day).
  Stream<List<TransactionRow>> watchExpenses({required DateTime since}) => repos.transactions.watchAll(
    where: (t) =>
        t.kind.equalsValue(TxKind.expense) &
        t.date.julianday.isBiggerOrEqual(Variable<DateTime>(CalendarDayConverter.startOf(since)).julianday),
  );

  /// Wallet id → currency code.
  Stream<Map<String, String>> watchWalletCurrencies() =>
      repos.wallets.watchAll().map((rows) => {for (final w in rows) w.id: w.currency.toUpperCase()});

  /// Expense rows as [BudgetTx] (the currency is the wallet's).
  static List<BudgetTx> toBudgetTxs(Iterable<TransactionRow> rows, Map<String, String> walletCurrency) => [
    for (final t in rows)
      BudgetTx(
        budgetItemId: t.budgetItemId,
        amountMilli: t.amountMilli,
        date: t.date,
        currency: walletCurrency[t.walletId],
        kind: t.kind,
      ),
  ];

  // ----------------------------------------------------------- writes ----

  /// A fresh id for a new item (drafts need it before they are saved).
  static String newItemId() => newId();

  /// Inserts [node] (its id is kept). With [afterId] it is placed right
  /// after that sibling, otherwise last among its siblings.
  Future<BudgetUndo> add(BudgetNode node, {String? afterId}) async {
    await _db.transaction(() async {
      await repos.budgetItems.insert(
        BudgetItemsCompanion.insert(
          id: Value(node.id),
          parentId: Value(node.parentId),
          name: node.name,
          mode: Value(node.mode),
          amountMilli: Value(node.amountMilli),
          percent: Value(node.percent),
          percentOf: Value(node.percentOf),
          period: Value(node.period),
          currency: Value(node.currency),
        ),
      );
      if (afterId != null) {
        final siblings = await _siblingIds(node.parentId);
        await repos.budgetItems.reorder(BudgetEdits.placeAfter(siblings, node.id, afterId));
      }
    });
    await _log(node.id, 'add');
    return () async {
      await repos.budgetItems.delete(node.id);
    };
  }

  /// Writes [node] over the stored item. An item that changes parent moves
  /// to the end of its new siblings.
  Future<BudgetUndo> save(BudgetNode node) => saveAll([node]);

  /// Writes several items at once (one transaction, one undo).
  Future<BudgetUndo> saveAll(Iterable<BudgetNode> nodes) async {
    final before = <BudgetItemRow>[];
    await _db.transaction(() async {
      for (final n in nodes) {
        final old = await repos.budgetItems.byId(n.id);
        if (old == null) continue;
        before.add(old);
        await repos.budgetItems.update(_companion(n));
        if (old.parentId != n.parentId) await repos.budgetItems.setColumns(n.id, const {}, moveToEnd: true);
      }
    });
    if (before.isNotEmpty) await _log(before.first.id, 'edit');
    return () => repos.budgetItems.restoreAll(before);
  }

  /// Deletes [id] with all its sub-items. Expenses and obligations booked
  /// to them move to the nearest remaining parent (or to no item when a
  /// top-level item goes), so their spend keeps counting where it belongs.
  Future<BudgetUndo> deleteSubtree(String id) async {
    final all = await items();
    final children = <String, List<String>>{};
    final byId = {for (final r in all) r.id: r};
    for (final r in all) {
      if (r.parentId != null) (children[r.parentId!] ??= []).add(r.id);
    }
    final ids = <String>[];
    void walk(String n) {
      if (ids.contains(n)) return;
      ids.add(n);
      children[n]?.forEach(walk);
    }

    if (!byId.containsKey(id)) return () async {};
    walk(id);
    final heir = byId[id]!.parentId;
    late List<BudgetItemRow> removed;
    final txRefs = <String, String?>{};
    final obligationRefs = <String, String?>{};
    await _db.transaction(() async {
      final txs = await (_db.select(_db.transactions)..where((t) => t.budgetItemId.isIn(ids))).get();
      for (final t in txs) {
        txRefs[t.id] = t.budgetItemId;
      }
      final obs = await (_db.select(_db.obligations)..where((o) => o.budgetItemId.isIn(ids))).get();
      for (final o in obs) {
        obligationRefs[o.id] = o.budgetItemId;
      }
      if (txRefs.isNotEmpty) {
        await (_db.update(_db.transactions)..where((t) => t.id.isIn(txRefs.keys))).write(
          TransactionsCompanion(budgetItemId: Value(heir), updatedAt: Value(_clock())),
        );
      }
      if (obligationRefs.isNotEmpty) {
        await (_db.update(_db.obligations)..where((o) => o.id.isIn(obligationRefs.keys))).write(
          ObligationsCompanion(budgetItemId: Value(heir), updatedAt: Value(_clock())),
        );
      }
      removed = await repos.budgetItems.deleteWhere((b) => b.id.isIn(ids));
    });
    await _log(id, 'delete', payload: {'count': ids.length});
    return () => _db.transaction(() async {
      await repos.budgetItems.restoreAll(removed);
      for (final e in txRefs.entries) {
        await (_db.update(
          _db.transactions,
        )..where((t) => t.id.equals(e.key))).write(TransactionsCompanion(budgetItemId: Value(e.value)));
      }
      for (final e in obligationRefs.entries) {
        await (_db.update(
          _db.obligations,
        )..where((o) => o.id.equals(e.key))).write(ObligationsCompanion(budgetItemId: Value(e.value)));
      }
    });
  }

  /// Stores the order of one group of siblings.
  Future<BudgetUndo> reorder(List<String> idsInOrder) async {
    final before = await (_db.select(_db.budgetItems)..where((b) => b.id.isIn(idsInOrder))).get();
    await repos.budgetItems.reorder(idsInOrder);
    return () => repos.budgetItems.restoreAll(before);
  }

  /// Stores weeks per month (`key_values` [BudgetSettings.weeksPerMonthKey]).
  Future<BudgetUndo> setWeeksPerMonth(num weeksPerMonth) async {
    if (weeksPerMonth <= 0 || !weeksPerMonth.isFinite) throw ArgumentError.value(weeksPerMonth, 'weeksPerMonth');
    const key = BudgetSettings.weeksPerMonthKey;
    final had = await repos.keyValues.contains(key);
    final previous = await repos.keyValues.getJson(key);
    await repos.keyValues.setJson(key, weeksPerMonth);
    return () => had ? repos.keyValues.setJson(key, previous) : repos.keyValues.remove(key);
  }

  // ---------------------------------------------------------- helpers ----

  Future<List<String>> _siblingIds(String? parentId) async {
    final rows = await repos.budgetItems.getAll(
      where: (b) => parentId == null ? b.parentId.isNull() : b.parentId.equals(parentId),
    );
    return [for (final r in rows) r.id];
  }

  BudgetItemsCompanion _companion(BudgetNode n) => BudgetItemsCompanion(
    id: Value(n.id),
    parentId: Value(n.parentId),
    name: Value(n.name),
    mode: Value(n.mode),
    amountMilli: Value(n.amountMilli),
    percent: Value(n.percent),
    percentOf: Value(n.percentOf),
    period: Value(n.period),
    currency: Value(n.currency),
  );

  Future<void> _log(String id, String action, {Map<String, Object?> payload = const {}}) async {
    await repos.activity.log(
      planetKey: planetKey,
      kind: activityKind,
      refTable: table,
      refId: id,
      at: _clock(),
      payload: {'action': action, ...payload},
    );
  }
}
