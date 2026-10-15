import 'package:flutter/foundation.dart';

import '../../../core/notifications/notification_models.dart';
import '../../../core/notifications/notification_service.dart';
import '../domain/adhan_event.dart';
import '../domain/adhan_plan.dart';
import '../domain/adhan_settings.dart';
import '../domain/adhan_slot.dart';
import '../domain/adhan_sound.dart';
import 'adhan_system.dart';
import 'adhan_texts.dart';

/// What one [AdhanScheduler.sync] did.
@immutable
class AdhanSyncResult {
  const AdhanSyncResult({required this.plan, required this.report, required this.at});

  final List<AdhanAlarm> plan;
  final NotificationSyncReport report;
  final DateTime at;

  /// Exact alarms were refused, so some alerts may come minutes late.
  bool get degraded => report.inexactFallback > 0;

  AdhanAlarm? nextCall(DateTime now) => AdhanPlanner.nextCall(plan, now);
}

/// Turns the adhan settings and the prayer times into pending exact alarms
/// and the notification channels they play on.
///
/// Channels (Android freezes a channel's sound, vibration and audio usage at
/// creation, so each combination is its own channel; old ones are deleted):
/// * `madar.adhan.call.<sound>.<v|q>.1` – the adhan: urgent, alarm stream
///   (alarm volume; sounds in silent mode and, by default, in Do Not
///   Disturb), the muezzin as channel sound (a raw tanbih tone, or a
///   `content://` URI of a recording), full-screen intent.
/// * `madar.adhan.reminder.<v|q>.1` – pre-adhan reminders (chime).
/// * `madar.adhan.sunrise.<v|q>.1` – the sunrise alert.
///
/// Alarms use `AlarmManager.setAlarmClock` (see [NotificationTiming]): the
/// only mode that is exact, leaves Doze, ignores battery saver and app
/// standby. If exact alarms are refused they fall back to inexact.
class AdhanScheduler {
  AdhanScheduler({
    required this.notifications,
    required this.system,
    this.planner = const AdhanPlanner(),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final NotificationService notifications;
  final AdhanSystem system;
  final AdhanPlanner planner;
  final DateTime Function() _clock;

  static const channelPrefix = 'madar.adhan.';
  static const groupId = 'madar.adhan';

  /// The adhan notification disappears (sound included) after this long.
  static const callTimeout = Duration(minutes: 15);

  /// After a reboot, alarms later than this are not restored.
  static const callDropIfLate = Duration(minutes: 10);
  static const reminderDropIfLate = Duration(minutes: 3);

  static const callVibration = [0, 700, 500, 700, 500, 700];
  static const reminderVibration = [0, 250, 180, 250];

  static String callChannelId(AdhanSoundRef sound, {required bool vibrate}) =>
      '${channelPrefix}call.${sound.key.replaceAll(':', '-')}.${vibrate ? 'v' : 'q'}.1';
  static String reminderChannelId({required bool vibrate}) => '${channelPrefix}reminder.${vibrate ? 'v' : 'q'}.1';
  static String sunriseChannelId({required bool vibrate}) => '${channelPrefix}sunrise.${vibrate ? 'v' : 'q'}.1';

  /// Re-plans everything: channels, then the pending alarms of the next days.
  /// Idempotent – unchanged alarms are left alone.
  Future<AdhanSyncResult> sync({
    required AdhanSettings settings,
    required AdhanTimesFor timesFor,
    required LocalDayOf localDayOf,
    required AdhanTexts texts,
  }) async {
    final now = _clock();
    final plan = planner.plan(settings: settings, now: now, timesFor: timesFor, localDayOf: localDayOf);
    final sounds = await _ensureChannels(settings, texts);
    final requests = [for (final a in plan) _request(a, settings, texts, sounds)];
    final report = await notifications.sync(AdhanIds.namespace, requests, keep: AdhanIds.isOneOff);
    return AdhanSyncResult(plan: plan, report: report, at: now);
  }

  /// Creates the channels; returns the channel id of every call sound in
  /// use (a recording whose file vanished maps to its slot's default tone).
  Future<Map<AdhanSoundRef, String>> _ensureChannels(AdhanSettings settings, AdhanTexts texts) async {
    await notifications.ensureChannelGroup(groupId, texts.channelGroup);
    final v = settings.vibrate;
    final specs = <NotificationChannelSpec>[];
    final ids = <AdhanSoundRef, String>{};
    for (final slot in const [AdhanSlot.fajr, AdhanSlot.dhuhr]) {
      var ref = settings.resolve(settings.soundFor(slot), slot);
      NotificationSoundSpec? spec = switch (ref.kind) {
        AdhanSoundKind.tone => NotificationSoundSpec.raw(ref.tone!.rawName),
        AdhanSoundKind.silent => const NotificationSoundSpec.silent(),
        AdhanSoundKind.file => null,
      };
      if (ref.kind == AdhanSoundKind.file) {
        final m = settings.muezzinById(ref.fileId)!;
        final uri = await system.soundUri(m.fileName);
        if (uri != null) {
          spec = NotificationSoundSpec.uri(uri);
        } else {
          final fallback = slot == AdhanSlot.fajr ? TanbihTone.dawn : TanbihTone.brass;
          ids[ref] = callChannelId(AdhanSoundRef.tone(fallback), vibrate: v);
          ref = AdhanSoundRef.tone(fallback);
          spec = NotificationSoundSpec.raw(fallback.rawName);
        }
      }
      final id = callChannelId(ref, vibrate: v);
      ids[ref] = id;
      if (specs.any((s) => s.id == id)) continue;
      specs.add(
        NotificationChannelSpec(
          id: id,
          name: texts.channelCall(texts.soundName(ref, muezzin: settings.muezzinById(ref.fileId))),
          description: texts.channelCallDescription,
          importance: NotificationImportance.urgent,
          sound: spec!,
          vibrate: v,
          vibrationPattern: v ? callVibration : null,
          usage: NotificationAudioUsage.alarm,
          groupId: groupId,
        ),
      );
    }
    specs
      ..add(
        NotificationChannelSpec(
          id: reminderChannelId(vibrate: v),
          name: texts.channelReminder,
          importance: NotificationImportance.high,
          sound: NotificationSoundSpec.raw(TanbihTone.chime.rawName),
          vibrate: v,
          vibrationPattern: v ? reminderVibration : null,
          groupId: groupId,
        ),
      )
      ..add(
        NotificationChannelSpec(
          id: sunriseChannelId(vibrate: v),
          name: texts.channelSunrise,
          importance: NotificationImportance.high,
          sound: NotificationSoundSpec.raw(TanbihTone.sunrise.rawName),
          vibrate: v,
          vibrationPattern: v ? reminderVibration : null,
          groupId: groupId,
        ),
      );
    await notifications.ensureChannels(specs, prunePrefix: channelPrefix);
    return ids;
  }

  NotificationRequest _request(
    AdhanAlarm a,
    AdhanSettings settings,
    AdhanTexts texts,
    Map<AdhanSoundRef, String> callChannels,
  ) {
    final data = AdhanEvent.fromAlarm(a).toData();
    final v = settings.vibrate;
    switch (a.kind) {
      case AdhanKind.adhan || AdhanKind.test:
        final sound = a.sound ?? settings.soundFor(a.slot);
        return NotificationRequest(
          namespace: AdhanIds.namespace,
          id: a.id,
          channelId: callChannels[sound] ?? callChannelId(sound, vibrate: v),
          title: a.kind == AdhanKind.test ? texts.testTitle(a.slot) : texts.callTitle(a.slot),
          body: a.kind == AdhanKind.test ? texts.testBody : texts.callBody(a.prayerAt),
          at: a.at,
          data: data,
          category: NotificationCategory.alarm,
          timing: NotificationTiming.alarmClock,
          fullScreen: settings.fullScreen,
          publicOnLockScreen: true,
          timeout: callTimeout,
          dropIfLateBy: callDropIfLate,
          actions: [NotificationActionSpec(id: AdhanActions.stop, title: texts.stopAction)],
          autoCancel: true,
        );
      case AdhanKind.preAdhan || AdhanKind.snooze:
        final left = a.prayerAt.difference(a.at);
        return NotificationRequest(
          namespace: AdhanIds.namespace,
          id: a.id,
          channelId: reminderChannelId(vibrate: v),
          title: texts.preTitle(a.slot, a.minutesBefore),
          body: texts.preBody(a.prayerAt),
          at: a.at,
          data: data,
          category: NotificationCategory.reminder,
          timing: NotificationTiming.alarmClock,
          publicOnLockScreen: true,
          // Gone once the adhan itself arrives.
          timeout: left > Duration.zero ? left : const Duration(minutes: 1),
          dropIfLateBy: reminderDropIfLate,
        );
      case AdhanKind.sunrise:
        return NotificationRequest(
          namespace: AdhanIds.namespace,
          id: a.id,
          channelId: sunriseChannelId(vibrate: v),
          title: texts.sunriseTitle(a.minutesBefore),
          body: texts.sunriseBody(a.minutesBefore, a.prayerAt),
          at: a.at,
          data: data,
          category: NotificationCategory.reminder,
          timing: NotificationTiming.alarmClock,
          publicOnLockScreen: true,
          timeout: const Duration(minutes: 30),
          dropIfLateBy: callDropIfLate,
        );
    }
  }

  /// "Test adhan now": a real adhan notification of [slot]'s sound in
  /// [delay] – through the same channel, alarm and full-screen path, so
  /// locking the screen shows exactly what the real adhan will do.
  /// Returns the test's event (null if it could not be scheduled).
  Future<AdhanEvent?> scheduleTest({
    required AdhanSettings settings,
    required AdhanTexts texts,
    AdhanSlot slot = AdhanSlot.maghrib,
    Duration delay = const Duration(seconds: 10),
  }) async {
    final sounds = await _ensureChannels(settings, texts);
    final now = _clock();
    final at = now.add(delay);
    final alarm = AdhanAlarm(
      id: AdhanIds.test,
      kind: AdhanKind.test,
      slot: slot,
      at: at,
      prayerAt: at,
      day: DateTime.utc(at.year, at.month, at.day),
      sound: settings.resolve(settings.soundFor(slot), slot),
    );
    final ok = await notifications.schedule(_request(alarm, settings, texts, sounds));
    return ok ? AdhanEvent.fromAlarm(alarm, source: AdhanEventSource.tap) : null;
  }

  /// Snoozes a reminder by the settings' snooze length – only while that
  /// still leaves the reminder before the adhan. False when it cannot.
  Future<bool> snooze(AdhanEvent event, {required AdhanSettings settings, required AdhanTexts texts}) async {
    if (!canSnooze(event, settings: settings, now: _clock())) return false;
    final at = _clock().add(Duration(minutes: settings.snoozeMinutes));
    final left = event.prayerAt.difference(at);
    final alarm = AdhanAlarm(
      id: AdhanIds.snooze,
      kind: AdhanKind.snooze,
      slot: event.slot,
      at: at,
      prayerAt: event.prayerAt,
      day: event.day,
      minutesBefore: (left.inSeconds / 60).ceil(),
    );
    await _ensureChannels(settings, texts);
    return notifications.schedule(_request(alarm, settings, texts, const {}));
  }

  /// A snooze must still ring at least a minute before the adhan.
  static bool canSnooze(AdhanEvent event, {required AdhanSettings settings, required DateTime now}) {
    if (event.kind != AdhanKind.preAdhan && event.kind != AdhanKind.snooze) return false;
    final at = now.add(Duration(minutes: settings.snoozeMinutes));
    return event.prayerAt.difference(at) >= const Duration(minutes: 1);
  }

  /// Silences a sounding adhan (cancelling its notification stops the
  /// channel sound).
  Future<void> silence(AdhanEvent event) async {
    final id = event.notificationId;
    if (id != null) await notifications.cancel(id);
  }

  Future<void> cancelAll() => notifications.cancelNamespace(AdhanIds.namespace);
}
