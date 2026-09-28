import 'package:drift/drift.dart';

import 'indexes.dart';
import 'seed/seeder.dart';
import 'tables/converters.dart';
import 'tables/core_tables.dart';
import 'tables/faith_tables.dart';
import 'tables/health_tables.dart';
import 'tables/life_tables.dart';
import 'tables/money_tables.dart';
import '../domain/enums.dart';

export 'seed/seeder.dart' show SeedOptions;
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
  QuranBookmarks, QuranSessions, WirdPlans, HifzItems, HifzReviews,
])
class MadarDatabase extends _$MadarDatabase {
  /// Wraps an executor. Pass [seed] to seed the generic defaults (planets,
  /// currencies, tag options, habits) once, when the database is first opened.
  /// Without [seed] the database starts empty (the default for unit tests);
  /// `openMadarDatabase` / `openInMemoryMadarDatabase` seed by default.
  MadarDatabase(super.e, {this.seed});

  /// Seeding configuration, or null to never seed.
  final SeedOptions? seed;

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          // v2: Quran bookmarks + sessions, daily wird plans, Hifz.
          if (from < 2) {
            await m.createTable(quranBookmarks);
            await m.createTable(quranSessions);
            await m.createTable(wirdPlans);
            await m.createTable(hifzItems);
            await m.createTable(hifzReviews);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          for (final statement in madarIndexStatements) {
            await customStatement(statement);
          }
          final seed = this.seed;
          if (seed != null) {
            await MadarSeeder(this, options: seed).seedIfNeeded();
          }
        },
      );
}
