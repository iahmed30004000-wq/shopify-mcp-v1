import 'package:meta/meta.dart';

import '../../../core/db/database.dart';
import '../../health/record/domain/lab_flags.dart';

/// Location and time zone the user set for prayer times (read from the
/// `prayer.settings` key; every field optional).
@immutable
class SummaryPlace {
  const SummaryPlace({this.cityAr, this.cityEn, this.city, this.countryCode, this.timeZone});

  final String? cityAr;
  final String? cityEn;
  final String? city;
  final String? countryCode;
  final String? timeZone;

  /// The city name in [languageCode], falling back to the other names.
  String? cityFor(String languageCode) => (languageCode == 'ar' ? (cityAr ?? cityEn) : (cityEn ?? cityAr)) ?? city;

  static SummaryPlace fromJson(Object? json) {
    if (json is! Map) return const SummaryPlace();
    String? s(String k) {
      final v = json[k];
      return v is String && v.trim().isNotEmpty ? v.trim() : null;
    }

    return SummaryPlace(
      cityAr: s('cityNameAr'),
      cityEn: s('cityNameEn'),
      city: s('cityName'),
      countryCode: s('countryCode'),
      timeZone: s('timeZone'),
    );
  }
}

/// Everything the summary builder reads, loaded in one go from the database
/// (see `DataExportRepository.loadSummaryInput`). Lists default to empty so
/// tests can fill only what they exercise.
@immutable
class SummaryInput {
  const SummaryInput({
    required this.now,
    this.place = const SummaryPlace(),
    // Faith
    this.prayerLogs = const [],
    this.quranSessions = const [],
    this.wirdPlans = const [],
    this.hifzItems = const [],
    this.hifzReviews = const [],
    // Health
    this.healthAlerts = const [],
    this.conditions = const [],
    this.medications = const [],
    this.labTests = const [],
    this.labReadings = const [],
    this.painEntries = const [],
    this.moodEntries = const [],
    this.labMargin = LabFlags.defaultMargin,
    // Money
    this.currencies = const [],
    this.wallets = const [],
    this.transactions = const [],
    this.budgetItems = const [],
    this.weeksPerMonth = 4,
    this.jars = const [],
    this.jarDeposits = const [],
    this.debts = const [],
    this.debtPayments = const [],
    this.obligations = const [],
    // Family
    this.people = const [],
    this.contactLogs = const [],
    // Work
    this.tasks = const [],
    this.boards = const [],
    this.boardCards = const [],
    this.archivedBoardIds = const {},
    this.projects = const [],
    this.projectItems = const [],
    // Growth
    this.learningGoals = const [],
    this.goalLogs = const [],
    // Body
    this.exercises = const [],
    this.workoutLogs = const [],
    this.fastingSessions = const [],
    this.waterLogs = const [],
    this.waterTargetMl,
    this.avoidItems = const [],
    this.foods = const [],
    this.foodLogs = const [],
    this.mealPlans = const [],
    this.mealSlots = const [],
    this.mealSlotFoods = const [],
    this.foodRules = const [],
    // Travel
    this.trips = const [],
    this.travelDocuments = const [],
    // Custom
    this.customModules = const [],
    this.customEntries = const [],
  });

  /// The moment the summary describes (windows end today).
  final DateTime now;
  final SummaryPlace place;

  final List<PrayerLogRow> prayerLogs;
  final List<QuranSessionRow> quranSessions;
  final List<WirdPlanRow> wirdPlans;
  final List<HifzItemRow> hifzItems;
  final List<HifzReviewRow> hifzReviews;

  final List<HealthAlertRow> healthAlerts;
  final List<ConditionRow> conditions;
  final List<MedicationRow> medications;
  final List<LabTestRow> labTests;
  final List<LabReadingRow> labReadings;
  final List<PainEntryRow> painEntries;
  final List<MoodEntryRow> moodEntries;

  /// Borderline margin for lab flags (the user's Health setting).
  final double labMargin;

  final List<CurrencyRow> currencies;
  final List<WalletRow> wallets;
  final List<TransactionRow> transactions;
  final List<BudgetItemRow> budgetItems;
  final num weeksPerMonth;
  final List<JarRow> jars;
  final List<JarDepositRow> jarDeposits;
  final List<DebtRow> debts;
  final List<DebtPaymentRow> debtPayments;
  final List<ObligationRow> obligations;

  final List<PersonRow> people;
  final List<ContactLogRow> contactLogs;

  final List<TaskRow> tasks;
  final List<BoardRow> boards;
  final List<BoardCardRow> boardCards;
  final Set<String> archivedBoardIds;
  final List<ProjectRow> projects;
  final List<ProjectItemRow> projectItems;

  final List<LearningGoalRow> learningGoals;
  final List<GoalLogRow> goalLogs;

  final List<ExerciseRow> exercises;
  final List<WorkoutLogRow> workoutLogs;
  final List<FastingSessionRow> fastingSessions;
  final List<WaterLogRow> waterLogs;
  final int? waterTargetMl;
  final List<AvoidItemRow> avoidItems;

  /// His food library, his log of what he ate, his meal plans and their
  /// meals, and the risk rules he wrote himself (schema v3).
  final List<FoodRow> foods;
  final List<FoodLogRow> foodLogs;
  final List<MealPlanRow> mealPlans;
  final List<MealSlotRow> mealSlots;
  final List<MealSlotFoodRow> mealSlotFoods;
  final List<FoodRuleRow> foodRules;

  final List<TripRow> trips;
  final List<TravelDocumentRow> travelDocuments;

  final List<CustomModuleRow> customModules;
  final List<CustomEntryRow> customEntries;
}
