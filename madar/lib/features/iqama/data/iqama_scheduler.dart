import 'package:flutter/foundation.dart';

import '../../../core/notifications/notification_models.dart';
import '../../../core/notifications/notification_service.dart';
import '../../adhan/data/adhan_system.dart';
import '../../adhan/domain/adhan_plan.dart';
import '../../adhan/domain/adhan_settings.dart';
import '../../adhan/domain/adhan_slot.dart';
import '../../adhan/domain/adhan_sound.dart';
import '../domain/iqama_event.dart';
import '../domain/iqama_plan.dart';
import '../domain/iqama_settings.dart';
import 'iqama_texts.dart';

/// What one [IqamaScheduler.sync] did.
@immutable
class IqamaSyncResult {
  const IqamaSyncResult({required this.plan, required this.report, required this.at});

  final List<IqamaAlarm> plan;
  final NotificationSyncReport report;
  final DateTime at;

  /// Exact alarms were refused, so some iqamas may come minutes late.
  bool get degraded => report.inexactFallback > 0;

  IqamaAlarm? next(DateTime now) => IqamaPlanner.next(plan, now);
}

/// Building the iqama's notifications – pure, so the background isolate
/// builds the snooze and the notices exactly as the app builds the iqama
/// itself.
abstract final class IqamaNotifications {
  static const channelPrefix = 'madar.iqama.';

  /// The adhan's group: «الصلاة والأذان» holds the adhan and the iqama.
  static const groupId = 'madar.adhan';

  /// After a reboot, an iqama later than this is not restored (the prayer
  /// has long since been prayed – or missed).
  static const dropIfLateBy = Duration(minutes: 10);

  /// The notification leaves the shade (its sound with it) after this long.
  static const timeout = Duration(minutes: 30);

  static const vibration = [0, 400, 250, 400];

  static String channelId(AdhanSoundRef sound, {required bool vibrate}) =>
      '${channelPrefix}call.${sound.key.replaceAll(':', '-')}.${vibrate ? 'v' : 'q'}.1';

  /// The iqama of [alarm]: «قامت الصلاة» with «صلّيت» and «بعد شوي».
  ///
  /// Its delivery is the adhan's, never weaker: `setAlarmClock` timing (the
  /// exact minute, out of Doze, untouched by battery saver and app
  /// standby), the alarm category and audio usage, readable on the lock
  /// screen, and restored after a reboot while it is still due.
  static NotificationRequest request(
    IqamaAlarm alarm, {
    required IqamaSettings settings,
    required IqamaTexts texts,
    required String channelId,
    bool snooze = false,
    DateTime? at,
  }) => NotificationRequest(
    namespace: IqamaIds.namespace,
    id: snooze ? IqamaIds.snooze : alarm.id,
    channelId: channelId,
    title: snooze ? texts.snoozeTitle : texts.title,
    body: texts.body(alarm.slot, alarm.prayerAt),
    at: at ?? alarm.at,
    data: IqamaNotificationTaps.dataOf(
      alarm,
      snoozeMinutes: settings.snoozeMinutes,
      language: texts.fmt.languageCode,
      digits: texts.fmt.digits,
      snooze: snooze,
    ),
    category: NotificationCategory.alarm,
    timing: NotificationTiming.alarmClock,
    publicOnLockScreen: true,
    timeout: timeout,
    dropIfLateBy: dropIfLateBy,
    actions: [
      NotificationActionSpec(id: IqamaActions.prayed, title: texts.prayedAction),
      // One snooze: the snoozed notification does not offer another.
      if (!snooze) NotificationActionSpec(id: IqamaActions.later, title: texts.laterAction),
    ],
    autoCancel: true,
  );

  /// "You already logged it by hand" – shown instead of a second row.
  static NotificationRequest alreadyLogged({
    required AdhanSlot slot,
    required DateTime day,
    required IqamaTexts texts,
    required DateTime now,
    String? channelId,
  }) => _notice(
    id: IqamaIds.already(slot),
    slot: slot,
    day: day,
    title: texts.alreadyTitle(slot),
    body: texts.alreadyBody,
    texts: texts,
    now: now,
    channelId: channelId,
  );

  /// "It was not recorded – open Madar": an answer is never lost silently.
  static NotificationRequest failedNotice({
    required AdhanSlot slot,
    required DateTime day,
    required IqamaTexts texts,
    required DateTime now,
    String? channelId,
  }) => _notice(
    id: IqamaIds.failed(slot),
    slot: slot,
    day: day,
    title: texts.failedTitle,
    body: texts.failedBody,
    texts: texts,
    now: now,
    channelId: channelId,
  );

  static NotificationRequest _notice({
    required int id,
    required AdhanSlot slot,
    required DateTime day,
    required String title,
    required String body,
    required IqamaTexts texts,
    required DateTime now,
    String? channelId,
  }) => NotificationRequest(
    namespace: IqamaIds.namespace,
    id: id,
    channelId: channelId ?? IqamaNotifications.channelId(const AdhanSoundRef.silent(), vibrate: false),
    title: title,
    body: body,
    at: now,
    data: {
      IqamaNotificationTaps.kKind: IqamaNotificationTaps.kindNotice,
      IqamaNotificationTaps.kSlot: slot.name,
      IqamaNotificationTaps.kDay: IqamaNotificationTaps.dayKey(day),
      IqamaNotificationTaps.kLanguage: texts.fmt.languageCode == 'en' ? 'en' : 'ar',
      IqamaNotificationTaps.kDigits: texts.fmt.digits.name,
    },
    category: NotificationCategory.reminder,
  );
}

/// Turns the iqama settings and the prayer times into pending exact alarms
/// and the channel they call on.
///
/// Channel (Android freezes a channel's sound, vibration and audio usage at
/// creation, so each combination is its own channel and the old ones are
/// deleted): `madar.iqama.call.<sound>.<v|q>.1` – urgent, on the alarm
/// stream like the adhan's, the chosen tone or recording as its sound, in
/// the adhan's channel group.
class IqamaScheduler {
  IqamaScheduler({required this.notifications, required this.system, this.planner = const IqamaPlanner(), DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final NotificationService notifications;
  final AdhanSystem system;
  final IqamaPlanner planner;
  final DateTime Function() _clock;

  /// Re-plans everything: the channel, then the pending iqamas of the next
  /// days. Idempotent – unchanged ones are left alone, and the one-off
  /// snooze and the notices are never swept.
  Future<IqamaSyncResult> sync({
    required IqamaSettings settings,
    required AdhanSettings adhan,
    required AdhanTimesFor timesFor,
    required LocalDayOf localDayOf,
    required IqamaTexts texts,
  }) async {
    final now = _clock();
    final plan = planner.plan(settings: settings, adhan: adhan, now: now, timesFor: timesFor, localDayOf: localDayOf);
    final channel = await ensureChannel(settings, adhan, texts);
    final requests = [
      for (final a in plan) IqamaNotifications.request(a, settings: settings, texts: texts, channelId: channel),
    ];
    final report = await notifications.sync(IqamaIds.namespace, requests, keep: IqamaIds.isOneOff);
    return IqamaSyncResult(plan: plan, report: report, at: now);
  }

  /// Creates the iqama's channel and returns its id. A recording whose file
  /// has vanished falls back to the built-in chime.
  Future<String> ensureChannel(IqamaSettings settings, AdhanSettings adhan, IqamaTexts texts) async {
    await notifications.ensureChannelGroup(IqamaNotifications.groupId, texts.channelGroup);
    final v = settings.vibrate;
    var ref = settings.resolve(adhan.muezzins);
    NotificationSoundSpec? spec = switch (ref.kind) {
      AdhanSoundKind.tone => NotificationSoundSpec.raw(ref.tone!.rawName),
      AdhanSoundKind.silent => const NotificationSoundSpec.silent(),
      AdhanSoundKind.file => null,
    };
    CustomMuezzin? muezzin;
    if (ref.kind == AdhanSoundKind.file) {
      muezzin = adhan.muezzinById(ref.fileId);
      final uri = muezzin == null ? null : await system.soundUri(muezzin.fileName);
      if (uri != null) {
        spec = NotificationSoundSpec.uri(uri);
      } else {
        ref = const AdhanSoundRef.tone(TanbihTone.chime);
        muezzin = null;
        spec = NotificationSoundSpec.raw(TanbihTone.chime.rawName);
      }
    }
    final id = IqamaNotifications.channelId(ref, vibrate: v);
    await notifications.ensureChannels([
      NotificationChannelSpec(
        id: id,
        name: texts.channel(texts.soundName(ref, muezzin: muezzin)),
        description: texts.channelDescription,
        importance: NotificationImportance.urgent,
        sound: spec!,
        vibrate: v,
        vibrationPattern: v ? IqamaNotifications.vibration : null,
        usage: NotificationAudioUsage.alarm,
        groupId: IqamaNotifications.groupId,
      ),
    ], prunePrefix: IqamaNotifications.channelPrefix);
    return id;
  }

  Future<void> cancelAll() => notifications.cancelNamespace(IqamaIds.namespace);
}
