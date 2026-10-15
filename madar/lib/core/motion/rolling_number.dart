import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'motion.dart';
import 'springs.dart';

/// One glyph of a formatted number: a digit (with its digit family) or a
/// static symbol (separator, sign, percent...).
@immutable
class NumberGlyph {
  const NumberGlyph.digit(this.digit, this.zero) : symbol = null;
  const NumberGlyph.symbol(String this.symbol) : digit = -1, zero = 0;

  /// 0..9, or -1 for a symbol.
  final int digit;

  /// Code unit of the family's zero ('0', '٠' or '۰').
  final int zero;
  final String? symbol;

  bool get isDigit => digit >= 0;

  /// The glyph of digit [d] in this family.
  String glyphOf(int d) => String.fromCharCode(zero + (d % 10));

  @override
  bool operator ==(Object other) =>
      other is NumberGlyph && other.digit == digit && other.zero == zero && other.symbol == symbol;

  @override
  int get hashCode => Object.hash(digit, zero, symbol);

  @override
  String toString() => isDigit ? glyphOf(digit) : symbol!;
}

/// Pure odometer maths for [RollingNumber] (unit-tested).
abstract final class RollingDigits {
  /// Digit families: Western, Arabic-Indic, Extended Arabic-Indic (Persian).
  static const zeros = <int>[0x30, 0x660, 0x6F0];

  /// Invisible bidi controls some formatters insert (LRM, RLM, ALM, isolates).
  static bool _isBidiControl(int c) =>
      c == 0x200E || c == 0x200F || c == 0x061C || (c >= 0x2066 && c <= 0x2069) || (c >= 0x202A && c <= 0x202E);

  /// Splits [text] into glyphs in logical order, dropping bidi controls.
  static List<NumberGlyph> parse(String text) {
    final out = <NumberGlyph>[];
    for (final rune in text.runes) {
      if (_isBidiControl(rune)) continue;
      var matched = false;
      for (final z in zeros) {
        if (rune >= z && rune <= z + 9) {
          out.add(NumberGlyph.digit(rune - z, z));
          matched = true;
          break;
        }
      }
      if (!matched) out.add(NumberGlyph.symbol(String.fromCharCode(rune)));
    }
    return out;
  }

  /// The strip position for [digit] nearest to [current] in the rolling
  /// direction: the smallest `p ≥ current` (rolling [up]) or the largest
  /// `p ≤ current` (rolling down) with `p mod 10 == digit`.
  static double nextPosition(double current, int digit, {required bool up}) {
    const eps = 1e-6;
    if (up) {
      final base = (current - eps).ceilToDouble();
      final delta = (digit - base) % 10;
      return base + delta;
    }
    final base = (current + eps).floorToDouble();
    final delta = (base - digit) % 10;
    return base - delta;
  }

  /// Digit shown at strip [position] and the one rolling in after it, plus
  /// the fraction rolled (0 = [current] fully shown).
  static (int current, int next, double fraction) split(double position) {
    final base = position.floorToDouble();
    return (base.toInt() % 10, (base.toInt() + 1) % 10, position - base);
  }
}

/// An animated number whose digits roll like an odometer: each digit column
/// springs independently to its new digit (up when the value grows, down when
/// it shrinks), retargeting mid-flight without jumps.
///
/// Digits are recognised in Western, Arabic-Indic (٠-٩) and Persian (۰-۹)
/// forms, so pass a [formatter] (e.g. a locale-aware `NumberFormat`) to get
/// Arabic-Indic digits. Other glyphs (separators, signs) stay static. Units
/// belong outside the widget. The row is laid out left-to-right, as numbers
/// are in both scripts.
///
/// Reduced motion: the value simply changes.
class RollingNumber extends StatefulWidget {
  const RollingNumber({
    super.key,
    required this.value,
    this.from,
    this.formatter,
    this.fractionDigits = 0,
    this.style,
    this.spring,
    this.semanticsLabel,
  });

  final num value;

  /// Roll from this value on first build (e.g. 0 for a stat reveal).
  final num? from;

  /// Formats the value; defaults to `toStringAsFixed(fractionDigits)`.
  final String Function(num value)? formatter;
  final int fractionDigits;
  final TextStyle? style;

  /// Defaults to [MadarSprings.roll].
  final SpringDescription? spring;

  /// Defaults to the formatted value.
  final String? semanticsLabel;

  @override
  State<RollingNumber> createState() => _RollingNumberState();
}

class _Column {
  _Column.digit(NumberGlyph g, double position, SpringDescription spring, {double presence = 1})
    : zero = g.zero,
      symbol = null,
      position = SpringMotion(spring: spring, value: position, tolerance: _tol),
      presence = SpringMotion(spring: spring, value: presence, tolerance: _tol);

  _Column.symbol(String this.symbol, SpringDescription spring, {double presence = 1})
    : zero = 0x30,
      position = SpringMotion(spring: spring, value: 0, tolerance: _tol),
      presence = SpringMotion(spring: spring, value: presence, tolerance: _tol);

  static const _tol = Tolerance(distance: 1e-3, velocity: 1e-2);

  int zero;
  String? symbol;
  final SpringMotion position;
  final SpringMotion presence;

  bool get isDigit => symbol == null;
  bool get atRest => position.isAtRest && presence.isAtRest;
}

class _RollingNumberState extends State<RollingNumber> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  double _clock = 0;
  double _tickBase = 0;

  /// Columns from the END of the string (index 0 = last glyph).
  final List<_Column> _cols = [];
  late num _shown;
  String _text = '';
  bool _initialised = false;

  SpringDescription get _spring => widget.spring ?? MadarSprings.roll;

  String _format(num v) => widget.formatter?.call(v) ?? v.toStringAsFixed(widget.fractionDigits);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    _initialised = true;
    final from = widget.from;
    if (from != null && from != widget.value && !context.reducedMotion) {
      _shown = from;
      _layout(_format(from), up: true, animate: false);
      _retargetTo(widget.value);
    } else {
      _shown = widget.value;
      _layout(_format(widget.value), up: true, animate: false);
    }
  }

  @override
  void didUpdateWidget(RollingNumber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value ||
        widget.fractionDigits != oldWidget.fractionDigits ||
        widget.formatter != oldWidget.formatter) {
      _retargetTo(widget.value);
    }
  }

  void _retargetTo(num value) {
    final up = value >= _shown;
    _shown = value;
    final animate = !context.reducedMotion;
    _layout(_format(value), up: up, animate: animate);
    if (animate && _cols.any((c) => !c.atRest)) {
      if (!_ticker.isActive) {
        _tickBase = _clock;
        _ticker.start();
      }
    } else {
      _ticker.stop();
    }
  }

  void _layout(String text, {required bool up, required bool animate}) {
    _text = text;
    final glyphs = RollingDigits.parse(text);
    final n = glyphs.length;
    final spring = _spring;
    for (var k = 0; k < n; k++) {
      final g = glyphs[n - 1 - k];
      if (k < _cols.length) {
        final col = _cols[k];
        if (g.isDigit) {
          if (!col.isDigit) {
            col
              ..symbol = null
              ..zero = g.zero;
            col.position.jumpTo(g.digit.toDouble());
          } else {
            col.zero = g.zero;
            col.position.spring = spring;
            final target = RollingDigits.nextPosition(col.position.value, g.digit, up: up);
            if (animate) {
              col.position.retarget(target, time: _clock);
            } else {
              col.position.jumpTo(target);
            }
          }
        } else {
          col.symbol = g.symbol;
        }
        if (col.presence.target != 1) {
          animate ? col.presence.retarget(1, time: _clock) : col.presence.jumpTo(1);
        }
      } else {
        // A new leading column rolls/fades in.
        final _Column col;
        if (g.isDigit) {
          col = _Column.digit(g, animate && up ? 0 : g.digit.toDouble(), spring, presence: animate ? 0 : 1);
          if (animate) col.position.retarget(g.digit.toDouble(), time: _clock);
        } else {
          col = _Column.symbol(g.symbol!, spring, presence: animate ? 0 : 1);
        }
        if (animate) col.presence.retarget(1, time: _clock);
        _cols.add(col);
      }
    }
    if (_cols.length > n) _cols.removeRange(n, _cols.length);
  }

  void _onTick(Duration elapsed) {
    _clock = _tickBase + elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    var rest = true;
    for (final c in _cols) {
      c.position.advanceTo(_clock);
      c.presence.advanceTo(_clock);
      rest &= c.atRest;
    }
    if (rest) _ticker.stop();
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style.merge(widget.style);
    final style = base.copyWith(fontFeatures: [...?base.fontFeatures, const FontFeature.tabularFigures()]);
    final children = <Widget>[for (var k = _cols.length - 1; k >= 0; k--) _ColumnView(column: _cols[k], style: style)];
    return Semantics(
      label: widget.semanticsLabel ?? _text,
      excludeSemantics: true,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: children,
        ),
      ),
    );
  }
}

class _ColumnView extends StatelessWidget {
  const _ColumnView({required this.column, required this.style});

  final _Column column;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final presence = column.presence.value.clamp(0.0, 1.0);
    final color = style.color;
    Widget glyph(String text, double alpha) => Text(
      text,
      textAlign: TextAlign.center,
      maxLines: 1,
      softWrap: false,
      style: color == null ? style : style.copyWith(color: color.withValues(alpha: color.a * alpha)),
    );

    Widget body;
    if (!column.isDigit) {
      body = glyph(column.symbol!, presence);
    } else {
      final (a, b, frac) = RollingDigits.split(column.position.value);
      final zero = column.zero;
      String g(int d) => String.fromCharCode(zero + d);
      body = ClipRect(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Sizes the column to the widest digit of the family.
            Visibility(
              visible: false,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: glyph(g(8), 1),
            ),
            if (frac < 0.999)
              Positioned.fill(
                child: FractionalTranslation(translation: Offset(0, -frac), child: glyph(g(a), presence * (1 - frac))),
              ),
            if (frac > 0.001)
              Positioned.fill(
                child: FractionalTranslation(translation: Offset(0, 1 - frac), child: glyph(g(b), presence * frac)),
              ),
          ],
        ),
      );
    }
    if (presence >= 1) return body;
    return ClipRect(
      child: Align(alignment: Alignment.centerRight, widthFactor: presence, child: body),
    );
  }
}
