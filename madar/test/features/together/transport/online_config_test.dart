import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/encryption.dart' show MemorySecretStore;
import 'package:madar/core/notifications/fake_notification_platform.dart';
import 'package:madar/core/notifications/notification_models.dart';
import 'package:madar/core/notifications/notification_service.dart';
import 'package:madar/features/together/pairing/pairing.dart';
import 'package:madar/features/together/together.dart';

import '../together_test_utils.dart';

const _key = 'AIzaSyA1b2C3d4E5f6G7h8I9j0KlMnOpQrStUvW';
const _appId = '1:123456789012:android:0123456789abcdef';
const _db = 'https://madar-couple-default-rtdb.europe-west1.firebasedatabase.app';

void main() {
  group('online config', () {
    test('a valid project passes; the sender id comes from the app id', () {
      expect(OnlineConfig.validate(apiKey: _key, appId: _appId, projectId: 'madar-couple', databaseUrl: _db), isEmpty);
      final c = OnlineConfig.tryCreate(
        apiKey: ' $_key ',
        appId: _appId,
        projectId: 'madar-couple',
        databaseUrl: '$_db/',
      )!;
      expect(c.apiKey, _key);
      expect(c.databaseUrl, _db);
      expect(c.senderId, '123456789012');
      expect(OnlineConfig.fromJson(jsonDecode(jsonEncode(c.toJson()))), c);
      expect(
        OnlineConfig.validate(
          apiKey: _key,
          appId: '1:123456789012:web:0123456789abcdef012345',
          projectId: 'madar-couple',
          databaseUrl: 'https://madar-couple-default-rtdb.firebaseio.com',
        ),
        isEmpty,
      );
    });

    test('each field is checked: missing, malformed, mismatched', () {
      final problems = OnlineConfig.validate(
        apiKey: 'not-a-key',
        appId: '1:12:android:xyz',
        projectId: 'Madar Couple',
        databaseUrl: 'http://evil.example.com/db',
        senderId: '999999999',
      );
      expect(problems, {
        OnlineConfigField.apiKey: OnlineConfigProblem.format,
        OnlineConfigField.appId: OnlineConfigProblem.format,
        OnlineConfigField.projectId: OnlineConfigProblem.format,
        OnlineConfigField.databaseUrl: OnlineConfigProblem.format,
      });
      expect(OnlineConfig.validate(apiKey: '', appId: '', projectId: '', databaseUrl: ''), {
        OnlineConfigField.apiKey: OnlineConfigProblem.missing,
        OnlineConfigField.appId: OnlineConfigProblem.missing,
        OnlineConfigField.projectId: OnlineConfigProblem.missing,
        OnlineConfigField.databaseUrl: OnlineConfigProblem.missing,
      });
      expect(
        OnlineConfig.validate(
          apiKey: _key,
          appId: _appId,
          projectId: 'madar-couple',
          databaseUrl: _db,
          senderId: '222222222222',
        ),
        {OnlineConfigField.senderId: OnlineConfigProblem.mismatch},
      );
      // Only Firebase database hosts, only https, no paths.
      for (final url in [
        'https://madar.firebaseio.com.evil.io',
        'https://madar.firebaseio.com/rooms',
        'https://firebaseio.com',
        'ftp://madar.firebaseio.com',
      ]) {
        expect(OnlineConfig.validate(apiKey: _key, appId: _appId, projectId: 'madar-couple', databaseUrl: url), {
          OnlineConfigField.databaseUrl: OnlineConfigProblem.format,
        }, reason: url);
      }
      expect(OnlineConfig.fromJson({'apiKey': 'x'}), isNull);
      expect(OnlineConfig.fromJson('nonsense'), isNull);
    });

    test('pasting google-services.json fills the fields (the app.madar.orbit client first)', () {
      final json = jsonEncode({
        'project_info': {
          'project_number': '123456789012',
          'firebase_url': 'https://madar-couple-default-rtdb.firebaseio.com',
          'project_id': 'madar-couple',
        },
        'client': [
          {
            'client_info': {
              'mobilesdk_app_id': '1:123456789012:android:ffffffffffffffff',
              'android_client_info': {'package_name': 'com.other.app'},
            },
            'api_key': [
              {'current_key': 'AIzaSyOTHERxxxxxxxxxxxxxxxxxxxxxxxxxxxx'},
            ],
          },
          {
            'client_info': {
              'mobilesdk_app_id': _appId,
              'android_client_info': {'package_name': 'app.madar.orbit'},
            },
            'api_key': [
              {'current_key': _key},
            ],
          },
        ],
      });
      final d = OnlineConfigDraft.parse(json)!;
      expect(d.apiKey, _key);
      expect(d.appId, _appId);
      expect(d.projectId, 'madar-couple');
      expect(d.databaseUrl, 'https://madar-couple-default-rtdb.firebaseio.com');
      expect(d.senderId, '123456789012');
    });

    test('pasting the console\'s web snippet fills the fields', () {
      const snippet =
          '''
const firebaseConfig = {
  apiKey: "$_key",
  authDomain: "madar-couple.firebaseapp.com",
  databaseURL: "$_db",
  projectId: "madar-couple",
  messagingSenderId: "123456789012",
  appId: "1:123456789012:web:0123456789abcdef012345"
};''';
      final d = OnlineConfigDraft.parse(snippet)!;
      expect(d.apiKey, _key);
      expect(d.databaseUrl, _db);
      expect(d.projectId, 'madar-couple');
      expect(d.appId, '1:123456789012:web:0123456789abcdef012345');
      expect(OnlineConfigDraft.parse('hello'), isNull);
    });

    test('the store keeps it in secure storage, and forgets it', () async {
      final secrets = MemorySecretStore();
      final store = OnlineConfigStore(secrets);
      expect(await store.read(), isNull);
      final c = OnlineConfig.tryCreate(apiKey: _key, appId: _appId, projectId: 'madar-couple', databaseUrl: _db)!;
      await store.write(c);
      expect(secrets.values.keys, [OnlineConfigStore.key]);
      expect(await store.read(), c);
      secrets.values[OnlineConfigStore.key] = '{broken';
      expect(await store.read(), isNull);
      await store.clear();
      expect(secrets.values, isEmpty);
    });
  });

  group('two-phone seating', () {
    test('each phone maps the participants to its own players', () {
      const host = TwoPhoneSeating(role: SessionRole.host, localSlot: PlayerSlot.two);
      const guest = TwoPhoneSeating(role: SessionRole.guest, localSlot: PlayerSlot.one);
      expect(host.seating, [PlayerSlot.two, PlayerSlot.one]);
      expect(guest.seating, [PlayerSlot.two, PlayerSlot.one]);
      expect(host.participantOf(PlayerSlot.two), 0);
      expect(guest.participantOf(PlayerSlot.one), 1);
    });

    test('whoever starts sits on seat 0, whichever phone hosts', () {
      const host = TwoPhoneSeating(role: SessionRole.host, localSlot: PlayerSlot.one);
      expect(host.seats(firstPlayer: PlayerSlot.one, seatCount: 2), [0, 1]);
      expect(host.seats(firstPlayer: PlayerSlot.two, seatCount: 2), [1, 0]);
      expect(host.seats(firstPlayer: PlayerSlot.two, seatCount: 4), [1, 0, -1, -1]);
      expect(host.seats(firstPlayer: PlayerSlot.two, seatCount: 4, partners: true), [1, -1, 0, -1]);
      expect(host.seats(firstPlayer: PlayerSlot.one, seatCount: 4, partners: true), TogetherSeats.partners(4));
    });
  });

  group('your-turn alerts', () {
    Future<(TogetherSession<RaceState, int>, TogetherSession<RaceState, int>)> pair() async {
      final link = LoopbackLink(mode: PlayMode.online);
      final host = TogetherSession<RaceState, int>(adapter: const RaceGame(), transport: link.host);
      final guest = TogetherSession<RaceState, int>(
        adapter: const RaceGame(),
        transport: link.guest,
        role: SessionRole.guest,
      );
      await host.start(seed: 1);
      await settle();
      return (host, guest);
    }

    TogetherTurnTexts texts() => const TogetherTurnTexts(
      groupName: 'Together',
      channelName: 'Your turn',
      channelDescription: 'When your partner has played',
      title: 'Your turn',
      body: 'Sara played in Race.',
    );

    test('shown in the background when the partner\'s move makes it this phone\'s turn; cleared on return', () async {
      final platform = FakeNotificationPlatform();
      final foreground = ValueNotifier(true);
      final alerts = TogetherTurnAlerts(notifications: NotificationService(platform), foreground: foreground);
      final (host, guest) = await pair();
      final stop = alerts.watch(guest, texts: texts);
      foreground.value = false;
      await host.play(1);
      await settle();
      final shown = platform.shown[TogetherNotifications.yourTurnId];
      expect(shown, isNotNull);
      expect(shown!.request.namespace, TogetherNotifications.namespace);
      expect(shown.request.title, 'Your turn');
      expect(platform.channels.keys, contains(TogetherNotifications.turnChannelId));
      foreground.value = true;
      await settle();
      expect(platform.cancelled, contains(TogetherNotifications.yourTurnId));
      stop();
      host.dispose();
      guest.dispose();
    });

    test('nothing in the foreground, without permission, or on this phone\'s own move', () async {
      final platform = FakeNotificationPlatform(enabled: false);
      final foreground = ValueNotifier(false);
      final alerts = TogetherTurnAlerts(notifications: NotificationService(platform), foreground: foreground);
      final (host, guest) = await pair();
      final stop = alerts.watch(guest, texts: texts);
      await host.play(1);
      await settle();
      expect(platform.shown, isEmpty, reason: 'notifications not allowed: never asked mid-game');
      platform.enabled = true;
      await guest.play(2);
      await settle();
      expect(platform.shown, isEmpty, reason: 'this phone\'s own move');
      foreground.value = true;
      await host.play(1);
      await settle();
      expect(platform.shown, isEmpty, reason: 'in the foreground');
      stop();
      host.dispose();
      guest.dispose();
    });

    test('the id block is Together\'s own and overlaps no other feature', () {
      const ns = TogetherNotifications.namespace;
      expect(ns.contains(TogetherNotifications.yourTurnId), isTrue);
      for (final other in [...NotificationNamespaces.all, const NotificationNamespace('center', 160000, 160999)]) {
        // Together's own block is in `NotificationNamespaces.all` now (the
        // same const value), so it is the one entry it may equal.
        if (other.name == ns.name) {
          expect(other, ns, reason: 'the core block and Together\'s must stay the same ids');
          continue;
        }
        expect(ns.first > other.last || ns.last < other.first, isTrue, reason: other.name);
      }
    });
  });
}
