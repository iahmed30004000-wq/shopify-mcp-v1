import '../../../core/domain/enums.dart';
import '../../../core/notifications/notification_models.dart';
import '../../../core/notifications/notification_service.dart';
import '../../orbit/domain/prayer_schedule.dart';
import '../../prayer/domain/prayer_day.dart' show PrayerTimesDay;
import '../custom_texts.dart';
import '../domain/module_reminders.dart';
import 'custom_modules_service.dart';

/// Schedules the module reminders through Madar's [NotificationService]:
/// the planner's complete wanted set for [CustomModuleReminderIds]
/// (137000–137999 in the shared `reminders` namespace) – a re-plan leaves
/// unchanged notifications alone, reschedules changed ones and cancels the
/// rest – without touching any other id of the namespace.
///
/// One channel, `madar.custom.reminder.1` (default importance: a gentle
/// nudge). Exact-while-idle, falling back to inexact without the exact-alarm
/// permission. After a reboot a notice more than [dropIfLateBy] late is not
/// restored; a shown one removes itself after [timeout].
class CustomModulesReminderEngine {
  CustomModulesReminderEngine({
    required this.service,
    required this.notifications,
    required this.texts,
    required this.prayerStart,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final CustomModulesService service;
  final NotificationService notifications;
  final CustomTexts texts;
  final PrayerStartOf prayerStart;
  final DateTime Function() _clock;

  static const NotificationNamespace namespace = CustomModuleReminderIds.namespace;
  static const String channelPrefix = 'madar.custom.';
  static const String channelId = 'madar.custom.reminder.1';
  static const String groupId = 'madar.custom';
  static const Duration dropIfLateBy = Duration(hours: 2);
  static const Duration timeout = Duration(hours: 8);

  /// The accent of the notification (the app's brass gold).
  static const int accentArgb = 0xFFC9A45C;

  /// Window starts from a prayer schedule: Fajr, Duha (a quarter of an hour
  /// after sunrise, as on the prayer screen), Dhuhr, Asr, Maghrib, Isha.
  static PrayerStartOf prayerStartFrom(PrayerSchedule schedule) => (day, window) {
    final t = schedule.timesFor(day);
    return switch (window) {
      PrayerWindow.fajr => t.fajr,
      PrayerWindow.duha => t.sunrise.add(PrayerTimesDay.duhaAfterSunrise),
      PrayerWindow.dhuhr => t.dhuhr,
      PrayerWindow.asr => t.asr,
      PrayerWindow.maghrib => t.maghrib,
      PrayerWindow.isha => t.isha,
      PrayerWindow.anytime => null,
    };
  };

  Future<void> _ensureChannel() async {
    await notifications.ensureChannelGroup(groupId, texts.l.cmodNotifyGroup);
    await notifications.ensureChannels([
      NotificationChannelSpec(
        id: channelId,
        name: texts.l.cmodNotifyChannel,
        description: texts.l.cmodNotifyChannelDescription,
        importance: NotificationImportance.normal,
        groupId: groupId,
      ),
    ], prunePrefix: channelPrefix);
  }

  static NotificationRequest requestFor(ModuleNotice n) => NotificationRequest(
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
  Future<List<ModuleNotice>> plan() async => CustomReminderPlanner.plan(
    reminders: await service.reminderInputs(),
    now: _clock(),
    prayerStart: prayerStart,
    texts: texts,
  );

  /// Re-plans and reconciles the Custom Modules block.
  Future<NotificationSyncReport> resync() async {
    final notices = await plan();
    if (notices.isNotEmpty) await _ensureChannel();
    return notifications.sync(namespace, [
      for (final n in notices) requestFor(n),
    ], keep: (id) => !CustomModuleReminderIds.owns(id));
  }

  /// Cancels every module notification (other reminders stay).
  Future<void> cancelAll() =>
      notifications.sync(namespace, const [], keep: (id) => !CustomModuleReminderIds.owns(id));

  /// Asks for the notification permission when it is off.
  Future<bool> ensurePermission() async {
    if (await notifications.notificationsEnabled()) return true;
    return notifications.requestNotifications();
  }
}
