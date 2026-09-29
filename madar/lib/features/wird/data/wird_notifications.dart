import '../../../core/notifications/notification_models.dart';
import '../../../core/notifications/notification_service.dart';
import '../domain/wird_reminders.dart';

/// The channel texts (system settings › notifications), in the UI language.
typedef WirdChannelTexts = ({String group, String name, String description});

/// [WirdReminderScheduler] over Madar's [NotificationService]: the reminders
/// are the complete, declarative plan of the [WirdReminderIds.namespace] id
/// block, so re-planning leaves unchanged reminders alone and cancels the
/// ones no longer wanted.
///
/// One channel, `madar.wird.reminder.1` (high importance, the system
/// sound – a gentle nudge, never an alarm). Exact-while-idle, falling back to
/// inexact without the exact-alarm permission (fine for "after Asr"). After
/// a reboot a reminder more than [dropIfLateBy] late is not restored; a shown
/// one removes itself after [timeout].
class NotificationWirdReminderScheduler implements WirdReminderScheduler {
  NotificationWirdReminderScheduler({required this.notifications, required this.texts});

  final NotificationService notifications;

  /// Resolved on every sync, so a language switch renames the channel.
  final WirdChannelTexts Function() texts;

  static const NotificationNamespace namespace = WirdReminderIds.namespace;
  static const String channelPrefix = 'madar.wird.';
  static const String channelId = 'madar.wird.reminder.1';
  static const String groupId = 'madar.wird';
  static const Duration dropIfLateBy = Duration(hours: 2);
  static const Duration timeout = Duration(hours: 4);

  Future<void> _ensureChannel() async {
    final t = texts();
    await notifications.ensureChannelGroup(groupId, t.group);
    await notifications.ensureChannels([
      NotificationChannelSpec(
        id: channelId,
        name: t.name,
        description: t.description,
        importance: NotificationImportance.high,
        groupId: groupId,
      ),
    ], prunePrefix: channelPrefix);
  }

  static NotificationRequest requestFor(WirdReminderNotice notice) => NotificationRequest(
    namespace: namespace,
    id: notice.id,
    channelId: channelId,
    title: notice.title,
    body: notice.body,
    at: notice.at,
    data: notice.data,
    category: NotificationCategory.reminder,
    timing: NotificationTiming.exactWhileIdle,
    timeout: timeout,
    dropIfLateBy: dropIfLateBy,
  );

  @override
  Future<void> replaceAll(List<WirdReminderNotice> notices) async {
    await _ensureChannel();
    await notifications.sync(namespace, [for (final n in notices) requestFor(n)]);
  }

  @override
  Future<void> cancelAll() => notifications.cancelNamespace(namespace);

  @override
  Future<bool> ensurePermission() async {
    if (await notifications.notificationsEnabled()) return true;
    return notifications.requestNotifications();
  }
}

/// Routing of a tapped wird reminder.
abstract final class WirdReminderTaps {
  /// The plan a tapped reminder is about (null when [tap] is not a wird
  /// reminder). Open the wird screen, or the reader at that plan's portion.
  static String? planOf(NotificationTap tap) {
    if (tap.namespace != WirdReminderIds.namespace.name) return null;
    final plan = tap.data['plan'];
    return plan is String && plan.isNotEmpty ? plan : null;
  }
}
