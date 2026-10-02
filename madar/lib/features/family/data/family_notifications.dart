import '../../../core/notifications/notification_models.dart';
import '../../../core/notifications/notification_service.dart';
import '../domain/family_models.dart';
import '../domain/family_reminders.dart';
import '../family_texts.dart';
import 'family_service.dart';

/// Schedules the Family notifications through Madar's [NotificationService]:
/// the planner's complete wanted set for [FamilyNotificationIds] – so a
/// re-plan leaves unchanged notifications alone, reschedules changed ones
/// and cancels the rest – without touching other ids of the shared
/// `reminders` namespace.
///
/// One channel, `madar.family.reminder.1` (default importance, the system
/// sound: a gentle nudge, never an alarm). Exact-while-idle, falling back to
/// inexact without the exact-alarm permission. After a reboot a notice more
/// than [dropIfLateBy] late is not restored; a shown one removes itself
/// after [timeout].
class FamilyReminderEngine {
  FamilyReminderEngine({
    required this.service,
    required this.notifications,
    required this.texts,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final FamilyService service;
  final NotificationService notifications;
  final FamilyTexts texts;
  final DateTime Function() _clock;

  static const NotificationNamespace namespace = FamilyNotificationIds.namespace;
  static const String channelPrefix = 'madar.family.';
  static const String channelId = 'madar.family.reminder.1';
  static const String groupId = 'madar.family';
  static const Duration dropIfLateBy = Duration(hours: 3);
  static const Duration timeout = Duration(hours: 10);

  /// Terracotta of the Family planet (the notification accent).
  static const int accentArgb = 0xFFD9774A;

  Future<void> _ensureChannel() async {
    await notifications.ensureChannelGroup(groupId, texts.l.familyNotifyGroup);
    await notifications.ensureChannels([
      NotificationChannelSpec(
        id: channelId,
        name: texts.l.familyNotifyChannel,
        description: texts.l.familyNotifyChannelDescription,
        importance: NotificationImportance.normal,
        groupId: groupId,
      ),
    ], prunePrefix: channelPrefix);
  }

  static NotificationRequest requestFor(FamilyNotice n) => NotificationRequest(
    namespace: namespace,
    id: n.id,
    channelId: channelId,
    title: n.title,
    body: n.body,
    at: n.at,
    data: n.data,
    category: NotificationCategory.reminder,
    timing: NotificationTiming.exactWhileIdle,
    timeout: timeout,
    dropIfLateBy: dropIfLateBy,
    colorArgb: accentArgb,
  );

  /// The notices wanted now.
  Future<List<FamilyNotice>> plan() async {
    final overview = await service.overview();
    final settings = await service.settings();
    return FamilyReminderPlanner.plan(people: overview.people, settings: settings, now: _clock(), texts: texts);
  }

  /// Re-plans and reconciles the Family block.
  Future<NotificationSyncReport> resync() async {
    final notices = await plan();
    await _ensureChannel();
    return notifications.sync(namespace, [
      for (final n in notices) requestFor(n),
    ], keep: (id) => !FamilyNotificationIds.owns(id));
  }

  /// Cancels every Family notification (other reminders stay).
  Future<void> cancelAll() => notifications.sync(namespace, const [], keep: (id) => !FamilyNotificationIds.owns(id));

  /// Asks for the notification permission when it is off.
  Future<bool> ensurePermission() async {
    if (await notifications.notificationsEnabled()) return true;
    return notifications.requestNotifications();
  }

  /// Whether [settings] want any notification at all.
  static bool wantsAny(FamilySettings settings) => settings.digestEnabled || settings.birthdaysEnabled;
}
