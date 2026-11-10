import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/notifications/notifications.dart';

const _ns = NotificationNamespaces.adhkar;

NotificationRequest _req(int offset, DateTime at, {String title = 't', Map<String, Object?> data = const {}}) =>
    NotificationRequest(
      namespace: _ns,
      id: _ns.id(offset),
      channelId: 'c',
      title: title,
      body: 'b',
      at: at,
      data: data,
      dropIfLateBy: const Duration(minutes: 5),
    );

void main() {
  final now = DateTime.utc(2026, 9, 28, 10);
  late FakeNotificationPlatform platform;
  late NotificationService service;

  setUp(() {
    platform = FakeNotificationPlatform();
    service = NotificationService(platform, clock: () => now);
  });

  group('envelope', () {
    test('round-trips namespace, data, channel and instant', () {
      final r = _req(3, now.add(const Duration(hours: 1)), data: {'k': 'v', 'n': 2});
      final payload = NotificationEnvelope.encode(r);
      final json = jsonDecode(payload) as Map<String, dynamic>;
      expect(json['ns'], 'adhkar');
      expect(json['late'], 300000);
      expect(json['at'], now.add(const Duration(hours: 1)).millisecondsSinceEpoch);
      expect(json.containsKey('ls'), isFalse);
      final tap = NotificationEnvelope.decode(payload, id: r.id, actionId: 'a');
      expect(tap.namespace, 'adhkar');
      expect(tap.data, {'k': 'v', 'n': 2});
      expect(tap.channelId, 'c');
      expect(tap.at, now.add(const Duration(hours: 1)));
      expect(tap.actionId, 'a');
    });

    test('changes when anything visible changes', () {
      final at = now.add(const Duration(hours: 1));
      final a = NotificationEnvelope.encode(_req(1, at));
      expect(NotificationEnvelope.encode(_req(1, at)), a);
      expect(NotificationEnvelope.encode(_req(1, at, title: 'other')), isNot(a));
      expect(NotificationEnvelope.encode(_req(1, at.add(const Duration(minutes: 1)))), isNot(a));
    });

    test('foreign or malformed payloads decode without a namespace', () {
      expect(NotificationEnvelope.decode('hello').namespace, isNull);
      expect(NotificationEnvelope.decode('hello').data['raw'], 'hello');
      expect(NotificationEnvelope.decode('{"x":1}').namespace, isNull);
      expect(NotificationEnvelope.decode(null).data, isEmpty);
    });
  });

  group('namespaces', () {
    test('never overlap', () {
      final all = NotificationNamespaces.all;
      for (var i = 0; i < all.length; i++) {
        for (var j = i + 1; j < all.length; j++) {
          expect(all[i].last < all[j].first || all[j].last < all[i].first, isTrue);
        }
      }
      expect(NotificationNamespaces.owning(100005), NotificationNamespaces.adhan);
      expect(NotificationNamespaces.byName('meds'), NotificationNamespaces.meds);
      expect(() => _ns.id(_ns.size), throwsRangeError);
    });
  });

  group('sync', () {
    test('schedules new, skips identical, cancels unwanted', () async {
      final a = _req(0, now.add(const Duration(hours: 1)));
      final b = _req(1, now.add(const Duration(hours: 2)));
      final first = await service.sync(_ns, [a, b]);
      expect(first.scheduled, 2);
      expect(platform.scheduled.keys, unorderedEquals([a.id, b.id]));

      final second = await service.sync(_ns, [a, b]);
      expect(second.scheduled, 0);
      expect(second.unchanged, 2);
      expect(platform.scheduleLog, hasLength(2), reason: 'no alarm churn');

      final c = _req(2, now.add(const Duration(hours: 3)));
      final third = await service.sync(_ns, [b, c]);
      expect(third.cancelled, 1);
      expect(third.scheduled, 1);
      expect(third.unchanged, 1);
      expect(platform.scheduled.keys, unorderedEquals([b.id, c.id]));
      expect(platform.cancelled, [a.id]);
    });

    test('alarms the system dropped (force stop, OEM task killer) are re-armed although the plugin still lists them', () async {
      final a = _req(0, now.add(const Duration(hours: 1)));
      final b = _req(1, now.add(const Duration(hours: 2)));
      await service.sync(_ns, [a, b]);
      platform.dropArmedAlarms();
      expect(await platform.pending(), hasLength(2), reason: "the plugin's cache survives a force stop");

      final report = await service.sync(_ns, [a, b]);
      expect(report.scheduled, 2, reason: 'identical payloads, but nothing is armed any more');
      expect(report.unchanged, 0);
      expect(await platform.armedIds([a.id, b.id]), {a.id, b.id});

      // Armed again → the next reconcile touches nothing.
      final again = await service.sync(_ns, [a, b]);
      expect(again.unchanged, 2);
      expect(again.scheduled, 0);
    });

    test('a platform that cannot tell what is armed trusts its pending list', () async {
      final a = _req(0, now.add(const Duration(hours: 1)));
      await service.sync(_ns, [a]);
      platform
        ..dropArmedAlarms()
        ..reportsArmed = false;
      final report = await service.sync(_ns, [a]);
      expect(report.unchanged, 1);
    });

    test('a changed request is re-scheduled under the same id', () async {
      await service.sync(_ns, [_req(0, now.add(const Duration(hours: 1)))]);
      final report = await service.sync(_ns, [_req(0, now.add(const Duration(hours: 1)), title: 'new')]);
      expect(report.scheduled, 1);
      expect(platform.scheduled[_ns.id(0)]!.request.title, 'new');
    });

    test('skips moments already past and cancels them if pending', () async {
      await service.sync(_ns, [_req(0, now.add(const Duration(minutes: 1)))]);
      final later = NotificationService(platform, clock: () => now.add(const Duration(minutes: 2)));
      final report = await later.sync(_ns, [_req(0, now.add(const Duration(minutes: 1)))]);
      expect(report.skippedPast, 1);
      expect(report.cancelled, 1);
      expect(platform.scheduled, isEmpty);
    });

    test('leaves other namespaces alone', () async {
      final other = NotificationRequest(
        namespace: NotificationNamespaces.meds,
        id: NotificationNamespaces.meds.id(0),
        channelId: 'm',
        title: 'm',
        body: 'm',
        at: now.add(const Duration(hours: 1)),
      );
      await service.sync(NotificationNamespaces.meds, [other]);
      await service.sync(_ns, const []);
      expect(platform.scheduled.keys, [other.id]);
    });

    test('rejects ids outside the namespace and duplicates', () async {
      final foreign = NotificationRequest(
        namespace: _ns,
        id: 5,
        channelId: 'c',
        title: 't',
        body: 'b',
        at: now.add(const Duration(hours: 1)),
      );
      expect(() => service.sync(_ns, [foreign]), throwsArgumentError);
      final a = _req(0, now.add(const Duration(hours: 1)));
      expect(() => service.sync(_ns, [a, a]), throwsArgumentError);
    });

    test('keeps one-off notifications the plan does not own', () async {
      final snooze = _req(9, now.add(const Duration(minutes: 5)));
      await service.schedule(snooze);
      final report = await service.sync(_ns, [
        _req(0, now.add(const Duration(hours: 1))),
      ], keep: (id) => id == snooze.id);
      expect(report.cancelled, 0);
      expect(platform.scheduled.keys, containsAll([snooze.id, _ns.id(0)]));
      await service.sync(_ns, const []);
      expect(platform.scheduled, isEmpty);
    });

    test('falls back to inexact when exact alarms are refused', () async {
      platform.exactAllowed = false;
      final report = await service.sync(_ns, [_req(0, now.add(const Duration(hours: 1)))]);
      expect(report.scheduled, 1);
      expect(report.inexactFallback, 1);
      expect(platform.scheduled.values.single.timing, NotificationTiming.inexactWhileIdle);
    });
  });

  group('channels', () {
    test('creates, renames and prunes by prefix', () async {
      const a = NotificationChannelSpec(id: 'x.a', name: 'A', sound: NotificationSoundSpec.raw('one'));
      const b = NotificationChannelSpec(id: 'x.b', name: 'B');
      const keep = NotificationChannelSpec(id: 'y.keep', name: 'K');
      await service.ensureChannels([a, b, keep]);
      await service.ensureChannels([
        const NotificationChannelSpec(id: 'x.a', name: 'A2', sound: NotificationSoundSpec.raw('two')),
      ], prunePrefix: 'x.');
      expect(platform.channels.keys, unorderedEquals(['x.a', 'y.keep']));
      expect(platform.channels['x.a']!.name, 'A2');
      expect(platform.channels['x.a']!.sound, const NotificationSoundSpec.raw('one'), reason: 'frozen at creation');
      expect(platform.deletedChannels, ['x.b']);
    });
  });

  group('taps', () {
    test('the launch notification is returned once', () async {
      final r = _req(0, now.add(const Duration(hours: 1)), data: {'k': 1});
      platform.launch = RawNotificationTap(id: r.id, payload: NotificationEnvelope.encode(r), fromLaunch: true);
      final tap = await service.takeLaunchTap();
      expect(tap?.namespace, 'adhkar');
      expect(tap?.fromLaunch, isTrue);
      expect(await service.takeLaunchTap(), isNull);
    });

    test('taps while running are decoded and streamed', () async {
      await service.init();
      final r = _req(0, now.add(const Duration(hours: 1)), data: {'k': 1});
      final next = service.taps.first;
      platform.tap(RawNotificationTap(id: r.id, actionId: 'go', payload: NotificationEnvelope.encode(r)));
      final tap = await next;
      expect(tap.id, r.id);
      expect(tap.actionId, 'go');
      expect(tap.data, {'k': 1});
    });
  });

  test('pendingIn lists a namespace soonest first', () async {
    await service.sync(_ns, [_req(1, now.add(const Duration(hours: 2))), _req(0, now.add(const Duration(hours: 1)))]);
    final pending = await service.pendingIn(_ns);
    expect(pending.map((p) => p.id), [_ns.id(0), _ns.id(1)]);
  });
}
