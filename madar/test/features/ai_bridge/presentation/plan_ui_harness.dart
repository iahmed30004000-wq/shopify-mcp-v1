// Test harness for Part 3's screens: the **real** Madar app (router, app
// lock gate, themes, locale, undo toasts) over a seeded in-memory database,
// with a frozen clock and a fake share intake.
//
// Everything here is generic: a budget envelope, a food, a meal, a
// switched-off habit, a lab test, a project, a goal and a tracker. No
// personal data ships, in the app or in these tests.
import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/ai_bridge/ai_bridge.dart';
import 'package:madar/features/data/data.dart' show dataClockProvider;

import '../../../helpers/test_app.dart';

/// Saturday 10 Oct 2026, 09:00 – the day every fixture is written against.
final DateTime planUiNow = DateTime(2026, 10, 10, 9);

/// A share intake a test drives by hand.
class FakeShareIntake implements ShareIntake {
  FakeShareIntake({this.launch});

  /// What was "shared" before the app started.
  SharedPlanPayload? launch;

  final StreamController<SharedPlanPayload> _shares = StreamController.broadcast();

  @override
  Stream<SharedPlanPayload> get shares => _shares.stream;

  @override
  Future<SharedPlanPayload?> takeLaunchShare() async {
    final payload = launch;
    launch = null;
    return payload;
  }

  /// Another app shares an answer into the running Madar.
  void share(String text, {String? name}) => _shares.add(SharedPlanPayload(text, name: name));

  void dispose() => unawaited(_shares.close());
}

/// His own data: one envelope by amount, a food, a meal plan with one meal,
/// a switched-off habit, a lab test, a project, a learning goal and a
/// tracker – exactly what the fixture plan below points at.
Future<void> seedPlanData(MadarDatabase db) async {
  final repos = Repositories(db);
  await repos.db
      .into(repos.db.currencies)
      .insert(
        CurrenciesCompanion.insert(
          code: 'JOD',
          nameAr: 'دينار',
          nameEn: 'Dinar',
          symbol: 'د.أ',
          decimals: const Value(3),
          isBase: const Value(true),
        ),
        mode: InsertMode.insertOrReplace,
      );
  await repos.budgetItems.insert(
    BudgetItemsCompanion.insert(
      id: const Value('env-grocery'),
      name: 'بقالة',
      mode: const Value(BudgetMode.amount),
      amountMilli: const Value(120000),
      period: const Value(BudgetPeriod.monthly),
    ),
  );
  await repos.foods.insert(
    FoodsCompanion.insert(
      id: const Value('food-maqluba'),
      name: 'مقلوبة',
      tags: const Value(['نشويات']),
      defaultPortion: const Value(1.5),
      unit: const Value('طبق'),
    ),
  );
  await repos.mealPlans.insert(
    MealPlansCompanion.insert(id: const Value('mplan-1'), name: 'خطتي', active: const Value(true)),
  );
  await repos.mealSlots.insert(
    MealSlotsCompanion.insert(id: const Value('slot-lunch'), planId: 'mplan-1', name: 'غدا', timeMinutes: 780),
  );
  await repos.habits.insert(
    HabitsCompanion.insert(
      id: const Value('habit-walk'),
      name: 'مشي',
      category: const Value('حركة'),
      active: const Value(false),
    ),
  );
  await repos.labTests.insert(
    LabTestsCompanion.insert(id: const Value('lab-a1c'), name: 'سكر صائم', unit: const Value('mg/dL')),
  );
  await repos.projects.insert(ProjectsCompanion.insert(id: const Value('proj-1'), name: 'البيت'));
  await repos.learningGoals.insert(
    LearningGoalsCompanion.insert(id: const Value('goal-1'), name: 'حفظ', target: 10, unit: const Value('صفحة')),
  );
  await repos.customModules.insert(
    CustomModulesCompanion.insert(id: const Value('mod-1'), name: 'مزاجي', color: 0xFF1FB5C9),
  );
}

/// An answer the screens are built against: one of every state the review
/// has to show, and – for the checklist – the owner's own example
/// («خطة تشرين الأول» with ☐ امشي ٢٠ دقيقة بعد العشا · ☐ راجع فاتورة
/// الكهربا · ☐ سجّل أكلك ٥ أيام متواصلة · ☐ اتصل بأمك يوم الجمعة).
///
/// * `b1` budget tweak on «بقالة» (ready, and his own before/after
///   example: ١٢٠ د.أ اليوم ← ١٠٠ د.أ);
/// * `h1` a habit he has, switched off (ready);
/// * `f1` a new food, and `m1` a meal change that **needs** it first
///   (blocked until he approves `f1`);
/// * `t1`, `d1`, `e1` three tasks (ready; each a checklist line only);
/// * `p1` a task on a day that has passed (needs an edit);
/// * `x1` a dose – refused by the health guard, and never approvable;
/// * `n1` a note.
Map<String, Object?> uiPlan() => {
  'madar': 'plan',
  'version': 1,
  'title': 'خطة تشرين الأول',
  'summary': 'ثلاث حركات صغيرة على المصاري والأكل والمشي.',
  'generatedFor': planDay(planUiNow),
  'source': {
    'kind': 'video',
    'title': 'حلقة عن الأكل',
    'completeness': 'النص بيوقف عند النص',
    'claimsFlagged': ['بيحكي إنه بيخلّص من كل الأمراض المزمنة — ما بنبني عليه إشي'],
  },
  'items': [
    {
      'id': 'b1',
      'kind': 'budgetTweak',
      'title': 'نزّل مصروف البقالة لمية',
      'reason': 'آخر ثلاث شهور صرفت أقل من المرصود بعشرين دينار.',
      'area': 'money',
      'data': {'envelopeRef': 'بقالة', 'newAmount': 100, 'period': 'monthly'},
    },
    {
      'id': 'h1',
      'kind': 'habit',
      'title': 'امشي عشرين دقيقة بعد العشا',
      'reason': 'المشي عندك مسجّل ستة أيام من ثلاثين بس.',
      'area': 'body',
      'data': {'existingRef': 'habit-walk'},
    },
    {
      'id': 'f1',
      'kind': 'food',
      'title': 'شوفان',
      'reason': 'فطورك المسجّل كله خبز أبيض.',
      'area': 'body',
      'data': {
        'tags': ['فطور'],
        'portion': 1,
        'unit': 'كوب',
      },
    },
    {
      'id': 'm1',
      'kind': 'mealChange',
      'title': 'حطّ الشوفان على الغدا',
      'reason': 'الغدا عندك نشويات لحالها بأربعة أيام من سبعة.',
      'area': 'body',
      'dependsOn': ['f1'],
      'data': {'op': 'addFood', 'slotRef': 'غدا', 'foodRef': 'شوفان', 'portion': 1, 'unit': 'كوب'},
    },
    {
      'id': 't1',
      'kind': 'task',
      'title': 'راجع فاتورة الكهربا',
      'reason': 'آخر فاتورتين أعلى من المعدل.',
      'area': 'money',
      'data': {'window': 'asr', 'priority': 2},
    },
    {
      'id': 'd1',
      'kind': 'task',
      'title': 'سجّل أكلك ٥ أيام متواصلة',
      'reason': 'أكلك مسجّل يومين بس من آخر أسبوع.',
      'area': 'body',
      'data': {'window': 'isha'},
    },
    {
      'id': 'e1',
      'kind': 'task',
      'title': 'اتصل بأمك يوم الجمعة',
      'reason': 'آخر مكالمة مسجّلة قبل ثلاث أسابيع.',
      'area': 'family',
      'data': {'day': '2026-10-16'},
    },
    {
      'id': 'p1',
      'kind': 'task',
      'title': 'رتّب أوراق البيت',
      'reason': 'الأوراق المهمة بلا مكان ثابت عندك.',
      'area': 'work',
      'data': {'day': '2026-09-20'},
    },
    {
      'id': 'x1',
      'kind': 'task',
      'title': 'زيد حبة الضغط لـ٥٠٠ ملغ بعد الغدا',
      'reason': 'الضغط عندك عالي بآخر قراءتين.',
      'area': 'health',
      'data': {},
    },
    {
      'id': 'n1',
      'kind': 'note',
      'title': 'الصلاة بالمسجد بترفع يومك',
      'reason': 'أيام الجماعة عندك أعلى بالمهام المخلّصة.',
      'data': {'body': 'جرّب تربط المشي بالرجعة من المسجد.'},
    },
  ],
};

String encodeUiPlan([Map<String, Object?>? plan]) => jsonEncode(plan ?? uiPlan());

/// A payload the validator refuses outright: not a «خطة مدار» at all.
const String notAPlanPayload = '{"hello": "world", "items": []}';

/// A payload that is a plan but carries nothing to review.
const String emptyPlanPayload = '{"madar": "plan", "version": 1, "items": []}';

/// Imports [payload] straight through the engine (no screen), the way a
/// test that wants to **start** on a plan does. Returns the stored plan.
Future<AppliedPlanRow> importForTest(
  MadarDatabase db,
  String payload, {
  String name = 'خطة تشرين الأول',
  PlanOrigin origin = PlanOrigin.paste,
}) async {
  final repos = Repositories(db);
  final service = PlanApplyService(repos, clock: () => planUiNow);
  final catalog = await AiBridgeRepository(repos).loadCatalog(planUiNow);
  final import = await service.take(payload, catalog: catalog, origin: origin, name: name);
  return import.plan!;
}

/// The app at [initialLocation] with the plan clock frozen and the share
/// intake faked. Deliberately **not** settled: the empty states' and the
/// glass sheen's loops never finish, and an undo toast counts down for five
/// seconds – [planFrames] drives the frames instead.
Future<TestApp> pumpPlanApp(
  WidgetTester tester, {
  String initialLocation = '/plans',
  Locale locale = const Locale('ar'),
  FakeShareIntake? share,
  Future<void> Function(MadarDatabase db)? beforePump,
  double textScale = 1,
  List<Override> overrides = const [],
}) async {
  final intake = share ?? FakeShareIntake();
  addTearDown(intake.dispose);
  final app = await pumpMadarApp(
    tester,
    settings: AppSettings(onboarded: true, languageCode: locale.languageCode),
    initialLocation: initialLocation,
    now: planUiNow,
    settle: false,
    overrides: [
      dataClockProvider.overrideWithValue(() => planUiNow),
      shareIntakeProvider.overrideWithValue(intake),
      ...overrides,
    ],
    beforePump: (db) async {
      await seedPlanData(db);
      if (beforePump != null) await beforePump(db);
    },
  );
  await planFrames(tester, n: 18);
  return app;
}

/// Pumps [n] frames of [step], letting database work (microtasks and
/// stream hops) run in between – the way to drive these screens when an
/// undo toast has to stay on the screen.
Future<void> planFrames(WidgetTester tester, {int n = 12, Duration step = const Duration(milliseconds: 60)}) async {
  for (var i = 0; i < n; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 2)));
    await tester.pump(step);
  }
}

/// Lets the undo toasts count down and leave (a test must not end with one
/// on screen – its timer would be pending).
Future<void> expirePlanToasts(WidgetTester tester) => planFrames(tester, n: 9, step: const Duration(seconds: 1));

/// Taps [finder] (scrolling it into view first) and lets the work land.
Future<void> tapPlan(WidgetTester tester, Finder finder, {int frames = 14}) async {
  await showPlan(tester, finder);
  await tester.tap(finder.first, warnIfMissed: false);
  await planFrames(tester, n: frames);
}

/// Scrolls [finder] into view inside the screen's list, which builds its
/// cards lazily (a card further down the plan is not in the tree at all
/// until the list reaches it).
///
/// The hunt is bounded by **the list's own extent**, not by a step count:
/// it stops the moment the list cannot scroll any further, so a longer or
/// shorter plan never changes whether it works.
Future<void> showPlan(WidgetTester tester, Finder finder) async {
  const step = 260.0;
  final list = find.byType(ListView);
  if (finder.evaluate().isEmpty && list.evaluate().isNotEmpty) {
    final position = tester.state<ScrollableState>(
      find.descendant(of: list.first, matching: find.byType(Scrollable)).first,
    ).position;
    var previous = double.negativeInfinity;
    while (finder.evaluate().isEmpty &&
        position.pixels < position.maxScrollExtent &&
        position.pixels > previous) {
      previous = position.pixels;
      await tester.drag(list.first, const Offset(0, -step));
      await planFrames(tester, n: 3, step: const Duration(milliseconds: 40));
    }
  }
  await tester.ensureVisible(finder.first);
  await planFrames(tester, n: 6, step: const Duration(milliseconds: 40));
}

/// Runs real async work from a test.
///
/// **Every** database read in a widget test has to go through this: the
/// test body runs inside a fake clock, where a drift query's future never
/// completes, and a bare `await` on one simply hangs the test.
Future<T> planWork<T>(WidgetTester tester, Future<T> Function() work) async {
  final result = await tester.runAsync(work);
  await planFrames(tester, n: 4, step: const Duration(milliseconds: 40));
  return result as T;
}

/// Reads [work] outside the fake clock without pumping afterwards (for a
/// plain assertion at the end of a test).
Future<T> planRead<T>(WidgetTester tester, Future<T> Function() work) async {
  final result = await tester.runAsync(work);
  return result as T;
}

/// Every suggestion row of a plan, by item id.
Future<Map<String, AppliedPlanItemRow>> planRows(WidgetTester tester, MadarDatabase db, String planId) =>
    planRead(tester, () async {
      final rows = await Repositories(db).appliedPlanItems.getAll(where: (t) => t.planId.equals(planId));
      return {for (final r in rows) r.itemKey: r};
    });
