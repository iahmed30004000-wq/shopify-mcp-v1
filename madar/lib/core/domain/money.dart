/// Exact money arithmetic for Madar.
///
/// * Amounts are integer **milli-units** (`amount × 1000`), the same unit the
///   database stores (`*_milli` columns), so 3-decimal currencies (JOD, LYD)
///   and 2-decimal ones (USD, EGP, SYP) share one exact representation.
/// * Every operation that can produce a fraction of a milli (percentages,
///   exchange rates, weeks-per-month) is computed exactly with [Rational] and
///   rounded **once**, half-up (ties away from zero) to the milli –
///   see [Rational.roundHalfUp].
/// * Text is parsed from Western, Arabic-Indic (٠-٩) and Persian (۰-۹) digits
///   with `.`/`,`/`٫`/`٬` separators (`"1,234.5"`, `"1٬234٫5"`, `"١٢٫٥ د.أ"`).
///
/// Pure Dart (no Flutter) – safe to use from isolates and unit tests.
library;

import 'package:intl/intl.dart';
import 'package:meta/meta.dart';

// ---------------------------------------------------------------- Rational --

/// An exact rational number `numerator / denominator` (denominator > 0,
/// always reduced). Used for exchange rates, percentages and the
/// weeks-per-month factor so money math never touches binary floating point.
@immutable
class Rational implements Comparable<Rational> {
  const Rational._(this.numerator, this.denominator);

  /// `n / d`, normalised (sign on the numerator, reduced by the gcd).
  factory Rational(BigInt n, [BigInt? d]) {
    var den = d ?? BigInt.one;
    if (den == BigInt.zero) throw ArgumentError('Denominator must not be zero');
    var num = n;
    if (den.isNegative) {
      num = -num;
      den = -den;
    }
    final g = num.gcd(den);
    if (g > BigInt.one) {
      num = num ~/ g;
      den = den ~/ g;
    }
    return Rational._(num, den);
  }

  /// `n / d` from ints.
  factory Rational.fromInt(int n, [int d = 1]) => Rational(BigInt.from(n), BigInt.from(d));

  /// The exact decimal value a number *prints as*: an int exactly, a double
  /// via its shortest round-trip representation (`0.709` → 709/1000,
  /// `4.345` → 869/200). Throws for NaN / infinity.
  factory Rational.fromNum(num value) {
    if (value is int) return Rational.fromInt(value);
    if (value.isNaN || value.isInfinite) throw ArgumentError.value(value, 'value', 'Not a finite number');
    return Rational.tryParse(value.toString())!;
  }

  static final Rational zero = Rational._(BigInt.zero, BigInt.one);
  static final Rational one = Rational._(BigInt.one, BigInt.one);
  static final Rational hundred = Rational._(BigInt.from(100), BigInt.one);
  static final Rational thousand = Rational._(BigInt.from(1000), BigInt.one);

  static final RegExp _decimal = RegExp(r'^([+-]?)(\d*)(?:\.(\d*))?(?:[eE]([+-]?\d+))?$');

  /// Parses a plain decimal (`"12"`, `"-0.5"`, `"4.345"`, `"1e-3"`). Digits
  /// may be Arabic-Indic / Persian and `٫` is accepted as the decimal point;
  /// no grouping separators (see [MoneyText.canonicalDecimal] for those).
  static Rational? tryParse(String text) {
    final s = MoneyText.foldDigits(text.trim()).replaceAll(',', '');
    final m = _decimal.firstMatch(s);
    if (m == null) return null;
    final intPart = m.group(2) ?? '';
    final frac = m.group(3) ?? '';
    if (intPart.isEmpty && frac.isEmpty) return null;
    var num = BigInt.parse('${intPart.isEmpty ? '0' : intPart}$frac');
    var den = BigInt.from(10).pow(frac.length);
    final exp = int.tryParse(m.group(4) ?? '0') ?? 0;
    if (exp.abs() > 400) return null;
    if (exp > 0) num *= BigInt.from(10).pow(exp);
    if (exp < 0) den *= BigInt.from(10).pow(-exp);
    if (m.group(1) == '-') num = -num;
    return Rational(num, den);
  }

  final BigInt numerator;
  final BigInt denominator;

  bool get isZero => numerator == BigInt.zero;
  bool get isNegative => numerator.isNegative;
  bool get isInteger => denominator == BigInt.one;

  Rational operator +(Rational o) =>
      Rational(numerator * o.denominator + o.numerator * denominator, denominator * o.denominator);
  Rational operator -(Rational o) =>
      Rational(numerator * o.denominator - o.numerator * denominator, denominator * o.denominator);
  Rational operator *(Rational o) => Rational(numerator * o.numerator, denominator * o.denominator);
  Rational operator /(Rational o) {
    if (o.isZero) throw ArgumentError('Division by zero');
    return Rational(numerator * o.denominator, denominator * o.numerator);
  }

  Rational operator -() => Rational._(-numerator, denominator);
  Rational abs() => isNegative ? -this : this;

  bool operator <(Rational o) => compareTo(o) < 0;
  bool operator <=(Rational o) => compareTo(o) <= 0;
  bool operator >(Rational o) => compareTo(o) > 0;
  bool operator >=(Rational o) => compareTo(o) >= 0;

  @override
  int compareTo(Rational o) => (numerator * o.denominator).compareTo(o.numerator * denominator);

  /// Rounds to the nearest integer; exact halves go **away from zero**
  /// (`2.5 → 3`, `-2.5 → -3`, `21.7249 → 22`). This is the single rounding
  /// rule of all Madar money math ("half-up").
  int roundHalfUp() {
    final twice = numerator.abs() * BigInt.two + denominator;
    final q = twice ~/ (denominator * BigInt.two);
    return (isNegative ? -q : q).toInt();
  }

  /// Truncates toward zero.
  int truncate() => (numerator ~/ denominator).toInt();

  double toDouble() => numerator / denominator;

  @override
  bool operator ==(Object other) =>
      other is Rational && other.numerator == numerator && other.denominator == denominator;

  @override
  int get hashCode => Object.hash(numerator, denominator);

  @override
  String toString() => isInteger ? '$numerator' : '$numerator/$denominator';
}

// ---------------------------------------------------------- CurrencyCatalog --

/// Static facts about currency codes. The user's own configuration (the
/// `currencies` table) always wins: pass its `decimals` as an override.
abstract final class CurrencyCatalog {
  /// Minor-unit digits of well-known 3-decimal currencies.
  static const threeDecimal = {'JOD', 'LYD', 'KWD', 'BHD', 'OMR', 'TND', 'IQD'};

  /// Currencies without minor units.
  static const zeroDecimal = {'JPY', 'KRW', 'VND', 'CLP', 'ISK'};

  /// Decimals shown for [code]: [overrides] (user configuration) first, then
  /// JOD/LYD/KWD… = 3, JPY… = 0, everything else (USD, EGP, SYP, …) = 2.
  static int decimalsFor(String code, {Map<String, int>? overrides}) {
    final c = code.toUpperCase();
    final o = overrides?[c];
    if (o != null) return o.clamp(0, 3);
    if (threeDecimal.contains(c)) return 3;
    if (zeroDecimal.contains(c)) return 0;
    return 2;
  }

  static const _arabicSymbols = {
    'JOD': 'د.أ',
    'USD': r'$',
    'SYP': 'ل.س',
    'EGP': 'ج.م',
    'LYD': 'ل.د',
    'SAR': 'ر.س',
    'AED': 'د.إ',
    'KWD': 'د.ك',
    'QAR': 'ر.ق',
    'BHD': 'د.ب',
    'OMR': 'ر.ع',
    'IQD': 'د.ع',
    'LBP': 'ل.ل',
    'TND': 'د.ت',
    'MAD': 'د.م',
    'EUR': '€',
    'GBP': '£',
    'TRY': '₺',
  };

  static const _latinSymbols = {'USD': r'$', 'EUR': '€', 'GBP': '£', 'TRY': '₺'};

  /// Display symbol: Arabic abbreviations (`د.أ`) in Arabic, the ISO code (or
  /// `$ € £ ₺`) otherwise.
  static String symbolFor(String code, {bool arabic = false}) {
    final c = code.toUpperCase();
    if (arabic) return _arabicSymbols[c] ?? c;
    return _latinSymbols[c] ?? c;
  }

  /// Whether the Latin symbol is a single sign written before the number.
  static bool isPrefixSign(String code) => _latinSymbols.containsKey(code.toUpperCase());

  // Longest patterns first so "US$" wins over "$" and "E£" over "£".
  static final List<(RegExp, String)> _detectors = [
    for (final (pattern, code) in const [
      (r'US\$', 'USD'),
      (r'E£|LE\b|L\.E\.?', 'EGP'),
      (r'دولار', 'USD'),
      (r'دينار\s*ليبي|ل\.?\s?د\b|LD\b', 'LYD'),
      (r'دينار\s*كويتي|د\.?\s?ك\b', 'KWD'),
      (r'دينار(\s*أردني)?|د\.?\s?أ|JD\b', 'JOD'),
      (r'جنيه(\s*مصري)?|ج\.?\s?م', 'EGP'),
      (r'ليرة\s*تركية|₺', 'TRY'),
      (r'ليرة(\s*سورية)?|ل\.?\s?س|S\.?P\.?\b', 'SYP'),
      (r'ريال(\s*سعودي)?|ر\.?\s?س', 'SAR'),
      (r'درهم(\s*إماراتي)?|د\.?\s?إ', 'AED'),
      (r'يورو|€', 'EUR'),
      (r'£', 'GBP'),
      (r'\$', 'USD'),
    ])
      (RegExp(pattern, caseSensitive: false), code),
  ];

  static final RegExp _isoCode = RegExp(r'(?<![A-Za-z])([A-Za-z]{3})(?![A-Za-z])');

  /// Recognised ISO codes when they appear in free text.
  static const knownCodes = {
    'JOD', 'USD', 'SYP', 'EGP', 'LYD', 'SAR', 'AED', 'KWD', 'QAR', 'BHD', 'OMR', 'IQD', 'LBP', 'TND', 'MAD', //
    'EUR', 'GBP', 'TRY', 'CAD', 'AUD', 'CHF', 'JPY', 'CNY', 'INR', 'PKR', 'MYR', 'IDR',
  };

  /// Detects a currency written in [text] (`"200 JOD"`, `"$12"`, `"١٢ د.أ"`,
  /// `"5 دنانير"`), or null.
  static String? detect(String text) {
    for (final m in _isoCode.allMatches(text)) {
      final code = m.group(1)!.toUpperCase();
      if (knownCodes.contains(code)) return code;
    }
    if (RegExp('دنانير').hasMatch(text)) return 'JOD';
    for (final (re, code) in _detectors) {
      if (re.hasMatch(text)) return code;
    }
    return null;
  }

  /// Normalises a currency field value (`"jd"`, `"دينار"`, `"$"`, `"usd"`) to
  /// an ISO code, or null.
  static String? normalize(Object? value) {
    if (value is! String) return null;
    final t = value.trim();
    if (t.isEmpty) return null;
    if (RegExp(r'^[A-Za-z]{3}$').hasMatch(t)) return t.toUpperCase();
    return detect(t);
  }
}

// ---------------------------------------------------------------- MoneyText --

/// Text helpers shared by money parsing and the importer.
abstract final class MoneyText {
  static const int _arabicIndicZero = 0x0660;
  static const int _persianZero = 0x06F0;

  /// Folds Arabic-Indic / Persian digits to ASCII, `٫` to `.`, `٬` to `,`
  /// and the unicode minus / en dash to `-`.
  static String foldDigits(String input) {
    if (input.isEmpty) return input;
    final out = StringBuffer();
    for (final c in input.codeUnits) {
      if (c >= _arabicIndicZero && c <= _arabicIndicZero + 9) {
        out.writeCharCode(0x30 + c - _arabicIndicZero);
      } else if (c >= _persianZero && c <= _persianZero + 9) {
        out.writeCharCode(0x30 + c - _persianZero);
      } else {
        out.writeCharCode(switch (c) {
          0x066B => 0x2E, // ٫
          0x066C => 0x2C, // ٬
          0x2212 || 0x2013 => 0x2D, // − –
          _ => c,
        });
      }
    }
    return out.toString();
  }

  /// Converts ASCII digits in [s] to Arabic-Indic digits.
  static String toArabicIndic(String s) {
    final out = StringBuffer();
    for (final c in s.codeUnits) {
      out.writeCharCode(c >= 0x30 && c <= 0x39 ? _arabicIndicZero + c - 0x30 : c);
    }
    return out.toString();
  }

  static final RegExp _noise = RegExp('[\\s\u00A0\u202F\u200E\u200F\u061C\u2066-\u2069\u202A-\u202E\'\u2019_]');
  static final RegExp _numberRun = RegExp(r'[-+]?\(?\d[\d.,]*\)?|[-+]?\.\d+');

  /// Extracts the canonical ASCII decimal (`"-1234.5"`) from free text such
  /// as `"1,234.5"`, `"1٬234٫5"`, `"JOD 12.5"`, `"(12.50)"` or `"1.234,5"`.
  ///
  /// Separator rules: with both `.` and `,` the last one is the decimal mark;
  /// a lone `,` is a thousands separator when it groups exactly three digits
  /// (`"1,234"`), otherwise a decimal comma (`"12,5"`); several `.` are
  /// thousands separators (`"1.234.567"`). Returns null when [text] holds no
  /// number or more than one.
  static String? canonicalDecimal(String text) {
    var s = foldDigits(text).replaceAll(_noise, '');
    final negativeByParens = RegExp(r'^\(.*\)$').hasMatch(s.replaceAll(RegExp(r'[^\d.,()\-+]'), ''));
    final runs = _numberRun.allMatches(s).map((m) => m.group(0)!).toList();
    if (runs.length != 1) return null;
    s = runs.single.replaceAll(RegExp('[()]'), '');
    var negative = negativeByParens;
    if (s.startsWith('-')) {
      negative = true;
      s = s.substring(1);
    } else if (s.startsWith('+')) {
      s = s.substring(1);
    }
    s = s.replaceAll(RegExp(r'[.,]+$'), '');
    if (s.isEmpty) return null;
    final lastDot = s.lastIndexOf('.');
    final lastComma = s.lastIndexOf(',');
    if (lastDot >= 0 && lastComma >= 0) {
      final decimalMark = lastDot > lastComma ? '.' : ',';
      final group = decimalMark == '.' ? ',' : '.';
      final parts = s.split(decimalMark);
      if (parts.length != 2) return null;
      s = '${parts[0].replaceAll(group, '')}.${parts[1]}';
    } else if (lastComma >= 0) {
      if (RegExp(r'^\d{1,3}(,\d{3})+$').hasMatch(s)) {
        s = s.replaceAll(',', '');
      } else if (RegExp(r'^\d*,\d+$').hasMatch(s)) {
        s = s.replaceAll(',', '.');
      } else {
        return null;
      }
    } else if ('.'.allMatches(s).length > 1) {
      if (!RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(s)) return null;
      s = s.replaceAll('.', '');
    }
    if (!RegExp(r'^\d*\.?\d*$').hasMatch(s) || s == '.') return null;
    if (s.startsWith('.')) s = '0$s';
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    return negative ? '-$s' : s;
  }

  /// Parses a localised number (see [canonicalDecimal]) to a double.
  static double? parseNumber(String text) {
    final c = canonicalDecimal(text);
    return c == null ? null : double.tryParse(c);
  }

  /// Parses a localised decimal to exact milli-units, half-up.
  static int? parseMilli(String text) {
    final c = canonicalDecimal(text);
    if (c == null) return null;
    final r = Rational.tryParse(c);
    return r == null ? null : (r * Rational.thousand).roundHalfUp();
  }
}

// -------------------------------------------------------------------- Money --

/// Digit script used by [Money.format] (mirrors the app's `DigitStyle`).
enum MoneyDigits {
  /// Arabic-Indic in Arabic locales, Western otherwise.
  auto,
  western,
  arabicIndic,
}

/// An exact amount of one currency, in milli-units.
@immutable
class Money implements Comparable<Money> {
  const Money(this.milli, this.currency);

  const Money.zero(this.currency) : milli = 0;

  /// [units] of [currency] (`Money.fromUnits(12.5, 'JOD')` = 12 500 milli),
  /// exact for the decimal the number prints as, half-up to the milli.
  factory Money.fromUnits(num units, String currency) =>
      Money((Rational.fromNum(units) * Rational.thousand).roundHalfUp(), currency.toUpperCase());

  /// Amount × 1000 (e.g. 12.5 JOD = 12 500).
  final int milli;

  /// ISO-like currency code (`JOD`, `USD` …).
  final String currency;

  static const int milliPerUnit = 1000;

  /// Parses a number or text into money.
  ///
  /// * `num` → units (`12.5` → 12.500).
  /// * `String` → any digits / separators accepted by
  ///   [MoneyText.canonicalDecimal], optionally with a currency code, symbol
  ///   or Arabic name (`"200 JOD"`, `"$12.50"`, `"١٢٫٥ د.أ"`).
  ///
  /// The currency is, in order: the one written in the text, [currency],
  /// then [fallbackCurrency]. Returns null for anything else, including
  /// percentages (`"10%"`).
  static Money? tryParse(Object? input, {String? currency, String fallbackCurrency = 'JOD'}) {
    final code = (currency ?? fallbackCurrency).toUpperCase();
    if (input is Money) return input;
    if (input is num) {
      if (input.isNaN || input.isInfinite) return null;
      return Money.fromUnits(input, code);
    }
    if (input is! String) return null;
    final text = input.trim();
    if (text.isEmpty || text.contains('%') || text.contains('٪')) return null;
    final milli = MoneyText.parseMilli(text);
    if (milli == null) return null;
    return Money(milli, CurrencyCatalog.detect(text) ?? code);
  }

  /// Like [tryParse] but throws a [FormatException].
  static Money parse(Object? input, {String? currency, String fallbackCurrency = 'JOD'}) =>
      tryParse(input, currency: currency, fallbackCurrency: fallbackCurrency) ??
      (throw FormatException('Not an amount of money', '$input'));

  /// Sum of [items] (all in [currency]).
  static Money sum(Iterable<Money> items, String currency) =>
      items.fold(Money.zero(currency), (a, b) => a + b);

  bool get isZero => milli == 0;
  bool get isNegative => milli < 0;
  bool get isPositive => milli > 0;

  /// Approximate value in whole units – for charts only, never for math.
  double get units => milli / milliPerUnit;

  void _same(Money o) {
    if (o.currency != currency) {
      throw ArgumentError('Currency mismatch: $currency vs ${o.currency} (convert first)');
    }
  }

  Money operator +(Money o) {
    _same(o);
    return Money(milli + o.milli, currency);
  }

  Money operator -(Money o) {
    _same(o);
    return Money(milli - o.milli, currency);
  }

  Money operator -() => Money(-milli, currency);

  bool operator <(Money o) => compareTo(o) < 0;
  bool operator <=(Money o) => compareTo(o) <= 0;
  bool operator >(Money o) => compareTo(o) > 0;
  bool operator >=(Money o) => compareTo(o) >= 0;

  Money abs() => milli < 0 ? -this : this;

  /// × [factor], exact, half-up to the milli.
  Money multiply(num factor) => multiplyRatio(Rational.fromNum(factor));

  /// × [ratio], exact, half-up to the milli.
  Money multiplyRatio(Rational ratio) =>
      Money((Rational.fromInt(milli) * ratio).roundHalfUp(), currency);

  /// [pct] percent of this amount (`Money(200000).percent(50)` = 100.000),
  /// half-up to the milli.
  Money percent(num pct) => multiplyRatio(Rational.fromNum(pct) / Rational.hundred);

  /// Converts with manual rates to a common base: 1 unit of this currency =
  /// [fromRateToBase] base units, 1 unit of [to] = [toRateToBase] base units.
  ///
  /// `result = milli × fromRate / toRate`, computed exactly from the rates'
  /// printed decimals and rounded once, half-up, to the milli. Identity when
  /// the currencies match.
  Money convert(String to, {required num fromRateToBase, required num toRateToBase}) {
    final target = to.toUpperCase();
    if (target == currency) return this;
    if (fromRateToBase <= 0 || toRateToBase <= 0) {
      throw ArgumentError('Exchange rates must be positive');
    }
    final r = Rational.fromNum(fromRateToBase) / Rational.fromNum(toRateToBase);
    return Money((Rational.fromInt(milli) * r).roundHalfUp(), target);
  }

  /// Converts to the base currency ([rateToBase] = base units per unit).
  Money toBase(num rateToBase, String baseCurrency) =>
      convert(baseCurrency, fromRateToBase: rateToBase, toRateToBase: 1);

  /// Rounds to the currency's minor unit (e.g. 12.345 USD → 12.350 when
  /// shown with 2 decimals), half-up.
  Money roundToMinor({int? decimals}) {
    final d = decimals ?? CurrencyCatalog.decimalsFor(currency);
    if (d >= 3) return this;
    final step = BigInt.from(10).pow(3 - d).toInt();
    return Money(Rational.fromInt(milli, step).roundHalfUp() * step, currency);
  }

  /// The amount without symbol, e.g. `"1,234.500"` / `"١٬٢٣٤٫٥٠٠"`.
  String formatAmount({String locale = 'en', MoneyDigits digits = MoneyDigits.auto, int? decimals}) {
    final d = decimals ?? CurrencyCatalog.decimalsFor(currency);
    final rounded = roundToMinor(decimals: d);
    final arabic = locale.toLowerCase().startsWith('ar');
    final indic = digits == MoneyDigits.arabicIndic || (digits == MoneyDigits.auto && arabic);
    final intlLocale = arabic ? (indic ? 'ar_EG' : 'ar') : 'en';
    final f = NumberFormat.decimalPatternDigits(locale: intlLocale, decimalDigits: d);
    var out = f.format(rounded.milli / milliPerUnit);
    if (indic && !arabic) out = MoneyText.toArabicIndic(out);
    return out;
  }

  /// Formatted for display via intl: grouping, the currency's decimals
  /// ([decimals] or [CurrencyCatalog.decimalsFor]), digits per [digits] and
  /// the currency symbol (Arabic abbreviation after the number in Arabic,
  /// `$12.50` / `12.500 JOD` in English). [symbol] overrides the symbol.
  /// A no-break space (U+00A0) joins amount and symbol so they never wrap
  /// apart.
  String format({
    String locale = 'en',
    MoneyDigits digits = MoneyDigits.auto,
    int? decimals,
    bool withSymbol = true,
    String? symbol,
  }) {
    final amount = formatAmount(locale: locale, digits: digits, decimals: decimals);
    if (!withSymbol) return amount;
    final arabic = locale.toLowerCase().startsWith('ar');
    final sym = symbol ?? CurrencyCatalog.symbolFor(currency, arabic: arabic);
    if (!arabic && symbol == null && CurrencyCatalog.isPrefixSign(currency)) {
      return amount.startsWith('-') ? '-$sym${amount.substring(1)}' : '$sym$amount';
    }
    return '$amount\u00A0$sym';
  }

  Map<String, Object?> toJson() => {'milli': milli, 'currency': currency};

  static Money? fromJson(Object? json) {
    if (json is! Map) return null;
    final m = json['milli'];
    final c = json['currency'];
    if (m is! int || c is! String) return null;
    return Money(m, c);
  }

  @override
  int compareTo(Money o) {
    _same(o);
    return milli.compareTo(o.milli);
  }

  @override
  bool operator ==(Object other) => other is Money && other.milli == milli && other.currency == currency;

  @override
  int get hashCode => Object.hash(milli, currency);

  @override
  String toString() {
    final sign = milli < 0 ? '-' : '';
    final a = milli.abs();
    return '$sign${a ~/ 1000}.${(a % 1000).toString().padLeft(3, '0')} $currency';
  }
}
