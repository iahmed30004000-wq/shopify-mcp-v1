import 'package:drift/drift.dart';

import '../../../../core/db/database.dart';
import '../../../../core/db/repositories/repositories.dart';
import '../../../../core/db/seed/seeder.dart' show SeedKeys;
import '../../../../core/domain/budget_math.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/domain/money.dart';
import '../domain/currency_math.dart';
import '../domain/ledger_book.dart';
import '../domain/ledger_links.dart';
import '../domain/ledger_models.dart';
import '../domain/tx_draft.dart';

/// Records an activity (so the Money planet's freshness and pulse react).
typedef LedgerActivityRecorder = Future<void> Function({
  required String kind,
  required String refTable,
  required String refId,
  required DateTime at,
  double? value,
  Map<String, Object?> payload,
});

/// Reverts a change (for the undo toast).
typedef LedgerUndo = Future<void> Function();

/// The currency a wallet uses cannot change once entries were booked in it.
class WalletCurrencyLockedException implements Exception {
  const WalletCurrencyLockedException(this.walletId);
  final String walletId;
  @override
  String toString() => 'WalletCurrencyLockedException($walletId)';
}

/// Entries written for a jar, debt or obligation ([LedgerLinks]) are only
/// changed by their owner, never by the ledger alone.
class LedgerLinkedEntryException implements Exception {
  const LedgerLinkedEntryException(this.transactionId, this.link);
  final String transactionId;
  final LedgerLink link;
  @override
  String toString() => 'LedgerLinkedEntryException($transactionId, ${link.name})';
}

/// A currency still used by wallets cannot be deleted.
class CurrencyInUseException implements Exception {
  const CurrencyInUseException(this.code, this.wallets, {this.elsewhere = 0});
  final String code;
  final int wallets;

  /// Savings jars, debts, recurring obligations and budget items kept in
  /// [code] (without its rate they would silently count 1:1).
  final int elsewhere;
  @override
  String toString() => 'CurrencyInUseException($code, $wallets wallets, $elsewhere elsewhere)';
}

/// Row ↔ domain mapping.
abstract final class LedgerRows {
  static LedgerCurrency currency(CurrencyRow r) => LedgerCurrency(
    code: r.code.toUpperCase(),
    nameAr: r.nameAr,
    nameEn: r.nameEn,
    symbol: r.symbol,
    decimals: r.decimals,
    rateToBase: r.rateToBase,
    isBase: r.isBase,
    sortOrder: r.sortOrder,
  );

  static LedgerWallet wallet(WalletRow r) => LedgerWallet(
    id: r.id,
    name: r.name,
    currency: r.currency.toUpperCase(),
    openingMilli: r.openingMilli,
    kind: r.kind,
    color: r.color,
    icon: r.icon,
    archived: r.archived,
    sortOrder: r.sortOrder,
  );

  static LedgerTx tx(TransactionRow r) => LedgerTx(
    id: r.id,
    walletId: r.walletId,
    kind: r.kind,
    amountMilli: r.amountMilli,
    date: r.date,
    budgetItemId: r.budgetItemId,
    toWalletId: r.toWalletId,
    toAmountMilli: r.toAmountMilli,
    note: r.note,
    tags: r.tags,
    createdAt: r.createdAt,
  );

  static BudgetNode budgetNode(BudgetItemRow r) => BudgetNode(
    id: r.id,
    name: r.name,
    parentId: r.parentId,
    mode: r.mode,
    amountMilli: r.amountMilli,
    percent: r.percent,
    percentOf: r.percentOf,
    period: r.period,
    currency: r.currency,
    sortOrder: r.sortOrder,
  );
}

/// Reads and writes the ledger: currencies and rates, wallets and
/// transactions. Every destructive write returns a [LedgerUndo].
class LedgerService {
  LedgerService(this.repos, {DateTime Function()? clock, this.recorder}) : clock = clock ?? DateTime.now;

  final Repositories repos;
  final DateTime Function() clock;

  /// Where `money.tx` activities go (the orbit pulse hub in the app); null
  /// logs straight to the activity table.
  final LedgerActivityRecorder? recorder;

  MadarDatabase get db => repos.db;

  /// Activity kind logged for every entry added in the ledger.
  static const activityKind = 'money.tx';
  static const planetKey = 'money';

  // ------------------------------------------------------------ reads ----

  Stream<List<LedgerCurrency>> watchCurrencies() =>
      repos.currencies.watchAll().map((rows) => [for (final r in rows) LedgerRows.currency(r)]);

  Stream<List<LedgerWallet>> watchWallets() =>
      (db.select(db.wallets)..orderBy([(w) => OrderingTerm.asc(w.sortOrder), (w) => OrderingTerm.asc(w.name)]))
          .watch()
          .map((rows) => [for (final r in rows) LedgerRows.wallet(r)]);

  Stream<List<LedgerTx>> watchTransactions() =>
      (db.select(db.transactions)..orderBy([(t) => OrderingTerm.desc(t.date), (t) => OrderingTerm.desc(t.createdAt)]))
          .watch()
          .map((rows) => [for (final r in rows) LedgerRows.tx(r)]);

  Stream<List<BudgetItemRow>> watchBudgetItems() =>
      (db.select(db.budgetItems)..orderBy([(b) => OrderingTerm.asc(b.sortOrder)])).watch();

  /// The user's weeks-per-month (see [BudgetSettings.weeksPerMonthKey]).
  Stream<num?> watchWeeksPerMonth() =>
      repos.keyValues.watchJson(BudgetSettings.weeksPerMonthKey).map((v) => v is num && v > 0 ? v : null);

  /// How many savings jars, debts, recurring obligations and budget items
  /// are kept in each currency (upper-case code → count). A currency in use
  /// there cannot be deleted: without its rate their amounts would count 1:1.
  Stream<Map<String, int>> watchCurrencyUseElsewhere() => db
      .customSelect(
        'SELECT UPPER(currency) AS code, COUNT(*) AS n FROM ('
        'SELECT currency FROM ${db.jars.actualTableName} '
        'UNION ALL SELECT currency FROM ${db.debts.actualTableName} '
        'UNION ALL SELECT currency FROM ${db.obligations.actualTableName} '
        'UNION ALL SELECT currency FROM ${db.budgetItems.actualTableName} WHERE currency IS NOT NULL'
        ') GROUP BY UPPER(currency)',
        readsFrom: {db.jars, db.debts, db.obligations, db.budgetItems},
      )
      .watch()
      .map((rows) => {for (final r in rows) r.read<String>('code'): r.read<int>('n')});

  /// Whether the rates are still the generic seeded ones.
  Stream<bool> watchRatesAreDefaults() =>
      repos.keyValues.watchJson(SeedKeys.currencyRatesAreDefaults).map((v) => v == true);

  /// A one-off snapshot (tests, services).
  Future<LedgerBook> book() async {
    final currencies = [for (final r in await repos.currencies.getAll()) LedgerRows.currency(r)];
    final wallets = [for (final r in await repos.wallets.getAll()) LedgerRows.wallet(r)];
    final txs = [for (final r in await repos.transactions.getAll()) LedgerRows.tx(r)];
    final items = await repos.budgetItems.getAll();
    final weeks = await repos.keyValues.getJson(BudgetSettings.weeksPerMonthKey);
    return LedgerBook(
      currencies: currencies,
      wallets: wallets,
      transactions: txs,
      budgetNodes: [for (final r in items) LedgerRows.budgetNode(r)],
      budgetLooks: {for (final r in items) r.id: BudgetItemLook(color: r.color, icon: r.icon)},
      weeksPerMonth: weeks is num && weeks > 0 ? weeks : BudgetSettings.defaultWeeksPerMonth,
    );
  }

  // ----------------------------------------------------- transactions ----

  TransactionsCompanion _companion(TxWrite w) => TransactionsCompanion(
    walletId: Value(w.walletId),
    kind: Value(w.kind),
    amountMilli: Value(w.amountMilli),
    date: Value(w.date),
    budgetItemId: Value(w.budgetItemId),
    toWalletId: Value(w.toWalletId),
    toAmountMilli: Value(w.toAmountMilli),
    note: Value(w.note),
    tags: Value(w.tags),
  );

  /// Adds an entry and records the `money.tx` activity.
  Future<LedgerTx> add(TxWrite write) async {
    final row = await repos.transactions.insert(_companion(write));
    await _record(row);
    return LedgerRows.tx(row);
  }

  Future<void> _record(TransactionRow row) async {
    final at = clock();
    final value = row.amountMilli.abs() / Money.milliPerUnit;
    final payload = {'kind': row.kind.name, 'walletId': row.walletId};
    final record = recorder;
    if (record != null) {
      await record(kind: activityKind, refTable: 'transactions', refId: row.id, at: at, value: value, payload: payload);
    } else {
      await repos.activity.log(
        planetKey: planetKey,
        kind: activityKind,
        refTable: 'transactions',
        refId: row.id,
        at: at,
        value: value,
        payload: payload,
      );
    }
  }

  static void _guard(String id) {
    final link = LedgerLinks.ofId(id);
    if (link != null) throw LedgerLinkedEntryException(id, link);
  }

  /// Rewrites entry [id]; returns the undo. Throws
  /// [LedgerLinkedEntryException] for a jar / debt / obligation entry.
  Future<LedgerUndo> update(String id, TxWrite write) async {
    _guard(id);
    final before = await repos.transactions.byId(id);
    if (before == null) throw StateError('No transaction $id');
    await repos.transactions.update(_companion(write).copyWith(id: Value(id)));
    return () => repos.transactions.restore(before);
  }

  /// Deletes entry [id] (and its activity entries); returns the undo.
  /// Throws [LedgerLinkedEntryException] for a jar / debt / obligation entry.
  Future<LedgerUndo> delete(String id) async {
    _guard(id);
    return db.transaction(() async {
      final row = await repos.transactions.delete(id);
      final activity = await repos.activity.removeFor(refTable: 'transactions', refId: id);
      return () async {
        await db.transaction(() async {
          if (row != null) await repos.transactions.restore(row);
          if (activity.isNotEmpty) await repos.activityLog.restoreAll(activity);
        });
      };
    });
  }

  /// Copies entry [id] to [date] (today by default); returns the copy and
  /// its undo. Throws [LedgerLinkedEntryException] for a jar / debt /
  /// obligation entry.
  Future<(LedgerTx, LedgerUndo)> duplicate(String id, {DateTime? date}) async {
    _guard(id);
    final now = clock();
    final day = date ?? DateTime(now.year, now.month, now.day);
    final copy = await repos.transactions.duplicate(id, overrides: {'date': day});
    await _record(copy);
    return (LedgerRows.tx(copy), () => delete(copy.id).then((_) {}));
  }

  /// Moves entry [id] to [walletId]. Between currencies the amount is
  /// converted with the manual rates (rounded to the target's minor unit);
  /// returns the undo, or null when the move is not possible (always for a
  /// jar / debt / obligation entry).
  Future<LedgerUndo?> move(String id, String walletId, LedgerBook book) async {
    if (LedgerLinks.ofId(id) != null) return null;
    final before = await repos.transactions.byId(id);
    final target = book.wallet(walletId);
    if (before == null || target == null || before.walletId == walletId) return null;
    if (before.kind == TxKind.transfer && before.toWalletId == walletId) return null;
    final from = book.currencyOfWallet(before.walletId) ?? target.currency;
    var amount = before.amountMilli;
    if (from != target.currency) {
      final converted = book.rates.convert(
        before.amountMilli,
        from,
        target.currency,
        decimals: book.currency(target.currency)?.decimals,
      );
      if (converted == null) return null;
      amount = converted;
    }
    // A transfer that stored no separate received amount received the same
    // number; keep what arrived once the source changes currency.
    final keepReceived =
        before.kind == TxKind.transfer &&
        before.toWalletId != null &&
        before.toAmountMilli == null &&
        amount != before.amountMilli;
    await repos.transactions.update(
      TransactionsCompanion(
        id: Value(id),
        walletId: Value(walletId),
        amountMilli: Value(amount),
        toAmountMilli: keepReceived ? Value(before.amountMilli.abs()) : const Value.absent(),
      ),
    );
    return () => repos.transactions.restore(before);
  }

  // ---------------------------------------------------------- wallets ----

  Future<LedgerWallet> addWallet({
    required String name,
    required String currency,
    int openingMilli = 0,
    WalletKind kind = WalletKind.personal,
    int? color,
    String? icon,
  }) async {
    final row = await repos.wallets.insert(
      WalletsCompanion.insert(
        name: name.trim(),
        currency: currency.toUpperCase(),
        openingMilli: Value(openingMilli),
        kind: Value(kind),
        color: Value(color),
        icon: Value(icon),
      ),
    );
    return LedgerRows.wallet(row);
  }

  /// Edits a wallet; the currency is locked once entries exist
  /// ([WalletCurrencyLockedException]). Returns the undo.
  Future<LedgerUndo> updateWallet(
    String id, {
    required String name,
    required String currency,
    required int openingMilli,
    required WalletKind kind,
    int? color,
    String? icon,
  }) async {
    final before = await repos.wallets.byId(id);
    if (before == null) throw StateError('No wallet $id');
    final code = currency.toUpperCase();
    if (code != before.currency.toUpperCase() && await transactionCount(id) > 0) {
      throw WalletCurrencyLockedException(id);
    }
    await repos.wallets.update(
      WalletsCompanion(
        id: Value(id),
        name: Value(name.trim()),
        currency: Value(code),
        openingMilli: Value(openingMilli),
        kind: Value(kind),
        color: Value(color),
        icon: Value(icon),
      ),
    );
    return () => repos.wallets.restore(before);
  }

  /// Entries booked in (or transferred into) [walletId].
  Future<int> transactionCount(String walletId) =>
      repos.transactions.count(where: (t) => t.walletId.equals(walletId) | t.toWalletId.equals(walletId));

  Future<LedgerUndo> setArchived(String id, bool archived) async {
    final before = await repos.wallets.byId(id);
    if (before == null) throw StateError('No wallet $id');
    await repos.wallets.update(WalletsCompanion(id: Value(id), archived: Value(archived)));
    return () => repos.wallets.restore(before);
  }

  /// Deletes a wallet with every entry booked in it or transferred into it
  /// (and their activity); returns the undo.
  Future<LedgerUndo> deleteWallet(String id) async {
    return db.transaction(() async {
      final wallet = await repos.wallets.delete(id);
      final txs = await repos.transactions.deleteWhere((t) => t.walletId.equals(id) | t.toWalletId.equals(id));
      final activity = <ActivityRow>[
        for (final t in txs) ...await repos.activity.removeFor(refTable: 'transactions', refId: t.id),
      ];
      return () async {
        await db.transaction(() async {
          if (wallet != null) await repos.wallets.restore(wallet);
          await repos.transactions.restoreAll(txs);
          await repos.activityLog.restoreAll(activity);
        });
      };
    });
  }

  Future<void> reorderWallets(List<String> ids) => repos.wallets.reorder(ids);

  // ------------------------------------------------------- currencies ----

  /// Adds or edits a currency. [rate] (1 unit = rate base units) is stored
  /// through [RateMath.storable]; the base currency keeps 1. Returns the
  /// undo (restores the previous row, or deletes a new one).
  Future<LedgerUndo> saveCurrency(LedgerCurrency currency, {Rational? rate}) async {
    final code = currency.code.toUpperCase();
    final before = await repos.currencies.byCode(code);
    final isBase = before?.isBase ?? false;
    final stored = isBase ? 1.0 : (rate == null ? (before?.rateToBase ?? 1.0) : RateMath.storable(rate));
    await repos.currencies.upsert(
      CurrenciesCompanion(
        code: Value(code),
        nameAr: Value(currency.nameAr.trim()),
        nameEn: Value(currency.nameEn.trim()),
        symbol: Value(currency.symbol.trim().isEmpty ? code : currency.symbol.trim()),
        decimals: Value(currency.decimals.clamp(0, 3)),
        rateToBase: Value(stored),
        sortOrder: before == null ? const Value.absent() : Value(before.sortOrder),
      ),
    );
    if (rate != null && !isBase && (before == null || before.rateToBase != stored)) {
      await _clearDefaultRatesFlag();
    }
    return () async {
      if (before == null) {
        await repos.currencies.delete(code);
      } else {
        await repos.currencies.restore(before);
      }
    };
  }

  /// Sets the manual rate of [code] (1 unit = [rate] base units); returns
  /// the undo.
  Future<LedgerUndo> setRate(String code, Rational rate) async {
    final before = await repos.currencies.byCode(code);
    if (before == null) throw StateError('Unknown currency $code');
    if (before.isBase) return () async {};
    final stored = RateMath.storable(rate);
    await repos.currencies.setRate(code, stored);
    // The user has now set a rate of their own.
    if (before.rateToBase != stored) await _clearDefaultRatesFlag();
    return () => repos.currencies.restore(before);
  }

  Future<void> _clearDefaultRatesFlag() => repos.keyValues.remove(SeedKeys.currencyRatesAreDefaults);

  /// Makes [code] the base currency, re-expressing every rate exactly
  /// ([RebasePlan]); returns the undo (restores every previous rate).
  Future<LedgerUndo> rebase(String code) async {
    return db.transaction(() async {
      final rows = await repos.currencies.getAll();
      final plan = RebasePlan.of([for (final r in rows) LedgerRows.currency(r)], code.toUpperCase());
      if (plan == null) throw StateError('Cannot make $code the base currency');
      await db.batch((b) {
        for (final r in rows) {
          final next = plan.row(r.code.toUpperCase());
          b.update(
            db.currencies,
            CurrenciesCompanion(
              rateToBase: next?.stored == null ? const Value.absent() : Value(next!.stored!),
              isBase: Value(r.code.toUpperCase() == code.toUpperCase()),
            ),
            where: (t) => t.code.equals(r.code),
          );
        }
      });
      return () async {
        await db.batch((b) {
          for (final r in rows) {
            b.insert(db.currencies, r, mode: InsertMode.insertOrReplace);
          }
        });
      };
    });
  }

  /// Deletes an unused currency; throws [CurrencyInUseException] when
  /// wallets, jars, debts, obligations or budget items use it and a [StateError] for the base currency. Returns the
  /// undo.
  Future<LedgerUndo> deleteCurrency(String code) async {
    final current = await repos.currencies.byCode(code);
    if (current?.isBase ?? false) throw StateError('The base currency $code cannot be deleted');
    final used = await repos.wallets.count(where: (w) => w.currency.equals(code));
    final elsewhere = (await watchCurrencyUseElsewhere().first)[code.toUpperCase()] ?? 0;
    if (used > 0 || elsewhere > 0) throw CurrencyInUseException(code, used, elsewhere: elsewhere);
    final row = await repos.currencies.delete(code);
    return () async {
      if (row != null) await repos.currencies.restore(row);
    };
  }

  Future<void> reorderCurrencies(List<String> codes) => repos.currencies.reorder(codes);
}
