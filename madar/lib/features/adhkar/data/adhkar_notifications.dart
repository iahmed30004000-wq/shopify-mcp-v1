import '../../../core/notifications/notification_models.dart';
import '../../../core/notifications/notification_service.dart';
import '../domain/adhkar_models.dart';
import '../domain/adhkar_reminders.dart';

/// The channel texts (system settings › notifications), in the UI language.
typedef AdhkarChannelTexts = ({String group, String name, String description});

/// [AdhkarReminderScheduler] over Madar's [NotificationService]: the
/// reminders are the complete, declarative plan of the
/// [NotificationNamespaces.adhkar] id block, so re-planning leaves unchanged
/// reminders alone and cancels the ones no longer wanted.
///
/// One channel, `madar.adhkar.reminder.1` (high importance, the system
/// notification sound – a gentle reminder, never an alarm). Timing is
/// exact-while-idle; without the exact-alarm permission the service falls
/// back to inexact delivery, which is fine for "a little after Fajr". After a
/// reboot a reminder more than [dropIfLateBy] late is not restored, and a
/// shown reminder removes itself after [timeout].
class NotificationAdhkarReminderScheduler implements AdhkarReminderScheduler {
  NotificationAdhkarReminderScheduler({required this.notifications, required this.texts});

  final NotificationService notifications;

  /// Resolved on every sync, so a language switch renames the channel.
  final AdhkarChannelTexts Function() texts;

  static const NotificationNamespace namespace = NotificationNamespaces.adhkar;
  static const String channelPrefix = 'madar.adhkar.';
  static const String channelId = 'madar.adhkar.reminder.1';
  static const String groupId = 'madar.adhkar';
  static const Duration dropIfLateBy = Duration(minutes: 90);
  static const Duration timeout = Duration(hours: 3);

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

  /// The notification request for [notice].
  static NotificationRequest requestFor(AdhkarReminderNotice notice) => NotificationRequest(
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
  Future<void> replaceAll(List<AdhkarReminderNotice> notices) async {
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

/// Routing of a tapped adhkar reminder.
abstract final class AdhkarReminderTaps {
  /// The set a tapped reminder opens (null when [tap] is not an adhkar
  /// reminder). Open it with `AdhkarReaderScreen(category: …)`.
  static AdhkarCategoryId? categoryOf(NotificationTap tap) =>
      tap.namespace == NotificationNamespaces.adhkar.name ? AdhkarCategoryId.tryParse(tap.data['set']) : null;
}
