import 'package:flutter/foundation.dart';

import '../../../core/notifications/notification_models.dart';
import 'documents.dart';
import 'trip_timeline.dart';

/// Travel's block inside the shared `reminders` notification namespace
/// (130000–139999): 138000–138999. Syncing leaves every other id of the
/// namespace alone, so other features' reminders survive.
abstract final class TravelReminderIds {
  static const NotificationNamespace namespace = NotificationNamespaces.reminders;
  static const int first = 138000;
  static const int last = 138999;

  /// Two reminders per document.
  static const int perDocument = 2;
  static const int maxDocuments = (last - first + 1) ~/ perDocument;

  static bool owns(int id) => id >= first && id <= last;

  static int idFor(int slot, DocumentReminderKind kind) => first + slot * perDocument + kind.index;
}

enum DocumentReminderKind {
  /// `remindDaysBefore` days before the expiry.
  ahead,

  /// On the expiry day itself.
  onDay,
}

/// One planned document reminder (texts are added by the scheduler).
@immutable
class DocumentReminderPlan {
  const DocumentReminderPlan({
    required this.id,
    required this.at,
    required this.doc,
    required this.kind,
    required this.daysLeft,
  });

  final int id;
  final DateTime at;
  final DocFacts doc;
  final DocumentReminderKind kind;

  /// Calendar days from the reminder's day to the expiry.
  final int daysLeft;

  @override
  bool operator ==(Object other) =>
      other is DocumentReminderPlan && other.id == id && other.at == at && other.doc.id == doc.id && other.kind == kind;

  @override
  int get hashCode => Object.hash(id, at, doc.id, kind);

  @override
  String toString() => 'DocumentReminderPlan($id, ${doc.name}, $kind at $at)';
}

/// Plans the expiry reminders of travel documents (pure): one
/// `remindDaysBefore` days ahead and one on the expiry day, at [hour]:[minute]
/// device time, only for moments still ahead of `now`.
abstract final class DocumentReminderPlanner {
  static const int defaultHour = 10;
  static const int defaultMinute = 0;

  static List<DocumentReminderPlan> plan(
    List<DocFacts> docs, {
    required DateTime now,
    int hour = defaultHour,
    int minute = defaultMinute,
  }) {
    final out = <DocumentReminderPlan>[];
    for (var slot = 0; slot < docs.length && slot < TravelReminderIds.maxDocuments; slot++) {
      final d = docs[slot];
      final expiry = d.expiry;
      if (expiry == null) continue;
      DateTime at(DateTime day) => DateTime(day.year, day.month, day.day, hour, minute);
      final ahead = d.remindDaysBefore.clamp(0, 3650);
      if (ahead > 0) {
        final day = TravelDates.addDays(expiry, -ahead);
        final when = at(day);
        if (when.isAfter(now)) {
          out.add(
            DocumentReminderPlan(
              id: TravelReminderIds.idFor(slot, DocumentReminderKind.ahead),
              at: when,
              doc: d,
              kind: DocumentReminderKind.ahead,
              daysLeft: ahead,
            ),
          );
        }
      }
      final onDay = at(expiry);
      if (onDay.isAfter(now)) {
        out.add(
          DocumentReminderPlan(
            id: TravelReminderIds.idFor(slot, DocumentReminderKind.onDay),
            at: onDay,
            doc: d,
            kind: DocumentReminderKind.onDay,
            daysLeft: 0,
          ),
        );
      }
    }
    out.sort((a, b) => a.at.compareTo(b.at));
    return out;
  }
}
