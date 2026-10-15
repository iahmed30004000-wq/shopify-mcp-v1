import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/notifications/notification_models.dart';
import 'package:madar/features/body/domain/body_reminder_plan.dart' show BodyReminderIds;
import 'package:madar/features/custom_modules/domain/module_reminders.dart';
import 'package:madar/features/family/domain/family_reminders.dart';
import 'package:madar/features/money/goals/data/goals_notifications.dart' show GoalsReminderIds;
import 'package:madar/features/nutrition/nutrition.dart';
import 'package:madar/features/travel/domain/document_reminders.dart';

MealSlot _slot(String id, String name, int minutes, {List<int> weekdays = const [], bool remind = true, List<PlannedFood> foods = const []}) =>
    MealSlot(id: id, planId: 'p1', name: name, timeMinutes: minutes, weekdays: weekdays, remind: remind, foods: foods);

MealPlan _plan(List<MealSlot> slots, {bool active = true}) =>
    MealPlan(id: 'p1', name: 'خطتي', active: active, slots: slots);

void main() {
  group('the id block', () {
    test('owns 139000–139499 of the reminders namespace', () {
      expect(MealReminderIds.namespace, NotificationNamespaces.reminders);
      expect(MealReminderIds.first, 139000);
      expect(MealReminderIds.last, 139499);
      expect(MealReminderIds.of(0, 0), 139000);
      expect(MealReminderIds.of(2, MealReminderIds.perDay - 1), lessThanOrEqualTo(139499));
      expect(MealReminderIds.owns(139000), isTrue);
      expect(MealReminderIds.owns(139499), isTrue);
      expect(MealReminderIds.owns(138999), isFalse);
      expect(MealReminderIds.owns(139500), isFalse);
      expect(() => MealReminderIds.of(MealReminderIds.days, 0), throwsRangeError);
      expect(() => MealReminderIds.of(0, MealReminderIds.perDay), throwsRangeError);
    });

    test('collides with no other feature\'s block', () {
      for (var id = MealReminderIds.first; id <= MealReminderIds.last; id++) {
        expect(GoalsReminderIds.owns(id), isFalse, reason: '$id');
        expect(FamilyNotificationIds.owns(id), isFalse, reason: '$id');
        expect(CustomModuleReminderIds.owns(id), isFalse, reason: '$id');
        expect(TravelReminderIds.owns(id), isFalse, reason: '$id');
        expect(BodyReminderIds.owns(id), isFalse, reason: '$id');
      }
      // And the other way round: no foreign id falls inside the block.
      for (final foreign in [132000, 132999, 136000, 136999, 137000, 137999, 138000, 138999, 139800, 139803, 160000, 170000]) {
        expect(MealReminderIds.owns(foreign), isFalse, reason: '$foreign');
      }
    });

    test('each day has its own slice, so a slot keeps one id per day', () {
      expect(MealReminderIds.of(1, 0) - MealReminderIds.of(0, 0), MealReminderIds.perDay);
      expect(MealReminderIds.days, 7);
      expect(MealReminderIds.perDay, 71);
    });
  });

  group('MealReminderPlanner', () {
    final now = DateTime(2026, 10, 10, 7); // Saturday 07:00

    test('plans only the slots whose reminder is on, from now forward', () {
      final plan = _plan([
        _slot('s1', 'فطور', 8 * 60, foods: [const PlannedFood(id: 'pf1', name: 'شوفان')]),
        _slot('s2', 'غدا', 13 * 60, remind: false),
        _slot('s3', 'عشا', 6 * 60), // already past today
      ]);
      final notices = MealReminderPlanner.plan(plan: plan, now: now);
      // Today's breakfast, then the next two days' breakfast and dinner.
      expect(notices.where((n) => n.slotId == 's2'), isEmpty);
      expect(notices.first.at, DateTime(2026, 10, 10, 8));
      expect(notices.first.slotName, 'فطور');
      expect(notices.first.timeLabel, '08:00');
      expect(notices.first.foods, ['شوفان']);
      expect(notices.map((n) => n.at).take(5), [
        DateTime(2026, 10, 10, 8),
        DateTime(2026, 10, 11, 6),
        DateTime(2026, 10, 11, 8),
        DateTime(2026, 10, 12, 6),
        DateTime(2026, 10, 12, 8),
      ]);
      expect(notices, hasLength(1 + 2 * 6), reason: 'today\'s breakfast plus two meals a day for six days');
      expect(notices.map((n) => n.id).toSet(), hasLength(notices.length));
      expect(notices.every((n) => MealReminderIds.owns(n.id)), isTrue);
    });

    test('a weekday slot is planned only on its weekday, anywhere in the week ahead', () {
      final plan = _plan([_slot('s1', 'غدا الجمعة', 13 * 60, weekdays: [5])]);
      expect(MealReminderPlanner.plan(plan: plan, now: now, days: 3), isEmpty,
          reason: '10–12 October 2026 are Sat, Sun, Mon');
      final week = MealReminderPlanner.plan(plan: plan, now: now);
      expect(week.single.at, DateTime(2026, 10, 16, 13));
      // Asking for more days than the block holds never overflows it.
      final asked = MealReminderPlanner.plan(plan: plan, now: now, days: 90);
      expect(asked.every((n) => MealReminderIds.owns(n.id)), isTrue);
      expect(asked, hasLength(1));
    });

    test('a draft plan reminds of nothing', () {
      final draft = _plan([_slot('s1', 'فطور', 8 * 60)], active: false);
      expect(MealReminderPlanner.plan(plan: draft, now: now), isEmpty);
      expect(MealReminderPlanner.plan(plan: MealPlan.none, now: now), isEmpty);
    });

    test('a plan with no reminding slot cancels everything', () {
      final plan = _plan([_slot('s1', 'فطور', 8 * 60, remind: false)]);
      expect(MealReminderPlanner.plan(plan: plan, now: now), isEmpty);
    });
  });

  test('the recording scheduler keeps what would have been shown', () async {
    final scheduler = RecordingMealReminderScheduler();
    final plan = _plan([_slot('s1', 'فطور', 8 * 60)]);
    final notices = MealReminderPlanner.plan(plan: plan, now: DateTime(2026, 10, 10, 7));
    await scheduler.replaceAll(notices);
    expect(scheduler.syncs, 1);
    expect(scheduler.current, notices);
    await scheduler.cancelAll();
    expect(scheduler.current, isEmpty);
    expect(await scheduler.ensurePermission(), isTrue);
    expect(scheduler.permissionRequests, 1);
  });
}
