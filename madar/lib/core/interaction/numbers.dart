/// Number input normalisation shared by every numeric field and the quick-add
/// parser. Pure Dart – unit-tested.
///
/// Users type Western (0-9), Arabic-Indic (٠-٩) or Extended Arabic-Indic /
/// Persian (۰-۹) digits, the Arabic decimal separator (٫), the Arabic
/// thousands separator (٬) and sometimes a comma as decimal mark. Everything
/// is folded to a canonical Western form before parsing.
library;

abstract final class LocalizedNumbers {
  static const int _arabicIndicZero = 0x0660;
  static const int _persianZero = 0x06F0;

  /// Replaces Arabic-Indic / Persian digits with ASCII digits, `٫` with `.`,
  /// `٬` with `,` and the unicode minus sign with `-`. Every other character is
  /// kept, and the result has exactly the same length as [input] (callers rely
  /// on indexes staying aligned).
  static String normalizeDigits(String input) {
    if (input.isEmpty) return input;
    final out = StringBuffer();
    for (final unit in input.codeUnits) {
      out.writeCharCode(_foldUnit(unit));
    }
    return out.toString();
  }

  static int _foldUnit(int c) {
    if (c >= _arabicIndicZero && c <= _arabicIndicZero + 9) return 0x30 + c - _arabicIndicZero;
    if (c >= _persianZero && c <= _persianZero + 9) return 0x30 + c - _persianZero;
    return switch (c) {
      0x066B => 0x2E, // ٫ Arabic decimal separator
      0x066C => 0x2C, // ٬ Arabic thousands separator
      0x2212 => 0x2D, // − minus sign
      0x2013 => 0x2D, // – en dash typed as minus
      _ => c,
    };
  }

  /// Whether [c] is a digit in any supported script.
  static bool isDigitUnit(int c) =>
      (c >= 0x30 && c <= 0x39) ||
      (c >= _arabicIndicZero && c <= _arabicIndicZero + 9) ||
      (c >= _persianZero && c <= _persianZero + 9);

  static final RegExp _thousandsComma = RegExp(r'^[+-]?\d{1,3}(,\d{3})+(\.\d+)?$');
  static final RegExp _canonical = RegExp(r'^[+-]?(\d+\.?\d*|\.\d+)$');

  /// Canonical ASCII form of a typed number (`"١٢٫٥"` → `"12.5"`,
  /// `"1,250"` → `"1250"`, `"12,5"` → `"12.5"`), or null if [input] is not a
  /// number. Surrounding and inner whitespace is ignored.
  static String? canonical(String input) {
    var s = normalizeDigits(input).replaceAll(RegExp(r'[\s\u00A0\u202F\u200F\u200E\u061C]', unicode: true), '');
    if (s.isEmpty) return null;
    if (s.contains(',')) {
      if (s.contains('.') || _thousandsComma.hasMatch(s)) {
        // Comma is a thousands separator.
        if (!RegExp(r'^[+-]?\d{1,3}(,\d{3})*(\.\d+)?$').hasMatch(s)) return null;
        s = s.replaceAll(',', '');
      } else if (RegExp(r'^[+-]?\d+,\d+$').hasMatch(s)) {
        // Single comma between digits: decimal comma ("12,5").
        s = s.replaceAll(',', '.');
      } else {
        return null;
      }
    }
    if (s.startsWith('+')) s = s.substring(1);
    if (!_canonical.hasMatch(s)) return null;
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    if (s.startsWith('.')) s = '0$s';
    if (s.startsWith('-.')) s = '-0${s.substring(1)}';
    return s;
  }

  /// Parses a typed number in any supported script, or null.
  static num? parse(String input) {
    final c = canonical(input);
    if (c == null) return null;
    return c.contains('.') ? double.tryParse(c) : int.tryParse(c) ?? double.tryParse(c);
  }

  /// Number of digits after the decimal point in the canonical form of
  /// [input] (0 for integers or unparseable input).
  static int decimalPlaces(String input) {
    final c = canonical(input);
    if (c == null) return 0;
    final dot = c.indexOf('.');
    return dot < 0 ? 0 : c.length - dot - 1;
  }

  /// `amount × 1000` rounded to an int (money and quantities are stored as
  /// milli-units).
  static int toMilli(num amount) => (amount * 1000).round();

  /// Formats milli-units back to a short decimal string without trailing
  /// zeros: 12500 → "12.5", 3000 → "3", 1250 → "1.25".
  static String formatMilli(int milli, {int maxDecimals = 3}) {
    final negative = milli < 0;
    final abs = milli.abs();
    final whole = abs ~/ 1000;
    var frac = (abs % 1000).toString().padLeft(3, '0');
    if (maxDecimals < 3) {
      final rounded = (abs / 1000).toStringAsFixed(maxDecimals);
      final parts = rounded.split('.');
      final w = parts[0];
      final f = parts.length > 1 ? parts[1].replaceAll(RegExp(r'0+$'), '') : '';
      final body = f.isEmpty ? w : '$w.$f';
      return negative && body != '0' ? '-$body' : body;
    }
    frac = frac.replaceAll(RegExp(r'0+$'), '');
    final body = frac.isEmpty ? '$whole' : '$whole.$frac';
    return negative ? '-$body' : body;
  }

  /// Formats a number for an input field: integers without a decimal point,
  /// decimals without trailing zeros.
  static String formatNum(num value) {
    if (value is int) return '$value';
    if (value == value.roundToDouble() && value.abs() < 1e15) return '${value.toInt()}';
    var s = value.toString();
    if (s.contains('e')) s = value.toStringAsFixed(6);
    if (s.contains('.')) s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    return s;
  }

  /// Converts ASCII digits to Arabic-Indic for display (`"12.5"` → `"١٢٫٥"`).
  static String toArabicIndic(String input) {
    final out = StringBuffer();
    for (final c in input.codeUnits) {
      if (c >= 0x30 && c <= 0x39) {
        out.writeCharCode(_arabicIndicZero + c - 0x30);
      } else if (c == 0x2E) {
        out.writeCharCode(0x066B);
      } else {
        out.writeCharCode(c);
      }
    }
    return out.toString();
  }
}
