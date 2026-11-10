import '../../../../core/db/database.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/notifications/notification_models.dart';
import '../../../../core/notifications/notification_service.dart';
import '../domain/appointment_plan.dart';
import '../domain/record_texts.dart';

/// A planned reminder with its texts.
class AppointmentNotice {
  const AppointmentNotice({required this.reminder, required this.title, required this.body});

  final AppointmentReminder reminder;
  final String title;
  final String body;

  Map<String, Object?> get data => {
    'kind': AppointmentReminderTaps.kind,
    'appointment': reminder.appointmentId,
    'offset': reminder.offsetMinutes,
  };
}

/// Delivers appointment reminders (the notification service in the app, a
/// recorder in tests).
abstract interface class AppointmentReminderScheduler {
  /// Makes the record's pending reminders exactly [notices].
  Future<void> replaceAll(List<AppointmentNotice> notices);

  /// Cancels every pending appointment reminder.
  Future<void> cancelAll();

  /// Asks for the notification permission if needed.
  Future<bool> ensurePermission();
}

/// Texts channel / group names in the UI language.
typedef AppointmentChannelTexts = ({String group, String name, String description});

/// [AppointmentReminderScheduler] over Madar's [NotificationService]. It
/// reconciles only its own id block ([AppointmentReminderIds], 150000–150399
/// of the shared health namespace) and leaves the other health packages'
/// notifications alone.
///
/// Channel `madar.health.appointments.1` (high importance, system sound).
/// Exact-while-idle, falling back to inexact without the exact-alarm
/// permission. A reminder shown stays until dismissed or 6 h have passed.
class NotificationAppointmentReminderScheduler implements AppointmentReminderScheduler {
  NotificationAppointmentReminderScheduler({required this.notifications, required this.texts});

  final NotificationService notifications;
  final AppointmentChannelTexts Function() texts;

  static const String channelPrefix = 'madar.health.appointments.';
  static const String channelId = 'madar.health.appointments.1';
  static const String groupId = 'madar.health';
  static const Duration timeout = Duration(hours: 6);
  static const Duration dropIfLateBy = Duration(hours: 3);

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

  static NotificationRequest requestFor(AppointmentNotice n) => NotificationRequest(
    namespace: AppointmentReminderIds.namespace,
    id: n.reminder.id,
    channelId: channelId,
    title: n.title,
    body: n.body,
    at: n.reminder.at,
    data: n.data,
    category: NotificationCategory.event,
    timing: NotificationTiming.exactWhileIdle,
    timeout: timeout,
    dropIfLateBy: dropIfLateBy,
  );

  @override
  Future<void> replaceAll(List<AppointmentNotice> notices) async {
    if (notices.isNotEmpty) await _ensureChannel();
    await notifications.sync(AppointmentReminderIds.namespace, [
      for (final n in notices) requestFor(n),
    ], keep: (id) => !AppointmentReminderIds.owns(id));
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
class RecordingAppointmentReminderScheduler implements AppointmentReminderScheduler {
  List<AppointmentNotice> current = const [];
  int syncs = 0;
  bool permission = true;

  @override
  Future<void> replaceAll(List<AppointmentNotice> notices) async {
    syncs++;
    current = List.unmodifiable(notices);
  }

  @override
  Future<void> cancelAll() => replaceAll(const []);

  @override
  Future<bool> ensurePermission() async => permission;
}

/// Routing of a tapped appointment reminder.
abstract final class AppointmentReminderTaps {
  static const String kind = 'appointment';

  /// The appointment a tapped reminder is about (null when [tap] is not an
  /// appointment reminder). Open `AppointmentsScreen(highlightId: …)`.
  static String? appointmentOf(NotificationTap tap) {
    if (tap.namespace != AppointmentReminderIds.namespace.name) return null;
    if (tap.data['kind'] != kind) return null;
    final id = tap.data['appointment'];
    return id is String && id.isNotEmpty ? id : null;
  }
}

/// Builds the reminder texts in the UI language.
abstract final class AppointmentNoticeTexts {
  static List<AppointmentNotice> build(
    List<AppointmentReminder> reminders,
    Map<String, AppointmentRow> appointments,
    L10n l,
    MadarFormatter fmt,
  ) {
    final texts = RecordTexts(l, fmt);
    final out = <AppointmentNotice>[];
    for (final r in reminders) {
      final a = appointments[r.appointmentId];
      if (a == null) continue;
      final time = fmt.formatTime(a.at);
      final when = r.offsetMinutes >= 1440
          ? texts.relativeDay(AppointmentTimeline.daysUntil(a.at, r.at))
          : l.recordReminderIn(fmt.formatDurationWords(l, Duration(minutes: r.offsetMinutes)));
      final details = [
        l.recordDateAtTime(when, time),
        if (a.doctor?.trim().isNotEmpty ?? false) BidiIsolate.isolate(a.doctor!.trim()),
        if (a.place?.trim().isNotEmpty ?? false) BidiIsolate.isolate(a.place!.trim()),
      ];
      out.add(
        AppointmentNotice(
          reminder: r,
          title: l.recordReminderTitle(BidiIsolate.isolate(a.title.trim())),
          body: details.join(l.recordListSeparator),
        ),
      );
    }
    return out;
  }
}
