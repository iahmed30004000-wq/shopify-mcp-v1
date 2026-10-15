import 'package:meta/meta.dart';

/// Quick choices for the CSV date filter.
enum ExportRangePreset { days30, days90, year, all, custom }

/// An inclusive range of calendar days (either end open).
@immutable
class ExportDateRange {
  const ExportDateRange({this.from, this.to});

  /// Everything.
  static const ExportDateRange all = ExportDateRange();

  /// The last [days] calendar days up to and including [today].
  factory ExportDateRange.lastDays(int days, DateTime today) {
    final t = dayOf(today);
    return ExportDateRange(from: DateTime(t.year, t.month, t.day - (days - 1)), to: t);
  }

  factory ExportDateRange.forPreset(ExportRangePreset preset, DateTime today, {ExportDateRange? custom}) =>
      switch (preset) {
        ExportRangePreset.days30 => ExportDateRange.lastDays(30, today),
        ExportRangePreset.days90 => ExportDateRange.lastDays(90, today),
        ExportRangePreset.year => ExportDateRange.lastDays(365, today),
        ExportRangePreset.all => all,
        ExportRangePreset.custom => custom ?? all,
      };

  /// First day (local midnight), or null for "from the beginning".
  final DateTime? from;

  /// Last day (local midnight, inclusive), or null for "until today".
  final DateTime? to;

  bool get isAll => from == null && to == null;

  /// Local midnight of [t]'s calendar day.
  static DateTime dayOf(DateTime t) {
    final l = t.isUtc ? t.toLocal() : t;
    return DateTime(l.year, l.month, l.day);
  }

  /// Whether [t]'s calendar day lies in the range.
  bool contains(DateTime t) {
    final d = dayOf(t);
    final f = from, e = to;
    if (f != null && d.isBefore(dayOf(f))) return false;
    if (e != null && d.isAfter(dayOf(e))) return false;
    return true;
  }

  /// `2026-09-01_2026-09-30` (or `all`), for file names.
  String get fileTag {
    if (isAll) return 'all';
    String d(DateTime? t) => t == null ? '…' : isoDay(t);
    return '${d(from)}_${d(to)}';
  }

  @override
  bool operator ==(Object other) => other is ExportDateRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

/// `yyyy-MM-dd` of [t]'s local calendar day.
String isoDay(DateTime t) {
  final d = ExportDateRange.dayOf(t);
  return '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';
}

/// `HH:mm` of [t] in local time.
String isoTime(DateTime t) {
  final l = t.isUtc ? t.toLocal() : t;
  return '${_two(l.hour)}:${_two(l.minute)}';
}

String _two(int n) => n.toString().padLeft(2, '0');
