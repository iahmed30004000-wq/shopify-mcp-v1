import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/growth/growth.dart';

import 'growth_harness.dart';

Future<void> frames(WidgetTester tester, [int n = 20]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Lets the database stream deliver after a write.
Future<void> settleDb(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<List<GoalLogRow>> logsOf(WidgetTester tester, GrowthTestEnv env) async =>
    (await tester.runAsync(() => env.repos.goalLogs.getAll()))!;

Future<List<ActivityRow>> activity(WidgetTester tester, GrowthTestEnv env) async =>
    (await tester.runAsync(() => env.repos.activityLog.getAll()))!;

void main() {
  testWidgets('empty screen → create a goal in the sheet (Arabic)', (tester) async {
    final env = await pumpGrowthApp(tester, home: const GrowthScreen());
    expect(find.text('ابدأ رحلة تعلّم'), findsOneWidget);

    await tester.tap(find.text('أضف أول هدف'));
    await frames(tester);
    expect(find.text('هدف جديد'), findsWidgets);

    // Saving empty shows the errors (and the error sound).
    await tester.tap(find.text('أنشئ الهدف'));
    await frames(tester, 6);
    expect(find.text('اكتب اسمًا للهدف'), findsOneWidget);
    expect(find.text('أدخل مقدارًا أكبر من صفر'), findsOneWidget);
    expect(env.sound.played, contains(Sfx.error));

    await tester.enterText(find.byKey(const ValueKey('growth-goal-name')), 'قراءة كتاب');
    await tester.tap(find.text('صفحات'));
    await tester.enterText(find.byKey(const ValueKey('growth-goal-target')), '٢٠٠');
    await tester.enterText(find.byKey(const ValueKey('growth-goal-initial')), '٢٠');
    await frames(tester, 4);
    expect(find.text('يجب أن تكون البداية أقل من المستهدف'), findsNothing);
    await tester.tap(find.text('أنشئ الهدف'));
    await frames(tester, 10);
    await settleDb(tester);

    final goals = (await tester.runAsync(() => env.repos.learningGoals.getAll()))!;
    expect(goals, hasLength(1));
    expect(goals.single.name, 'قراءة كتاب');
    expect(goals.single.unit, 'pages');
    expect(goals.single.target, 200);
    expect(goals.single.initial, 20);
    expect(env.sound.played, contains(Sfx.complete));
    expect(find.text('قراءة كتاب'), findsWidgets);
    await frames(tester, 140); // the undo toast times out
  });

  testWidgets('the starting value must stay below the target', (tester) async {
    await pumpGrowthApp(tester, home: const GrowthScreen(), locale: const Locale('en'));
    await tester.tap(find.text('Add your first goal'));
    await frames(tester);
    await tester.enterText(find.byKey(const ValueKey('growth-goal-name')), 'Course');
    await tester.enterText(find.byKey(const ValueKey('growth-goal-target')), '10');
    await tester.enterText(find.byKey(const ValueKey('growth-goal-initial')), '12');
    await tester.tap(find.text('Create goal'));
    await frames(tester, 6);
    expect(find.text('Must be less than the target'), findsOneWidget);
  });

  testWidgets('log from a tile: the sheet records the amount and the growth activity', (tester) async {
    late GrowthScenario s;
    final env = await pumpGrowthApp(
      tester,
      home: const GrowthScreen(),
      locale: const Locale('en'),
      beforePump: (db) async => s = await seedScenario(db, lang: 'en'),
    );
    final before = (await logsOf(tester, env)).length;
    // The first tile's "+" (Read "Atomic Habits").
    await tester.tap(find.bySemanticsLabel('Log progress').first);
    await frames(tester);
    expect(find.text('Read “Atomic Habits”'), findsWidgets);
    await tester.tap(find.text('+20'));
    await frames(tester, 4);
    expect(find.textContaining('New total: 208 of 320 pages'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('growth-log-note')), 'Two chapters');
    await tester.tap(find.text('Log it'));
    await frames(tester, 10);
    await settleDb(tester);

    final logs = await logsOf(tester, env);
    expect(logs, hasLength(before + 1));
    final added = logs.firstWhere((l) => l.note == 'Two chapters');
    expect(added.goalId, s.book.id);
    expect(added.amount, 20);
    expect(added.at, growthTestNow);
    final a = (await activity(tester, env)).firstWhere((a) => a.refId == added.id);
    expect(a.planetKey, 'growth');
    expect(a.value, 20);
    expect(find.textContaining('Logged 20 pages'), findsOneWidget);
    await frames(tester, 140);
  });

  testWidgets('the log sheet refuses zero', (tester) async {
    final env = await pumpGrowthApp(
      tester,
      home: const GrowthScreen(),
      locale: const Locale('en'),
      beforePump: (db) => seedScenario(db, lang: 'en'),
    );
    final before = (await logsOf(tester, env)).length;
    await tester.tap(find.bySemanticsLabel('Log progress').first);
    await frames(tester);
    await tester.enterText(find.byKey(const ValueKey('growth-log-amount')), '0');
    await tester.tap(find.text('Log it'));
    await frames(tester, 6);
    expect(find.text('Enter an amount above zero'), findsOneWidget);
    expect((await logsOf(tester, env)).length, before);
  });

  testWidgets('today card: one tap logs the usual amount; undo removes it', (tester) async {
    final env = await pumpGrowthApp(
      tester,
      home: const Scaffold(body: SingleChildScrollView(child: GrowthTodayCard())),
      locale: const Locale('en'),
      beforePump: (db) => seedScenario(db, lang: 'en'),
    );
    expect(find.text('Growth today'), findsOneWidget);
    // Most urgent first: the overdue coding practice.
    expect(find.text('Coding practice'), findsOneWidget);
    final before = (await logsOf(tester, env)).length;
    await tester.tap(find.text('+2.5'));
    await frames(tester, 6);
    await settleDb(tester);
    expect((await logsOf(tester, env)).length, before + 1);
    expect(env.sound.played, contains(Sfx.complete));

    await tester.tap(find.text('Undo'));
    await frames(tester, 10);
    await settleDb(tester);
    expect((await logsOf(tester, env)).length, before);
    final left = await activity(tester, env);
    expect(left.where((a) => a.value == 2.5 && a.at == growthTestNow), isEmpty);
    await frames(tester, 40);
  });

  testWidgets('reaching the target celebrates', (tester) async {
    late LearningGoalRow goal;
    final env = await pumpGrowthApp(
      tester,
      home: const GrowthScreen(),
      locale: const Locale('en'),
      beforePump: (db) async {
        goal = await seedGoal(
          db,
          const GoalDraft(name: 'Short course', unit: 'lessons', target: 3),
          created: growthTestNow,
        );
        await seedLog(db, goal, 2, growthTestNow.subtract(const Duration(hours: 3)));
      },
    );
    await tester.tap(find.text('Short course'));
    await frames(tester, 30);
    expect(find.byType(GoalScreen), findsOneWidget);
    await tester.tap(find.text('+1').first);
    await frames(tester, 20);
    await settleDb(tester);
    expect(find.text('Goal complete – well done!'), findsOneWidget);
    expect(find.text('3 lessons in 1 day'), findsOneWidget);
    expect(env.sound.played, contains(Sfx.levelUp));
    // No undo toast over the celebration's buttons.
    expect(find.text('Undo'), findsNothing);
    await tester.tap(find.text('Alhamdulillah'));
    await frames(tester, 30);
    await settleDb(tester);
    expect(find.text('Completed'), findsWidgets);
    expect(find.text('Undo'), findsOneWidget, reason: 'the undo comes after the celebration');
    await frames(tester, 140);
  });

  testWidgets('goal page: edit an entry from the history', (tester) async {
    late GrowthScenario s;
    final env = await pumpGrowthApp(
      tester,
      home: const GrowthScreen(),
      locale: const Locale('en'),
      beforePump: (db) async => s = await seedScenario(db, lang: 'en'),
    );
    await tester.tap(find.text('Read “Atomic Habits”'));
    await frames(tester, 30);
    await tester.dragUntilVisible(
      find.text('Chapter on habit stacking'),
      find.byType(ListView).last,
      const Offset(0, -300),
    );
    await frames(tester, 10);
    await tester.tap(find.text('Chapter on habit stacking'));
    await frames(tester, 20);
    expect(find.text('Edit entry'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('growth-log-amount')), '12');
    await tester.tap(find.text('Save'));
    await frames(tester, 10);
    await settleDb(tester);
    final log = (await logsOf(tester, env)).firstWhere((l) => l.note == 'Chapter on habit stacking');
    expect(log.goalId, s.book.id);
    expect(log.amount, 12);
    expect(find.text('Entry updated'), findsOneWidget);
    await frames(tester, 140);
  });

  testWidgets('goal page shows pace, projection and the chart', (tester) async {
    late GrowthScenario s;
    await pumpGrowthApp(
      tester,
      home: Builder(builder: (_) => GoalScreen(goalId: s.book.id)),
      locale: const Locale('en'),
      beforePump: (db) async => s = await seedScenario(db, lang: 'en'),
    );
    expect(find.text('Ahead'), findsOneWidget);
    expect(find.text('132 pages to go'), findsOneWidget);
    expect(find.text('5 pages a day'), findsOneWidget);
    expect(find.text('7 pages a day'), findsOneWidget);
    expect(find.text('Projected finish'), findsOneWidget);
    expect(find.text('10 days early'), findsOneWidget);
    await tester.dragUntilVisible(find.byType(GoalChart), find.byType(ListView).last, const Offset(0, -300));
    expect(find.byType(GoalChart), findsOneWidget);
  });

  testWidgets('reduced motion: logging and celebrating still work', (tester) async {
    late LearningGoalRow goal;
    await pumpGrowthApp(
      tester,
      home: Builder(builder: (_) => GoalScreen(goalId: goal.id)),
      reducedMotion: true,
      beforePump: (db) async {
        goal = await seedGoal(
          db,
          const GoalDraft(name: 'Ten words', unit: 'words', target: 10),
          created: growthTestNow,
        );
      },
    );
    await tester.tap(find.bySemanticsLabel('سجّل ١٠ كلمات'));
    await frames(tester, 20);
    await settleDb(tester);
    expect(find.text('ما شاء الله، أتممتَ هدفك!'), findsOneWidget);
    await frames(tester, 140);
  });
}
