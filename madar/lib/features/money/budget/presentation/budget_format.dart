import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../../../core/domain/budget_math.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/domain/money.dart';
import '../../../../core/i18n/formatters.dart';
import '../../money_glyphs.dart';
import '../data/budget_repository.dart';

/// Money, percent and period formatting of the budget screens: the app's
/// digit style, each currency's decimals and symbol, and every amount
/// bidi-isolated (right-to-left in Arabic, so a minus sign and the currency
/// abbreviation land on the correct side).
@immutable
class BudgetFormat {
  const BudgetFormat(this.fmt, {this.currencies = BudgetCurrencies.fallback});

  factory BudgetFormat.of(BuildContext context, [BudgetCurrencies currencies = BudgetCurrencies.fallback]) =>
      BudgetFormat(MadarFormatter.of(context), currencies: currencies);

  final MadarFormatter fmt;
  final BudgetCurrencies currencies;

  bool get arabic => fmt.isArabic;
  String get base => currencies.base;

  MoneyDigits get _digits => fmt.arabicIndic ? MoneyDigits.arabicIndic : MoneyDigits.western;

  /// The display symbol of [code] (`د.أ` / `JOD`, `$`, or the user's own
  /// for a currency Madar does not know).
  String symbol(String code) {
    final c = code.toUpperCase();
    return _customSymbol(c) ?? CurrencyCatalog.symbolFor(c, arabic: arabic);
  }

  String? _customSymbol(String code) => CurrencyCatalog.knownCodes.contains(code) ? null : currencies.symbols[code];

  /// `12.500 JOD` / `١٢٫٥٠٠ د.أ` (base currency when [currency] is null).
  String money(int milli, [String? currency]) {
    final code = (currency ?? base).toUpperCase();
    final s = Money(milli, code).format(
      locale: fmt.languageCode,
      digits: _digits,
      decimals: currencies.decimalsOf(code),
      symbol: _customSymbol(code),
    );
    return _isolate(MoneyGlyphs.legibleGroups(s));
  }

  /// The amount without a symbol (`1,234.5` → `1,234.500`).
  String amount(int milli, [String? currency]) {
    final code = (currency ?? base).toUpperCase();
    final s = Money(
      milli,
      code,
    ).formatAmount(locale: fmt.languageCode, digits: _digits, decimals: currencies.decimalsOf(code));
    return _isolate(MoneyGlyphs.legibleGroups(s));
  }

  String _isolate(String s) => arabic ? BidiIsolate.rtl(s) : BidiIsolate.ltr(s);

  /// A compact amount for chart axes (`1.2k`), no symbol.
  String compact(int milli) {
    final units = milli / Money.milliPerUnit;
    final s = NumberFormat.compact(locale: 'en').format(units);
    return fmt.localizeDigits(s);
  }

  /// An editable amount: no grouping, trailing zeros dropped, the user's
  /// digits (`12.5`, `١٢٫٥`, `0`).
  String inputAmount(int milli) {
    final neg = milli < 0;
    final a = milli.abs();
    var s = '${a ~/ 1000}';
    final frac = (a % 1000).toString().padLeft(3, '0').replaceFirst(RegExp(r'0+$'), '');
    if (frac.isNotEmpty) s = '$s.$frac';
    return fmt.localizeDigits(neg ? '-$s' : s);
  }

  /// `33.33%` / `٣٣٫٣٣٪` for a percent (0–100); `–` for null.
  String percent(double? pct, {int maxDecimals = 2}) {
    if (pct == null || !pct.isFinite) return '–';
    final n = fmt.formatNumber(_tidy(pct), maxDecimals: maxDecimals, grouping: false);
    final s = fmt.arabicIndic ? '$n${Digits.arabicPercent}' : '$n%';
    return arabic ? BidiIsolate.rtl(s) : BidiIsolate.ltr(s);
  }

  /// An editable percent (`33.33`, trailing zeros dropped).
  String inputPercent(double pct) => fmt.formatNumber(_tidy(pct), maxDecimals: 2, grouping: false);

  /// Weeks per month (`4`, `4.345`).
  String weeks(num w) => fmt.formatNumber(w, maxDecimals: 3, grouping: false);

  /// Plain integer in the user's digits.
  String count(int n) => fmt.formatInt(n);

  /// `September 2026` for a month window; `19 – 25 Sep` for a week.
  String window(BudgetWindow w) {
    final lang = fmt.languageCode;
    if (w.period == BudgetPeriod.monthly) return fmt.localizeDigits(DateFormat.yMMMM(lang).format(w.start));
    final last = w.end.subtract(const Duration(hours: 12));
    final sameMonth = last.month == w.start.month;
    final from = sameMonth ? DateFormat.d(lang).format(w.start) : DateFormat.MMMd(lang).format(w.start);
    final to = DateFormat.MMMd(lang).format(last);
    return fmt.localizeDigits('$from – $to');
  }

  /// A short label of a window for chart axes (`Sep`, `19/9`).
  String windowShort(BudgetWindow w) {
    final lang = fmt.languageCode;
    if (w.period == BudgetPeriod.monthly) return fmt.localizeDigits(DateFormat.MMM(lang).format(w.start));
    return fmt.localizeDigits(DateFormat.Md(lang).format(w.start));
  }

  /// Kills binary-float noise (33.333333333333336 → 33.3333…) before
  /// rounding for display.
  static double _tidy(double v) => (v * 1e8).roundToDouble() / 1e8;
}
