import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/interaction/interaction.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/body/body.dart';

import 'body_harness.dart';
import 'body_seed.dart';

final L10n ar = lookupL10n(const Locale('ar'));
final L10n en = lookupL10n(const Locale('en'));

Future<T> db<T>(WidgetTester tester, Future<T> Function() work) async => (await tester.runAsync(work)) as T;

Future<void> frames(WidgetTester tester, {int n = 12, Duration step = const Duration(milliseconds: 80)}) async {
  for (var i = 0; i < n; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 2)));
    await tester.pump(step);
  }
}

/// Lets undo toasts count down and leave.
Future<void> expireToasts(WidgetTester tester) => frames(tester, n: 8, step: const Duration(seconds: 1));

void main() {
  group('today', () {
    testWidgets("today's weekday session: the orb logs the planned values; undo removes the log", (tester) async {
      final env = await pumpBodyApp(tester, home: const BodyScreen(), seed: BodySeed.planOnly);
      // Tuesday: squats, push-ups and the walk – not stretching (Mon/Wed/Fri)
      // and not the paused swim.
      expect(find.byType(SessionTile), findsNWidgets(3));
      expect(find.text('تمارين الإطالة'), findsNothing);
      expect(find.text('سباحة'), findsNothing);

      final tile = find.byKey(ValueKey('body.session.${(await db(tester, () => env.repos.exercises.getAll()))[1].id}'));
      final orb = find.descendant(of: tile, matching: find.bySemanticsLabel(ar.bodyMarkDone));
      await tester.tap(orb.first);
      await frames(tester);
      final logs = await db(tester, () => env.repos.workoutLogs.getAll());
      expect(logs, hasLength(1));
      expect(logs.single.name, 'تمرين ضغط');
      expect(logs.single.sets, 3);
      expect(logs.single.reps, 15);
      expect(logs.single.at, bodyTestNow);
      final activity = await db(tester, () => env.repos.activityLog.getAll());
      expect(activity.single.planetKey, 'body');
      expect(activity.single.kind, 'body.workout');
      expect(env.haptics.fired, contains(Haptic.success));

      expect(find.text(ar.actionUndo), findsOneWidget);
      await tester.tap(find.text(ar.actionUndo));
      await frames(tester);
      expect(await db(tester, () => env.repos.workoutLogs.count()), 0);
      expect(await db(tester, () => env.repos.activityLog.count()), 0);
      await expireToasts(tester);
    });

    testWidgets('tapping an exercise opens the log sheet prefilled; actual values are saved', (tester) async {
      final env = await pumpBodyApp(tester, home: const BodyScreen(), seed: BodySeed.planOnly);
      await tester.tap(find.text('قرفصاء بالبار'));
      await frames(tester);
      expect(find.text(ar.bodyLogSubtitle), findsOneWidget);
      // 60 kg planned → +2.5.
      final weight = find.byKey(const ValueKey('body.log.weight'));
      expect(find.descendant(of: weight, matching: find.text('٦٠')), findsOneWidget);
      await tester.tap(find.descendant(of: weight, matching: find.byIcon(Icons.add_rounded)));
      await frames(tester, n: 6);
      expect(find.descendant(of: weight, matching: find.text('٦٢٫٥')), findsOneWidget);
      await tester.tap(find.widgetWithText(SheetButton, ar.bodyLogSave));
      await frames(tester);
      final log = (await db(tester, () => env.repos.workoutLogs.getAll())).single;
      expect(log.weight, 62.5);
      expect(log.sets, 4);
      expect(log.reps, 8);
      expect(env.haptics.fired, contains(Haptic.tick));
      // The row now shows it as done with its volume (4 × 8 × 62.5).
      expect(find.text(ar.bodyKg('٢٬٠٠٠')), findsOneWidget);
    });

    testWidgets('swiping an exercise to the reading end logs it', (tester) async {
      final env = await pumpBodyApp(tester, home: const BodyScreen(), seed: BodySeed.planOnly, locale: const Locale('en'));
      await tester.drag(find.text('Brisk walk'), const Offset(260, 0));
      await frames(tester, n: 30);
      final log = (await db(tester, () => env.repos.workoutLogs.getAll())).single;
      expect(log.name, 'Brisk walk');
      expect(log.durationMin, 30);
      await expireToasts(tester);
    });

    testWidgets('a fresh install shows the empty plan invitation', (tester) async {
      await pumpBodyApp(tester, home: const BodyScreen());
      expect(find.text(ar.bodyNoPlanTitle), findsOneWidget);
      expect(find.byType(SessionTile), findsNothing);
      await tester.tap(find.text(ar.bodyOpenPlan));
      await frames(tester);
      expect(find.text(ar.bodyPlanEmptyTitle), findsOneWidget);
    });
  });

  group('plan', () {
    testWidgets('the add sheet saves the name, days (Saturday first in Arabic) and targets', (tester) async {
      final env = await pumpBodyApp(tester, home: const BodyScreen(initialTab: BodyTab.plan));
      await tester.tap(find.byKey(const ValueKey('body.fab')));
      await frames(tester);
      await tester.enterText(find.byKey(const ValueKey('body.exercise.name')), 'Plank');
      // The seven day toggles run Saturday → Friday from the right.
      final sat = find.bySemanticsLabel('السبت');
      final sun = find.bySemanticsLabel('الأحد');
      final fri = find.bySemanticsLabel('الجمعة');
      expect(tester.getCenter(sat).dx, greaterThan(tester.getCenter(sun).dx));
      expect(tester.getCenter(sun).dx, greaterThan(tester.getCenter(fri).dx));
      await tester.tap(sat);
      await tester.tap(find.bySemanticsLabel('الاثنين'));
      await frames(tester, n: 6);
      await tester.tap(find.descendant(of: find.byKey(const ValueKey('body.exercise.sets')), matching: find.byIcon(Icons.add_rounded)));
      await frames(tester, n: 6);
      await tester.tap(find.widgetWithText(SheetButton, ar.bodySave));
      await frames(tester);
      final row = (await db(tester, () => env.repos.exercises.getAll())).single;
      expect(row.name, 'Plank');
      expect(row.weekdays, [1, 6]);
      expect(row.sets, 1);
      expect(find.byType(ExerciseTile), findsOneWidget);
    });

    testWidgets('a nameless exercise cannot be saved', (tester) async {
      final env = await pumpBodyApp(tester, home: const BodyScreen(initialTab: BodyTab.plan));
      await tester.tap(find.byKey(const ValueKey('body.fab')));
      await frames(tester);
      await tester.tap(find.widgetWithText(SheetButton, ar.bodySave));
      await frames(tester, n: 6);
      expect(find.text(ar.bodyNameRequired), findsOneWidget);
      expect(env.haptics.fired, contains(Haptic.error));
      expect(await db(tester, () => env.repos.exercises.count()), 0);
    });

    testWidgets('delete with undo from the row', (tester) async {
      final env = await pumpBodyApp(tester, home: const BodyScreen(initialTab: BodyTab.plan), seed: BodySeed.planOnly);
      expect(find.byType(ExerciseTile), findsNWidgets(5));
      final first = (await db(tester, () => env.repos.exercises.getAll())).first;
      final state = tester.state<ActionableItemState>(find.byKey(ValueKey('body.exercise.${first.id}')));
      state.delete();
      await frames(tester);
      expect(await db(tester, () => env.repos.exercises.count()), 4);
      await tester.tap(find.text(ar.actionUndo));
      await frames(tester);
      expect(await db(tester, () => env.repos.exercises.count()), 5);
      await expireToasts(tester);
    });

    testWidgets('the week strip runs Saturday → Friday in Arabic, Sunday → Saturday in English', (tester) async {
      await pumpBodyApp(tester, home: const BodyScreen(initialTab: BodyTab.plan), seed: BodySeed.planOnly);
      final strip = find.byType(WeekStripCard);
      double x(String label) => tester.getCenter(find.descendant(of: strip, matching: find.bySemanticsLabel(RegExp('^$label')))).dx;
      expect(x('السبت'), greaterThan(x('الأحد')));
      expect(x('الخميس'), greaterThan(x('الجمعة')));
    });

    testWidgets('English weeks start on Sunday, left to right', (tester) async {
      await pumpBodyApp(
        tester,
        home: const BodyScreen(initialTab: BodyTab.plan),
        seed: BodySeed.planOnly,
        locale: const Locale('en'),
      );
      final strip = find.byType(WeekStripCard);
      double x(String label) => tester.getCenter(find.descendant(of: strip, matching: find.bySemanticsLabel(RegExp('^$label')))).dx;
      expect(x('Sunday'), lessThan(x('Monday')));
      expect(x('Friday'), lessThan(x('Saturday')));
    });
  });

  group('fasting', () {
    testWidgets('start, then end: the fast is stored and logged on the planet', (tester) async {
      final env = await pumpBodyApp(tester, home: const BodyScreen(initialTab: BodyTab.fasting));
      await tester.tap(find.byKey(const ValueKey('body.fasting.start')));
      await frames(tester);
      final started = (await db(tester, () => env.repos.fastingSessions.getAll())).single;
      expect(started.start, bodyTestNow);
      expect(started.end, isNull);
      expect(started.targetHours, 16);
      expect(find.text(ar.bodyFastPhaseFasting), findsWidgets);
      await expireToasts(tester);

      await tester.tap(find.byKey(const ValueKey('body.fasting.end')));
      await frames(tester);
      final ended = (await db(tester, () => env.repos.fastingSessions.getAll())).single;
      expect(ended.end, bodyTestNow);
      final activity = await db(tester, () => env.repos.activityLog.getAll());
      expect(activity.single.kind, 'body.fast');
      await expireToasts(tester);
    });

    testWidgets('choosing 18:6 saves the plan; the goal notification is planned while fasting', (tester) async {
      final env = await pumpBodyApp(tester, home: const BodyScreen(initialTab: BodyTab.fasting), seed: BodySeed.full);
      await tester.ensureVisible(find.byKey(const ValueKey('body.fast.preset.18')));
      await tester.tap(find.byKey(const ValueKey('body.fast.preset.18')));
      await frames(tester);
      final plan = await db(tester, () => BodyService(env.repos).fastingPlan());
      expect(plan.targetHours, 18);
      await frames(tester, n: 20);
      await env.container.read(bodyReminderSyncProvider.notifier).syncNow();
      final goal = env.reminders.current.where((n) => n.kind == BodyNoticeKind.fastGoal).single;
      // The running fast keeps its own 16 h goal: yesterday 20:05 + 16 h.
      expect(goal.at, DateTime(2026, 9, 29, 12, 5));
      expect(goal.id, BodyReminderIds.goal);
    });
  });

  group('water', () {
    testWidgets('+250 logs a glass with undo; crossing the target celebrates', (tester) async {
      final env = await pumpBodyApp(
        tester,
        home: const BodyScreen(initialTab: BodyTab.water),
        beforePump: (db) => BodyService(Repositories(db)).setWaterTarget(500),
      );
      final add = find.byKey(const ValueKey('body.water.add.250'));
      await tester.tap(add);
      await frames(tester);
      expect((await db(tester, () => env.repos.waterLogs.getAll())).single.ml, 250);
      expect((await db(tester, () => env.repos.activityLog.getAll())).single.kind, 'body.water');
      await tester.tap(find.text(ar.actionUndo));
      await frames(tester);
      expect(await db(tester, () => env.repos.waterLogs.count()), 0);
      await expireToasts(tester);

      await tester.tap(add);
      await frames(tester);
      expect(find.text(ar.bodyWaterGoalMet), findsNothing);
      env.haptics.fired.clear();
      await tester.tap(add);
      await frames(tester);
      expect(find.text(ar.bodyWaterGoalMet), findsOneWidget);
      expect(env.haptics.fired, contains(Haptic.heavy));
      await expireToasts(tester);
    });

    testWidgets('the target is editable and stored for the orbit', (tester) async {
      final env = await pumpBodyApp(tester, home: const BodyScreen(initialTab: BodyTab.water));
      await tester.tap(find.byKey(const ValueKey('body.water.target')));
      await frames(tester);
      await tester.enterText(find.byType(TextField).first, '3000');
      await frames(tester, n: 4);
      await tester.tap(find.widgetWithText(SheetButton, ar.bodySave));
      await frames(tester);
      expect(await db(tester, () => env.repos.keyValues.getJson('body.waterTargetMl')), 3000);
      await expireToasts(tester);
    });
  });

  group('avoid', () {
    testWidgets('add an item with a reason; it shows on the list and today', (tester) async {
      final env = await pumpBodyApp(tester, home: const BodyScreen(initialTab: BodyTab.avoid));
      expect(find.text(ar.bodyAvoidEmptyTitle), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('body.fab')));
      await frames(tester);
      await tester.enterText(find.byType(TextField).at(0), 'Deep squats');
      await tester.enterText(find.byType(TextField).at(1), 'knee');
      await frames(tester, n: 4);
      await tester.tap(find.widgetWithText(SheetButton, ar.bodySave));
      await frames(tester);
      final row = (await db(tester, () => env.repos.avoidItems.getAll())).single;
      expect(row.body, 'Deep squats');
      expect(row.reason, 'knee');
      expect(find.byType(AvoidTile), findsOneWidget);
    });
  });

  group('hub card', () {
    testWidgets('BodyTodayCard summarises session, water and fasting; tap opens', (tester) async {
      var opened = 0;
      await pumpBodyApp(
        tester,
        home: Scaffold(body: ListView(children: [BodyTodayCard(onOpen: () => opened++)])),
        seed: BodySeed.full,
      );
      expect(find.text(ar.bodyCardTitle), findsOneWidget);
      expect(find.text('١ من ٣'), findsOneWidget);
      expect(find.text('١٫٢٥ لتر'), findsOneWidget);
      // Fasting since yesterday 20:05: 14:35 by 10:40.
      expect(find.text('١٤:٣٥'), findsOneWidget);
      await tester.tap(find.text(ar.bodyCardTitle));
      await frames(tester, n: 4);
      expect(opened, 1);
    });
  });

  testWidgets('reduced motion: every tab builds', (tester) async {
    await pumpBodyApp(tester, home: const BodyScreen(), seed: BodySeed.full, reducedMotion: true);
    for (final tab in [ar.bodyTabPlan, ar.bodyTabFasting, ar.bodyTabWater, ar.bodyTabAvoid, ar.bodyTabToday]) {
      await tester.tap(find.bySemanticsLabel(tab).first);
      await frames(tester, n: 10);
    }
    expect(tester.takeException(), isNull);
  });
}
