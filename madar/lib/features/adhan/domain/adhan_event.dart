import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show NotificationAppLaunchDetails, NotificationResponse;

import '../../../core/notifications/notification_envelope.dart';
import '../../../core/notifications/notification_models.dart';
import 'adhan_plan.dart';
import 'adhan_slot.dart';
import 'adhan_sound.dart';

/// How an [AdhanEvent] reached the app.
enum AdhanEventSource {
  /// The notification launched the app (full-screen intent or a tap on a
  /// cold start).
  launch,

  /// A tap (or full-screen intent) while the app was running.
  tap,

  /// The app was open in the foreground when the adhan time came.
  foreground,
}

/// The adhan notification's action ids.
abstract final class AdhanActions {
  static const stop = 'adhan.stop';
}

/// An adhan, reminder or sunrise alert to present on the [AdhanScreen].
@immutable
class AdhanEvent {
  const AdhanEvent({
    required this.kind,
    required this.slot,
    required this.prayerAt,
    required this.firedAt,
    required this.day,
    this.notificationId,
    this.sound,
    this.minutesBefore = 0,
    this.source = AdhanEventSource.tap,
    this.actionId,
    this.playInApp = false,
  });

  final AdhanKind kind;
  final AdhanSlot slot;

  /// The prayer (or sunrise) time.
  final DateTime prayerAt;

  /// When the alarm fired / was scheduled to fire.
  final DateTime firedAt;

  /// The prayer day (calendar date, UTC midnight).
  final DateTime day;

  /// The notification that carries it (cancel it to silence the adhan).
  final int? notificationId;
  final AdhanSoundRef? sound;
  final int minutesBefore;
  final AdhanEventSource source;

  /// The notification action the user pressed (e.g. [AdhanActions.stop]).
  final String? actionId;

  /// Play the muezzin inside the app (no notification is sounding – e.g.
  /// notifications are switched off while the app is open).
  final bool playInApp;

  /// A stable identity: the same alarm reaching the app twice (the
  /// foreground timer and a tap) is one event.
  String get key => '${kind.name}:${slot.name}:${firedAt.toUtc().millisecondsSinceEpoch}';

  /// Local calendar date of the prayer day as a `DateTime` at local midnight
  /// (what `PrayerLogService` expects).
  DateTime get localDay => DateTime(day.year, day.month, day.day);

  AdhanEvent copyWith({AdhanEventSource? source, bool? playInApp, String? actionId}) => AdhanEvent(
    kind: kind,
    slot: slot,
    prayerAt: prayerAt,
    firedAt: firedAt,
    day: day,
    notificationId: notificationId,
    sound: sound,
    minutesBefore: minutesBefore,
    source: source ?? this.source,
    actionId: actionId ?? this.actionId,
    playInApp: playInApp ?? this.playInApp,
  );

  /// The data stored in the notification payload (inside the
  /// [NotificationEnvelope]).
  Map<String, Object?> toData() => {
    'k': kind.name,
    's': slot.name,
    'p': prayerAt.toUtc().millisecondsSinceEpoch,
    'day': dayKey(day),
    if (sound != null) 'snd': sound!.key,
    if (minutesBefore > 0) 'm': minutesBefore,
  };

  static AdhanEvent fromAlarm(AdhanAlarm a, {AdhanEventSource source = AdhanEventSource.foreground}) => AdhanEvent(
    kind: a.kind,
    slot: a.slot,
    prayerAt: a.prayerAt,
    firedAt: a.at,
    day: a.day,
    notificationId: a.id,
    sound: a.sound,
    minutesBefore: a.minutesBefore,
    source: source,
  );

  /// Maps a decoded notification tap to an event (null when it is not an
  /// adhan notification or its data is malformed).
  static AdhanEvent? fromTap(NotificationTap tap) {
    if (tap.namespace != NotificationNamespaces.adhan.name) return null;
    final d = tap.data;
    final kind = AdhanKind.byName(d['k']);
    final slot = AdhanSlot.byName(d['s']);
    final p = d['p'];
    final day = parseDayKey(d['day']);
    if (kind == null || slot == null || p is! int || day == null) return null;
    final prayerAt = DateTime.fromMillisecondsSinceEpoch(p, isUtc: true);
    final m = d['m'];
    return AdhanEvent(
      kind: kind,
      slot: slot,
      prayerAt: prayerAt,
      firedAt: tap.at ?? prayerAt,
      day: day,
      notificationId: tap.id,
      sound: AdhanSoundRef.parse(d['snd']),
      minutesBefore: m is int ? m : 0,
      source: tap.fromLaunch ? AdhanEventSource.launch : AdhanEventSource.tap,
      actionId: tap.actionId,
    );
  }

  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime? parseDayKey(Object? raw) {
    if (raw is! String) return null;
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw);
    if (m == null) return null;
    return DateTime.utc(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  }

  @override
  bool operator ==(Object other) =>
      other is AdhanEvent &&
      other.key == key &&
      other.notificationId == notificationId &&
      other.source == source &&
      other.actionId == actionId &&
      other.playInApp == playInApp &&
      other.sound == sound &&
      other.minutesBefore == minutesBefore &&
      other.prayerAt == prayerAt &&
      other.day == day;

  @override
  int get hashCode => Object.hash(key, notificationId, source, actionId, playInApp, sound, minutesBefore);

  @override
  String toString() => 'AdhanEvent($key ${source.name}${actionId == null ? '' : ' action=$actionId'})';
}

/// The adhan event of the notification that launched the app, if it was an
/// adhan notification.
AdhanEvent? adhanEventFromLaunchDetails(NotificationAppLaunchDetails? details) {
  final r = details?.notificationResponse;
  if (details == null || !details.didNotificationLaunchApp || r == null) return null;
  return adhanEventFromResponse(r, fromLaunch: true);
}

/// The adhan event of a notification response (tap / action).
AdhanEvent? adhanEventFromResponse(NotificationResponse response, {bool fromLaunch = false}) {
  final action = response.actionId;
  return adhanEventFromPayload(
    response.payload,
    notificationId: response.id,
    actionId: (action == null || action.isEmpty) ? null : action,
    fromLaunch: fromLaunch,
  );
}

/// The adhan event of a raw notification payload.
AdhanEvent? adhanEventFromPayload(String? payload, {int? notificationId, String? actionId, bool fromLaunch = false}) =>
    AdhanEvent.fromTap(
      NotificationEnvelope.decode(payload, id: notificationId, actionId: actionId, fromLaunch: fromLaunch),
    );
