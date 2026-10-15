import 'package:flutter/foundation.dart';

import '../../../core/notifications/notification_models.dart';
import 'body_clock.dart';
import 'fasting.dart';

/// The Body planet's notification ids: a block at the end of the shared
/// `reminders` namespace (139800–139803), reconciled on its own.
abstract final class BodyReminderIds {
  static const NotificationNamespace namespace = NotificationNamespaces.reminders;
  static const int firstOffset = 9800;

  /// Goal reached + up to three eating-window reminders.
  static const int size = 4;
  static const int eatingDays = 3;

  static int get first => namespace.first + firstOffset;
  static int get last => first + size - 1;

  static bool owns(int id) => id >= first && id <= last;

  /// "Your fast reached its goal".
  static int get goal => namespace.id(firstOffset);

  /// "Your eating window closes soon", [slot] 0‥2 (next three days).
  static int eating(int slot) {
    if (slot < 0 || slot >= eatingDays) throw RangeError.range(slot, 0, eatingDays - 1, 'slot');
    return namespace.id(firstOffset + 1 + slot);
  }
}

enum BodyNoticeKind { fastGoal, eatingClose }

/// One planned Body notification.
@immutable
class BodyNotice {
  const BodyNotice({required this.id, required this.kind, required this.at, required this.title, required this.body});

  final int id;
  final BodyNoticeKind kind;
  final DateTime at;
  final String title;
  final String body;

  @override
  bool operator ==(Object other) =>
      other is BodyNotice &&
      other.id == id &&
      other.kind == kind &&
      other.at == at &&
      other.title == title &&
      other.body == body;

  @override
  int get hashCode => Object.hash(id, kind, at, title, body);

  @override
  String toString() => 'BodyNotice#$id(${kind.name}@$at)';
}

/// Plans the fasting notifications (pure).
abstract final class BodyReminderPlanner {
  /// * the running fast's goal ([FastingPlan.notifyGoal]), when still ahead;
  /// * [FastingPlan.eatingLeadMinutes] before each of the next
  ///   [BodyReminderIds.eatingDays] planned fast starts
  ///   ([FastingPlan.notifyEatingClose]), skipping any that fall inside the
  ///   running fast or are already past.
  static List<BodyNotice> plan({
    required FastingPlan plan,
    required DateTime now,
    FastingSpan? active,
    required String goalTitle,
    required String Function(FastingSpan fast) goalBody,
    required String eatingTitle,
    required String Function(DateTime closesAt) eatingBody,
    BodyWallClock clock = const LocalBodyWallClock(),
  }) {
    final out = <BodyNotice>[];
    if (plan.notifyGoal && active != null && active.goalAt.isAfter(now)) {
      out.add(
        BodyNotice(
          id: BodyReminderIds.goal,
          kind: BodyNoticeKind.fastGoal,
          at: active.goalAt,
          title: goalTitle,
          body: goalBody(active),
        ),
      );
    }
    if (plan.notifyEatingClose && plan.eatingWindow > Duration.zero) {
      var slot = 0;
      var day = clock.dayOf(now);
      for (var i = 0; i < BodyReminderIds.eatingDays + 1 && slot < BodyReminderIds.eatingDays; i++) {
        final closes = clock.at(day, plan.lastMealMinutes);
        final at = closes.subtract(Duration(minutes: plan.eatingLeadMinutes));
        day = BodyDays.add(day, 1);
        if (!at.isAfter(now)) continue;
        if (active != null && !at.isBefore(active.start) && at.isBefore(active.goalAt)) continue;
        out.add(
          BodyNotice(
            id: BodyReminderIds.eating(slot++),
            kind: BodyNoticeKind.eatingClose,
            at: at,
            title: eatingTitle,
            body: eatingBody(closes),
          ),
        );
      }
    }
    return out;
  }
}
