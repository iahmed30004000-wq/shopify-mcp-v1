import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../domain/lab_flags.dart';
import '../domain/record_texts.dart';

/// Screen-side helpers: texts, colours and icons of the record.
extension RecordContext on BuildContext {
  RecordTexts get recordTexts => RecordTexts(L10n.of(this), MadarFormatter.of(this));
}

abstract final class RecordColors {
  /// Out of range → danger, borderline → warning, the rest calm.
  static Color flag(MadarTokens t, LabFlag f) => switch (f) {
    LabFlag.low || LabFlag.high => t.danger,
    LabFlag.borderlineLow || LabFlag.borderlineHigh => t.warning,
    LabFlag.inRange => t.textSecondary,
    _ => t.textTertiary,
  };

  /// Chart dot colour: flagged ones in their flag colour, the rest in the
  /// neutral text colour (the line itself is the accent).
  static Color dot(MadarTokens t, LabFlag f) => f.isFlagged ? flag(t, f) : t.textPrimary;

  /// The reference band and its dashed limits.
  static Color band(MadarTokens t) => t.info;

  static Color severity(MadarTokens t, Severity s) => switch (s) {
    Severity.critical => t.danger,
    Severity.warning => t.warning,
    Severity.info => t.info,
  };
}

abstract final class RecordIcons {
  static const labs = Icons.science_outlined;
  static const appointments = Icons.event_available_outlined;
  static const conditions = Icons.monitor_heart_outlined;
  static const questions = Icons.contact_support_outlined;
  static const report = Icons.picture_as_pdf_outlined;
  static const settings = Icons.tune_rounded;
  static const alert = Icons.push_pin_outlined;
  static const visit = Icons.biotech_outlined;
  static const doctor = Icons.person_outline_rounded;
  static const place = Icons.place_outlined;
  static const time = Icons.schedule_rounded;
  static const notes = Icons.notes_rounded;

  static IconData severity(Severity s) => switch (s) {
    Severity.critical => Icons.do_not_disturb_on_outlined,
    Severity.warning => Icons.warning_amber_rounded,
    Severity.info => Icons.info_outline_rounded,
  };

  /// Vertical arrows only (never mirrored): towards / beyond which limit.
  static IconData? flag(LabFlag f) => switch (f) {
    LabFlag.low || LabFlag.borderlineLow => Icons.arrow_downward_rounded,
    LabFlag.high || LabFlag.borderlineHigh => Icons.arrow_upward_rounded,
    _ => null,
  };
}
