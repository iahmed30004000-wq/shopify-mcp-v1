import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/features/together/together.dart';

MatchRecord _m(
  int i,
  MatchOutcome o, {
  String game = 'chess',
  DateTime? at,
  int? a,
  int? b,
}) => MatchRecord(id: 'm$i', gameId: game, endedAt: at ?? DateTime(2026, 9, 1, 20, i % 60), outcome: o, scoreOne: a, scoreTwo: b);

TogetherLedger _ledgerOf(Iterable<MatchRecord> records) => records.fold(TogetherLedger.empty, (l, r) => l.apply(r));

void main() {
  group('head-to-head tallies and streaks', () {
    test('wins, draws, co-op and win streaks', () {
      final l = _ledgerOf([
        _m(1, MatchOutcome.oneWon),
        _m(2, MatchOutcome.oneWon),
        _m(3, MatchOutcome.oneWon),
        _m(4, MatchOutcome.twoWon),
        _m(5, MatchOutcome.twoWon),
        _m(6, MatchOutcome.draw),
        _m(7, MatchOutcome.teamWon, game: 'metropolisCoop'),
        _m(8, MatchOutcome.teamWon, game: 'metropolisCoop'),
        _m(9, MatchOutcome.teamLost, game: 'metropolisCoop'),
      ]);
      final all = l.overall;
      expect(all.winsOne, 3);
      expect(all.winsTwo, 2);
      expect(all.draws, 1);
      expect(all.coopWins, 2);
      expect(all.coopLosses, 1);
      expect(all.matches, 9);
      expect(all.versusMatches, 6);
      expect(all.bestStreakOne, 3);
      expect(all.bestStreakTwo, 2);
      expect(all.streakHolder, isNull, reason: 'the draw broke the run');
      expect(all.bestCoopStreak, 2);
      expect(all.coopStreak, 0);
      expect(all.leader, PlayerSlot.one);
      expect(l.tallyOf('chess').matches, 6);
      expect(l.tallyOf('metropolisCoop').coopWins, 2);
      expect(l.games.keys, containsAll(['chess', 'metropolisCoop']));
    });

    test('co-op results do not break a head-to-head streak', () {
      final l = _ledgerOf([
        _m(1, MatchOutcome.twoWon),
        _m(2, MatchOutcome.teamWon, game: 'tarneeb'),
        _m(3, MatchOutcome.twoWon),
      ]);
      expect(l.overall.streakHolder, PlayerSlot.two);
      expect(l.overall.streakLength, 2);
    });

    test('high scores per player', () {
      final l = _ledgerOf([
        _m(1, MatchOutcome.oneWon, game: 'basra', a: 101, b: 80),
        _m(2, MatchOutcome.twoWon, game: 'basra', a: 70, b: 120),
      ]);
      expect(l.tallyOf('basra').highScoreOne, 101);
      expect(l.tallyOf('basra').highScoreTwo, 120);
    });

    test('days in a row: same day counts once, a gap restarts, late records never rewind', () {
      final d = DateTime(2026, 9, 1, 21);
      var l = _ledgerOf([
        _m(1, MatchOutcome.oneWon, at: d),
        _m(2, MatchOutcome.oneWon, at: d.add(const Duration(hours: 1))),
        _m(3, MatchOutcome.oneWon, at: d.add(const Duration(days: 1))),
        _m(4, MatchOutcome.oneWon, at: d.add(const Duration(days: 2))),
      ]);
      expect(l.dayStreak, 3);
      expect(l.currentDayStreak(d.add(const Duration(days: 2))), 3);
      expect(l.currentDayStreak(d.add(const Duration(days: 3))), 3, reason: 'still alive the next day');
      expect(l.currentDayStreak(d.add(const Duration(days: 4))), 0, reason: 'broken after a missed day');
      expect(l.matchesOnLastDay, 1);
      expect(l.bestMatchesInDay, 2);
      l = l.apply(_m(5, MatchOutcome.twoWon, at: d.subtract(const Duration(days: 5))));
      expect(l.dayStreak, 3);
      expect(l.overall.matches, 5);
      l = l.apply(_m(6, MatchOutcome.twoWon, at: d.add(const Duration(days: 6))));
      expect(l.dayStreak, 1);
      expect(l.bestDayStreak, 3);
      expect(l.firstPlayed, d.subtract(const Duration(days: 5)));
    });

    test('per-game tallies are bounded; the least recently played game goes', () {
      final base = DateTime(2026, 1, 1);
      var l = TogetherLedger.empty;
      for (var i = 0; i < TogetherBounds.maxGames + 5; i++) {
        l = l.apply(_m(i, MatchOutcome.oneWon, game: 'g$i', at: base.add(Duration(hours: i))));
      }
      expect(l.games.length, TogetherBounds.maxGames);
      expect(l.games.containsKey('g0'), isFalse);
      expect(l.games.containsKey('g${TogetherBounds.maxGames + 4}'), isTrue);
      expect(l.overall.matches, TogetherBounds.maxGames + 5, reason: 'the overall tally keeps counting');
    });

    test('ledger JSON round-trips and tolerates corruption', () {
      final l = _ledgerOf([_m(1, MatchOutcome.oneWon, a: 3, b: 1), _m(2, MatchOutcome.draw)]);
      final back = TogetherLedger.fromJson(jsonDecode(jsonEncode(l.toJson())));
      expect(back.overall.winsOne, 1);
      expect(back.overall.draws, 1);
      expect(back.tallyOf('chess').highScoreOne, 3);
      expect(back.lastDay, l.lastDay);
      final corrupt = TogetherLedger.fromJson({
        'all': {'w1': -5, 'w2': 'x', 'sh': 'three', 'sl': 4},
        'games': {'bad id!': {}, 'ok': 7},
      });
      expect(corrupt.overall.winsOne, 0);
      expect(corrupt.overall.streakHolder, isNull);
      expect(corrupt.games.keys, ['ok']);
      expect(TogetherLedger.fromJson('garbage').isEmpty, isTrue);
    });
  });

  group('trophies', () {
    Set<String> keysAfter(List<MatchRecord> records) {
      var l = TogetherLedger.empty;
      final keys = <String>{};
      for (final r in records) {
        l = l.apply(r);
        keys.addAll(TrophyRules.satisfied(l, r).map((k) => k.storageKey));
      }
      return keys;
    }

    test('first match, milestones and win streaks', () {
      final keys = keysAfter([for (var i = 0; i < 10; i++) _m(i, MatchOutcome.twoWon)]);
      expect(keys, contains('firstMatch||'));
      expect(keys, contains('matches10||'));
      expect(keys, contains('winStreak3|two|'));
      expect(keys, contains('winStreak5|two|'));
      expect(keys, contains('winStreak10|two|'));
      expect(keys, contains('gameMaster|two|chess'));
      expect(keys, isNot(contains('winStreak3|one|')));
      expect(keys, contains('marathon||'), reason: 'ten matches on one day');
    });

    test('draws, close finishes, co-op, explorers, perfect balance', () {
      final records = <MatchRecord>[
        _m(1, MatchOutcome.draw),
        _m(2, MatchOutcome.oneWon, game: 'basra', a: 100, b: 99),
        for (var i = 0; i < 5; i++) _m(10 + i, MatchOutcome.teamWon, game: 'tarneeb'),
        for (final g in ['ludo', 'dominoes', 'backgammon']) _m(g.length * 7, MatchOutcome.twoWon, game: g),
      ];
      final keys = keysAfter(records);
      expect(keys, contains('photoFinish||'));
      expect(keys, contains('nailBiter|one|'));
      expect(keys, contains('coopWins5||'));
      expect(keys, contains('explorer5||'));
      expect(keys, isNot(contains('perfectBalance||')));
      final balanced = keysAfter([for (var i = 0; i < 20; i++) _m(i, i.isEven ? MatchOutcome.oneWon : MatchOutcome.twoWon)]);
      expect(balanced, contains('perfectBalance||'));
    });

    test('day-streak trophies', () {
      final d = DateTime(2026, 9, 1, 21);
      final keys = keysAfter([for (var i = 0; i < 7; i++) _m(i, MatchOutcome.oneWon, at: d.add(Duration(days: i)))]);
      expect(keys, containsAll(['dayStreak3||', 'dayStreak7||']));
      expect(keys, isNot(contains('dayStreak30||')));
    });

    test('progress counts towards the target and caps at it', () {
      final l = _ledgerOf([for (var i = 0; i < 4; i++) _m(i, MatchOutcome.oneWon)]);
      expect(TrophyRules.progress(TrophyId.matches10, l).current, 4);
      expect(TrophyRules.progress(TrophyId.matches10, l).fraction, closeTo(0.4, 1e-9));
      expect(TrophyRules.progress(TrophyId.winStreak3, l).current, 3);
      expect(TrophyRules.progress(TrophyId.gameMaster, l).current, 4);
    });
  });

  group('profiles', () {
    test('defaults are generic, distinct and localised later (no stored name)', () {
      final p = TogetherProfiles.defaults();
      expect(p.one.name, isEmpty);
      expect(p.two.name, isEmpty);
      expect(p.one.colorIndex, isNot(p.two.colorIndex));
      expect(p.one.avatar, isNot(p.two.avatar));
    });

    test('names and titles are cleaned and bounded', () {
      final p = TogetherProfile.defaults(PlayerSlot.one).copyWith(
        name: '  A\u202Eb\u0000c   d ${'x' * 40} ',
        customTitle: 'T' * 80,
      );
      expect(p.name.contains('\u202E'), isFalse);
      expect(p.name.runes.length, lessThanOrEqualTo(TogetherBounds.maxNameLength));
      expect(p.name.startsWith('Abc d'), isTrue);
      expect(p.customTitle.length, TogetherBounds.maxTitleLength);
    });

    test('JSON round trip and corrupt values fall back to defaults', () {
      final p = TogetherProfiles.defaults().withProfile(
        TogetherProfile.defaults(PlayerSlot.two).copyWith(
          name: 'Player B',
          avatar: const TogetherAvatar.emoji('🦉', seed: 4),
          colorIndex: 5,
          title: PlayerTitle.quizWhiz,
        ),
      );
      final back = TogetherProfiles.fromJson(jsonDecode(jsonEncode(p.toJson())));
      expect(back, p);
      final corrupt = TogetherProfiles.fromJson({
        'one': {'n': 42, 'a': {'k': 'emoji', 'e': ''}, 'c': 99, 't': 'emperor'},
        'two': 'x',
      });
      expect(corrupt.one.name, isEmpty);
      expect(corrupt.one.avatar, TogetherProfile.defaults(PlayerSlot.one).avatar);
      expect(corrupt.one.colorIndex, 0);
      expect(corrupt.one.title, isNull);
      expect(corrupt.two, TogetherProfile.defaults(PlayerSlot.two));
    });

    test('settings JSON: online stays off unless explicitly on', () {
      expect(TogetherSettings.fromJson(null).onlineEnabled, isFalse);
      expect(TogetherSettings.fromJson({'online': 'yes'}).onlineEnabled, isFalse);
      const s = TogetherSettings(defaultMode: PlayMode.splitScreen, splitLayout: SplitLayout.endToEnd, hideInRecents: false);
      expect(TogetherSettings.fromJson(jsonDecode(jsonEncode(s.toJson()))), s);
    });

    test('mode availability: same-device always, transports "coming soon", online off by default', () {
      ModeAvailability a(PlayMode m, {Set<PlayMode> transports = const {}, bool online = false, Set<PlayMode>? game}) =>
          togetherModeAvailability(
            m,
            gameModes: game,
            transports: transports,
            settings: TogetherSettings(onlineEnabled: online),
          );
      expect(a(PlayMode.passAndPlay), ModeAvailability.available);
      expect(a(PlayMode.splitScreen), ModeAvailability.available);
      expect(a(PlayMode.nearby), ModeAvailability.comingSoon);
      expect(a(PlayMode.online), ModeAvailability.comingSoon);
      expect(a(PlayMode.nearby, transports: {PlayMode.nearby}), ModeAvailability.available);
      expect(a(PlayMode.online, transports: {PlayMode.online}), ModeAvailability.disabled);
      expect(a(PlayMode.online, transports: {PlayMode.online}, online: true), ModeAvailability.available);
      expect(a(PlayMode.splitScreen, game: TogetherGames.chess.modes), ModeAvailability.unsupported);
    });
  });

  group('repository – bounded JSON in KeyValues', () {
    late MadarDatabase db;
    late TogetherRepository repo;

    setUp(() {
      db = MadarDatabase(NativeDatabase.memory());
      repo = TogetherRepository(db);
    });
    tearDown(() => db.close());

    Future<int> storedBytes(String key) async {
      final row = await (db.select(db.keyValues)..where((t) => t.key.equals(key))).getSingleOrNull();
      return row == null ? 0 : utf8.encode(row.value).length;
    }

    test('records a match, earns trophies once, ignores a duplicate id', () async {
      final first = await repo.recordMatch(_m(1, MatchOutcome.oneWon));
      expect(first.duplicate, isFalse);
      expect(first.newTrophies.map((t) => t.id), [TrophyId.firstMatch]);
      final again = await repo.recordMatch(_m(1, MatchOutcome.twoWon));
      expect(again.duplicate, isTrue);
      expect((await repo.ledger()).overall.matches, 1);
      expect((await repo.history()).single.outcome, MatchOutcome.oneWon);
      final second = await repo.recordMatch(_m(2, MatchOutcome.oneWon));
      expect(second.newTrophies, isEmpty);
      expect((await repo.trophies()).trophies, hasLength(1));
    });

    test('invalid ids are refused', () async {
      await expectLater(
        repo.recordMatch(MatchRecord(id: 'bad id', gameId: 'chess', endedAt: DateTime(2026), outcome: MatchOutcome.draw)),
        throwsArgumentError,
      );
    });

    test('stays bounded after thousands of matches', () async {
      final base = DateTime(2025, 1, 1, 20);
      for (var i = 0; i < 1200; i++) {
        await repo.recordMatch(
          MatchRecord(
            id: 'match-$i-${'x' * 40}',
            gameId: 'game${i % 90}',
            endedAt: base.add(Duration(hours: 7 * i)),
            outcome: MatchOutcome.values[i % MatchOutcome.values.length],
            scoreOne: i * 1000000,
            scoreTwo: -i,
            mode: PlayMode.values[i % 4],
            durationSeconds: i * 1000,
          ),
        );
      }
      final history = await repo.history();
      expect(history.length, TogetherBounds.maxHistory);
      expect(history.first.id, startsWith('match-1199-'), reason: 'newest first, oldest dropped');
      final ledger = await repo.ledger();
      expect(ledger.overall.matches, 1200);
      expect(ledger.games.length, TogetherBounds.maxGames);
      for (final key in TogetherRepository.allKeys) {
        expect(await storedBytes(key), lessThanOrEqualTo(TogetherBounds.maxStoredBytes), reason: key);
      }
      expect(history.every((r) => r.scoreOne!.abs() <= TogetherBounds.maxScore), isTrue);
      expect(history.every((r) => r.durationSeconds! <= TogetherBounds.maxDurationSeconds), isTrue);
    });

    test('profiles and settings persist; watch streams emit only on change', () async {
      final emitted = <TogetherProfiles>[];
      final sub = repo.watchProfiles().listen(emitted.add);
      await pumpEventQueue();
      await repo.saveProfile(TogetherProfile.defaults(PlayerSlot.one).copyWith(name: 'Player A', colorIndex: 4));
      await pumpEventQueue();
      // An unrelated KeyValues write does not re-emit.
      await repo.keyValues.setJson('other.feature', {'x': 1});
      await pumpEventQueue();
      await sub.cancel();
      expect(emitted, hasLength(2));
      expect(emitted.last.one.name, 'Player A');
      expect((await repo.profiles()).one.colorIndex, 4);
      await repo.saveSettings(const TogetherSettings(defaultMode: PlayMode.splitScreen));
      expect((await repo.settings()).defaultMode, PlayMode.splitScreen);
    });

    test('corrupt stored JSON reads as empty / defaults', () async {
      for (final key in TogetherRepository.allKeys) {
        await db.into(db.keyValues).insertOnConflictUpdate(KeyValuesCompanion.insert(key: key, value: '{not json'));
      }
      expect(await repo.history(), isEmpty);
      expect((await repo.ledger()).isEmpty, isTrue);
      expect((await repo.trophies()).trophies, isEmpty);
      expect(await repo.profiles(), TogetherProfiles.defaults());
      expect(await repo.settings(), const TogetherSettings());
      // Recording still works over the corrupt values.
      final r = await repo.recordMatch(_m(1, MatchOutcome.draw));
      expect(r.newTrophies.map((t) => t.id), containsAll([TrophyId.firstMatch, TrophyId.photoFinish]));
    });

    test('reset clears records (not profiles) and can be undone', () async {
      await repo.saveProfile(TogetherProfile.defaults(PlayerSlot.two).copyWith(name: 'Player B'));
      await repo.recordMatch(_m(1, MatchOutcome.twoWon));
      final undo = await repo.resetRecords();
      expect(await repo.history(), isEmpty);
      expect((await repo.ledger()).isEmpty, isTrue);
      expect((await repo.profiles()).two.name, 'Player B');
      await undo();
      expect((await repo.history()).single.id, 'm1');
      expect((await repo.trophies()).trophies, isNotEmpty);
    });
  });
}
