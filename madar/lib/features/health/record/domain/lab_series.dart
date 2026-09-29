import 'dart:math' as math;

import '../../../../core/db/database.dart';
import '../../../../core/interaction/numbers.dart';
import 'lab_flags.dart';

/// How far back a lab trend looks.
enum LabPeriod {
  months3(3),
  months6(6),
  months12(12),
  all(null);

  const LabPeriod(this.months);

  /// Null = every reading.
  final int? months;

  /// The first day inside the period ending [today] (null = no limit).
  DateTime? start(DateTime today) {
    final m = months;
    if (m == null) return null;
    return DateTime(today.year, today.month - m, today.day);
  }
}

/// One lab reading, classified.
class LabPoint {
  const LabPoint({required this.id, required this.date, required this.flag, this.value, this.text, this.note});

  factory LabPoint.of(LabReadingRow r, LabRange range, {double margin = LabFlags.defaultMargin}) => LabPoint(
    id: r.id,
    date: r.date,
    value: r.value,
    text: r.valueText,
    note: r.note,
    flag: r.value == null ? LabFlag.qualitative : LabFlags.classify(r.value, range, margin: margin),
  );

  final String id;

  /// Calendar day (local midnight).
  final DateTime date;
  final double? value;

  /// Qualitative result ("negative", "trace").
  final String? text;
  final String? note;
  final LabFlag flag;

  bool get isNumeric => value != null;

  @override
  String toString() => 'LabPoint($date ${value ?? text} ${flag.name})';
}

/// The latest reading and how it compares with the one before.
class LabSummary {
  const LabSummary({required this.latest, this.previous, this.count = 0});

  final LabPoint latest;
  final LabPoint? previous;
  final int count;

  /// latest − previous (numeric readings only).
  double? get change {
    final a = latest.value, b = previous?.value;
    return a == null || b == null ? null : a - b;
  }
}

abstract final class LabSeries {
  /// A test's range as a [LabRange].
  static LabRange rangeOf(LabTestRow test) => LabRange(low: test.low, high: test.high);

  /// Readings of one test as points, oldest first (same day: first entered
  /// first).
  static List<LabPoint> points(
    Iterable<LabReadingRow> readings,
    LabTestRow test, {
    double margin = LabFlags.defaultMargin,
  }) {
    final range = rangeOf(test);
    final sorted = readings.where((r) => r.testId == test.id).toList()
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        return byDate != 0 ? byDate : a.createdAt.compareTo(b.createdAt);
      });
    return [for (final r in sorted) LabPoint.of(r, range, margin: margin)];
  }

  /// The points inside [period] (ending [today]).
  static List<LabPoint> within(List<LabPoint> points, LabPeriod period, DateTime today) {
    final from = period.start(today);
    if (from == null) return points;
    return [
      for (final p in points)
        if (!p.date.isBefore(from)) p,
    ];
  }

  /// Latest + previous reading, or null without readings.
  static LabSummary? summary(List<LabPoint> points) {
    if (points.isEmpty) return null;
    return LabSummary(
      latest: points.last,
      previous: points.length > 1 ? points[points.length - 2] : null,
      count: points.length,
    );
  }

  /// Groups readings by test id (each list oldest first).
  static Map<String, List<LabReadingRow>> byTest(Iterable<LabReadingRow> readings) {
    final map = <String, List<LabReadingRow>>{};
    for (final r in readings) {
      (map[r.testId] ??= []).add(r);
    }
    for (final list in map.values) {
      list.sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        return byDate != 0 ? byDate : a.createdAt.compareTo(b.createdAt);
      });
    }
    return map;
  }
}

/// Decimal places worth showing for a test's numbers: the most any reading
/// or bound was typed with (0–3), so 5.4 stays "5.4" and 120 stays "120".
abstract final class LabDecimals {
  static int of(double value) {
    if (value.isNaN || value.isInfinite) return 0;
    for (var d = 0; d <= 3; d++) {
      final scaled = value * math.pow(10, d);
      if ((scaled - scaled.roundToDouble()).abs() < 1e-6 * math.max(1, scaled.abs())) return d;
    }
    return 3;
  }

  static int forValues(Iterable<double?> values) {
    var d = 0;
    for (final v in values) {
      if (v != null) d = math.max(d, of(v));
    }
    return d;
  }

  static int forTest(LabTestRow test, Iterable<LabPoint> points) =>
      forValues([test.low, test.high, for (final p in points) p.value]);
}

/// What the user typed as a lab result: a number, or a qualitative text.
class LabValueInput {
  const LabValueInput._(this.value, this.text);

  final double? value;
  final String? text;

  bool get isEmpty => value == null && text == null;

  /// Numbers in any digit script (`١٢٫٥`, `12,5`); anything else non-empty
  /// is kept as text.
  static LabValueInput parse(String? input) {
    final s = input?.trim() ?? '';
    if (s.isEmpty) return const LabValueInput._(null, null);
    final n = LocalizedNumbers.parse(s);
    if (n != null) return LabValueInput._(n.toDouble(), null);
    return LabValueInput._(null, s);
  }
}

/// Value-axis bounds with "nice" ticks that always include the reference
/// band, so the band is visible even when every reading sits inside it.
class LabChartScale {
  const LabChartScale({required this.minY, required this.maxY, required this.interval});

  final double minY;
  final double maxY;
  final double interval;

  List<double> get ticks {
    final out = <double>[];
    for (var v = minY; v <= maxY + interval * 1e-6; v += interval) {
      out.add(double.parse(v.toStringAsFixed(6)));
    }
    return out;
  }

  static LabChartScale of(Iterable<double> values, {LabRange range = const LabRange(), int targetTicks = 4}) {
    final all = [...values, ?range.low, ?range.high].where((v) => v.isFinite).toList();
    if (all.isEmpty) return const LabChartScale(minY: 0, maxY: 1, interval: 0.25);
    var lo = all.reduce(math.min);
    var hi = all.reduce(math.max);
    if (hi == lo) {
      final pad = lo == 0 ? 1.0 : lo.abs() * 0.1;
      lo -= pad;
      hi += pad;
    } else {
      final pad = (hi - lo) * 0.12;
      final allPositive = lo >= 0;
      lo -= pad;
      hi += pad;
      // Measurements that cannot be negative never get a negative axis.
      if (allPositive && lo < 0) lo = 0;
    }
    final interval = niceStep((hi - lo) / targetTicks);
    final minY = (lo / interval).floorToDouble() * interval;
    final maxY = (hi / interval).ceilToDouble() * interval;
    return LabChartScale(minY: minY, maxY: maxY == minY ? minY + interval : maxY, interval: interval);
  }

  /// 1, 2, 2.5 or 5 × 10ⁿ nearest above [raw].
  static double niceStep(double raw) {
    if (raw <= 0 || !raw.isFinite) return 1;
    final exp = (math.log(raw) / math.ln10).floor();
    final base = math.pow(10, exp).toDouble();
    final f = raw / base;
    final nice = f <= 1
        ? 1.0
        : f <= 2
        ? 2.0
        : f <= 2.5
        ? 2.5
        : f <= 5
        ? 5.0
        : 10.0;
    return nice * base;
  }
}

/// Maps days onto a chart's x axis in the reading direction.
///
/// **Madar's chart convention:** time runs in the reading direction. In
/// Arabic (right-to-left) the oldest day sits at the right (start) edge and
/// the newest at the left (end) edge, and the value axis sits on the start
/// (right) side; in English it is the usual left-to-right. `x` is measured
/// in days from the left edge, so charts stay plain left-to-right geometry.
class ChartTimeAxis {
  ChartTimeAxis({required DateTime start, required DateTime end, required this.rtl})
    : start = _day(start),
      end = _day(end).isAfter(_day(start)) ? _day(end) : _day(start).add(const Duration(days: 1));

  /// Covers [dates] (padded by [padFraction] of the span on both sides, at
  /// least a day), extended to [from] / [to] when given.
  factory ChartTimeAxis.covering(
    Iterable<DateTime> dates, {
    required bool rtl,
    DateTime? from,
    DateTime? to,
    double padFraction = 0.04,
  }) {
    final list = dates.map(_day).toList()..sort();
    var s = from ?? (list.isEmpty ? (to ?? DateTime.now()) : list.first);
    var e = to ?? (list.isEmpty ? s : list.last);
    if (list.isNotEmpty) {
      if (list.first.isBefore(s)) s = list.first;
      if (list.last.isAfter(e)) e = list.last;
    }
    final span = _days(_day(s), _day(e));
    final pad = math.max(1, (span * padFraction).round());
    return ChartTimeAxis(
      start: _day(s).subtract(Duration(days: pad)),
      end: _day(e).add(Duration(days: pad)),
      rtl: rtl,
    );
  }

  final DateTime start;
  final DateTime end;
  final bool rtl;

  /// Width in days.
  double get span => _days(start, end).toDouble();

  /// Horizontal position (0 = left edge, [span] = right edge).
  double x(DateTime day) {
    final raw = _days(start, _day(day)).toDouble();
    return rtl ? span - raw : raw;
  }

  /// The day at horizontal position [x].
  DateTime dateAt(double x) {
    final raw = rtl ? span - x : x;
    return DateTime(start.year, start.month, start.day + raw.round());
  }

  /// 0..1 fraction from the left edge (for sparklines).
  double fraction(DateTime day) => span == 0 ? 0.5 : x(day) / span;

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Whole calendar days between two local midnights (DST-safe).
  static int _days(DateTime a, DateTime b) =>
      DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
}
