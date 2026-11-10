import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show NotificationAppLaunchDetails, NotificationResponse, NotificationResponseType;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/features/adhan/domain/adhan_event.dart';
import 'package:madar/features/adhan/domain/adhan_plan.dart';
import 'package:madar/features/adhan/domain/adhan_slot.dart';
import 'package:madar/features/adhan/domain/adhan_sound.dart';

NotificationRequest _requestFor(AdhanAlarm a) => NotificationRequest(
  namespace: AdhanIds.namespace,
  id: a.id,
  channelId: 'madar.adhan.call.tone-brass.v.1',
  title: 't',
  body: 'b',
  at: a.at,
  data: AdhanEvent.fromAlarm(a).toData(),
  fullScreen: true,
  dropIfLateBy: const Duration(minutes: 10),
);

void main() {
  final day = DateTime.utc(2026, 9, 28);
  final maghrib = DateTime.utc(2026, 9, 28, 15, 31);
  final alarm = AdhanAlarm(
    id: AdhanIds.of(day, AdhanKind.adhan, AdhanSlot.maghrib),
    kind: AdhanKind.adhan,
    slot: AdhanSlot.maghrib,
    at: maghrib,
    prayerAt: maghrib,
    day: day,
    sound: const AdhanSoundRef.tone(TanbihTone.brass),
  );
  final payload = NotificationEnvelope.encode(_requestFor(alarm));

  test('the payload carries everything the screen needs', () {
    final json = jsonDecode(payload) as Map<String, dynamic>;
    expect(json['ns'], 'adhan');
    expect(json['ls'], 1, reason: 'MainActivity may show it over the lock screen');
    expect(json['late'], 600000, reason: 'AdhanBootGuard drops it once 10 min late');
    expect((json['d'] as Map)['day'], '2026-09-28');

    final e = adhanEventFromPayload(payload, notificationId: alarm.id)!;
    expect(e.kind, AdhanKind.adhan);
    expect(e.slot, AdhanSlot.maghrib);
    expect(e.prayerAt, maghrib);
    expect(e.firedAt, maghrib);
    expect(e.day, day);
    expect(e.localDay, DateTime(2026, 9, 28));
    expect(e.notificationId, alarm.id);
    expect(e.sound, const AdhanSoundRef.tone(TanbihTone.brass));
    expect(e.slot.prayer, Prayer.maghrib);
    expect(e.source, AdhanEventSource.tap);
  });

  test('NotificationResponse → event (tap and action)', () {
    final tap = adhanEventFromResponse(
      NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        id: alarm.id,
        actionId: '',
        payload: payload,
      ),
    )!;
    expect(tap.actionId, isNull);
    expect(tap.key, AdhanEvent.fromAlarm(alarm).key);

    final stop = adhanEventFromResponse(
      NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotificationAction,
        id: alarm.id,
        actionId: AdhanActions.stop,
        payload: payload,
      ),
    )!;
    expect(stop.actionId, AdhanActions.stop);
  });

  test('NotificationAppLaunchDetails → event only when it launched the app', () {
    final response = NotificationResponse(
      notificationResponseType: NotificationResponseType.selectedNotification,
      id: alarm.id,
      payload: payload,
    );
    final launched = adhanEventFromLaunchDetails(NotificationAppLaunchDetails(true, notificationResponse: response));
    expect(launched?.source, AdhanEventSource.launch);
    expect(adhanEventFromLaunchDetails(NotificationAppLaunchDetails(false, notificationResponse: response)), isNull);
    expect(adhanEventFromLaunchDetails(null), isNull);
  });

  test('pre-adhan reminders keep their lead time', () {
    final pre = AdhanAlarm(
      id: AdhanIds.of(day, AdhanKind.preAdhan, AdhanSlot.asr),
      kind: AdhanKind.preAdhan,
      slot: AdhanSlot.asr,
      at: maghrib.subtract(const Duration(minutes: 10)),
      prayerAt: maghrib,
      day: day,
      minutesBefore: 10,
    );
    final e = adhanEventFromPayload(NotificationEnvelope.encode(_requestFor(pre)), notificationId: pre.id)!;
    expect(e.kind, AdhanKind.preAdhan);
    expect(e.minutesBefore, 10);
    expect(e.firedAt, pre.at);
    expect(e.prayerAt, maghrib);
    expect(e.sound, isNull);
  });

  test('foreign, other-feature and malformed payloads are not adhan events', () {
    expect(adhanEventFromPayload(null), isNull);
    expect(adhanEventFromPayload('item x'), isNull);
    final other = NotificationRequest(
      namespace: NotificationNamespaces.adhkar,
      id: NotificationNamespaces.adhkar.first,
      channelId: 'c',
      title: 't',
      body: 'b',
      at: maghrib,
      data: AdhanEvent.fromAlarm(alarm).toData(),
    );
    expect(adhanEventFromPayload(NotificationEnvelope.encode(other)), isNull);
    final broken = jsonEncode({
      'ns': 'adhan',
      'd': {'k': 'adhan', 's': 'noon', 'p': 1, 'day': '2026-09-28'},
    });
    expect(adhanEventFromPayload(broken), isNull);
    expect(AdhanEvent.parseDayKey('2026-9-28'), isNull);
  });

  test('the same alarm reaching the app twice is one event', () {
    final a = AdhanEvent.fromAlarm(alarm, source: AdhanEventSource.foreground);
    final b = adhanEventFromPayload(payload, notificationId: alarm.id)!;
    expect(a.key, b.key);
    expect(a.copyWith(playInApp: true).key, a.key);
  });
}
