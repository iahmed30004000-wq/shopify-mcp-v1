// Harness for «الحفظ»'s screens (Part 14, step 2): the real Faith test app
// over an in-memory database, with the app's **own verified Quran text**
// behind `quranStoreProvider`, so every drill runs against the real
// Uthmani data and never against a verse typed into a test.
import 'package:drift/drift.dart' show Value;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/quran/ayah.dart';
import 'package:madar/features/hifz/hifz_plan.dart';
import 'package:madar/features/orbit/domain/prayer_schedule.dart';
import 'package:madar/features/quran/quran.dart' show quranStoreProvider;
import 'package:madar/features/tasmee/tasmee.dart';

import '../quran/quran_test_data.dart';
import '../wird/fake_quran_catalog.dart';
import '../wird/wird_harness.dart';

/// Monday 28 Sep 2026, 17:10 in Amman – the Faith harness's own "now".
final DateTime hifzNow = faithTestNow;
final DateTime hifzToday = DateTime(hifzNow.year, hifzNow.month, hifzNow.day);

DateTime hifzDay(int offset) => DateTime(hifzNow.year, hifzNow.month, hifzNow.day + offset);

/// Fixed prayer times, so a reminder's instant is a number a test can
/// name instead of a guess about Amman in September.
DayTimes hifzTimes(DateTime day) => DayTimes(
  day: day,
  fajr: DateTime(day.year, day.month, day.day, 4, 40),
  sunrise: DateTime(day.year, day.month, day.day, 6, 5),
  dhuhr: DateTime(day.year, day.month, day.day, 11, 50),
  asr: DateTime(day.year, day.month, day.day, 15, 15),
  maghrib: DateTime(day.year, day.month, day.day, 17, 45),
  isha: DateTime(day.year, day.month, day.day, 19, 5),
);

/// A schedule with fixed prayer times, so a reminder's instant is a
/// number the test can name.
class FixedPrayerSchedule extends PrayerSchedule {
  FixedPrayerSchedule() : super(const PrayerSettings());

  @override
  DayTimes timesFor(DateTime date) => hifzTimes(date);
}

/// Records what «الحفظ» asked the notification layer to schedule.
class FakeHifzGoalScheduler implements HifzGoalScheduler {
  List<HifzGoalNotice> last = const [];
  int replaced = 0;
  int cancelled = 0;

  @override
  Future<void> replaceAll(List<HifzGoalNotice> notices) async {
    last = notices;
    replaced++;
  }

  @override
  Future<void> cancelAll() async {
    last = const [];
    cancelled++;
  }

  @override
  Future<bool> ensurePermission() async => true;
}

/// Puts [surah] [from]–[to] into his Hifz list (the inventory the plan
/// reads), and marks [lastActiveDaysAgo] as the last day he turned up.
Future<void> seedHifzPlan(
  MadarDatabase db, {
  int surah = 2,
  int from = 1,
  int to = 150,
  int? lastActiveDaysAgo,
}) async {
  final repos = Repositories(db);
  await repos.hifzItems.insert(
    HifzItemsCompanion.insert(
      id: const Value('h-plan'),
      kind: const Value(HifzKind.ayat),
      surah: Value(surah),
      ayahFrom: Value(from),
      ayahTo: Value(to),
    ),
  );
  if (lastActiveDaysAgo != null) {
    await repos.hifzReviews.insert(
      HifzReviewsCompanion.insert(
        itemId: 'h-plan',
        at: hifzDay(-lastActiveDaysAgo).add(const Duration(hours: 6)),
        grade: 4,
        intervalBefore: 6,
        intervalAfter: 14,
        easeAfter: 2.5,
      ),
    );
  }
}

/// One goal, written straight through the service (outside the tree).
Future<HifzGoal> seedHifzGoal(
  MadarDatabase db, {
  required String title,
  HifzGoalKind kind = HifzGoalKind.rangeOnWeekday,
  AyahRange? range,
  int? weekday,
  double? amount,
  WirdUnit unit = WirdUnit.pages,
  PrayerWindow? window = PrayerWindow.fajr,
  int offsetMinutes = 15,
  bool remind = true,
  bool active = true,
}) async {
  final repos = Repositories(db);
  final service = HifzPlanService(
    repos: repos,
    tasmee: TasmeeService(repos, clock: () => hifzNow),
    shape: await CatalogMushafShape.load(FakeQuranCatalog()),
    clock: () => hifzNow,
  );
  final (goal, _) = await service.addGoal(
    title: title,
    kind: kind,
    range: range,
    weekday: weekday,
    amount: amount,
    unit: unit,
    window: window,
    offsetMinutes: offsetMinutes,
    remind: remind,
    active: active,
  );
  return goal;
}

/// The plan's settings, written before the app reads them (the new
/// portion's cursor, the caps).
Future<void> seedHifzSettings(MadarDatabase db, HifzPlanSettings settings) async {
  final repos = Repositories(db);
  final service = HifzPlanService(
    repos: repos,
    tasmee: TasmeeService(repos, clock: () => hifzNow),
    shape: await CatalogMushafShape.load(FakeQuranCatalog()),
    clock: () => hifzNow,
  );
  await service.setSettings(settings);
}

/// The whole Faith app around [home], with the verified Quran text loaded
/// and the recogniser answering, honestly, that there is none.
Future<FaithTestEnv> pumpHifzUi(
  WidgetTester tester, {
  required Widget home,
  Locale locale = const Locale('ar'),
  DateTime? now,
  Future<void> Function(MadarDatabase db)? beforePump,
  List<Override> overrides = const [],
}) => pumpFaithApp(
  tester,
  home: home,
  locale: locale,
  now: now ?? hifzNow,
  beforePump: beforePump,
  overrides: [
    quranStoreProvider.overrideWithValue(QuranTestData.store()),
    ...overrides,
  ],
);
