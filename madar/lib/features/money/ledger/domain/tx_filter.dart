/// Transaction filters, search and day grouping (pure Dart).
library;

import 'package:meta/meta.dart';

import '../../../../core/domain/enums.dart';
import '../../../../core/domain/money.dart';
import 'ledger_math.dart';
import 'ledger_models.dart';

/// What the filter needs to know about wallets and budget items.
abstract interface class TxFilterContext {
  WalletKind? walletKindOf(String walletId);
  String? walletNameOf(String walletId);

  /// Name of a budget item (null when unknown).
  String? budgetNameOf(String itemId);

  /// [ids] and all their descendants.
  Set<String> budgetSubtree(Iterable<String> ids);
}

/// The ledger's filters. Empty sets mean "any".
@immutable
class TxFilter {
  const TxFilter({
    this.walletIds = const {},
    this.kinds = const {},
    this.budgetItemIds = const {},
    this.unassignedOnly = false,
    this.tags = const {},
    this.from,
    this.to,
    this.walletKind,
    this.query = '',
  });

  static const none = TxFilter();

  /// Entries in (or transferred into) one of these wallets.
  final Set<String> walletIds;
  final Set<TxKind> kinds;

  /// Entries booked to one of these items **or any of their children**.
  final Set<String> budgetItemIds;

  /// Only entries without a budget item (expenses/income).
  final bool unassignedOnly;

  /// Entries carrying at least one of these tags.
  final Set<String> tags;

  /// Inclusive day range.
  final DateTime? from;
  final DateTime? to;

  /// Personal or business wallets only.
  final WalletKind? walletKind;

  /// Free text: note, tags, wallet and budget item names, or an amount.
  final String query;

  bool get hasDateRange => from != null || to != null;

  /// Number of active filter groups (search excluded).
  int get activeCount =>
      (walletIds.isNotEmpty ? 1 : 0) +
      (kinds.isNotEmpty ? 1 : 0) +
      (budgetItemIds.isNotEmpty || unassignedOnly ? 1 : 0) +
      (tags.isNotEmpty ? 1 : 0) +
      (hasDateRange ? 1 : 0) +
      (walletKind != null ? 1 : 0);

  bool get isEmpty => activeCount == 0 && query.trim().isEmpty;

  TxFilter copyWith({
    Set<String>? walletIds,
    Set<TxKind>? kinds,
    Set<String>? budgetItemIds,
    bool? unassignedOnly,
    Set<String>? tags,
    DateTime? from,
    DateTime? to,
    bool clearDates = false,
    WalletKind? walletKind,
    bool clearWalletKind = false,
    String? query,
  }) => TxFilter(
    walletIds: walletIds ?? this.walletIds,
    kinds: kinds ?? this.kinds,
    budgetItemIds: budgetItemIds ?? this.budgetItemIds,
    unassignedOnly: unassignedOnly ?? this.unassignedOnly,
    tags: tags ?? this.tags,
    from: clearDates ? null : (from ?? this.from),
    to: clearDates ? null : (to ?? this.to),
    walletKind: clearWalletKind ? null : (walletKind ?? this.walletKind),
    query: query ?? this.query,
  );

  /// The filter without its search text.
  TxFilter get withoutQuery => copyWith(query: '');

  /// Applies the filter (budget subtrees are expanded once).
  List<LedgerTx> apply(Iterable<LedgerTx> txs, TxFilterContext ctx) {
    final items = budgetItemIds.isEmpty ? const <String>{} : ctx.budgetSubtree(budgetItemIds);
    final q = LedgerSearch.normalize(query);
    final amount = LedgerSearch.amountQuery(query);
    return [
      for (final tx in txs)
        if (_matches(tx, ctx, items, q, amount)) tx,
    ];
  }

  /// Whether [tx] passes the filter.
  bool matches(LedgerTx tx, TxFilterContext ctx) => _matches(
    tx,
    ctx,
    budgetItemIds.isEmpty ? const <String>{} : ctx.budgetSubtree(budgetItemIds),
    LedgerSearch.normalize(query),
    LedgerSearch.amountQuery(query),
  );

  bool _matches(LedgerTx tx, TxFilterContext ctx, Set<String> items, String q, int? amount) {
    if (walletIds.isNotEmpty &&
        !walletIds.contains(tx.walletId) &&
        !(tx.isTransfer && walletIds.contains(tx.toWalletId))) {
      return false;
    }
    if (kinds.isNotEmpty && !kinds.contains(tx.kind)) return false;
    if (unassignedOnly) {
      if (tx.budgetItemId != null) return false;
      if (tx.kind != TxKind.expense && tx.kind != TxKind.income) return false;
    } else if (items.isNotEmpty && (tx.budgetItemId == null || !items.contains(tx.budgetItemId))) {
      return false;
    }
    if (tags.isNotEmpty && !tx.tags.any(tags.contains)) return false;
    final day = LedgerMath.dayOf(tx.date);
    if (from != null && day.isBefore(LedgerMath.dayOf(from!))) return false;
    if (to != null && day.isAfter(LedgerMath.dayOf(to!))) return false;
    if (walletKind != null) {
      final k = ctx.walletKindOf(tx.walletId);
      final kTo = tx.isTransfer && tx.toWalletId != null ? ctx.walletKindOf(tx.toWalletId!) : null;
      if (k != walletKind && kTo != walletKind) return false;
    }
    if (q.isNotEmpty) {
      if (amount != null && (tx.amountMilli.abs() == amount || tx.toAmountMilli?.abs() == amount)) return true;
      final hay = [
        tx.note ?? '',
        ...tx.tags,
        ctx.walletNameOf(tx.walletId) ?? '',
        if (tx.toWalletId != null) ctx.walletNameOf(tx.toWalletId!) ?? '',
        if (tx.budgetItemId != null) ctx.budgetNameOf(tx.budgetItemId!) ?? '',
      ];
      if (!hay.any((h) => LedgerSearch.normalize(h).contains(q))) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is TxFilter &&
      _setEq(other.walletIds, walletIds) &&
      _setEq(other.kinds, kinds) &&
      _setEq(other.budgetItemIds, budgetItemIds) &&
      other.unassignedOnly == unassignedOnly &&
      _setEq(other.tags, tags) &&
      other.from == from &&
      other.to == to &&
      other.walletKind == walletKind &&
      other.query == query;

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(walletIds),
    Object.hashAllUnordered(kinds),
    Object.hashAllUnordered(budgetItemIds),
    unassignedOnly,
    Object.hashAllUnordered(tags),
    from,
    to,
    walletKind,
    query,
  );
}

bool _setEq<T>(Set<T> a, Set<T> b) => a.length == b.length && a.containsAll(b);

/// Search normalisation: case, Arabic diacritics / tatweel, alef, teh
/// marbuta and yeh forms, and digit scripts are ignored.
abstract final class LedgerSearch {
  static final RegExp _marks = RegExp('[\u064B-\u065F\u0670ـ\u200E\u200F\u061C\u2066-\u2069]');

  static String normalize(String text) {
    var s = MoneyText.foldDigits(text.trim().toLowerCase());
    s = s.replaceAll(_marks, '');
    s = s
        .replaceAll(RegExp('[أإآٱ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي');
    return s.replaceAll(RegExp(r'\s+'), ' ');
  }

  /// The query as an amount in milli-units when it is a plain number
  /// (`"12.5"`, `"١٢٫٥"`), else null.
  static int? amountQuery(String query) {
    final t = query.trim();
    if (t.isEmpty || !RegExp(r'^[\d٠-٩۰-۹.,٫٬]+$').hasMatch(t)) return null;
    return MoneyText.parseMilli(t);
  }
}

/// Entries of one calendar day.
@immutable
class TxDayGroup {
  const TxDayGroup(this.day, this.txs);

  final DateTime day;

  /// Newest first.
  final List<LedgerTx> txs;
}

abstract final class TxGrouping {
  /// Groups [txs] by day, newest day first; entries inside a day newest
  /// first.
  static List<TxDayGroup> byDay(Iterable<LedgerTx> txs) {
    final sorted = [...txs]..sort(LedgerMath.compareNewestFirst);
    final out = <TxDayGroup>[];
    DateTime? day;
    var bucket = <LedgerTx>[];
    for (final tx in sorted) {
      final d = LedgerMath.dayOf(tx.date);
      if (day != d) {
        if (day != null) out.add(TxDayGroup(day, List.unmodifiable(bucket)));
        day = d;
        bucket = [];
      }
      bucket.add(tx);
    }
    if (day != null) out.add(TxDayGroup(day, List.unmodifiable(bucket)));
    return out;
  }

  /// Every tag used, most used first (ties alphabetical).
  static List<String> tagsByUse(Iterable<LedgerTx> txs) {
    final counts = <String, int>{};
    for (final tx in txs) {
      for (final t in tx.tags) {
        final tag = t.trim();
        if (tag.isEmpty) continue;
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    final tags = counts.keys.toList()
      ..sort((a, b) {
        final c = counts[b]!.compareTo(counts[a]!);
        return c != 0 ? c : a.compareTo(b);
      });
    return tags;
  }
}
