import '../../../core/notifications/notification_models.dart';
import '../../../core/notifications/notification_service.dart';
import '../domain/body_reminder_plan.dart';

/// Channel / group names in the UI language.
typedef BodyChannelTexts = ({String group, String name, String description});

/// Delivers the Body planet's notifications.
abstract interface class BodyReminderScheduler {
  /// Makes [notices] exactly the pending Body notifications.
  Future<void> replaceAll(List<BodyNotice> notices);

  Future<void> cancelAll();

  /// Asks for the notification permission when it is missing (called when
  /// the user switches a fasting notification on); true when granted.
  Future<bool> ensurePermission();
}

/// [BodyReminderScheduler] over Madar's [NotificationService]: its own id
/// block of the `reminders` namespace ([BodyReminderIds], 139800–139803),
/// channel `madar.body.fasting.1` (normal importance, system sound), inexact
/// timing (a few minutes' drift is fine for a fasting goal).
class NotificationBodyReminderScheduler implements BodyReminderScheduler {
  NotificationBodyReminderScheduler({required this.notifications, required this.texts});

  final NotificationService notifications;
  final BodyChannelTexts Function() texts;

  static const String channelPrefix = 'madar.body.fasting.';
  static const String channelId = 'madar.body.fasting.1';
  static const String groupId = 'madar.body';

  /// `data.kind` of every Body notification (`fastGoal` / `eatingClose` in
  /// `data.notice`).
  static const String kind = 'bodyFasting';

  Future<void> _ensureChannel() async {
    final t = texts();
    await notifications.ensureChannelGroup(groupId, t.group);
    await notifications.ensureChannels([
      NotificationChannelSpec(
        id: channelId,
        name: t.name,
        description: t.description,
        importance: NotificationImportance.normal,
        groupId: groupId,
      ),
    ], prunePrefix: channelPrefix);
  }

  static NotificationRequest requestFor(BodyNotice n) => NotificationRequest(
    namespace: BodyReminderIds.namespace,
    id: n.id,
    channelId: channelId,
    title: n.title,
    body: n.body,
    at: n.at,
    data: {'kind': kind, 'notice': n.kind.name},
    category: NotificationCategory.reminder,
    timing: NotificationTiming.inexactWhileIdle,
    timeout: const Duration(hours: 3),
    dropIfLateBy: const Duration(hours: 1),
  );

  @override
  Future<void> replaceAll(List<BodyNotice> notices) async {
    if (notices.isNotEmpty) await _ensureChannel();
    await notifications.sync(BodyReminderIds.namespace, [
      for (final n in notices) requestFor(n),
    ], keep: (id) => !BodyReminderIds.owns(id));
  }

  @override
  Future<void> cancelAll() => replaceAll(const []);

  @override
  Future<bool> ensurePermission() async {
    if (await notifications.notificationsEnabled()) return true;
    return notifications.requestNotifications();
  }
}

/// Records what would have been scheduled (tests, previews).
class RecordingBodyReminderScheduler implements BodyReminderScheduler {
  List<BodyNotice> current = const [];
  int syncs = 0;

  /// How often the permission was asked for.
  int permissionRequests = 0;

  /// What [ensurePermission] answers.
  bool granted = true;

  @override
  Future<bool> ensurePermission() async {
    permissionRequests++;
    return granted;
  }

  @override
  Future<void> replaceAll(List<BodyNotice> notices) async {
    syncs++;
    current = List.unmodifiable(notices);
  }

  @override
  Future<void> cancelAll() => replaceAll(const []);
}

/// Routing of a tapped Body notification.
abstract final class BodyReminderTaps {
  /// Whether [tap] is a fasting notification (open the Body screen on its
  /// fasting tab).
  static bool matches(NotificationTap tap) =>
      tap.namespace == BodyReminderIds.namespace.name &&
      (tap.id == null || BodyReminderIds.owns(tap.id!)) &&
      tap.data['kind'] == NotificationBodyReminderScheduler.kind;
}
