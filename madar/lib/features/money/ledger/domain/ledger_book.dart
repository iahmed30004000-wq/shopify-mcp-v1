/// A consistent snapshot of the whole ledger – currencies, wallets,
/// transactions and the budget tree – with every derived value the screens
/// need (pure Dart, computed once per database change).
library;

import '../../../../core/domain/budget_math.dart';
import '../../../../core/domain/enums.dart';
import 'ledger_math.dart';
import 'ledger_models.dart';
import 'tx_filter.dart';

/// Display extras of a budget item (not part of the math).
class BudgetItemLook {
  const BudgetItemLook({this.color, this.icon});

  final int? color;
  final String? icon;
}

class LedgerBook implements TxFilterContext {
  LedgerBook({
    required List<LedgerCurrency> currencies,
    required List<LedgerWallet> wallets,
    required List<LedgerTx> transactions,
    List<BudgetNode> budgetNodes = const [],
    Map<String, BudgetItemLook> budgetLooks = const {},
    num weeksPerMonth = BudgetSettings.defaultWeeksPerMonth,
    this.ratesAreDefaults = false,
    this.weekStart = DateTime.saturday,
  }) : currencies = List<LedgerCurrency>.unmodifiable(currencies),
       wallets = List<LedgerWallet>.unmodifiable(<LedgerWallet>[...wallets]..sort(_walletOrder)),
       transactions = List<LedgerTx>.unmodifiable(<LedgerTx>[...transactions]..sort(LedgerMath.compareNewestFirst)),
       budgetLooks = Map.unmodifiable(budgetLooks) {
    rates = LedgerRates.of(this.currencies);
    currencyByCode = {for (final c in this.currencies) c.code.toUpperCase(): c};
    walletById = {for (final w in this.wallets) w.id: w};
    balances = LedgerMath.balances(this.wallets, this.transactions);
    totals = LedgerTotals.of(this.wallets, balances, rates);
    budget = budgetNodes.isEmpty
        ? null
        : BudgetMath(
            budgetNodes,
            settings: BudgetSettings(
              weeksPerMonth: weeksPerMonth,
              baseCurrency: rates.base,
              ratesToBase: rates.asNumbers,
              weekStart: weekStart,
            ),
          );
  }

  /// First day of a week in the weekly views ([DateTime.monday] …
  /// [DateTime.sunday]; the user's Money setting, Saturday by default).
  final int weekStart;

  static int _walletOrder(LedgerWallet a, LedgerWallet b) {
    final s = a.sortOrder.compareTo(b.sortOrder);
    return s != 0 ? s : a.name.compareTo(b.name);
  }

  /// Currencies (base first, then the user's order).
  final List<LedgerCurrency> currencies;

  /// All wallets (archived included) in the user's order.
  final List<LedgerWallet> wallets;

  /// All entries, newest first.
  final List<LedgerTx> transactions;

  final Map<String, BudgetItemLook> budgetLooks;

  /// Whether the currency rates are still the generic seeded ones.
  final bool ratesAreDefaults;

  late final LedgerRates rates;
  late final Map<String, LedgerCurrency> currencyByCode;
  late final Map<String, LedgerWallet> walletById;

  /// Current balance per wallet id (wallet currency).
  late final Map<String, int> balances;

  /// Totals of the non-archived wallets.
  late final LedgerTotals totals;

  /// The budget tree (null without budget items).
  late final BudgetMath? budget;

  String get baseCode => rates.base;

  LedgerCurrency? currency(String code) => currencyByCode[code.toUpperCase()];

  List<LedgerWallet> get activeWallets => [
    for (final w in wallets)
      if (!w.archived) w,
  ];

  List<LedgerWallet> get archivedWallets => [
    for (final w in wallets)
      if (w.archived) w,
  ];

  LedgerWallet? wallet(String? id) => id == null ? null : walletById[id];

  int balanceOf(String walletId) => balances[walletId] ?? walletById[walletId]?.openingMilli ?? 0;

  /// Wallet id → currency code.
  late final Map<String, String> walletCurrency = {for (final w in wallets) w.id: w.currency};

  String? currencyOfWallet(String walletId) => walletById[walletId]?.currency;

  /// Entries touching [walletId], newest first.
  List<LedgerTx> transactionsOf(String walletId) => [
    for (final tx in transactions)
      if (tx.touches(walletId)) tx,
  ];

  LedgerTx? transaction(String id) => transactions.where((t) => t.id == id).firstOrNull;

  /// Every tag in use, most used first.
  late final List<String> tags = TxGrouping.tagsByUse(transactions);

  /// Budget items in tree order (parents before children).
  List<BudgetNodeResult> get budgetTree => budget?.flattened ?? const [];

  /// `Parent › Child` path of a budget item (null when unknown).
  String? budgetPath(String? itemId, {String separator = ' › '}) {
    final b = budget;
    if (itemId == null || b == null) return null;
    final parts = <String>[];
    var r = b[itemId];
    var guard = 0;
    while (r != null && guard++ < 64) {
      parts.insert(0, r.node.name);
      r = r.parentId == null ? null : b[r.parentId!];
    }
    return parts.isEmpty ? null : parts.join(separator);
  }

  /// The top-level item above [itemId] (itself for a root; null when
  /// unknown).
  String? rootIdOf(String? itemId) {
    final b = budget;
    if (itemId == null || b == null) return null;
    var r = b[itemId];
    var guard = 0;
    while (r != null && r.parentId != null && guard++ < 64) {
      final p = b[r.parentId!];
      if (p == null) break;
      r = p;
    }
    return r?.node.id;
  }

  /// The item's icon and colour, each falling back to the nearest ancestor
  /// that has one.
  BudgetItemLook lookOf(String? itemId) {
    final b = budget;
    if (itemId == null || b == null) return const BudgetItemLook();
    int? color;
    String? icon;
    var r = b[itemId];
    var guard = 0;
    while (r != null && guard++ < 64 && (color == null || icon == null)) {
      final look = budgetLooks[r.node.id];
      color ??= look?.color;
      icon ??= look?.icon;
      r = r.parentId == null ? null : b[r.parentId!];
    }
    return BudgetItemLook(color: color, icon: icon);
  }

  /// Position of [itemId]'s root among the roots (for palette colours).
  int rootIndexOf(String? itemId) {
    final root = rootIdOf(itemId);
    return root == null ? -1 : (budget?.rootIds.indexOf(root) ?? -1);
  }

  /// The wallet's balance without entry [excludingTxId] (to edit "set
  /// balance" adjustments).
  int balanceWithout(String walletId, String? excludingTxId) {
    final w = walletById[walletId];
    if (w == null) return 0;
    if (excludingTxId == null) return balanceOf(walletId);
    return LedgerMath.balanceOf(w, transactions.where((t) => t.id != excludingTxId));
  }

  // ------------------------------------------------ TxFilterContext ----

  @override
  WalletKind? walletKindOf(String walletId) => walletById[walletId]?.kind;

  @override
  String? walletNameOf(String walletId) => walletById[walletId]?.name;

  @override
  String? budgetNameOf(String itemId) => budget?[itemId]?.node.name;

  @override
  Set<String> budgetSubtree(Iterable<String> ids) {
    final b = budget;
    final out = <String>{...ids};
    if (b == null) return out;
    final stack = [...ids];
    while (stack.isNotEmpty) {
      final id = stack.removeLast();
      for (final c in b[id]?.childIds ?? const <String>[]) {
        if (out.add(c)) stack.add(c);
      }
    }
    return out;
  }
}
