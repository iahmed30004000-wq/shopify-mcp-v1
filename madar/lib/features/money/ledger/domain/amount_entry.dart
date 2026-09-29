/// Keypad amount entry (pure Dart): the typed text, limited to the
/// currency's decimals, read back as exact milli-units.
library;

import 'package:meta/meta.dart';

/// Keys of the amount keypad.
enum KeypadKey {
  d0,
  d1,
  d2,
  d3,
  d4,
  d5,
  d6,
  d7,
  d8,
  d9,
  decimal,
  backspace,
  clear;

  /// The digit (0–9) of a digit key, else null.
  int? get digit => index <= 9 ? index : null;

  static KeypadKey ofDigit(int d) => KeypadKey.values[d];
}

@immutable
class AmountEntry {
  const AmountEntry([this.text = '', this.decimals = 3]);

  /// The amount shown when editing [milli] (magnitude, trailing zeros of the
  /// fraction dropped: 12 500 → `12.5`).
  factory AmountEntry.fromMilli(int milli, {int decimals = 3}) {
    final a = milli.abs();
    if (a == 0) return AmountEntry('', decimals);
    final whole = a ~/ 1000;
    var frac = (a % 1000).toString().padLeft(3, '0').substring(0, decimals.clamp(0, 3));
    frac = frac.replaceFirst(RegExp(r'0+$'), '');
    return AmountEntry(frac.isEmpty ? '$whole' : '$whole.$frac', decimals);
  }

  /// ASCII digits with at most one `.`.
  final String text;

  /// Fraction digits allowed (0–3).
  final int decimals;

  /// Most integer digits accepted (keeps milli-units far inside `int`).
  static const int maxIntegerDigits = 12;

  bool get isEmpty => text.isEmpty;
  bool get hasDecimal => text.contains('.');

  /// Exact milli-units (0 when empty).
  int get milli {
    if (text.isEmpty || text == '.') return 0;
    final parts = text.split('.');
    final whole = int.tryParse(parts[0].isEmpty ? '0' : parts[0]) ?? 0;
    final frac = parts.length > 1 ? parts[1].padRight(3, '0').substring(0, 3) : '000';
    return whole * 1000 + int.parse(frac);
  }

  /// The entry after pressing [key]; unchanged when the key is not allowed
  /// (a second decimal point, too many decimals or digits).
  AmountEntry press(KeypadKey key) {
    switch (key) {
      case KeypadKey.clear:
        return AmountEntry('', decimals);
      case KeypadKey.backspace:
        return text.isEmpty ? this : AmountEntry(text.substring(0, text.length - 1), decimals);
      case KeypadKey.decimal:
        if (decimals == 0 || hasDecimal) return this;
        return AmountEntry(text.isEmpty ? '0.' : '$text.', decimals);
      default:
        final d = key.digit!;
        if (hasDecimal) {
          final fracLen = text.length - text.indexOf('.') - 1;
          if (fracLen >= decimals) return this;
          return AmountEntry('$text$d', decimals);
        }
        if (text == '0') return AmountEntry('$d', decimals);
        if (text.length >= maxIntegerDigits) return this;
        return AmountEntry('$text$d', decimals);
    }
  }

  /// Whether [key] would change the entry.
  bool accepts(KeypadKey key) => press(key) != this || key == KeypadKey.clear;

  /// The same text limited to [newDecimals] fraction digits.
  AmountEntry withDecimals(int newDecimals) {
    final d = newDecimals.clamp(0, 3);
    if (!hasDecimal) return AmountEntry(text, d);
    final i = text.indexOf('.');
    if (d == 0) return AmountEntry(text.substring(0, i), d);
    final frac = text.substring(i + 1);
    return AmountEntry(frac.length <= d ? text : text.substring(0, i + 1 + d), d);
  }

  @override
  bool operator ==(Object other) => other is AmountEntry && other.text == text && other.decimals == decimals;

  @override
  int get hashCode => Object.hash(text, decimals);

  @override
  String toString() => 'AmountEntry("$text", $decimals)';
}
