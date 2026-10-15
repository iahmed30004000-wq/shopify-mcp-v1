import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/interaction/interaction.dart';
import 'package:madar/core/notifications/notification_models.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/money/goals/goals.dart';

import 'goals_harness.dart';

DateTime d(int y, int m, int day) => DateTime(y, m, day);

NotificationTap _tapFor(GoalsNotice n) =>
    NotificationTap(id: n.id, namespace: GoalsReminderIds.namespace.name, data: n.data);

void main() {
  group('GoalsScreen', () {
    testWidgets('a fresh install shows calm empty states on every tab', (tester) async {
      final env = await pumpGoalsApp(tester, home: const GoalsScreen(), seed: false);
      expect(find.text('لا حصّالات بعد'), findsOneWidget);
      await tester.tap(find.text('الديون'));
      await settleGoals(tester);
      expect(find.text('لا ديون مسجّلة'), findsOneWidget);
      await tester.tap(find.text('الالتزامات'));
      await settleGoals(tester);
      expect(find.text('لا التزامات دورية'), findsOneWidget);
      expect(env.haptics.fired, isNotEmpty, reason: 'tab switches fire feedback');
      expect(await tester.runAsync(() => env.repos.jars.count()), 0);
    });

    testWidgets('jars: totals, pace and tiles in Arabic', (tester) async {
      await pumpGoalsApp(tester, home: const GoalsScreen());
      expect(find.text('سفر العائلة'), findsOneWidget);
      expect(find.text('المدّخر في الحصّالات'), findsOneWidget);
      expect(find.text('على المسار'), findsOneWidget);
      expect(find.text('متأخرة عن الخطة'), findsOneWidget);
      expect(find.text('بلغت الهدف'), findsOneWidget);
      // Archived jars stay folded away.
      expect(find.text('دورة لغة'), findsNothing);
      await tester.ensureVisible(find.text('إظهار'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('إظهار'));
      await settleGoals(tester);
      expect(find.text('دورة لغة'), findsOneWidget);
    });

    testWidgets('swiping an obligation marks it paid, and undo restores the date', (tester) async {
      final env = await pumpGoalsApp(tester, home: const GoalsScreen(initialTab: GoalsTab.obligations));
      expect(find.text('اشتراك الإنترنت'), findsOneWidget);
      await tester.drag(find.text('اشتراك الإنترنت'), const Offset(260, 0));
      await settleGoals(tester, andSettle: false);
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 50));
      }
      var ob = await tester.runAsync(() => env.repos.obligations.byId(GoalsSeedIds.obInternet));
      expect(ob!.nextDue, d(2026, 10, 27));
      final pays = await tester.runAsync(
        () => env.repos.obligationPayments.getAll(where: (t) => t.obligationId.equals(GoalsSeedIds.obInternet)),
      );
      expect(pays!.single.dueDate, d(2026, 9, 27));
      final tx = await tester.runAsync(() => env.repos.transactions.byId(pays.single.transactionId!));
      expect(tx!.kind, TxKind.expense);
      expect(tx.walletId, GoalsSeedIds.walletCash);
      expect(env.haptics.fired, contains(Haptic.success));

      await tester.tap(find.text('تراجع').last);
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 50));
      }
      ob = await tester.runAsync(() => env.repos.obligations.byId(GoalsSeedIds.obInternet));
      expect(ob!.nextDue, d(2026, 9, 27));
      expect(await tester.runAsync(() => env.repos.transactions.count()), 0);
      await tester.pumpAndSettle(const Duration(seconds: 20));
    });

    testWidgets('swiping a debt settles it', (tester) async {
      final env = await pumpGoalsApp(tester, home: const GoalsScreen(initialTab: GoalsTab.debts));
      expect(find.text('صديق'), findsOneWidget);
      await tester.drag(find.text('صديق'), const Offset(260, 0));
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 50));
      }
      final debt = await tester.runAsync(() => env.repos.debts.byId(GoalsSeedIds.debtFriend));
      expect(debt!.settledAt, isNotNull);
      await tester.pumpAndSettle(const Duration(seconds: 20));
    });

    testWidgets('the debt filter narrows the list', (tester) async {
      await pumpGoalsApp(
        tester,
        home: const GoalsScreen(initialTab: GoalsTab.debts),
        locale: const Locale('en'),
      );
      expect(find.text('Supplier'), findsOneWidget);
      expect(find.text('A friend'), findsOneWidget);
      await tester.tap(find.widgetWithText(MadarChip, 'Owed to me'));
      await settleGoals(tester);
      expect(find.text('Supplier'), findsNothing);
      expect(find.text('A friend'), findsOneWidget);
    });

    testWidgets('tapping a jar opens its screen', (tester) async {
      await pumpGoalsApp(tester, home: const GoalsScreen(), locale: const Locale('en'));
      await tester.tap(find.text('Family trip'));
      await settleGoals(tester);
      expect(find.byType(JarScreen), findsOneWidget);
      expect(find.byType(AstrolabeProgressRing), findsOneWidget);
      expect(find.text('Deposit'), findsOneWidget);
      expect(find.text('On track'), findsOneWidget);
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -700));
      await settleGoals(tester);
      expect(find.text('Savings trajectory'), findsOneWidget);
      expect(find.byType(JarTrajectoryChart), findsOneWidget);
    });

    testWidgets('due reminders are planned in the goals block of the reminders namespace', (tester) async {
      final env = await pumpGoalsApp(tester, home: const GoalsScreen(), locale: const Locale('en'));
      await tester.pump(const Duration(seconds: 1));
      await settleGoals(tester);
      final notices = env.reminders.current;
      expect(notices, isNotEmpty);
      expect(notices.every((n) => GoalsReminderIds.owns(n.id)), isTrue);
      expect(notices.map((n) => n.id).toSet(), hasLength(notices.length));
      expect(notices.every((n) => n.at.isAfter(goalsTestNow)), isTrue);
      final rent = notices.where((n) => n.refId == GoalsSeedIds.obRent).toList();
      // Rent is due Oct 1: a day-before reminder (Sep 30, 09:00) and one on the day.
      expect([for (final n in rent) n.at], [DateTime(2026, 9, 30, 9), DateTime(2026, 10, 1, 9)]);
      expect(rent.first.title, contains('Rent'));
      expect(rent.first.body, contains('Tomorrow'));
      final supplier = notices.firstWhere((n) => n.refId == GoalsSeedIds.debtSupplier);
      expect(supplier.kind, DueReminderKind.debt);
      expect(supplier.title, contains('Supplier'));
      // Paused obligations and undated or settled debts get nothing.
      expect(notices.where((n) => n.refId == GoalsSeedIds.obMusic), isEmpty);
      expect(notices.where((n) => n.refId == GoalsSeedIds.debtColleague), isEmpty);
      expect(notices.where((n) => n.refId == GoalsSeedIds.debtNeighbour), isEmpty);
      expect(GoalsReminderTaps.targetOf(_tapFor(notices.first)), (kind: notices.first.kind, id: notices.first.refId));
    });
  });

  group('hub cards', () {
    testWidgets('upcoming dues list overdue items first and pay in place', (tester) async {
      final env = await pumpGoalsApp(
        tester,
        home: const Scaffold(
          body: SingleChildScrollView(child: Column(children: [UpcomingDuesCard(maxItems: 6)])),
        ),
        locale: const Locale('en'),
      );
      expect(find.text('Courier company'), findsOneWidget);
      expect(find.text('Internet'), findsOneWidget);
      expect(find.text('Rent'), findsOneWidget);
      final courier = tester.getTopLeft(find.text('Courier company')).dy;
      final internet = tester.getTopLeft(find.text('Internet')).dy;
      final rent = tester.getTopLeft(find.text('Rent')).dy;
      expect(courier, lessThan(internet));
      expect(internet, lessThan(rent));
      // Every row has one action (debts take a payment, obligations are
      // marked paid); Internet's marks it paid in place.
      expect(find.byIcon(GoalsIcons.paid), findsNWidgets(find.byType(DueLeaf).evaluate().length));
      await tester.tap(
        find.byWidgetPredicate((w) => w is MadarButton && w.semanticLabel == 'Mark Internet paid'),
      );
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 50));
      }
      final ob = await tester.runAsync(() => env.repos.obligations.byId(GoalsSeedIds.obInternet));
      expect(ob!.nextDue, d(2026, 10, 27));
      await tester.pumpAndSettle(const Duration(seconds: 20));
    });

    testWidgets('jars card shows the first jars and the total', (tester) async {
      await pumpGoalsApp(
        tester,
        home: const Scaffold(body: JarsCard()),
        locale: const Locale('en'),
      );
      expect(find.text('Family trip'), findsOneWidget);
      expect(find.text('Emergency fund'), findsOneWidget);
      expect(find.text('New laptop'), findsOneWidget);
      expect(find.text('Eid gifts'), findsNothing);
      expect(find.textContaining('saved'), findsOneWidget);
    });

    testWidgets('empty cards hide when asked to', (tester) async {
      await pumpGoalsApp(
        tester,
        home: const Scaffold(
          body: Column(children: [UpcomingDuesCard(hideWhenEmpty: true), JarsCard(hideWhenEmpty: true)]),
        ),
        seed: false,
      );
      expect(find.byType(GlassCard), findsNothing);
      expect(find.textContaining('مستحق'), findsNothing);
    });
  });

  group('sheets', () {
    testWidgets('the debt sheet shows payments and records a settle', (tester) async {
      final env = await pumpGoalsApp(
        tester,
        home: const GoalsScreen(initialTab: GoalsTab.debts),
        locale: const Locale('en'),
      );
      await tester.tap(find.text('Supplier'));
      await settleGoals(tester);
      expect(find.byType(DebtSheet), findsOneWidget);
      expect(find.text('Payments'), findsOneWidget);
      expect(find.text('September stock'), findsOneWidget);
      await tester.tap(find.widgetWithText(SheetButton, 'Settle'));
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 50));
      }
      final debt = await tester.runAsync(() => env.repos.debts.byId(GoalsSeedIds.debtSupplier));
      expect(debt!.settledAt, isNotNull);
      await tester.pumpAndSettle(const Duration(seconds: 20));
    });

    testWidgets('the obligation sheet lists history with skips', (tester) async {
      await pumpGoalsApp(
        tester,
        home: const GoalsScreen(initialTab: GoalsTab.obligations),
        locale: const Locale('en'),
      );
      await tester.tap(find.text('Rent'));
      await settleGoals(tester);
      expect(find.byType(ObligationSheet), findsOneWidget);
      expect(find.text('Skipped'), findsOneWidget);
      expect(find.text('After that'), findsOneWidget);
    });
  });
}
