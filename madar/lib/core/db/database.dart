import 'package:drift/drift.dart';

import 'tables/converters.dart';
import 'tables/core_tables.dart';
import 'tables/health_tables.dart';
import 'tables/life_tables.dart';
import 'tables/money_tables.dart';
import '../domain/enums.dart';

export 'tables/converters.dart' show newId;

part 'database.g.dart';

@DriftDatabase(tables: [
  Planets, KeyValues, Reminders, ActivityLog, Tasks, PrayerLogs, ImportArchive,
  HealthAlerts, Conditions, Medications, MedCourses, MedRules, MedDoses,
  LabTests, LabReadings, Appointments, DoctorQuestions, PainEntries,
  MoodEntries, TagOptions, Habits, HabitLogs, Worries,
  Currencies, Wallets, BudgetItems, Transactions, Jars, JarDeposits, Debts,
  DebtPayments, Obligations, ObligationPayments,
  People, ContactLogs, Projects, ProjectItems, Boards, BoardCards, Trips,
  TripItems, PackingTemplates, TravelDocuments, LearningGoals, GoalLogs,
  Exercises, WorkoutLogs, AvoidItems, FastingSessions, WaterLogs,
  CustomModules, CustomEntries,
])
class MadarDatabase extends _$MadarDatabase {
  MadarDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
