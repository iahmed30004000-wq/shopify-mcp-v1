import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../domain/body_clock.dart';
import '../domain/fasting.dart';
import '../domain/training.dart';

/// Localised texts and number formats of the Body screens (digits follow
/// the app's digit setting; names are bidi-isolated where they sit inside
/// sentences).
class BodyTexts {
  BodyTexts(this.l, this.fmt);

  factory BodyTexts.of(BuildContext context) => BodyTexts(L10n.of(context), context.formatter);

  final L10n l;
  final MadarFormatter fmt;

  // A Monday used to name ISO weekdays.
  static final DateTime _monday = DateTime(2026, 9, 28);

  DateTime _isoDay(int iso) => _monday.add(Duration(days: iso - 1));

  /// One letter (Arabic "س") / short ("Sat").
  String weekdayShort(int iso) =>
      DateFormat(fmt.isArabic ? 'EEEEE' : 'E', fmt.languageCode).format(_isoDay(iso));

  /// "السبت" / "Saturday".
  String weekdayName(int iso) => DateFormat('EEEE', fmt.languageCode).format(_isoDay(iso));

  /// Days as a list sentence in display order: "السبت، الإثنين والأربعاء".
  String weekdayList(List<int> ordered) {
    final names = [for (final d in ordered) weekdayName(d)];
    if (names.isEmpty) return '';
    if (names.length == 1) return names.first;
    final and = fmt.isArabic ? ' و' : ' and ';
    final sep = fmt.isArabic ? '، ' : ', ';
    return '${names.sublist(0, names.length - 1).join(sep)}$and${names.last}';
  }

  /// Between parts of a summary: an Arabic comma in Arabic (a middle dot
  /// beside Arabic-Indic digits reads as a zero: "٨ · ٦٠" ≈ "٨٠ ٦٠").
  String get sep => fmt.isArabic ? '، ' : ' · ';

  /// A signed change: "+2.5 kg" / "؜+٢٫٥ كغ" (the Arabic letter mark keeps
  /// the sign at the reading start, as CLDR does).
  String signed(double change, String Function(double magnitude) format) {
    final sign = change > 0 ? '+' : (change < 0 ? '−' : '');
    final mark = fmt.isArabic && sign.isNotEmpty ? '\u061C' : '';
    return '$mark$sign${format(change.abs())}';
  }

  String kg(double v) => l.bodyKg(fmt.formatNumber(v, maxDecimals: 2));
  String minutes(int v) => l.bodyMinutes(fmt.formatInt(v));
  String ml(int v) => l.bodyMl(fmt.formatInt(v));
  String reps(int v) => l.bodyRepsValue(fmt.formatInt(v));
  String hours(double v) => l.bodyHours(fmt.formatNumber(v, maxDecimals: 1));

  /// Litres for large amounts in the water ring ("2.5 L"), ml otherwise.
  String volumeWater(int ml) => ml >= 1000 ? l.bodyLiters(fmt.formatNumber(ml / 1000, maxDecimals: 2)) : this.ml(ml);

  String setsReps(int? sets, int? reps) {
    if (reps == null) return sets == null ? '' : fmt.formatInt(sets);
    if (sets == null || sets <= 1) return this.reps(reps);
    return fmt.localizeDigits(l.bodySetsReps(fmt.formatInt(sets), fmt.formatInt(reps)));
  }

  /// "٣ × ١٢ · ٢٠ كغ · ١٥ د".
  String summary({int? sets, int? reps, double? weight, int? durationMin}) {
    final parts = [
      if (reps != null || sets != null) setsReps(sets, reps),
      if (weight != null && weight > 0) kg(weight),
      if (durationMin != null && durationMin > 0) minutes(durationMin),
    ].where((s) => s.isNotEmpty);
    return parts.join(sep);
  }

  String planSummary(PlannedExercise e) =>
      summary(sets: e.sets, reps: e.reps, weight: e.weight, durationMin: e.durationMin);

  String workoutSummary(WorkoutEntry w) =>
      summary(sets: w.sets, reps: w.reps, weight: w.weight, durationMin: w.durationMin);

  /// A running timer: `12:04:09` (hours not capped).
  String timer(Duration d) {
    final v = d.isNegative ? Duration.zero : d;
    final h = v.inHours, m = v.inMinutes.remainder(60), s = v.inSeconds.remainder(60);
    return fmt.localizeDigits('${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}');
  }

  /// "16 h 12 m" style words (rounded up to minutes).
  String duration(Duration d) => fmt.formatDurationWords(l, d);

  /// "16:8", or "20 h" for fasts without a daily eating window.
  String planRatio(FastingPlan p) => p.ratio != null ? fmt.localizeDigits(p.ratio!) : hours(p.targetHours);

  /// "Today" / weekday + date for other days.
  String day(DateTime d, DateTime today) {
    if (BodyDays.same(d, today)) return l.bodyTabToday;
    return fmt.formatDate(d, style: MadarDateStyle.weekdayDayMonth);
  }

  /// A time, with the weekday when it is not today.
  String timeOn(DateTime at, DateTime today) {
    final d = BodyDays.of(at);
    if (BodyDays.same(d, today)) return fmt.formatTime(at);
    final diff = BodyDays.between(today, d);
    if (diff.abs() < 7) return '${DateFormat('EEEE', fmt.languageCode).format(at)} ${fmt.formatTime(at)}';
    return '${fmt.formatDate(at, style: MadarDateStyle.dayMonth)} ${fmt.formatTime(at)}';
  }

  String metric(ProgressMetric m) => switch (m) {
    ProgressMetric.weight => l.bodyMetricWeight,
    ProgressMetric.volume => l.bodyMetricVolume,
    ProgressMetric.reps => l.bodyMetricReps,
    ProgressMetric.minutes => l.bodyMetricMinutes,
  };

  String metricValue(ProgressMetric m, double v) => switch (m) {
    ProgressMetric.weight => kg(v),
    ProgressMetric.volume => l.bodyKg(fmt.formatNumber(v, maxDecimals: 0)),
    ProgressMetric.reps => reps(v.round()),
    ProgressMetric.minutes => minutes(v.round()),
  };

  String phase(FastingPhase p) => switch (p) {
    FastingPhase.fasting => l.bodyFastPhaseFasting,
    FastingPhase.eating => l.bodyFastPhaseEating,
    FastingPhase.waiting => l.bodyFastPhaseWaiting,
  };
}
