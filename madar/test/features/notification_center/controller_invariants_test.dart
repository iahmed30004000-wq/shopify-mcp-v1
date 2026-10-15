// Adversarial tests of the center's controller over the gate, the fake
// plugin and a real in-memory database: tray removals never take another
// firing of the same id, a mute / undo in a fresh run never leaves an adhan
// stripped of its buttons, snooze undo brings the notification back, and
// late arrivals still count as new.
import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/core/providers.dart';
import 'package:madar/features/adhan/domain/adhan_event.dart';
import 'package:madar/features/adhan/domain/adhan_slot.dart';
import 'package:madar/features/adhkar/domain/adhkar_models.dart';
import 'package:madar/features/health/meds/data/meds_notifications.dart';
import 'package:madar/features/home/home_providers.dart';
import 'package:madar/features/notification_center/notification_center.dart';

import 'nc_fixtures.dart';

/// A plugin whose pending list can stall (the app dies while it waits).
class _HangingPlatform extends FakeNotificationPlatform {
  Completer<void>? hang;

  @override
  Future<List<PendingNotice>> pending() async {
    final wait = hang;
    if (wait != null) await wait.future;
    return super.pending();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late DateTime now;
  late FakeNotificationPlatform fake;
  late MadarDatabase db;

  setUp(() {
    now = ncNow;
    fake = FakeNotificationPlatform();
    db = MadarDatabase(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  ProviderContainer container({List<Override> overrides = const [], NotificationPlatform? platform}) {
    final c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        notificationCenterClockProvider.overrideWithValue(() => now),
        homeClockProvider.overrideWithValue(() => now),
        notificationPlatformProvider.overrideWith((ref) => gatedNotificationPlatform(ref, platform ?? fake)),
        notificationServiceProvider.overrideWith((ref) {
          final s = NotificationService(ref.watch(notificationPlatformProvider), clock: () => now);
          ref.onDispose(s.dispose);
          return s;
        }),
        ...overrides,
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<NotificationCenterState> look(ProviderContainer c) async {
    c.read(notificationCenterProvider);
    await c.read(notificationCenterProvider.notifier).refresh();
    return c.read(notificationCenterProvider);
  }

  NotificationService service(ProviderContainer c) => c.read(notificationServiceProvider);
  NotificationCenterController ctrl(ProviderContainer c) => c.read(notificationCenterProvider.notifier);

  group('#1 tray removals never take another firing of the same id', () {
    test('clear all and dismiss leave the next due reminder of that id armed', () async {
      final c = container();
      final today = moneyDue(ncAt(0, 9));
      final next = moneyDue(ncAt(3, 9));
      await service(c).show(today);
      await service(c).show(worry(ncAt(0, 12)));
      await service(c).sync(NotificationNamespaces.reminders, [next]);
      var state = await look(c);
      expect(state.recent, hasLength(2));
      await ctrl(c).dismiss(state.recent.firstWhere((i) => i.id == today.id));
      expect(fake.scheduled[next.id]?.request.at, ncAt(3, 9), reason: 'dismiss');
      state = c.read(notificationCenterProvider);
      await ctrl(c).clearAll();
      expect(fake.scheduled[next.id]?.request.at, ncAt(3, 9), reason: 'clear all');
      expect(fake.shown.containsKey(worry(now).id), isFalse, reason: 'the rest still leaves the tray');
      expect(c.read(notificationCenterProvider).recent, isEmpty);
    });

    test('answering a live dose never cancels the dose that now owns its id', () async {
      final answered = <CenterActionRequest>[];
      final c = container(
        overrides: [
          notificationActionHandlersProvider.overrideWithValue(
            NotificationActionHandlers({
              MedsNotificationTaps.actionTaken: (r) async {
                answered.add(r);
                return true;
              },
            }),
          ),
        ],
      );
      final morning = medsDose(ncAt(0, 8));
      final evening = medsDose(ncAt(0, 20)); // same id (re-assigned after a collision)
      await service(c).show(morning);
      await service(c).sync(NotificationNamespaces.meds, [evening]);
      final item = (await look(c)).recent.single;
      expect(item.live, isTrue);
      expect(await ctrl(c).perform(item, MedsNotificationTaps.actionTaken), isTrue);
      expect(answered, hasLength(1));
      expect(fake.scheduled[evening.id]?.request.at, ncAt(0, 20));
    });
  });

  group('#1 a mute undone in a fresh run', () {
    test('the adhan is re-planned while muted, so undo re-arms it with Stop and full screen', () async {
      final prayers = [adhanFull(AdhanSlot.maghrib, ncAt(0, 18, 12)), adhanFull(AdhanSlot.isha, ncAt(0, 19, 40))];
      // An earlier run armed them; this run's re-plan finds them unchanged.
      for (final r in prayers) {
        await fake.schedule(r, NotificationEnvelope.encode(r), timing: r.timing);
      }
      var replans = 0;
      late ProviderContainer c;
      c = container(
        overrides: [
          notificationReplanHooksProvider.overrideWithValue(
            NotificationReplanHooks({
              'adhan': () async {
                replans++;
                await service(c).sync(NotificationNamespaces.adhan, prayers);
              },
            }),
          ),
        ],
      );
      expect((await service(c).sync(NotificationNamespaces.adhan, prayers)).unchanged, 2);
      await look(c);
      final undo = await ctrl(c).mute(NotificationGroup.prayer, ncAt(0, 21));
      expect(fake.scheduled, isEmpty);
      expect(replans, greaterThanOrEqualTo(1), reason: 'the held copies were rebuilt: the adhan re-sends its own');
      final gate = c.read(notificationGateProvider);
      expect(gate.held.values.map((h) => h.rebuilt), [false, false], reason: 'held in full before undo is possible');
      expect(gate.staleNamespaces, isEmpty);
      await undo();
      for (final r in prayers) {
        expect(fake.scheduled[r.id]!.payload, NotificationEnvelope.encode(r));
        expect(fake.scheduled[r.id]!.request.actions.single.id, AdhanActions.stop);
        expect(fake.scheduled[r.id]!.request.fullScreen, isTrue);
        expect(fake.scheduled[r.id]!.timing, NotificationTiming.alarmClock);
      }
    });
  });

  group('#2 snoozes', () {
    test('a snooze the system dropped (force stop, exact alarms revoked) is re-armed at the next look', () async {
      final c = container();
      final r = adhkar(AdhkarCategoryId.morning, ncAt(0, 12, 50));
      await service(c).show(r);
      final item = (await look(c)).recent.single;
      expect(await ctrl(c).snooze(item, const Duration(minutes: 30)), ncAt(0, 13, 40));
      fake.dropArmedAlarms();
      fake.exactAllowed = false;
      // The adhkar feature's own re-plan cannot see it (hidden) …
      await service(c).sync(NotificationNamespaces.adhkar, const []);
      expect(fake.unarmed, contains(r.id));
      // … the center's next look re-arms it.
      await look(c);
      expect(fake.unarmed, isNot(contains(r.id)));
      expect(fake.scheduled[r.id]!.request.at, ncAt(0, 13, 40));
      expect(fake.scheduled[r.id]!.timing, NotificationTiming.inexactWhileIdle);
      expect(GateMarks.of(fake.scheduled[r.id]!.payload), GateMarks.snooze, reason: 'still hidden from features');
    });
  });

  group('undo', () {
    test('undoing a snooze brings the notification back to the tray and the list', () async {
      final c = container();
      final r = adhkar(AdhkarCategoryId.morning, ncAt(0, 12, 50));
      await service(c).show(r);
      final item = (await look(c)).recent.single;
      final until = await ctrl(c).snooze(item, const Duration(minutes: 30));
      expect(until, isNotNull);
      expect(fake.shown, isEmpty);
      await ctrl(c).undoSnooze(item);
      expect(fake.scheduled, isEmpty, reason: 'the snoozed alarm is gone');
      expect(fake.shown.keys, [r.id], reason: 'back where it was');
      final state = c.read(notificationCenterProvider);
      expect(state.upcoming, isEmpty);
      expect(state.recent.single.state, CenterItemState.live);
      expect(state.policy.snoozed, isEmpty);
    });
  });

  group('unread', () {
    test('a notification that arrived late (Doze) after the last look counts as new', () async {
      final c = container();
      final r = worry(ncAt(0, 13, 12));
      await service(c).sync(NotificationNamespaces.health, [r]);
      await look(c);
      await look(c); // the first look's follow-up refresh is done too
      now = ncAt(0, 13, 14);
      await ctrl(c).markSeen(); // the user looked; it had not arrived yet
      now = ncAt(0, 13, 20);
      fake.fireDue(now); // it arrives 8 minutes late
      final state = await look(c);
      expect(state.recent.single.notice.id, r.id);
      expect(state.unread, 1);
    });
  });

  group('counts', () {
    test('an alarm still pending after its moment (Doze) and swiped away later is still recorded', () async {
      final c = container();
      final r = worry(ncAt(0, 13, 12));
      await service(c).sync(NotificationNamespaces.health, [r]);
      await look(c);
      await look(c);
      now = ncAt(0, 13, 14); // due, not fired yet: the plugin still lists it
      await look(c);
      now = ncAt(0, 13, 20);
      fake.fireDue(now);
      await fake.cancel(r.id); // swiped away before the center looked again
      final state = await look(c);
      expect(state.recent.map((i) => i.notice.id), [r.id]);
      expect(state.recent.single.state, CenterItemState.delivered);
    });
  });

  group('#2 a mute or unmute survives the app dying mid-way', () {
    test('an unmute is stored before it is applied (re-arming can be cut short)', () async {
      final slow = _HangingPlatform();
      final c = container(platform: slow);
      final kv = Repositories(db).keyValues;
      await look(c);
      await ctrl(c).mute(NotificationGroup.prayer, ncAt(1, 7));
      expect((await NotificationCenterStore(kv).policy()).mutedUntil, isNotEmpty);
      slow.hang = Completer<void>();
      final unmuting = ctrl(c).unmute(NotificationGroup.prayer);
      await pumpEventQueue();
      // The process dies here: what the next run loads must be the unmute.
      expect((await NotificationCenterStore(kv).policy()).mutedUntil, isEmpty);
      slow.hang!.complete();
      await unmuting;
    });
  });

  group('#2 background policy', () {
    test('the stored policy loads into a background gate without the center', () async {
      final kv = Repositories(db).keyValues;
      final policy = CenterPolicy.empty.mute(NotificationGroup.medications, ncAt(0, 15));
      await NotificationCenterStore(kv).savePolicy(policy);
      final gate = NotificationGate.background(clock: () => now);
      await loadStoredNotificationPolicy(gate, kv);
      expect(gate.policy, policy);
      // A store that fails leaves the gate open (never throws).
      final open = NotificationGate.background(clock: () => now);
      await db.close();
      await loadStoredNotificationPolicy(open, kv);
      expect(open.policy, CenterPolicy.empty);
      db = MadarDatabase(NativeDatabase.memory());
    });
  });
}
