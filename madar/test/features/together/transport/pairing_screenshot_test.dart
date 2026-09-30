@Tags(['screenshot'])
// Rendering glass + cosmos shaders can take minutes per shot on a loaded box.
@Timeout(Duration(minutes: 30))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/encryption.dart' show MemorySecretStore;
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/features/together/pairing/pairing.dart';
import 'package:madar/features/together/together.dart';

import '../../../helpers/screenshot_harness.dart';
import '../together_test_utils.dart';
import 'net_fakes.dart';

const _dir = 'together/pairing';
const _game = TogetherGames.fourInARow;

class _Host extends StatefulWidget {
  const _Host(this.open);

  final Future<void> Function(BuildContext context) open;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(widget.open(context)));
  }

  @override
  Widget build(BuildContext context) => const MadarScaffold(title: '', body: SizedBox.shrink());
}

Future<void> _loadEmojiFont() async {
  for (final path in [
    '/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf',
    '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/sdk/flutter'}/engine/src/flutter/txt/third_party/fonts/NotoColorEmoji.ttf',
  ]) {
    final f = File(path);
    if (!f.existsSync()) continue;
    final loader = FontLoader('NotoColorEmoji')..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    await loader.load();
    return;
  }
}

PairingIdentity _sara() =>
    const PairingIdentity(slot: PlayerSlot.one, rawName: 'سارة', avatar: TogetherAvatar.emoji('🌙'), colorIndex: 1);

PairingIdentity _saraEn() =>
    const PairingIdentity(slot: PlayerSlot.one, rawName: 'Sara', avatar: TogetherAvatar.emoji('🌙'), colorIndex: 1);

final _config = OnlineConfig.tryCreate(
  apiKey: 'AIzaSyA1b2C3d4E5f6G7h8I9j0KlMnOpQrStUvW',
  appId: '1:123456789012:android:0123456789abcdef',
  projectId: 'madar-couple',
  databaseUrl: 'https://madar-couple-default-rtdb.firebaseio.com',
)!;

Future<void> _named(TogetherRepository repo) async {
  await repo.saveProfile(TogetherProfile.defaults(PlayerSlot.one).copyWith(name: 'علي', title: PlayerTitle.strategist));
  await repo.saveProfile(
    TogetherProfile.defaults(PlayerSlot.two).copyWith(name: 'سارة', avatar: const TogetherAvatar.emoji('🌙')),
  );
}

Future<void> _namedEn(TogetherRepository repo) async {
  await repo.saveProfile(TogetherProfile.defaults(PlayerSlot.one).copyWith(name: 'Ali'));
  await repo.saveProfile(TogetherProfile.defaults(PlayerSlot.two).copyWith(name: 'Sara', avatar: const TogetherAvatar.emoji('🌙')));
}

void main() {
  setUpAll(_loadEmojiFont);

  Future<void> shot(
    WidgetTester tester,
    String name,
    Future<void> Function(BuildContext context) open, {
    MadarThemeId theme = MadarThemeId.lapis,
    Locale locale = const Locale('ar'),
    List<Override> overrides = const [],
    Future<void> Function(TogetherRepository repo)? seed,
    Future<void> Function(WidgetTester tester)? drive,
    int trailingFrames = 12,
  }) async {
    final (app, _) = await buildTogetherApp(
      tester,
      home: _Host(open),
      theme: theme,
      locale: locale,
      overrides: overrides,
      seed: seed,
    );
    await captureScreen(tester, app, '$_dir/$name', beforeCapture: drive, trailingFrames: trailingFrames);
    await tester.pumpWidget(const SizedBox());
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
  }

  // ------------------------------------------------------------------ nearby

  ({FakeNearbyAir air, FakeNearbyApi mine, FakeNearbyPermissions perms, Override override}) nearby({
    NearbyPermissionStatus status = NearbyPermissionStatus.granted,
    NearbyPermissionNeed need = NearbyPermissionNeed.nearbyDevices,
  }) {
    final air = FakeNearbyAir();
    final mine = air.phone('me');
    final perms = FakeNearbyPermissions(status: status, needValue: need);
    return (
      air: air,
      mine: mine,
      perms: perms,
      override: togetherTransportFactoriesProvider.overrideWithValue({
        PlayMode.nearby: (req) async => NearbyTransport(
          api: mine,
          permissions: perms,
          request: req,
          autoConnectDelay: const Duration(seconds: 30),
        ),
      }),
    );
  }

  NearbyTransport other(FakeNearbyAir air, String label) => NearbyTransport(
    api: air.phone(label),
    permissions: FakeNearbyPermissions(),
    request: const TransportRequest(mode: PlayMode.nearby, host: true, gameId: 'fourInARow'),
    autoConnectDelay: const Duration(seconds: 30),
  );

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(ValueKey(key)));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  testWidgets('nearby – idle, Arabic, lapis', (tester) async {
    final n = nearby();
    await shot(
      tester,
      'nearby_idle_ar',
      (c) => showPairingSheet(c, game: _game, mode: PlayMode.nearby),
      overrides: [n.override],
      seed: _named,
    );
  });

  testWidgets('nearby – permission rationale, English, pearl', (tester) async {
    final n = nearby(status: NearbyPermissionStatus.needed, need: NearbyPermissionNeed.nearbyDevicesAndLocation);
    await shot(
      tester,
      'nearby_permission_en_pearl',
      (c) => showPairingSheet(c, game: _game, mode: PlayMode.nearby),
      locale: const Locale('en'),
      theme: MadarThemeId.pearl,
      overrides: [n.override],
      seed: _namedEn,
      drive: (tester) => tap(tester, 'together-pair-play'),
    );
  });

  testWidgets('nearby – permission refused for good, Arabic, desert', (tester) async {
    final n = nearby(status: NearbyPermissionStatus.permanentlyDenied);
    await shot(
      tester,
      'nearby_denied_ar_desert',
      (c) => showPairingSheet(c, game: _game, mode: PlayMode.nearby),
      theme: MadarThemeId.desert,
      overrides: [n.override],
      seed: _named,
      drive: (tester) => tap(tester, 'together-pair-play'),
    );
  });

  testWidgets('nearby – searching, two phones found, Arabic, emerald', (tester) async {
    final n = nearby();
    await shot(
      tester,
      'nearby_searching_ar_emerald',
      (c) => showPairingSheet(c, game: _game, mode: PlayMode.nearby),
      theme: MadarThemeId.emerald,
      overrides: [n.override],
      seed: _named,
      drive: (tester) async {
        await tap(tester, 'together-pair-play');
        for (final name in ['سارة', 'هدى']) {
          final p = n.air.phone(name);
          await p.startAdvertising(name: name, serviceId: NearbyService.idFor('fourInARow'));
        }
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 60));
        }
      },
    );
  });

  testWidgets('nearby – confirm the four digits, Arabic, lapis', (tester) async {
    final n = nearby();
    late NearbyTransport partner;
    await shot(
      tester,
      'nearby_confirm_ar',
      (c) => showPairingSheet(c, game: _game, mode: PlayMode.nearby),
      overrides: [n.override],
      seed: _named,
      drive: (tester) async {
        await tap(tester, 'together-pair-play');
        partner = other(n.air, 'sara');
        await partner.playTogether(_sara());
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 60));
        }
        final found = partner.pairing.value.found;
        if (found.isNotEmpty) partner.connectTo(found.first.id);
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 60));
        }
      },
    );
    await partner.close();
  });

  testWidgets('nearby – confirm, English, aurora', (tester) async {
    final n = nearby();
    late NearbyTransport partner;
    await shot(
      tester,
      'nearby_confirm_en_aurora',
      (c) => showPairingSheet(c, game: _game, mode: PlayMode.nearby),
      locale: const Locale('en'),
      theme: MadarThemeId.aurora,
      overrides: [n.override],
      seed: _namedEn,
      drive: (tester) async {
        await tap(tester, 'together-pair-play');
        partner = other(n.air, 'sara');
        await partner.playTogether(_saraEn());
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 60));
        }
        final found = partner.pairing.value.found;
        if (found.isNotEmpty) partner.connectTo(found.first.id);
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 60));
        }
      },
    );
    await partner.close();
  });

  testWidgets('nearby – connected, Arabic, aurora', (tester) async {
    final n = nearby();
    late NearbyTransport partner;
    await shot(
      tester,
      'nearby_connected_ar_aurora',
      (c) => showPairingSheet(c, game: _game, mode: PlayMode.nearby),
      theme: MadarThemeId.aurora,
      overrides: [n.override],
      seed: _named,
      trailingFrames: 3,
      drive: (tester) async {
        await tap(tester, 'together-pair-play');
        partner = other(n.air, 'sara');
        await partner.playTogether(_sara());
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 60));
        }
        final found = partner.pairing.value.found;
        if (found.isNotEmpty) partner.connectTo(found.first.id);
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 60));
        }
        await tap(tester, 'together-pair-match');
        await partner.confirmToken();
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 60));
        }
      },
    );
    await partner.close();
  });

  // ------------------------------------------------------------------ online

  ({FakeRtdb db, List<Override> overrides}) online({bool configured = true}) {
    final db = FakeRtdb();
    final secrets = MemorySecretStore({if (configured) OnlineConfigStore.key: jsonEncode(_config.toJson())});
    return (
      db: db,
      overrides: [
        togetherSecretsProvider.overrideWithValue(secrets),
        rtdbClientFactoryProvider.overrideWithValue((config) async => db.client(uid: 'uid-test')),
        togetherTransportFactoriesProvider.overrideWithValue({
          PlayMode.online: (req) async => OnlineTransport(
            request: req,
            connect: () async => db.client(uid: 'uid-me'),
            random: ScriptedRandom([382915]),
          ),
        }),
      ],
    );
  }

  Future<void> onlineOn(TogetherRepository repo) async {
    await _named(repo);
    await repo.saveSettings(const TogetherSettings(onlineEnabled: true));
  }

  Future<void> onlineOnEn(TogetherRepository repo) async {
    await _namedEn(repo);
    await repo.saveSettings(const TogetherSettings(onlineEnabled: true));
  }

  testWidgets('online – a code and its QR, Arabic, lapis', (tester) async {
    final o = online();
    await shot(
      tester,
      'online_code_ar',
      (c) => showPairingSheet(c, game: _game, mode: PlayMode.online),
      overrides: o.overrides,
      seed: onlineOn,
      drive: (tester) => tap(tester, 'together-pair-create'),
    );
  });

  testWidgets('online – a code, English, pearl', (tester) async {
    final o = online();
    await shot(
      tester,
      'online_code_en_pearl',
      (c) => showPairingSheet(c, game: _game, mode: PlayMode.online),
      locale: const Locale('en'),
      theme: MadarThemeId.pearl,
      overrides: o.overrides,
      seed: onlineOnEn,
      drive: (tester) => tap(tester, 'together-pair-create'),
    );
  });

  testWidgets('online – the partner asks to join, Arabic, emerald', (tester) async {
    final o = online();
    late OnlineTransport partner;
    await shot(
      tester,
      'online_request_ar_emerald',
      (c) => showPairingSheet(c, game: _game, mode: PlayMode.online),
      theme: MadarThemeId.emerald,
      overrides: o.overrides,
      seed: onlineOn,
      drive: (tester) async {
        await tap(tester, 'together-pair-create');
        partner = OnlineTransport(
          request: const TransportRequest(mode: PlayMode.online, host: false, gameId: 'fourInARow'),
          connect: () async => o.db.client(uid: 'uid-sara'),
        );
        await partner.join('482915', _sara());
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 60));
        }
      },
    );
    await partner.close();
  });

  testWidgets('online – typing a code, English, desert', (tester) async {
    final o = online();
    await shot(
      tester,
      'online_join_en_desert',
      (c) => showPairingSheet(c, game: _game, mode: PlayMode.online),
      locale: const Locale('en'),
      theme: MadarThemeId.desert,
      overrides: o.overrides,
      seed: onlineOnEn,
      drive: (tester) async {
        await tester.tap(find.text('Enter a code'));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.enterText(find.byKey(const ValueKey('together-pair-code-field')), '482 915');
        await tester.pump(const Duration(milliseconds: 300));
        FocusManager.instance.primaryFocus?.unfocus();
      },
    );
  });

  testWidgets('online – off: set it up first, Arabic, desert', (tester) async {
    final o = online(configured: false);
    await shot(
      tester,
      'online_off_ar_desert',
      (c) => showPairingSheet(c, game: _game, mode: PlayMode.online),
      theme: MadarThemeId.desert,
      overrides: o.overrides,
      seed: _named,
    );
  });

  testWidgets('online play settings – Arabic, aurora', (tester) async {
    final o = online();
    await shot(
      tester,
      'online_settings_ar_aurora',
      showOnlinePlaySheet,
      theme: MadarThemeId.aurora,
      overrides: o.overrides,
      seed: onlineOn,
    );
  });

  testWidgets('online play settings – English, lapis, with errors', (tester) async {
    final o = online(configured: false);
    await shot(
      tester,
      'online_settings_en_errors',
      showOnlinePlaySheet,
      locale: const Locale('en'),
      overrides: o.overrides,
      seed: _namedEn,
      drive: (tester) async {
        final key = find.byKey(const ValueKey('together-online-apiKey'));
        await tester.ensureVisible(key);
        await tester.enterText(key, 'AIza-not-a-real-key');
        await tester.tap(find.byKey(const ValueKey('together-online-save')));
        await tester.pump(const Duration(milliseconds: 300));
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.drag(find.byType(SingleChildScrollView).last, const Offset(0, -420));
      },
    );
  });
}
