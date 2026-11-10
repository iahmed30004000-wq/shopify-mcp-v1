import 'package:flutter/foundation.dart';
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
/// `notificationPlatformProvider` – the gate directly around the plugin (it
/// reads the tray with payloads), any other decorator outside it:
///
/// ```dart
/// notificationPlatformProvider.overrideWith(
///   (ref) => SuspendingNotificationPlatform(
///     gatedNotificationPlatform(ref, FlutterLocalNotificationsPlatform(backgroundHandler: …)),
///     lockSuspender(ref),
///   ),
/// ),
/// ```
///
/// Fails open: if the gate cannot be built, [inner] is returned as it is –
/// every alarm is still scheduled, only mutes are not enforced.
NotificationPlatform gatedNotificationPlatform(Ref ref, NotificationPlatform inner) {
  try {
    return GatedNotificationPlatform(inner, ref.watch(notificationGateProvider));
  } catch (e) {
    debugPrint('NotificationGate: unavailable (${e.runtimeType}); notifications pass straight through');
    return inner;
  }
}

/// The center's persisted state (inside the database gate).
final notificationCenterStoreProvider = Provider<NotificationCenterStore>(
  (ref) => NotificationCenterStore(ref.watch(repositoriesProvider).keyValues),
);

/// Loads the stored policy into a background isolate's gate
/// ([NotificationGate.background]) once its database is open – before it
/// re-plans anything (the medication tracker's answer handler). Never
/// sweeps (what is held lives in the app's own gate) and never throws: a
/// policy that cannot be read holds nothing back.
Future<void> loadStoredNotificationPolicy(NotificationGate gate, KeyValueRepository keyValues) async {
  try {
    await gate.setPolicy(await NotificationCenterStore(keyValues).policy(), sweep: false);
  } catch (e) {
    debugPrint('NotificationGate: the stored policy is unavailable (${e.runtimeType}); holding nothing back');
  }
}
