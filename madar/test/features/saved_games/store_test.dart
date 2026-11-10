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

  group('import of an earlier list (the hall\'s first cinema.savedGames)', () {
    test('validates every link, upgrades http, skips duplicates and bad entries', () async {
      final store = MemorySavedWebGamesStore(SavedGamesState(games: [game('a')]));
      var n = 0;
      final added = await store.importEntries(
        [
          {
            'id': 'g1',
            'title': 'Double Feature',
            'url': 'https://claude.ai/public/artifacts/abc',
            'addedAt': '2026-09-20T10:00:00.000Z',
          },
          {'title': 'Old', 'url': 'http://old.example.com/play'},
          {'title': 'Dup', 'url': 'https://a.example.com/'},
          {'title': 'Bad', 'url': 'javascript:alert(1)'},
          {'title': 'Also bad', 'url': 'file:///sdcard/game.html'},
          {'title': 'Again', 'url': 'https://claude.ai/public/artifacts/abc'},
          {'title': '  ', 'url': 'games.example.net/x'},
          {'title': 'No link'},
          'junk',
        ],
        newId: () => 'm${n++}',
        now: DateTime(2026, 9, 30),
      );
      expect(added, 3);
      final s = await store.read();
      expect(s.games.map((g) => g.url.toString()), [
        'https://a.example.com/',
        'https://claude.ai/public/artifacts/abc',
        'https://old.example.com/play',
        'https://games.example.net/x',
      ]);
      expect(s.games.map((g) => g.id), ['a', 'm0', 'm1', 'm2']);
      expect(s.games[1].title, 'Double Feature');
      expect(s.games[1].addedAt, DateTime.utc(2026, 9, 20, 10).toLocal());
      expect(s.games[3].title, 'games.example.net');
      expect(s.games[3].addedAt, DateTime(2026, 9, 30));
      expect(await store.importEntries('nope', newId: () => 'x', now: DateTime(2026)), 0);
    });

    test('never grows past maxGames', () async {
      final store = MemorySavedWebGamesStore();
      var n = 0;
      final added = await store.importEntries(
        [
          for (var i = 0; i < SavedGamesLimits.maxGames + 5; i++) {'title': 'G$i', 'url': 'https://g$i.example.com/'},
        ],
        newId: () => 'm${n++}',
        now: DateTime(2026, 9, 30),
      );
      expect(added, SavedGamesLimits.maxGames);
      expect((await store.read()).games, hasLength(SavedGamesLimits.maxGames));
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

    test('moves the hall\'s earlier list once, then removes the old row', () async {
      final kv = KeyValueRepository(db);
      await kv.setJson(KvSavedWebGamesStore.legacyHallKey, [
        {
          'id': 'g1',
          'title': 'Tiles',
          'url': 'https://claude.ai/public/artifacts/abc',
          'addedAt': '2026-09-20T10:00:00.000Z',
        },
      ]);
      final store = KvSavedWebGamesStore(kv);
      var n = 0;
      expect(await store.migrateLegacyList(newId: () => 'm${n++}'), 1);
      expect(await kv.contains(KvSavedWebGamesStore.legacyHallKey), isFalse);
      expect((await store.read()).games.single.title, 'Tiles');
      expect(await store.migrateLegacyList(newId: () => 'm${n++}'), 0);
      expect((await store.read()).games, hasLength(1));
    });

    test('a corrupt row reads as empty', () async {
      final kv = KeyValueRepository(db);
      await kv.setJson(KvSavedWebGamesStore.key, {'games': 'broken'});
      expect((await KvSavedWebGamesStore(kv).read()).games, isEmpty);
    });
  });
}
