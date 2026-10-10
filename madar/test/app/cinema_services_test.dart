// Madar Cinema in the app shell: the hall's first list of web games
// (`cinema.savedGames`) moves into Saved Games at start – before the hall
// is ever opened – once, and the old row is gone; an app without that row
// starts as before.
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/features/saved_games/saved_games.dart';

import '../features/lock/lock_test_utils.dart';
import '../helpers/test_app.dart';

void main() {
  testWidgets('the hall\'s earlier saved games move into Saved Games at start, once', (tester) async {
    final app = await pumpMadarApp(
      tester,
      initialLocation: AppRoutes.home,
      overrides: LockFixture.empty().overrides,
      beforePump: (db) => KeyValueRepository(db).setJson(KvSavedWebGamesStore.legacyHallKey, [
        {
          'id': 'g1',
          'title': 'Tiles',
          'url': 'http://claude.ai/public/artifacts/abc',
          'addedAt': '2026-09-20T10:00:00.000Z',
        },
      ]),
    );
    final kv = app.repos.keyValues;
    final games = await tester.runAsync(() async {
      // The import runs on its own; give its queries a moment.
      for (var i = 0; i < 50 && await kv.contains(KvSavedWebGamesStore.legacyHallKey); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      return (await app.container.read(savedWebGamesStoreProvider).read()).games;
    });
    expect(await tester.runAsync(() => kv.contains(KvSavedWebGamesStore.legacyHallKey)), isFalse);
    expect(games!.single.title, 'Tiles');
    expect(games.single.url.scheme, 'https', reason: 'an old http link is upgraded');
    expect(app.container.read(savedGamesLegacyImportProvider).value, 1, reason: 'read once at start');
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('without an earlier list nothing is imported', (tester) async {
    final app = await pumpMadarApp(tester, overrides: LockFixture.empty().overrides);
    final count = await tester.runAsync(() => app.container.read(savedGamesLegacyImportProvider.future));
    expect(count, 0);
    expect(
      await tester.runAsync(() async => (await app.container.read(savedWebGamesStoreProvider).read()).games),
      isEmpty,
    );
    await tester.pump(const Duration(seconds: 6));
  });
}
