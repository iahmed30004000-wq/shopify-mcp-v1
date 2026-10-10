// "Delete all data" and the life reminders: every life record lives in the
// encrypted database, so deleting it (the gate's start-fresh, through
// `deleteAllMadarData`) needs no extra wipe hook – on the next unlock the
// app-wide syncs run over the empty database and cancel whatever the old
// data had planned in their own blocks (family, trackers, travel documents,
// fasting), leaving ids no feature owns alone.
//
// (The system services' delete-all extras – the AI keys, the widgets' data,
// Together's online project, every armed alarm, the safety copies – are
// tested in `phase9b_system_test.dart`; this test overrides the whole
// `databaseResetProvider`, so they do not run here.)
import 'dart:io';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/app/app_gate.dart';
import 'package:madar/core/db/db_errors.dart';
import 'package:madar/core/db/encryption.dart';
import 'package:madar/core/db/open.dart' show deleteAllMadarData;
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/app/splash.dart';
import 'package:madar/features/body/body.dart' show BodyReminderIds;
import 'package:madar/features/custom_modules/custom_modules.dart' show CustomModuleReminderIds;
import 'package:madar/features/family/family.dart' show FamilyNotificationIds;
import 'package:madar/features/home/home_screen.dart';
import 'package:madar/features/travel/travel.dart' show TravelReminderIds;

import '../helpers/test_app.dart';

final _ar = lookupL10n(const Locale('ar'));

NotificationRequest _left(int id, Map<String, Object?> data) => NotificationRequest(
  namespace: NotificationNamespaces.reminders,
  id: id,
  channelId: 'x',
  title: 'left over',
  body: '',
  at: DateTime(2026, 10, 5, 20),
  data: data,
);

void main() {
  testWidgets('after delete-all, the next unlock cancels every life reminder the old data planned', (tester) async {
    // What the old database had planned, still with the system.
    final platform = FakeNotificationPlatform();
    final leftovers = [
      _left(FamilyNotificationIds.digestFirst + 2, const {'k': 'digest'}),
      _left(FamilyNotificationIds.birthdayFirst + 40, const {'k': 'birthday', 'p': 'gone'}),
      _left(CustomModuleReminderIds.first + 5, const {'k': 'cmod', 'm': 'gone', 'r': 'r'}),
      _left(TravelReminderIds.first + 1, const {'feature': 'travel', 'documentId': 'gone', 'kind': 'onDay'}),
      _left(BodyReminderIds.goal, const {'kind': 'bodyFasting', 'notice': 'goal'}),
    ];
    // An id in a free part of the namespace: nobody's, so nobody cancels it.
    final foreign = _left(131500, const {'k': 'nobody'});
    for (final r in [...leftovers, foreign]) {
      await platform.schedule(r, NotificationEnvelope.encode(r), timing: NotificationTiming.exactWhileIdle);
    }

    // The key is unreadable: the gate offers "start fresh", which deletes
    // the database files and the key for real (a temp file, a memory store).
    final dir = Directory.systemTemp.createTempSync('madar_life_reset_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/madar.db')..writeAsStringSync('the old, encrypted data');
    final secrets = MemorySecretStore({DatabaseKeyStore.storageKey: 'not a key'});
    final keys = DatabaseKeyStore(store: secrets);
    final fresh = await openTestDatabase(tester);
    var resets = 0;

    final app = await pumpMadarApp(
      tester,
      database: false,
      settle: false,
      notifications: platform,
      overrides: [
        databaseOpenerProvider.overrideWithValue((_) async {
          if (await secrets.read(DatabaseKeyStore.storageKey) != null) {
            throw const DatabaseKeyException(DatabaseKeyProblem.malformed, 'bad');
          }
          return fresh;
        }),
        databaseResetProvider.overrideWithValue(() async {
          resets++;
          await deleteAllMadarData(keyStore: keys, file: file);
        }),
      ],
    );
    await tester.pump(AstrolabeSplash.assembly);
    await settleApp(tester);
    expect(find.text(_ar.shellGateReset), findsOneWidget);
    expect(platform.scheduled.keys, containsAll([for (final r in leftovers) r.id]));

    await tester.tap(find.text(_ar.shellGateReset));
    await settleApp(tester);
    await tester.tap(find.text(_ar.shellGateResetConfirm));
    // The files are really deleted: let that I/O run outside the fake clock.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
    await tester.pump(AstrolabeSplash.assembly);
    await settleApp(tester);
    expect(resets, 1);
    expect(file.existsSync(), isFalse, reason: 'deleteAllMadarData removed the files');
    expect(secrets.values, isEmpty, reason: '…and forgot the key');
    expect(find.byType(HomeScreen), findsOneWidget);

    // The syncs' debounces pass; each reconciles its own block.
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 400));
    }
    for (final r in leftovers) {
      expect(platform.scheduled.containsKey(r.id), isFalse, reason: '${r.id} still planned');
    }
    expect(platform.cancelled, containsAll([for (final r in leftovers) r.id]));
    expect(platform.scheduled.containsKey(foreign.id), isTrue, reason: 'no feature owns 131500');
    expect(app.notifications, same(platform));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 6));
  });
}
