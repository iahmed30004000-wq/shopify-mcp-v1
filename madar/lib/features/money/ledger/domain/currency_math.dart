/// Manual exchange rates: entry, storage and exact re-basing (pure Dart).
///
/// The `currencies.rate_to_base` column is a REAL. Rates are therefore
/// computed exactly as [Rational]s and stored as the *shortest* decimal
/// (at most [RateMath.storedDigits] significant digits) within
/// [RateMath.tolerance] of the exact value. That decimal survives the double
/// unchanged and reads back (via [Rational.fromNum]) as itself, and a rate
/// re-based there and back returns to the very decimal the user typed
/// (`0.709` → `1.410437235543` → `0.709`). The relative error is at most
/// 10⁻¹², i.e. under one milli on a billion units.
library;

import 'package:meta/meta.dart';

import '../../../../core/domain/money.dart';
import 'ledger_format.dart';
import 'ledger_models.dart';

abstract final class RateMath {
  /// Most significant digits kept when a computed rate is stored (a double
  /// holds 15 exactly).
  static const int storedDigits = 15;

  /// Largest relative difference between a stored rate and its exact value.
  static final Rational tolerance = Rational(BigInt.one, BigInt.from(10).pow(12));

  /// The double to store for [rate]: the shortest decimal (half-up at each
  /// length) within [tolerance] of it.
  static double storable(Rational rate) {
    final exact = rate.abs();
    final limit = exact * tolerance;
    for (var digits = 1; digits < storedDigits; digits++) {
      final text = RateText.decimal(rate, significant: digits);
      final candidate = Rational.tryParse(text)!;
      if ((candidate - rate).abs() <= limit) return double.parse(text);
    }
    return double.parse(RateText.decimal(rate, significant: storedDigits));
  }

  /// Parses a user-typed positive rate (`"0.709"`, `"٠٫٧٠٩"`, `"13,000"`);
  /// null for empty, zero, negative or malformed input.
  static Rational? parse(String text) {
    final c = MoneyText.canonicalDecimal(text);
    if (c == null) return null;
    final r = Rational.tryParse(c);
    if (r == null || r.isNegative || r.isZero) return null;
    return r;
  }

  /// `1 / rate`.
  static Rational inverse(Rational rate) => Rational.one / rate;

  /// The rate to store when the user types "1 [code] = [value] base" or,
  /// with [inverted], "1 base = [value] [code]".
  static Rational fromEntry(Rational value, {bool inverted = false}) => inverted ? inverse(value) : value;
}

/// One currency's rate before and after moving the base.
@immutable
class RebaseRow {
  const RebaseRow({required this.code, required this.oldRate, required this.newRate, required this.stored});

  final String code;

  /// 1 unit = [oldRate] units of the old base (null = no usable rate).
  final Rational? oldRate;

  /// 1 unit = [newRate] units of the new base, exact (null = no usable rate).
  final Rational? newRate;

  /// What will be written to the database.
  final double? stored;
}

/// The effect of making [newBase] the base currency: every rate is
/// re-expressed exactly as `rate / rate(newBase)`, so every conversion (and
/// every total) keeps its value.
@immutable
class RebasePlan {
  const RebasePlan({required this.oldBase, required this.newBase, required this.rows});

  final String oldBase;
  final String newBase;
  final List<RebaseRow> rows;

  /// The plan, or null when [newBase] is unknown, already the base or has no
  /// usable rate.
  static RebasePlan? of(Iterable<LedgerCurrency> currencies, String newBase) {
    final list = currencies.toList();
    final target = list.where((c) => c.code == newBase).firstOrNull;
    final old = list.where((c) => c.isBase).firstOrNull;
    if (target == null || target.isBase) return null;
    final pivot = target.rate;
    if (pivot == null) return null;
    return RebasePlan(
      oldBase: old?.code ?? '',
      newBase: newBase,
      rows: [
        for (final c in list)
          () {
            final r = c.rate;
            final next = c.code == newBase ? Rational.one : (r == null ? null : r / pivot);
            return RebaseRow(
              code: c.code,
              oldRate: r,
              newRate: next,
              stored: next == null ? null : (c.code == newBase ? 1.0 : RateMath.storable(next)),
            );
          }(),
      ],
    );
  }

  RebaseRow? row(String code) => rows.where((r) => r.code == code).firstOrNull;
}

/// Currency codes the user may add.
abstract final class CurrencyCodes {
  static final RegExp _valid = RegExp(r'^[A-Z][A-Z0-9]{1,5}$');

  /// Upper-cased, trimmed, Latin-only code, or null when invalid (2–6
  /// characters, starting with a letter).
  static String? normalize(String input) {
    final c = MoneyText.foldDigits(input).trim().toUpperCase();
    return _valid.hasMatch(c) ? c : null;
  }
}
