import 'package:flutter/foundation.dart';

import '../../../../core/db/database.dart';
import '../../../../core/domain/enums.dart';
import 'lab_flags.dart';

/// Sections the user can include in the doctor report (in print order).
enum ReportSection { alerts, conditions, medications, labs, pain, mood, questions }

/// The report's look-back period.
enum ReportPeriod {
  months1(1),
  months3(3),
  months6(6),
  months12(12),
  all(null);

  const ReportPeriod(this.months);

  final int? months;

  /// First day inside the period ending [today] (null = whole record).
  DateTime? start(DateTime today) {
    final m = months;
    if (m == null) return null;
    return DateTime(today.year, today.month - m, today.day);
  }
}

/// What the user asked for in the report dialog.
@immutable
class DoctorReportRequest {
  const DoctorReportRequest({
    required this.sections,
    required this.period,
    required this.now,
    this.patientName,
    this.languageCode = 'ar',
  });

  final Set<ReportSection> sections;
  final ReportPeriod period;
  final DateTime now;

  /// Typed in the dialog; printed only (stored only if the user asks).
  final String? patientName;
  final String languageCode;

  DateTime get today => DateTime(now.year, now.month, now.day);
  DateTime? get from => period.start(today);

  bool includes(ReportSection s) => sections.contains(s);
}

/// Everything the report reads, straight from the tables.
@immutable
class DoctorReportData {
  const DoctorReportData({
    this.alerts = const [],
    this.conditions = const [],
    this.medications = const [],
    this.tests = const [],
    this.readings = const [],
    this.pains = const [],
    this.moods = const [],
    this.questions = const [],
    this.appointments = const [],
    this.tagLabels = const {},
    this.margin = LabFlags.defaultMargin,
  });

  /// Pinned standing alerts.
  final List<HealthAlertRow> alerts;

  /// Active conditions.
  final List<ConditionRow> conditions;

  /// Active medications and supplements.
  final List<MedicationRow> medications;
  final List<LabTestRow> tests;

  /// Every reading of [tests] (the composer applies the period).
  final List<LabReadingRow> readings;

  /// Pain / mood entries inside the period.
  final List<PainEntryRow> pains;
  final List<MoodEntryRow> moods;

  /// Open (unanswered) questions.
  final List<DoctorQuestionRow> questions;

  /// For "question for an appointment" lines.
  final List<AppointmentRow> appointments;

  /// Tag option id → label (pain locations / triggers and mood factors may
  /// be stored as either).
  final Map<String, String> tagLabels;
  final double margin;
}

// ------------------------------------------------------------ document ----

/// A composed, fully localised report – what the PDF renderer lays out (and
/// what tests read).
@immutable
class ReportDocument {
  const ReportDocument({
    required this.languageCode,
    required this.title,
    required this.periodLine,
    required this.generatedLine,
    required this.nameLabel,
    required this.footer,
    required this.pageLabel,
    required this.blocks,
    this.patientName,
    this.metaTitle = '',
  });

  final String languageCode;
  final String title;
  final String periodLine;
  final String generatedLine;
  final String nameLabel;
  final String? patientName;
  final String footer;

  /// "Page 1 of 3".
  final String Function(int page, int total) pageLabel;
  final List<ReportBlock> blocks;

  /// Document title in the PDF metadata.
  final String metaTitle;

  bool get rtl => languageCode == 'ar';

  /// Every visible string (tests search it).
  List<String> get texts => [
    title,
    periodLine,
    generatedLine,
    nameLabel,
    ?patientName,
    footer,
    for (final b in blocks) ...b.texts,
  ];
}

sealed class ReportBlock {
  const ReportBlock({required this.section, required this.title, this.emptyText});

  final ReportSection section;
  final String title;

  /// Shown instead of content when the section has nothing.
  final String? emptyText;

  bool get isEmpty;

  List<String> get texts;
}

class ReportAlert {
  const ReportAlert({required this.text, required this.severity, required this.severityLabel});

  final String text;
  final Severity severity;
  final String severityLabel;
}

final class ReportAlertsBlock extends ReportBlock {
  const ReportAlertsBlock({required super.title, required this.alerts, super.emptyText})
    : super(section: ReportSection.alerts);

  final List<ReportAlert> alerts;

  @override
  bool get isEmpty => alerts.isEmpty;

  @override
  List<String> get texts => [
    title,
    ?emptyText,
    for (final a in alerts) ...[a.severityLabel, a.text],
  ];
}

class ReportItem {
  const ReportItem({required this.title, this.detail, this.meta});

  final String title;
  final String? detail;

  /// Small line on the end side (a date).
  final String? meta;
}

/// A list of items (conditions, questions).
final class ReportItemsBlock extends ReportBlock {
  const ReportItemsBlock({required super.section, required super.title, required this.items, super.emptyText});

  final List<ReportItem> items;

  @override
  bool get isEmpty => items.isEmpty;

  @override
  List<String> get texts => [
    title,
    ?emptyText,
    for (final i in items) ...[i.title, ?i.detail, ?i.meta],
  ];
}

class ReportColumn {
  const ReportColumn(this.header, {this.flex = 1});

  final String header;
  final int flex;
}

/// A plain table (medications).
final class ReportTableBlock extends ReportBlock {
  const ReportTableBlock({
    required super.section,
    required super.title,
    required this.columns,
    required this.rows,
    super.emptyText,
  });

  final List<ReportColumn> columns;
  final List<List<String>> rows;

  @override
  bool get isEmpty => rows.isEmpty;

  @override
  List<String> get texts => [title, ?emptyText, for (final c in columns) c.header, for (final r in rows) ...r];
}

/// A tiny trend line: x is 0..1 across the period in reading direction.
class ReportSpark {
  const ReportSpark({required this.points, required this.minY, required this.maxY, this.low, this.high});

  final List<({double x, double y, LabFlag flag})> points;
  final double minY;
  final double maxY;
  final double? low;
  final double? high;
}

class ReportLabRow {
  const ReportLabRow({
    required this.name,
    required this.latest,
    required this.latestDate,
    required this.flag,
    required this.flagLabel,
    this.unit,
    this.range,
    this.history = const [],
    this.spark,
  });

  final String name;
  final String? unit;

  /// Formatted reference range ("٣٫٥ – ٥٫٠").
  final String? range;

  /// Latest value (or qualitative text).
  final String latest;
  final String latestDate;
  final LabFlag flag;
  final String flagLabel;

  /// Earlier readings in the period, newest first ("٢ أغسطس: ٥٫٦").
  final List<({String date, String value, LabFlag flag})> history;
  final ReportSpark? spark;
}

class ReportLabGroup {
  const ReportLabGroup({required this.rows, this.category});

  final String? category;
  final List<ReportLabRow> rows;
}

final class ReportLabsBlock extends ReportBlock {
  const ReportLabsBlock({
    required super.title,
    required this.groups,
    required this.columns,
    required this.legend,
    super.emptyText,
  }) : super(section: ReportSection.labs);

  final List<ReportLabGroup> groups;

  /// Test, latest, range, trend, earlier readings.
  final List<String> columns;
  final String legend;

  @override
  bool get isEmpty => groups.every((g) => g.rows.isEmpty);

  @override
  List<String> get texts => [
    title,
    ?emptyText,
    legend,
    ...columns,
    for (final g in groups) ...[
      ?g.category,
      for (final r in g.rows) ...[
        r.name,
        ?r.unit,
        ?r.range,
        r.latest,
        r.latestDate,
        r.flagLabel,
        for (final h in r.history) ...[h.date, h.value],
      ],
    ],
  ];
}

class ReportStat {
  const ReportStat(this.label, this.value);

  final String label;
  final String value;
}

/// A "most frequent" line: tags with how often they were recorded.
class ReportTagLine {
  const ReportTagLine(this.label, this.tags);

  final String label;
  final List<({String label, String count})> tags;
}

/// Neutral statistics (pain, mood).
final class ReportStatsBlock extends ReportBlock {
  const ReportStatsBlock({
    required super.section,
    required super.title,
    required this.stats,
    this.tagLines = const [],
    super.emptyText,
  });

  final List<ReportStat> stats;
  final List<ReportTagLine> tagLines;

  @override
  bool get isEmpty => stats.isEmpty;

  @override
  List<String> get texts => [
    title,
    ?emptyText,
    for (final s in stats) ...[s.label, s.value],
    for (final t in tagLines) ...[
      t.label,
      for (final tag in t.tags) ...[tag.label, tag.count],
    ],
  ];
}
