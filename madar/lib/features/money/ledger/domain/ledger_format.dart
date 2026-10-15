/// Money text for the ledger: exact (built from integer milli-units, never
/// through a double), localised digits and separators, RTL-safe signs and
/// bidi-isolated currency symbols (pure Dart).
///
/// ### Bidi
/// * Arabic with Arabic-Indic digits writes the sign after an ARABIC LETTER
///   MARK (`\u061C-١٢٫٥٠٠`, the CLDR `ar-EG` form): in a right-to-left line the
///   sign is read first, on the right of the number.
/// * Arabic with Western digits writes it after a LEFT-TO-RIGHT MARK
///   (`\u200E-12.500`, the CLDR `ar` form): the number and its sign stay one
///   left-to-right run.
/// * The symbol follows after a no-break space inside a first-strong isolate
///   (FSI … PDI), so `د.أ`, `$` or a user code never reorders the amount
///   around it, whatever the surrounding direction.
library;

import 'package:meta/meta.dart';

import '../../../../core/domain/money.dart';
import '../../money_glyphs.dart';
import 'ledger_models.dart';

/// When a sign is written.
enum SignDisplay {
  /// `-` for negatives only.
  auto,

  /// `+` / `-` always (not for zero).
  always,

  /// Never (magnitude only).
  never,
}

@immutable
class LedgerMoneyFormat {
  const LedgerMoneyFormat({required this.arabic, required this.arabicIndic, this.currencies = const {}});

  /// Arabic UI (symbols in Arabic, RTL sign marks).
  final bool arabic;

  /// Arabic-Indic digits (`٠-٩`, `٫`, `٬`).
  final bool arabicIndic;

  /// The user's currencies by code (decimals and symbols).
  final Map<String, LedgerCurrency> currencies;

  static const String nbsp = '\u00A0';
  static const String fsi = '\u2068';
  static const String pdi = '\u2069';
  static const String lrm = '\u200E';
  static const String alm = '\u061C';

  LedgerMoneyFormat withCurrencies(Map<String, LedgerCurrency> currencies) =>
      LedgerMoneyFormat(arabic: arabic, arabicIndic: arabicIndic, currencies: currencies);

  /// Minor-unit digits of [code]: the user's setting, else the catalog's.
  int decimalsOf(String code) {
    final c = currencies[code.toUpperCase()];
    if (c != null) return c.decimals.clamp(0, 3);
    return CurrencyCatalog.decimalsFor(code);
  }

  /// The symbol shown for [code]: in Arabic the user's symbol (else the
  /// catalog's Arabic abbreviation, else the code); in English `$ € £ ₺` or
  /// the code.
  String symbolOf(String code) {
    final c = code.toUpperCase();
    if (arabic) {
      final own = currencies[c]?.symbol.trim() ?? '';
      if (own.isNotEmpty) return own;
      return CurrencyCatalog.symbolFor(c, arabic: true);
    }
    return CurrencyCatalog.symbolFor(c);
  }

  /// Wraps [text] in a first-strong isolate.
  static String isolate(String text) => text.isEmpty ? text : '$fsi$text$pdi';

  static const String lri = '\u2066';
  static const String rli = '\u2067';

  /// Wraps a formatted amount for use inside a sentence, isolated in the
  /// UI's own direction (RLI … PDI in Arabic, LRI … PDI otherwise).
  ///
  /// A first-strong isolate is wrong here: an Arabic amount has no strong
  /// letter outside its (isolated) symbol, so FSI would lay it out left to
  /// right and the symbol would be read before the number.
  String embed(String amount) => amount.isEmpty ? amount : '${arabic ? rli : lri}$amount$pdi';

  String _sign(bool negative) {
    final s = negative ? '-' : '+';
    if (!arabic) return s;
    return arabicIndic ? '$alm$s' : '$lrm$s';
  }

  /// Localises the ASCII digits and separators of [s] (digits and `.`/`,`
  /// only – [s] is built by this class).
  String _digits(String s) {
    if (!arabicIndic) return s;
    final out = StringBuffer();
    for (final c in s.codeUnits) {
      if (c >= 0x30 && c <= 0x39) {
        out.writeCharCode(0x0660 + c - 0x30);
      } else if (c == 0x2E) {
        out.write('٫');
      } else if (c == 0x2C) {
        // Not `٬`: see MoneyGlyphs (the font draws it like the decimal `٫`).
        out.write(MoneyGlyphs.arabicGroup);
      } else {
        out.writeCharCode(c);
      }
    }
    return out.toString();
  }

  static String _group(String digits) {
    if (digits.length <= 3) return digits;
    final out = StringBuffer();
    final head = digits.length % 3;
    if (head > 0) out.write(digits.substring(0, head));
    for (var i = head; i < digits.length; i += 3) {
      if (out.isNotEmpty) out.write(',');
      out.write(digits.substring(i, i + 3));
    }
    return out.toString();
  }

  /// The magnitude of [milli] with [decimals] fraction digits, grouped and
  /// localised, rounded half-up to the minor unit. No sign.
  String number(int milli, {int decimals = 3, bool grouping = true}) {
    final d = decimals.clamp(0, 3);
    final step = const [1000, 100, 10, 1][d];
    final abs = milli.abs();
    // Half-up on the magnitude (ties away from zero).
    final units = (abs + step ~/ 2) ~/ step; // in 10^-d units
    final scale = const [1, 10, 100, 1000][d];
    final whole = '${units ~/ scale}';
    final frac = d == 0 ? '' : '${units % scale}'.padLeft(d, '0');
    final head = grouping ? _group(whole) : whole;
    return _digits(d == 0 ? head : '$head.$frac');
  }

  /// [milli] of [code] (`١٢٫٥٠٠ د.أ`, `$12.50`, `-12.500 JOD`).
  ///
  /// [decimals] overrides the currency's; [symbol] = false drops the symbol;
  /// [trimZeros] drops an all-zero fraction (`12 JOD`).
  String amount(
    int milli,
    String code, {
    SignDisplay sign = SignDisplay.auto,
    bool symbol = true,
    int? decimals,
    bool trimZeros = false,
  }) {
    var d = decimals ?? decimalsOf(code);
    if (trimZeros && d > 0) {
      final step = const [1000, 100, 10, 1][d];
      final rounded = ((milli.abs() + step ~/ 2) ~/ step) * step;
      if (rounded % 1000 == 0) d = 0;
    }
    final body = number(milli, decimals: d);
    final isZero = body.replaceAll(RegExp('[^1-9١-٩]'), '').isEmpty;
    final negative = milli < 0 && !isZero;
    final signText = switch (sign) {
      SignDisplay.never => '',
      SignDisplay.auto => negative ? _sign(true) : '',
      SignDisplay.always => isZero ? '' : _sign(negative),
    };
    if (!symbol) return '$signText$body';
    final c = code.toUpperCase();
    final sym = symbolOf(c);
    if (!arabic && CurrencyCatalog.isPrefixSign(c)) return '$signText$sym$body';
    return '$signText$body$nbsp${isolate(sym)}';
  }

  /// [amount] of a [Money].
  String money(Money m, {SignDisplay sign = SignDisplay.auto, bool symbol = true}) =>
      amount(m.milli, m.currency, sign: sign, symbol: symbol);

  /// A short axis label (`350`, `1.2K`, `3.4M` / `١٫٢ ألف`-style numbers
  /// with the given suffixes), display only.
  String compact(int milli, {String thousand = 'K', String million = 'M'}) {
    final negative = milli < 0;
    final units = milli.abs() / 1000;
    String body;
    if (units >= 1e6) {
      body = '${_trim((units / 1e6).toStringAsFixed(units >= 1e7 ? 0 : 1))}$million';
    } else if (units >= 1e3) {
      body = '${_trim((units / 1e3).toStringAsFixed(units >= 1e4 ? 0 : 1))}$thousand';
    } else {
      body = _trim(units.toStringAsFixed(units >= 10 ? 0 : 1));
    }
    return '${negative ? _sign(true) : ''}${_digits(body)}';
  }

  static String _trim(String s) => s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;

  /// An exchange rate with up to [significant] significant digits
  /// (`0.709`, `1.410437`, `0.0000545`, `18,348.6`), localised.
  String rate(Rational r, {int significant = 6}) {
    final text = RateText.decimal(r, significant: significant);
    final negative = text.startsWith('-');
    final body = negative ? text.substring(1) : text;
    final dot = body.indexOf('.');
    final whole = dot < 0 ? body : body.substring(0, dot);
    final grouped = '${_group(whole)}${dot < 0 ? '' : body.substring(dot)}';
    return _digits(negative ? '-$grouped' : grouped);
  }
}

/// Exact decimal text of rationals (rates), rounded half-up to a number of
/// significant digits.
abstract final class RateText {
  /// [r] as a plain decimal with at most [significant] significant digits,
  /// trailing zeros removed (`1/3` → `0.333333`, `869/200` → `4.345`).
  static String decimal(Rational r, {int significant = 12}) {
    if (r.isZero) return '0';
    final negative = r.isNegative;
    final a = r.abs();
    // Find the exponent e with 10^e <= a < 10^(e+1).
    var e = a.numerator.toString().length - a.denominator.toString().length;
    Rational pow10(int n) => n >= 0 ? Rational(BigInt.from(10).pow(n)) : Rational(BigInt.one, BigInt.from(10).pow(-n));
    if (a < pow10(e)) e--;
    if (a >= pow10(e + 1)) e++;
    // Scale so the integer part has [significant] digits, round half-up.
    final shift = significant - 1 - e;
    final scaled = (a * pow10(shift)).roundHalfUpBig();
    final digits = scaled.toString();
    final point = digits.length - shift; // position of the decimal point
    String out;
    if (point <= 0) {
      out = '0.${'0' * -point}$digits';
    } else if (point >= digits.length) {
      out = digits + '0' * (point - digits.length);
    } else {
      out = '${digits.substring(0, point)}.${digits.substring(point)}';
    }
    if (out.contains('.')) out = out.replaceFirst(RegExp(r'\.?0+$'), '');
    return negative ? '-$out' : out;
  }
}

extension on Rational {
  /// Half-up rounding without the `int` range limit.
  BigInt roundHalfUpBig() {
    final twice = numerator.abs() * BigInt.two + denominator;
    final q = twice ~/ (denominator * BigInt.two);
    return isNegative ? -q : q;
  }
}
