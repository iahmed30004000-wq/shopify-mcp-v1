import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/repositories/repositories.dart';
import '../../../core/notifications/notification_platform.dart';
import '../domain/builtin_describers.dart';
import '../domain/describers.dart';
import 'center_store.dart';
import 'notification_gate.dart';

/// The center's clock (tests pin it).
final notificationCenterClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// The describers the center titles and groups notifications with – the
/// built-ins for every namespace; a feature contributes its own with
/// `ref.read(notificationDescribersProvider).register(MyDescriber())`.
final notificationDescribersProvider = Provider<NotificationDescriberRegistry>(
  (ref) => NotificationDescriberRegistry(builtInDescribers()),
);

/// The gate that enforces mutes, skips and snoozes. Created without the
/// database (the platform exists before unlock); the center loads the stored
/// policy into it. Wire it into the platform with [gatedNotificationPlatform].
final notificationGateProvider = Provider<NotificationGate>((ref) {
  final registry = ref.watch(notificationDescribersProvider);
  final gate = NotificationGate(groupOf: registry.groupOf, clock: ref.watch(notificationCenterClockProvider));
  ref.onDispose(gate.dispose);
  return gate;
});

/// Wraps the real notifications plugin so the center's mutes, skips and
/// snoozes are enforced for every feature. For the lead, in the override of
/// `notificationPlatformProvider`:
///
/// ```dart
/// notificationPlatformProvider.overrideWith(
///   (ref) => gatedNotificationPlatform(ref, SuspendingNotificationPlatform(…)),
/// ),
/// ```
NotificationPlatform gatedNotificationPlatform(Ref ref, NotificationPlatform inner) =>
    GatedNotificationPlatform(inner, ref.watch(notificationGateProvider));

/// The center's persisted state (inside the database gate).
final notificationCenterStoreProvider = Provider<NotificationCenterStore>(
  (ref) => NotificationCenterStore(ref.watch(repositoriesProvider).keyValues),
);
