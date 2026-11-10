import 'package:flutter/foundation.dart';

import '../../../core/notifications/notification_models.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/settings/app_settings.dart' show DigitStyle;
import '../../wird/domain/calendar_days.dart';
import '../domain/fasting_log.dart';
import '../domain/fasting_models.dart';
import '../domain/fasting_planner.dart';
import 'fasting_texts.dart';

/// The two buttons of the evening reminder. Both run **in the background**
/// (`opensApp: false`): answering from the shade never opens Madar and never
/// has to pass the app lock.
abstract final class FastingActions {
  /// «ناوي» - writes the intention, so the morning has it.
  static const yes = 'fasting.yes';

  /// «لأ» - silences that day only.
  static const no = 'fasting.no';
}

/// An answer given on a reminder, as the background isolate and the running
/// app both see it.
@immutable
class FastingAnswer {
  const FastingAnswer({required this.day, required this.choice, this.language = 'ar', this.digits = DigitStyle.auto});

  /// The fasting day (local midnight).
  final DateTime day;
  final FastIntentionChoice choice;
  final String language;
  final DigitStyle digits;

  FastIntention get intention => FastIntention(day: day, choice: choice);

  @override
  String toString() => 'FastingAnswer(${choice.name} ${CalendarDays.key(day)})';
}

/// Reading a fasting notification's payload - the one place that knows its
/// shape, shared by the planner, the app's tap routing and the background
/// isolate.
abstract final class FastingNotificationTaps {
  static const namespace = NotificationNamespaces.fasting;

  /// Payload fields: the fasting day, its kind, the language / digit style
  /// it was written in, and what sort of notification it is.
  static const kDay = 'day', kKind = 'kind', kLanguage = 'l', kDigits = 'g', kType = 't';

  /// The "open Madar to renew the reminders" notice.
  static const typeRunway = 'runway';

  /// A "not saved" notice.
  static const typeNotice = 'notice';

  static bool isFasting(NotificationTap tap) => tap.namespace == namespace.name;

  /// A tap on the body (the two buttons are answered in the background).
  static bool opensFasting(NotificationTap tap) => isFasting(tap) && tap.actionId == null;

  static String languageOf(NotificationTap tap) => tap.data[kLanguage] == 'en' ? 'en' : 'ar';

  static DigitStyle digitsOf(NotificationTap tap) =>
      DigitStyle.values.where((d) => d.name == tap.data[kDigits]).firstOrNull ?? DigitStyle.auto;

  /// The answer a button gives - null for a tap on the body, a notice, a
  /// malformed payload or a foreign notification.
  static FastingAnswer? answerOf(NotificationTap tap) {
    if (!isFasting(tap) || tap.data[kType] != null) return null;
    final choice = switch (tap.actionId) {
      FastingActions.yes => FastIntentionChoice.yes,
      FastingActions.no => FastIntentionChoice.no,
      _ => null,
    };
    final day = CalendarDays.parse(tap.data[kDay]);
    if (choice == null || day == null) return null;
    return FastingAnswer(day: day, choice: choice, language: languageOf(tap), digits: digitsOf(tap));
  }
}

/// Building the reminder's notification - pure, so the background isolate
/// builds its notices exactly as the app builds the reminders.
abstract final class FastingNotifications {
  static const channelPrefix = 'madar.fasting.';
  static const channelId = 'madar.fasting.reminder.1';
  static const groupId = 'madar.fasting';

  /// After a reboot a reminder later than this is not restored (it is
  /// pointless at midday for last night).
  static const dropIfLateBy = Duration(hours: 3);

  /// A shown reminder removes itself by morning.
  static const timeout = Duration(hours: 9);

  /// When no reminder is planned for this many days ahead, one notice asks
  /// him to open Madar (which re-plans). Opening the app any time pushes it
  /// forward again, so it only ever fires after a long absence.
  static const runwayAfterDays = 18;

  /// The id of that notice: the last of the block, clear of every reminder.
  static int get runwayId => FastingNotificationIds.namespace.last;

  /// The id of a "not saved" notice.
  static int get failedId => FastingNotificationIds.namespace.last - 1;

  static NotificationChannelSpec channel(FastingTexts t) => NotificationChannelSpec(
    id: channelId,
    name: t.channelName,
    description: t.channelDescription,
    importance: NotificationImportance.high,
    groupId: groupId,
  );

  /// The evening reminder of [p] with its two buttons.
  static NotificationRequest request(PlannedFastReminder p, FastingTexts t) => NotificationRequest(
    namespace: FastingNotificationIds.namespace,
    id: p.notificationId,
    channelId: channelId,
    title: t.title(p.reminder.kind),
    body: t.body(p),
    at: p.at,
    data: {...p.data, FastingNotificationTaps.kLanguage: t.fmt.languageCode == 'en' ? 'en' : 'ar', FastingNotificationTaps.kDigits: t.fmt.digits.name},
    category: NotificationCategory.reminder,
    timing: NotificationTiming.exactWhileIdle,
    timeout: timeout,
    dropIfLateBy: dropIfLateBy,
    actions: [
      NotificationActionSpec(id: FastingActions.yes, title: t.actionYes),
      NotificationActionSpec(id: FastingActions.no, title: t.actionNo),
    ],
  );

  /// "Open Madar so the reminders keep coming".
  static NotificationRequest runway(DateTime at, FastingTexts t) => NotificationRequest(
    namespace: FastingNotificationIds.namespace,
    id: runwayId,
    channelId: channelId,
    title: t.runwayTitle,
    body: t.runwayBody,
    at: at,
    data: {FastingNotificationTaps.kType: FastingNotificationTaps.typeRunway},
    timing: NotificationTiming.inexactWhileIdle,
    timeout: const Duration(hours: 12),
  );

  /// "Your answer was not saved - open Madar".
  static NotificationRequest failedNotice({required FastingAnswer answer, required FastingTexts t, required DateTime now}) =>
      NotificationRequest(
        namespace: FastingNotificationIds.namespace,
        id: failedId,
        channelId: channelId,
        title: t.failedTitle,
        body: t.failedBody,
        at: now,
        data: {
          FastingNotificationTaps.kType: FastingNotificationTaps.typeNotice,
          FastingNotificationTaps.kDay: CalendarDays.key(answer.day),
        },
      );
}

/// What one [FastingScheduler.sync] did.
@immutable
class FastingSyncResult {
  const FastingSyncResult({required this.plan, required this.report, required this.at});

  final List<PlannedFastReminder> plan;
  final NotificationSyncReport report;
  final DateTime at;

  /// The ids that were wanted pending after this sync.
  Set<int> get ids => {for (final p in plan) p.notificationId};
}

/// Turns the plan into pending alarms and the channel they ring on.
class FastingScheduler {
  FastingScheduler({required this.notifications, DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  /// How far ahead reminders are planned.
  static const int daysAhead = 21;

  final NotificationService notifications;
  final DateTime Function() _clock;

  /// Re-plans everything for the fasting days of the next [daysAhead] days.
  /// Idempotent: an unchanged reminder keeps its id and its alarm.
  ///
  /// [config] is the *effective* one (the prayer settings' Hijri shift
  /// already in it). A day that already holds an answer or a log entry gets
  /// no reminder.
  Future<FastingSyncResult> sync({
    required FastingConfig config,
    required Iterable<FastIntention> intentions,
    required Iterable<FastLogEntry> log,
    required DateTime? Function(DateTime day) ishaOf,
    required FastingTexts texts,
  }) async {
    final now = _clock();
    final answered = [
      ...intentions,
      for (final e in log) FastIntention(day: e.day, choice: e.fasted ? FastIntentionChoice.yes : FastIntentionChoice.no),
    ];
    final plan = FastingPlanner.plan(config: config, now: now, ishaOf: ishaOf, intentions: answered, daysAhead: daysAhead);
    await notifications.ensureChannelGroup(FastingNotifications.groupId, texts.channelGroup);
    await notifications.ensureChannels([FastingNotifications.channel(texts)], prunePrefix: FastingNotifications.channelPrefix);
    final requests = [
      for (final p in plan) FastingNotifications.request(p, texts),
      if (plan.isNotEmpty)
        FastingNotifications.runway(
          DateTime(now.year, now.month, now.day + FastingNotifications.runwayAfterDays, 10),
          texts,
        ),
    ];
    final report = await notifications.sync(FastingNotificationIds.namespace, requests);
    return FastingSyncResult(plan: plan, report: report, at: now);
  }

  Future<void> cancelAll() => notifications.cancelNamespace(FastingNotificationIds.namespace);
}
