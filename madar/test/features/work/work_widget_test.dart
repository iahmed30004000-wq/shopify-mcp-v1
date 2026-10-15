import 'package:drift/drift.dart' show BooleanExpressionOperators;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/work/work.dart';

import 'work_harness.dart';

final _ar = lookupL10n(const Locale('ar'));

void main() {
  Future<BoardCardRow> card(WorkTestEnv env, String id) async => (await env.repos.boardCards.byId(id))!;

  testWidgets('RTL board: the first column is on the right, the next one to its left', (tester) async {
    late WorkSeed s;
    await pumpWorkApp(tester, home: Builder(builder: (_) => BoardScreen(boardId: s.store.id)), beforePump: (env) async {
      s = await seedWork(env);
    });
    final todo = tester.getCenter(find.text(_ar.workColTodo).last);
    final doing = tester.getCenter(find.text(_ar.workColDoing).last);
    expect(todo.dx, greaterThan(doing.dx), reason: 'reading order flows right to left');
    expect(find.text('تأكيد طلبات الدفع عند الاستلام'), findsOneWidget);
  });

  testWidgets('long-press drag moves a card to the next column (RTL: to the left), with haptics', (tester) async {
    late WorkSeed s;
    final env = await pumpWorkApp(
      tester,
      home: Builder(builder: (_) => BoardScreen(boardId: s.store.id)),
      beforePump: (env) async => s = await seedWork(env),
    );
    final title = find.text('تصوير المنتجات الجديدة');
    final from = tester.getCenter(title);
    final doingHeader = tester.getCenter(find.text(_ar.workColDoing).last);
    final gesture = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 400));
    expect(env.haptics.fired, contains(Haptic.medium), reason: 'pick-up');
    // Towards the Doing column on the left, in small steps.
    final target = Offset(doingHeader.dx, from.dy + 40);
    for (var i = 1; i <= 12; i++) {
      await gesture.moveTo(Offset.lerp(from, target, i / 12)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.text(_ar.workDropHere), findsOneWidget, reason: 'the drop gap shows');
    await gesture.up();
    await settleWork(tester);
    final moved = await tester.runAsync(() => card(env, s.cards[2].id));
    expect(moved!.columnId, 'doing');
    expect(env.sound.played, contains(Sfx.drop));
  });

  testWidgets('swiping a card toward the next column advances it; undo returns it', (tester) async {
    late WorkSeed s;
    final env = await pumpWorkApp(
      tester,
      home: Builder(builder: (_) => BoardScreen(boardId: s.store.id)),
      beforePump: (env) async => s = await seedWork(env),
    );
    final title = find.text('مراجعة إعلانات الأسبوع');
    // RTL: the next column is on the left.
    await tester.drag(title, const Offset(-260, 0));
    await workFrames(tester);
    final moved = await tester.runAsync(() => card(env, s.cards[1].id));
    expect(moved!.columnId, 'doing');
    expect(env.sound.played, contains(Sfx.swipe));
    expect(find.text(_ar.actionUndo), findsWidgets);
    await tester.tap(find.text(_ar.actionUndo).first);
    await settleWork(tester);
    final back = await tester.runAsync(() => card(env, s.cards[1].id));
    expect(back!.columnId, 'todo');
  });

  testWidgets('swiping toward a column that does not exist does nothing', (tester) async {
    late WorkSeed s;
    final env = await pumpWorkApp(
      tester,
      home: Builder(builder: (_) => BoardScreen(boardId: s.store.id)),
      beforePump: (env) async => s = await seedWork(env),
    );
    await tester.drag(find.text('مراجعة إعلانات الأسبوع'), const Offset(260, 0));
    await settleWork(tester);
    expect((await tester.runAsync(() => card(env, s.cards[1].id)))!.columnId, 'todo');
  });

  testWidgets('Top 3: finishing the last one celebrates with a chime and completes the card', (tester) async {
    late WorkSeed s;
    final env = await pumpWorkApp(
      tester,
      home: const Scaffold(body: SingleChildScrollView(child: Top3Card())),
      beforePump: (env) async {
        s = await seedWork(env);
        await env.service.moveCard(s.cards[0].id, 'done');
        await env.service.moveCard(s.cards[3].id, 'done');
      },
    );
    expect(find.text('تحويل مستحقات المندوبين'), findsOneWidget);
    await tester.tap(find.text('تحويل مستحقات المندوبين'));
    await settleWork(tester);
    expect(env.sound.played, contains(Sfx.levelUp));
    final c = await tester.runAsync(() => card(env, s.cards[4].id));
    expect(c!.columnId, 'done');
    // Its placed task was completed too (the home panel shows it done).
    final tasks = await tester.runAsync(() => env.repos.tasks.getAll(where: (t) => t.cardId.equals(c.id)));
    expect(tasks!.single.done, isTrue);
    expect(find.text(_ar.workTop3AllDone), findsOneWidget);
  });

  testWidgets('next morning: carry over keeps yesterday\'s unfinished focus', (tester) async {
    await pumpWorkApp(
      tester,
      home: const Scaffold(body: SingleChildScrollView(child: Top3Card())),
      now: workTestNow.add(const Duration(days: 1)),
      beforePump: (env) async => seedWork(env, at: workTestNow),
    );
    expect(find.text(_ar.workCarryTitle), findsOneWidget);
    await tester.tap(find.text(_ar.workCarryOver));
    await settleWork(tester);
    expect(find.text(_ar.workCarryTitle), findsNothing);
    expect(find.text('تأكيد طلبات الدفع عند الاستلام'), findsOneWidget);
  });

  testWidgets('project: ticking the last step celebrates at 100 %', (tester) async {
    late WorkSeed s;
    final env = await pumpWorkApp(
      tester,
      home: Builder(builder: (_) => ProjectScreen(projectId: s.project.id)),
      beforePump: (env) async {
        s = await seedWork(env);
        final items = await env.repos.projectItems.getAll(where: (i) => i.projectId.equals(s.project.id) & i.done.equals(false));
        for (final i in items.skip(1)) {
          await env.service.toggleItem(i);
        }
      },
    );
    await tester.tap(find.text('الاتفاق مع شركة الشحن'));
    await workFrames(tester);
    expect(env.sound.played, contains(Sfx.levelUp));
    expect(find.text(_ar.workProjectComplete), findsOneWidget);
    await settleWork(tester);
    final logged = await tester.runAsync(
      () => env.repos.activityLog.getAll(where: (a) => a.kind.equals(WorkService.itemDoneKind)),
    );
    expect(logged!.map((a) => a.planetKey).toSet(), {'work'});
  });

  testWidgets('fresh install: empty Work screen with a generic example only', (tester) async {
    await pumpWorkApp(tester, home: const WorkScreen());
    expect(find.text(_ar.workBoardsEmptyTitle), findsOneWidget);
    expect(find.text(_ar.workTop3Empty), findsOneWidget);
  });

  testWidgets('English board flows left to right', (tester) async {
    late WorkSeed s;
    await pumpWorkApp(
      tester,
      locale: const Locale('en'),
      home: Builder(builder: (_) => BoardScreen(boardId: s.store.id)),
      beforePump: (env) async => s = await seedWork(env, lang: 'en'),
    );
    final todo = tester.getCenter(find.text('To-do').last);
    final doing = tester.getCenter(find.text('Doing').last);
    expect(todo.dx, lessThan(doing.dx));
  });

  testWidgets('reduced motion: swipe still moves the card', (tester) async {
    late WorkSeed s;
    final env = await pumpWorkApp(
      tester,
      reducedMotion: true,
      home: Builder(builder: (_) => BoardScreen(boardId: s.store.id)),
      beforePump: (env) async => s = await seedWork(env),
    );
    await tester.drag(find.text('مراجعة إعلانات الأسبوع'), const Offset(-260, 0));
    await settleWork(tester);
    expect((await tester.runAsync(() => card(env, s.cards[1].id)))!.columnId, 'doing');
  });

  testWidgets('placing a card in a window from its menu creates the home task', (tester) async {
    late WorkSeed s;
    final env = await pumpWorkApp(
      tester,
      home: Builder(builder: (_) => BoardScreen(boardId: s.store.id)),
      beforePump: (env) async => s = await seedWork(env),
    );
    final c = await tester.runAsync(() => card(env, s.cards[2].id));
    final undo = await tester.runAsync(() => env.service.placeCard(c!, PrayerWindow.maghrib));
    await settleWork(tester);
    final tasks = await tester.runAsync(() => env.repos.tasks.getAll(where: (t) => t.cardId.equals(s.cards[2].id)));
    expect(tasks!.single.window, PrayerWindow.maghrib);
    expect(find.text(_ar.windowMaghrib), findsWidgets);
    await tester.runAsync(undo!);
  });

  testWidgets('filter by due date and assignee', (tester) async {
    late WorkSeed s;
    await pumpWorkApp(
      tester,
      home: Builder(builder: (_) => BoardScreen(boardId: s.store.id)),
      beforePump: (env) async => s = await seedWork(env),
    );
    await tester.tap(find.byIcon(Icons.filter_list_rounded).first);
    await settleWork(tester);
    await tester.tap(find.text(_ar.workFilterToday).first);
    await settleWork(tester);
    expect(find.text('تأكيد طلبات الدفع عند الاستلام'), findsOneWidget);
    expect(find.text('تصوير المنتجات الجديدة'), findsNothing);
    await tester.tap(find.text(_ar.workFilterClear).first);
    await settleWork(tester);
    await tester.tap(find.text('ليلى').first);
    await settleWork(tester);
    expect(find.text('تصوير المنتجات الجديدة'), findsOneWidget);
    expect(find.text('مراجعة إعلانات الأسبوع'), findsNothing);
  });
}
