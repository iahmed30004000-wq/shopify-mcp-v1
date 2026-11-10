// An independent verifier's scenarios for the notification gate (written
// without the earlier reviewer's tests as a guide):
//
// 1. Unmuted adhan / dose alarms are never suppressed, delayed, duplicated
//    or stripped; the gate fails open.
// 2. Mutes, skips and snoozes end on time without the app opening.
// 3. Ids stay within namespaces; bounded state; no personal text in logs.
import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/features/adhan/domain/adhan_slot.dart';
import 'package:madar/features/money/goals/data/goals_notifications.dart' show GoalsReminderIds;
import 'package:madar/features/notification_center/notification_center.dart';
import 'package:madar/features/travel/domain/document_reminders.dart' show TravelReminderIds;

import 'nc_fixtures.dart';

/// A plugin whose pending list can hang forever (a stuck platform channel)
/// and that can pretend to know nothing about payloads.
class _Plugin extends FakeNotificationPlatform {
  bool hangPending = false;
  bool payloadless = false;

  @override
  Future<List<PendingNotice>> pending() async {
    if (hangPending) await Completer<void>().future;
    final list = await super.pending();
    return payloadless ? [for (final p in list) PendingNotice(p.id, null)] : list;
  }
}

/// A plugin whose errors quote what it was handed (the worst a platform
/// channel could do).
class _LeakyPlugin extends FakeNotificationPlatform {
  bool failAll = false;

  @override
  Future<void> schedule(NotificationRequest request, String payload, {required NotificationTiming timing}) async {
    if (failAll) throw StateError('could not schedule ${request.title}: $payload');
    return super.schedule(request, payload, timing: timing);
  }

  @override
  Future<void> cancel(int id) async {
    if (failAll) throw StateError('could not cancel $id');
    return super.cancel(id);
  }

  @override
  Future<List<PendingNotice>> pending() async {
    final list = await super.pending();
    if (failAll) throw StateError('pending: ${[for (final p in list) p.title]}');
    return list;
  }
}

/// A plugin that only knows ids of what is shown (no [ActiveNotificationQuery]).
class _IdsOnlyPlugin implements NotificationPlatform {
  _IdsOnlyPlugin(this.inner);

  final FakeNotificationPlatform inner;

  @override
  Future<void> initialize({required void Function(RawNotificationTap tap) onTap}) => inner.initialize(onTap: onTap);
  @override
  Future<RawNotificationTap?> launchTap() => inner.launchTap();
  @override
  Future<void> createChannelGroup(String id, String name) => inner.createChannelGroup(id, name);
  @override
  Future<void> createChannel(NotificationChannelSpec spec) => inner.createChannel(spec);
  @override
  Future<void> deleteChannel(String id) => inner.deleteChannel(id);
  @override
  Future<List<String>> channelIds() => inner.channelIds();
  @override
  Future<void> schedule(NotificationRequest request, String payload, {required NotificationTiming timing}) =>
      inner.schedule(request, payload, timing: timing);
  @override
  Future<void> show(NotificationRequest request, String payload) => inner.show(request, payload);
  @override
  Future<void> cancel(int id) => inner.cancel(id);
  @override
  Future<List<PendingNotice>> pending() => inner.pending();
  @override
  Future<Set<int>?> armedIds(Iterable<int> ids) => inner.armedIds(ids);
  @override
  Future<List<int>> activeIds() => inner.activeIds();
  @override
  Future<bool> notificationsEnabled() => inner.notificationsEnabled();
  @override
  Future<bool> requestNotifications() => inner.requestNotifications();
  @override
  Future<bool> canScheduleExact() => inner.canScheduleExact();
  @override
  Future<bool> requestExactAlarms() => inner.requestExactAlarms();
  @override
  Future<bool> requestFullScreenIntent() => inner.requestFullScreenIntent();
}

void main() {
  late DateTime now;
  late _Plugin fake;
  late NotificationGate gate;
  late NotificationService service;
  final registry = NotificationDescriberRegistry(builtInDescribers());

  (NotificationGate, NotificationService) run({GroupOf? groupOf}) {
    final g = NotificationGate(groupOf: groupOf ?? registry.groupOf, clock: () => now);
    final s = NotificationService(GatedNotificationPlatform(fake, g), clock: () => now);
    addTearDown(() async {
      await s.dispose();
      await g.dispose();
    });
    return (g, s);
  }

  setUp(() {
    now = ncNow;
    fake = _Plugin();
    (gate, service) = run();
  });

  final maghrib = adhanFull(AdhanSlot.maghrib, ncAt(0, 18, 12));
  final isha = adhanFull(AdhanSlot.isha, ncAt(0, 19, 40));
  final fajr = adhanFull(AdhanSlot.fajr, ncAt(1, 4, 20));
  final dhuhr = adhanFull(AdhanSlot.dhuhr, ncAt(1, 11, 36));
  List<NotificationRequest> prayers() => [maghrib, isha, fajr, dhuhr];

  void expectWhole(NotificationRequest want) {
    final got = fake.scheduled[want.id];
    expect(got, isNotNull, reason: '#${want.id} must be armed');
    expect(got!.payload, NotificationEnvelope.encode(want), reason: 'exactly the feature\'s own request');
    expect(got.request.actions.map((a) => a.id), want.actions.map((a) => a.id));
    expect(got.timing, want.timing);
    expect(got.request.fullScreen, want.fullScreen);
  }

  List<FakeScheduled> snoozesArmed() => [
    for (final s in fake.scheduled.values)
      if (GateMarks.of(s.payload) == GateMarks.snooze) s,
  ];

  Future<NotificationSyncReport> goalsSync(NotificationService s, List<NotificationRequest> wanted) =>
      s.sync(NotificationNamespaces.reminders, wanted, keep: (id) => !GoalsReminderIds.owns(id));

  group('V1 one id, a firing Doze held past its moment', () {
    test('taking an older notification of that id out of the tray never cancels the delayed dose', () async {
      final yesterday = medsDose(ncAt(-1, 20));
      final delayed = medsDose(ncAt(0, 13, 5)); // the same id: meds re-assigned it
      await service.show(yesterday);
      now = ncAt(0, 13);
      expect(await service.schedule(delayed), isTrue);
      now = ncAt(0, 13, 10); // due five minutes ago; Doze has not let it fire yet
      expect(await gate.removeShown(CenterNotice.fromRequest(yesterday)), isFalse);
      expectWhole(delayed);
      expect(await gate.snooze(CenterNotice.fromRequest(yesterday), ncAt(0, 14)), isFalse);
      expectWhole(delayed);
    });

    test('its own firing still listed (the plugin not yet done with it) does not block removal', () async {
      final r = worry(ncAt(0, 13, 5));
      now = ncAt(0, 13);
      await service.schedule(r);
      now = ncAt(0, 13, 10);
      await fake.show(r, NotificationEnvelope.encode(r)); // shown, the cache not yet cleared
      expect(await gate.removeShown(CenterNotice.fromRequest(r)), isTrue);
    });
  });

  group('V2 a snooze outlives a feature re-plan that reuses its id', () {
    test('positional ids: the next due takes the id, the snooze still arrives at its time', () async {
      final today = moneyDue(ncAt(0, 9)); // of(0), fired at 9:00, still in the tray
      await service.show(today);
      expect(await gate.snooze(CenterNotice.fromRequest(today), ncAt(0, 13, 40)), isTrue);
      // A due changed (or midnight, or a restart): of(0) is now the next due.
      final next = moneyDue(ncAt(3, 9));
      await goalsSync(service, [next]);
      expectWhole(next);
      final snoozed = snoozesArmed();
      expect(snoozed, hasLength(1), reason: 'the snooze must still be armed');
      expect(snoozed.single.request.at, ncAt(0, 13, 40));
      expect(NotificationEnvelope.decode(snoozed.single.payload).data, today.data);
      expect(
        NotificationNamespaces.all.any((ns) => ns.contains(snoozed.single.request.id)),
        isFalse,
        reason: 'never an id a feature plans',
      );
      expect(gate.policy.snoozed.keys, [today.id], reason: 'still listed as snoozed');
      // No churn afterwards, and the feature never sees it.
      expect((await goalsSync(service, [next])).unchanged, 1);
      expect(snoozesArmed(), hasLength(1));
      // Tapped, it routes to the goals feature under its own id.
      final tap = service.taps.first;
      fake.tap(RawNotificationTap(id: snoozed.single.request.id, payload: snoozed.single.payload));
      expect((await tap).id, today.id);
      // Cancelling the snooze takes only it.
      await gate.cancelSnooze(today.id);
      expect(snoozesArmed(), isEmpty);
      expectWhole(next);
    });

    test('in a new run, before the stored policy is loaded', () async {
      final today = moneyDue(ncAt(0, 9));
      await service.show(today);
      expect(await gate.snooze(CenterNotice.fromRequest(today), ncAt(0, 13, 40)), isTrue);
      final stored = gate.policy;
      final (g2, s2) = run();
      final next = moneyDue(ncAt(3, 9));
      await goalsSync(s2, [next]);
      expectWhole(next);
      expect(snoozesArmed().map((s) => s.request.at.toUtc()), [ncAt(0, 13, 40).toUtc()]);
      await g2.setPolicy(stored);
      expect(g2.policy.snoozed.keys, [today.id]);
      await g2.cancelSnooze(today.id);
      expect(snoozesArmed(), isEmpty);
      expectWhole(next);
    });
  });

  test('V2 a one-off schedule of the id, the first call of a new run, still keeps the snooze', () async {
    final today = moneyDue(ncAt(0, 9));
    await service.show(today);
    expect(await gate.snooze(CenterNotice.fromRequest(today), ncAt(0, 13, 40)), isTrue);
    final (_, s2) = run();
    final next = moneyDue(ncAt(3, 9));
    expect(await s2.schedule(next), isTrue);
    expectWhole(next);
    expect(snoozesArmed().map((s) => s.request.at.toUtc()), [ncAt(0, 13, 40).toUtc()]);
  });

  test('V2 exact alarms revoked: the service\'s inexact retry never moves the snooze twice', () async {
    // Travel reminders are exact, and positional (the document's slot).
    final today = travelDoc(ncAt(0, 9));
    await service.show(today);
    expect(await gate.snooze(CenterNotice.fromRequest(today), ncAt(0, 13, 40)), isTrue);
    fake.exactAllowed = false;
    final next = travelDoc(ncAt(3, 9)); // another document now in slot 0
    final report = await service.sync(TravelReminderIds.namespace, [next], keep: (id) => !TravelReminderIds.owns(id));
    expect(report.inexactFallback, 1);
    expect(fake.scheduled[next.id]!.payload, NotificationEnvelope.encode(next));
    expect(snoozesArmed(), hasLength(1), reason: 'the snooze arrives once');
  });

  test('V2 undoing a snooze puts the notification back even if its group was muted meanwhile', () async {
    final r = worry(ncAt(0, 12));
    await service.show(r);
    final notice = CenterNotice.fromRequest(r);
    expect(await gate.snooze(notice, ncAt(0, 13, 40)), isTrue);
    await gate.setPolicy(gate.policy.mute(NotificationGroup.health, ncAt(0, 18)));
    final silenced = <CenterNotice>[];
    final sub = gate.silenced.listen(silenced.add);
    addTearDown(sub.cancel);
    expect(await gate.unsnooze(notice), isTrue);
    expect(fake.shown.keys, [r.id], reason: 'back in the tray, as it was');
    expect(snoozesArmed(), isEmpty);
    await pumpEventQueue();
    expect(silenced, isEmpty);
  });

  test(
    'V2 a moved snooze that arrived can be snoozed again, and dismissed, without touching the id\'s next firing',
    () async {
      final today = travelDoc(ncAt(0, 9));
      await service.show(today);
      final notice = CenterNotice.fromRequest(today);
      expect(await gate.snooze(notice, ncAt(0, 13, 40)), isTrue);
      final next = travelDoc(ncAt(3, 9));
      await service.sync(TravelReminderIds.namespace, [next], keep: (id) => !TravelReminderIds.owns(id));
      now = ncAt(0, 13, 41);
      fake.fireDue(now);
      expect(fake.shown, hasLength(1));
      final arrived = notice.copyWith(at: ncAt(0, 13, 40).toUtc());
      expect(await gate.snooze(arrived, ncAt(0, 14, 30)), isTrue);
      expect(fake.shown, isEmpty);
      expect(snoozesArmed().map((s) => (GateMarks.originOf(s.payload), s.request.at.toUtc())), [
        (today.id, ncAt(0, 14, 30).toUtc()),
      ]);
      expectWhole(next);
      now = ncAt(0, 14, 31);
      fake.fireDue(now);
      expect(await gate.removeShown(arrived.copyWith(at: ncAt(0, 14, 30).toUtc())), isTrue);
      expect(fake.shown, isEmpty);
      expectWhole(next);
    },
  );

  test('V5 a dose held from the plugin\'s copy in a new run comes back whole after the meds re-plan', () async {
    final dose = medsDose(ncAt(0, 14));
    await service.sync(NotificationNamespaces.meds, [dose]);
    final (g2, s2) = run();
    expect((await s2.sync(NotificationNamespaces.meds, [dose])).unchanged, 1);
    await g2.setPolicy(CenterPolicy.empty.mute(NotificationGroup.medications, ncAt(0, 15)));
    expect(fake.scheduled, isEmpty);
    await g2.setPolicy(CenterPolicy.empty);
    final rebuilt = fake.scheduled[dose.id]!;
    expect(rebuilt.timing, NotificationTiming.exactWhileIdle);
    expect(rebuilt.request.at.toUtc(), dose.at.toUtc());
    expect(NotificationEnvelope.decode(rebuilt.payload).data, dose.data);
    expect(g2.staleNamespaces, {'meds'});
    final report = await s2.sync(NotificationNamespaces.meds, [dose]);
    expect(report.scheduled, 1);
    expectWhole(dose);
    expect(g2.staleNamespaces, isEmpty);
  });

  test('V8 logs carry no notification text, even when errors do', () async {
    final logs = <String>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
    addTearDown(() => debugPrint = original);
    final leaky = _LeakyPlugin();
    final registryThrowing = NotificationDescriberRegistry(builtInDescribers())
      ..register(
        FunctionDescriber(
          id: 'leaky',
          classify: (n) => throw StateError('describer saw ${n.title}'),
          build: (n, t) => throw StateError('describer saw ${n.title}'),
        ),
      );
    final g = NotificationGate(groupOf: registryThrowing.groupOf, clock: () => now);
    final s = NotificationService(GatedNotificationPlatform(leaky, g), clock: () => now);
    addTearDown(() async {
      await s.dispose();
      await g.dispose();
    });
    final dose = medsDose(ncAt(0, 14), name: 'Warfarin');
    final r = worry(ncAt(0, 16));
    await s.sync(NotificationNamespaces.meds, [dose]);
    await s.sync(NotificationNamespaces.health, [r]);
    await g.setPolicy(
      CenterPolicy.empty.mute(NotificationGroup.medications, ncAt(0, 15)).mute(NotificationGroup.health, ncAt(0, 17)),
    );
    leaky.failAll = true;
    await g.setPolicy(CenterPolicy.empty);
    await g.snooze(CenterNotice.fromRequest(worry(ncAt(0, 12))), ncAt(0, 14));
    await g.removeShown(CenterNotice.fromRequest(dose));
    expect(logs, isNotEmpty, reason: 'failures were logged');
    for (final line in logs) {
      expect(line, isNot(contains('Warfarin')));
      expect(line, isNot(contains(r.title)));
      expect(line, isNot(contains('"d"')));
    }
  });

  group('V3 fails open', () {
    test('a feature describer that claims everything never lets a Money mute silence the adhan or a dose', () async {
      final greedy = NotificationDescriberRegistry(builtInDescribers())
        ..register(
          FunctionDescriber(
            id: 'greedy',
            classify: (_) => NotificationGroup.money,
            build: (n, t) => NotificationDescriberRegistry.fallbackDescription(n, t),
          ),
        );
      final (g, s) = run(groupOf: greedy.groupOf);
      await g.setPolicy(CenterPolicy.empty.mute(NotificationGroup.money, ncAt(2, 0)));
      await s.sync(NotificationNamespaces.adhan, prayers());
      final dose = medsDose(ncAt(0, 14));
      await s.sync(NotificationNamespaces.meds, [dose]);
      for (final r in [...prayers(), dose]) {
        expectWhole(r);
      }
      // …and muting Prayer still mutes the adhan.
      await g.setPolicy(CenterPolicy.empty.mute(NotificationGroup.prayer, ncAt(0, 20)));
      expect(fake.scheduled.containsKey(maghrib.id), isFalse);
    });

    test('a gate that cannot be built leaves the plugin as it is', () async {
      final c = ProviderContainer(
        overrides: [
          notificationDescribersProvider.overrideWith((ref) => throw StateError('broken registry')),
          notificationPlatformProvider.overrideWith((ref) => gatedNotificationPlatform(ref, fake)),
          notificationServiceProvider.overrideWith((ref) {
            final s = NotificationService(ref.watch(notificationPlatformProvider), clock: () => now);
            ref.onDispose(s.dispose);
            return s;
          }),
        ],
      );
      addTearDown(c.dispose);
      final report = await c.read(notificationServiceProvider).sync(NotificationNamespaces.adhan, prayers());
      expect(report.failed, 0);
      for (final r in prayers()) {
        expectWhole(r);
      }
    });

    testWidgets('a platform call that never returns delays an adhan by at most lockWait', (tester) async {
      await service.init();
      fake.hangPending = true;
      // The center's look (or a sweep) is stuck in the plugin's pending list.
      unawaited(gate.setPolicy(CenterPolicy.empty.mute(NotificationGroup.health, ncAt(1, 0))));
      var armed = false;
      unawaited(service.schedule(maghrib).then((ok) => armed = ok));
      await tester.pump(NotificationGate.lockWait - const Duration(seconds: 1));
      expect(armed, isFalse);
      await tester.pump(const Duration(seconds: 2));
      expect(armed, isTrue);
      expectWhole(maghrib);
    });
  });

  group('V4 concurrency', () {
    test('two features re-planning while a mute is applied: the adhan armed once, whole; the dose held', () async {
      final early = medsDose(ncAt(0, 14), id: 120001);
      final lateDose = medsDose(ncAt(0, 16), id: 120002);
      await Future.wait([
        service.sync(NotificationNamespaces.adhan, prayers()),
        service.sync(NotificationNamespaces.meds, [early, lateDose]),
        gate.setPolicy(CenterPolicy.empty.mute(NotificationGroup.medications, ncAt(0, 15))),
      ]);
      // (Two syncs of one namespace at once re-send in core too – the
      // adhan's syncNow runs them one after the other.)
      expect((await service.sync(NotificationNamespaces.adhan, prayers())).unchanged, 4);
      for (final r in [...prayers(), lateDose]) {
        expectWhole(r);
      }
      expect(fake.scheduled.containsKey(early.id), isFalse);
      expect(gate.held.keys, [early.id]);
      for (final r in prayers()) {
        expect(fake.scheduleLog.where((s) => s.request.id == r.id), hasLength(1), reason: 'no churn');
      }
      // The mute ends while Madar is closed: the next dose is already armed.
      now = ncAt(0, 15, 30);
      final (_, s2) = run();
      expect((await s2.sync(NotificationNamespaces.meds, [lateDose])).unchanged, 1);
    });
  });

  group('V5 mutes end on time, the app closed', () {
    test('a mute extended, then the app dies: exactly what lies after the new end sounds', () async {
      await service.sync(NotificationNamespaces.adhan, prayers());
      await gate.setPolicy(CenterPolicy.empty.mute(NotificationGroup.prayer, ncAt(0, 19)));
      expect(fake.scheduled.keys, unorderedEquals([isha.id, fajr.id, dhuhr.id]));
      await gate.setPolicy(CenterPolicy.empty.mute(NotificationGroup.prayer, MuteLength.untilMorning.endFrom(now)));
      expect(fake.scheduled.keys, [dhuhr.id]);
      expectWhole(dhuhr);
    });

    test('a mute across midnight, set before dawn: it ends this morning', () async {
      now = ncAt(1, 2, 30);
      final end = MuteLength.untilMorning.endFrom(now);
      expect(end, ncAt(1, 7));
      final (g, s) = run();
      await s.sync(NotificationNamespaces.adhan, [fajr, dhuhr]);
      await g.setPolicy(CenterPolicy.fromJson(CenterPolicy.empty.mute(NotificationGroup.prayer, end).toJson()));
      expect(fake.scheduled.keys, [dhuhr.id]);
    });

    test('an unmute stored, the app dead before re-arming: the next run arms the full requests', () async {
      await gate.setPolicy(CenterPolicy.empty.mute(NotificationGroup.prayer, ncAt(1, 7)));
      await service.sync(NotificationNamespaces.adhan, prayers());
      expect(fake.scheduled.keys, [dhuhr.id]);
      // (the unmute was stored; the process died before the sweep)
      final (g2, s2) = run();
      await g2.setPolicy(CenterPolicy.empty);
      await s2.sync(NotificationNamespaces.adhan, prayers());
      for (final r in prayers()) {
        expectWhole(r);
      }
    });
  });

  group('V6 scale', () {
    test('unmuting thousands of held alarms re-arms every one quickly', () async {
      final doses = [for (var i = 0; i < 3000; i++) medsDose(ncAt(0, 14).add(Duration(minutes: i)), id: 120000 + i)];
      await gate.setPolicy(CenterPolicy.empty.mute(NotificationGroup.medications, ncAt(5, 0)));
      await service.sync(NotificationNamespaces.meds, doses);
      expect(fake.scheduled, isEmpty);
      final watch = Stopwatch()..start();
      await gate.setPolicy(CenterPolicy.empty);
      watch.stop();
      expect(fake.scheduled, hasLength(3000));
      expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
      expect((await service.sync(NotificationNamespaces.meds, doses)).unchanged, 3000);
    });
  });

  group('V7 payload-less platforms', () {
    test('entries without payloads are never held, never listed twice, and block a tray removal of their id', () async {
      await service.sync(NotificationNamespaces.adhan, prayers());
      fake.payloadless = true;
      await gate.setPolicy(CenterPolicy.empty.mute(NotificationGroup.prayer, ncAt(2, 0)));
      expect(fake.scheduled, hasLength(4), reason: 'nothing to classify: left armed (open)');
      final shown = worry(ncAt(0, 12));
      await fake.show(shown, NotificationEnvelope.encode(shown));
      await fake.schedule(worry(ncAt(1, 21)), 'x', timing: NotificationTiming.exactWhileIdle);
      expect(await gate.removeShown(CenterNotice.fromRequest(shown)), isFalse);
      expect((await fake.pending()).length, 5);
    });

    test('a plugin that only knows shown ids: a shown notification is never mistaken for the next firing', () async {
      final ids = FakeNotificationPlatform();
      final g = NotificationGate(groupOf: registry.groupOf, clock: () => now);
      final p = GatedNotificationPlatform(_IdsOnlyPlugin(ids), g);
      final s = NotificationService(p, clock: () => now);
      addTearDown(() async {
        await s.dispose();
        await g.dispose();
      });
      final morning = medsDose(ncAt(0, 8));
      await s.show(morning);
      final evening = medsDose(ncAt(0, 20)); // the same id
      await s.sync(NotificationNamespaces.meds, [evening]);
      final active = await g.activeNotices()!;
      final at = NotificationEnvelope.decode(active.single.payload).at;
      expect(at == null || !at.isAfter(now), isTrue, reason: 'a shown notification never fires in the future');
    });
  });
}
