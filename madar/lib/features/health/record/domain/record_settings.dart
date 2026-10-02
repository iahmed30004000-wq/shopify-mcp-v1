import 'package:flutter/foundation.dart';

import 'appointment_plan.dart';
import 'lab_flags.dart';
import 'report_model.dart';

/// The medical record's preferences, stored on the device under
/// `key_values['health.record']`. Nothing personal is kept here unless the
/// user explicitly saves a name for the doctor report.
@immutable
class RecordSettings {
  const RecordSettings({
    this.borderlineMargin = LabFlags.defaultMargin,
    this.remindersEnabled = true,
    this.reminderOffsets = defaultOffsets,
    this.reportName,
    this.reportSections,
    this.reportPeriod = ReportPeriod.months6,
  });

  /// Day before + 2 hours before.
  static const List<int> defaultOffsets = [1440, 120];

  /// Offsets (minutes before) the settings offer.
  static const List<int> offsetChoices = [10080, 2880, 1440, 180, 120, 60, 30];

  static const String storageKey = 'health.record';

  /// Fraction of the range width counted as borderline (see [LabFlags]).
  final double borderlineMargin;
  final bool remindersEnabled;

  /// Minutes before each appointment (largest first).
  final List<int> reminderOffsets;

  /// Only set when the user ticked "remember on this device".
  final String? reportName;

  /// Sections last used for the doctor report (null = all).
  final Set<ReportSection>? reportSections;
  final ReportPeriod reportPeriod;

  List<int> get effectiveOffsets =>
      remindersEnabled ? AppointmentReminderPlanner.normalizeOffsets(reminderOffsets) : const [];

  Set<ReportSection> get sectionsOrDefault => reportSections ?? ReportSection.values.toSet();

  RecordSettings copyWith({
    double? borderlineMargin,
    bool? remindersEnabled,
    List<int>? reminderOffsets,
    String? reportName,
    bool clearReportName = false,
    Set<ReportSection>? reportSections,
    ReportPeriod? reportPeriod,
  }) => RecordSettings(
    borderlineMargin: (borderlineMargin ?? this.borderlineMargin).clamp(0.0, LabFlags.maxMargin),
    remindersEnabled: remindersEnabled ?? this.remindersEnabled,
    reminderOffsets: reminderOffsets == null
        ? this.reminderOffsets
        : AppointmentReminderPlanner.normalizeOffsets(reminderOffsets),
    reportName: clearReportName ? null : (reportName ?? this.reportName),
    reportSections: reportSections ?? this.reportSections,
    reportPeriod: reportPeriod ?? this.reportPeriod,
  );

  Map<String, Object?> toJson() => {
    'borderlineMargin': borderlineMargin,
    'remindersEnabled': remindersEnabled,
    'reminderOffsets': reminderOffsets,
    if (reportName != null) 'reportName': reportName,
    if (reportSections != null) 'reportSections': [for (final s in reportSections!) s.name],
    'reportPeriod': reportPeriod.name,
  };

  static RecordSettings fromJson(Object? json) {
    if (json is! Map) return const RecordSettings();
    final margin = json['borderlineMargin'];
    final offsets = json['reminderOffsets'];
    final sections = json['reportSections'];
    final name = json['reportName'];
    return RecordSettings(
      borderlineMargin: margin is num ? margin.toDouble().clamp(0.0, LabFlags.maxMargin) : LabFlags.defaultMargin,
      remindersEnabled: json['remindersEnabled'] is bool ? json['remindersEnabled'] as bool : true,
      reminderOffsets: offsets is List
          ? AppointmentReminderPlanner.normalizeOffsets([
              for (final o in offsets)
                if (o is num) o.toInt(),
            ])
          : defaultOffsets,
      reportName: name is String && name.trim().isNotEmpty ? name.trim() : null,
      reportSections: sections is List
          ? {for (final s in sections) ?ReportSection.values.where((v) => v.name == s).firstOrNull}
          : null,
      reportPeriod:
          ReportPeriod.values.where((p) => p.name == json['reportPeriod']).firstOrNull ?? ReportPeriod.months6,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RecordSettings &&
      other.borderlineMargin == borderlineMargin &&
      other.remindersEnabled == remindersEnabled &&
      listEquals(other.reminderOffsets, reminderOffsets) &&
      other.reportName == reportName &&
      setEquals(other.reportSections, reportSections) &&
      other.reportPeriod == reportPeriod;

  @override
  int get hashCode => Object.hash(
    borderlineMargin,
    remindersEnabled,
    Object.hashAll(reminderOffsets),
    reportName,
    reportSections == null ? null : Object.hashAllUnordered(reportSections!),
    reportPeriod,
  );
}
