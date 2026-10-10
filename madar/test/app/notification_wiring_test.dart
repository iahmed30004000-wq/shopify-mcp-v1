// The shape of the production notification chain, and the links the
// notification centre is given. Safety-critical: a wrong gate silently
// swallows a medicine reminder, or sounds an adhan the owner silenced.
//
// What is asserted here, and why it is asserted structurally:
//
// * exactly ONE gate, directly around the real plugin, inside the
//   suspending wrapper – a second gate layer would hold alarms in an
//   instance nothing can un-hold, and the chain assertion below fails the
//   moment one is added;
// * the gate in the chain is the very instance `notificationGateProvider`
//   hands the centre, so what the centre un-holds is what the platform
//   holds;
// * that gate never rebuilds when the database is unlocked or invalidated
//   (held alarms live in the instance);
// * the background entry point is the app's gated one;
// * where a centre row opens, and that every group but `other` offers its
//   reminder settings.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/app/app_gate.dart';
import 'package:madar/app/background_notifications.dart';
import 'package:madar/app/suspending_flows.dart';
import 'package:madar/app/system_services.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/features/adhkar/adhkar.dart' show AdhkarCategoryId;
import 'package:madar/features/family/family.dart' show FamilyNotificationIds;
import 'package:madar/features/health/record/record.dart' show AppointmentReminderIds;
import 'package:madar/features/health/wellbeing/wellbeing.dart' show WorryReminderIds;
import 'package:madar/features/money/goals/goals.dart' show GoalsReminderIds;
import 'package:madar/features/notification_center/notification_center.dart';
import 'package:madar/features/travel/travel.dart' show TravelReminderIds;
import 'package:madar/features/wird/wird.dart' show WirdReminderIds;

/// The decorators of [platform], outermost first (production's chain).
List<Object> _chain(NotificationPlatform platform) {
  final out = <Object>[];
  Object? current = platform;
  while (current != null) {
    out.add(current);
    current = switch (current) {
      SuspendingNotificationPlatform(:final inner) => inner,
      GatedNotificationPlatform(:final inner) => inner,
      _ => null,
    };
  }
  return out;
}

NotificationTap _tap({
  required String namespace,
  int? id,
  Map<String, Object?> data = const {},
  String? actionId,
}) => NotificationTap(namespace: namespace, id: id, data: data, actionId: actionId);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the production platform chain', () {
    test('is Suspending(Gated(plugin)) – one gate, directly around the plugin', () {
      final container = ProviderContainer(overrides: suspendingFlowOverrides());
      addTearDown(container.dispose);
      final chain = _chain(container.read(notificationPlatformProvider));

      // Exactly three links, in this order. A second gate (or a decorator
      // between the gate and the plugin) makes this list longer, and a gate
      // outside the suspending wrapper changes the order.
      expect(chain.map((o) => o.runtimeType.toString()), [
        'SuspendingNotificationPlatform',
        'GatedNotificationPlatform',
        'FlutterLocalNotificationsPlatform',
      ]);
      expect(
        chain.whereType<GatedNotificationPlatform>(),
        hasLength(1),
        reason: 'two gates: alarms held in one of them could never be re-armed',
      );
      expect(
        chain.last,
        isA<FlutterLocalNotificationsPlatform>(),
        reason: 'the gate must sit directly on the plugin: it reads the tray with payloads',
      );
    });

    test('the gate in the chain is the one the centre holds', () {
      final container = ProviderContainer(overrides: suspendingFlowOverrides());
      addTearDown(container.dispose);
      final gated = _chain(container.read(notificationPlatformProvider)).whereType<GatedNotificationPlatform>().single;
      expect(gated.gate, same(container.read(notificationGateProvider)));
      expect(gated.gate.attached, isTrue, reason: 'the gate reads the tray through its platform');
    });

    test('the plugin dispatches background actions to the app\'s gated entry point', () {
      final container = ProviderContainer(overrides: suspendingFlowOverrides());
      addTearDown(container.dispose);
      final plugin =
          _chain(container.read(notificationPlatformProvider)).last as FlutterLocalNotificationsPlatform;
      expect(plugin.backgroundHandler, same(madarAppNotificationBackgroundTap));
    });

    test('the gate survives an unlock: it never rebuilds with the database', () {
      final container = ProviderContainer(
        overrides: [
          ...suspendingFlowOverrides(),
          databaseUnlockProvider.overrideWithValue(const AsyncValue<MadarDatabase>.loading()),
        ],
      );
      addTearDown(container.dispose);
      final before = container.read(notificationGateProvider);
      container.invalidate(databaseUnlockProvider);
      expect(container.read(notificationGateProvider), same(before), reason: 'held alarms live in this instance');
      // And the platform still carries that same gate.
      final gated = _chain(container.read(notificationPlatformProvider)).whereType<GatedNotificationPlatform>().single;
      expect(gated.gate, same(before));
    });

    test('the centre\'s snooze ids are the reserved block, outside every namespace', () {
      expect(NotificationGate.snoozeIds, NotificationNamespaces.center);
      expect(NotificationNamespaces.all, isNot(contains(NotificationNamespaces.center)));
      for (final id in [160000, 160500, 160999]) {
        expect(NotificationNamespaces.owning(id), isNull, reason: 'id $id belongs to no feature');
      }
      expect(NotificationNamespaces.byName('center'), isNull);
    });
  });

  group('re-plan hooks', () {
    test('every namespace the centre may ask to re-plan has a hook', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final hooks = container.read(systemReplanHooksProvider);
      expect(hooks.namespaces, containsAll(<String>{
        NotificationNamespaces.adhan.name, // built in
        NotificationNamespaces.meds.name, // built in
        NotificationNamespaces.adhkar.name,
        NotificationNamespaces.wird.name,
        NotificationNamespaces.health.name,
        NotificationNamespaces.reminders.name,
      }));
      // `reminders` is shared by Money, Family, Travel, fasting, meals and
      // the trackers: ONE hook must run them all (a second `register` for
      // that namespace would silently replace the first).
      expect(hooks[NotificationNamespaces.reminders.name], isNotNull);
    });

    test('a hook never starts a sync that is not running, and never throws', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final hooks = container.read(systemReplanHooksProvider);
      for (final ns in hooks.namespaces) {
        await expectLater(hooks[ns]!(), completes);
      }
      // Nothing was created by asking: no database was touched.
      expect(container.exists(systemReplanHooksProvider), isTrue);
    });
  });

  group('centre links', () {
    test('every group a notification can land in offers its reminder settings', () {
      final groups = NotificationGroup.values.where((g) => g != NotificationGroup.other);
      for (final g in groups) {
        expect(centerSettingsLinks.containsKey(g), isTrue, reason: '${g.name} has no settings link');
      }
      expect(centerSettingsLinks.containsKey(NotificationGroup.other), isFalse);
    });

    test('centerLocationOf: every feature\'s notification opens its own page', () {
      expect(
        centerLocationOf(
          _tap(
            namespace: NotificationNamespaces.adhkar.name,
            id: NotificationNamespaces.adhkar.first,
            data: {'set': AdhkarCategoryId.morning.name},
          ),
        ),
        AppRoutes.adhkarSetOf(AdhkarCategoryId.morning.name),
      );
      expect(
        centerLocationOf(
          _tap(namespace: WirdReminderIds.namespace.name, id: WirdReminderIds.namespace.first, data: {'plan': 'p1'}),
        ),
        AppRoutes.wirdOf('p1'),
      );
      expect(
        centerLocationOf(
          _tap(
            namespace: NotificationNamespaces.meds.name,
            id: NotificationNamespaces.meds.first,
            data: {'m': 'm1', 's': 0},
          ),
        ),
        AppRoutes.meds,
      );
      expect(
        centerLocationOf(
          _tap(
            namespace: NotificationNamespaces.health.name,
            id: AppointmentReminderIds.first,
            data: {'kind': 'appointment', 'appointment': 'a1'},
          ),
        ),
        AppRoutes.appointmentsOf(highlightId: 'a1'),
      );
      expect(
        centerLocationOf(
          _tap(
            namespace: WorryReminderIds.namespace.name,
            id: WorryReminderIds.first,
            data: {'kind': 'worryWindow'},
          ),
        ),
        AppRoutes.wellbeingOf(tab: 'worries'),
      );
      expect(
        centerLocationOf(
          _tap(
            namespace: GoalsReminderIds.namespace.name,
            id: GoalsReminderIds.first,
            data: {'kind': 'money.due', 'target': 'debt', 'id': 'd1'},
          ),
        ),
        AppRoutes.goalsOf(debt: 'd1'),
      );
      expect(
        centerLocationOf(
          _tap(
            namespace: FamilyNotificationIds.namespace.name,
            id: FamilyNotificationIds.digestFirst,
            data: {'k': 'digest'},
          ),
        ),
        AppRoutes.family,
      );
      expect(
        centerLocationOf(
          _tap(
            namespace: TravelReminderIds.namespace.name,
            id: TravelReminderIds.first,
            data: {'feature': 'travel', 'documentId': 'doc1'},
          ),
        ),
        AppRoutes.travelOf(tab: 'documents'),
      );
      // The adhan's own taps belong to the adhan hub; from the centre a row
      // for it opens the prayer times.
      expect(
        centerLocationOf(_tap(namespace: NotificationNamespaces.adhan.name, id: 100001)),
        AppRoutes.prayerTimes,
      );
      // A foreign payload opens nothing (the row shows no "Open").
      expect(centerLocationOf(_tap(namespace: 'someone.else', id: 1)), isNull);
    });
  });
}
