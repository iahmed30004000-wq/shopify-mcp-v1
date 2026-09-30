// The shared `reminders` namespace (130000–139999) is split into blocks,
// one per feature, and every sync reconciles only its own: Money's due
// reminders, Family's digest and birthdays, the trackers', the travel
// documents' and Body's fasting notices. They must never overlap, stay
// inside the namespace, and each `owns` must agree with its bounds – an
// overlap would let one feature's sync cancel another's notifications.
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/features/body/body.dart' show BodyReminderIds;
import 'package:madar/features/custom_modules/custom_modules.dart' show CustomModuleReminderIds;
import 'package:madar/features/family/family.dart' show FamilyNotificationIds;
import 'package:madar/features/money/goals/goals.dart' show GoalsReminderIds;
import 'package:madar/features/travel/travel.dart' show TravelReminderIds;

typedef _Block = ({String name, NotificationNamespace ns, int first, int last, bool Function(int) owns});

void main() {
  final blocks = <_Block>[
    (
      name: 'money goals',
      ns: GoalsReminderIds.namespace,
      first: GoalsReminderIds.first,
      last: GoalsReminderIds.last,
      owns: GoalsReminderIds.owns,
    ),
    (
      name: 'family',
      ns: FamilyNotificationIds.namespace,
      first: FamilyNotificationIds.first,
      last: FamilyNotificationIds.last,
      owns: FamilyNotificationIds.owns,
    ),
    (
      name: 'custom modules',
      ns: CustomModuleReminderIds.namespace,
      first: CustomModuleReminderIds.first,
      last: CustomModuleReminderIds.last,
      owns: CustomModuleReminderIds.owns,
    ),
    (
      name: 'travel documents',
      ns: TravelReminderIds.namespace,
      first: TravelReminderIds.first,
      last: TravelReminderIds.last,
      owns: TravelReminderIds.owns,
    ),
    (
      name: 'body fasting',
      ns: BodyReminderIds.namespace,
      first: BodyReminderIds.first,
      last: BodyReminderIds.last,
      owns: BodyReminderIds.owns,
    ),
  ];

  test('every block lives in the shared reminders namespace', () {
    for (final b in blocks) {
      expect(b.ns, NotificationNamespaces.reminders, reason: b.name);
      expect(b.first, lessThanOrEqualTo(b.last), reason: b.name);
      expect(NotificationNamespaces.reminders.contains(b.first), isTrue, reason: b.name);
      expect(NotificationNamespaces.reminders.contains(b.last), isTrue, reason: b.name);
    }
  });

  test('the blocks are pairwise disjoint', () {
    for (var i = 0; i < blocks.length; i++) {
      for (var j = i + 1; j < blocks.length; j++) {
        final a = blocks[i], b = blocks[j];
        expect(a.last < b.first || b.last < a.first, isTrue, reason: '${a.name} and ${b.name} overlap');
        // …and no id is claimed by both.
        expect(a.owns(b.first) || a.owns(b.last) || b.owns(a.first) || b.owns(a.last), isFalse);
      }
    }
  });

  test('owns() agrees with each block\'s first and last id', () {
    for (final b in blocks) {
      expect(b.owns(b.first), isTrue, reason: b.name);
      expect(b.owns(b.last), isTrue, reason: b.name);
      expect(b.owns(b.first - 1), isFalse, reason: b.name);
      expect(b.owns(b.last + 1), isFalse, reason: b.name);
    }
  });

  test('the documented blocks: 132xxx, 136xxx, 137xxx, 138xxx and 139800–139803', () {
    expect((GoalsReminderIds.first, GoalsReminderIds.last), (132000, 132999));
    expect((FamilyNotificationIds.first, FamilyNotificationIds.last), (136000, 136999));
    expect((FamilyNotificationIds.digestFirst, FamilyNotificationIds.digestLast), (136000, 136099));
    expect((FamilyNotificationIds.birthdayFirst, FamilyNotificationIds.birthdayLast), (136100, 136999));
    expect((CustomModuleReminderIds.first, CustomModuleReminderIds.last), (137000, 137999));
    expect((TravelReminderIds.first, TravelReminderIds.last), (138000, 138999));
    expect((BodyReminderIds.first, BodyReminderIds.last), (139800, 139803));
    expect(BodyReminderIds.goal, BodyReminderIds.first);
  });

  test('the other namespaces never reach into reminders', () {
    for (final ns in NotificationNamespaces.all) {
      if (ns == NotificationNamespaces.reminders) continue;
      final r = NotificationNamespaces.reminders;
      expect(ns.last < r.first || r.last < ns.first, isTrue, reason: ns.name);
    }
  });
}
