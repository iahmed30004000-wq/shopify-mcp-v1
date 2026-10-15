// The notification centre must be alive BEFORE every reminder sync, and
// its stored mutes must be in the gate before anything re-plans.
//
// Safety-critical: if the centre is watched later than a sync (or not at
// all), the first re-plan of a run re-arms the very alarms the owner muted
// – his phone would sound a group he silenced. The first test fails the
// moment that line moves down `AppServices.build`; the second shows the
// effect on the real chain (service → suspending wrapper → gate → plugin).
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderBase;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/adhkar/adhkar.dart' show adhkarReminderSyncProvider;
import 'package:madar/features/health/meds/meds.dart' show medsReminderSyncProvider;
import 'package:madar/features/money/goals/goals.dart' show goalsReminderSyncProvider;
import 'package:madar/features/notification_center/notification_center.dart';
import 'package:madar/features/wird/wird.dart' show wirdReminderSyncProvider;

import '../helpers/test_app.dart';

Future<void> _frames(WidgetTester tester, [int n = 10]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Records the order providers are first created in.
final class _StartOrder extends ProviderObserver {
  _StartOrder(this.watched);

  /// The providers whose order matters, by name.
  final Map<ProviderBase<Object?>, String> watched;
  final List<String> started = [];

  @override
  void didAddProvider(ProviderObserverContext context, Object? value) {
    final name = watched[context.provider];
    if (name != null && !started.contains(name)) started.add(name);
  }
}

NotificationRequest _reminder(NotificationNamespace ns, int id, DateTime at, {String channel = 'test'}) =>
    NotificationRequest(
      namespace: ns,
      id: id,
      channelId: channel,
      title: 'x',
      body: 'y',
      at: at,
      data: {'set': 'morning'},
    );

void main() {
  final order = _StartOrder({
    notificationCenterProvider: 'centre',
    adhkarReminderSyncProvider: 'adhkar',
    wirdReminderSyncProvider: 'wird',
    medsReminderSyncProvider: 'meds',
    goalsReminderSyncProvider: 'money',
  });

  testWidgets('the centre starts before every reminder sync', (tester) async {
    order.started.clear();
    await pumpMadarApp(tester, observers: [order]);
    expect(order.started, isNotEmpty);
    expect(order.started.first, 'centre', reason: 'started in this order: ${order.started}');
    for (final sync in ['adhkar', 'wird', 'meds', 'money']) {
      if (!order.started.contains(sync)) continue;
      expect(
        order.started.indexOf('centre'),
        lessThan(order.started.indexOf(sync)),
        reason: '$sync re-plans before the centre loaded the mutes: ${order.started}',
      );
    }
  });

  testWidgets('the owner\'s stored mutes are in the gate before anything re-plans', (tester) async {
    final now = testNow;
    final until = now.add(const Duration(hours: 4));
    // settle: false – the centre re-reads the tray on its own timer, so
    // `pumpAndSettle` would keep finding work to do.
    final app = await pumpMadarApp(
      tester,
      gated: true,
      settle: false,
      settings: const AppSettings(onboarded: true),
      beforePump: (MadarDatabase db) async {
        // The owner muted Adhkar before this run.
        await NotificationCenterStore(Repositories(db).keyValues).savePolicy(
          CenterPolicy.empty.mute(NotificationGroup.adhkar, until),
        );
      },
    );
    await _frames(tester, 20);

    // The real chain: the fake plugin behind the real gate (the production
    // chain's shape is `notification_wiring_test`'s job).
    expect(app.container.read(notificationPlatformProvider), isA<GatedNotificationPlatform>());
    final gate = app.container.read(notificationGateProvider);
    expect(gate.attached, isTrue, reason: 'the gate is the platform the app schedules through');
    expect(gate.policyLoaded, isTrue, reason: 'the centre loaded the stored policy at startup');
    expect(gate.policy.mutedUntil[NotificationGroup.adhkar], until);

    // So the gate holds that group back, and only that one.
    final adhkar = CenterNotice(
      id: 110500,
      namespace: NotificationNamespaces.adhkar.name,
      at: now.add(const Duration(hours: 1)).toUtc(),
      data: const {'set': 'morning'},
    );
    final wird = CenterNotice(
      id: 140500,
      namespace: NotificationNamespaces.wird.name,
      at: now.add(const Duration(hours: 1)).toUtc(),
      data: const {'plan': 'p1'},
    );
    expect(gate.withholds(adhkar), isTrue, reason: 'a muted group must be held');
    expect(gate.withholds(wird), isFalse, reason: 'another group must still arrive');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });

  // The effect of that policy at the platform, on the production chain
  // (`gatedNotificationPlatform` + the real NotificationService), without a
  // widget tree: a withheld namespace makes no platform call at all.
  test('a stored mute reaches the platform as silence; unmuting re-arms it', () async {
    final now = testNow;
    final db = MadarDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    addTearDown(db.close);
    final keyValues = Repositories(db).keyValues;
    await NotificationCenterStore(keyValues).savePolicy(
      CenterPolicy.empty.mute(NotificationGroup.adhkar, now.add(const Duration(hours: 4))),
    );

    final plugin = FakeNotificationPlatform();
    final container = ProviderContainer(
      overrides: [
        notificationCenterClockProvider.overrideWithValue(() => now),
        notificationPlatformProvider.overrideWith((ref) => gatedNotificationPlatform(ref, plugin)),
      ],
    );
    addTearDown(container.dispose);
    final gate = container.read(notificationGateProvider);
    final service = NotificationService(container.read(notificationPlatformProvider), clock: () => now);
    addTearDown(service.dispose);

    // Exactly what the centre does at startup (and the background isolate).
    await loadStoredNotificationPolicy(gate, keyValues);

    const adhkarId = 110500;
    const wirdId = 140500;
    final at = now.add(const Duration(hours: 1));
    await service.schedule(_reminder(NotificationNamespaces.adhkar, adhkarId, at));
    await service.schedule(_reminder(NotificationNamespaces.wird, wirdId, at));
    expect(
      plugin.scheduled.keys,
      isNot(contains(adhkarId)),
      reason: 'a muted group reached the platform: ${plugin.scheduled.keys}',
    );
    expect(plugin.scheduled.keys, contains(wirdId), reason: 'an unmuted group must still be armed');

    // Lifting the mute re-arms what was held, with its own request.
    await gate.setPolicy(CenterPolicy.empty);
    expect(plugin.scheduled.keys, contains(adhkarId), reason: 'unmuting must bring the reminder back');
    expect(plugin.scheduled[adhkarId]!.request.at, at);
  });
}
