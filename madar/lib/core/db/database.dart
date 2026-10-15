import 'package:drift/drift.dart';

import 'indexes.dart';
import 'seed/seeder.dart';
import 'tables/converters.dart';
import 'tables/core_tables.dart';
import 'tables/faith_tables.dart';
import 'tables/health_tables.dart';
import 'tables/kitchen_tables.dart';
import 'tables/life_tables.dart';
import 'tables/list_tables.dart';
import 'tables/money_tables.dart';
import 'tables/plan_tables.dart';
import 'tables/tasmee_tables.dart';
import '../domain/enums.dart';

export 'seed/seeder.dart' show SeedOptions;
export 'tables/converters.dart' show newId;

part 'database.g.dart';

@DriftDatabase(tables: [
  Planets, KeyValues, Reminders, ActivityLog, Tasks, PrayerLogs, ImportArchive,
  HealthAlerts, Conditions, Medications, MedCourses, MedRules, MedDoses,
  LabTests, LabReadings, Appointments, DoctorQuestions, PainEntries,
  MoodEntries, TagOptions, Habits, HabitLogs, Worries,
  Foods, FoodLogs, MealPlans, MealSlots, MealSlotFoods, FoodRules,
  Currencies, Wallets, BudgetItems, Transactions, Jars, JarDeposits, Debts,
  DebtPayments, Obligations, ObligationPayments,
  People, ContactLogs, Projects, ProjectItems, Boards, BoardCards, Trips,
  TripItems, PackingTemplates, TravelDocuments, LearningGoals, GoalLogs,
  Exercises, WorkoutLogs, AvoidItems, FastingSessions, WaterLogs,
  CustomModules, CustomEntries,
  QuranBookmarks, QuranSessions, WirdPlans, HifzItems, HifzReviews,
  AppliedPlans, AppliedPlanItems,
  RecordLists, RecordListItems,
  PantryItems, Recipes, RecipeIngredients, CookedMeals, KitchenRules,
  TasmeeSessions, TasmeeAyat, TasmeeMistakes,
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
  int get schemaVersion => 7;

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
          // v3: the food library, the food log, the meal plan and the
          // user's own food rules, plus a colour on his conditions.
          if (from < 3) {
            await m.createTable(foods);
            await m.createTable(foodLogs);
            await m.createTable(mealPlans);
            await m.createTable(mealSlots);
            await m.createTable(mealSlotFoods);
            await m.createTable(foodRules);
            await m.addColumn(conditions, conditions.color);
          }
          // v4: the AI bridge's history – imported plans and the decision
          // he made on every suggestion in them.
          if (from < 4) {
            await m.createTable(appliedPlans);
            await m.createTable(appliedPlanItems);
          }
          // v5: the shared list engine – a tick list on any record (a
          // budget envelope's shopping list, a trip's list, the pantry).
          if (from < 5) {
            await m.createTable(recordLists);
            await m.createTable(recordListItems);
          }
          // v6: «السفرة» – the pantry, her recipes with their ingredients,
          // the cooked log the no-repeat window reads, and her own
          // constraints. Nothing of ours is written: a fresh install is
          // empty and she fills it.
          if (from < 6) {
            await m.createTable(pantryItems);
            await m.createTable(recipes);
            await m.createTable(recipeIngredients);
            await m.createTable(cookedMeals);
            await m.createTable(kitchenRules);
          }
          // v7: «التسميع» – the recitation log Part 13 writes and Part 14
          // reads: one row per session, one per ayah of it, one per word
          // that went wrong. Nothing of ours is written and no audio is
          // stored: a fresh install is empty until he recites.
          if (from < 7) {
            await m.createTable(tasmeeSessions);
            await m.createTable(tasmeeAyat);
            await m.createTable(tasmeeMistakes);
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
