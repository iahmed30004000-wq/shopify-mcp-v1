import '../../../core/notifications/notification_models.dart';
import '../../../core/notifications/notification_service.dart';
import '../domain/document_reminders.dart';
import '../domain/documents.dart';
import '../travel_texts.dart';

/// Document-expiry reminders over Madar's [NotificationService].
///
/// The plan is declarative for Travel's id block ([TravelReminderIds],
/// 138000–138999 inside the shared `reminders` namespace): re-planning
/// leaves unchanged reminders alone, cancels the ones no longer wanted and
/// never touches another feature's ids in the namespace.
///
/// One channel, `madar.travel.documents.1` (default importance with the
/// system sound – a nudge, never an alarm), inexact-tolerant exact-while-idle
/// timing; a reminder that missed its moment by more than [dropIfLateBy]
/// (phone off) is not restored after a reboot.
class TravelDocumentNotifier {
  TravelDocumentNotifier({required this.notifications, required this.texts});

  final NotificationService notifications;

  /// Resolved on every sync, so a language switch renames the channel.
  final TravelTexts Function() texts;

  static const String channelPrefix = 'madar.travel.';
  static const String channelId = 'madar.travel.documents.1';
  static const String groupId = 'madar.travel';
  static const Duration dropIfLateBy = Duration(hours: 12);

  Future<void> _ensureChannel(TravelTexts t) async {
    final c = t.channel;
    await notifications.ensureChannelGroup(groupId, c.group);
    await notifications.ensureChannels([
      NotificationChannelSpec(
        id: channelId,
        name: c.name,
        description: c.description,
        importance: NotificationImportance.high,
        groupId: groupId,
      ),
    ], prunePrefix: channelPrefix);
  }

  static NotificationRequest requestFor(DocumentReminderPlan plan, TravelTexts t) => NotificationRequest(
    namespace: TravelReminderIds.namespace,
    id: plan.id,
    channelId: channelId,
    title: t.noticeTitle(plan),
    body: t.noticeBody(plan),
    at: plan.at,
    data: {'feature': 'travel', 'documentId': plan.doc.id, 'kind': plan.kind.name},
    category: NotificationCategory.reminder,
    timing: NotificationTiming.exactWhileIdle,
    dropIfLateBy: dropIfLateBy,
  );

  /// Plans and syncs the reminders of [docs] (in their stored order – each
  /// document's slot is its position) as of [now].
  Future<NotificationSyncReport> sync(List<DocFacts> docs, {required DateTime now}) async {
    final t = texts();
    await _ensureChannel(t);
    final plans = DocumentReminderPlanner.plan(docs, now: now);
    return notifications.sync(TravelReminderIds.namespace, [
      for (final p in plans) requestFor(p, t),
    ], keep: (id) => !TravelReminderIds.owns(id));
  }

  /// Cancels every pending travel reminder (and nothing else).
  Future<void> cancelAll() async {
    for (final tap in await notifications.pendingIn(TravelReminderIds.namespace)) {
      final id = tap.id;
      if (id != null && TravelReminderIds.owns(id)) await notifications.cancel(id);
    }
  }
}

/// Routing of a tapped travel reminder.
abstract final class TravelReminderTaps {
  /// The document a tapped reminder is about (null when [tap] is not one).
  static String? documentOf(NotificationTap tap) {
    if (tap.namespace != TravelReminderIds.namespace.name) return null;
    if (tap.data['feature'] != 'travel') return null;
    final id = tap.data['documentId'];
    return id is String && id.isNotEmpty ? id : null;
  }
}
