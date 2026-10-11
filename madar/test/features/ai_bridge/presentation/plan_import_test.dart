// Bringing an answer in, inside the real app: the paste box, the file
// picker, the share intent, and – the rule that matters most – a payload
// the validator refuses showing its plain-Arabic problems and NOTHING
// else: no card, no Approve, no crash, no blank screen.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart' show PlanItemState, PlanOrigin;
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/features/ai_bridge/ai_bridge.dart';
import 'package:madar/features/import/import_controller.dart' show importFilePickerProvider;

import 'plan_ui_harness.dart';

void main() {
  final ar = lookupL10n(const Locale('ar'));
  final en = lookupL10n(const Locale('en'));

  group('«استيراد خطة» – the way in', () {
    testWidgets('a good answer pasted opens the plan, with nothing applied yet', (tester) async {
      final app = await pumpPlanApp(tester, initialLocation: AppRoutes.planImport);

      await tester.enterText(find.byKey(const ValueKey('aiPlan.paste')), encodeUiPlan());
      await planFrames(tester, n: 6);
      await tapPlan(tester, find.byKey(const ValueKey('aiPlan.read')), frames: 24);

      // The review screen is open on the plan that just arrived, with the
      // AI's own words about it on the header.
      expect(app.location, startsWith('/plans/plan/'));
      expect(find.textContaining('ثلاث حركات صغيرة'), findsWidgets);

      // Every suggestion is stored, and every one of them is pending: not
      // a single record of his was touched by the import.
      final plans = await planRead(tester, () => app.container.read(planApplyServiceProvider).plans());
      expect(plans, hasLength(1));
      final rows = await planRows(tester, app.db, plans.single.id);
      expect(rows, hasLength(10));
      // x1 is refused by the health guard, so it is stored rejected.
      expect(rows.values.where((r) => r.state == PlanItemState.pending).length, 9);
      expect(rows['x1']!.state, PlanItemState.rejected);
      expect(rows.values.where((r) => r.state == PlanItemState.applied), isEmpty);

      // His data is exactly as it was.
      await planRead(tester, () async {
        final repos = Repositories(app.db);
        expect((await repos.budgetItems.byId('env-grocery'))!.amountMilli, 120000);
        expect((await repos.habits.byId('habit-walk'))!.active, isFalse);
        expect(await repos.foods.getAll(where: (f) => f.name.equals('شوفان')), isEmpty);
        return true;
      });
      await expirePlanToasts(tester);
    });

    testWidgets('a payload that is not a Madar plan shows only its problems', (tester) async {
      final app = await pumpPlanApp(tester, initialLocation: AppRoutes.planImport);

      await tester.enterText(find.byKey(const ValueKey('aiPlan.paste')), notAPlanPayload);
      await planFrames(tester, n: 6);
      await tapPlan(tester, find.byKey(const ValueKey('aiPlan.read')), frames: 20);

      // Still on the import screen, with the problems panel.
      expect(app.location, AppRoutes.planImport);
      await showPlan(tester, find.byKey(const ValueKey('aiPlan.problems')));
      expect(find.byKey(const ValueKey('aiPlan.problems')), findsOneWidget);
      expect(find.text(ar.aiPlanProblemNotAPlan), findsOneWidget);
      expect(find.text(ar.aiPlanProblemsHint), findsOneWidget);

      // Nothing else: no card, no Approve, and nothing stored.
      expect(find.byType(PlanItemCard), findsNothing);
      expect(find.text(ar.aiPlanApproveAction), findsNothing);
      final plans = await planRead(tester, () => app.container.read(planApplyServiceProvider).plans());
      expect(plans, isEmpty);
    });

    testWidgets('a plan with no suggestions says so, and stores nothing', (tester) async {
      final app = await pumpPlanApp(tester, initialLocation: AppRoutes.planImport);

      await tester.enterText(find.byKey(const ValueKey('aiPlan.paste')), emptyPlanPayload);
      await planFrames(tester, n: 6);
      await tapPlan(tester, find.byKey(const ValueKey('aiPlan.read')), frames: 20);

      await showPlan(tester, find.byKey(const ValueKey('aiPlan.problems')));
      expect(find.text(ar.aiPlanProblemNoItems), findsOneWidget);
      expect(find.text(ar.aiPlanApproveAction), findsNothing);
      final plans = await planRead(tester, () => app.container.read(planApplyServiceProvider).plans());
      expect(plans, isEmpty);
    });

    testWidgets('an empty paste box is told so, in English too', (tester) async {
      await pumpPlanApp(tester, initialLocation: AppRoutes.planImport, locale: const Locale('en'));

      await tapPlan(tester, find.byKey(const ValueKey('aiPlan.read')), frames: 10);

      expect(find.text(en.aiPlanPasteEmpty), findsOneWidget);
      expect(find.byKey(const ValueKey('aiPlan.problems')), findsNothing);
    });

    testWidgets('the file picker reads the answer out of a .json', (tester) async {
      final app = await pumpPlanApp(
        tester,
        initialLocation: AppRoutes.planImport,
        overrides: [
          importFilePickerProvider.overrideWithValue(() async => (name: 'madar-plan.json', text: encodeUiPlan())),
        ],
      );

      await tapPlan(tester, find.byKey(const ValueKey('aiPlan.pick')), frames: 26);

      expect(app.location, startsWith('/plans/plan/'));
      final plans = await planRead(tester, () => app.container.read(planApplyServiceProvider).plans());
      expect(plans.single.origin, PlanOrigin.file);
      await expirePlanToasts(tester);
    });

    testWidgets('the same answer imported twice is the same plan', (tester) async {
      final app = await pumpPlanApp(
        tester,
        initialLocation: AppRoutes.planImport,
        beforePump: (db) => importForTest(db, encodeUiPlan()).then((_) {}),
      );

      await tester.enterText(find.byKey(const ValueKey('aiPlan.paste')), encodeUiPlan());
      await planFrames(tester, n: 6);
      await tapPlan(tester, find.byKey(const ValueKey('aiPlan.read')), frames: 24);

      final plans = await planRead(tester, () => app.container.read(planApplyServiceProvider).plans());
      expect(plans, hasLength(1));
      await expirePlanToasts(tester);
    });
  });

  group('the share intent', () {
    testWidgets('an answer shared while Madar runs opens the import screen and the plan', (tester) async {
      final share = FakeShareIntake();
      final app = await pumpPlanApp(tester, initialLocation: AppRoutes.home, share: share);

      share.share(encodeUiPlan(), name: 'plan.json');
      await planFrames(tester, n: 34);

      expect(app.location, startsWith('/plans/plan/'));
      final plans = await planRead(tester, () => app.container.read(planApplyServiceProvider).plans());
      expect(plans.single.origin, PlanOrigin.share);
      // Still nothing applied: a share only ever opens the review.
      final rows = await planRows(tester, app.db, plans.single.id);
      expect(rows.values.any((r) => r.state == PlanItemState.applied), isFalse);
      await expirePlanToasts(tester);
    });

    testWidgets('an answer that launched Madar is read once', (tester) async {
      final share = FakeShareIntake(launch: SharedPlanPayload(encodeUiPlan()));
      final app = await pumpPlanApp(tester, initialLocation: AppRoutes.home, share: share);
      await planFrames(tester, n: 34);

      expect(app.location, startsWith('/plans/plan/'));
      final plans = await planRead(tester, () => app.container.read(planApplyServiceProvider).plans());
      expect(plans, hasLength(1));
      // Nothing is parked any more, so the import screen never re-reads
      // the same answer.
      expect(app.container.read(pendingSharedPlanProvider), isNull);
      await expirePlanToasts(tester);
    });

    testWidgets('a shared payload the validator refuses shows its problems', (tester) async {
      final share = FakeShareIntake();
      final app = await pumpPlanApp(tester, initialLocation: AppRoutes.home, share: share);

      share.share(notAPlanPayload);
      await planFrames(tester, n: 30);

      expect(app.location, AppRoutes.planImport);
      await showPlan(tester, find.byKey(const ValueKey('aiPlan.problems')));
      expect(find.text(ar.aiPlanProblemNotAPlan), findsOneWidget);
      expect(find.text(ar.aiPlanImportShared), findsOneWidget);
      final plans = await planRead(tester, () => app.container.read(planApplyServiceProvider).plans());
      expect(plans, isEmpty);
    });
  });
}
