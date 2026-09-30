import 'package:flutter/material.dart';

import '../../../core/db/database.dart';
import '../../../core/design/tokens.dart';
import '../../../core/domain/enums.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../home/widgets/window_chips.dart' show windowLabel;
import '../domain/board_columns.dart';
import '../domain/countdown.dart';
import '../domain/work_days.dart';

/// Countries offered as board labels (a generic regional list; any other
/// text is accepted too). Stored as the ISO code.
const List<String> kWorkCountries = [
  'JO', 'SA', 'AE', 'KW', 'QA', 'BH', 'OM', 'IQ', 'SY', 'LB', 'PS', 'EG', 'LY', 'TN', 'DZ', 'MA', 'SD', 'YE', 'TR', //
];

/// Localised texts of the Work planet (numbers in the user's digits, names
/// bidi-isolated).
class WorkTexts {
  WorkTexts(this.l, this.fmt);

  factory WorkTexts.of(BuildContext context) => WorkTexts(L10n.of(context), MadarFormatter.of(context));

  final L10n l;
  final MadarFormatter fmt;

  String n(int v) => fmt.formatInt(v);
  String d(String s) => fmt.localizeDigits(s);

  /// A user-typed name, isolated so it never reorders the sentence.
  String name(String s) => fmt.isolate(s.trim());

  String column(BoardColumn c) {
    switch (BoardColumns.defaultKindOf(c)) {
      case DefaultColumnKind.todo:
        return l.workColTodo;
      case DefaultColumnKind.doing:
        return l.workColDoing;
      case DefaultColumnKind.done:
        return l.workColDone;
      case null:
        final s = c.label.trim();
        return s.isEmpty ? l.workColumnUntitled : s;
    }
  }

  String? countryName(String code) => switch (code.toUpperCase()) {
    'JO' => l.workCountryJO,
    'SA' => l.workCountrySA,
    'AE' => l.workCountryAE,
    'KW' => l.workCountryKW,
    'QA' => l.workCountryQA,
    'BH' => l.workCountryBH,
    'OM' => l.workCountryOM,
    'IQ' => l.workCountryIQ,
    'SY' => l.workCountrySY,
    'LB' => l.workCountryLB,
    'PS' => l.workCountryPS,
    'EG' => l.workCountryEG,
    'LY' => l.workCountryLY,
    'TN' => l.workCountryTN,
    'DZ' => l.workCountryDZ,
    'MA' => l.workCountryMA,
    'SD' => l.workCountrySD,
    'YE' => l.workCountryYE,
    'TR' => l.workCountryTR,
    _ => null,
  };

  /// A board's country / business label: the localised country for a known
  /// code, else the text as typed.
  String? country(String? stored) {
    final s = stored?.trim();
    if (s == null || s.isEmpty) return null;
    return countryName(s) ?? s;
  }

  String window(PrayerWindow w) => windowLabel(l, w);

  String status(ProjectStatus s) => switch (s) {
    ProjectStatus.active => l.workStatusActive,
    ProjectStatus.paused => l.workStatusPaused,
    ProjectStatus.done => l.workStatusDone,
  };

  /// A day relative to [today]: today / tomorrow / the date.
  String day(DateTime day, DateTime today) {
    final n = WorkDays.between(today, day);
    if (n == 0) return l.workToday;
    if (n == 1) return l.workTomorrow;
    return fmt.formatDate(day, style: MadarDateStyle.dayMonth);
  }

  /// Short due badge text.
  String due(DateTime due, DateTime today) {
    final c = Countdown.of(due, today);
    return switch (c.kind) {
      CountdownKind.overdue => d(l.workLateDays(c.days)),
      CountdownKind.today => l.workToday,
      CountdownKind.tomorrow => l.workTomorrow,
      _ => fmt.formatDate(due, style: MadarDateStyle.dayMonth),
    };
  }

  String cards(int count) => d(l.workCardsCount(count));
  String daysLeft(int count) => d(l.workDaysLeft(count));

  String planet(PlanetRow p) => l.localeName.startsWith('ar') ? p.nameAr : p.nameEn;
}

/// Colours of due states.
Color dueColor(MadarTokens t, DueStatus s) => switch (s) {
  DueStatus.overdue => t.danger,
  DueStatus.today => t.warning,
  DueStatus.tomorrow => t.info,
  _ => t.textSecondary,
};

/// A board's / project's colour, or the theme accent.
Color workColor(MadarTokens t, int? argb) => argb == null ? t.accent : Color(argb);

IconData workStatusIcon(ProjectStatus s) => switch (s) {
  ProjectStatus.active => Icons.play_circle_outline_rounded,
  ProjectStatus.paused => Icons.pause_circle_outline_rounded,
  ProjectStatus.done => Icons.check_circle_outline_rounded,
};
