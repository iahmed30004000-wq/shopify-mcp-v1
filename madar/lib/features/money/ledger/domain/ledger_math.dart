/// Wallet balances, running balances, balance history and totals – exact
/// integer milli-unit arithmetic (pure Dart).
///
/// ### Balance rule
/// `balance = opening + Σ effects`, where a transaction's effect on a wallet
/// is:
/// * income: `+amount` on its wallet;
/// * expense: `−amount` on its wallet;
/// * transfer: `−amount` on the source wallet and `+toAmount` (or `+amount`
///   when no separate received amount was stored) on the destination;
/// * adjustment: its signed amount on its wallet.
library;

import 'package:meta/meta.dart';

import '../../../../core/domain/enums.dart';
import '../../../../core/domain/money.dart';
import 'ledger_models.dart';

/// One point of a wallet's balance history: the closing balance of [day].
@immutable
class BalancePoint {
  const BalancePoint(this.day, this.balanceMilli);

  final DateTime day;
  final int balanceMilli;

  @override
  bool operator ==(Object other) => other is BalancePoint && other.day == day && other.balanceMilli == balanceMilli;

  @override
  int get hashCode => Object.hash(day, balanceMilli);

  @override
  String toString() => 'BalancePoint(${day.toIso8601String().substring(0, 10)} $balanceMilli)';
}

abstract final class LedgerMath {
  /// The signed effect of [tx] on [walletId] (0 when unrelated).
  static int effectOn(LedgerTx tx, String walletId) {
    var effect = 0;
    if (tx.walletId == walletId) {
      effect += switch (tx.kind) {
        TxKind.income => tx.amountMilli.abs(),
        TxKind.expense => -tx.amountMilli.abs(),
        TxKind.transfer => -tx.amountMilli.abs(),
        TxKind.adjustment => tx.amountMilli,
      };
    }
    if (tx.kind == TxKind.transfer && tx.toWalletId == walletId) effect += tx.receivedMilli;
    return effect;
  }

  /// Calendar day of [t] (local midnight).
  static DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

  /// Chronological order: day, then insertion time, then id.
  static int compareChrono(LedgerTx a, LedgerTx b) {
    final d = dayOf(a.date).compareTo(dayOf(b.date));
    if (d != 0) return d;
    final c = a.createdAt.compareTo(b.createdAt);
    if (c != 0) return c;
    return a.id.compareTo(b.id);
  }

  /// Newest first (the order lists show).
  static int compareNewestFirst(LedgerTx a, LedgerTx b) => compareChrono(b, a);

  /// Balance of every wallet: opening + effects of [txs] up to and
  /// including the day [asOf] (all of them when null).
  static Map<String, int> balances(Iterable<LedgerWallet> wallets, Iterable<LedgerTx> txs, {DateTime? asOf}) {
    final out = {for (final w in wallets) w.id: w.openingMilli};
    final limit = asOf == null ? null : dayOf(asOf);
    for (final tx in txs) {
      if (limit != null && dayOf(tx.date).isAfter(limit)) continue;
      if (out.containsKey(tx.walletId)) out[tx.walletId] = out[tx.walletId]! + effectOn(tx, tx.walletId);
      final to = tx.toWalletId;
      if (tx.kind == TxKind.transfer && to != null && to != tx.walletId && out.containsKey(to)) {
        out[to] = out[to]! + effectOn(tx, to);
      }
    }
    return out;
  }

  /// Balance of one wallet (see [balances]).
  static int balanceOf(LedgerWallet wallet, Iterable<LedgerTx> txs, {DateTime? asOf}) {
    final limit = asOf == null ? null : dayOf(asOf);
    var b = wallet.openingMilli;
    for (final tx in txs) {
      if (limit != null && dayOf(tx.date).isAfter(limit)) continue;
      b += effectOn(tx, wallet.id);
    }
    return b;
  }

  /// The wallet's balance right after each of its transactions (by id), in
  /// chronological order ([compareChrono]).
  static Map<String, int> runningBalances(LedgerWallet wallet, Iterable<LedgerTx> txs) {
    final mine = [
      for (final tx in txs)
        if (tx.touches(wallet.id)) tx,
    ]..sort(compareChrono);
    var b = wallet.openingMilli;
    return {for (final tx in mine) tx.id: b += effectOn(tx, wallet.id)};
  }

  /// Daily closing balances of [wallet] from [from] to [to] (inclusive).
  /// Everything before [from] is folded into the first point. When the range
  /// holds more than [maxPoints] days, points are sampled evenly (the last
  /// day is always kept).
  static List<BalancePoint> balanceSeries(
    LedgerWallet wallet,
    Iterable<LedgerTx> txs, {
    required DateTime from,
    required DateTime to,
    int maxPoints = 120,
  }) {
    final start = dayOf(from), end = dayOf(to);
    if (end.isBefore(start)) return const [];
    final byDay = <DateTime, int>{};
    var before = wallet.openingMilli;
    for (final tx in txs) {
      final e = effectOn(tx, wallet.id);
      if (e == 0) continue;
      final d = dayOf(tx.date);
      if (d.isBefore(start)) {
        before += e;
      } else if (!d.isAfter(end)) {
        byDay[d] = (byDay[d] ?? 0) + e;
      }
    }
    final days = <DateTime>[];
    for (var d = start; !d.isAfter(end); d = DateTime(d.year, d.month, d.day + 1)) {
      days.add(d);
    }
    final points = <BalancePoint>[];
    var b = before;
    for (final d in days) {
      b += byDay[d] ?? 0;
      points.add(BalancePoint(d, b));
    }
    if (points.length <= maxPoints || maxPoints < 2) return points;
    final step = (points.length - 1) / (maxPoints - 1);
    return [for (var i = 0; i < maxPoints; i++) points[(i * step).round().clamp(0, points.length - 1)]];
  }

  /// The day of the oldest entry touching [wallet] (null without any).
  static DateTime? firstDay(LedgerWallet wallet, Iterable<LedgerTx> txs) {
    DateTime? first;
    for (final tx in txs) {
      if (!tx.touches(wallet.id)) continue;
      final d = dayOf(tx.date);
      if (first == null || d.isBefore(first)) first = d;
    }
    return first;
  }
}

/// Balances summed per currency and converted to the base currency, overall
/// and per wallet kind (personal / business).
@immutable
class LedgerTotals {
  const LedgerTotals({
    required this.base,
    required this.byCurrency,
    required this.byKindCurrency,
    required this.baseMilli,
    required this.baseByKind,
    required this.missingRates,
    required this.walletCount,
  });

  /// Totals of the non-archived wallets (archived ones too when
  /// [includeArchived]).
  factory LedgerTotals.of(
    Iterable<LedgerWallet> wallets,
    Map<String, int> balances,
    LedgerRates rates, {
    bool includeArchived = false,
  }) {
    final byCurrency = <String, int>{};
    final byKind = <WalletKind, Map<String, int>>{};
    final all = BaseSum(rates);
    final perKind = {for (final k in WalletKind.values) k: BaseSum(rates)};
    var count = 0;
    for (final w in wallets) {
      if (w.archived && !includeArchived) continue;
      count++;
      final b = balances[w.id] ?? w.openingMilli;
      byCurrency[w.currency] = (byCurrency[w.currency] ?? 0) + b;
      final k = byKind.putIfAbsent(w.kind, () => {});
      k[w.currency] = (k[w.currency] ?? 0) + b;
      all.add(b, w.currency);
      perKind[w.kind]!.add(b, w.currency);
    }
    return LedgerTotals(
      base: rates.base,
      byCurrency: Map.unmodifiable(byCurrency),
      byKindCurrency: Map.unmodifiable({for (final e in byKind.entries) e.key: Map<String, int>.unmodifiable(e.value)}),
      baseMilli: all.milli,
      baseByKind: Map.unmodifiable({for (final e in perKind.entries) e.key: e.value.milli}),
      missingRates: Set.unmodifiable(all.missing),
      walletCount: count,
    );
  }

  /// Base currency code.
  final String base;

  /// Native totals per currency code.
  final Map<String, int> byCurrency;

  /// Native totals per currency, per wallet kind.
  final Map<WalletKind, Map<String, int>> byKindCurrency;

  /// Everything converted to the base currency (rounded once).
  final int baseMilli;

  /// Base totals per wallet kind (each rounded once).
  final Map<WalletKind, int> baseByKind;

  /// Currencies left out of the base totals for lack of a rate.
  final Set<String> missingRates;

  final int walletCount;

  Money get total => Money(baseMilli, base);

  int kindMilli(WalletKind kind) => baseByKind[kind] ?? 0;

  /// Whether any business wallet exists (so the split is worth showing).
  bool get hasBusiness => (byKindCurrency[WalletKind.business] ?? const {}).isNotEmpty;
  bool get hasPersonal => (byKindCurrency[WalletKind.personal] ?? const {}).isNotEmpty;
}
