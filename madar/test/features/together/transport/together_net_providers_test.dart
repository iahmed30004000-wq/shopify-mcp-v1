// The app shell's registration of the two-phone transports: both modes are
// registered, and online play is inert – no database client is ever opened –
// while it is off or no Firebase project has been entered.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/encryption.dart' show MemorySecretStore;
import 'package:madar/core/providers.dart' show databaseProvider;
import 'package:madar/features/home/home_providers.dart' show appForegroundProvider;
import 'package:madar/features/together/pairing/pairing.dart';
import 'package:madar/features/together/together.dart';

import '../../../helpers/test_app.dart' show testDatabase;
import '../together_test_utils.dart';
import 'net_fakes.dart';

const _request = TransportRequest(mode: PlayMode.online, host: true, gameId: 'fourInARow');

PairingIdentity _ali() =>
    const PairingIdentity(slot: PlayerSlot.one, rawName: 'Ali', avatar: TogetherAvatar.constellation(3), colorIndex: 0);

void main() {
  late ProviderContainer container;
  late MemorySecretStore secrets;
  late FakeRtdb db;
  var opened = 0;
  late List<OnlineConfig> openedWith;

  setUp(() async {
    final database = testDatabase(seed: false);
    await database.customSelect('SELECT 1').get();
    addTearDown(database.close);
    secrets = MemorySecretStore();
    db = FakeRtdb();
    opened = 0;
    openedWith = [];
    final air = FakeNearbyAir();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        togetherSecretsProvider.overrideWithValue(secrets),
        appForegroundProvider.overrideWithValue(ValueNotifier(true)),
        nearbyApiProvider.overrideWithValue(air.phone('me')),
        nearbyPermissionsProvider.overrideWithValue(FakeNearbyPermissions()),
        rtdbClientFactoryProvider.overrideWithValue((config) async {
          opened++;
          openedWith.add(config);
          return db.client(uid: 'uid-me');
        }),
        ...togetherTransportOverrides(),
      ],
    );
    addTearDown(container.dispose);
  });

  test('both two-phone modes are registered; opening a transport touches no radio and no database', () async {
    final factories = container.read(togetherTransportFactoriesProvider);
    expect(factories.keys, containsAll([PlayMode.nearby, PlayMode.online]));
    final nearby = await factories[PlayMode.nearby]!(
      const TransportRequest(mode: PlayMode.nearby, host: true, gameId: 'fourInARow'),
    );
    final online = await factories[PlayMode.online]!(_request);
    await settle();
    expect(nearby, isA<NearbyTransport>());
    expect(online, isA<OnlineTransport>());
    nearby as NearbyTransport;
    online as OnlineTransport;
    expect(nearby.advertising, isFalse);
    expect(nearby.discovering, isFalse);
    expect(opened, 0, reason: 'Firebase is never started by opening the sheet');
    expect(nearby.pairing.value.phase, PairingPhase.idle);
    expect(online.pairing.value.phase, PairingPhase.idle);
    await nearby.close();
    await online.close();
  });

  test('online play off: "Create a code" asks for the setup and never opens Firebase', () async {
    // A project is entered, but the switch is off (the default).
    await OnlineConfigStore(secrets).write(
      OnlineConfig.tryCreate(
        apiKey: 'AIzaSyA1b2C3d4E5f6G7h8I9j0KlMnOpQrStUvW',
        appId: '1:123456789012:android:0123456789abcdef',
        projectId: 'madar-couple',
        databaseUrl: 'https://madar-couple-default-rtdb.firebaseio.com',
      )!,
    );
    final t = await container.read(togetherTransportFactoriesProvider)[PlayMode.online]!(_request) as OnlineTransport;
    addTearDown(t.close);
    await t.host(_ali());
    await settle();
    expect(t.pairing.value.phase, PairingPhase.needsSetup);
    expect(opened, 0);
    await t.join('123456', _ali());
    await settle();
    expect(t.pairing.value.phase, PairingPhase.needsSetup);
    expect(opened, 0);
  });

  test('online play on but no project entered: still the setup, still no Firebase', () async {
    final repo = container.read(togetherRepositoryProvider);
    await repo.saveSettings(const TogetherSettings(onlineEnabled: true));
    final t = await container.read(togetherTransportFactoriesProvider)[PlayMode.online]!(_request) as OnlineTransport;
    addTearDown(t.close);
    await t.host(_ali());
    await settle();
    expect(t.pairing.value.phase, PairingPhase.needsSetup);
    expect(opened, 0);
    expect(secrets.values.keys, isNot(contains(OnlineRoomLedger.key)));
  });

  test('on, with a project: Firebase opens once, with exactly the entered project, when a code is created', () async {
    final repo = container.read(togetherRepositoryProvider);
    await repo.saveSettings(const TogetherSettings(onlineEnabled: true));
    final config = OnlineConfig.tryCreate(
      apiKey: 'AIzaSyA1b2C3d4E5f6G7h8I9j0KlMnOpQrStUvW',
      appId: '1:123456789012:android:0123456789abcdef',
      projectId: 'madar-couple',
      databaseUrl: 'https://madar-couple-default-rtdb.firebaseio.com/',
    )!;
    await OnlineConfigStore(secrets).write(config);
    expect(jsonDecode(secrets.values[OnlineConfigStore.key]!), isA<Map<String, Object?>>());
    final t = await container.read(togetherTransportFactoriesProvider)[PlayMode.online]!(_request) as OnlineTransport;
    addTearDown(t.close);
    await t.host(_ali());
    await settle();
    expect(t.pairing.value.phase, PairingPhase.hosting);
    expect(opened, 1);
    expect(openedWith.single, config);
    expect(openedWith.single.databaseUrl, 'https://madar-couple-default-rtdb.firebaseio.com');
    final room = db.room(t.code!)!;
    expect(room.keys.toSet(), {'h', 'v', 'gm', 'c', 'x', 'ph'});
    expect(room['ph'], {'n': 'Ali', 'a': 'c3', 'k': 0});
  });
}
