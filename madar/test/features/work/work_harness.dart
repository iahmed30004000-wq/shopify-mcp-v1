// Test harness for the Work screens: the real theme, localisations, digit
// scope, motion scope and celebration overlay (like the app frame), over an
// in-memory database, a silent sound engine, recording haptics and a frozen
// clock.
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/motion/motion_kit.dart';
import 'package:madar/core/providers.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/home/home_providers.dart';
import 'package:madar/features/work/work.dart';
import 'package:shared_preferences/shared_preferences.dart';


// Local copies of the shared test helpers, so these tests do not compile the
// whole app (and never break on another package's work in progress).

/// Records haptics fired through [Fx].
class RecordingHaptics implements HapticsService {
  final List<Haptic> fired = [];
  @override
  bool enabled = true;
  @override
  void fire(Haptic haptic) => fired.add(haptic);
}

/// Phone-sized test surface (logical 412×915).
void usePhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(412, 915) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

/// A seeded in-memory database whose streams close synchronously.
Future<MadarDatabase> openTestDatabase(WidgetTester tester, {String languageCode = 'ar'}) async {
  final db = MadarDatabase(
    DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    seed: SeedOptions(languageCode: languageCode),
  );
  await tester.runAsync(() => db.customSelect('SELECT 1').get());
  addTearDown(() => tester.runAsync(db.close));
  return db;
}

/// Tuesday 29 Sep 2026, 11:20 in Amman (the Duha window).
final DateTime workTestNow = DateTime(2026, 9, 29, 11, 20);
final DateTime workTestToday = DateTime(2026, 9, 29);

class WorkTestEnv {
  WorkTestEnv(this.db, this.haptics, this.sound, this.now);

  final MadarDatabase db;
  final RecordingHaptics haptics;
  final SilentSoundService sound;
  final DateTime now;
  late ProviderContainer container;

  Repositories get repos => Repositories(db);
  WorkService get service => WorkService(repos, clock: () => now);
}

Future<(Widget, WorkTestEnv)> buildWorkApp(
  WidgetTester tester, {
  required Widget home,
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('ar'),
  DateTime? now,
  bool reducedMotion = false,
  List<Override> overrides = const [],
  Future<void> Function(WorkTestEnv env)? beforePump,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
  final db = await openTestDatabase(tester, languageCode: locale.languageCode);
  final sound = SilentSoundService();
  final haptics = RecordingHaptics();
  Fx.install(FeedbackService(sound, haptics));
  final clock = now ?? workTestNow;
  final env = WorkTestEnv(db, haptics, sound, clock);
  if (beforePump != null) await tester.runAsync(() => beforePump(env));
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

Future<WorkTestEnv> pumpWorkApp(
  WidgetTester tester, {
  required Widget home,
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('ar'),
  DateTime? now,
  bool reducedMotion = false,
  Future<void> Function(WorkTestEnv env)? beforePump,
}) async {
  usePhoneSurface(tester);
  final (app, env) = await buildWorkApp(
    tester,
    home: home,
    theme: theme,
    locale: locale,
    now: now,
    reducedMotion: reducedMotion,
    beforePump: beforePump,
  );
  await tester.pumpWidget(app);
  await settleWork(tester);
  return env;
}

/// Lets database work (microtasks, stream hops) and finite animations finish.
Future<void> settleWork(WidgetTester tester, {int rounds = 6}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.pumpAndSettle();
}

/// Pumps frames without running an undo toast's countdown out.
Future<void> workFrames(WidgetTester tester, [int n = 20]) async {
  for (var i = 0; i < n; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 2)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

// ------------------------------------------------------------ seed data ----

/// Ids of the seeded scenario.
class WorkSeed {
  late BoardRow store, team;
  late List<BoardCardRow> cards;
  late ProjectRow project;
}

/// A store board with cards across To-do / Doing / Done (Top 3 flags, a
/// placed card, due and overdue dates, assignees), a second board, and a
/// project with a partly ticked checklist. Generic example content.
Future<WorkSeed> seedWork(WorkTestEnv env, {String lang = 'ar', bool top3AllDone = false, DateTime? at}) async {
  final ar = lang == 'ar';
  final s = WorkSeed();
  final w = WorkService(env.repos, clock: () => at ?? env.now);
  final today = workTestToday;
  DateTime day(int d) => today.add(Duration(days: d));
  s.store = await w.createBoard(name: ar ? 'متجر الأردن' : 'Jordan store', country: 'JO', color: 0xFF4F7BD9);
  s.team = await w.createBoard(name: ar ? 'فريق التوصيل' : 'Delivery team', country: 'EG', color: 0xFFD98E4F);
  final b = s.store.id;
  s.cards = [
    await w.addCard(
      b,
      CardDraft(
        title: ar ? 'تأكيد طلبات الدفع عند الاستلام' : 'Confirm cash-on-delivery orders',
        assignee: ar ? 'سارة' : 'Sara',
        dueDate: today,
        isTop3: true,
      ),
    ),
    await w.addCard(
      b,
      CardDraft(
        title: ar ? 'مراجعة إعلانات الأسبوع' : 'Review this week’s ads',
        notes: ar ? 'التركيز على المنتجات الأعلى مبيعًا' : 'Focus on the best sellers',
        dueDate: day(3),
      ),
    ),
    await w.addCard(
      b,
      CardDraft(title: ar ? 'تصوير المنتجات الجديدة' : 'Shoot the new products', assignee: ar ? 'ليلى' : 'Layla'),
    ),
    await w.addCard(
      b,
      CardDraft(
        title: ar ? 'متابعة شركة الشحن بخصوص المرتجعات' : 'Follow up returns with the courier',
        columnId: 'doing',
        assignee: ar ? 'عمر' : 'Omar',
        dueDate: day(-2),
        isTop3: true,
      ),
    ),
    await w.addCard(
      b,
      CardDraft(
        title: ar ? 'تحويل مستحقات المندوبين' : 'Pay the couriers',
        columnId: 'doing',
        window: PrayerWindow.dhuhr,
        windowDay: today,
        isTop3: true,
      ),
    ),
    await w.addCard(b, CardDraft(title: ar ? 'تحديث أسعار الشحن' : 'Update shipping rates', columnId: 'done')),
    await w.addCard(
      b,
      CardDraft(title: ar ? 'الرد على رسائل العملاء' : 'Answer customer messages', columnId: 'done', assignee: ar ? 'سارة' : 'Sara'),
    ),
  ];
  await w.addCard(s.team.id, CardDraft(title: ar ? 'جدولة جولات الغد' : 'Schedule tomorrow’s rounds', dueDate: day(1)));
  await w.createBoard(name: ar ? 'متجر ليبيا' : 'Libya store', country: 'LY', color: 0xFF5FB58A);
  if (top3AllDone) {
    for (final c in [s.cards[0], s.cards[3], s.cards[4]]) {
      await w.moveCard(c.id, 'done');
    }
  }
  s.project = await w.createProject(
    ProjectDraft(
      name: ar ? 'إطلاق متجر جديد' : 'Launch a new store',
      description: ar ? 'تجهيز المتجر والشحن والإعلانات قبل الإطلاق.' : 'Store, shipping and ads ready before launch.',
      deadline: day(12),
      color: 0xFF8E6FD9,
    ),
  );
  final steps = ar
      ? ['تسجيل النطاق', 'رفع المنتجات والصور', 'الاتفاق مع شركة الشحن', 'حملة الإطلاق', 'تدريب فريق خدمة العملاء']
      : ['Register the domain', 'Upload products and photos', 'Sign the courier', 'Launch campaign', 'Train customer service'];
  final items = [
    for (final (i, body) in steps.indexed) await w.addItem(s.project.id, body, dueDate: i == 3 ? day(9) : null),
  ];
  await w.toggleItem(items[0]);
  await w.toggleItem(items[1]);
  await w.addProjectTask(s.project, title: ar ? 'مكالمة مع المصمم' : 'Call the designer', window: PrayerWindow.asr, date: today);
  await w.createProject(ProjectDraft(name: ar ? 'دليل الموظفين' : 'Staff handbook', deadline: day(-3)));
  return s;
}
