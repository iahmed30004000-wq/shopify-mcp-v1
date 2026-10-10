import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/notifications/fake_notification_platform.dart';
import 'package:madar/core/notifications/notification_models.dart';
import 'package:madar/core/notifications/notification_service.dart';
import 'package:madar/features/money/goals/goals.dart';

/// Tuesday 29 Sep 2026, 20:15 – a fixed clock.
final _now = DateTime(2026, 9, 29, 20, 15);

GoalsNotice _notice(int id, DateTime at, {String ref = 'ob-1'}) => GoalsNotice(
  id: id,
  at: at,
  title: 'Rent',
  body: 'Tomorrow',
  kind: DueReminderKind.obligation,
  refId: ref,
);

void main() {
  group('GoalsReminderIds', () {
    test('own 132000–132999 of the reminders namespace (clear of Family, Travel and Body)', () {
      expect(GoalsReminderIds.namespace, NotificationNamespaces.reminders);
      expect(GoalsReminderIds.first, 132000);
      expect(GoalsReminderIds.last, 132999);
      expect(GoalsReminderIds.of(0), 132000);
      expect(GoalsReminderIds.of(999), 132999);
      expect(() => GoalsReminderIds.of(1000), throwsRangeError);
      expect(() => GoalsReminderIds.of(-1), throwsRangeError);
      expect(GoalsReminderIds.owns(131999), isFalse);
      expect(GoalsReminderIds.owns(133000), isFalse);
      // Blocks other features already use: Family 136000–136999, Travel
      // 138000–138999, Body 139800–139803.
      for (final foreign in [136000, 136999, 138000, 138999, 139800, 139803]) {
        expect(GoalsReminderIds.owns(foreign), isFalse, reason: '$foreign');
      }
    });
  });

  group('NotificationGoalsReminderScheduler', () {
    late FakeNotificationPlatform platform;
    late NotificationService service;
    late NotificationGoalsReminderScheduler scheduler;

    setUp(() {
      platform = FakeNotificationPlatform();
      service = NotificationService(platform, clock: () => _now);
      scheduler = NotificationGoalsReminderScheduler(
        notifications: service,
        texts: () => (group: 'Money', name: 'Due dates', description: 'Debts and recurring payments'),
      );
    });

    test('schedules its block on a quiet channel and leaves other features alone', () async {
      // Another feature's reminder in the same namespace.
      final foreign = NotificationGoalsReminderScheduler.requestFor(
        _notice(136005, DateTime(2026, 10, 3, 8), ref: 'family'),
      );
      await service.sync(NotificationNamespaces.reminders, [foreign], keep: (id) => GoalsReminderIds.owns(id));
      expect(platform.scheduled.keys, [136005]);

      await scheduler.replaceAll([
        _notice(GoalsReminderIds.of(0), DateTime(2026, 9, 30, 9)),
        _notice(GoalsReminderIds.of(1), DateTime(2026, 10, 1, 9)),
      ]);
      expect(platform.scheduled.keys.toSet(), {136005, 132000, 132001});
      final channel = platform.channels[NotificationGoalsReminderScheduler.channelId]!;
      expect(channel.importance, NotificationImportance.normal);
      expect(channel.name, 'Due dates');
      expect(platform.groups[NotificationGoalsReminderScheduler.groupId], 'Money');
      final r = platform.scheduled[132000]!;
      expect(r.request.at, DateTime(2026, 9, 30, 9));
      expect(r.request.title, 'Rent');
      expect(r.timing, NotificationTiming.inexactWhileIdle);

      // A new plan replaces only the goals block.
      await scheduler.replaceAll([_notice(GoalsReminderIds.of(0), DateTime(2026, 10, 1, 9))]);
      expect(platform.scheduled.keys.toSet(), {136005, 132000});
      expect(platform.scheduled[132000]!.request.at, DateTime(2026, 10, 1, 9));

      await scheduler.cancelAll();
      expect(platform.scheduled.keys, [136005]);
    });

    test('a tapped reminder routes to its debt or obligation', () {
      final n = _notice(GoalsReminderIds.of(4), DateTime(2026, 10, 1, 9), ref: 'debt-9');
      final debt = GoalsNotice(
        id: n.id,
        at: n.at,
        title: n.title,
        body: n.body,
        kind: DueReminderKind.debt,
        refId: 'debt-9',
      );
      NotificationTap tap(GoalsNotice x, {String? namespace, int? id}) => NotificationTap(
        id: id ?? x.id,
        namespace: namespace ?? GoalsReminderIds.namespace.name,
        data: x.data,
      );
      expect(GoalsReminderTaps.targetOf(tap(debt)), (kind: DueReminderKind.debt, id: 'debt-9'));
      expect(GoalsReminderTaps.targetOf(tap(n)), (kind: DueReminderKind.obligation, id: 'debt-9'));
      // Another feature's id or namespace is not ours.
      expect(GoalsReminderTaps.targetOf(tap(n, id: 136005)), isNull);
      expect(GoalsReminderTaps.targetOf(tap(n, namespace: 'meds')), isNull);
    });
  });
}
