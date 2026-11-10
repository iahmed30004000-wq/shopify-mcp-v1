/// What a list needs to know about money to show its prices: the base
/// currency, each currency's decimals (JOD has three) and the user's own
/// symbols. Pure Dart; the rows are read in the data layer.
library;

import 'package:meta/meta.dart';

import '../../../core/domain/money.dart';

@immutable
class ListCurrencies {
  const ListCurrencies({
    required this.base,
    this.decimals = const {},
    this.symbols = const {},
    this.codes = const [],
  });

  /// Before the currencies table is readable (and in a test with none).
  static const fallback = ListCurrencies(base: 'JOD', codes: ['JOD']);

  /// Upper-case code of the base currency.
  final String base;

  /// Code → decimals, when the user changed them.
  final Map<String, int> decimals;

  /// Code → the user's own symbol (for currencies Madar does not know).
  final Map<String, String> symbols;

  /// Codes in the user's order.
  final List<String> codes;

  /// The currency a list's prices are in: its own, else the base.
  String of(String? listCurrency) {
    final c = listCurrency?.trim();
    return c == null || c.isEmpty ? base : c.toUpperCase();
  }

  int decimalsOf(String code) => CurrencyCatalog.decimalsFor(code.toUpperCase(), overrides: decimals);

  /// The user's own symbol for [code], or null when Madar knows the
  /// currency (and has a better one).
  String? customSymbol(String code) {
    final c = code.toUpperCase();
    return CurrencyCatalog.knownCodes.contains(c) ? null : symbols[c];
  }

  @override
  bool operator ==(Object other) =>
      other is ListCurrencies &&
      other.base == base &&
      other.decimals.length == decimals.length &&
      other.symbols.length == symbols.length &&
      other.codes.length == codes.length;

  @override
  int get hashCode => Object.hash(base, decimals.length, symbols.length, codes.length);
}
