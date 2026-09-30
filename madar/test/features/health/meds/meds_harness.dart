// Test harness for the medication screens: the real theme, localisations,
// digit and motion scopes and the celebration overlay (like AppFrame), over a
// seeded in-memory database, a silent sound engine, recording haptics, a
// frozen clock, fixed Amman-like prayer times and a fake notification
// platform.
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
import 'package:madar/core/providers.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/health/meds/meds.dart';
import 'package:madar/features/home/home_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/test_app.dart';

/// Tuesday 29 Sep 2026, 13:10 (the Dhuhr window).
final DateTime medsTestNow = DateTime(2026, 9, 29, 13, 10);

/// Amman-like prayer times on any day (fixed, so tests do not depend on the
/// host's time zone).
DateTime? fakePrayerTime(DateTime day, AnchorBase base) {
  final (h, m) = switch (base) {
    AnchorBase.fajr => (4, 55),
    AnchorBase.sunrise => (6, 18),
    AnchorBase.dhuhr => (12, 26),
    AnchorBase.asr => (15, 50),
    AnchorBase.maghrib => (18, 32),
    AnchorBase.isha => (19, 50),
    _ => (-1, 0),
  };
  if (h < 0) return null;
  return DateTime(day.year, day.month, day.day, h, m);
}

PrayerWindow fakeWindowOf(DateTime at) {
  final day = DateTime(at.year, at.month, at.day);
  DateTime t(AnchorBase b) => fakePrayerTime(day, b)!;
  if (at.isBefore(t(AnchorBase.fajr))) return PrayerWindow.isha;
  if (at.isBefore(t(AnchorBase.sunrise))) return PrayerWindow.fajr;
  if (at.isBefore(t(AnchorBase.dhuhr))) return PrayerWindow.duha;
  if (at.isBefore(t(AnchorBase.asr))) return PrayerWindow.dhuhr;
  if (at.isBefore(t(AnchorBase.maghrib))) return PrayerWindow.asr;
  if (at.isBefore(t(AnchorBase.isha))) return PrayerWindow.maghrib;
  return PrayerWindow.isha;
}

class MedsTestEnv {
  MedsTestEnv(this.db, this.haptics, this.sound);

  final MadarDatabase db;
  final RecordingHaptics haptics;
  final SilentSoundService sound;
  final FakeNotificationPlatform notifications = FakeNotificationPlatform();
  late ProviderContainer container;

  Repositories get repos => Repositories(db);
}

Future<(Widget, MedsTestEnv)> buildMedsApp(
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
  final clock = now ?? medsTestNow;
  final env = MedsTestEnv(db, haptics, sound);
  final arabic = locale.languageCode == 'ar';
  final app = ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      soundServiceProvider.overrideWithValue(sound),
      hapticsServiceProvider.overrideWithValue(haptics),
      databaseProvider.overrideWithValue(db),
      homeClockProvider.overrideWithValue(() => clock),
      notificationPlatformProvider.overrideWithValue(env.notifications),
      medsPrayerTimeProvider.overrideWithValue(fakePrayerTime),
      medsWindowOfProvider.overrideWithValue(fakeWindowOf),
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

Future<MedsTestEnv> pumpMedsApp(
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
  final (app, env) = await buildMedsApp(
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
  await settleMeds(tester);
  return env;
}

/// Lets database work (microtasks, stream hops) and finite animations finish.
Future<void> settleMeds(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.pump(const Duration(seconds: 1));
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await tester.pump(const Duration(milliseconds: 16));
  }
}

// ------------------------------------------------------------- scenario ----

/// Ids of the seeded scenario.
class MedsScenario {
  late String levo, calcium, omega, metformin, magnesium, iron, paracetamol, b12, course;
}

/// A realistic day at 13:10: a thyroid pill after Fajr (taken), calcium
/// pushed back by a four-hour rule (taken), iron skipped, magnesium late
/// with a rule it cannot meet, omega-3 due now and running low, metformin
/// pinned to lunch, an injection course on day 8 of 10 (taken), an as-needed
/// painkiller; the six days before mostly taken.
Future<MedsScenario> seedMedsScenario(MadarDatabase db, {String lang = 'ar', DateTime? now}) async {
  final ar = lang == 'ar';
  final n = now ?? medsTestNow;
  final today = DateTime(n.year, n.month, n.day);
  final s = MedsScenario();
  final service = MedsService(Repositories(db), clock: () => n);
  Future<String> med(MedDraft d) async => (await service.saveMed(d)).id;

  s.levo = await med(
    MedDraft(
      name: ar ? 'ليفوثيروكسين' : 'Levothyroxine',
      dose: ar ? '٥٠ مكغ' : '50 mcg',
      doseAmount: 1,
      doseUnit: ar ? 'حبة' : 'tab',
      slots: const [MedSlot(ClockHm(5, 10), TimeAnchor(AnchorBase.fajr, 15))],
      takenWith: TakenWith.emptyStomach,
      stock: 42,
      refillAt: 7,
      color: 0xFF7FB2E5,
    ),
  );
  s.calcium = await med(
    MedDraft(
      name: ar ? 'كالسيوم + فيتامين د' : 'Calcium + D3',
      dose: ar ? '٦٠٠ ملغ' : '600 mg',
      slots: const [MedSlot(ClockHm(8, 0)), MedSlot(ClockHm(20, 0))],
      takenWith: TakenWith.breakfast,
      color: 0xFFE8C66A,
    ),
  );
  s.iron = await med(
    MedDraft(
      name: ar ? 'حديد' : 'Iron',
      dose: ar ? '٦٥ ملغ' : '65 mg',
      kind: MedKind.supplement,
      slots: const [MedSlot(ClockHm(7, 0))],
      color: 0xFFC8736B,
    ),
  );
  s.magnesium = await med(
    MedDraft(
      name: ar ? 'مغنيسيوم' : 'Magnesium',
      dose: ar ? '٢٥٠ ملغ' : '250 mg',
      kind: MedKind.supplement,
      slots: const [MedSlot(ClockHm(11, 0))],
      color: 0xFF9C8BD9,
    ),
  );
  s.omega = await med(
    MedDraft(
      name: ar ? 'أوميغا ٣' : 'Omega-3',
      dose: ar ? 'كبسولة' : '1 cap',
      doseAmount: 1,
      doseUnit: 'cap',
      kind: MedKind.supplement,
      slots: const [MedSlot(ClockHm(13, 0))],
      stock: 5,
      refillAt: 7,
      color: 0xFF6CC3B5,
    ),
  );
  s.metformin = await med(
    MedDraft(
      name: ar ? 'ميتفورمين' : 'Metformin',
      dose: ar ? '٥٠٠ ملغ' : '500 mg',
      slots: const [MedSlot(ClockHm(13, 30))],
      takenWith: TakenWith.lunch,
    ),
  );
  s.paracetamol = await med(
    MedDraft(name: ar ? 'باراسيتامول' : 'Paracetamol', dose: ar ? '٥٠٠ ملغ' : '500 mg', color: 0xFFB9C2CF),
  );
  s.b12 = await med(
    MedDraft(
      name: ar ? 'فيتامين ب١٢' : 'Vitamin B12',
      kind: MedKind.injection,
      dose: ar ? 'أمبولة' : '1 amp',
      slots: const [MedSlot(ClockHm(10, 0))],
      takenWith: TakenWith.perCourse,
      color: 0xFFE39AC0,
    ),
  );
  s.course = (await service.saveCourse(
    CourseDraft(
      name: ar ? 'حقن ب١٢' : 'B12 injections',
      startDate: DateTime(2026, 9, 22),
      medicationId: s.b12,
      phases: [
        CoursePhase(frequency: CourseFrequency.daily, count: 10, dose: ar ? '١٠٠٠ مكغ' : '1000 mcg'),
        CoursePhase(frequency: CourseFrequency.weekly, count: 4, dose: ar ? '١٠٠٠ مكغ' : '1000 mcg'),
        CoursePhase(frequency: CourseFrequency.monthly, dose: ar ? '١٠٠٠ مكغ' : '1000 mcg'),
      ],
    ),
  )).id;

  await Repositories(db).healthAlerts.insert(
    HealthAlertsCompanion.insert(body: ar ? 'حساسية من البنسلين' : 'Penicillin allergy'),
  );
  await service.saveRule(RuleDraft(kind: MedRuleKind.separate, medAId: s.levo, medBId: s.calcium, minutes: 240));
  await service.saveRule(RuleDraft(kind: MedRuleKind.separate, medAId: s.calcium, medBId: s.magnesium, minutes: 360));
  await service.saveRule(RuleDraft(kind: MedRuleKind.withFood, medAId: s.metformin));
  await service.saveRule(
    RuleDraft(kind: MedRuleKind.separate, medAId: s.iron, medBId: s.calcium, minutes: 120),
  );

  // Everything was added six days ago.
  for (final m in await service.meds()) {
    await Repositories(db).medications.update(
      MedicationsCompanion(id: Value(m.id), createdAt: Value(today.subtract(const Duration(days: 6)))),
    );
  }

  // The week before: mostly taken, a skip and a miss here and there.
  final scheduler = DoseScheduler(
    meds: await service.meds(),
    courses: await service.courses(),
    rules: await service.rules(),
    prayerTime: fakePrayerTime,
  );
  final plans = scheduler.planDays(today.subtract(const Duration(days: 6)), 6);
  var k = 0;
  for (final p in plans) {
    for (final d in p.doses) {
      k++;
      if (k % 11 == 0) continue; // missed
      if (k % 13 == 0) {
        await service.skip(d);
        continue;
      }
      await service.take(d, at: d.at.add(Duration(minutes: 3 + k % 17)));
    }
  }

  // Today so far.
  DateTime at(int h, int m) => DateTime(today.year, today.month, today.day, h, m);
  Future<void> takeAt(String medId, DateTime slot, DateTime when) async {
    await service.takeSlot(medId, slot, at: when);
  }

  await takeAt(s.levo, at(5, 10), at(5, 22));
  await takeAt(s.calcium, at(8, 0), at(9, 26));
  await service.skipSlot(s.iron, at(7, 0));
  await takeAt(s.b12, at(10, 0), at(10, 4));
  // The painkiller, last night.
  await service.logNow(s.paracetamol, at: at(22, 10).subtract(const Duration(days: 1)));
  // Keep today's stock where the story needs it.
  await Repositories(db).medications.update(MedicationsCompanion(id: Value(s.omega), stock: const Value(5)));
  return s;
}
