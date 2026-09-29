import 'package:intl/intl.dart';

import '../../../../core/db/database.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import 'lab_flags.dart';
import 'lab_series.dart';
import 'report_model.dart';

/// Localised labels and number / range / dose formatting shared by the
/// record's screens and the doctor report. With [isolate] (screens) user
/// text, numbers and units are bidi-isolated; the PDF (which has no bidi
/// controls in its font) uses `isolate: false`.
class RecordTexts {
  const RecordTexts(this.l, this.fmt, {this.isolate = true});

  final L10n l;
  final MadarFormatter fmt;
  final bool isolate;

  String iso(String s) => isolate ? BidiIsolate.isolate(s) : s;

  // ---------------------------------------------------------------- flags

  /// Full neutral label ("Near high limit").
  String flag(LabFlag f) => switch (f) {
    LabFlag.low => l.recordFlagLow,
    LabFlag.borderlineLow => l.recordFlagBorderlineLow,
    LabFlag.inRange => l.recordFlagInRange,
    LabFlag.borderlineHigh => l.recordFlagBorderlineHigh,
    LabFlag.high => l.recordFlagHigh,
    LabFlag.noRange => l.recordFlagNoRange,
    LabFlag.qualitative => l.recordFlagQualitative,
  };

  /// Short chip label ("Borderline").
  String flagShort(LabFlag f) => switch (f) {
    LabFlag.borderlineLow || LabFlag.borderlineHigh => l.recordFlagBorderline,
    _ => flag(f),
  };

  String severity(Severity s) => switch (s) {
    Severity.critical => l.recordSeverityCritical,
    Severity.warning => l.recordSeverityWarning,
    Severity.info => l.recordSeverityInfo,
  };

  // --------------------------------------------------------------- numbers

  String number(double v, {int decimals = 0}) => fmt.formatNumber(v, decimals: decimals, maxDecimals: decimals);

  /// "٥٫٤ mg/dL" (value and unit isolated on screens).
  String valueUnit(double v, String? unit, {int decimals = 0}) {
    final n = iso(number(v, decimals: decimals));
    final u = unit?.trim();
    return u == null || u.isEmpty ? n : '$n ${iso(u)}';
  }

  /// A reading as shown: its number (with [unit]) or its qualitative text.
  String reading(LabPoint p, {String? unit, int decimals = 0}) {
    final v = p.value;
    if (v != null) return valueUnit(v, unit, decimals: decimals);
    final t = p.text?.trim();
    return t == null || t.isEmpty ? '—' : iso(t);
  }

  /// "٣٫٥ – ٥٫٠", "up to 200", "40 or more" – null without a range.
  String? range(LabRange range, {String? unit, int decimals = 0}) {
    final (lo, hi) = range.ordered;
    String n(double v) => iso(number(v, decimals: decimals));
    final String core;
    if (lo != null && hi != null) {
      core = l.recordRangeBetween(n(lo), n(hi));
    } else if (hi != null) {
      core = l.recordRangeUpTo(n(hi));
    } else if (lo != null) {
      core = l.recordRangeAtLeast(n(lo));
    } else {
      return null;
    }
    final u = unit?.trim();
    return u == null || u.isEmpty ? core : '$core ${iso(u)}';
  }

  /// Just the value of a reading (number or qualitative text), no unit.
  String readingValue(LabPoint p, {int decimals = 0}) {
    final v = p.value;
    if (v != null) return iso(number(v, decimals: decimals));
    final t = p.text?.trim();
    return t == null || t.isEmpty ? '—' : iso(t);
  }

  DateFormat _date(DateFormat Function(String locale) build) {
    try {
      return build(fmt.languageCode);
    } catch (_) {
      return build('en');
    }
  }

  /// Compact axis dates: "Sep 2025" / "سبتمبر ٢٠٢٥".
  String monthYear(DateTime d) => fmt.localizeDigits(_date(DateFormat.yMMM).format(d));

  /// Compact axis dates: "Sep 14" / "١٤ سبتمبر".
  String dayMonthShort(DateTime d) => fmt.localizeDigits(_date(DateFormat.MMMd).format(d));

  /// "Tuesday, 6 October at 10:30 AM".
  String dateAtTime(DateTime at, {MadarDateStyle style = MadarDateStyle.weekdayDayMonth}) =>
      l.recordDateAtTime(fmt.formatDate(at, style: style), fmt.formatTime(at));

  /// Margin as a percentage ("٥٪").
  String margin(double fraction) => fmt.formatPercent(fraction);

  // ------------------------------------------------------------ medications

  String takenWith(TakenWith w) => switch (w) {
    TakenWith.emptyStomach => l.recordTakenWithEmptyStomach,
    TakenWith.breakfast => l.recordTakenWithBreakfast,
    TakenWith.lunch => l.recordTakenWithLunch,
    TakenWith.dinner => l.recordTakenWithDinner,
    TakenWith.bedtime => l.recordTakenWithBedtime,
    TakenWith.other => l.recordTakenWithOther,
    TakenWith.perCourse => l.recordTakenWithPerCourse,
    TakenWith.anytime => l.recordTakenWithAnytime,
  };

  String? dose(MedicationRow m) {
    final text = m.dose?.trim();
    if (text != null && text.isNotEmpty) return iso(text);
    final amount = m.doseAmount;
    if (amount == null) return null;
    return valueUnit(amount, m.doseUnit, decimals: LabDecimals.of(amount));
  }

  /// "٨:٠٠ ص، ٨:٠٠ م" from `HH:mm` strings (unparseable ones kept as typed).
  String times(List<String> hhmm) => hhmm
      .map((t) {
        final parts = t.split(':');
        final h = parts.isNotEmpty ? int.tryParse(parts[0]) : null;
        final m = parts.length > 1 ? int.tryParse(parts[1]) : 0;
        return h == null || m == null ? t : fmt.formatClock(h, m);
      })
      .join(l.recordListSeparator);

  // --------------------------------------------------------------- periods

  String labPeriod(LabPeriod p) => switch (p) {
    LabPeriod.months3 => l.recordPeriodMonths(3, fmt.formatInt(3)),
    LabPeriod.months6 => l.recordPeriodMonths(6, fmt.formatInt(6)),
    LabPeriod.months12 => l.recordPeriod12m,
    LabPeriod.all => l.recordPeriodAll,
  };

  String reportPeriod(ReportPeriod p) => switch (p) {
    ReportPeriod.months1 => l.recordPeriod1m,
    ReportPeriod.months3 => l.recordPeriodMonths(3, fmt.formatInt(3)),
    ReportPeriod.months6 => l.recordPeriodMonths(6, fmt.formatInt(6)),
    ReportPeriod.months12 => l.recordPeriod12m,
    ReportPeriod.all => l.recordPeriodAll,
  };

  String section(ReportSection s) => switch (s) {
    ReportSection.alerts => l.recordSectionAlerts,
    ReportSection.conditions => l.recordSectionConditions,
    ReportSection.medications => l.recordSectionMedications,
    ReportSection.labs => l.recordSectionLabs,
    ReportSection.pain => l.recordSectionPain,
    ReportSection.mood => l.recordSectionMood,
    ReportSection.questions => l.recordSectionQuestions,
  };

  /// "1 day before", "2 hours before", "30 minutes before".
  String reminderOffset(int minutes) {
    if (minutes % 10080 == 0) return l.recordOffsetWeeks(minutes ~/ 10080, fmt.formatInt(minutes ~/ 10080));
    if (minutes % 1440 == 0) return l.recordOffsetDays(minutes ~/ 1440, fmt.formatInt(minutes ~/ 1440));
    if (minutes % 60 == 0) return l.recordOffsetHours(minutes ~/ 60, fmt.formatInt(minutes ~/ 60));
    return l.recordOffsetMinutes(minutes, fmt.formatInt(minutes));
  }

  /// "Today", "Tomorrow", "In 3 days", "3 days ago".
  String relativeDay(int days) {
    if (days == 0) return l.recordToday;
    if (days == 1) return l.recordTomorrow;
    if (days == -1) return l.recordYesterday;
    if (days > 0) return l.recordInDays(days, fmt.formatInt(days));
    return l.recordDaysAgo(-days, fmt.formatInt(-days));
  }
}
