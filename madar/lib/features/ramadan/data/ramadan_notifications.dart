import 'package:flutter/foundation.dart';

import '../../../core/notifications/notification_models.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/settings/app_settings.dart' show DigitStyle;
import '../domain/prayer_times_of.dart';
import '../domain/ramadan_calendar.dart';
import '../domain/ramadan_config.dart';
import '../domain/ramadan_notification_ids.dart';
import '../domain/ramadan_planner.dart';
import 'ramadan_texts.dart';

/// The one button of the Taraweeh reminder. It runs **in the background**
/// (`opensApp: false`): answering from the shade never opens Madar and never
/// has to pass the app lock.
abstract final class RamadanActions {
  /// «صلّيت» - writes the night into the Taraweeh log.
  static const prayed = 'ramadan.prayed';
}

/// A Taraweeh night marked from the notification.
@immutable
class RamadanPrayedAnswer {
  const RamadanPrayedAnswer({
    required this.hijriYear,
    required this.night,
    this.language = 'ar',
    this.digits = DigitStyle.auto,
  });

  final int hijriYear;
  final int night;
  final String language;
  final DigitStyle digits;

  @override
  String toString() => 'RamadanPrayedAnswer($hijriYear night $night)';
}

/// Reading a Ramadan notification's payload - the one place that knows its
/// shape, shared by the planner, the app's tap routing and the background
/// isolate.
abstract final class RamadanNotificationTaps {
  static const namespace = NotificationNamespaces.ramadan;

  /// Payload fields: what sort of notification it is, the day or night number,
  /// the Hijri year, and the language / digit style it was written in.
  static const kType = 't', kNumber = 'n', kYear = 'y', kLanguage = 'l', kDigits = 'g';

  static const typeSuhoor = 'suhoor';
  static const typeIftar = 'iftar';
  static const typeTaraweeh = 'taraweeh';
  static const typeLastTen = 'lastTen';

  /// The "open Madar to set up the reminders" notice.
  static const typeRunway = 'runway';

  /// A "not saved" notice.
  static const typeNotice = 'notice';

  static String typeOf(RamadanReminderKind kind) => switch (kind) {
    RamadanReminderKind.suhoor => typeSuhoor,
    RamadanReminderKind.iftar => typeIftar,
    RamadanReminderKind.taraweeh => typeTaraweeh,
    RamadanReminderKind.lastTenNight => typeLastTen,
    RamadanReminderKind.khatmah => 'khatmah',
  };

  static bool isRamadan(NotificationTap tap) => tap.namespace == namespace.name;

  /// A tap on the body (the button is answered in the background).
  static bool opensRamadan(NotificationTap tap) => isRamadan(tap) && tap.actionId == null;

  static String languageOf(NotificationTap tap) => tap.data[kLanguage] == 'en' ? 'en' : 'ar';

  static DigitStyle digitsOf(NotificationTap tap) =>
      DigitStyle.values.where((d) => d.name == tap.data[kDigits]).firstOrNull ?? DigitStyle.auto;

  static int? _int(Object? v) => v is int ? v : (v is num ? v.toInt() : int.tryParse('$v'));

  /// The night «صلّيت» marks - null for a tap on the body, a notice, a
  /// malformed payload or a foreign notification.
  static RamadanPrayedAnswer? prayedOf(NotificationTap tap) {
    if (!isRamadan(tap) || tap.actionId != RamadanActions.prayed || tap.data[kType] != typeTaraweeh) return null;
    final year = _int(tap.data[kYear]), night = _int(tap.data[kNumber]);
    if (year == null || year < 1 || night == null || night < 1 || night > 30) return null;
    return RamadanPrayedAnswer(hijriYear: year, night: night, language: languageOf(tap), digits: digitsOf(tap));
  }
}

/// Building Ramadan's notifications - pure, so the background isolate builds
/// its notices exactly as the app builds the reminders.
abstract final class RamadanNotifications {
  static const channelPrefix = 'madar.ramadan.';
  static const channelId = 'madar.ramadan.reminder.1';
  static const groupId = 'madar.ramadan';

  /// After a reboot a reminder later than this is not restored.
  static const dropIfLateBy = Duration(hours: 2);

  /// A shown reminder removes itself after this.
  static const timeout = Duration(hours: 4);

  /// The id of the "open Madar" notice: the last of the block, clear of every reminder.
  static int get runwayId => RamadanNotificationIds.last;

  /// The id of a "not saved" notice.
  static int get failedId => RamadanNotificationIds.last - 1;

  static NotificationChannelSpec channel(RamadanTexts t) => NotificationChannelSpec(
    id: channelId,
    name: t.channelName,
    description: t.channelDescription,
    importance: NotificationImportance.high,
    groupId: groupId,
  );

  /// The reminder of [p]; [eventClock] is the moment it is about on the
  /// place's wall clock (what the text names).
  static NotificationRequest request(PlannedRamadanReminder p, RamadanTexts t, {required DateTime eventClock}) =>
      NotificationRequest(
        namespace: RamadanNotificationTaps.namespace,
        id: p.notificationId,
        channelId: channelId,
        title: t.title(p),
        body: t.body(p, eventClock),
        at: p.at,
        data: {
          RamadanNotificationTaps.kType: RamadanNotificationTaps.typeOf(p.kind),
          RamadanNotificationTaps.kNumber: p.number,
          RamadanNotificationTaps.kYear: p.hijriYear,
          RamadanNotificationTaps.kLanguage: t.fmt.languageCode == 'en' ? 'en' : 'ar',
          RamadanNotificationTaps.kDigits: t.fmt.digits.name,
        },
        category: NotificationCategory.reminder,
        timing: NotificationTiming.exactWhileIdle,
        timeout: timeout,
        dropIfLateBy: dropIfLateBy,
        actions: p.kind == RamadanReminderKind.taraweeh
            ? [NotificationActionSpec(id: RamadanActions.prayed, title: t.actionPrayed)]
            : const [],
      );

  /// "Open Madar so the reminders are set".
  static NotificationRequest runway(DateTime at, RamadanTexts t) => NotificationRequest(
    namespace: RamadanNotificationTaps.namespace,
    id: runwayId,
    channelId: channelId,
    title: t.runwayTitle,
    body: t.runwayBody,
    at: at,
    data: {RamadanNotificationTaps.kType: RamadanNotificationTaps.typeRunway},
    timing: NotificationTiming.inexactWhileIdle,
    timeout: const Duration(hours: 12),
  );

  /// "Your night was not saved - open Madar".
  static NotificationRequest failedNotice({required RamadanPrayedAnswer answer, required RamadanTexts t, required DateTime now}) =>
      NotificationRequest(
        namespace: RamadanNotificationTaps.namespace,
        id: failedId,
        channelId: channelId,
        title: t.failedTitle,
        body: t.failedBody,
        at: now,
        data: {
          RamadanNotificationTaps.kType: RamadanNotificationTaps.typeNotice,
          RamadanNotificationTaps.kNumber: answer.night,
          RamadanNotificationTaps.kYear: answer.hijriYear,
        },
      );
}

/// What one [RamadanScheduler.sync] did.
@immutable
class RamadanSyncResult {
  const RamadanSyncResult({required this.plan, required this.report, required this.at});

  final RamadanPlan plan;
  final NotificationSyncReport report;
  final DateTime at;

  /// The ids that were wanted pending after this sync (the notice included).
  Set<int> get ids => {...plan.ids, if (plan.runwayAt != null) RamadanNotifications.runwayId};
}

/// Turns the plan into pending alarms and the channel they ring on.
class RamadanScheduler {
  RamadanScheduler({required this.notifications, DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final NotificationService notifications;
  final DateTime Function() _clock;

  /// Re-plans everything for the days of the current (or next) Ramadan.
  /// Idempotent: an unchanged reminder keeps its id and its alarm; one that
  /// is no longer wanted (a switch turned off, the Eid passed, the Hijri
  /// shift moved) is cancelled.
  ///
  /// [calendar] already carries the prayer settings' Hijri shift. [wallClock]
  /// turns an instant into the place's clock for the texts (identity by
  /// default).
  Future<RamadanSyncResult> sync({
    required RamadanConfig config,
    required RamadanCalendar calendar,
    required PrayerTimesOf timesOf,
    required RamadanTexts texts,
    DateTime Function(DateTime instant)? wallClock,
  }) async {
    final now = _clock();
    final clockOf = wallClock ?? (instant) => instant;
    final plan = RamadanPlanner.plan(config: config, calendar: calendar, now: now, timesOf: timesOf);
    await notifications.ensureChannelGroup(RamadanNotifications.groupId, texts.channelGroup);
    await notifications.ensureChannels([RamadanNotifications.channel(texts)], prunePrefix: RamadanNotifications.channelPrefix);
    final requests = [
      for (final p in plan.reminders) RamadanNotifications.request(p, texts, eventClock: clockOf(p.eventAt)),
      if (plan.runwayAt != null) RamadanNotifications.runway(plan.runwayAt!, texts),
    ];
    final report = await notifications.sync(RamadanNotificationTaps.namespace, requests);
    return RamadanSyncResult(plan: plan, report: report, at: now);
  }

  Future<void> cancelAll() => notifications.cancelNamespace(RamadanNotificationTaps.namespace);
}
