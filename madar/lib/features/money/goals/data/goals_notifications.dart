import 'package:meta/meta.dart';

import '../../../../core/notifications/notification_models.dart';
import '../../../../core/notifications/notification_service.dart';
import '../domain/due_reminders.dart';

/// The goals package's slice of the shared `reminders` notification
/// namespace: ids 136000–136999 (offsets 6000–6999). Syncing touches only
/// this block, so other features may use the rest of the namespace.
abstract final class GoalsReminderIds {
  static const NotificationNamespace namespace = NotificationNamespaces.reminders;
  static const int firstOffset = 6000;
  static const int size = 1000;

  static int get first => namespace.first + firstOffset;
  static int get last => first + size - 1;

  /// The id of the [index]-th planned reminder (0 ≤ index < [size]).
  static int of(int index) {
    if (index < 0 || index >= size) throw RangeError.range(index, 0, size - 1, 'index');
    return namespace.id(firstOffset + index);
  }

  static bool owns(int id) => id >= first && id <= last;
}

/// One due reminder ready to schedule.
@immutable
class GoalsNotice {
  const GoalsNotice({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
    required this.kind,
    required this.refId,
  });

  final int id;
  final DateTime at;
  final String title;
  final String body;
  final DueReminderKind kind;
  final String refId;

  Map<String, Object?> get data => {'kind': 'money.due', 'target': kind.name, 'id': refId};

  @override
  String toString() => 'GoalsNotice($id at $at: $title – $body)';
}

/// Delivers due reminders (a seam for tests).
abstract interface class GoalsReminderScheduler {
  /// Makes the scheduled reminders exactly [notices].
  Future<void> replaceAll(List<GoalsNotice> notices);

  Future<void> cancelAll();
}

/// The channel texts (system settings › notifications), in the UI language.
typedef GoalsChannelTexts = ({String group, String name, String description});

/// [GoalsReminderScheduler] over Madar's [NotificationService].
///
/// One channel, `madar.money.due.1` (normal importance, the system sound –
/// a nudge, never an alarm), inexact-while-idle (a bill reminder may drift
/// by minutes), removed after 12 hours, not restored after a reboot when
/// more than 6 hours late.
class NotificationGoalsReminderScheduler implements GoalsReminderScheduler {
  NotificationGoalsReminderScheduler({required this.notifications, required this.texts});

  final NotificationService notifications;
  final GoalsChannelTexts Function() texts;

  static const String channelPrefix = 'madar.money.';
  static const String channelId = 'madar.money.due.1';
  static const String groupId = 'madar.money';

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

  static NotificationRequest requestFor(GoalsNotice n) => NotificationRequest(
    namespace: GoalsReminderIds.namespace,
    id: n.id,
    channelId: channelId,
    title: n.title,
    body: n.body,
    at: n.at,
    data: n.data,
    category: NotificationCategory.reminder,
    timing: NotificationTiming.inexactWhileIdle,
    timeout: const Duration(hours: 12),
    dropIfLateBy: const Duration(hours: 6),
  );

  @override
  Future<void> replaceAll(List<GoalsNotice> notices) async {
    if (notices.isNotEmpty) await _ensureChannel();
    await notifications.sync(GoalsReminderIds.namespace, [
      for (final n in notices) requestFor(n),
    ], keep: (id) => !GoalsReminderIds.owns(id));
  }

  @override
  Future<void> cancelAll() => replaceAll(const []);
}

/// Records what would have been scheduled (tests, previews).
class RecordingGoalsReminderScheduler implements GoalsReminderScheduler {
  List<GoalsNotice> current = const [];
  int syncs = 0;

  @override
  Future<void> replaceAll(List<GoalsNotice> notices) async {
    syncs++;
    current = List.unmodifiable(notices);
  }

  @override
  Future<void> cancelAll() => replaceAll(const []);
}

/// Routing of a tapped due reminder.
abstract final class GoalsReminderTaps {
  /// The debt or obligation a tapped reminder is about (null when [tap] is
  /// not a goals reminder): open the goals screen on that tab and show its
  /// sheet (`showDebtSheet` / `showObligationSheet`).
  static ({DueReminderKind kind, String id})? targetOf(NotificationTap tap) {
    if (tap.namespace != GoalsReminderIds.namespace.name) return null;
    if (tap.id != null && !GoalsReminderIds.owns(tap.id!)) return null;
    if (tap.data['kind'] != 'money.due') return null;
    final id = tap.data['id'];
    final kind = DueReminderKind.values.where((k) => k.name == tap.data['target']).firstOrNull;
    if (id is! String || id.isEmpty || kind == null) return null;
    return (kind: kind, id: id);
  }
}
