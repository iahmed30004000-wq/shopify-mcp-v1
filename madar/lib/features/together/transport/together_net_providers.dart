/// Providers of the two-phone transports and [togetherTransportOverrides],
/// the app shell's one line to register them.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import '../../../core/db/encryption.dart' show FlutterSecretStore, SecretStore;
import '../../../core/notifications/notification_providers.dart';
import '../../../core/providers.dart' show databaseProvider;
import '../../home/home_providers.dart' show appForegroundProvider;
import '../data/together_providers.dart';
import '../domain/play_modes.dart';
import '../domain/player_profile.dart';
import '../protocol/transport.dart';
import 'device_store.dart';
import 'nearby/nearby_api.dart';
import 'nearby/nearby_permissions.dart';
import 'nearby/nearby_transport.dart';
import 'online/firebase_rtdb.dart';
import 'online/online_config.dart';
import 'online/online_rooms.dart';
import 'online/online_transport.dart';
import 'online/rtdb.dart';
import 'turn_alerts.dart';

/// Runs a system flow (a permission dialog, a settings page) so the app lock
/// treats it as the owner's own – the app shell's `lockSuspender(ref)`.
typedef TogetherSuspender = Future<T> Function<T>(Future<T> Function() action);

/// Google Nearby Connections (the plugin; tests override with a fake).
final nearbyApiProvider = Provider<NearbyApi>((ref) => PluginNearbyApi());

/// Nearby's runtime permissions.
final nearbyPermissionsProvider = Provider<NearbyPermissions>((ref) => const PermissionHandlerNearbyPermissions());

/// Where the online settings live: the Keystore-backed secure storage.
final togetherSecretsProvider = Provider<SecretStore>((ref) => const FlutterSecretStore());

final onlineConfigStoreProvider = Provider<OnlineConfigStore>(
  (ref) => OnlineConfigStore(ref.watch(togetherSecretsProvider)),
);

final onlineRoomLedgerProvider = Provider<OnlineRoomLedger>(
  (ref) => OnlineRoomLedger(ref.watch(togetherSecretsProvider)),
);

/// The entered Firebase project (null: none). Invalidated by the online-play
/// sheet when it saves or removes one.
final onlineConfigProvider = FutureProvider<OnlineConfig?>((ref) => ref.watch(onlineConfigStoreProvider).read());

/// Opens the database client (Firebase; tests: an in-memory database).
final rtdbClientFactoryProvider = Provider<RtdbClientFactory>((ref) => FirebaseRtdbClient.open);

final togetherDeviceStoreProvider = Provider<TogetherDeviceStore>(
  (ref) => TogetherDeviceStore(ref.watch(databaseProvider)),
);

/// This phone's player (null until chosen once).
final togetherDeviceSlotProvider = StreamProvider<PlayerSlot?>((ref) => ref.watch(togetherDeviceStoreProvider).watch());

/// "Your turn" alerts for two-phone sessions.
final togetherTurnAlertsProvider = Provider<TogetherTurnAlerts>(
  (ref) => TogetherTurnAlerts(
    notifications: ref.watch(notificationServiceProvider),
    foreground: ref.watch(appForegroundProvider),
  ),
);

/// Opens a [NearbyTransport] (idle: nothing is advertised or discovered
/// before "Play together").
final nearbyTransportFactoryProvider = Provider<TogetherTransportFactory>(
  (ref) =>
      (request) async => NearbyTransport(
        api: ref.read(nearbyApiProvider),
        permissions: ref.read(nearbyPermissionsProvider),
        request: request,
        foreground: ref.read(appForegroundProvider),
      ),
);

/// Opens an [OnlineTransport] (idle: Firebase starts only when a code is
/// created or typed, and only with online play on and a project entered).
final onlineTransportFactoryProvider = Provider<TogetherTransportFactory>(
  (ref) =>
      (request) async => OnlineTransport(
        request: request,
        ledger: ref.read(onlineRoomLedgerProvider),
        connect: () async {
          final settings = await ref.read(togetherRepositoryProvider).settings();
          final config = await ref.read(onlineConfigStoreProvider).read();
          if (!settings.onlineEnabled || config == null) throw const OnlineNotConfigured();
          return ref.read(rtdbClientFactoryProvider)(config);
        },
      ),
);

/// The app shell's registration of the two-phone transports – add
/// `...togetherTransportOverrides(suspender: lockSuspender)` to the root
/// `ProviderScope` overrides. [suspender] routes Nearby's permission dialogs
/// and settings pages through the app lock.
List<Override> togetherTransportOverrides({TogetherSuspender Function(Ref ref)? suspender}) => [
  togetherTransportFactoriesProvider.overrideWith(
    (ref) => {
      PlayMode.nearby: ref.watch(nearbyTransportFactoryProvider),
      PlayMode.online: ref.watch(onlineTransportFactoryProvider),
    },
  ),
  if (suspender != null)
    nearbyPermissionsProvider.overrideWith(
      (ref) => SuspendingNearbyPermissions(const PermissionHandlerNearbyPermissions(), suspender(ref)),
    ),
];
