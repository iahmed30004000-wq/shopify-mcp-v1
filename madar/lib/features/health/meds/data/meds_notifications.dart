import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../../core/notifications/notification_models.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../../../core/settings/app_settings.dart' show DigitStyle;
import '../domain/dose_scheduler.dart';
import '../domain/dose_tracker.dart';
import '../domain/meds_planner.dart';
import '../domain/meds_settings.dart';
import '../meds_texts.dart';
import 'meds_service.dart';

/// The medication tracker's slice of the `meds` notification namespace
/// (120000–129999):
///
/// * 120000–128999 – dose reminders (the rolling 48-hour plan);
/// * 129000–129499 – refill alerts (one per medication);
/// * 129500–129999 – notices (a notification action that could not be
///   recorded).
abstract final class MedsNotificationIds {
  static const NotificationNamespace namespace = NotificationNamespaces.meds;
  static const doseFirst = 120000, doseLast = 128999;
  static const refillFirst = 129000, refillLast = 129499;
  static const noticeFirst = 129500, noticeLast = 129999;

  static bool isDose(int id) => id >= doseFirst && id <= doseLast;

  static int _hash(String s) {
    var h = 0x811c9dc5;
    for (final unit in utf8.encode(s)) {
      h ^= unit;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h;
  }

  /// The id a dose's reminder prefers (a stable hash of its key).
  static int preferred(String doseKey) => doseFirst + _hash(doseKey) % (doseLast - doseFirst + 1);

  /// Ids for [keys]: each its preferred id, the next free one on a
  /// collision (in key order, so the assignment is deterministic).
  static Map<String, int> assign(Iterable<String> keys) {
    final sorted = keys.toSet().toList()..sort();
    final used = <int>{};
    final out = <String, int>{};
    const size = doseLast - doseFirst + 1;
    for (final k in sorted) {
      var id = preferred(k);
      for (var i = 0; used.contains(id) && i < size; i++) {
        id = id == doseLast ? doseFirst : id + 1;
      }
      used.add(id);
      out[k] = id;
    }
    return out;
  }

  static int refill(String medId) => refillFirst + _hash(medId) % (refillLast - refillFirst + 1);

  static int notice(String key) => noticeFirst + _hash(key) % (noticeLast - noticeFirst + 1);
}

/// Payload keys and action ids of Madar's dose notifications.
abstract final class MedsNotificationTaps {
  static const actionTaken = 'meds.taken';
  static const actionSnooze = 'meds.snooze';
  static const actionSkip = 'meds.skip';

  /// `d` payload fields: kind (`dose` / `refill` / `notice`), medication,
  /// slot (ms since epoch), snooze minutes, language, digit style.
  static const kDose = 'dose', kRefill = 'refill', kNotice = 'notice';

  static bool isMeds(NotificationTap tap) => tap.namespace == MedsNotificationIds.namespace.name;

  /// The medication and slot a dose notification is about.
  static ({String medId, DateTime slot})? doseOf(NotificationTap tap) {
    if (!isMeds(tap)) return null;
    final m = tap.data['m'], s = tap.data['s'];
    if (m is! String || s is! int) return null;
    return (medId: m, slot: DateTime.fromMillisecondsSinceEpoch(s));
  }

  /// A tap on the body of one of these notifications (open the medications
  /// screen; the buttons are recorded in the background).
  static bool opensMeds(NotificationTap tap) => isMeds(tap) && tap.actionId == null;

  /// The medication a meds notification (dose or refill) is about.
  static String? medOf(NotificationTap tap) {
    if (!isMeds(tap)) return null;
    final m = tap.data['m'];
    return m is String ? m : null;
  }

  /// The answer an action button gives (null for a tap on the body or a
  /// foreign notification).
  static MedDoseAction? actionOf(NotificationTap tap, {required DateTime now}) {
    final dose = doseOf(tap);
    if (dose == null) return null;
    final kind = switch (tap.actionId) {
      actionTaken => MedDoseActionKind.taken,
      actionSnooze => MedDoseActionKind.snoozed,
      actionSkip => MedDoseActionKind.skipped,
      _ => null,
    };
    if (kind == null) return null;
    final z = tap.data['z'];
    return MedDoseAction(
      medId: dose.medId,
      slot: dose.slot,
      kind: kind,
      at: now,
      snooze: kind == MedDoseActionKind.snoozed ? Duration(minutes: z is int && z > 0 ? z : 10) : null,
    );
  }

  /// The UI language / digit style the notification was written in (the
  /// background handler writes follow-ups the same way).
  static String languageOf(NotificationTap tap) => tap.data['l'] == 'en' ? 'en' : 'ar';

  static DigitStyle digitsOf(NotificationTap tap) =>
      DigitStyle.values.where((d) => d.name == tap.data['g']).firstOrNull ?? DigitStyle.auto;
}

/// Builds the dose reminders (pure).
abstract final class MedsReminderPlanner {
  static const String channelPrefix = 'madar.meds.';
  static const String channelId = 'madar.meds.dose.1';
  static const String groupId = 'madar.meds';

  /// After a reboot, a reminder more than this late is not restored.
  static const Duration dropIfLateBy = Duration(hours: 2);

  static const Duration horizon = Duration(hours: 48);

  static NotificationChannelSpec channel(MedsTexts t) => NotificationChannelSpec(
    id: channelId,
    name: t.l.medsNotifyChannel,
    description: t.l.medsNotifyChannelDescription,
    importance: NotificationImportance.high,
    groupId: groupId,
  );

  /// One reminder per open dose in [upcoming] (see [MedsPlanner.upcoming]),
  /// with Taken / Snooze / Skip buttons that run in the background.
  static List<NotificationRequest> requests(
    List<TrackedDose> upcoming, {
    required MedsTexts texts,
    required MedsSettings settings,
  }) {
    final ids = MedsNotificationIds.assign(upcoming.map((t) => t.key));
    final l = texts.l;
    final snooze = settings.snoozeMinutes;
    final actions = [
      NotificationActionSpec(id: MedsNotificationTaps.actionTaken, title: l.medsTake),
      NotificationActionSpec(id: MedsNotificationTaps.actionSnooze, title: l.medsSnoozeFor(texts.duration(snooze))),
      NotificationActionSpec(id: MedsNotificationTaps.actionSkip, title: l.medsSkip),
    ];
    return [
      for (final t in upcoming)
        NotificationRequest(
          namespace: MedsNotificationIds.namespace,
          id: ids[t.key]!,
          channelId: channelId,
          title: t.state == DoseState.snoozed
              ? l.medsNotifyAgainTitle(texts.name(t.dose.med.name))
              : l.medsNotifyTitle(texts.name(t.dose.med.name)),
          body: bodyOf(t.dose, texts),
          at: t.dueAt,
          data: {
            'k': MedsNotificationTaps.kDose,
            'm': t.dose.medId,
            's': t.dose.slot.millisecondsSinceEpoch,
            'z': snooze,
            'l': texts.fmt.languageCode == 'en' ? 'en' : 'ar',
            'g': texts.fmt.digits.name,
          },
          category: NotificationCategory.reminder,
          timing: NotificationTiming.exactWhileIdle,
          dropIfLateBy: dropIfLateBy,
          actions: actions,
          colorArgb: t.dose.med.color,
          subText: l.medsNotifyGroup,
        ),
    ];
  }

  /// "5 mg · With breakfast · 8:00 AM".
  static String bodyOf(PlannedDose d, MedsTexts texts) {
    final line = texts.doseLine(d);
    final time = texts.time(d.at);
    return line.isEmpty ? time : '$line · $time';
  }

  static NotificationRequest refill({
    required String medId,
    required String medName,
    required int stock,
    required MedsTexts texts,
    required DateTime now,
    int? colorArgb,
  }) => NotificationRequest(
    namespace: MedsNotificationIds.namespace,
    id: MedsNotificationIds.refill(medId),
    channelId: channelId,
    title: texts.l.medsNotifyRefillTitle(texts.name(medName)),
    body: texts.l.medsNotifyRefillBody(texts.count(stock)),
    at: now,
    data: {'k': MedsNotificationTaps.kRefill, 'm': medId},
    category: NotificationCategory.reminder,
    colorArgb: colorArgb,
    subText: texts.l.medsNotifyGroup,
  );

  static NotificationRequest failedNotice({required MedDoseAction action, required MedsTexts texts}) =>
      NotificationRequest(
        namespace: MedsNotificationIds.namespace,
        id: MedsNotificationIds.notice(PlannedDose.doseKey(action.medId, action.slot)),
        channelId: channelId,
        title: texts.l.medsNotifyFailedTitle,
        body: texts.l.medsNotifyFailedBody,
        at: action.at,
        data: {'k': MedsNotificationTaps.kNotice, 'm': action.medId, 's': action.slot.millisecondsSinceEpoch},
        category: NotificationCategory.reminder,
        subText: texts.l.medsNotifyGroup,
      );
}

/// Re-plans the dose reminders of the next [MedsReminderPlanner.horizon]
/// from the database – shared by the app (on every change, at start and
/// daily) and the background action handler (after an answer).
class MedsReminderEngine {
  MedsReminderEngine({
    required this.service,
    required this.notifications,
    required this.texts,
    this.prayerTime,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final MedsService service;
  final NotificationService notifications;
  final MedsTexts texts;
  final PrayerTimeOf? prayerTime;
  final DateTime Function() _clock;

  /// The ids given to each dose key by the last [resync] (so an answer given
  /// in the app can remove the matching shown notification).
  Map<String, int> lastIds = const {};

  Future<NotificationSyncReport> resync() async {
    final now = _clock();
    final settings = await service.settings();
    final meds = await service.meds();
    final hasPlan = settings.notify && meds.any((m) => m.active);
    await notifications.ensureChannelGroup(MedsReminderPlanner.groupId, texts.l.medsNotifyGroup);
    await notifications.ensureChannels([
      MedsReminderPlanner.channel(texts),
    ], prunePrefix: MedsReminderPlanner.channelPrefix);
    if (!hasPlan) {
      lastIds = const {};
      return notifications.sync(MedsNotificationIds.namespace, const [], keep: (id) => !MedsNotificationIds.isDose(id));
    }
    final scheduler = DoseScheduler(
      meds: meds,
      courses: await service.courses(),
      rules: await service.rules(),
      settings: settings,
      prayerTime: prayerTime,
    );
    final today = DateTime(now.year, now.month, now.day);
    final logs = await service.logs(today.subtract(const Duration(days: 2)));
    final period = MedsPlanner.period(scheduler, from: today, count: 3, logs: logs, now: now);
    final upcoming = MedsPlanner.upcoming(period, horizon: MedsReminderPlanner.horizon);
    final requests = MedsReminderPlanner.requests(upcoming, texts: texts, settings: settings);
    lastIds = {for (var i = 0; i < upcoming.length; i++) upcoming[i].key: requests[i].id};
    return notifications.sync(MedsNotificationIds.namespace, requests, keep: (id) => !MedsNotificationIds.isDose(id));
  }

  /// Removes a shown (or pending) reminder of [doseKey] – after an answer in
  /// the app.
  Future<void> dismiss(String doseKey) async {
    final id = lastIds[doseKey] ?? MedsNotificationIds.preferred(doseKey);
    await notifications.cancel(id);
  }

  /// Shows the refill alert when an answer brought the stock down to the
  /// threshold.
  Future<void> refillIfNeeded(String medId, DoseActionResult result) async {
    if (!result.refillCrossed || result.stockAfter == null) return;
    final med = await service.med(medId);
    if (med == null) return;
    await notifications.show(
      MedsReminderPlanner.refill(
        medId: medId,
        medName: med.name,
        stock: result.stockAfter!,
        texts: texts,
        now: _clock(),
        colorArgb: med.color,
      ),
    );
  }

  @visibleForTesting
  DateTime get now => _clock();
}
