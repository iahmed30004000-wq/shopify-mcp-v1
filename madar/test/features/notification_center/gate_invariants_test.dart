// Adversarial tests of the notification gate's safety invariants:
//
// 1. An adhan or dose alarm the user did not mute / skip / snooze is never
//    suppressed, delayed, duplicated or stripped of its buttons – across
//    restarts, concurrent re-syncs, exact-alarm changes and failures inside
//    the gate (it fails open).
// 2. A mute / skip / snooze does what it says without relying on memory
//    that a restart loses.
// 3. Ids stay in their namespaces; the gate never takes a feature's other
//    firing with it.
import 'dart:async';

import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/features/adhan/domain/adhan_event.dart';
import 'package:madar/features/adhan/domain/adhan_slot.dart';
import 'package:madar/features/adhkar/domain/adhkar_models.dart';
import 'package:madar/features/health/meds/data/meds_notifications.dart';
import 'package:madar/features/notification_center/notification_center.dart';

import 'nc_fixtures.dart';

/// A plugin whose calls can be made slow (a busy platform channel) or fail.
class _SlowPlatform extends FakeNotificationPlatform {
  Completer<void>? pendingGate;
  final Set<int> failInexact = {};

  @override
  Future<List<PendingNotice>> pending() async {
    final snapshot = await super.pending();
    final wait = pendingGate;
    if (wait != null) {
      pendingGate = null;
      await wait.future;
    }
    return snapshot;
  }

  @override
  Future<void> schedule(NotificationRequest request, String payload, {required NotificationTiming timing}) async {
    if (timing == NotificationTiming.inexactWhileIdle && failInexact.contains(request.id)) {
      throw PlatformException(code: 'error', message: 'plugin failure');
    }
    return super.schedule(request, payload, timing: timing);
  }
}

void main() {
  late DateTime now;
  late _SlowPlatform fake;
  late NotificationGate gate;
  late NotificationService service;
  final registry = NotificationDescriberRegistry(builtInDescribers());

  setUp(() {
    now = ncNow;
    fake = _SlowPlatform();
    gate = NotificationGate(groupOf: registry.groupOf, clock: () => now);
    service = NotificationService(GatedNotificationPlatform(fake, gate), clock: () => now);
  });
  tearDown(() async {
    await service.dispose();
    await gate.dispose();
  });

  final maghrib = adhanFull(AdhanSlot.maghrib, ncAt(0, 18, 12));
  final isha = adhanFull(AdhanSlot.isha, ncAt(0, 19, 40));
  final fajr = adhanFull(AdhanSlot.fajr, ncAt(1, 4, 20));
  List<NotificationRequest> prayers() => [maghrib, isha, fajr];

  /// A new app run over the same plugin (its pending cache survives).
  (NotificationGate, NotificationService) restart() {
    final g = NotificationGate(groupOf: registry.groupOf, clock: () => now);
    final s = NotificationService(GatedNotificationPlatform(fake, g), clock: () => now);
    addTearDown(() async {
      await s.dispose();
      await g.dispose();
    });
    return (g, s);
  }

  void expectWhole(NotificationRequest want) {
    final got = fake.scheduled[want.id];
    expect(got, isNotNull, reason: '#${want.id} must be armed');
    expect(got!.payload, NotificationEnvelope.encode(want), reason: 'exactly the feature\'s own request');
    expect(got.request.actions.map((a) => a.id), want.actions.map((a) => a.id));
    expect(got.timing, want.timing);
    expect(got.request.fullScreen, want.fullScreen);
  }

  group('#1 fails open', () {
    test('a classifier that throws never keeps an alarm from the system', () async {
      final g = NotificationGate(groupOf: (_) => throw StateError('describer bug'), clock: () => now);
      final s = NotificationService(GatedNotificationPlatform(fake, g), clock: () => now);
      addTearDown(() async {
        await s.dispose();
        await g.dispose();
      });
      await g.setPolicy(CenterPolicy.empty.mute(NotificationGroup.health, ncAt(1, 0)));
      final report = await s.sync(NotificationNamespaces.adhan, prayers());
      expect(report.failed, 0);
      for (final r in prayers()) {
        expectWhole(r);
      }
      final dose = medsDose(now);
      await s.show(dose);
      expect(fake.shown.keys, [dose.id]);
      await s.cancel(maghrib.id);
      expect(fake.scheduled.containsKey(maghrib.id), isFalse, reason: 'cancels pass through too');
    });

    test('a re-arm that fails on unmute does not strand the other held alarms', () async {
      await service.sync(NotificationNamespaces.adhan, prayers());
      await gate.setPolicy(CenterPolicy.empty.mute(NotificationGroup.prayer, ncAt(0, 20)));
      expect(fake.scheduled.keys, [fajr.id]);
      // Exact alarms revoked meanwhile, and the plugin chokes on Maghrib.
      fake.exactAllowed = false;
      fake.failInexact.add(maghrib.id);
      await gate.setPolicy(CenterPolicy.empty);
      expect(fake.scheduled.keys, contains(isha.id), reason: 'Isha is no longer muted: it must be armed');
      expect(gate.held, isEmpty);
      // Maghrib could not be armed: the feature's next sync must see it missing.
      fake.failInexact.clear();
      await service.sync(NotificationNamespaces.adhan, prayers());
      expect(fake.scheduled.keys, containsAll(prayers().map((r) => r.id)));
    });
  });

  group('#1 never stripped', () {
    test('mute + undo in a fresh run: the next feature sync restores the full alarm', () async {
      await service.sync(NotificationNamespaces.adhan, prayers());
      // A new run: the adhan feature finds its alarms unchanged (sends nothing).
      final (g2, s2) = restart();
      expect((await s2.sync(NotificationNamespaces.adhan, prayers())).unchanged, 3);
      await g2.setPolicy(CenterPolicy.empty.mute(NotificationGroup.prayer, ncAt(0, 20)));
      expect(fake.scheduled.keys, [fajr.id]);
      await g2.setPolicy(CenterPolicy.empty); // undo
      final rebuilt = fake.scheduled[maghrib.id]!;
      // Re-armed from what the plugin reported: still an alarm clock, full screen.
      expect(rebuilt.timing, NotificationTiming.alarmClock);
      expect(rebuilt.request.fullScreen, isTrue);
      expect(rebuilt.request.dropIfLateBy, maghrib.dropIfLateBy);
      expect(g2.staleNamespaces, {'adhan'}, reason: 'the adhan must re-plan to get its buttons back');
      // …and the adhan's next re-plan replaces it with its own request.
      final report = await s2.sync(NotificationNamespaces.adhan, prayers());
      expect(report.scheduled, 2);
      expectWhole(maghrib);
      expectWhole(isha);
      expect(g2.staleNamespaces, isEmpty);
    });

    test('a re-plan while muted makes the held alarm whole before the mute is lifted', () async {
      await service.sync(NotificationNamespaces.adhan, prayers());
      final (g2, s2) = restart();
      await s2.sync(NotificationNamespaces.adhan, prayers());
      await g2.setPolicy(CenterPolicy.empty.mute(NotificationGroup.prayer, ncAt(0, 20)));
      // The held copies read as changed, so the adhan re-sends them in full…
      await s2.sync(NotificationNamespaces.adhan, prayers());
      expect(fake.scheduled.keys, [fajr.id], reason: 'still muted');
      expect(g2.held[maghrib.id]!.request.actions.single.id, AdhanActions.stop);
      // …and unmuting arms exactly those.
      await g2.setPolicy(CenterPolicy.empty);
      expectWhole(maghrib);
      expectWhole(isha);
      expect((await s2.sync(NotificationNamespaces.adhan, prayers())).unchanged, 3, reason: 'no churn afterwards');
    });
  });

  group('#1 concurrency', () {
    test('a mute sweep racing an adhan re-plan never cancels the re-planned alarm', () async {
      await service.sync(NotificationNamespaces.adhan, prayers());
      // Maghrib moves after the mute's end (a new calculation method).
      final moved = adhanFull(AdhanSlot.maghrib, ncAt(0, 19, 30));
      fake.pendingGate = Completer<void>();
      final release = fake.pendingGate!;
      final sweep = gate.setPolicy(CenterPolicy.empty.mute(NotificationGroup.prayer, ncAt(0, 19)));
      await pumpEventQueue();
      final sync = service.sync(NotificationNamespaces.adhan, [moved, isha, fajr]);
      await pumpEventQueue();
      release.complete();
      await Future.wait([sweep, sync]);
      // No second re-plan comes (the app may close now): it must be armed already.
      expectWhole(moved);
      expect(fake.scheduled[moved.id]!.request.at, ncAt(0, 19, 30));
    });

    test('holding a request takes out the alarm that id still has armed from an earlier run', () async {
      final early = adhanFull(AdhanSlot.maghrib, ncAt(0, 18, 12));
      await service.sync(NotificationNamespaces.adhan, [early]);
      final (g2, s2) = restart();
      await g2.setPolicy(CenterPolicy.empty.mute(NotificationGroup.prayer, ncAt(0, 20)));
      // (The sweep already held it; the plugin still lists nothing for it.)
      expect(fake.scheduled, isEmpty);
      // Another run arms it outside the gate (the medication background
      // isolate does that for doses)…
      await fake.schedule(early, NotificationEnvelope.encode(early), timing: early.timing);
      // …then the feature moves it within the mute with a one-off schedule.
      final moved = adhanFull(AdhanSlot.maghrib, ncAt(0, 18, 20));
      expect(await s2.schedule(moved), isTrue);
      expect(fake.scheduled, isEmpty, reason: 'neither the stale 18:12 alarm nor the muted 18:20 one may sound');
      expect(g2.held[moved.id]!.request.at, ncAt(0, 18, 20));
    });
  });

  group('#1/#2 restarts, reboots, zones', () {
    test('a reboot re-arms exactly what should sound: nothing muted, the snooze, everything after the mute', () async {
      final r = adhkar(AdhkarCategoryId.morning, ncAt(0, 5, 30));
      await service.show(r);
      await gate.snooze(CenterNotice.fromRequest(r), ncAt(0, 13, 40));
      await service.sync(NotificationNamespaces.adhan, prayers());
      await gate.setPolicy(CenterPolicy.empty.mute(NotificationGroup.prayer, ncAt(0, 19)));
      // The plugin's cache is what its boot receiver re-arms (the app is dead).
      expect(fake.scheduled.keys, unorderedEquals([r.id, isha.id, fajr.id]));
      expectWhole(isha);
      expectWhole(fajr);
      expect(fake.scheduled[r.id]!.request.at, ncAt(0, 13, 40));
      // The mute ends while Madar stays closed: Maghrib's moment is gone, the rest sound.
      now = ncAt(0, 19, 1);
      final (_, s2) = restart();
      await s2.sync(NotificationNamespaces.adhan, prayers());
      expectWhole(isha);
      expectWhole(fajr);
    });

    test('a skip holds only its firing: the adhan re-planned for a new zone arrives', () async {
      await service.sync(NotificationNamespaces.adhan, prayers());
      await gate.setPolicy(CenterPolicy.empty.skip(CenterNotice.fromRequest(isha)));
      expect(fake.scheduled.containsKey(isha.id), isFalse);
      // A time-zone change: the same prayer, another instant, the same id.
      final moved = adhanFull(AdhanSlot.isha, ncAt(0, 20, 40));
      await service.sync(NotificationNamespaces.adhan, [maghrib, moved, fajr]);
      expectWhole(moved);
      expect(gate.held, isEmpty);
    });

    test('exact alarms revoked while muted: unmuting still arms them (inexactly), none lost', () async {
      await gate.setPolicy(CenterPolicy.empty.mute(NotificationGroup.prayer, ncAt(0, 20)));
      await service.sync(NotificationNamespaces.adhan, prayers());
      fake.exactAllowed = false;
      await gate.setPolicy(CenterPolicy.empty);
      expect(fake.scheduled.keys, unorderedEquals(prayers().map((r) => r.id)));
      expect(fake.scheduled[maghrib.id]!.timing, NotificationTiming.inexactWhileIdle);
      // Permission back: the adhan's re-plan (on the grant) re-arms them exactly.
      fake.exactAllowed = true;
      fake.dropArmedAlarms();
      await service.sync(NotificationNamespaces.adhan, prayers());
      expectWhole(maghrib);
    });
  });

  group('#2 in-app presentations', () {
    test('what the adhan hub asks before opening the full-screen adhan at its time', () async {
      final event = CenterNotice.fromRequest(maghrib);
      expect(gate.withholds(event), isFalse);
      await gate.setPolicy(CenterPolicy.empty.mute(NotificationGroup.prayer, ncAt(0, 19)));
      expect(gate.withholds(event), isTrue);
      expect(gate.withholds(CenterNotice.fromRequest(isha)), isFalse, reason: 'after the mute');
      await gate.setPolicy(CenterPolicy.empty.skip(CenterNotice.fromRequest(isha)));
      expect(gate.withholds(CenterNotice.fromRequest(isha)), isTrue);
      final broken = NotificationGate(groupOf: (_) => throw StateError('bug'), clock: () => now);
      await broken.setPolicy(CenterPolicy.empty.mute(NotificationGroup.adhkar, ncAt(1, 0)));
      final reminder = CenterNotice.fromRequest(adhkar(AdhkarCategoryId.evening, ncAt(0, 16)));
      expect(broken.withholds(reminder), isFalse, reason: 'open on error');
      // The adhan never goes through a classifier (pinned to Prayer): a
      // Prayer mute holds it, whatever a describer does.
      expect(broken.withholds(event), isFalse);
      await broken.setPolicy(CenterPolicy.empty.mute(NotificationGroup.prayer, ncAt(1, 0)));
      expect(broken.withholds(event), isTrue);
    });
  });

  group('#2 snoozes survive restarts', () {
    test('features re-planning before the center loads its policy leave a snooze alone', () async {
      final r = adhkar(AdhkarCategoryId.morning, ncAt(0, 5, 30));
      await service.show(r);
      expect(await gate.snooze(CenterNotice.fromRequest(r), ncAt(0, 13, 40)), isTrue);
      final (g2, s2) = restart();
      expect(g2.policyLoaded, isFalse);
      // The adhkar reminders re-plan at start (nothing wanted at that id).
      final report = await s2.sync(NotificationNamespaces.adhkar, [adhkar(AdhkarCategoryId.morning, ncAt(1, 5, 30))]);
      expect(report.cancelled, 0);
      expect(fake.scheduled[r.id]!.request.at, ncAt(0, 13, 40), reason: 'the snooze still arrives');
      expect(NotificationEnvelope.decode(fake.scheduled[r.id]!.payload).namespace, 'adhkar');
    });

    test('cancelling a stale snooze never cancels the feature\'s own alarm under that id', () async {
      final due = moneyDue(ncAt(3, 9));
      await service.sync(NotificationNamespaces.reminders, [due]);
      // The stored policy still lists a snooze of that id (the feature took it back while the app was closed).
      final old = CenterNotice.fromRequest(moneyDue(ncAt(0, 9)));
      await gate.setPolicy(CenterPolicy.empty.snooze(SnoozedNotice(notice: old, until: ncAt(0, 14))));
      await gate.cancelSnooze(due.id);
      expect(fake.scheduled[due.id]?.request.at, ncAt(3, 9));
    });
  });

  group('#1/#3 one id, two firings', () {
    test('snoozing a shown reminder never replaces the next firing of the same id', () async {
      final today = moneyDue(ncAt(0, 9));
      final next = moneyDue(ncAt(3, 9));
      await service.show(today);
      await service.sync(NotificationNamespaces.reminders, [next]);
      final ok = await gate.snooze(CenterNotice.fromRequest(today), ncAt(0, 14));
      expect(ok, isFalse, reason: 'it would take the next firing with it');
      expect(fake.scheduled[next.id]!.request.at, ncAt(3, 9));
      expect(gate.policy.snoozed, isEmpty);
    });

    test('taking a shown notification out of the tray leaves its id\'s next firing armed', () async {
      final eight = medsDose(ncAt(0, 8));
      final eight2 = medsDose(ncAt(0, 20)); // the same id, re-assigned to the evening dose
      await service.show(eight);
      await service.sync(NotificationNamespaces.meds, [eight2]);
      expect(await gate.removeShown(CenterNotice.fromRequest(eight)), isFalse);
      expectWhole(eight2);
      // Without another firing it goes.
      final worryNow = worry(now);
      await service.show(worryNow);
      expect(await gate.removeShown(CenterNotice.fromRequest(worryNow)), isTrue);
      expect(fake.shown.containsKey(worryNow.id), isFalse);
    });

    test('taking a shown notification out of the tray never drops a held firing of that id', () async {
      final eight = medsDose(ncAt(0, 8));
      final later = medsDose(ncAt(0, 14));
      await gate.setPolicy(CenterPolicy.empty.mute(NotificationGroup.medications, ncAt(0, 15)));
      await service.show(eight); // silenced by the mute
      await service.sync(NotificationNamespaces.meds, [later]);
      expect(gate.held.keys, [later.id]);
      await gate.removeShown(CenterNotice.fromRequest(eight));
      await gate.setPolicy(CenterPolicy.empty);
      expectWhole(later);
    });
  });

  group('#2 background re-plans', () {
    test('the medication background re-plan through a policy-loaded gate holds a muted dose', () async {
      final dose = medsDose(ncAt(0, 14));
      final policy = CenterPolicy.empty.mute(NotificationGroup.medications, ncAt(0, 15));
      // As wired today: a bare service over the plugin arms it during the mute.
      final bare = NotificationService(fake, clock: () => now);
      addTearDown(bare.dispose);
      await bare.sync(NotificationNamespaces.meds, [dose]);
      expect(fake.scheduled.keys, [dose.id], reason: 'the violation the wiring change removes');
      await fake.cancel(dose.id);
      // Through a background gate with the stored policy: held.
      final bgGate = NotificationGate.background(clock: () => now);
      await bgGate.setPolicy(policy, sweep: false);
      final bg = NotificationService(GatedNotificationPlatform(fake, bgGate), clock: () => now);
      addTearDown(bg.dispose);
      await bg.sync(NotificationNamespaces.meds, [dose]);
      expect(fake.scheduled, isEmpty);
      // It never sweeps other features' alarms, and still shows the failure notice.
      await fake.schedule(maghrib, NotificationEnvelope.encode(maghrib), timing: maghrib.timing);
      await bgGate.setPolicy(policy.mute(NotificationGroup.prayer, ncAt(0, 20)), sweep: false);
      expect(fake.scheduled.keys, [maghrib.id]);
      await bg.show(medsFailed(now));
      expect(fake.shown, hasLength(1));
      expect(MedsNotificationTaps.isMeds(NotificationEnvelope.decode(fake.shown.values.single.payload)), isTrue);
    });
  });

  group('#3 hygiene', () {
    test('what the gate marks is invisible to the feature\'s tap and to the boot guard keys', () async {
      final r = adhkar(AdhkarCategoryId.evening, ncAt(0, 12));
      await service.show(r);
      await gate.snooze(CenterNotice.fromRequest(r), ncAt(0, 14));
      final payload = fake.scheduled[r.id]!.payload;
      final tap = NotificationEnvelope.decode(payload, id: r.id);
      expect(tap.data, r.data);
      expect(tap.namespace, 'adhkar');
      expect(tap.at, ncAt(0, 14).toUtc());
      expect(GateMarks.of(payload), GateMarks.snooze);
      expect(GateMarks.of(NotificationEnvelope.encode(r)), isNull);
      expect(GateMarks.strip(payload), NotificationEnvelope.encode(r.copyWith(at: ncAt(0, 14))));
    });

    test('held requests never outlive their moment', () async {
      await gate.setPolicy(CenterPolicy.empty.mute(NotificationGroup.prayer, ncAt(1, 7)));
      await service.sync(NotificationNamespaces.adhan, prayers());
      expect(gate.held, hasLength(3));
      now = ncAt(1, 5);
      await gate.setPolicy(gate.policy);
      expect(gate.held, isEmpty);
      expect(gate.staleNamespaces, isEmpty);
    });
  });
}
