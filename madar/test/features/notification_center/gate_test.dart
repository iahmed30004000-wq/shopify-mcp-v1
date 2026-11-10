import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/features/adhan/domain/adhan_slot.dart';
import 'package:madar/features/adhkar/domain/adhkar_models.dart';
import 'package:madar/features/notification_center/notification_center.dart';

import 'nc_fixtures.dart';

void main() {
  late DateTime now;
  late FakeNotificationPlatform fake;
  late NotificationGate gate;
  late NotificationService service;
  final registry = NotificationDescriberRegistry(builtInDescribers());

  setUp(() {
    now = ncNow;
    fake = FakeNotificationPlatform();
    gate = NotificationGate(groupOf: registry.groupOf, clock: () => now);
    service = NotificationService(GatedNotificationPlatform(fake, gate), clock: () => now);
  });
  tearDown(() async {
    await service.dispose();
    await gate.dispose();
  });

  final maghrib = adhanCall(AdhanSlot.maghrib, ncAt(0, 18, 12));
  final isha = adhanCall(AdhanSlot.isha, ncAt(0, 19, 40));
  final fajr = adhanCall(AdhanSlot.fajr, ncAt(1, 4, 20));
  List<NotificationRequest> prayers() => [maghrib, isha, fajr];

  test('passes everything through when nothing is muted', () async {
    expect(gate.attached, isTrue);
    final report = await service.sync(NotificationNamespaces.adhan, prayers());
    expect(report.scheduled, 3);
    expect(fake.scheduled.keys, unorderedEquals(prayers().map((r) => r.id)));
    expect((await service.pendingNotices()).map((p) => p.id), [maghrib.id, isha.id, fajr.id]);
    expect((await service.pendingNotices()).first.title, maghrib.title);
  });

  test('a mute holds back what falls inside it – listed as pending, no churn on re-sync', () async {
    await gate.setPolicy(CenterPolicy.empty.mute(NotificationGroup.prayer, ncAt(0, 20)));
    final first = await service.sync(NotificationNamespaces.adhan, prayers());
    expect(first.scheduled, 3, reason: 'the feature asked for all three');
    expect(fake.scheduled.keys, [fajr.id], reason: 'only Fajr reached the system');
    expect(gate.held.keys, unorderedEquals([maghrib.id, isha.id]));
    // The feature re-plans (e.g. on resume): the held ones read unchanged.
    fake.scheduleLog.clear();
    final again = await service.sync(NotificationNamespaces.adhan, prayers());
    expect(again.unchanged, 3);
    expect(again.scheduled, 0);
    expect(fake.scheduleLog, isEmpty);
    // The center still lists them.
    expect((await service.pendingNotices()).map((p) => p.id), [maghrib.id, isha.id, fajr.id]);
  });

  test('muting sweeps what is already armed; unmuting re-arms it with its buttons', () async {
    await service.sync(NotificationNamespaces.adhan, prayers());
    await gate.setPolicy(CenterPolicy.empty.mute(NotificationGroup.prayer, ncAt(0, 20)));
    expect(fake.scheduled.keys, [fajr.id]);
    expect(fake.cancelled, containsAll([maghrib.id, isha.id]));
    await gate.setPolicy(CenterPolicy.empty);
    expect(fake.scheduled.keys, unorderedEquals(prayers().map((r) => r.id)));
    expect(fake.scheduled[maghrib.id]!.request.actions.single.id, maghrib.actions.single.id);
    expect(fake.scheduled[maghrib.id]!.timing, NotificationTiming.alarmClock);
    expect(gate.held, isEmpty);
    // …and nothing churns afterwards.
    final report = await service.sync(NotificationNamespaces.adhan, prayers());
    expect(report.unchanged, 3);
  });

  test('a mute that ends leaves nothing unarmed: only moments inside it were held', () async {
    await gate.setPolicy(CenterPolicy.empty.mute(NotificationGroup.prayer, ncAt(0, 19)));
    await service.sync(NotificationNamespaces.adhan, prayers());
    expect(gate.held.keys, [maghrib.id]);
    expect(fake.scheduled.keys, unorderedEquals([isha.id, fajr.id]));
    now = ncAt(0, 18, 30); // Maghrib's moment passed while muted
    final list = await service.pendingNotices();
    expect(list.map((p) => p.id), unorderedEquals([isha.id, fajr.id]));
    expect(gate.held, isEmpty);
  });

  test('other groups are untouched by a mute', () async {
    await gate.setPolicy(CenterPolicy.empty.mute(NotificationGroup.prayer, ncAt(2, 0)));
    final r = adhkar(AdhkarCategoryId.evening, ncAt(0, 16));
    await service.sync(NotificationNamespaces.adhkar, [r]);
    expect(fake.scheduled.keys, [r.id]);
  });

  test('a muted show() is silenced and reported, never posted', () async {
    await gate.setPolicy(CenterPolicy.empty.mute(NotificationGroup.medications, ncAt(0, 15)));
    final silenced = <CenterNotice>[];
    final sub = gate.silenced.listen(silenced.add);
    await service.show(medsRefill(now));
    await pumpEventQueue();
    expect(fake.shown, isEmpty);
    expect(silenced.single.namespace, 'meds');
    await sub.cancel();
    // Other groups still show.
    await service.show(worry(now));
    expect(fake.shown, hasLength(1));
  });

  test('a skip holds one firing only', () async {
    await service.sync(NotificationNamespaces.adhan, prayers());
    final isha0 = CenterNotice.fromRequest(isha);
    await gate.setPolicy(CenterPolicy.empty.skip(isha0));
    expect(fake.scheduled.keys, unorderedEquals([maghrib.id, fajr.id]));
    expect(gate.held.keys, [isha.id]);
    final report = await service.sync(NotificationNamespaces.adhan, prayers());
    expect(report.unchanged, 3);
    await gate.setPolicy(CenterPolicy.empty);
    expect(fake.scheduled.keys, contains(isha.id));
  });

  test('a snooze re-arms a shown notification later, hidden from the feature sync', () async {
    final r = adhkar(AdhkarCategoryId.morning, ncAt(0, 5, 30));
    await service.show(r);
    final shown = CenterNotice.fromRequest(r);
    final ok = await gate.snooze(shown, ncAt(0, 13, 40));
    expect(ok, isTrue);
    expect(fake.shown, isEmpty, reason: 'out of the tray');
    final again = fake.scheduled[r.id]!;
    expect(again.request.at, ncAt(0, 13, 40));
    expect(again.request.title, r.title);
    expect(NotificationEnvelope.decode(again.payload).data, {'set': 'morning'});
    expect(gate.policy.snoozed.keys, [r.id]);
    // The adhkar sync (which wants no pending reminder at that id) leaves it.
    final report = await service.sync(NotificationNamespaces.adhkar, const []);
    expect(report.cancelled, 0);
    expect(fake.scheduled.keys, [r.id]);
    expect(await service.pendingNotices(), isEmpty, reason: 'hidden from pending lists');
    // It fires; the tap still routes as an adhkar reminder.
    fake.fireDue(ncAt(0, 13, 41));
    final tap = NotificationEnvelope.decode(fake.shown[r.id]!.payload, id: r.id);
    expect(tap.namespace, 'adhkar');
  });

  test('a feature that re-schedules or cancels a snoozed id takes it back', () async {
    final r = medsDose(ncAt(0, 12));
    await service.show(r);
    await gate.snooze(CenterNotice.fromRequest(r), ncAt(0, 14));
    final changes = <CenterPolicy>[];
    final sub = gate.policyChanges.listen(changes.add);
    await service.cancel(r.id);
    await pumpEventQueue();
    expect(gate.policy.snoozed, isEmpty);
    expect(changes, hasLength(1));
    expect(fake.scheduled, isEmpty);
    await sub.cancel();
  });

  test('features cancelling upcoming notifications are reported (not "delivered")', () async {
    await service.sync(NotificationNamespaces.adhan, prayers());
    final cancelled = <CenterNotice>[];
    final sub = gate.cancelled.listen(cancelled.add);
    await service.sync(NotificationNamespaces.adhan, [maghrib, fajr]);
    await pumpEventQueue();
    expect(cancelled.map((n) => n.id), [isha.id]);
    await sub.cancel();
  });

  test('held ones count as armed; a dropped alarm is still re-armed', () async {
    await gate.setPolicy(CenterPolicy.empty.mute(NotificationGroup.prayer, ncAt(0, 19)));
    await service.sync(NotificationNamespaces.adhan, prayers());
    fake.dropArmedAlarms();
    final report = await service.sync(NotificationNamespaces.adhan, prayers());
    expect(report.rearmed, 2, reason: 'Isha and Fajr, not the held Maghrib');
    expect(gate.held.keys, [maghrib.id]);
  });

  test('active notices come with their payload through the gate', () async {
    await service.show(worry(now));
    final active = await service.activeNotices();
    expect(active.single.payload, isNotNull);
    expect(CenterNotice.fromPayload(active.single.id, active.single.payload).namespace, 'health');
  });

  test('the gate reads the tray from the platform it wraps (whatever wraps the gate)', () async {
    await service.show(worry(now));
    final active = await gate.activeNotices()!;
    expect(CenterNotice.fromPayload(active.single.id, active.single.payload).namespace, 'health');
    expect(NotificationGate().activeNotices(), isNull, reason: 'not attached');
  });

  test('a request can be rebuilt from what the platform reports', () {
    final n = CenterNotice.fromPayload(maghrib.id, NotificationEnvelope.encode(maghrib), title: 'T', body: 'B');
    final r = NotificationGate.requestFor(n, at: ncAt(0, 19), now: now);
    expect(r.namespace, NotificationNamespaces.adhan);
    expect(r.channelId, maghrib.channelId);
    expect(r.at, ncAt(0, 19));
    expect(r.data, maghrib.data);
    expect(r.title, 'T');
  });
}
