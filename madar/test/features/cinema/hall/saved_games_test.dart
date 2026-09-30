import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/features/cinema/engine/core/score.dart';
import 'package:madar/features/cinema/hall/cinema_store.dart';
import 'package:madar/features/cinema/hall/saved_games/saved_game.dart';
import 'package:madar/features/cinema/hall/saved_games/saved_games_store.dart';

void main() {
  group('parseGameUrl', () {
    test('accepts http(s) links and adds https when no scheme was typed', () {
      expect(parseGameUrl('  example.com/play?level=2 ').toString(), 'https://example.com/play?level=2');
      expect(parseGameUrl('https://games.example.org/x').toString(), 'https://games.example.org/x');
      expect(parseGameUrl('http://arcade.example.net').toString(), 'http://arcade.example.net');
    });

    test('rejects everything else', () {
      for (final bad in ['', 'not a url', 'localhost', 'ftp://example.com/f', 'javascript:alert(1)', 'file:///sdcard/x.html']) {
        expect(parseGameUrl(bad), isNull, reason: bad);
      }
    });
  });

  test('SavedGame JSON round trip', () {
    final g = SavedGame(id: 'g1', title: 'لعبة', url: Uri.parse('https://example.com/g'), addedAt: DateTime.utc(2026, 9, 1));
    expect(SavedGame.fromJson(g.toJson()), g);
  });

  group('stores on the encrypted key/value table', () {
    late MadarDatabase db;
    late KeyValueRepository kv;

    setUp(() {
      db = MadarDatabase(NativeDatabase.memory());
      kv = KeyValueRepository(db);
    });
    tearDown(() => db.close());

    test('KvSavedGamesStore adds, replaces by id, removes and skips malformed rows', () async {
      final store = KvSavedGamesStore(kv);
      final a = SavedGame(id: 'a', title: 'A', url: Uri.parse('https://a.example.com'), addedAt: DateTime.utc(2026));
      final b = SavedGame(id: 'b', title: 'B', url: Uri.parse('https://b.example.com'), addedAt: DateTime.utc(2026));
      await store.add(a);
      await store.add(b);
      await store.add(SavedGame(id: 'a', title: 'A2', url: a.url, addedAt: a.addedAt));
      expect((await store.all()).map((g) => g.title), ['B', 'A2']);
      await store.remove('b');
      expect((await store.all()).map((g) => g.id), ['a']);
      await kv.setJson(KvSavedGamesStore.key, [
        {'id': 'x'},
        a.toJson(),
      ]);
      expect((await store.all()).single.id, 'a');
    });

    test('KvScoreSink keeps the best score per game', () async {
      final sink = KvScoreSink(kv);
      GameResult r(String id, int s) => GameResult(gameId: id, score: s, won: true, playTime: Duration.zero);
      await sink.submit(r('demo', 5));
      await sink.submit(r('demo', 3));
      await sink.submit(r('other', 9));
      expect(await sink.best('demo'), 5);
      await sink.submit(r('demo', 8));
      expect(await sink.best('demo'), 8);
      expect(await sink.best('other'), 9);
      expect(await sink.best('none'), isNull);
    });
  });

  test('MemorySavedGamesStore streams changes', () async {
    final store = MemorySavedGamesStore();
    final seen = <int>[];
    final sub = store.watch().listen((l) => seen.add(l.length));
    await Future<void>.delayed(Duration.zero);
    await store.add(SavedGame(id: 'a', title: 'A', url: Uri.parse('https://a.example.com'), addedAt: DateTime.utc(2026)));
    await store.remove('a');
    await Future<void>.delayed(Duration.zero);
    expect(seen, [0, 1, 0]);
    await sub.cancel();
  });
}
