/// The planned rows of an import, one typed batch per Drift table, in the
/// order `commit` writes them (referenced tables first).
library;

import 'package:drift/drift.dart' show Table;

import '../db/database.dart';
import 'import_aliases.dart';
import 'import_models.dart';

class ImportRows {
  final healthAlerts = ImportTableRows<$HealthAlertsTable, HealthAlertRow>(ImportSection.healthAlerts, (db) => db.healthAlerts);
  final conditions = ImportTableRows<$ConditionsTable, ConditionRow>(ImportSection.conditions, (db) => db.conditions);
  final medications = ImportTableRows<$MedicationsTable, MedicationRow>(ImportSection.medications, (db) => db.medications);
  final medDoses = ImportTableRows<$MedDosesTable, MedDoseRow>(ImportSection.medDoses, (db) => db.medDoses);
  final labTests = ImportTableRows<$LabTestsTable, LabTestRow>(ImportSection.labTests, (db) => db.labTests);
  final labReadings = ImportTableRows<$LabReadingsTable, LabReadingRow>(ImportSection.labReadings, (db) => db.labReadings);
  final appointments = ImportTableRows<$AppointmentsTable, AppointmentRow>(ImportSection.appointments, (db) => db.appointments);
  final doctorQuestions = ImportTableRows<$DoctorQuestionsTable, DoctorQuestionRow>(
    ImportSection.doctorQuestions,
    (db) => db.doctorQuestions,
  );
  final painEntries = ImportTableRows<$PainEntriesTable, PainEntryRow>(ImportSection.painEntries, (db) => db.painEntries);
  final moodEntries = ImportTableRows<$MoodEntriesTable, MoodEntryRow>(ImportSection.moodEntries, (db) => db.moodEntries);
  final habits = ImportTableRows<$HabitsTable, HabitRow>(ImportSection.habits, (db) => db.habits);
  final habitLogs = ImportTableRows<$HabitLogsTable, HabitLogRow>(ImportSection.habitLogs, (db) => db.habitLogs);
  final worries = ImportTableRows<$WorriesTable, WorryRow>(ImportSection.worries, (db) => db.worries);
  final currencies = ImportTableRows<$CurrenciesTable, CurrencyRow>(ImportSection.currencies, (db) => db.currencies);
  final wallets = ImportTableRows<$WalletsTable, WalletRow>(ImportSection.wallets, (db) => db.wallets);
  final budgetItems = ImportTableRows<$BudgetItemsTable, BudgetItemRow>(ImportSection.budgetItems, (db) => db.budgetItems);
  final transactions = ImportTableRows<$TransactionsTable, TransactionRow>(ImportSection.transactions, (db) => db.transactions);
  final jars = ImportTableRows<$JarsTable, JarRow>(ImportSection.jars, (db) => db.jars);
  final jarDeposits = ImportTableRows<$JarDepositsTable, JarDepositRow>(ImportSection.jarDeposits, (db) => db.jarDeposits);
  final debts = ImportTableRows<$DebtsTable, DebtRow>(ImportSection.debts, (db) => db.debts);
  final debtPayments = ImportTableRows<$DebtPaymentsTable, DebtPaymentRow>(ImportSection.debtPayments, (db) => db.debtPayments);
  final obligations = ImportTableRows<$ObligationsTable, ObligationRow>(ImportSection.obligations, (db) => db.obligations);
  final people = ImportTableRows<$PeopleTable, PersonRow>(ImportSection.people, (db) => db.people);
  final contactLogs = ImportTableRows<$ContactLogsTable, ContactLogRow>(ImportSection.contactLogs, (db) => db.contactLogs);
  final projects = ImportTableRows<$ProjectsTable, ProjectRow>(ImportSection.projects, (db) => db.projects);
  final projectItems = ImportTableRows<$ProjectItemsTable, ProjectItemRow>(ImportSection.projectItems, (db) => db.projectItems);
  final boards = ImportTableRows<$BoardsTable, BoardRow>(ImportSection.boards, (db) => db.boards);
  final boardCards = ImportTableRows<$BoardCardsTable, BoardCardRow>(ImportSection.boardCards, (db) => db.boardCards);
  final trips = ImportTableRows<$TripsTable, TripRow>(ImportSection.trips, (db) => db.trips);
  final tripItems = ImportTableRows<$TripItemsTable, TripItemRow>(ImportSection.tripItems, (db) => db.tripItems);
  final travelDocuments = ImportTableRows<$TravelDocumentsTable, TravelDocumentRow>(
    ImportSection.travelDocuments,
    (db) => db.travelDocuments,
  );
  final learningGoals = ImportTableRows<$LearningGoalsTable, LearningGoalRow>(
    ImportSection.learningGoals,
    (db) => db.learningGoals,
  );
  final goalLogs = ImportTableRows<$GoalLogsTable, GoalLogRow>(ImportSection.goalLogs, (db) => db.goalLogs);
  final exercises = ImportTableRows<$ExercisesTable, ExerciseRow>(ImportSection.exercises, (db) => db.exercises);
  final workoutLogs = ImportTableRows<$WorkoutLogsTable, WorkoutLogRow>(ImportSection.workoutLogs, (db) => db.workoutLogs);
  final avoidItems = ImportTableRows<$AvoidItemsTable, AvoidItemRow>(ImportSection.avoidItems, (db) => db.avoidItems);
  final fastingSessions = ImportTableRows<$FastingSessionsTable, FastingSessionRow>(
    ImportSection.fastingSessions,
    (db) => db.fastingSessions,
  );
  final waterLogs = ImportTableRows<$WaterLogsTable, WaterLogRow>(ImportSection.waterLogs, (db) => db.waterLogs);
  final prayerLogs = ImportTableRows<$PrayerLogsTable, PrayerLogRow>(ImportSection.prayerLogs, (db) => db.prayerLogs);
  final tasks = ImportTableRows<$TasksTable, TaskRow>(ImportSection.tasks, (db) => db.tasks);
  final customModules = ImportTableRows<$CustomModulesTable, CustomModuleRow>(
    ImportSection.customModules,
    (db) => db.customModules,
  );
  final customEntries = ImportTableRows<$CustomEntriesTable, CustomEntryRow>(
    ImportSection.customEntries,
    (db) => db.customEntries,
  );

  /// Every batch, in write order.
  late final List<ImportTableRows<Table, Object?>> all = [
    currencies,
    healthAlerts,
    conditions,
    medications,
    medDoses,
    labTests,
    labReadings,
    appointments,
    doctorQuestions,
    painEntries,
    moodEntries,
    habits,
    habitLogs,
    worries,
    wallets,
    budgetItems,
    transactions,
    jars,
    jarDeposits,
    debts,
    debtPayments,
    obligations,
    people,
    contactLogs,
    projects,
    projectItems,
    boards,
    boardCards,
    trips,
    tripItems,
    travelDocuments,
    learningGoals,
    goalLogs,
    exercises,
    workoutLogs,
    avoidItems,
    fastingSessions,
    waterLogs,
    prayerLogs,
    tasks,
    customModules,
    customEntries,
  ];

  /// Rows planned for [section].
  int count(ImportSection section) => all.firstWhere((t) => t.section == section).rows.length;

  int get total => all.fold(0, (a, t) => a + t.rows.length);
}
