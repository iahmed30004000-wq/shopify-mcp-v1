import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/features/saved_games/saved_games.dart';

SavedWebGame game(String id, {String? url, String title = 'Game', GameArt art = const GameArt(glyph: 0, hue: 0)}) =>
    SavedWebGame(
      id: id,
      title: title,
      url: Uri.parse(url ?? 'https://$id.example.com/'),
      art: art,
      addedAt: DateTime(2026, 9, 1),
    );

void main() {
  group('SavedGamesCodec (bounds)', () {
    test('decodes nothing / garbage as empty', () {
      expect(SavedGamesCodec.decode(null), SavedGamesState.empty);
      expect(SavedGamesCodec.decode('x'), SavedGamesState.empty);
      expect(SavedGamesCodec.decode({'games': 'nope'}).games, isEmpty);
    });

    test('skips malformed entries, dangerous links and duplicate ids; keeps order', () {
      final state = SavedGamesCodec.decode({
        'v': 1,
        'layout': 'list',
        'games': [
          game('a').toJson(),
          42,
          {'id': 'b'},
          {...game('c').toJson(), 'url': 'javascript:alert(1)'},
          {...game('d').toJson(), 'url': 'http://d.example.com/'},
          {...game('e').toJson(), 'url': 'file:///sdcard/x.html'},
          {...game('a').toJson(), 'title': 'dup'},
          game('f').toJson(),
        ],
      });
      expect(state.layout, SavedGamesLayout.list);
      expect(state.games.map((g) => g.id), ['a', 'f']);
    });

    test('caps the list at maxGames and clamps fields', () {
      final many = [for (var i = 0; i < SavedGamesLimits.maxGames + 15; i++) game('g$i').toJson()];
      many[0] = {...many[0], 'title': 'T' * 1000, 'notes': 'N' * 9000};
      final state = SavedGamesCodec.decode({'games': many});
      expect(state.games, hasLength(SavedGamesLimits.maxGames));
      expect(state.games.first.title.length, SavedGamesLimits.maxTitle);
      expect(state.games.first.notes.length, SavedGamesLimits.maxNotes);
    });

    test('encoded worst case stays bounded', () {
      final icon = Uint8List(SavedGamesLimits.maxIconBytes);
      final games = [
        for (var i = 0; i < SavedGamesLimits.maxGames; i++)
          game(
            'g$i',
            url: 'https://g$i.example.com/${'p' * 1900}',
            title: 'T' * 80,
            art: GameArt(glyph: 1, hue: 1, favicon: icon),
          ).copyWith(notes: 'N' * SavedGamesLimits.maxNotes),
      ];
      final text = jsonEncode(SavedGamesCodec.encode(SavedGamesState(games: games)));
      // ~40 × (22 KB icon + 2 KB link + notes): about 1 MB, never more.
      expect(text.length, lessThan(1100 * 1024));
      expect(SavedGamesCodec.decode(jsonDecode(text)).games, hasLength(SavedGamesLimits.maxGames));
    });
  });

  group('SavedWebGamesStore operations', () {
    late MemorySavedWebGamesStore store;
    setUp(() => store = MemorySavedWebGamesStore());

    test('add appends, refuses duplicates by link and a full shelf', () async {
      expect((await store.add(game('a'))).status, AddGameStatus.added);
      final dup = await store.add(game('z', url: 'https://a.example.com/'));
      expect(dup.status, AddGameStatus.duplicate);
      expect(dup.game!.id, 'a');
      for (var i = 1; i < SavedGamesLimits.maxGames; i++) {
        await store.add(game('g$i'));
      }
      expect((await store.read()).games, hasLength(SavedGamesLimits.maxGames));
      expect((await store.add(game('overflow'))).status, AddGameStatus.full);
    });

    test('remove + restore puts the game back where it was', () async {
      for (final id in ['a', 'b', 'c']) {
        await store.add(game(id));
      }
      final removed = await store.remove('b');
      expect(removed!.index, 1);
      expect((await store.read()).games.map((g) => g.id), ['a', 'c']);
      expect(await store.restore(removed), isTrue);
      expect((await store.read()).games.map((g) => g.id), ['a', 'b', 'c']);
      // A second undo does nothing.
      expect(await store.restore(removed), isFalse);
      expect(await store.remove('missing'), isNull);
    });

    test('reorder follows the ids, keeps unknown/missing sensibly', () async {
      for (final id in ['a', 'b', 'c', 'd']) {
        await store.add(game(id));
      }
      await store.reorder(['c', 'x', 'a']);
      expect((await store.read()).games.map((g) => g.id), ['c', 'a', 'b', 'd']);
    });

    test('markPlayed, update, clear-data flag and layout', () async {
      await store.add(game('a'));
      final at = DateTime(2026, 9, 30, 21);
      await store.markPlayed('a', at);
      await store.markPlayed('a', at);
      var a = (await store.read()).byId('a')!;
      expect(a.playCount, 2);
      expect(a.lastPlayedAt, at);
      await store.update(a.copyWith(title: 'Renamed', orientation: GameOrientation.landscape));
      await store.setClearDataPending('a', true);
      await store.setLayout(SavedGamesLayout.list);
      final s = await store.read();
      a = s.byId('a')!;
      expect(a.title, 'Renamed');
      expect(a.orientation, GameOrientation.landscape);
      expect(a.clearDataPending, isTrue);
      expect(s.layout, SavedGamesLayout.list);
    });

    test('overlapping changes are serialized (no lost update)', () async {
      await Future.wait([for (var i = 0; i < 20; i++) store.add(game('g$i'))]);
      await Future.wait([for (var i = 0; i < 10; i++) store.markPlayed('g0', DateTime(2026, 9, 30))]);
      final s = await store.read();
      expect(s.games, hasLength(20));
      expect(s.byId('g0')!.playCount, 10);
    });

    test('corrupt stored text reads as empty and is replaced on the next write', () async {
      store.rawText = '{not json';
      expect((await store.read()).games, isEmpty);
      await store.add(game('a'));
      expect((await store.read()).games.single.id, 'a');
    });

    test('watch emits the current state and every change', () async {
      final seen = <int>[];
      final sub = store.watch().listen((s) => seen.add(s.games.length));
      await Future<void>.delayed(Duration.zero);
      await store.add(game('a'));
      await store.add(game('b'));
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(seen, [0, 1, 2]);
    });
  });

  group('KvSavedWebGamesStore (encrypted key/value table)', () {
    late MadarDatabase db;
    setUp(() => db = MadarDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true)));
    tearDown(() => db.close());

    test('stores one bounded JSON row under savedGames.v1', () async {
      final kv = KeyValueRepository(db);
      final store = KvSavedWebGamesStore(kv);
      await store.add(game('a'));
      await store.add(game('b'));
      final raw = await kv.getJson(KvSavedWebGamesStore.key);
      expect(raw, isA<Map<String, Object?>>());
      expect((raw! as Map)['v'], 1);
      expect(((raw as Map)['games'] as List).length, 2);
      final again = KvSavedWebGamesStore(kv);
      expect((await again.read()).games.map((g) => g.id), ['a', 'b']);
    });

    test('a corrupt row reads as empty', () async {
      final kv = KeyValueRepository(db);
      await kv.setJson(KvSavedWebGamesStore.key, {'games': 'broken'});
      expect((await KvSavedWebGamesStore(kv).read()).games, isEmpty);
    });
  });
}
