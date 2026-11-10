// Money notifications into the running app, end to end (router, database
// gate, adhan host, app lock, the app's services):
// * at start the app plans the debts' and bills' due reminders (and
//   re-plans when a bill is paid);
// * a tap on a debt's or a bill's reminder opens the goals on its tab with
//   that one's sheet up (cold start or warm), under the app lock like every
//   deep link.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/app/app_services.dart';
import 'package:madar/app/money_services.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/core/routing/router.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/lock/presentation/lock_screen.dart';
import 'package:madar/features/money/goals/goals.dart';

import '../features/lock/lock_test_utils.dart';
import '../helpers/test_app.dart';

final DateTime _now = DateTime(2026, 9, 29, 7, 30);
const _english = AppSettings(onboarded: true, languageCode: 'en');

RawNotificationTap _dueTap(String target, String id, {int offset = 0, bool launch = false}) {
  final nid = GoalsReminderIds.of(offset);
  return RawNotificationTap(
    id: nid,
    fromLaunch: launch,
    payload: NotificationEnvelope.encode(
      NotificationRequest(
        namespace: GoalsReminderIds.namespace,
        id: nid,
        channelId: 'madar.money.due.1',
        title: 't',
        body: '',
        at: _now,
        data: {'kind': 'money.due', 'target': target, 'id': id},
      ),
    ),
  );
}

NotificationTap _decoded(RawNotificationTap raw) =>
    NotificationEnvelope.decode(raw.payload, id: raw.id, actionId: raw.actionId);

/// Lets database writes and the reminder syncs' debounces finish.
Future<void> _writes(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 400));
  }
}

/// A debt due tomorrow and a monthly bill due in two days.
Future<({String debt, String bill})> _seed(MadarDatabase db) async {
  final goals = GoalsService(Repositories(db), clock: () => _now);
  final debt = await goals.addDebt(
    DebtDraft(
      direction: DebtDirection.iOwe,
      person: 'Khaled',
      amountMilli: 150000,
      currency: 'JOD',
      dueDate: DateTime(2026, 9, 30),
    ),
  );
  final bill = await goals.addObligation(
    ObligationDraft(
      name: 'Internet',
      amountMilli: 25000,
      currency: 'JOD',
      frequency: Recurrence.monthly,
      nextDue: DateTime(2026, 10, 1),
    ),
  );
  return (debt: debt.id, bill: bill.id);
}

void main() {
  group('where a tap leads (pure)', () {
    test('a debt\'s or a bill\'s reminder opens its sheet on the goals; others are not money\'s', () {
      expect(moneyNotificationLocation(_decoded(_dueTap('debt', 'd1'))), '/goals?tab=debts&debt=d1');
      expect(
        moneyNotificationLocation(_decoded(_dueTap('obligation', 'o 1'))),
        '/goals?tab=obligations&obligation=o+1',
      );
      expect(AppNotificationRouter.locationOf(_decoded(_dueTap('debt', 'd1'))), '/goals?tab=debts&debt=d1');
      expect(moneyNotificationLocation(_decoded(_dueTap('jar', 'j1'))), isNull, reason: 'no such reminder');
      final foreign = RawNotificationTap(
        id: 136001,
        payload: NotificationEnvelope.encode(
          NotificationRequest(
            namespace: NotificationNamespaces.reminders,
            id: 136001,
            channelId: 'x',
            title: 't',
            body: '',
            at: _now,
            data: const {'kind': 'money.due', 'target': 'debt', 'id': 'd1'},
          ),
        ),
      );
      expect(moneyNotificationLocation(_decoded(foreign)), isNull, reason: "another feature's id block");
    });
  });

  testWidgets('at start the due reminders are planned; paying the bill re-plans them', (tester) async {
    late ({String debt, String bill}) ids;
    final app = await pumpMadarApp(
      tester,
      settings: _english,
      now: _now,
      overrides: LockFixture.empty().overrides,
      beforePump: (db) async => ids = await _seed(db),
    );
    await _writes(tester);
    List<Map<String, Object?>> planned() => [
      for (final s in app.notifications.scheduled.values)
        if (GoalsReminderIds.owns(s.request.id)) s.request.data,
    ];
    expect(planned().where((d) => d['target'] == 'debt' && d['id'] == ids.debt), isNotEmpty);
    expect(planned().where((d) => d['target'] == 'obligation' && d['id'] == ids.bill), isNotEmpty);
    final before = app.notifications.scheduled.values
        .where((s) => GoalsReminderIds.owns(s.request.id) && s.request.data['id'] == ids.bill)
        .map((s) => s.request.at)
        .toList();

    // "Paid" moves the bill a month on; its reminders follow.
    // (Written in the test's own zone: the app's queries share the database.)
    unawaited(app.container.read(goalsServiceProvider).payObligation(ids.bill));
    await _writes(tester);
    final after = app.notifications.scheduled.values
        .where((s) => GoalsReminderIds.owns(s.request.id) && s.request.data['id'] == ids.bill)
        .map((s) => s.request.at)
        .toList();
    expect(after, isNotEmpty);
    expect(after.first.isAfter(before.last), isTrue, reason: 'the next due date is in November');
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('warm: a debt reminder opens the debts with its sheet', (tester) async {
    late ({String debt, String bill}) ids;
    final app = await pumpMadarApp(
      tester,
      settings: _english,
      now: _now,
      overrides: LockFixture.empty().overrides,
      beforePump: (db) async => ids = await _seed(db),
    );
    app.notifications.tap(_dueTap('debt', ids.debt));
    await settleApp(tester);
    expect(app.router.state.uri.toString(), '/goals?tab=debts&debt=${ids.debt}');
    expect(tester.widget<GoalsScreen>(find.byType(GoalsScreen)).initialTab, GoalsTab.debts);
    expect(find.byType(DebtSheet), findsOneWidget);
    expect(tester.widget<DebtSheet>(find.byType(DebtSheet)).debtId, ids.debt);
    // Back closes the sheet, then leaves the goals for home.
    await tester.binding.handlePopRoute();
    await settleApp(tester);
    expect(find.byType(DebtSheet), findsNothing);
    await tester.binding.handlePopRoute();
    await settleApp(tester);
    expect(app.location, AppRoutes.home);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('cold start from a bill reminder shows the bill over the obligations', (tester) async {
    final app = await pumpMadarApp(
      tester,
      settings: _english,
      now: _now,
      notifications: FakeNotificationPlatform(launch: _dueTap('obligation', 'o-9', launch: true)),
      overrides: LockFixture.empty().overrides,
    );
    expect(app.router.state.uri.toString(), '/goals?tab=obligations&obligation=o-9');
    expect(tester.widget<GoalsScreen>(find.byType(GoalsScreen)).initialTab, GoalsTab.obligations);
    expect(tester.widget<ObligationSheet>(find.byType(ObligationSheet)).obligationId, 'o-9');
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('a due reminder tapped while locked moves the router under the lock', (tester) async {
    final fx = await LockFixture.configured(biometrics: false);
    final app = await pumpMadarApp(tester, settings: _english, now: _now, overrides: fx.overrides);
    expect(find.byType(LockScreen), findsOneWidget);
    app.notifications.tap(_dueTap('debt', 'd-1'));
    await settleApp(tester);
    expect(app.router.state.uri.toString(), '/goals?tab=debts&debt=d-1');
    expect(find.byType(LockScreen), findsOneWidget, reason: 'a deep link never lifts the lock');
    expect(find.byType(DebtSheet), findsNothing);
    await tester.pump(const Duration(seconds: 6));
  });
}
