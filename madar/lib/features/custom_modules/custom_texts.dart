import 'dart:ui' show Locale;

import 'package:flutter/widgets.dart' show BuildContext;
import 'package:intl/date_symbol_data_local.dart';

import '../../core/domain/enums.dart';
import '../../core/domain/money.dart';
import '../../core/i18n/formatters.dart';
import '../../core/i18n/gen/app_localizations.dart';
import '../../core/settings/app_settings.dart' show DigitStyle;
import 'domain/field_migration.dart';
import 'domain/field_values.dart';
import 'domain/module_builder_rules.dart';
import 'domain/module_export.dart';
import 'domain/module_reminders.dart';
import 'domain/module_schema.dart';
import 'domain/module_summary.dart';
import 'domain/module_templates.dart';

/// Every user-facing Custom Modules text: localisations + the user's digit
/// style (numbers in Arabic-Indic digits in Arabic by default) + bidi
/// isolation of user-written names. Also the localised implementation of the
/// domain's formatter / export / reminder text interfaces.
class CustomTexts implements CustomReminderTexts, ModuleExportTexts, ModuleValueFormatter {
  const CustomTexts(this.l, this.fmt, {this.planetNames = const {}});

  factory CustomTexts.of(BuildContext context, {Map<String, String> planetNames = const {}}) =>
      CustomTexts(L10n.of(context), MadarFormatter.of(context), planetNames: planetNames);

  /// Texts outside the widget tree (notifications, exports).
  factory CustomTexts.forLanguage(
    String languageCode, {
    DigitStyle digits = DigitStyle.auto,
    Map<String, String> planetNames = const {},
  }) {
    if (!_dateSymbols) {
      _dateSymbols = true;
      initializeDateFormatting();
    }
    final lang = languageCode == 'en' ? 'en' : 'ar';
    return CustomTexts(
      lookupL10n(Locale(lang)),
      MadarFormatter(languageCode: lang, digits: digits),
      planetNames: planetNames,
    );
  }

  static bool _dateSymbols = false;

  final L10n l;
  final MadarFormatter fmt;

  /// Planet key → display name (the Planets table, in the UI language).
  final Map<String, String> planetNames;

  CustomTexts withPlanets(Map<String, String> names) => CustomTexts(l, fmt, planetNames: names);

  bool get arabic => fmt.languageCode == 'ar';

  String _n(String s) => fmt.localizeDigits(s);

  /// A user-written name, isolated so it never scrambles the sentence.
  String name(String s) => fmt.isolate(s.trim());

  String count(int n) => fmt.formatInt(n);

  // ------------------------------------------------------------ kinds ----

  @override
  String kind(CustomModuleKind kind) => kind == CustomModuleKind.tracker ? l.cmodKindTracker : l.cmodKindList;

  String kindHint(CustomModuleKind kind) =>
      kind == CustomModuleKind.tracker ? l.cmodKindTrackerHint : l.cmodKindListHint;

  @override
  String fieldType(FieldType type) => switch (type) {
    FieldType.text => l.cmodTypeText,
    FieldType.number => l.cmodTypeNumber,
    FieldType.date => l.cmodTypeDate,
    FieldType.time => l.cmodTypeTime,
    FieldType.checkbox => l.cmodTypeCheckbox,
    FieldType.singleSelect => l.cmodTypeSingle,
    FieldType.multiSelect => l.cmodTypeMulti,
    FieldType.rating => l.cmodTypeRating,
    FieldType.currency => l.cmodTypeCurrency,
  };

  String fieldTypeHint(FieldType type) => switch (type) {
    FieldType.text => l.cmodTypeTextHint,
    FieldType.number => l.cmodTypeNumberHint,
    FieldType.date => l.cmodTypeDateHint,
    FieldType.time => l.cmodTypeTimeHint,
    FieldType.checkbox => l.cmodTypeCheckboxHint,
    FieldType.singleSelect => l.cmodTypeSingleHint,
    FieldType.multiSelect => l.cmodTypeMultiHint,
    FieldType.rating => l.cmodTypeRatingHint,
    FieldType.currency => l.cmodTypeCurrencyHint,
  };

  String chartType(ModuleChartType t) => switch (t) {
    ModuleChartType.line => l.cmodChartLine,
    ModuleChartType.bar => l.cmodChartBar,
    ModuleChartType.heat => l.cmodChartHeat,
    ModuleChartType.streak => l.cmodChartStreak,
  };

  String range(int days) => _n(l.cmodRangeDays(days));
  String days(int days) => _n(l.cmodDays(days));

  @override
  String? planet(String? key) => key == null ? null : planetNames[key];

  @override
  String? window(PrayerWindow? w) => switch (w) {
    null => null,
    PrayerWindow.fajr => l.windowFajr,
    PrayerWindow.duha => l.windowDuha,
    PrayerWindow.dhuhr => l.windowDhuhr,
    PrayerWindow.asr => l.windowAsr,
    PrayerWindow.maghrib => l.windowMaghrib,
    PrayerWindow.isha => l.windowIsha,
    PrayerWindow.anytime => l.windowAnytime,
  };

  // ------------------------------------------------------------ counts ----

  String modules(int n) => _n(l.cmodModulesCount(n));
  String loggedToday(int n) => _n(l.cmodLoggedToday(n));
  String entries(int n) => _n(l.cmodEntriesCount(n));
  String items(int n) => _n(l.cmodItemsCount(n));
  String openItems(int n) => _n(l.cmodOpenItems(n));
  String itemsProgress(int done, int total) => l.cmodItemsProgress(count(done), count(total));
  String stars(int n) => _n(l.cmodRateStars(n));
  String options(int n) => _n(l.cmodFieldOptionsCount(n));
  String streakBadge(int n) => l.cmodStreakBadge(count(n));

  /// "Last entry today / yesterday / N days ago / No entries yet".
  String lastEntry(ModuleSummary s, DateTime now) {
    final d = s.daysSinceLast(now);
    return switch (d) {
      null => l.cmodNoEntries,
      0 => l.cmodLastToday,
      1 => l.cmodLastYesterday,
      _ => _n(l.cmodLastDaysAgo(d)),
    };
  }

  /// "Today", "Yesterday" or the weekday and date.
  String dayLabel(DateTime day, DateTime today) {
    final a = DateTime(day.year, day.month, day.day), t = DateTime(today.year, today.month, today.day);
    if (a == t) return l.cmodToday;
    if (a == DateTime(t.year, t.month, t.day - 1)) return l.cmodYesterday;
    return fmt.formatDate(a, style: a.year == t.year ? MadarDateStyle.weekdayDayMonth : MadarDateStyle.medium);
  }

  // ----------------------------------------------------------- formatter --

  @override
  String number(num n) => fmt.formatNumber(n, maxDecimals: 3);

  @override
  String date(DateTime d) => fmt.formatDate(d, style: MadarDateStyle.medium);

  @override
  String time(String hhmm) {
    final m = FieldValues.minutesOf(hhmm);
    if (m == null) return _n(hhmm);
    return fmt.formatClock(m ~/ 60, m % 60);
  }

  String clock(DateTime t) => fmt.formatTime(t);

  @override
  String money(Money m) => m.format(
    locale: fmt.languageCode,
    digits: fmt.arabicIndic ? MoneyDigits.arabicIndic : MoneyDigits.western,
  );

  /// "٤/٥" (the app fonts have no star glyph: rows draw star icons).
  @override
  String rating(int stars, int max) => '${count(stars)}/${count(max)}';

  @override
  String checkbox(bool value) => value ? l.cmodChecked : l.cmodUnchecked;

  /// [v] of [f] for people (null when empty).
  String? value(ModuleField f, Object? v) => ModuleExport.displayValue(f, v, fmt: this);

  /// A number as the user types it (digits in their script, no grouping).
  String editableNumber(num n) => _n(FieldMigration.plainNumber(n));

  /// An amount as the user types it (currency decimals, no grouping).
  String editableAmount(Money m) =>
      _n(m.formatAmount(locale: 'en', digits: MoneyDigits.western).replaceAll(',', ''));

  // ------------------------------------------------------------ builder ----

  String issue(DraftIssue issue) => switch (issue) {
    DraftIssue.nameMissing => l.cmodIssueNameMissing,
    DraftIssue.nameTooLong => l.cmodIssueNameTooLong,
    DraftIssue.noFields => l.cmodIssueNoFields,
    DraftIssue.tooManyFields => l.cmodIssueTooManyFields(count(ModuleBuilderRules.maxFields)),
    DraftIssue.labelMissing => l.cmodIssueLabelMissing,
    DraftIssue.labelDuplicate => l.cmodIssueLabelDuplicate,
    DraftIssue.noOptions => l.cmodIssueNoOptions,
    DraftIssue.optionLabelMissing => l.cmodIssueOptionLabelMissing,
    DraftIssue.optionDuplicate => l.cmodIssueOptionDuplicate,
    DraftIssue.rangeInverted => l.cmodIssueRangeInverted,
    DraftIssue.currencyCode => l.cmodIssueCurrencyCode,
  };

  String migration(MigrationIssue i) {
    final field = name(i.fieldLabel);
    final e = entries(i.count);
    return switch (i.kind) {
      MigrationIssueKind.typeChangeBlocked => l.cmodMigTypeBlocked(field, e, fieldType(i.to!)),
      MigrationIssueKind.ratingScaleBlocked => l.cmodMigRatingBlocked(field, e),
      MigrationIssueKind.fieldHidden => l.cmodMigFieldHidden(field, e),
      MigrationIssueKind.optionHidden => l.cmodMigOptionHidden(field),
      MigrationIssueKind.valuesConverted => l.cmodMigConverted(field, e, fieldType(i.to!)),
      MigrationIssueKind.outOfRange => l.cmodMigOutOfRange(field, e),
      MigrationIssueKind.newlyRequired => l.cmodMigNewlyRequired(field, e),
    };
  }

  /// A field's settings in one line: "Number · pages · 0 – 500 · required".
  String fieldSummary(ModuleField f) {
    final bits = <String>[fieldType(f.type)];
    switch (f.type) {
      case FieldType.number:
        if (f.unit != null) bits.add(f.unit!);
        final r = _range(f.min, f.max);
        if (r != null) bits.add(r);
      case FieldType.currency:
        bits.add(f.currencyCode);
      case FieldType.rating:
        bits.add(l.cmodFieldRange(count(1), count(f.ratingMax)));
      case FieldType.singleSelect || FieldType.multiSelect:
        bits.add(options(f.visibleOptions.length));
      case FieldType.text when f.multiline:
        bits.add(l.cmodFieldMultiline);
      default:
        break;
    }
    if (f.isRequired) bits.add(l.cmodFieldRequired);
    return bits.join(' · ');
  }

  String? _range(num? min, num? max) {
    if (min != null && max != null) return l.cmodFieldRange(number(min), number(max));
    if (min != null) return l.cmodFieldAtLeast(number(min));
    if (max != null) return l.cmodFieldAtMost(number(max));
    return null;
  }

  // ------------------------------------------------------------- entries ---

  String entryIssue(ModuleField f, FieldCheck c) => switch (c.issue) {
    null => '',
    EntryIssue.required => l.cmodErrRequired,
    EntryIssue.notANumber => l.cmodErrNumber,
    EntryIssue.notWhole => l.cmodErrWhole,
    EntryIssue.tooPrecise => l.cmodErrPrecise(count((c.bound ?? 0).round())),
    EntryIssue.belowMin => l.cmodErrMin(number(c.bound ?? 0)),
    EntryIssue.aboveMax => l.cmodErrMax(number(c.bound ?? 0)),
    EntryIssue.invalidDate => l.cmodErrDate,
    EntryIssue.invalidTime => l.cmodErrTime,
    EntryIssue.unknownOption => l.cmodErrOption,
    EntryIssue.outOfScale => l.cmodErrScale,
    EntryIssue.tooLong => l.cmodErrTooLong,
  };

  // ----------------------------------------------------------- templates ---

  String templateName(ModuleTemplateKey k) => switch (k) {
    ModuleTemplateKey.readingLog => l.cmodTplReadingLog,
    ModuleTemplateKey.dhikrCounter => l.cmodTplDhikr,
    ModuleTemplateKey.dailyHabit => l.cmodTplHabit,
    ModuleTemplateKey.habitList => l.cmodTplHabitList,
    ModuleTemplateKey.sleepLog => l.cmodTplSleep,
    ModuleTemplateKey.giftIdeas => l.cmodTplGifts,
  };

  String templateDescription(ModuleTemplateKey k) => switch (k) {
    ModuleTemplateKey.readingLog => l.cmodTplReadingLogDesc,
    ModuleTemplateKey.dhikrCounter => l.cmodTplDhikrDesc,
    ModuleTemplateKey.dailyHabit => l.cmodTplHabitDesc,
    ModuleTemplateKey.habitList => l.cmodTplHabitListDesc,
    ModuleTemplateKey.sleepLog => l.cmodTplSleepDesc,
    ModuleTemplateKey.giftIdeas => l.cmodTplGiftsDesc,
  };

  String template(TemplateText t) => switch (t) {
    TemplateText.readingLogName => l.cmodTplReadingLog,
    TemplateText.readingBook => l.cmodTplBook,
    TemplateText.readingPages => l.cmodTplPages,
    TemplateText.readingRating => l.cmodTplRating,
    TemplateText.unitPages => l.cmodTplUnitPages,
    TemplateText.dhikrName => l.cmodTplDhikr,
    TemplateText.dhikrAfter => l.cmodTplAfterPrayer,
    TemplateText.dhikrCount => l.cmodTplCount,
    TemplateText.unitTimes => l.cmodTplUnitTimes,
    TemplateText.prayerFajr => l.prayerFajr,
    TemplateText.prayerDhuhr => l.prayerDhuhr,
    TemplateText.prayerAsr => l.prayerAsr,
    TemplateText.prayerMaghrib => l.prayerMaghrib,
    TemplateText.prayerIsha => l.prayerIsha,
    TemplateText.habitName => l.cmodTplHabit,
    TemplateText.habitDone => l.cmodTplDone,
    TemplateText.habitNote => l.cmodTplNote,
    TemplateText.habitListName => l.cmodTplHabitList,
    TemplateText.habitListHabit => l.cmodTplHabitItem,
    TemplateText.habitListFrequency => l.cmodTplFrequency,
    TemplateText.frequencyDaily => l.cmodTplDaily,
    TemplateText.frequencyWeekly => l.cmodTplWeekly,
    TemplateText.frequencyMonthly => l.cmodTplMonthly,
    TemplateText.sleepName => l.cmodTplSleep,
    TemplateText.sleepBedtime => l.cmodTplBedtime,
    TemplateText.sleepWake => l.cmodTplWake,
    TemplateText.sleepHours => l.cmodTplHours,
    TemplateText.unitHours => l.cmodTplUnitHours,
    TemplateText.sleepQuality => l.cmodTplQuality,
    TemplateText.giftName => l.cmodTplGifts,
    TemplateText.giftIdea => l.cmodTplIdea,
    TemplateText.giftFor => l.cmodTplFor,
    TemplateText.giftBudget => l.cmodTplBudget,
    TemplateText.giftOccasion => l.cmodTplOccasion,
    TemplateText.notes => l.cmodTplNotes,
  };

  // ------------------------------------------------------- notifications ---

  @override
  String reminderTitle(String moduleName) => moduleName.trim();

  @override
  String reminderBody(CustomModuleKind kind, String moduleName) =>
      kind == CustomModuleKind.tracker ? l.cmodNotifyBodyTracker : l.cmodNotifyBodyList;

  // -------------------------------------------------------------- export ---

  @override
  String get kindLabel => l.cmodKind;
  @override
  String get planetLabel => l.cmodPlanet;
  @override
  String get windowLabel => l.cmodWindow;
  @override
  String get fieldsLabel => l.cmodSectionFields;
  @override
  String get entriesLabel => l.cmodExportEntries;
  @override
  String get lastEntryLabel => l.cmodExportLastEntry;
  @override
  String get requiredLabel => l.cmodFieldRequired;
  @override
  String get hiddenLabel => l.cmodExportHidden;
  @override
  String get dateColumn => l.cmodExportDate;
  @override
  String get timeColumn => l.cmodExportTime;
  @override
  String get doneColumn => l.cmodExportDone;
  @override
  String get openLabel => l.cmodExportOpen;
  @override
  String get doneLabel => l.cmodDoneSection;
  @override
  String get noEntries => l.cmodNoEntries;

  @override
  String lastDays(int days) => _n(l.cmodExportLastDays(days));
  @override
  String activeDays(int days) => _n(l.cmodExportActiveDays(days));
  @override
  String total(String value) => l.cmodExportTotal(value);
  @override
  String average(String value) => l.cmodExportAverage(value);
  @override
  String streak(int current, int best) => l.cmodExportStreak(count(current), count(best));
}
