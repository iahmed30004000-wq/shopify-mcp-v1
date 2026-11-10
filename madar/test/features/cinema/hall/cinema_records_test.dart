import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/features/cinema/engine/core/score.dart';
import 'package:madar/features/cinema/hall/cinema_records.dart';
import 'package:madar/features/cinema/hall/cinema_store.dart';

GameResult _r(String id, int score, {bool won = true, int seconds = 30}) => GameResult(
  gameId: id,
  score: score,
  won: won,
  playTime: Duration(seconds: seconds),
);

void main() {
  group('GameRecord / CinemaRecords', () {
    test('adding results keeps the best, counts plays, wins and time', () {
      final at = DateTime.utc(2026, 9, 30, 20);
      var r = const GameRecord(gameId: 'demo');
      r = r.add(_r('demo', 120), at).add(_r('demo', 80, won: false, seconds: 10), at);
      expect(r.best, 120);
      expect(r.plays, 2);
      expect(r.wins, 1);
      expect(r.playTime, const Duration(seconds: 40));
      expect(r.lastScore, 80);
      expect(GameRecord.fromJson('demo', r.toJson()), r);
    });

    test('decoding is tolerant: junk reads as zero, legacy numbers as best', () {
      expect(GameRecord.fromJson('a', 'junk').best, 0);
      expect(GameRecord.fromJson('a', 77).best, 77);
      expect(GameRecord.fromJson('a', {'best': -5, 'plays': 'x', 'ms': double.nan}).plays, 0);
      final decoded = KvCinemaRecordsStore.decode({
        'ok_id': {'best': 3},
        'Bad Id!': {'best': 9},
        42: 1,
      });
      expect(decoded.games.keys, ['ok_id']);
    });

    test('totals and the favourite (most played, then longest)', () {
      const records = CinemaRecords({
        'a': GameRecord(gameId: 'a', plays: 3, wins: 1, playTime: Duration(minutes: 5), best: 10),
        'b': GameRecord(gameId: 'b', plays: 3, wins: 2, playTime: Duration(minutes: 9)),
        'c': GameRecord(gameId: 'c', plays: 1, playTime: Duration(minutes: 1)),
      });
      expect(records.totalPlays, 7);
      expect(records.totalWins, 3);
      expect(records.totalTime, const Duration(minutes: 15));
      expect(records.favourite?.gameId, 'b');
      expect(records.best('a'), 10);
      expect(records.best('b'), isNull, reason: 'no scored show yet');
      expect(CinemaRecords.empty.isEmpty, isTrue);
    });
  });

  group('KvCinemaRecordsStore on the encrypted key/value table', () {
    late MadarDatabase db;
    late KeyValueRepository kv;

    setUp(() {
      db = MadarDatabase(NativeDatabase.memory());
      kv = KeyValueRepository(db);
    });
    tearDown(() => db.close());

    test('submits results, serialising concurrent shows', () async {
      final store = KvCinemaRecordsStore(kv, clock: () => DateTime.utc(2026, 9, 30));
      await Future.wait([
        store.submit(_r('demo', 5)),
        store.submit(_r('demo', 12)),
        store.submit(_r('flappy_orbit', 3, won: false)),
      ]);
      final records = await store.load();
      expect(records.of('demo')?.plays, 2);
      expect(records.of('demo')?.best, 12);
      expect(await store.best('demo'), 12);
      expect(await store.best('flappy_orbit'), 3);
      expect(await store.best('nothing'), isNull);
      expect(records.totalWins, 2);
      expect((await kv.getJson(KvCinemaRecordsStore.key)) is Map, isTrue);
    });

    test('folds the old best-score map in once and removes it', () async {
      await kv.setJson(KvCinemaRecordsStore.legacyBestKey, {'demo': 40, 'noir_rooftops': 7});
      final store = KvCinemaRecordsStore(kv);
      await store.submit(_r('demo', 25));
      final records = await store.load();
      expect(records.best('demo'), 40, reason: 'the legacy best survives a lower new score');
      expect(records.of('demo')?.plays, 1);
      expect(records.best('noir_rooftops'), 7);
      expect(await kv.contains(KvCinemaRecordsStore.legacyBestKey), isFalse);
    });

    test('ignores malformed ids; watch emits updates', () async {
      final store = KvCinemaRecordsStore(kv);
      await store.submit(_r('../evil', 999));
      expect((await store.load()).isEmpty, isTrue);
      final seen = <int>[];
      final sub = store.watch().listen((r) => seen.add(r.totalPlays));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await store.submit(_r('demo', 1));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await sub.cancel();
      expect(seen.first, 0);
      expect(seen.last, 1);
    });

    test('KvScoreSink (former name) is the records store', () async {
      final ScoreSink sink = KvScoreSink(kv);
      await sink.submit(_r('demo', 9));
      expect(await sink.best('demo'), 9);
    });
  });

  test('MemoryCinemaRecordsStore records and streams', () async {
    final store = MemoryCinemaRecordsStore();
    final next = store.watch().skip(1).first;
    await store.submit(_r('demo', 4));
    expect((await next).best('demo'), 4);
    expect(store.submitted, hasLength(1));
  });
}
