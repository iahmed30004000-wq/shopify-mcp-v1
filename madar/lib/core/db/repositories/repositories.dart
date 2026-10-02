import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../database.dart';
import 'activity_repository.dart';
import 'currency_repository.dart';
import 'entity_repository.dart';
import 'key_value_repository.dart';

export 'activity_repository.dart';
export 'currency_repository.dart';
export 'entity_repository.dart';
export 'key_value_repository.dart';

/// Typed repositories for every table of [MadarDatabase].
///
/// Every `Entity` table gets an [EntityRepository]; `key_values`,
/// `activity_log` (as an append-only stream) and `currencies` also get
/// dedicated repositories. [byTable] looks a repository up by SQL table name,
/// for generic actions on records referenced as `ownerTable`/`refTable`.
class Repositories {
  Repositories(this.db)
    : planets = EntityRepository(db, db.planets),
      reminders = EntityRepository(db, db.reminders),
      activityLog = EntityRepository(db, db.activityLog),
      tasks = EntityRepository(db, db.tasks),
      prayerLogs = EntityRepository(db, db.prayerLogs),
      importArchive = EntityRepository(db, db.importArchive),
      healthAlerts = EntityRepository(db, db.healthAlerts),
      conditions = EntityRepository(db, db.conditions),
      medications = EntityRepository(db, db.medications),
      medCourses = EntityRepository(db, db.medCourses),
      medRules = EntityRepository(db, db.medRules),
      medDoses = EntityRepository(db, db.medDoses),
      labTests = EntityRepository(db, db.labTests),
      labReadings = EntityRepository(db, db.labReadings),
      appointments = EntityRepository(db, db.appointments),
      doctorQuestions = EntityRepository(db, db.doctorQuestions),
      painEntries = EntityRepository(db, db.painEntries),
      moodEntries = EntityRepository(db, db.moodEntries),
      tagOptions = EntityRepository(db, db.tagOptions),
      habits = EntityRepository(db, db.habits),
      habitLogs = EntityRepository(db, db.habitLogs),
      worries = EntityRepository(db, db.worries),
      wallets = EntityRepository(db, db.wallets),
      budgetItems = EntityRepository(db, db.budgetItems),
      transactions = EntityRepository(db, db.transactions),
      jars = EntityRepository(db, db.jars),
      jarDeposits = EntityRepository(db, db.jarDeposits),
      debts = EntityRepository(db, db.debts),
      debtPayments = EntityRepository(db, db.debtPayments),
      obligations = EntityRepository(db, db.obligations),
      obligationPayments = EntityRepository(db, db.obligationPayments),
      people = EntityRepository(db, db.people),
      contactLogs = EntityRepository(db, db.contactLogs),
      projects = EntityRepository(db, db.projects),
      projectItems = EntityRepository(db, db.projectItems),
      boards = EntityRepository(db, db.boards),
      boardCards = EntityRepository(db, db.boardCards),
      trips = EntityRepository(db, db.trips),
      tripItems = EntityRepository(db, db.tripItems),
      packingTemplates = EntityRepository(db, db.packingTemplates),
      travelDocuments = EntityRepository(db, db.travelDocuments),
      learningGoals = EntityRepository(db, db.learningGoals),
      goalLogs = EntityRepository(db, db.goalLogs),
      exercises = EntityRepository(db, db.exercises),
      workoutLogs = EntityRepository(db, db.workoutLogs),
      avoidItems = EntityRepository(db, db.avoidItems),
      fastingSessions = EntityRepository(db, db.fastingSessions),
      waterLogs = EntityRepository(db, db.waterLogs),
      customModules = EntityRepository(db, db.customModules),
      customEntries = EntityRepository(db, db.customEntries),
      quranBookmarks = EntityRepository(db, db.quranBookmarks),
      quranSessions = EntityRepository(db, db.quranSessions),
      wirdPlans = EntityRepository(db, db.wirdPlans),
      hifzItems = EntityRepository(db, db.hifzItems),
      hifzReviews = EntityRepository(db, db.hifzReviews),
      keyValues = KeyValueRepository(db),
      activity = ActivityRepository(db),
      currencies = CurrencyRepository(db);

  final MadarDatabase db;

  // Core
  final EntityRepository<$PlanetsTable, PlanetRow> planets;
  final EntityRepository<$RemindersTable, ReminderRow> reminders;
  final EntityRepository<$ActivityLogTable, ActivityRow> activityLog;
  final EntityRepository<$TasksTable, TaskRow> tasks;
  final EntityRepository<$PrayerLogsTable, PrayerLogRow> prayerLogs;
  final EntityRepository<$ImportArchiveTable, ImportArchiveRow> importArchive;

  // Health
  final EntityRepository<$HealthAlertsTable, HealthAlertRow> healthAlerts;
  final EntityRepository<$ConditionsTable, ConditionRow> conditions;
  final EntityRepository<$MedicationsTable, MedicationRow> medications;
  final EntityRepository<$MedCoursesTable, MedCourseRow> medCourses;
  final EntityRepository<$MedRulesTable, MedRuleRow> medRules;
  final EntityRepository<$MedDosesTable, MedDoseRow> medDoses;
  final EntityRepository<$LabTestsTable, LabTestRow> labTests;
  final EntityRepository<$LabReadingsTable, LabReadingRow> labReadings;
  final EntityRepository<$AppointmentsTable, AppointmentRow> appointments;
  final EntityRepository<$DoctorQuestionsTable, DoctorQuestionRow> doctorQuestions;
  final EntityRepository<$PainEntriesTable, PainEntryRow> painEntries;
  final EntityRepository<$MoodEntriesTable, MoodEntryRow> moodEntries;
  final EntityRepository<$TagOptionsTable, TagOptionRow> tagOptions;
  final EntityRepository<$HabitsTable, HabitRow> habits;
  final EntityRepository<$HabitLogsTable, HabitLogRow> habitLogs;
  final EntityRepository<$WorriesTable, WorryRow> worries;

  // Money
  final EntityRepository<$WalletsTable, WalletRow> wallets;
  final EntityRepository<$BudgetItemsTable, BudgetItemRow> budgetItems;
  final EntityRepository<$TransactionsTable, TransactionRow> transactions;
  final EntityRepository<$JarsTable, JarRow> jars;
  final EntityRepository<$JarDepositsTable, JarDepositRow> jarDeposits;
  final EntityRepository<$DebtsTable, DebtRow> debts;
  final EntityRepository<$DebtPaymentsTable, DebtPaymentRow> debtPayments;
  final EntityRepository<$ObligationsTable, ObligationRow> obligations;
  final EntityRepository<$ObligationPaymentsTable, ObligationPaymentRow> obligationPayments;

  // Life
  final EntityRepository<$PeopleTable, PersonRow> people;
  final EntityRepository<$ContactLogsTable, ContactLogRow> contactLogs;
  final EntityRepository<$ProjectsTable, ProjectRow> projects;
  final EntityRepository<$ProjectItemsTable, ProjectItemRow> projectItems;
  final EntityRepository<$BoardsTable, BoardRow> boards;
  final EntityRepository<$BoardCardsTable, BoardCardRow> boardCards;
  final EntityRepository<$TripsTable, TripRow> trips;
  final EntityRepository<$TripItemsTable, TripItemRow> tripItems;
  final EntityRepository<$PackingTemplatesTable, PackingTemplateRow> packingTemplates;
  final EntityRepository<$TravelDocumentsTable, TravelDocumentRow> travelDocuments;
  final EntityRepository<$LearningGoalsTable, LearningGoalRow> learningGoals;
  final EntityRepository<$GoalLogsTable, GoalLogRow> goalLogs;
  final EntityRepository<$ExercisesTable, ExerciseRow> exercises;
  final EntityRepository<$WorkoutLogsTable, WorkoutLogRow> workoutLogs;
  final EntityRepository<$AvoidItemsTable, AvoidItemRow> avoidItems;
  final EntityRepository<$FastingSessionsTable, FastingSessionRow> fastingSessions;
  final EntityRepository<$WaterLogsTable, WaterLogRow> waterLogs;
  final EntityRepository<$CustomModulesTable, CustomModuleRow> customModules;
  final EntityRepository<$CustomEntriesTable, CustomEntryRow> customEntries;

  // Quran, wird, Hifz
  final EntityRepository<$QuranBookmarksTable, QuranBookmarkRow> quranBookmarks;
  final EntityRepository<$QuranSessionsTable, QuranSessionRow> quranSessions;
  final EntityRepository<$WirdPlansTable, WirdPlanRow> wirdPlans;
  final EntityRepository<$HifzItemsTable, HifzItemRow> hifzItems;
  final EntityRepository<$HifzReviewsTable, HifzReviewRow> hifzReviews;

  // Special-purpose
  final KeyValueRepository keyValues;
  final ActivityRepository activity;
  final CurrencyRepository currencies;

  /// Every entity repository, keyed by SQL table name (`tasks`,
  /// `board_cards` …).
  late final Map<String, EntityRepository<Table, DataClass>> byTable = {
    for (final r in <EntityRepository<Table, DataClass>>[
      planets,
      reminders,
      activityLog,
      tasks,
      prayerLogs,
      importArchive,
      healthAlerts,
      conditions,
      medications,
      medCourses,
      medRules,
      medDoses,
      labTests,
      labReadings,
      appointments,
      doctorQuestions,
      painEntries,
      moodEntries,
      tagOptions,
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
      obligationPayments,
      people,
      contactLogs,
      projects,
      projectItems,
      boards,
      boardCards,
      trips,
      tripItems,
      packingTemplates,
      travelDocuments,
      learningGoals,
      goalLogs,
      exercises,
      workoutLogs,
      avoidItems,
      fastingSessions,
      waterLogs,
      customModules,
      customEntries,
      quranBookmarks,
      quranSessions,
      wirdPlans,
      hifzItems,
      hifzReviews,
    ])
      r.tableName: r,
  };

  /// Repository for the SQL table [name], or null.
  EntityRepository<Table, DataClass>? forTable(String name) => byTable[name];
}

/// All repositories over the unlocked database.
final repositoriesProvider = Provider<Repositories>((ref) => Repositories(ref.watch(databaseProvider)));
