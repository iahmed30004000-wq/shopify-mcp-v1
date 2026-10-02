import 'package:flutter/foundation.dart';

import '../../../../core/notifications/notification_models.dart';
import '../../../../core/notifications/notification_service.dart';
import '../domain/worry_window.dart';

/// One planned "your worry window is open" notification.
@immutable
class WorryNotice {
  const WorryNotice({required this.id, required this.at, required this.title, required this.body});

  final int id;
  final DateTime at;
  final String title;
  final String body;

  @override
  bool operator ==(Object other) =>
      other is WorryNotice && other.id == id && other.at == at && other.title == title && other.body == body;

  @override
  int get hashCode => Object.hash(id, at, title, body);

  @override
  String toString() => 'WorryNotice#$id@$at';
}

/// Texts channel / group names in the UI language.
typedef WorryChannelTexts = ({String group, String name, String description});

/// Delivers the worry-window notifications.
abstract interface class WorryReminderScheduler {
  /// Makes [notices] exactly the pending worry-window notifications.
  Future<void> replaceAll(List<WorryNotice> notices);

  Future<void> cancelAll();
}

/// [WorryReminderScheduler] over Madar's [NotificationService]: its own id
/// block of the health namespace ([WorryReminderIds], 150900–150906), channel
/// `madar.health.worry.1` (normal importance, gentle: system sound, no
/// heads-up), inexact timing (a few minutes' drift is fine), removed after
/// the window has closed.
class NotificationWorryReminderScheduler implements WorryReminderScheduler {
  NotificationWorryReminderScheduler({required this.notifications, required this.texts});

  final NotificationService notifications;
  final WorryChannelTexts Function() texts;

  static const String channelPrefix = 'madar.health.worry.';
  static const String channelId = 'madar.health.worry.1';
  static const String groupId = 'madar.health';
  static const String kind = 'worryWindow';

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

  static NotificationRequest requestFor(WorryNotice n) => NotificationRequest(
    namespace: WorryReminderIds.namespace,
    id: n.id,
    channelId: channelId,
    title: n.title,
    body: n.body,
    at: n.at,
    data: const {'kind': kind},
    category: NotificationCategory.reminder,
    timing: NotificationTiming.inexactWhileIdle,
    timeout: const Duration(hours: 2),
    dropIfLateBy: const Duration(hours: 1),
  );

  @override
  Future<void> replaceAll(List<WorryNotice> notices) async {
    if (notices.isNotEmpty) await _ensureChannel();
    await notifications.sync(WorryReminderIds.namespace, [
      for (final n in notices) requestFor(n),
    ], keep: (id) => !WorryReminderIds.owns(id));
  }

  @override
  Future<void> cancelAll() => replaceAll(const []);
}

/// Records what would have been scheduled (tests, previews).
class RecordingWorryReminderScheduler implements WorryReminderScheduler {
  List<WorryNotice> current = const [];
  int syncs = 0;

  @override
  Future<void> replaceAll(List<WorryNotice> notices) async {
    syncs++;
    current = List.unmodifiable(notices);
  }

  @override
  Future<void> cancelAll() => replaceAll(const []);
}

/// Routing of a tapped worry-window notification.
abstract final class WorryReminderTaps {
  /// Whether [tap] is a worry-window notification (open the wellbeing
  /// screen on its worries tab).
  static bool matches(NotificationTap tap) =>
      tap.namespace == WorryReminderIds.namespace.name &&
      (tap.id == null || WorryReminderIds.owns(tap.id!)) &&
      tap.data['kind'] == NotificationWorryReminderScheduler.kind;
}

/// Plans the notices for the next days (pure).
abstract final class WorryReminderPlanner {
  static List<WorryNotice> plan({
    required WorryWindowSettings settings,
    required DateTime now,
    required String title,
    required String Function(DateTime start) body,
  }) {
    final starts = WorryWindow.upcoming(settings, now);
    return [
      for (var i = 0; i < starts.length; i++)
        WorryNotice(id: WorryReminderIds.of(i), at: starts[i], title: title, body: body(starts[i])),
    ];
  }
}
