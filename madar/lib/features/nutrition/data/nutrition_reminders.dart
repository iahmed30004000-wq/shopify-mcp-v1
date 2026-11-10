import '../../../core/notifications/notification_models.dart';
import '../../../core/notifications/notification_service.dart';
import '../domain/meal_reminders.dart';

/// Channel / group names in the UI language.
typedef MealChannelTexts = ({String group, String name, String description});

/// Delivers the meal reminders of the active plan.
abstract interface class MealReminderScheduler {
  /// Makes [notices] exactly the pending meal notifications.
  Future<void> replaceAll(List<MealNotice> notices);

  Future<void> cancelAll();

  /// Asks for the notification permission when it is missing (called when
  /// the user switches a slot's reminder on); true when granted.
  Future<bool> ensurePermission();
}

/// [MealReminderScheduler] over Madar's [NotificationService]: its own id
/// block of the `reminders` namespace ([MealReminderIds], 139000–139499),
/// channel `madar.nutrition.meals.1` (normal importance, system sound) and
/// inexact timing – a meal reminder a few minutes off is still useful, and
/// it costs no exact-alarm permission.
class NotificationMealReminderScheduler implements MealReminderScheduler {
  NotificationMealReminderScheduler({required this.notifications, required this.texts, required this.body});

  final NotificationService notifications;
  final MealChannelTexts Function() texts;

  /// The notification body for one notice (the UI language; the planned
  /// foods are already in [MealNotice.foods]).
  final String Function(MealNotice notice) body;

  static const String channelPrefix = 'madar.nutrition.meals.';
  static const String channelId = 'madar.nutrition.meals.1';
  static const String groupId = 'madar.nutrition';

  /// `data.kind` of every meal notification.
  static const String kind = 'nutritionMeal';

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

  NotificationRequest requestFor(MealNotice n) => NotificationRequest(
    namespace: MealReminderIds.namespace,
    id: n.id,
    channelId: channelId,
    title: n.slotName,
    body: body(n),
    at: n.at,
    data: {'kind': kind, 'slotId': n.slotId},
    category: NotificationCategory.reminder,
    timing: NotificationTiming.inexactWhileIdle,
    timeout: const Duration(hours: 3),
    dropIfLateBy: const Duration(hours: 2),
  );

  @override
  Future<void> replaceAll(List<MealNotice> notices) async {
    if (notices.isNotEmpty) await _ensureChannel();
    await notifications.sync(MealReminderIds.namespace, [
      for (final n in notices) requestFor(n),
    ], keep: (id) => !MealReminderIds.owns(id));
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
class RecordingMealReminderScheduler implements MealReminderScheduler {
  List<MealNotice> current = const [];
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
  Future<void> replaceAll(List<MealNotice> notices) async {
    syncs++;
    current = List.unmodifiable(notices);
  }

  @override
  Future<void> cancelAll() => replaceAll(const []);
}

/// Routing of a tapped meal notification.
abstract final class MealReminderTaps {
  /// Whether [tap] is a meal reminder (open the food log on that slot).
  static bool matches(NotificationTap tap) =>
      tap.namespace == MealReminderIds.namespace.name &&
      (tap.id == null || MealReminderIds.owns(tap.id!)) &&
      tap.data['kind'] == NotificationMealReminderScheduler.kind;

  /// The slot the tapped reminder was for, or null.
  static String? slotOf(NotificationTap tap) => matches(tap) ? tap.data['slotId'] as String? : null;
}
