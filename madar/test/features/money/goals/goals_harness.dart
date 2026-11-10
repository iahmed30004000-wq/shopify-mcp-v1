// Test harness for the goals package: the real theme, localisations, digit
// scope, motion scope and celebration overlay over an in-memory seeded
// database, silent sound, recording haptics, a frozen clock, a fake
// notification platform and a recording due-reminder scheduler.
import 'package:drift/drift.dart' show Value;
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
import 'package:madar/core/notifications/fake_notification_platform.dart';
import 'package:madar/core/notifications/notification_providers.dart';
import 'package:madar/core/notifications/notification_service.dart';
import 'package:madar/core/providers.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/home/home_providers.dart';
import 'package:madar/features/money/goals/goals.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/test_app.dart';

/// Tuesday 29 Sep 2026, 20:15.
final DateTime goalsTestNow = DateTime(2026, 9, 29, 20, 15);

class GoalsTestEnv {
  GoalsTestEnv(this.db, this.haptics, this.sound);

  final MadarDatabase db;
  final RecordingHaptics haptics;
  final SilentSoundService sound;
  final FakeNotificationPlatform notifications = FakeNotificationPlatform();
  final RecordingGoalsReminderScheduler reminders = RecordingGoalsReminderScheduler();
  late ProviderContainer container;

  Repositories get repos => Repositories(db);
}

Future<(Widget, GoalsTestEnv)> buildGoalsApp(
  WidgetTester tester, {
  required Widget home,
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('ar'),
  DateTime? now,
  bool reducedMotion = false,
  bool seed = true,
  List<Override> overrides = const [],
  Future<void> Function(MadarDatabase db)? beforePump,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
  final db = await openTestDatabase(tester, languageCode: locale.languageCode);
  // Unmount the app (cancelling its database streams) before the database
  // closes – tear-downs run last-in, first-out.
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  final clock = now ?? goalsTestNow;
  if (seed) await tester.runAsync(() => seedGoals(db, arabic: locale.languageCode == 'ar', now: clock));
  if (beforePump != null) await tester.runAsync(() => beforePump(db));
  final sound = SilentSoundService();
  final haptics = RecordingHaptics();
  Fx.install(FeedbackService(sound, haptics));
  final env = GoalsTestEnv(db, haptics, sound);
  final arabic = locale.languageCode == 'ar';
  final app = ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      soundServiceProvider.overrideWithValue(sound),
      hapticsServiceProvider.overrideWithValue(haptics),
      databaseProvider.overrideWithValue(db),
      homeClockProvider.overrideWithValue(() => clock),
      notificationPlatformProvider.overrideWithValue(env.notifications),
      // The notification service drops requests in its past: give it the
      // frozen test clock, not the wall clock (else the plan depends on the
      // day the test runs).
      notificationServiceProvider.overrideWith((ref) {
        final service = NotificationService(env.notifications, clock: () => clock);
        ref.onDispose(service.dispose);
        return service;
      }),
      goalsReminderSchedulerProvider.overrideWithValue(env.reminders),
      appSettingsProvider.overrideWith(() => _FixedSettings(AppSettings(languageCode: locale.languageCode))),
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

class _FixedSettings extends AppSettingsController {
  _FixedSettings(this.initial);

  final AppSettings initial;

  @override
  AppSettings build() => initial;
}

/// [buildGoalsApp] + pump on a phone-sized surface.
Future<GoalsTestEnv> pumpGoalsApp(
  WidgetTester tester, {
  required Widget home,
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('ar'),
  DateTime? now,
  bool seed = true,
  bool reducedMotion = false,
  List<Override> overrides = const [],
  Future<void> Function(MadarDatabase db)? beforePump,
}) async {
  usePhoneSurface(tester);
  final (app, env) = await buildGoalsApp(
    tester,
    home: home,
    theme: theme,
    locale: locale,
    now: now,
    seed: seed,
    reducedMotion: reducedMotion,
    overrides: overrides,
    beforePump: beforePump,
  );
  await tester.pumpWidget(app);
  await settleGoals(tester);
  return env;
}

/// Lets database work (microtasks, stream hops) and finite animations finish.
Future<void> settleGoals(WidgetTester tester, {bool andSettle = true}) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await tester.pump(const Duration(milliseconds: 16));
  }
  if (andSettle) await tester.pumpAndSettle();
}

/// Runs real async work (database writes) from a test.
Future<T> dbWork<T>(WidgetTester tester, Future<T> Function() work) async {
  final result = await tester.runAsync(work);
  await settleGoals(tester);
  return result as T;
}

/// Ids of the seeded rows.
abstract final class GoalsSeedIds {
  static const walletCash = 'w.cash';
  static const walletBank = 'w.bank';
  static const walletUsd = 'w.usd';
  static const jarTrip = 'j.trip';
  static const jarEmergency = 'j.emergency';
  static const jarLaptop = 'j.laptop';
  static const jarEid = 'j.eid';
  static const jarCourse = 'j.course';
  static const debtSupplier = 'd.supplier';
  static const debtCourier = 'd.courier';
  static const debtFriend = 'd.friend';
  static const debtColleague = 'd.colleague';
  static const debtNeighbour = 'd.neighbour';
  static const obRent = 'o.rent';
  static const obInternet = 'o.internet';
  static const obAllowance = 'o.allowance';
  static const obInsurance = 'o.insurance';
  static const obMusic = 'o.music';
}

/// A believable (generic) money picture: three wallets, five jars, five
/// debts and five recurring obligations with some history.
Future<void> seedGoals(MadarDatabase db, {required bool arabic, required DateTime now}) async {
  final r = Repositories(db);
  String n(String ar, String en) => arabic ? ar : en;
  DateTime d(int y, int m, int day) => DateTime(y, m, day);

  Future<void> wallet(String id, String name, String currency, int opening, int color) => r.wallets.insert(
    WalletsCompanion.insert(
      id: Value(id),
      name: name,
      currency: currency,
      openingMilli: Value(opening),
      color: Value(color),
    ),
  );
  await wallet(GoalsSeedIds.walletCash, n('نقدًا', 'Cash'), 'JOD', 400000, 0xFF7FE3C4);
  await wallet(GoalsSeedIds.walletBank, n('البنك', 'Bank'), 'JOD', 2500000, 0xFF9C8CFF);
  await wallet(GoalsSeedIds.walletUsd, n('بطاقة دولار', 'USD card'), 'USD', 800000, 0xFFF5D06F);
  final home = await r.budgetItems.insert(BudgetItemsCompanion.insert(name: n('المنزل', 'Home')));

  Future<void> jar(
    String id,
    String name,
    int target,
    String currency, {
    DateTime? deadline,
    String icon = 'savings',
    int? color,
    bool archived = false,
    required DateTime created,
    List<(int, DateTime, String?)> moves = const [],
  }) async {
    await r.jars.insert(
      JarsCompanion.insert(
        id: Value(id),
        name: name,
        targetMilli: target,
        currency: currency,
        deadline: Value(deadline),
        icon: Value(icon),
        color: Value(color),
        archived: Value(archived),
        createdAt: Value(created),
      ),
    );
    var i = 0;
    for (final (amount, date, walletId) in moves) {
      await r.jarDeposits.insert(
        JarDepositsCompanion.insert(
          id: Value('$id.m${i++}'),
          jarId: id,
          amountMilli: amount,
          date: date,
          walletId: Value(walletId),
        ),
      );
    }
  }

  await jar(
    GoalsSeedIds.jarTrip,
    n('سفر العائلة', 'Family trip'),
    1200000,
    'JOD',
    deadline: d(2027, 6, 1),
    icon: 'plane',
    color: 0xFF9C8CFF,
    created: d(2026, 5, 20),
    moves: [
      (150000, d(2026, 6, 1), null),
      (150000, d(2026, 7, 1), GoalsSeedIds.walletBank),
      (100000, d(2026, 8, 1), GoalsSeedIds.walletCash),
      (150000, d(2026, 9, 1), GoalsSeedIds.walletBank),
      (-50000, d(2026, 9, 20), GoalsSeedIds.walletCash),
    ],
  );
  await jar(
    GoalsSeedIds.jarEmergency,
    n('صندوق الطوارئ', 'Emergency fund'),
    3000000,
    'JOD',
    icon: 'heart',
    color: 0xFF7FE3C4,
    created: d(2026, 1, 10),
    moves: [(1500000, d(2026, 2, 1), null), (600000, d(2026, 6, 15), null)],
  );
  await jar(
    GoalsSeedIds.jarLaptop,
    n('حاسوب جديد', 'New laptop'),
    900000,
    'USD',
    deadline: d(2026, 12, 15),
    icon: 'laptop',
    color: 0xFF1FB5C9,
    created: d(2026, 7, 1),
    moves: [(200000, d(2026, 7, 5), GoalsSeedIds.walletUsd), (150000, d(2026, 8, 20), GoalsSeedIds.walletUsd)],
  );
  await jar(
    GoalsSeedIds.jarEid,
    n('هدايا العيد', 'Eid gifts'),
    150000,
    'JOD',
    deadline: d(2027, 3, 18),
    icon: 'gift',
    color: 0xFFF2C14E,
    created: d(2026, 8, 1),
    moves: [(100000, d(2026, 8, 10), null), (60000, d(2026, 9, 25), null)],
  );
  await jar(
    GoalsSeedIds.jarCourse,
    n('دورة لغة', 'Language course'),
    250000,
    'JOD',
    icon: 'school',
    archived: true,
    created: d(2026, 2, 1),
    moves: [(250000, d(2026, 4, 1), null)],
  );

  Future<void> debt(
    String id,
    DebtDirection dir,
    String person,
    int amount,
    String currency, {
    DateTime? due,
    DateTime? settledAt,
    String? note,
    List<(int, DateTime)> pays = const [],
  }) async {
    await r.debts.insert(
      DebtsCompanion.insert(
        id: Value(id),
        direction: dir,
        person: person,
        amountMilli: amount,
        currency: currency,
        dueDate: Value(due),
        settledAt: Value(settledAt),
        note: Value(note),
      ),
    );
    var i = 0;
    for (final (a, date) in pays) {
      await r.debtPayments.insert(
        DebtPaymentsCompanion.insert(id: Value('$id.p${i++}'), debtId: id, amountMilli: a, date: date),
      );
    }
  }

  await debt(
    GoalsSeedIds.debtSupplier,
    DebtDirection.iOwe,
    n('المورّد', 'Supplier'),
    300000,
    'JOD',
    due: d(2026, 10, 5),
    note: n('بضاعة شهر أيلول', 'September stock'),
    pays: [(100000, d(2026, 9, 10))],
  );
  await debt(
    GoalsSeedIds.debtCourier,
    DebtDirection.iOwe,
    n('شركة الشحن', 'Courier company'),
    1250000,
    'EGP',
    due: d(2026, 9, 22),
  );
  await debt(GoalsSeedIds.debtFriend, DebtDirection.owedToMe, n('صديق', 'A friend'), 40000, 'JOD', due: d(2026, 10, 1));
  await debt(
    GoalsSeedIds.debtColleague,
    DebtDirection.owedToMe,
    n('زميل العمل', 'Colleague'),
    200000,
    'USD',
    pays: [(50000, d(2026, 9, 1))],
  );
  await debt(
    GoalsSeedIds.debtNeighbour,
    DebtDirection.owedToMe,
    n('الجار', 'Neighbour'),
    25000,
    'JOD',
    settledAt: DateTime(2026, 9, 12, 18),
  );

  Future<void> ob(
    String id,
    String name,
    int amount,
    String currency,
    Recurrence f,
    DateTime next, {
    int interval = 1,
    String? walletId,
    String? budgetItemId,
    bool active = true,
    List<(DateTime due, DateTime paidAt, int amount)> history = const [],
  }) async {
    await r.obligations.insert(
      ObligationsCompanion.insert(
        id: Value(id),
        name: name,
        amountMilli: amount,
        currency: currency,
        frequency: f,
        interval: Value(interval),
        nextDue: next,
        walletId: Value(walletId),
        budgetItemId: Value(budgetItemId),
        active: Value(active),
      ),
    );
    var i = 0;
    for (final (due, paidAt, a) in history) {
      await r.obligationPayments.insert(
        ObligationPaymentsCompanion.insert(
          id: Value('$id.h${i++}'),
          obligationId: id,
          dueDate: due,
          paidAt: paidAt,
          amountMilli: a,
          transactionId: Value(a == 0 ? null : '$id.tx$i'),
        ),
      );
    }
  }

  await ob(
    GoalsSeedIds.obRent,
    n('الإيجار', 'Rent'),
    350000,
    'JOD',
    Recurrence.monthly,
    d(2026, 10, 1),
    walletId: GoalsSeedIds.walletBank,
    budgetItemId: home.id,
    history: [
      (d(2026, 9, 1), DateTime(2026, 8, 31, 12), 350000),
      (d(2026, 8, 1), DateTime(2026, 8, 1, 9), 350000),
      (d(2026, 7, 1), DateTime(2026, 7, 2, 9), 0),
    ],
  );
  await ob(
    GoalsSeedIds.obInternet,
    n('اشتراك الإنترنت', 'Internet'),
    25000,
    'JOD',
    Recurrence.monthly,
    d(2026, 9, 27),
    walletId: GoalsSeedIds.walletCash,
  );
  await ob(
    GoalsSeedIds.obAllowance,
    n('مصروف أسبوعي', 'Weekly allowance'),
    5000,
    'JOD',
    Recurrence.weekly,
    d(2026, 10, 2),
    walletId: GoalsSeedIds.walletCash,
  );
  await ob(
    GoalsSeedIds.obInsurance,
    n('تأمين السيارة', 'Car insurance'),
    420000,
    'JOD',
    Recurrence.yearly,
    d(2027, 3, 15),
  );
  await ob(
    GoalsSeedIds.obMusic,
    n('اشتراك الموسيقى', 'Music subscription'),
    4990,
    'USD',
    Recurrence.monthly,
    d(2026, 10, 9),
    walletId: GoalsSeedIds.walletUsd,
    active: false,
  );
}
