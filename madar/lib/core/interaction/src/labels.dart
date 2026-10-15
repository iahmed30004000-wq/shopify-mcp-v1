import 'package:flutter/material.dart';

import '../../domain/enums.dart';
import '../../i18n/formatters.dart';
import '../../i18n/gen/app_localizations.dart';
import '../numbers.dart';
import '../quick_add/parser.dart';
import '../sheets/field_spec.dart';

/// Localised labels for the interaction kit's domain values.
abstract final class KitLabels {
  static String window(L10n l, PrayerWindow w) => switch (w) {
    PrayerWindow.fajr => l.windowFajr,
    PrayerWindow.duha => l.windowDuha,
    PrayerWindow.dhuhr => l.windowDhuhr,
    PrayerWindow.asr => l.windowAsr,
    PrayerWindow.maghrib => l.windowMaghrib,
    PrayerWindow.isha => l.windowIsha,
    PrayerWindow.anytime => l.windowAnytime,
  };

  /// Name of the prayer that opens a window ("Asr"), for reminders.
  static String prayer(L10n l, PrayerWindow w) => switch (w) {
    PrayerWindow.fajr => l.prayerFajr,
    PrayerWindow.duha => l.windowDuha,
    PrayerWindow.dhuhr => l.prayerDhuhr,
    PrayerWindow.asr => l.prayerAsr,
    PrayerWindow.maghrib => l.prayerMaghrib,
    PrayerWindow.isha => l.prayerIsha,
    PrayerWindow.anytime => l.windowAnytime,
  };

  static IconData windowIcon(PrayerWindow w) => switch (w) {
    PrayerWindow.fajr => Icons.wb_twilight_rounded,
    PrayerWindow.duha => Icons.light_mode_rounded,
    PrayerWindow.dhuhr => Icons.wb_sunny_rounded,
    PrayerWindow.asr => Icons.wb_cloudy_rounded,
    PrayerWindow.maghrib => Icons.nights_stay_rounded,
    PrayerWindow.isha => Icons.bedtime_rounded,
    PrayerWindow.anytime => Icons.all_inclusive_rounded,
  };

  static String currencyName(L10n l, String code) => switch (code) {
    'JOD' => l.interactionCurrencyJOD,
    'USD' => l.interactionCurrencyUSD,
    'SYP' => l.interactionCurrencySYP,
    'EGP' => l.interactionCurrencyEGP,
    'LYD' => l.interactionCurrencyLYD,
    _ => code,
  };

  static String currencySymbol(L10n l, String code) => switch (code) {
    'JOD' => l.interactionCurrencySymbolJOD,
    'USD' => l.interactionCurrencySymbolUSD,
    'SYP' => l.interactionCurrencySymbolSYP,
    'EGP' => l.interactionCurrencySymbolEGP,
    'LYD' => l.interactionCurrencySymbolLYD,
    _ => code,
  };

  /// Short weekday label for a Dart weekday (1 = Monday … 7 = Sunday).
  static String weekday(L10n l, int weekday) => switch (weekday) {
    DateTime.monday => l.interactionWeekdayMon,
    DateTime.tuesday => l.interactionWeekdayTue,
    DateTime.wednesday => l.interactionWeekdayWed,
    DateTime.thursday => l.interactionWeekdayThu,
    DateTime.friday => l.interactionWeekdayFri,
    DateTime.saturday => l.interactionWeekdaySat,
    _ => l.interactionWeekdaySun,
  };

  /// Human duration: "10 minutes", "2 hours", "1 day", "1 week", in the
  /// user's digit style (`١٥ دقيقة`).
  static String duration(BuildContext context, int minutes) {
    final l = L10n.of(context);
    final m = minutes.abs();
    final String s;
    if (m != 0 && m % 10080 == 0) {
      s = l.interactionDurationWeeks(m ~/ 10080);
    } else if (m != 0 && m % 1440 == 0) {
      s = l.interactionDurationDays(m ~/ 1440);
    } else if (m != 0 && m % 60 == 0) {
      s = l.interactionDurationHours(m ~/ 60);
    } else {
      s = l.interactionDurationMinutes(m);
    }
    return MadarFormatter.of(context).localizeDigits(s);
  }

  /// A validation message, its numbers in the user's digit style.
  static String issue(BuildContext context, FieldIssue issue) =>
      MadarFormatter.of(context).localizeDigits(_issue(L10n.of(context), issue));

  static String _issue(L10n l, FieldIssue issue) {
    String n(num? v) => v == null ? '' : LocalizedNumbers.formatNum(v);
    return switch (issue.code) {
      FieldIssueCode.required => l.fieldRequired,
      FieldIssueCode.invalidNumber => l.fieldInvalidNumber,
      FieldIssueCode.belowMin => l.interactionFieldMin(n(issue.limit)),
      FieldIssueCode.aboveMax => l.interactionFieldMax(n(issue.limit)),
      FieldIssueCode.tooManyDecimals => l.interactionFieldDecimals((issue.limit ?? 0).toInt()),
      FieldIssueCode.tooLong => l.interactionFieldTooLong((issue.limit ?? 0).toInt()),
      FieldIssueCode.selectAtLeast => l.interactionFieldSelectAtLeast((issue.limit ?? 1).toInt()),
      FieldIssueCode.selectAtMost => l.interactionFieldSelectAtMost((issue.limit ?? 1).toInt()),
      FieldIssueCode.dateOutOfRange => l.interactionFieldDateRange,
      FieldIssueCode.custom => issue.message ?? l.fieldRequired,
    };
  }

  static String kind(L10n l, QuickAddKind k) => switch (k) {
    QuickAddKind.task => l.interactionKindTask,
    QuickAddKind.expense => l.interactionKindExpense,
    QuickAddKind.income => l.interactionKindIncome,
    QuickAddKind.water => l.interactionKindWater,
    QuickAddKind.pain => l.interactionKindPain,
    QuickAddKind.mood => l.interactionKindMood,
    QuickAddKind.contact => l.interactionKindContact,
    QuickAddKind.note => l.interactionKindNote,
  };

  static IconData kindIcon(QuickAddKind k) => switch (k) {
    QuickAddKind.task => Icons.task_alt_rounded,
    QuickAddKind.expense => Icons.payments_rounded,
    QuickAddKind.income => Icons.savings_rounded,
    QuickAddKind.water => Icons.water_drop_rounded,
    QuickAddKind.pain => Icons.healing_rounded,
    QuickAddKind.mood => Icons.sentiment_satisfied_rounded,
    QuickAddKind.contact => Icons.call_rounded,
    QuickAddKind.note => Icons.sticky_note_2_rounded,
  };

  static String planet(L10n l, String key) => switch (key) {
    'faith' => l.planetFaith,
    'health' => l.planetHealth,
    'family' => l.planetFamily,
    'work' => l.planetWork,
    'money' => l.planetMoney,
    'growth' => l.planetGrowth,
    'body' => l.planetBody,
    'travel' => l.planetTravel,
    _ => key,
  };

  /// "Today" / "Tomorrow" / "Yesterday" / "Day after tomorrow" or a medium
  /// date, its digits in the user's digit style.
  static String date(BuildContext context, DateTime date, {DateTime? now}) {
    final l = L10n.of(context);
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = d.difference(today).inHours / 24;
    final days = diff.round();
    return switch (days) {
      0 => l.interactionDateToday,
      1 => l.interactionDateTomorrow,
      2 => l.interactionDateDayAfter,
      -1 => l.interactionDateYesterday,
      _ => MadarFormatter.of(context).localizeDigits(MaterialLocalizations.of(context).formatMediumDate(d)),
    };
  }

  /// Formats `"HH:mm"` for display (12/24 h per the platform setting) in the
  /// user's digit style – intl's `ar` data formats times with Western digits.
  static String time(BuildContext context, String hhmm) {
    final (h, m) = ClockTime.parts(hhmm);
    return MadarFormatter.of(context).localizeDigits(
      MaterialLocalizations.of(context).formatTimeOfDay(
        TimeOfDay(hour: h, minute: m),
        alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      ),
    );
  }
}
