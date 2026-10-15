/// «الحفظ» · delivering the goals' reminders (Part 14).
///
/// The planner is pure ([HifzGoalReminderPlanner]); this hands its result
/// to Madar's own [NotificationService] as the **complete, declarative
/// plan** of the [HifzGoalReminderIds.namespace] id block (190000–190999),
/// so re-planning leaves an unchanged reminder alone and cancels only the
/// ones that are no longer wanted. The daily wird's block
/// (140000–140999) is never touched.
///
/// One channel, `madar.hifz.reminder.1`: high importance with the system
/// sound – a nudge after the prayer, never an alarm. Exact-while-idle,
/// falling back to inexact without the exact-alarm permission (fine for
/// "after Fajr"). After a reboot a reminder more than [dropIfLateBy] late
/// is not restored, and a shown one removes itself after [timeout].
library;

import '../../../core/notifications/notification_models.dart';
import '../../../core/notifications/notification_service.dart';
import '../domain/hifz_goal_reminders.dart';

/// The channel texts (system settings › notifications), in the UI
/// language.
typedef HifzChannelTexts = ({String group, String name, String description});

class NotificationHifzGoalScheduler implements HifzGoalScheduler {
  NotificationHifzGoalScheduler({required this.notifications, required this.texts});

  final NotificationService notifications;

  /// Resolved on every sync, so a language switch renames the channel.
  final HifzChannelTexts Function() texts;

  static const NotificationNamespace namespace = HifzGoalReminderIds.namespace;
  static const String channelPrefix = 'madar.hifz.';
  static const String channelId = 'madar.hifz.reminder.1';
  static const String groupId = 'madar.hifz';
  static const Duration dropIfLateBy = Duration(hours: 2);
  static const Duration timeout = Duration(hours: 6);

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

  static NotificationRequest requestFor(HifzGoalNotice notice) => NotificationRequest(
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
  Future<void> replaceAll(List<HifzGoalNotice> notices) async {
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

/// Routing of a tapped goal reminder.
abstract final class HifzGoalTaps {
  /// The goal a tapped reminder is about (null when [tap] is not one of
  /// «الحفظ»'s). Open «الحفظ» at that goal, or the reader at its stretch.
  static String? goalOf(NotificationTap tap) {
    if (tap.namespace != HifzGoalReminderIds.namespace.name) return null;
    final goal = tap.data['goal'];
    return goal is String && goal.isNotEmpty ? goal : null;
  }
}
