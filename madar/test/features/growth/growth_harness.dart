// Test harness for the Growth planet: the real theme, localisations, digit
// scope, motion scope and celebration overlay (like AppFrame), over a
// seeded in-memory database, a silent sound engine, recording haptics and
// a frozen clock.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/motion/motion_kit.dart';
import 'package:madar/core/providers.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/growth/growth.dart';
import 'package:madar/features/home/home_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_app.dart';

/// Monday 28 Sep 2026, 17:10 in Amman.
final DateTime growthTestNow = DateTime(2026, 9, 28, 17, 10);

/// Everything a test needs after pumping.
class GrowthTestEnv {
  GrowthTestEnv(this.db, this.haptics, this.sound);

  final MadarDatabase db;
  final RecordingHaptics haptics;
  final SilentSoundService sound;
  late ProviderContainer container;

  Repositories get repos => Repositories(db);
}

/// Builds the harness app around [home].
Future<(Widget, GrowthTestEnv)> buildGrowthApp(
  WidgetTester tester, {
  required Widget home,
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('ar'),
  DateTime? now,
  bool reducedMotion = false,
  List<Override> overrides = const [],
  Future<void> Function(MadarDatabase db)? beforePump,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
  final db = await openTestDatabase(tester, languageCode: locale.languageCode);
  if (beforePump != null) await tester.runAsync(() => beforePump(db));
  final sound = SilentSoundService();
  final haptics = RecordingHaptics();
  Fx.install(FeedbackService(sound, haptics));
  final clock = now ?? growthTestNow;
  final env = GrowthTestEnv(db, haptics, sound);
  final arabic = locale.languageCode == 'ar';
  final app = ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      soundServiceProvider.overrideWithValue(sound),
      hapticsServiceProvider.overrideWithValue(haptics),
      databaseProvider.overrideWithValue(db),
      homeClockProvider.overrideWithValue(() => clock),
      ...overrides,
    ],
    child: Consumer(
      builder: (context, ref, _) {
        env.container = ProviderScope.containerOf(context);
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildMadarTheme(theme, arabic: arabic),
          locale: locale,
          supportedLocales: L10n.supportedLocales,
          localizationsDelegates: L10n.localizationsDelegates,
          builder: (context, child) => MadarFormatScope(
            digits: DigitStyle.auto,
            child: MotionScope(
              reduced: reducedMotion,
              child: CelebrationOverlay(child: child!),
            ),
          ),
          home: home,
        );
      },
    ),
  );
  return (app, env);
}

/// [buildGrowthApp] + pump on a phone-sized surface.
Future<GrowthTestEnv> pumpGrowthApp(
  WidgetTester tester, {
  required Widget home,
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('ar'),
  DateTime? now,
  bool reducedMotion = false,
  List<Override> overrides = const [],
  Future<void> Function(MadarDatabase db)? beforePump,
}) async {
  usePhoneSurface(tester);
  final (app, env) = await buildGrowthApp(
    tester,
    home: home,
    theme: theme,
    locale: locale,
    now: now,
    reducedMotion: reducedMotion,
    overrides: overrides,
    beforePump: beforePump,
  );
  await tester.pumpWidget(app);
  await settleGrowth(tester);
  return env;
}

/// Lets database work (microtasks, stream hops) and finite animations finish.
Future<void> settleGrowth(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.pumpAndSettle();
}

// ------------------------------------------------------------ seed data ----

/// Adds a goal created at [created].
Future<LearningGoalRow> seedGoal(MadarDatabase db, GoalDraft draft, {required DateTime created}) async {
  final (row, _) = await GrowthService(Repositories(db), clock: () => created).createGoal(draft);
  return row;
}

/// Logs [amount] on [goal] at [at].
Future<GoalLogRow> seedLog(MadarDatabase db, LearningGoalRow goal, double amount, DateTime at, {String? note}) async {
  final (row, _) = await GrowthService(Repositories(db), clock: () => at).addLog(goal.id, amount, at: at, note: note);
  return row;
}

DateTime _d(int offset, [int hour = 21, int minute = 0]) =>
    DateTime(growthTestNow.year, growthTestNow.month, growthTestNow.day + offset, hour, minute);

/// Ids of the scenario's goals.
class GrowthScenario {
  GrowthScenario(this.book, this.course, this.words, this.coding, this.done, this.paused);

  final LearningGoalRow book;
  final LearningGoalRow course;
  final LearningGoalRow words;
  final LearningGoalRow coding;
  final LearningGoalRow done;
  final LearningGoalRow paused;
}

/// A book (pages, behind), a course (lessons, ahead), vocabulary (words, no
/// deadline), coding practice (hours, overdue), a finished book and a
/// paused language course.
Future<GrowthScenario> seedScenario(MadarDatabase db, {String lang = 'ar'}) async {
  final ar = lang == 'ar';
  final book = await seedGoal(
    db,
    GoalDraft(
      name: ar ? 'قراءة «العادات الذرية»' : 'Read “Atomic Habits”',
      unit: 'pages',
      target: 320,
      initial: 40,
      deadline: DateTime(2026, 10, 25),
    ),
    created: _d(-18, 9),
  );
  final course = await seedGoal(
    db,
    GoalDraft(
      name: ar ? 'دورة تحليل البيانات' : 'Data analysis course',
      unit: 'lessons',
      target: 24,
      deadline: DateTime(2026, 11, 20),
      color: PlanetPalettes.health.surface.toARGB32(),
    ),
    created: _d(-12, 9),
  );
  final words = await seedGoal(
    db,
    GoalDraft(
      name: ar ? 'مفردات إنجليزية' : 'English vocabulary',
      unit: 'words',
      target: 1000,
      color: PlanetPalettes.travel.surface.toARGB32(),
    ),
    created: _d(-20, 9),
  );
  final coding = await seedGoal(
    db,
    GoalDraft(
      name: ar ? 'تدريب على البرمجة' : 'Coding practice',
      unit: 'hours',
      target: 40,
      deadline: DateTime(2026, 9, 25),
      color: PlanetPalettes.body.surface.toARGB32(),
    ),
    created: _d(-30, 9),
  );
  final done = await seedGoal(
    db,
    GoalDraft(
      name: ar ? 'كتاب في التسويق' : 'A marketing book',
      unit: 'pages',
      target: 180,
      color: PlanetPalettes.faith.surface.toARGB32(),
    ),
    created: _d(-26, 9),
  );
  final paused = await seedGoal(
    db,
    GoalDraft(
      name: ar ? 'تعلّم التركية' : 'Learn Turkish',
      unit: 'lessons',
      target: 60,
      color: PlanetPalettes.family.surface.toARGB32(),
      active: false,
    ),
    created: _d(-25, 9),
  );

  // The book: 6–14 pages most evenings, today after Asr.
  const bookPages = [12, 8, 0, 10, 14, 6, 0, 9, 11, 8, 0, 7, 10, 12, 0, 9, 8, 14];
  for (var i = 0; i < bookPages.length; i++) {
    if (bookPages[i] > 0) await seedLog(db, book, bookPages[i].toDouble(), _d(-18 + i, 22, 10));
  }
  await seedLog(db, book, 10, _d(0, 16, 40), note: ar ? 'فصل عن تكديس العادات' : 'Chapter on habit stacking');
  // The course: two lessons most days.
  for (final (off, n) in [(-11, 2), (-9, 1), (-8, 2), (-6, 1), (-4, 2), (-3, 1), (-1, 2), (0, 1)]) {
    await seedLog(db, course, n.toDouble(), _d(off, 6, 30));
  }
  // Vocabulary: 15–30 words a day.
  for (var i = -19; i <= -1; i++) {
    await seedLog(db, words, (15 + (i * 7).abs() % 16).toDouble(), _d(i, 20, 15));
  }
  // Coding: 32.5 hours before the deadline passed.
  for (var i = -29; i <= -4; i += 2) {
    await seedLog(db, coding, 2.5, _d(i, 23));
  }
  // The finished book, completed a week ago.
  for (final (off, n) in [(-25, 40), (-22, 45), (-18, 50), (-14, 30), (-7, 25)]) {
    await seedLog(db, done, n.toDouble(), _d(off, 21, 30));
  }
  // Turkish: twelve lessons, then paused.
  for (var i = -24; i <= -13; i++) {
    await seedLog(db, paused, 1, _d(i, 7));
  }
  return GrowthScenario(book, course, words, coding, done, paused);
}
