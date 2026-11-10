// The owner's own ask: the suggestions he approved gathered under one
// named list he ticks off and sees «٢ من ٤» on – plus the renaming, the
// honest before/after, the history, and the line on the home panel that
// brings him back to an unfinished list.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart' show PlanItemState;
import 'package:madar/core/i18n/formatters.dart' show BidiIsolate;
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/features/ai_bridge/ai_bridge.dart';

import '../../../helpers/test_app.dart';
import 'plan_ui_harness.dart';

/// Approves [ids] through the engine, exactly as a tap on each card would
/// – one call per suggestion, never a loop inside the engine.
Future<void> approveForTest(MadarDatabase db, String planId, List<String> ids) async {
  final repos = Repositories(db);
  final service = PlanApplyService(repos, clock: () => planUiNow);
  final catalog = await AiBridgeRepository(repos).loadCatalog(planUiNow);
  for (final id in ids) {
    final plan = (await service.planById(planId))!;
    final import = await service.reopen(plan, catalog: catalog);
    await service.applyItem(plan, import.preview(id)!);
  }
}

void main() {
  final ar = lookupL10n(const Locale('ar'));
  final en = lookupL10n(const Locale('en'));

  Finder line(String id) => find.byKey(ValueKey('aiPlan.line.$id'));

  /// The app on the plan's checklist, with the owner's own four lines
  /// approved: ☐ امشي ٢٠ دقيقة بعد العشا · ☐ راجع فاتورة الكهربا ·
  /// ☐ سجّل أكلك ٥ أيام متواصلة · ☐ اتصل بأمك يوم الجمعة.
  Future<(TestApp, String)> openList(WidgetTester tester, {Locale locale = const Locale('ar')}) async {
    String? planId;
    final app = await pumpPlanApp(
      tester,
      initialLocation: AppRoutes.plans,
      locale: locale,
      beforePump: (db) async {
        planId = (await importForTest(db, encodeUiPlan())).id;
        await approveForTest(db, planId!, ['h1', 't1', 'd1', 'e1']);
      },
    );
    await tapPlan(tester, find.byKey(ValueKey('aiPlan.history.$planId')), frames: 26);
    await tapPlan(tester, find.byKey(const ValueKey('aiPlan.tab.list')), frames: 22);
    return (app, planId!);
  }

  group('the checklist', () {
    testWidgets('the approved suggestions are the list, and the counter reads «٠ من ٤»', (tester) async {
      final (app, planId) = await openList(tester);

      expect(line('h1'), findsOneWidget);
      expect(line('t1'), findsOneWidget);
      expect(line('d1'), findsOneWidget);
      expect(line('e1'), findsOneWidget);
      // Nothing he refused or never decided is on the list.
      expect(line('b1'), findsNothing);
      expect(line('x1'), findsNothing);
      expect(line('n1'), findsNothing);

      final progress = app.container.read(planProgressProvider(planId)).value!;
      expect(progress.total, 4);
      expect(progress.done, 0);
      expect(find.text('٠ من ٤'), findsWidgets);
    });

    testWidgets('ticking two lines reads «٢ من ٤», and a tick undoes', (tester) async {
      final (app, planId) = await openList(tester);

      await tapPlan(tester, line('t1'), frames: 22);
      expect(find.text(ar.aiPlanTickedToast(BidiIsolate.isolate('راجع فاتورة الكهربا'))), findsOneWidget);
      await expirePlanToasts(tester);
      await tapPlan(tester, line('d1'), frames: 22);

      expect(find.text('٢ من ٤'), findsWidgets);
      final rows = await planRows(tester, app.db, planId);
      expect(rows['t1']!.done, isTrue);
      expect(rows['d1']!.done, isTrue);

      // Undo the second tick.
      await tapPlan(tester, find.text(ar.actionUndo), frames: 22);
      expect((await planRows(tester, app.db, planId))['d1']!.done, isFalse);
      expect(find.text('١ من ٤'), findsWidgets);
      await expirePlanToasts(tester);
    });

    testWidgets('un-ticking a line says so, and undoes too', (tester) async {
      final (app, planId) = await openList(tester);

      await tapPlan(tester, line('t1'), frames: 20);
      await expirePlanToasts(tester);
      await tapPlan(tester, line('t1'), frames: 20);

      expect(find.text(ar.aiPlanUntickedToast(BidiIsolate.isolate('راجع فاتورة الكهربا'))), findsOneWidget);
      expect((await planRows(tester, app.db, planId))['t1']!.done, isFalse);
      await tapPlan(tester, find.text(ar.actionUndo), frames: 20);
      expect((await planRows(tester, app.db, planId))['t1']!.done, isTrue);
      await expirePlanToasts(tester);
    });

    testWidgets('ticking everything says the list is done, in English too', (tester) async {
      final (app, _) = await openList(tester, locale: const Locale('en'));

      for (final id in ['h1', 't1', 'd1', 'e1']) {
        await tapPlan(tester, line(id), frames: 18);
        await expirePlanToasts(tester);
      }
      await showPlan(tester, find.text(en.aiPlanChecklistAllDone));
      expect(find.text(en.aiPlanChecklistAllDone), findsOneWidget);
      expect(find.text('4 of 4'), findsWidgets);
      expect(app.location, startsWith('/plans/plan/'));
    });

    testWidgets('a plan with nothing approved yet shows the warm empty state', (tester) async {
      String? planId;
      await pumpPlanApp(
        tester,
        initialLocation: AppRoutes.plans,
        beforePump: (db) async => planId = (await importForTest(db, encodeUiPlan())).id,
      );
      await tapPlan(tester, find.byKey(ValueKey('aiPlan.history.$planId')), frames: 26);
      await tapPlan(tester, find.byKey(const ValueKey('aiPlan.tab.list')), frames: 22);

      expect(find.byKey(const ValueKey('aiPlan.list.empty')), findsOneWidget);
      expect(find.text(ar.aiPlanChecklistEmpty), findsOneWidget);
    });

    testWidgets('the name of the list is his, and the rename undoes', (tester) async {
      final (app, planId) = await openList(tester);

      await tapPlan(tester, find.byKey(const ValueKey('aiPlan.rename')), frames: 20);
      await tester.enterText(find.byType(TextField).first, 'خطة تشرين الثاني');
      await planFrames(tester, n: 6);
      await tapPlan(tester, find.text(ar.actionSave), frames: 24);

      final renamed = await planRead(tester, () => app.container.read(planApplyServiceProvider).planById(planId));
      expect(renamed!.name, 'خطة تشرين الثاني');
      expect(find.textContaining('خطة تشرين الثاني'), findsWidgets);

      await tapPlan(tester, find.text(ar.actionUndo), frames: 22);
      final back = await planRead(tester, () => app.container.read(planApplyServiceProvider).planById(planId));
      expect(back!.name, 'خطة تشرين الأول');
      await expirePlanToasts(tester);
    });
  });

  group('before and after', () {
    /// The checklist of a plan with `b1` approved, after [then] has had its
    /// way with his data.
    Future<TestApp> openPair(WidgetTester tester, {Future<void> Function(MadarDatabase db)? then}) async {
      String? planId;
      final app = await pumpPlanApp(
        tester,
        initialLocation: AppRoutes.plans,
        beforePump: (db) async {
          planId = (await importForTest(db, encodeUiPlan())).id;
          await approveForTest(db, planId!, ['b1']);
          if (then != null) await then(db);
        },
      );
      await tapPlan(tester, find.byKey(ValueKey('aiPlan.history.$planId')), frames: 26);
      await tapPlan(tester, find.byKey(const ValueKey('aiPlan.tab.list')), frames: 22);
      return app;
    }

    testWidgets('an approved budget tweak shows the pair, before and now', (tester) async {
      final app = await openPair(tester);

      await showPlan(tester, line('b1'));
      expect(
        find.descendant(of: line('b1'), matching: find.textContaining(ar.aiPlanAfterBefore('').trim())),
        findsOneWidget,
      );
      expect(
        find.descendant(of: line('b1'), matching: find.textContaining(ar.aiPlanAfterNow('').trim())),
        findsOneWidget,
      );
      expect(find.descendant(of: line('b1'), matching: find.text(ar.aiPlanAfterMoved)), findsNothing);
      expect(app.location, startsWith('/plans/plan/'));
    });

    testWidgets('a number he moved himself afterwards says so, honestly', (tester) async {
      await openPair(
        tester,
        then: (db) => Repositories(db).budgetItems.setColumns('env-grocery', {'amountMilli': 90000}),
      );

      await showPlan(tester, line('b1'));
      expect(find.descendant(of: line('b1'), matching: find.text(ar.aiPlanAfterMoved)), findsOneWidget);
    });

    testWidgets('a record he deleted afterwards says that instead', (tester) async {
      await openPair(tester, then: (db) => Repositories(db).budgetItems.delete('env-grocery').then((_) {}));

      await showPlan(tester, line('b1'));
      expect(find.descendant(of: line('b1'), matching: find.text(ar.aiPlanAfterGone)), findsOneWidget);
    });
  });

  group('the history', () {
    testWidgets('a fresh install starts empty, with a warm way in', (tester) async {
      final app = await pumpPlanApp(tester, initialLocation: AppRoutes.plans);

      expect(find.byKey(const ValueKey('aiPlan.history.empty')), findsOneWidget);
      expect(find.text(ar.aiPlanHistoryEmptyTitle), findsOneWidget);
      expect(find.text(ar.aiPlanHistoryEmptyBody), findsOneWidget);

      await tapPlan(tester, find.text(ar.aiPlanImportTitle).first, frames: 22);
      expect(app.location, AppRoutes.planImport);
    });

    testWidgets('an old plan opens again, measured against his data as it is now', (tester) async {
      String? planId;
      final app = await pumpPlanApp(
        tester,
        initialLocation: AppRoutes.plans,
        beforePump: (db) async {
          planId = (await importForTest(db, encodeUiPlan())).id;
          await approveForTest(db, planId!, ['f1']);
        },
      );

      expect(find.byKey(ValueKey('aiPlan.history.$planId')), findsOneWidget);
      await tapPlan(tester, find.byKey(ValueKey('aiPlan.history.$planId')), frames: 28);
      expect(app.location, '/plans/plan/$planId');

      // `f1` was approved before this screen ever opened, so the meal
      // change that was waiting for it is ready now – the plan was read
      // against his data, not replayed from what arrived.
      final m1 = find.byKey(const ValueKey('aiPlan.card.m1'));
      await showPlan(tester, m1);
      expect(find.descendant(of: m1, matching: find.text(ar.aiPlanStatusReady)), findsOneWidget);
      expect(find.byKey(const ValueKey('aiPlan.approve.m1')), findsOneWidget);
    });

    testWidgets('a plan that is not there says so instead of a blank screen', (tester) async {
      await pumpPlanApp(tester, initialLocation: AppRoutes.planOf('no-such-plan'));
      expect(find.byKey(const ValueKey('aiPlan.missing')), findsOneWidget);
      expect(find.text(ar.aiPlanMissing), findsOneWidget);
    });
  });

  group('the line on the home panel', () {
    testWidgets('nothing shows while no plan has an open line', (tester) async {
      await pumpPlanApp(tester, initialLocation: AppRoutes.home);
      expect(find.byKey(const ValueKey('aiPlan.homeStrip')), findsNothing);
    });

    testWidgets('an unfinished list shows its next line and its count, and opens it', (tester) async {
      String? planId;
      final app = await pumpPlanApp(
        tester,
        initialLocation: AppRoutes.home,
        beforePump: (db) async {
          planId = (await importForTest(db, encodeUiPlan())).id;
          await approveForTest(db, planId!, ['h1', 't1', 'd1', 'e1']);
        },
      );
      await planFrames(tester, n: 16);

      final strip = find.byKey(const ValueKey('aiPlan.homeStrip'));
      expect(strip, findsOneWidget);
      expect(find.descendant(of: strip, matching: find.text('٠ من ٤')), findsOneWidget);
      expect(
        find.descendant(of: strip, matching: find.text(BidiIsolate.isolate('امشي عشرين دقيقة بعد العشا'))),
        findsOneWidget,
      );

      await tapPlan(tester, strip, frames: 28);
      // Straight onto the list, not onto the suggestions (the matched
      // location carries no query, so the open tab is what proves it).
      expect(app.location, '/plans/plan/$planId');
      expect(find.byKey(const ValueKey('aiPlan.line.h1')), findsOneWidget);
      expect(find.byKey(const ValueKey('aiPlan.list.progress')), findsOneWidget);
    });

    testWidgets('a list that is finished takes the line away again', (tester) async {
      await pumpPlanApp(
        tester,
        initialLocation: AppRoutes.home,
        beforePump: (db) async {
          final planId = (await importForTest(db, encodeUiPlan())).id;
          await approveForTest(db, planId, ['t1']);
          final service = PlanApplyService(Repositories(db), clock: () => planUiNow);
          final rows = await service.checklist(planId);
          await service.setDone(rows.single, true);
        },
      );
      await planFrames(tester, n: 16);
      expect(find.byKey(const ValueKey('aiPlan.homeStrip')), findsNothing);
    });

    testWidgets('an item he never approved is never on a list, and cannot be ticked', (tester) async {
      String? planId;
      final app = await pumpPlanApp(
        tester,
        initialLocation: AppRoutes.plans,
        beforePump: (db) async => planId = (await importForTest(db, encodeUiPlan())).id,
      );
      final rows = await planRows(tester, app.db, planId!);
      expect(rows['t1']!.state, PlanItemState.pending);
      await tester.runAsync(() async {
        await expectLater(
          () => app.container.read(planApplyServiceProvider).setDone(rows['t1']!, true),
          throwsA(isA<PlanApplyRefused>()),
        );
      });
    });
  });
}
