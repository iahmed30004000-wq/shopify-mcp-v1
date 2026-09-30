import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/encryption.dart' show MemorySecretStore;
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/core/i18n/formatters.dart' show Digits;
import 'package:madar/core/sound/sound_api.dart' show Haptic, Sfx, sfxHaptics;
import 'package:madar/features/together/pairing/pairing.dart';
import 'package:madar/features/together/together.dart';

import '../../../helpers/test_app.dart' show usePhoneSurface;
import '../together_test_utils.dart';
import 'net_fakes.dart';

const _game = TogetherGames.fourInARow;
const _apiKey = 'AIzaSyA1b2C3d4E5f6G7h8I9j0KlMnOpQrStUvW';
const _appId = '1:123456789012:android:0123456789abcdef';
const _dbUrl = 'https://madar-couple-default-rtdb.firebaseio.com';

final _config = OnlineConfig.tryCreate(apiKey: _apiKey, appId: _appId, projectId: 'madar-couple', databaseUrl: _dbUrl)!;

/// Opens [open] over an empty page after the first frame.
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

/// Frames plus real time for the database streams.
Future<void> _pump(WidgetTester tester, [int frames = 8]) async {
  for (var i = 0; i < frames; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 2)));
    await tester.pump(const Duration(milliseconds: 60));
  }
}

/// Tears the app down and lets the transports' last timers run out.
Future<void> _finish(WidgetTester tester, [List<PairedLink?> links = const []]) async {
  for (final link in links) {
    if (link != null) unawaited(link.close());
  }
  await tester.pumpWidget(const SizedBox());
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

PairingIdentity _sara() =>
    const PairingIdentity(slot: PlayerSlot.one, rawName: 'Sara', avatar: TogetherAvatar.emoji('🌙'), colorIndex: 3);

class _Nearby {
  final FakeNearbyAir air = FakeNearbyAir();
  late final FakeNearbyApi mine = air.phone('me');
  late final FakeNearbyApi theirs = air.phone('them');
  final FakeNearbyPermissions perms = FakeNearbyPermissions();
  NearbyTransport? opened;

  NearbyTransport other() => NearbyTransport(
    api: theirs,
    permissions: FakeNearbyPermissions(),
    request: const TransportRequest(mode: PlayMode.nearby, host: true, gameId: 'fourInARow'),
    autoConnectDelay: Duration.zero,
  );

  Override get override => togetherTransportFactoriesProvider.overrideWithValue({
    PlayMode.nearby: (req) async => opened = NearbyTransport(
      api: mine,
      permissions: perms,
      request: req,
      autoConnectDelay: Duration.zero,
    ),
  });
}

class _Online {
  _Online({bool configured = true}) : secrets = MemorySecretStore({
    if (configured) OnlineConfigStore.key: jsonEncode(_config.toJson()),
  });

  final FakeRtdb db = FakeRtdb();
  final MemorySecretStore secrets;
  OnlineTransport? opened;

  OnlineTransport partner({required bool host}) => OnlineTransport(
    request: TransportRequest(mode: PlayMode.online, host: host, gameId: 'fourInARow'),
    connect: () async => db.client(uid: 'uid-sara'),
    random: ScriptedRandom([45678]),
  );

  List<Override> get overrides => [
    togetherSecretsProvider.overrideWithValue(secrets),
    rtdbClientFactoryProvider.overrideWithValue((config) async => db.client(uid: 'uid-test')),
    togetherTransportFactoriesProvider.overrideWithValue({
      PlayMode.online: (req) async => opened = OnlineTransport(
        request: req,
        connect: () async => db.client(uid: 'uid-me'),
        random: ScriptedRandom([23456]),
      ),
    }),
  ];
}

Future<TogetherTestEnv> _open(
  WidgetTester tester, {
  required Future<void> Function(BuildContext context) open,
  Locale locale = const Locale('ar'),
  List<Override> overrides = const [],
  bool onlineOn = false,
}) async {
  usePhoneSurface(tester);
  final (app, env) = await buildTogetherApp(
    tester,
    home: _Host(open),
    locale: locale,
    overrides: overrides,
    seed: onlineOn ? (repo) => repo.saveSettings(const TogetherSettings(onlineEnabled: true)) : null,
  );
  await tester.pumpWidget(app);
  await _pump(tester);
  return env;
}

void main() {
  group('two phones nearby', () {
    testWidgets('Arabic: play together → the same four digits → match → paired, the link handed over', (tester) async {
      final n = _Nearby();
      PairedLink? link;
      final env = await _open(
        tester,
        overrides: [n.override],
        open: (c) async => link = await showPairingSheet(c, game: _game, mode: PlayMode.nearby),
      );
      expect(find.text('هاتفان متجاوران'), findsOneWidget);
      expect(find.text('على هذا الهاتف'), findsOneWidget);
      expect(find.text('العبا معًا'), findsOneWidget);
      expect(n.mine.calls, isEmpty, reason: 'nothing before "Play together"');

      await tester.tap(find.byKey(const ValueKey('together-pair-play')));
      await _pump(tester);
      expect(find.text('نبحث عن الهاتف الآخر…'), findsOneWidget);
      expect(n.mine.advertising, isTrue);
      expect(n.mine.advertisingName, 'اللاعب ١', reason: 'the display name of this phone\'s player only');

      final other = n.other();
      await other.playTogether(_sara());
      await _pump(tester);
      final token = n.opened!.pairing.value.token!;
      expect(other.pairing.value.token, token);
      expect(find.byKey(const ValueKey('together-pair-token')), findsOneWidget);
      expect(find.text(Digits.toArabicIndic(token[0])), findsWidgets);
      expect(find.text('هل يظهر الرقم نفسه؟'), findsOneWidget);
      expect(find.textContaining('Sara'), findsOneWidget);
      expect(env.haptics.fired, contains(sfxHaptics[Sfx.notify]));

      await tester.tap(find.byKey(const ValueKey('together-pair-match')));
      await _pump(tester);
      expect(find.textContaining('بانتظار تأكيد'), findsOneWidget);
      await other.confirmToken();
      await _pump(tester);
      expect(find.textContaining('متصلان'), findsOneWidget);
      expect(env.haptics.fired, contains(Haptic.success));
      await tester.pump(PairingSheet.handOverDelay);
      await _pump(tester);
      expect(link, isNotNull);
      expect(link!.peer.name, 'Sara');
      expect(link!.identity.slot, PlayerSlot.one);
      expect(link!.role, isNot(other.role));
      expect(n.mine.advertising, isFalse);
      unawaited(other.close());
      await _finish(tester, [link]);
    });

    testWidgets('English: the rationale comes before Android\'s dialog; refused for good → settings', (tester) async {
      final n = _Nearby()..perms.status = NearbyPermissionStatus.needed;
      n.perms.afterRequest = NearbyPermissionStatus.permanentlyDenied;
      await _open(
        tester,
        locale: const Locale('en'),
        overrides: [n.override],
        open: (c) => showPairingSheet(c, game: _game, mode: PlayMode.nearby),
      );
      await tester.tap(find.byKey(const ValueKey('together-pair-play')));
      await _pump(tester);
      expect(find.text('Allow finding nearby devices'), findsOneWidget);
      expect(find.textContaining('“Nearby devices” permission'), findsOneWidget);
      expect(find.text('Only game state leaves the phone'), findsOneWidget);
      expect(n.perms.requests, 0);
      expect(n.mine.calls, isEmpty);

      await tester.tap(find.byKey(const ValueKey('together-pair-allow')));
      await _pump(tester);
      expect(n.perms.requests, 1);
      expect(find.text('Madar can\'t search without this permission'), findsOneWidget);
      expect(find.textContaining('App settings › Permissions'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('together-pair-settings')));
      await _pump(tester);
      expect(n.perms.appSettings, 1);
      expect(n.mine.calls, isEmpty);
      await _finish(tester);
    });

    testWidgets('English: location on Android 11 – the rationale says Madar never reads it', (tester) async {
      final n = _Nearby()
        ..perms.status = NearbyPermissionStatus.needed
        ..perms.needValue = NearbyPermissionNeed.location;
      await _open(
        tester,
        locale: const Locale('en'),
        overrides: [n.override],
        open: (c) => showPairingSheet(c, game: _game, mode: PlayMode.nearby),
      );
      await tester.tap(find.byKey(const ValueKey('together-pair-play')));
      await _pump(tester);
      expect(find.textContaining('Madar never reads your location'), findsOneWidget);
      expect(find.textContaining('“Nearby devices” permission'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('together-pair-allow')));
      await _pump(tester);
      expect(find.text('Looking for the other phone…'), findsOneWidget);
      await _finish(tester);
    });

    testWidgets('dismissing the sheet stops the radios; "this phone is" is remembered', (tester) async {
      final n = _Nearby();
      PairedLink? link;
      var closed = false;
      final env = await _open(
        tester,
        locale: const Locale('en'),
        overrides: [n.override],
        open: (c) async {
          link = await showPairingSheet(c, game: _game, mode: PlayMode.nearby);
          closed = true;
        },
      );
      await tester.tap(find.byKey(const ValueKey('together-pair-me-two')));
      await _pump(tester);
      expect(await tester.runAsync(() => TogetherDeviceStore(env.db).read()), PlayerSlot.two);
      await tester.tap(find.byKey(const ValueKey('together-pair-play')));
      await _pump(tester);
      expect(n.mine.advertisingName, 'Player 2');
      await tester.tap(find.text('Cancel'));
      await _pump(tester);
      await tester.pump(const Duration(seconds: 3));
      await _pump(tester);
      expect(closed, isTrue);
      expect(link, isNull);
      expect(n.mine.advertising, isFalse);
      expect(n.mine.discovering, isFalse);
      expect(n.mine.calls, contains('stopAllEndpoints'));
      await _finish(tester);
    });
  });

  group('two phones online', () {
    testWidgets('Arabic: create a code – digits and QR – the partner joins, accept, paired', (tester) async {
      final o = _Online();
      PairedLink? link;
      await _open(
        tester,
        overrides: o.overrides,
        onlineOn: true,
        open: (c) async => link = await showPairingSheet(c, game: _game, mode: PlayMode.online),
      );
      expect(find.text('إنشاء رمز'), findsWidgets);
      expect(o.db.writes, isEmpty);
      await tester.tap(find.byKey(const ValueKey('together-pair-create')));
      await _pump(tester);
      expect(find.byKey(const ValueKey('together-pair-code')), findsOneWidget);
      for (final d in '١٢٣٤٥٦'.split('')) {
        expect(find.text(d), findsWidgets);
      }
      expect(find.byType(TogetherQrView), findsOneWidget);
      expect(find.text('بانتظار انضمام الهاتف الآخر…'), findsOneWidget);
      expect(o.db.room('123456'), isNotNull);

      final guest = o.partner(host: false);
      await guest.join('123456', _sara());
      await _pump(tester);
      expect(find.textContaining('يطلب الانضمام'), findsOneWidget);
      expect(find.textContaining('Sara'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('together-pair-accept')));
      await _pump(tester);
      expect(guest.pairing.value.phase, PairingPhase.connected);
      await tester.pump(PairingSheet.handOverDelay);
      await _pump(tester);
      expect(link, isNotNull);
      expect(link!.role, SessionRole.host);
      expect(link!.peer.name, 'Sara');
      unawaited(guest.close());
      await _finish(tester, [link]);
    });

    testWidgets('English: type the code – Join is enabled at six digits – wait for the host', (tester) async {
      final o = _Online();
      PairedLink? link;
      await _open(
        tester,
        locale: const Locale('en'),
        overrides: o.overrides,
        onlineOn: true,
        open: (c) async => link = await showPairingSheet(c, game: _game, mode: PlayMode.online),
      );
      final host = o.partner(host: true);
      await host.host(_sara());
      await _pump(tester);
      final code = host.pairing.value.code!;

      await tester.tap(find.text('Enter a code'));
      await _pump(tester);
      await tester.enterText(find.byKey(const ValueKey('together-pair-code-field')), code.substring(0, 5));
      await _pump(tester);
      await tester.tap(find.byKey(const ValueKey('together-pair-join')));
      await _pump(tester);
      expect(host.pairing.value.phase, PairingPhase.hosting, reason: 'five digits: Join stays disabled');
      await tester.enterText(find.byKey(const ValueKey('together-pair-code-field')), '${code.substring(0, 3)} ${code.substring(3)}');
      await _pump(tester);
      await tester.tap(find.byKey(const ValueKey('together-pair-join')));
      await _pump(tester);
      expect(find.text('Waiting for ${'\u2068'}Sara${'\u2069'} to accept…'), findsOneWidget);
      await host.acceptGuest();
      await _pump(tester);
      await tester.pump(PairingSheet.handOverDelay);
      await _pump(tester);
      expect(link!.role, SessionRole.guest);
      unawaited(host.close());
      await _finish(tester, [link]);
    });

    testWidgets('English: online play off – the sheet offers the setup instead of a code', (tester) async {
      final o = _Online(configured: false);
      await _open(
        tester,
        locale: const Locale('en'),
        overrides: o.overrides,
        open: (c) => showPairingSheet(c, game: _game, mode: PlayMode.online),
      );
      expect(find.text('Online play is off'), findsOneWidget);
      expect(find.byKey(const ValueKey('together-pair-create')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('together-pair-setup')));
      await _pump(tester);
      expect(find.byType(OnlinePlaySheet), findsOneWidget);
      expect(o.db.writes, isEmpty);
      await _finish(tester);
    });

    testWidgets('Arabic: a wrong code says so, and "try again" returns to the code', (tester) async {
      final o = _Online();
      await _open(
        tester,
        overrides: o.overrides,
        onlineOn: true,
        open: (c) => showPairingSheet(c, game: _game, mode: PlayMode.online),
      );
      await tester.tap(find.text('إدخال رمز'));
      await _pump(tester);
      await tester.enterText(find.byKey(const ValueKey('together-pair-code-field')), '٩٩٩٩٩٩');
      await _pump(tester);
      await tester.tap(find.byKey(const ValueKey('together-pair-join')));
      await _pump(tester);
      expect(find.text('لا توجد غرفة مفتوحة بهذا الرمز'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('together-pair-again')));
      await _pump(tester);
      expect(find.byKey(const ValueKey('together-pair-code-field')), findsOneWidget);
      await _finish(tester);
    });
  });

  group('online play settings', () {
    testWidgets('English: validate, paste google-services.json, save securely, turn on, copy the rules, remove', (
      tester,
    ) async {
      final o = _Online(configured: false);
      String? clipboard = jsonEncode({
        'project_info': {'project_number': '123456789012', 'firebase_url': _dbUrl, 'project_id': 'madar-couple'},
        'client': [
          {
            'client_info': {
              'mobilesdk_app_id': _appId,
              'android_client_info': {'package_name': 'app.madar.orbit'},
            },
            'api_key': [
              {'current_key': _apiKey},
            ],
          },
        ],
      });
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.getData') return {'text': clipboard};
        if (call.method == 'Clipboard.setData') clipboard = (call.arguments as Map)['text'] as String?;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      final env = await _open(
        tester,
        locale: const Locale('en'),
        overrides: o.overrides,
        open: (c) => showOnlinePlaySheet(c),
      );
      expect(find.text('Online play'), findsWidgets);
      expect(find.text('One-time setup'), findsOneWidget);

      // Turning on without a project is refused.
      await tester.tap(find.byKey(const ValueKey('together-online-switch')));
      await _pump(tester);
      expect(find.text('Save the project settings first'), findsOneWidget);

      // Invalid values.
      final apiKey = find.byKey(const ValueKey('together-online-apiKey'));
      await tester.ensureVisible(apiKey);
      await tester.enterText(apiKey, 'not-a-key');
      await tester.tap(find.byKey(const ValueKey('together-online-save')));
      await _pump(tester);
      expect(find.text('Not in the expected format'), findsOneWidget);
      expect(find.text('Required'), findsNWidgets(3));
      expect(o.secrets.values, isEmpty);

      // Paste.
      final paste = find.byKey(const ValueKey('together-online-paste'));
      await tester.ensureVisible(paste);
      await tester.tap(paste);
      await _pump(tester);
      expect(find.text('Fields filled from the clipboard'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('together-online-save')));
      await _pump(tester);
      expect(find.text('Settings saved'), findsOneWidget);
      final stored = OnlineConfig.fromJson(jsonDecode(o.secrets.values[OnlineConfigStore.key]!))!;
      expect((stored.apiKey, stored.appId, stored.projectId, stored.databaseUrl), (
        _config.apiKey,
        _config.appId,
        _config.projectId,
        _config.databaseUrl,
      ));
      expect(stored.senderId, '123456789012');

      // Test connection against the (fake) project.
      await tester.tap(find.byKey(const ValueKey('together-online-test')));
      await _pump(tester);
      expect(find.text('It works! Anonymous sign-in and the rules are ready'), findsOneWidget);

      // Turn on.
      final toggle = find.byKey(const ValueKey('together-online-switch'));
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await _pump(tester);
      expect((await tester.runAsync(env.repo.settings))!.onlineEnabled, isTrue);

      // Copy the rules.
      final rules = find.byKey(const ValueKey('together-online-rules'));
      await tester.ensureVisible(rules);
      await tester.tap(rules);
      await _pump(tester);
      expect(clipboard, OnlineSecurityRules.json);

      // Remove: forgotten, and online play off again.
      final remove = find.byKey(const ValueKey('together-online-remove'));
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await _pump(tester);
      expect(o.secrets.values, isEmpty);
      expect((await tester.runAsync(env.repo.settings))!.onlineEnabled, isFalse);
      await _finish(tester);
    });

    testWidgets('Arabic: a failing test explains the fix (rules missing)', (tester) async {
      final o = _Online();
      o.db.rulesInstalled = false;
      await _open(tester, overrides: o.overrides, open: (c) => showOnlinePlaySheet(c));
      await _pump(tester);
      expect(find.text('اللعب عبر الإنترنت'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('together-online-test')));
      await _pump(tester);
      expect(find.text('رفضت قاعدة البيانات الوصول — الصقا قواعد الأمان'), findsOneWidget);
      await _finish(tester);
    });
  });
}
