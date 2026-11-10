/// Manual exchange rates and minor units for the goals package (pure Dart,
/// exact: rates are read as the decimals they print as and every conversion
/// is rounded once, half-up, to the milli).
library;

import 'package:meta/meta.dart';

import '../../../../core/domain/money.dart';

/// One currency as the goals package needs it (mirrors a `currencies` row).
@immutable
class GoalsCurrency {
  const GoalsCurrency({required this.code, this.rateToBase = 1, this.decimals, this.symbol, this.isBase = false});

  final String code;

  /// 1 unit of [code] = [rateToBase] base units.
  final num rateToBase;

  /// Minor-unit digits configured by the user (null = catalogue default).
  final int? decimals;

  /// The user's own symbol (used only for codes the catalogue does not know).
  final String? symbol;
  final bool isBase;
}

/// The user's currencies: base code, manual rates and decimals.
@immutable
class GoalsRates {
  GoalsRates({required String base, Iterable<GoalsCurrency> currencies = const []})
    : base = base.toUpperCase(),
      _byCode = {for (final c in currencies) c.code.toUpperCase(): c};

  /// Only the base currency (tests, empty databases).
  factory GoalsRates.single(String base) => GoalsRates(base: base);

  /// Base currency code.
  final String base;
  final Map<String, GoalsCurrency> _byCode;

  Iterable<GoalsCurrency> get currencies => _byCode.values;

  /// All known codes, base first.
  List<String> get codes => [
    base,
    for (final c in _byCode.keys)
      if (c != base) c,
  ];

  GoalsCurrency? operator [](String code) => _byCode[code.toUpperCase()];

  /// Minor-unit digits of [code] (user configuration first).
  int decimalsOf(String code) {
    final c = code.toUpperCase();
    final d = _byCode[c]?.decimals;
    return CurrencyCatalog.decimalsFor(c, overrides: d == null ? null : {c: d});
  }

  /// Smallest amount step of [code] in milli-units (JOD 1, USD 10, JPY 1000).
  int minorStepOf(String code) {
    final d = decimalsOf(code);
    return d >= 3 ? 1 : BigInt.from(10).pow(3 - d).toInt();
  }

  /// Base units per unit of [code], or null when no usable rate is set.
  Rational? rateOf(String code) {
    final c = code.toUpperCase();
    if (c == base) return Rational.one;
    final r = _byCode[c]?.rateToBase;
    if (r == null || r <= 0 || (r is double && !r.isFinite)) return null;
    return Rational.fromNum(r);
  }

  /// Whether [code] can be converted (the base, or a positive rate).
  bool hasRate(String code) => rateOf(code) != null;

  /// [milli] of [code] in base milli-units, exact (1:1 when no rate).
  Rational toBaseExact(int milli, String code) => Rational.fromInt(milli) * (rateOf(code) ?? Rational.one);

  /// [milli] of [code] in base milli-units, half-up.
  int toBase(int milli, String code) => toBaseExact(milli, code).roundHalfUp();

  /// [milli] of [from] expressed in [to], exact and rounded once, half-up
  /// (identity for the same code; 1:1 for a missing rate).
  int convert(int milli, String from, String to) {
    if (from.toUpperCase() == to.toUpperCase()) return milli;
    final f = rateOf(from) ?? Rational.one;
    final t = rateOf(to) ?? Rational.one;
    return (Rational.fromInt(milli) * f / t).roundHalfUp();
  }

  /// [milli] of [from] as an amount a wallet in [to] can hold: converted
  /// exactly ([convert]) and rounded once, half-up, to [to]'s minor unit
  /// (100 JOD → 141.04 USD, not 141.044), so a wallet's balance is always
  /// the sum of the amounts its entries show. The same code is returned
  /// as is.
  int convertToMinor(int milli, String from, String to) {
    if (from.toUpperCase() == to.toUpperCase()) return milli;
    final f = rateOf(from) ?? Rational.one;
    final t = rateOf(to) ?? Rational.one;
    final step = minorStepOf(to);
    return (Rational.fromInt(milli) * f / (t * Rational.fromInt(step))).roundHalfUp() * step;
  }

  /// Rounds [value] (milli-units of [code]) **up** to the currency's minor
  /// unit – a plan that reaches its target never falls a fils short.
  int ceilToMinor(Rational value, String code) {
    final step = BigInt.from(minorStepOf(code));
    final scaled = value * Rational(BigInt.one, step);
    // Ceiling for positive values; negative values are clamped to zero.
    if (scaled.numerator <= BigInt.zero) return 0;
    final q = scaled.numerator ~/ scaled.denominator;
    final ceil = scaled.numerator % scaled.denominator == BigInt.zero ? q : q + BigInt.one;
    return (ceil * step).toInt();
  }
}
