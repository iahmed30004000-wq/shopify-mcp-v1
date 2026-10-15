/// Machine-friendly number text for exports: Western digits, `.` decimal
/// point, no grouping, `-` sign – the same in every app language, so files
/// open correctly in spreadsheets and read unambiguously for an assistant.
library;

abstract final class PlainNumbers {
  /// [value] with at most [maxDecimals] decimals, trailing zeros removed
  /// (`5`, `6.25`, `-0.5`). Non-finite values give an empty string.
  static String decimal(num value, {int maxDecimals = 4}) {
    if (value is int) return '$value';
    final v = value.toDouble();
    if (!v.isFinite) return '';
    var s = v.toStringAsFixed(maxDecimals);
    if (s.contains('.')) {
      s = s.replaceFirst(RegExp(r'0+$'), '');
      if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    }
    if (s == '-0') s = '0';
    return s;
  }

  /// A money amount stored in milli-units, with exactly [decimals] decimals
  /// (rounded half away from zero): `-12.500`, `3.50`, `120`.
  static String milli(int milli, {int decimals = 3}) {
    final d = decimals.clamp(0, 3);
    final negative = milli < 0;
    var abs = milli.abs();
    final step = const [1000, 100, 10, 1][d];
    abs = (abs + step ~/ 2) ~/ step; // units of 10^-d
    final scale = const [1, 10, 100, 1000][d];
    final whole = abs ~/ scale;
    final frac = abs % scale;
    final sign = negative && abs != 0 ? '-' : '';
    return d == 0 ? '$sign$whole' : '$sign$whole.${frac.toString().padLeft(d, '0')}';
  }

  /// Percentage of [part] in [whole] rounded to an integer (`64`), or null
  /// when [whole] is zero.
  static int? percent(num part, num whole) => whole == 0 ? null : (part * 100 / whole).round();
}
