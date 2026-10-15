// The review screen, inside the real app: every suggestion read card by
// card, and the three rules that must never bend –
//
//  * nothing is applied without his tap on THAT card (there is no
//    apply-all, in any wording);
//  * approving one suggestion unblocks the one that was waiting for it,
//    because the plan is re-opened against his data as it is now;
//  * a health-refused suggestion can never be approved, however hard a
//    test tries: no button on the card, and the engine says no as well.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart' show PlanItemState;
import 'package:madar/core/i18n/formatters.dart' show BidiIsolate;
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/features/ai_bridge/ai_bridge.dart';

import '../../../helpers/test_app.dart';
import 'plan_ui_harness.dart';

void main() {
  final ar = lookupL10n(const Locale('ar'));
  final en = lookupL10n(const Locale('en'));

  Finder card(String id) => find.byKey(ValueKey('aiPlan.card.$id'));
  Finder approve(String id) => find.byKey(ValueKey('aiPlan.approve.$id'));
  Finder reject(String id) => find.byKey(ValueKey('aiPlan.reject.$id'));
  Finder edit(String id) => find.byKey(ValueKey('aiPlan.edit.$id'));

  /// The app on the plan's review screen, with the fixture answer stored.
  Future<(TestApp, String)> openPlan(WidgetTester tester, {Locale locale = const Locale('ar')}) async {
    String? planId;
    final app = await pumpPlanApp(
      tester,
      initialLocation: AppRoutes.plans,
      locale: locale,
      beforePump: (db) async => planId = (await importForTest(db, encodeUiPlan())).id,
    );
    await tapPlan(tester, find.byKey(ValueKey('aiPlan.history.$planId')), frames: 26);
    return (app, planId!);
  }

  group('the review screen', () {
    testWidgets('every suggestion is a card with its change, its reason and what it is today', (tester) async {
      await openPlan(tester);

      expect(find.byType(PlanItemCard), findsWidgets);
      await showPlan(tester, card('b1'));
      expect(find.descendant(of: card('b1'), matching: find.text('نزّل مصروف البقالة لمية')), findsOneWidget);
      // The AI's reason, in its own words.
      expect(
        find.descendant(of: card('b1'), matching: find.text('آخر ثلاث شهور صرفت أقل من المرصود بعشرين دينار.')),
        findsOneWidget,
      );
      // What it would change, what it is today, and its state.
      expect(find.descendant(of: card('b1'), matching: find.text(ar.aiPlanChangeTitle)), findsOneWidget);
      expect(find.descendant(of: card('b1'), matching: find.text(ar.aiPlanBeforeTitle)), findsOneWidget);
      expect(find.descendant(of: card('b1'), matching: find.textContaining('بقالة')), findsWidgets);
      expect(find.descendant(of: card('b1'), matching: find.text(ar.aiPlanStatusReady)), findsOneWidget);
    });

    testWidgets('the provenance and the flagged claims are a warning, never an item', (tester) async {
      await openPlan(tester);

      await showPlan(tester, find.text(ar.aiPlanSourceTitle));
      expect(find.text(ar.aiPlanSourceTitle), findsOneWidget);
      expect(find.textContaining('حلقة عن الأكل'), findsWidgets);
      expect(find.text(ar.aiPlanSourcePartial(BidiIsolate.isolate('النص بيوقف عند النص'))), findsOneWidget);
      expect(find.text(ar.aiPlanClaimsTitle), findsOneWidget);
      expect(find.text(ar.aiPlanClaimsBody), findsOneWidget);
      // A claim is never a card, so it has no Approve of its own: the only
      // Approve buttons on the screen belong to suggestions.
      final approvals = find.byWidgetPredicate(
        (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('aiPlan.approve.'),
      );
      for (final w in tester.widgetList(approvals)) {
        final id = (w.key! as ValueKey<String>).value.split('.').last;
        expect(['b1', 'h1', 'f1', 't1', 'd1', 'e1', 'n1'], contains(id));
      }
    });

    testWidgets('a suggestion waiting for another one names it, and has no Approve', (tester) async {
      await openPlan(tester);

      await showPlan(tester, card('m1'));
      expect(find.descendant(of: card('m1'), matching: find.text(ar.aiPlanStatusBlocked)), findsOneWidget);
      // Named, never an id.
      expect(
        find.descendant(of: card('m1'), matching: find.text(ar.aiPlanWaitingFor(BidiIsolate.isolate('شوفان')))),
        findsOneWidget,
      );
      expect(approve('m1'), findsNothing);
    });

    testWidgets('approving the food unblocks the meal change, in front of him', (tester) async {
      final (app, planId) = await openPlan(tester);

      await tapPlan(tester, approve('f1'), frames: 28);

      // His data really changed – one suggestion, by his own tap.
      await planRead(tester, () async {
        expect(await Repositories(app.db).foods.getAll(where: (f) => f.name.equals('شوفان')), hasLength(1));
        return true;
      });

      // And the one that was waiting for it is ready now.
      await showPlan(tester, card('m1'));
      expect(find.descendant(of: card('m1'), matching: find.text(ar.aiPlanStatusReady)), findsOneWidget);
      expect(approve('m1'), findsOneWidget);

      final rows = await planRows(tester, app.db, planId);
      expect(rows['f1']!.state, PlanItemState.applied);
      expect(rows['m1']!.state, PlanItemState.pending);
      await expirePlanToasts(tester);
    });

    testWidgets('approving the budget tweak writes the envelope, and undo puts it back', (tester) async {
      final (app, planId) = await openPlan(tester);

      await tapPlan(tester, approve('b1'), frames: 26);
      await planRead(tester, () async {
        expect((await Repositories(app.db).budgetItems.byId('env-grocery'))!.amountMilli, 100000);
        return true;
      });
      expect((await planRows(tester, app.db, planId))['b1']!.state, PlanItemState.applied);

      // The app's own undo toast, like every other write in Madar.
      expect(
        find.text(ar.aiPlanApprovedToast(BidiIsolate.isolate('نزّل مصروف البقالة لمية'))),
        findsOneWidget,
      );
      await tapPlan(tester, find.text(ar.actionUndo), frames: 26);

      await planRead(tester, () async {
        expect((await Repositories(app.db).budgetItems.byId('env-grocery'))!.amountMilli, 120000);
        return true;
      });
      expect((await planRows(tester, app.db, planId))['b1']!.state, PlanItemState.undone);
      await expirePlanToasts(tester);
    });

    testWidgets('approving one suggestion leaves every other one alone', (tester) async {
      final (app, planId) = await openPlan(tester);

      await tapPlan(tester, approve('b1'), frames: 26);

      // Only b1 moved: the habit is still off, no food was added, and
      // every other suggestion is still pending.
      await planRead(tester, () async {
        final repos = Repositories(app.db);
        expect((await repos.habits.byId('habit-walk'))!.active, isFalse);
        expect(await repos.foods.getAll(where: (f) => f.name.equals('شوفان')), isEmpty);
        return true;
      });
      final rows = await planRows(tester, app.db, planId);
      expect(rows['b1']!.state, PlanItemState.applied);
      for (final id in ['h1', 'f1', 'm1', 't1', 'd1', 'e1', 'p1', 'n1']) {
        expect(rows[id]!.state, PlanItemState.pending, reason: id);
      }
      await expirePlanToasts(tester);
    });

    testWidgets('he can refuse one, with undo', (tester) async {
      final (app, planId) = await openPlan(tester);

      await tapPlan(tester, reject('t1'), frames: 26);
      expect((await planRows(tester, app.db, planId))['t1']!.state, PlanItemState.rejected);
      expect(find.text(ar.aiPlanRejectedToast(BidiIsolate.isolate('راجع فاتورة الكهربا'))), findsOneWidget);

      await tapPlan(tester, find.text(ar.actionUndo), frames: 26);
      expect((await planRows(tester, app.db, planId))['t1']!.state, PlanItemState.pending);
      await expirePlanToasts(tester);
    });

    testWidgets('a day that has passed is edited before it can be approved', (tester) async {
      final (app, planId) = await openPlan(tester);

      await showPlan(tester, card('p1'));
      expect(find.descendant(of: card('p1'), matching: find.text(ar.aiPlanStatusNeedsEdit)), findsOneWidget);
      expect(find.descendant(of: card('p1'), matching: find.text(ar.aiPlanEditDayPassed)), findsOneWidget);
      // No Approve at all while it needs an edit.
      expect(approve('p1'), findsNothing);
      expect(edit('p1'), findsOneWidget);

      // The day the AI sent is the one on the card.
      String whenLine() => tester
          .widget<Text>(
            find
                .descendant(of: card('p1'), matching: find.textContaining(ar.aiPlanChangeTaskWhen('').trim()))
                .first,
          )
          .data!;
      final sentDay = whenLine();
      expect(sentDay, isNotEmpty);

      await tapPlan(tester, edit('p1'), frames: 20);
      // The sheet opens on today, which is inside the window: saving is
      // enough to settle the suggestion.
      await tapPlan(tester, find.text(ar.actionSave), frames: 24);

      await showPlan(tester, card('p1'));
      expect(find.descendant(of: card('p1'), matching: find.text(ar.aiPlanStatusReady)), findsOneWidget);
      expect(approve('p1'), findsOneWidget);
      // The card now reads his own day, not the one the AI sent.
      expect(whenLine(), isNot(sentDay));
      // Still nothing written: the edit alone changes nothing.
      expect((await planRows(tester, app.db, planId))['p1']!.state, PlanItemState.pending);
      await expirePlanToasts(tester);

      // And it is his tap on Approve that writes it.
      await tapPlan(tester, approve('p1'), frames: 26);
      expect((await planRows(tester, app.db, planId))['p1']!.state, PlanItemState.applied);
      await expirePlanToasts(tester);
    });

    testWidgets('a note says plainly that it is a list line only', (tester) async {
      await openPlan(tester);
      await showPlan(tester, card('n1'));
      expect(find.descendant(of: card('n1'), matching: find.text(ar.aiPlanChecklistOnly)), findsOneWidget);
    });
  });

  group('health: track and practise only', () {
    testWidgets('a dose is refused with the words that tripped it, and cannot be approved', (tester) async {
      final (app, planId) = await openPlan(tester);

      await showPlan(tester, card('x1'));
      expect(find.descendant(of: card('x1'), matching: find.text(ar.aiPlanStatusRejected)), findsOneWidget);
      // The refusal quotes the words it hit on.
      expect(find.descendant(of: card('x1'), matching: find.textContaining('ملغ')), findsWidgets);
      expect(find.descendant(of: card('x1'), matching: find.text(ar.aiPlanCannotApprove)), findsOneWidget);

      // However hard the test tries: no button to tap…
      expect(approve('x1'), findsNothing);
      expect(edit('x1'), findsNothing);
      expect(reject('x1'), findsNothing);

      // …and the engine refuses it too, so no caller can route around the
      // screen. Nothing is written either way.
      await tester.runAsync(() async {
        final data = await app.container.read(planReviewProvider(planId).future);
        final refused = data!.previews.firstWhere((p) => p.id == 'x1');
        expect(refused.canApply, isFalse);
        await expectLater(
          () => app.container.read(planApplyServiceProvider).applyItem(data.plan!, refused),
          throwsA(isA<PlanApplyRefused>()),
        );
      });
      final rows = await planRows(tester, app.db, planId);
      expect(rows['x1']!.state, PlanItemState.rejected);
      expect(rows['x1']!.refTable, isNull);
      expect(rows['x1']!.refId, isNull);
    });

    testWidgets('the same refusal reads in English', (tester) async {
      await openPlan(tester, locale: const Locale('en'));
      await showPlan(tester, card('x1'));
      expect(find.descendant(of: card('x1'), matching: find.text(en.aiPlanStatusRejected)), findsOneWidget);
      expect(find.descendant(of: card('x1'), matching: find.text(en.aiPlanCannotApprove)), findsOneWidget);
      expect(approve('x1'), findsNothing);
    });
  });
}
