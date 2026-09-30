/// Plain value types of the ledger (wallets, currencies, transactions) and
/// exact currency conversion.
///
/// Pure Dart: the data layer maps database rows to these types, so every
/// rule here is unit-testable without a database or Flutter.
library;

import 'package:meta/meta.dart';

import '../../../../core/domain/enums.dart';
import '../../../../core/domain/money.dart';

/// A currency with the user's manual exchange rate.
@immutable
class LedgerCurrency {
  const LedgerCurrency({
    required this.code,
    this.nameAr = '',
    this.nameEn = '',
    this.symbol = '',
    this.decimals = 2,
    this.rateToBase = 1,
    this.isBase = false,
    this.sortOrder = 0,
  });

  /// ISO-like code (`JOD`, `USD`, or the user's own, e.g. `USDT`).
  final String code;
  final String nameAr;
  final String nameEn;

  /// The user's symbol (shown in Arabic; English shows the code or `$ € £`).
  final String symbol;

  /// Minor-unit digits shown (0–3).
  final int decimals;

  /// As stored: 1 unit of this currency = [rateToBase] base units.
  final double rateToBase;
  final bool isBase;
  final int sortOrder;

  /// The rate as the exact decimal it prints as, or null when unusable
  /// (zero, negative, NaN). The base currency is always exactly 1.
  Rational? get rate {
    if (isBase) return Rational.one;
    final r = rateToBase;
    if (!r.isFinite || r <= 0) return null;
    return Rational.fromNum(r);
  }

  /// The localised name, falling back to the other language, then the code.
  String name({required bool arabic}) {
    final first = arabic ? nameAr : nameEn;
    final second = arabic ? nameEn : nameAr;
    if (first.trim().isNotEmpty) return first.trim();
    if (second.trim().isNotEmpty) return second.trim();
    return code;
  }

  LedgerCurrency copyWith({
    String? code,
    String? nameAr,
    String? nameEn,
    String? symbol,
    int? decimals,
    double? rateToBase,
    bool? isBase,
    int? sortOrder,
  }) => LedgerCurrency(
    code: code ?? this.code,
    nameAr: nameAr ?? this.nameAr,
    nameEn: nameEn ?? this.nameEn,
    symbol: symbol ?? this.symbol,
    decimals: decimals ?? this.decimals,
    rateToBase: rateToBase ?? this.rateToBase,
    isBase: isBase ?? this.isBase,
    sortOrder: sortOrder ?? this.sortOrder,
  );

  @override
  bool operator ==(Object other) =>
      other is LedgerCurrency &&
      other.code == code &&
      other.nameAr == nameAr &&
      other.nameEn == nameEn &&
      other.symbol == symbol &&
      other.decimals == decimals &&
      other.rateToBase == rateToBase &&
      other.isBase == isBase &&
      other.sortOrder == sortOrder;

  @override
  int get hashCode => Object.hash(code, nameAr, nameEn, symbol, decimals, rateToBase, isBase, sortOrder);

  @override
  String toString() => 'LedgerCurrency($code ×$rateToBase${isBase ? ' base' : ''})';
}

/// A wallet (cash, bank account, card, a courier's COD float …).
@immutable
class LedgerWallet {
  const LedgerWallet({
    required this.id,
    required this.name,
    required this.currency,
    this.openingMilli = 0,
    this.kind = WalletKind.personal,
    this.color,
    this.icon,
    this.archived = false,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final String currency;

  /// Opening balance in the wallet's currency (milli-units).
  final int openingMilli;
  final WalletKind kind;

  /// ARGB32 colour chosen by the user (null = theme default).
  final int? color;

  /// Curated icon key (`InteractionIcons`), null = wallet.
  final String? icon;
  final bool archived;
  final int sortOrder;

  bool get isBusiness => kind == WalletKind.business;

  @override
  bool operator ==(Object other) =>
      other is LedgerWallet &&
      other.id == id &&
      other.name == name &&
      other.currency == currency &&
      other.openingMilli == openingMilli &&
      other.kind == kind &&
      other.color == color &&
      other.icon == icon &&
      other.archived == archived &&
      other.sortOrder == sortOrder;

  @override
  int get hashCode => Object.hash(id, name, currency, openingMilli, kind, color, icon, archived, sortOrder);

  @override
  String toString() => 'LedgerWallet($id "$name" $currency)';
}

/// One ledger entry (mirrors the `transactions` table).
///
/// [amountMilli] is positive for income, expense and transfer (the direction
/// comes from [kind]); an adjustment keeps its sign.
@immutable
class LedgerTx {
  const LedgerTx({
    required this.id,
    required this.walletId,
    required this.kind,
    required this.amountMilli,
    required this.date,
    this.budgetItemId,
    this.toWalletId,
    this.toAmountMilli,
    this.note,
    this.tags = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? date;

  final String id;
  final String walletId;
  final TxKind kind;
  final int amountMilli;

  /// Calendar day (local midnight).
  final DateTime date;
  final String? budgetItemId;
  final String? toWalletId;

  /// Amount received by [toWalletId] in its own currency (null = same
  /// number as [amountMilli], i.e. same currency).
  final int? toAmountMilli;
  final String? note;
  final List<String> tags;

  /// Insertion time – orders entries of the same day.
  final DateTime createdAt;

  bool get isTransfer => kind == TxKind.transfer;

  /// Whether this transfer lands in another wallet.
  bool get hasDestination => isTransfer && toWalletId != null;

  /// What the destination wallet receives.
  int get receivedMilli => (toAmountMilli ?? amountMilli).abs();

  /// The note, trimmed, or null.
  String? get cleanNote {
    final n = note?.trim();
    return n == null || n.isEmpty ? null : n;
  }

  /// Whether this entry moves money in or out of [walletId].
  bool touches(String walletId) => this.walletId == walletId || (isTransfer && toWalletId == walletId);

  @override
  bool operator ==(Object other) =>
      other is LedgerTx &&
      other.id == id &&
      other.walletId == walletId &&
      other.kind == kind &&
      other.amountMilli == amountMilli &&
      other.date == date &&
      other.budgetItemId == budgetItemId &&
      other.toWalletId == toWalletId &&
      other.toAmountMilli == toAmountMilli &&
      other.note == note &&
      _listEq(other.tags, tags) &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    walletId,
    kind,
    amountMilli,
    date,
    budgetItemId,
    toWalletId,
    toAmountMilli,
    note,
    Object.hashAll(tags),
    createdAt,
  );

  @override
  String toString() => 'LedgerTx($id ${kind.name} $amountMilli @$walletId ${date.toIso8601String().substring(0, 10)})';
}

bool _listEq(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Manual exchange rates of the user's currencies, applied exactly.
///
/// Conversions multiply milli-units by exact [Rational] rates and round
/// **once**, half-up (see [Rational.roundHalfUp]). Currencies without a usable
/// rate are *excluded* from base totals and reported through [missing]
/// instead of being silently counted 1:1.
@immutable
class LedgerRates {
  LedgerRates({required String base, Map<String, Rational> rates = const {}})
    : base = base.toUpperCase(),
      _rates = {for (final e in rates.entries) e.key.toUpperCase(): e.value};

  /// Rates from the currencies table (the one flagged `isBase` is the base;
  /// [fallbackBase] when none is).
  factory LedgerRates.of(Iterable<LedgerCurrency> currencies, {String fallbackBase = 'JOD'}) {
    String? base;
    final rates = <String, Rational>{};
    for (final c in currencies) {
      if (c.isBase) base = c.code;
      final r = c.rate;
      if (r != null) rates[c.code] = r;
    }
    return LedgerRates(base: base ?? fallbackBase, rates: rates);
  }

  final String base;
  final Map<String, Rational> _rates;

  /// Base units per unit of [code] (exactly 1 for the base), or null.
  Rational? rateOf(String code) {
    final c = code.toUpperCase();
    if (c == base) return Rational.one;
    return _rates[c];
  }

  bool hasRate(String code) => rateOf(code) != null;

  /// [milli] of [code] in the base currency, exact (null without a rate).
  Rational? toBaseExact(int milli, String code) {
    final r = rateOf(code);
    return r == null ? null : Rational.fromInt(milli) * r;
  }

  /// [milli] of [code] in base milli-units, half-up (null without a rate).
  int? toBase(int milli, String code) => toBaseExact(milli, code)?.roundHalfUp();

  /// Converts [milli] of [from] into [to] (`milli × rate(from) / rate(to)`),
  /// exact and rounded once; [decimals] additionally rounds to the target's
  /// minor unit (e.g. 2 for USD). Null when either rate is missing.
  int? convert(int milli, String from, String to, {int? decimals}) {
    if (from.toUpperCase() == to.toUpperCase()) {
      return decimals == null ? milli : Money(milli, to).roundToMinor(decimals: decimals).milli;
    }
    final rf = rateOf(from), rt = rateOf(to);
    if (rf == null || rt == null) return null;
    final exact = (Rational.fromInt(milli) * rf / rt).roundHalfUp();
    return decimals == null ? exact : Money(exact, to).roundToMinor(decimals: decimals).milli;
  }

  /// Units of [to] per unit of [from] (null when a rate is missing).
  Rational? cross(String from, String to) {
    final rf = rateOf(from), rt = rateOf(to);
    if (rf == null || rt == null) return null;
    return rf / rt;
  }

  /// Rates as plain numbers for [BudgetSettings.ratesToBase].
  Map<String, num> get asNumbers => {for (final e in _rates.entries) e.key: e.value.toDouble()};
}

/// A running exact sum in the base currency that remembers which currencies
/// could not be converted.
class BaseSum {
  BaseSum(this.rates);

  final LedgerRates rates;
  Rational _sum = Rational.zero;
  final Set<String> missing = {};

  void add(int milli, String code) {
    if (milli == 0) return;
    final v = rates.toBaseExact(milli, code);
    if (v == null) {
      missing.add(code.toUpperCase());
    } else {
      _sum += v;
    }
  }

  Rational get exact => _sum;

  /// The sum, rounded once, half-up, to the milli.
  int get milli => _sum.roundHalfUp();
}
