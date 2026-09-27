import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/design/themes.dart';
import '../../core/design/tokens.dart';
import '../../core/domain/budget_math.dart';
import '../../core/domain/money.dart';
import '../../core/i18n/gen/app_localizations.dart';
import '../../core/import/import.dart';
import '../../core/settings/app_settings.dart';

/// Localised names, icons and colours of import sections.
extension ImportSectionPresentation on ImportSection {
  String label(L10n l) => switch (this) {
    ImportSection.healthAlerts => l.importSectionHealthAlerts,
    ImportSection.conditions => l.importSectionConditions,
    ImportSection.medications => l.importSectionMedications,
    ImportSection.medDoses => l.importSectionMedDoses,
    ImportSection.labTests => l.importSectionLabTests,
    ImportSection.labReadings => l.importSectionLabReadings,
    ImportSection.appointments => l.importSectionAppointments,
    ImportSection.doctorQuestions => l.importSectionDoctorQuestions,
    ImportSection.painEntries => l.importSectionPainEntries,
    ImportSection.moodEntries => l.importSectionMoodEntries,
    ImportSection.habits => l.importSectionHabits,
    ImportSection.habitLogs => l.importSectionHabitLogs,
    ImportSection.worries => l.importSectionWorries,
    ImportSection.currencies => l.importSectionCurrencies,
    ImportSection.wallets => l.importSectionWallets,
    ImportSection.budgetItems => l.importSectionBudgetItems,
    ImportSection.transactions => l.importSectionTransactions,
    ImportSection.jars => l.importSectionJars,
    ImportSection.jarDeposits => l.importSectionJarDeposits,
    ImportSection.debts => l.importSectionDebts,
    ImportSection.debtPayments => l.importSectionDebtPayments,
    ImportSection.obligations => l.importSectionObligations,
    ImportSection.people => l.importSectionPeople,
    ImportSection.contactLogs => l.importSectionContactLogs,
    ImportSection.projects => l.importSectionProjects,
    ImportSection.projectItems => l.importSectionProjectItems,
    ImportSection.boards => l.importSectionBoards,
    ImportSection.boardCards => l.importSectionBoardCards,
    ImportSection.trips => l.importSectionTrips,
    ImportSection.tripItems => l.importSectionTripItems,
    ImportSection.travelDocuments => l.importSectionTravelDocuments,
    ImportSection.learningGoals => l.importSectionLearningGoals,
    ImportSection.goalLogs => l.importSectionGoalLogs,
    ImportSection.exercises => l.importSectionExercises,
    ImportSection.workoutLogs => l.importSectionWorkoutLogs,
    ImportSection.avoidItems => l.importSectionAvoidItems,
    ImportSection.fastingSessions => l.importSectionFastingSessions,
    ImportSection.waterLogs => l.importSectionWaterLogs,
    ImportSection.prayerLogs => l.importSectionPrayerLogs,
    ImportSection.tasks => l.importSectionTasks,
    ImportSection.customModules => l.importSectionCustomModules,
    ImportSection.customEntries => l.importSectionCustomEntries,
  };

  IconData get icon => switch (this) {
    ImportSection.healthAlerts => Icons.warning_amber_rounded,
    ImportSection.conditions => Icons.monitor_heart_outlined,
    ImportSection.medications => Icons.medication_rounded,
    ImportSection.medDoses => Icons.checklist_rounded,
    ImportSection.labTests => Icons.biotech_rounded,
    ImportSection.labReadings => Icons.show_chart_rounded,
    ImportSection.appointments => Icons.event_rounded,
    ImportSection.doctorQuestions => Icons.help_outline_rounded,
    ImportSection.painEntries => Icons.healing_rounded,
    ImportSection.moodEntries => Icons.mood_rounded,
    ImportSection.habits => Icons.repeat_rounded,
    ImportSection.habitLogs => Icons.task_alt_rounded,
    ImportSection.worries => Icons.cloud_outlined,
    ImportSection.currencies => Icons.currency_exchange_rounded,
    ImportSection.wallets => Icons.account_balance_wallet_rounded,
    ImportSection.budgetItems => Icons.pie_chart_rounded,
    ImportSection.transactions => Icons.receipt_long_rounded,
    ImportSection.jars => Icons.savings_rounded,
    ImportSection.jarDeposits => Icons.add_card_rounded,
    ImportSection.debts => Icons.handshake_rounded,
    ImportSection.debtPayments => Icons.payments_rounded,
    ImportSection.obligations => Icons.event_repeat_rounded,
    ImportSection.people => Icons.people_alt_rounded,
    ImportSection.contactLogs => Icons.call_rounded,
    ImportSection.projects => Icons.folder_special_rounded,
    ImportSection.projectItems => Icons.checklist_rtl_rounded,
    ImportSection.boards => Icons.view_kanban_rounded,
    ImportSection.boardCards => Icons.sticky_note_2_rounded,
    ImportSection.trips => Icons.flight_takeoff_rounded,
    ImportSection.tripItems => Icons.luggage_rounded,
    ImportSection.travelDocuments => Icons.badge_rounded,
    ImportSection.learningGoals => Icons.school_rounded,
    ImportSection.goalLogs => Icons.trending_up_rounded,
    ImportSection.exercises => Icons.fitness_center_rounded,
    ImportSection.workoutLogs => Icons.directions_run_rounded,
    ImportSection.avoidItems => Icons.do_not_disturb_on_rounded,
    ImportSection.fastingSessions => Icons.nights_stay_rounded,
    ImportSection.waterLogs => Icons.water_drop_rounded,
    ImportSection.prayerLogs => Icons.mosque_rounded,
    ImportSection.tasks => Icons.checklist_rounded,
    ImportSection.customModules => Icons.widgets_rounded,
    ImportSection.customEntries => Icons.dataset_rounded,
  };

  /// The planet colour of the section.
  Color color(MadarTokens t) => PlanetPalettes.byKey[planetKey]?.surface ?? t.accent;
}

extension ImportIssuePresentation on ImportIssueCode {
  String label(L10n l) => switch (this) {
    ImportIssueCode.invalidJson => l.importIssueInvalidJson,
    ImportIssueCode.emptyInput => l.importIssueEmptyInput,
    ImportIssueCode.notAnObject => l.importIssueNotAnObject,
    ImportIssueCode.unparsedDate => l.importIssueUnparsedDate,
    ImportIssueCode.unparsedAmount => l.importIssueUnparsedAmount,
    ImportIssueCode.unparsedTime => l.importIssueUnparsedTime,
    ImportIssueCode.unparsedNumber => l.importIssueUnparsedNumber,
    ImportIssueCode.inferredTime => l.importIssueInferredTime,
    ImportIssueCode.missingRequired => l.importIssueMissingRequired,
    ImportIssueCode.unresolvedReference => l.importIssueUnresolvedReference,
    ImportIssueCode.createdReference => l.importIssueCreatedReference,
    ImportIssueCode.unknownValue => l.importIssueUnknownValue,
    ImportIssueCode.assumedGlasses => l.importIssueAssumedGlasses,
    ImportIssueCode.assumedFastingTarget => l.importIssueAssumedFastingTarget,
    ImportIssueCode.assumedDate => l.importIssueAssumedDate,
    ImportIssueCode.assumedValue => l.importIssueAssumedValue,
    ImportIssueCode.currencyWallet => l.importIssueCurrencyWallet,
    ImportIssueCode.missingRate => l.importIssueMissingRate,
    ImportIssueCode.duplicateSourceId => l.importIssueDuplicateSourceId,
    ImportIssueCode.budget => l.importIssueBudget,
    ImportIssueCode.duplicateFile => l.importIssueDuplicateFile,
    ImportIssueCode.settingRead => l.importIssueSettingRead,
  };

  /// Something the user should look at (rather than a note).
  bool get isWarning => switch (this) {
    ImportIssueCode.unparsedDate ||
    ImportIssueCode.unparsedAmount ||
    ImportIssueCode.unparsedTime ||
    ImportIssueCode.unparsedNumber ||
    ImportIssueCode.missingRequired ||
    ImportIssueCode.unresolvedReference ||
    ImportIssueCode.missingRate ||
    ImportIssueCode.duplicateSourceId ||
    ImportIssueCode.budget ||
    ImportIssueCode.duplicateFile ||
    ImportIssueCode.invalidJson ||
    ImportIssueCode.emptyInput ||
    ImportIssueCode.notAnObject => true,
    _ => false,
  };

  IconData get icon => isWarning ? Icons.error_outline_rounded : Icons.info_outline_rounded;
}

extension ImportShapePresentation on ImportShape {
  /// Short localised descriptions of the detected layout.
  List<String> labels(L10n l) => [
    switch (container) {
      ImportContainer.wrapped => l.importShapeWrapped,
      ImportContainer.dataOnly => l.importShapeDataOnly,
      ImportContainer.logsOnly => l.importShapeLogsOnly,
      ImportContainer.flat => l.importShapeFlat,
      ImportContainer.list => l.importShapeList,
    },
    ?switch (keyStyle) {
      ImportKeyStyle.arabic => l.importKeysArabic,
      ImportKeyStyle.camelCase => l.importKeysCamel,
      ImportKeyStyle.snakeCase => l.importKeysSnake,
      ImportKeyStyle.mixed => l.importKeysMixed,
      ImportKeyStyle.plain => null,
    },
    if (nestedByDomain) l.importShapeNested,
    if (dayKeyedLogs) l.importShapeDayKeyed,
    if (typedEventLists) l.importShapeTyped,
    if (idKeyedMaps) l.importShapeIdKeyed,
  ];
}

/// Locale- and digit-style-aware number / money / date formatting for the
/// import screens.
@immutable
class ImportFormats {
  const ImportFormats({required this.languageCode, required this.digits});

  final String languageCode;
  final DigitStyle digits;

  bool get arabic => languageCode == 'ar';

  bool get _indic => digits == DigitStyle.arabicIndic || (digits == DigitStyle.auto && arabic);

  MoneyDigits get _moneyDigits => switch (digits) {
    DigitStyle.auto => MoneyDigits.auto,
    DigitStyle.western => MoneyDigits.western,
    DigitStyle.arabicIndic => MoneyDigits.arabicIndic,
  };

  String digitsOf(String ascii) => _indic ? MoneyText.toArabicIndic(ascii) : ascii;

  /// A grouped integer (`1,234` / `١٬٢٣٤`).
  String count(int n) {
    final s = NumberFormat.decimalPattern('en').format(n);
    return _indic ? MoneyText.toArabicIndic(s.replaceAll(',', '٬')) : s;
  }

  String percent(double value) => digitsOf('${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1)}%');

  String money(int milli, String currency) =>
      Money(milli, currency).format(locale: languageCode, digits: _moneyDigits);

  String date(DateTime d) => digitsOf(DateFormat.yMMMMd(languageCode).format(d));

  /// One budget check as a sentence.
  String budgetIssue(L10n l, ImportIssue issue) {
    final a = issue.args;
    final name = a['name'] as String? ?? l.importBudgetWhole;
    final currency = a['currency'] as String? ?? 'JOD';
    final kind = BudgetWarningKind.values.where((k) => k.name == a['kind']).firstOrNull;
    final milli = a['milli'] as int?;
    final pct = a['percent'] as num?;
    return switch (kind) {
      BudgetWarningKind.childrenUnder => l.importBudgetChildrenUnder(name, money(milli ?? 0, currency)),
      BudgetWarningKind.childrenOver => l.importBudgetChildrenOver(name, money(milli ?? 0, currency)),
      BudgetWarningKind.percentOver100 => l.importBudgetPercentOver(name, percent((pct ?? 0).toDouble())),
      BudgetWarningKind.circularPercent => l.importBudgetCircular(name),
      BudgetWarningKind.missingRate => l.importBudgetMissingRate(currency),
      BudgetWarningKind.circularParent || BudgetWarningKind.orphanParent => l.importBudgetStructure(name),
      BudgetWarningKind.overspent || null => l.importIssueBudget,
    };
  }
}
