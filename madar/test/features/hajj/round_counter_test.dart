import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/hajj/hajj.dart';

/// A monotonic clock the test moves by hand.
class _Mono {
  Duration now = Duration.zero;
  Duration call() => now;
  void ms(int n) => now += Duration(milliseconds: n);
}

/// A wall clock that can jump anywhere (NTP step, time-zone change, DST).
class _Wall {
  DateTime now = DateTime.utc(2026, 11, 10, 8);
  DateTime call() => now;
}

int _ids = 0;

RoundCounter _counter(_Mono mono, {_Wall? wall, RoundKind kind = RoundKind.tawaf, Duration? debounce}) {
  final c = RoundCounter(
    monotonic: mono.call,
    wallClock: wall?.call,
    newId: () => 's${_ids++}',
    debounce: debounce ?? RoundCounter.defaultDebounce,
  );
  c.start(kind);
  return c;
}

/// Taps once per second so the debounce never interferes.
void _tapN(RoundCounter c, _Mono m, int n) {
  for (var i = 0; i < n; i++) {
    m.ms(1000);
    c.tap();
  }
}

void main() {
  group('states', () {
    test('a new session is notStarted at round 1 of 7', () {
      final c = _counter(_Mono());
      expect(c.phase, CounterPhase.notStarted);
      expect(c.active!.currentRound, 1);
      expect(c.active!.total, 7);
      expect(c.canUndo, isFalse);
    });

    test('no session at all: taps say so and nothing breaks', () {
      final c = RoundCounter(monotonic: _Mono().call);
      expect(c.phase, CounterPhase.notStarted);
      expect(c.tap(), TapResult.noSession);
      expect(c.undo(), isFalse);
      expect(c.setRound(2), isFalse);
      expect(c.pause(), isFalse);
      expect(c.finish(), isFalse);
    });

    test('7 taps complete; the 7th says completed and stamps the end', () {
      final m = _Mono();
      final c = _counter(m);
      for (var i = 1; i <= 6; i++) {
        m.ms(1000);
        expect(c.tap(), TapResult.counted);
        expect(c.phase, CounterPhase.inProgress);
        expect(c.active!.currentRound, i + 1);
      }
      m.ms(1000);
      expect(c.tap(), TapResult.completed);
      expect(c.phase, CounterPhase.complete);
      expect(c.active!.count, 7);
      expect(c.active!.completedAtMs, isNotNull);
      expect(c.finish(), isTrue);
    });

    test('an 8th tap does nothing', () {
      final m = _Mono();
      final c = _counter(m);
      _tapN(c, m, 7);
      m.ms(5000);
      expect(c.tap(), TapResult.ignoredComplete);
      expect(c.active!.count, 7);
      expect(c.sessions, hasLength(1));
    });

    test('finish is refused before the end', () {
      final m = _Mono();
      final c = _counter(m);
      _tapN(c, m, 6);
      expect(c.finish(), isFalse);
      expect(c.phase, CounterPhase.inProgress);
    });
  });

  group('debounce', () {
    for (final (ms, counts) in [(1, false), (699, false), (700, true), (701, true)]) {
      test('a second tap $ms ms after the first ${counts ? 'counts' : 'is swallowed'}', () {
        final m = _Mono();
        final c = _counter(m);
        m.ms(10000);
        expect(c.tap(), TapResult.counted);
        m.ms(ms);
        expect(c.tap(), counts ? TapResult.counted : TapResult.debounced);
        expect(c.active!.count, counts ? 2 : 1);
      });
    }

    test('a swallowed tap does not push the window: 400 + 400 ms counts the second', () {
      final m = _Mono();
      final c = _counter(m);
      m.ms(5000);
      expect(c.tap(), TapResult.counted);
      m.ms(400);
      expect(c.tap(), TapResult.debounced);
      m.ms(400); // 800 ms after the COUNTED tap
      expect(c.tap(), TapResult.counted);
    });

    test('a pocket burst of ten taps inside half a second counts once', () {
      final m = _Mono();
      final c = _counter(m);
      m.ms(3000);
      for (var i = 0; i < 10; i++) {
        c.tap();
        m.ms(50);
      }
      expect(c.active!.count, 1);
    });

    test('the debounce is configurable', () {
      final m = _Mono();
      final c = _counter(m, debounce: const Duration(milliseconds: 2000));
      m.ms(5000);
      c.tap();
      m.ms(1999);
      expect(c.tap(), TapResult.debounced);
      m.ms(1);
      expect(c.tap(), TapResult.counted);
    });

    test('the wall clock jumping back, forward or to another time zone changes nothing', () {
      final m = _Mono();
      final w = _Wall();
      final c = _counter(m, wall: w);
      m.ms(5000);
      expect(c.tap(), TapResult.counted);
      // Clock steps back an hour: a naive wall-clock debounce would swallow
      // the next, perfectly legitimate tap (negative elapsed).
      w.now = w.now.subtract(const Duration(hours: 1));
      m.ms(700);
      expect(c.tap(), TapResult.counted);
      // Clock jumps a day forward: a naive version would let a double-tap through.
      w.now = w.now.add(const Duration(days: 1));
      m.ms(100);
      expect(c.tap(), TapResult.debounced);
      // Time zone change (UTC+3 to UTC-8): same instant, other offset.
      w.now = DateTime.parse('2026-11-10T01:00:00-08:00');
      m.ms(600);
      expect(c.tap(), TapResult.counted);
      expect(c.active!.count, 3);
    });

    test('undo and resume open the window for the next deliberate tap', () {
      final m = _Mono();
      final c = _counter(m);
      m.ms(5000);
      c.tap();
      m.ms(100);
      expect(c.undo(), isTrue);
      expect(c.tap(), TapResult.counted);
      m.ms(100);
      c.pause();
      c.resume();
      expect(c.tap(), TapResult.counted);
    });
  });

  group('undo', () {
    test('at 0 does nothing', () {
      final c = _counter(_Mono());
      expect(c.undo(), isFalse);
      expect(c.active!.count, 0);
    });

    test('takes back the last tap, several times, down to 0 and no further', () {
      final m = _Mono();
      final c = _counter(m);
      _tapN(c, m, 3);
      expect(c.undo(), isTrue);
      expect(c.undo(), isTrue);
      expect(c.active!.count, 1);
      expect(c.undo(), isTrue);
      expect(c.undo(), isFalse);
      expect(c.phase, CounterPhase.notStarted);
    });

    test('at complete it reopens the session at round 7', () {
      final m = _Mono();
      final c = _counter(m);
      _tapN(c, m, 7);
      expect(c.undo(), isTrue);
      expect(c.phase, CounterPhase.inProgress);
      expect(c.active!.currentRound, 7);
      expect(c.active!.completedAtMs, isNull);
      expect(c.finish(), isFalse);
      m.ms(1000);
      expect(c.tap(), TapResult.completed);
    });

    test('cannot take back what a manual correction set', () {
      final m = _Mono();
      final c = _counter(m);
      _tapN(c, m, 2);
      c.setRound(5);
      expect(c.canUndo, isFalse);
      expect(c.undo(), isFalse);
      expect(c.active!.currentRound, 5);
      _tapN(c, m, 1);
      expect(c.undo(), isTrue);
      expect(c.active!.currentRound, 5);
    });
  });

  group('manual correction', () {
    test('sets the round being walked (1..7)', () {
      final c = _counter(_Mono());
      for (var n = 1; n <= 7; n++) {
        expect(c.setRound(n), isTrue);
        expect(c.active!.currentRound, n);
        expect(c.active!.count, n - 1);
      }
      expect(c.phase, CounterPhase.inProgress); // never complete by correction
    });

    test('rejects 0, 8 and negatives without changing anything', () {
      final m = _Mono();
      final c = _counter(m);
      _tapN(c, m, 3);
      for (final bad in [0, -1, 8, 100]) {
        expect(c.setRound(bad), isFalse, reason: '$bad');
        expect(c.active!.count, 3);
      }
    });

    test('works while paused and reopens a complete session', () {
      final m = _Mono();
      final c = _counter(m);
      _tapN(c, m, 7);
      expect(c.setRound(7), isTrue);
      expect(c.phase, CounterPhase.inProgress);
      c.pause();
      expect(c.setRound(2), isTrue);
      expect(c.phase, CounterPhase.paused);
      expect(c.active!.currentRound, 2);
    });
  });

  group('pause and resume', () {
    test('a paused session ignores taps until resumed', () {
      final m = _Mono();
      final c = _counter(m);
      _tapN(c, m, 2);
      expect(c.pause(), isTrue);
      expect(c.pause(), isFalse);
      m.ms(5000);
      expect(c.tap(), TapResult.paused);
      expect(c.active!.count, 2);
      expect(c.resume(), isTrue);
      expect(c.resume(), isFalse);
      expect(c.tap(), TapResult.counted);
    });

    test('a complete session cannot be paused', () {
      final m = _Mono();
      final c = _counter(m);
      _tapN(c, m, 7);
      expect(c.pause(), isFalse);
    });
  });

  group('sa\'i direction', () {
    test('legs alternate from the start point and the 7th ends at the other end', () {
      final m = _Mono();
      final c = _counter(m, kind: RoundKind.sai);
      final heads = <SaiPoint?>[];
      for (var i = 0; i < 7; i++) {
        heads.add(c.active!.headingTo);
        _tapN(c, m, 1);
      }
      expect(heads, [
        SaiPoint.marwa,
        SaiPoint.safa,
        SaiPoint.marwa,
        SaiPoint.safa,
        SaiPoint.marwa,
        SaiPoint.safa,
        SaiPoint.marwa,
      ]);
      expect(c.active!.headingTo, isNull);
      expect(c.active!.endPoint, SaiPoint.marwa);
    });

    test('the heading is derived from the start point, so a Marwa start mirrors it', () {
      final c = RoundCounter(monotonic: _Mono().call)..start(RoundKind.sai, saiStart: SaiPoint.marwa);
      expect(c.active!.headingTo, SaiPoint.safa);
      expect(c.active!.endPoint, SaiPoint.safa);
    });

    test('the tawaf has no heading', () {
      final c = _counter(_Mono());
      expect(c.active!.headingTo, isNull);
      expect(c.active!.endPoint, isNull);
    });
  });

  group('sessions', () {
    test('a second tawaf the same day is a new session; the first is kept complete', () {
      final m = _Mono();
      final c = _counter(m);
      _tapN(c, m, 7);
      expect(c.start(RoundKind.tawaf), isTrue);
      expect(c.sessions, hasLength(2));
      expect(c.phase, CounterPhase.notStarted);
      expect(c.sessions.first.isComplete, isTrue);
      expect(c.completedOf(RoundKind.tawaf), hasLength(1));
      _tapN(c, m, 3);
      expect(c.active!.count, 3);
      expect(c.sessions.first.count, 7);
      expect(c.sessions.first.id, isNot(c.sessions.last.id));
    });

    test('starting over a half-done session is refused unless abandoning it', () {
      final m = _Mono();
      final c = _counter(m);
      _tapN(c, m, 3);
      expect(c.start(RoundKind.sai), isFalse);
      expect(c.sessions, hasLength(1));
      expect(c.start(RoundKind.sai, abandonCurrent: true), isTrue);
      expect(c.sessions, hasLength(2));
      expect(c.sessions.first.abandoned, isTrue);
      expect(c.sessions.first.count, 3);
      expect(c.completedOf(RoundKind.tawaf), isEmpty);
    });

    test('a session with nothing counted is replaced, not piled up', () {
      final c = _counter(_Mono());
      expect(c.start(RoundKind.sai), isTrue);
      expect(c.sessions, hasLength(1));
      expect(c.active!.kind, RoundKind.sai);
    });

    test('after complete only an explicit start counts again', () {
      final m = _Mono();
      final c = _counter(m);
      _tapN(c, m, 7);
      m.ms(1000);
      expect(c.tap(), TapResult.ignoredComplete);
      c.start(RoundKind.tawaf);
      m.ms(1000);
      expect(c.tap(), TapResult.counted);
    });

    test('the history is capped at the newest ${RoundCounter.maxSessions}', () {
      final m = _Mono();
      final c = _counter(m);
      for (var i = 0; i < RoundCounter.maxSessions + 5; i++) {
        _tapN(c, m, 7);
        c.start(RoundKind.tawaf);
      }
      expect(c.sessions.length, RoundCounter.maxSessions);
    });
  });

  group('kill and restore', () {
    RoundCounter restore(RoundCounter c, _Mono m) {
      // Through real JSON text, as the disk would hold it.
      final json = jsonDecode(jsonEncode(c.toJson()));
      return RoundCounter.fromJson(json, monotonic: m.call, newId: () => 'x${_ids++}');
    }

    test('mid-round: same state, can keep counting and undo', () {
      final m = _Mono();
      final c = _counter(m);
      _tapN(c, m, 4);
      final back = restore(c, _Mono());
      expect(back.sessions, c.sessions);
      expect(back.phase, CounterPhase.inProgress);
      expect(back.active!.currentRound, 5);
      expect(back.canUndo, isTrue);
      // A fresh process has a fresh monotonic clock: the first tap counts.
      expect(back.tap(), TapResult.counted);
      expect(back.active!.count, 5);
    });

    test('paused, complete and sa\'i sessions survive', () {
      final m = _Mono();
      final c = _counter(m, kind: RoundKind.sai);
      _tapN(c, m, 7);
      c.start(RoundKind.tawaf);
      _tapN(c, m, 2);
      c.pause();
      final back = restore(c, m);
      expect(back.sessions, c.sessions);
      expect(back.phase, CounterPhase.paused);
      expect(back.sessions.first.isComplete, isTrue);
      expect(back.sessions.first.kind, RoundKind.sai);
    });

    test('a time-zone change between save and restore changes nothing', () {
      final m = _Mono();
      final w = _Wall();
      final c = _counter(m, wall: w);
      _tapN(c, m, 7);
      final back = restore(c, m);
      expect(back.active!.completedAtMs, c.active!.completedAtMs);
      expect(back.phase, CounterPhase.complete);
    });

    test('toJson is versioned', () {
      expect(_counter(_Mono()).toJson()['v'], RoundCounter.version);
    });

    test('damaged or missing data gives an empty counter, never a crash', () {
      for (final bad in <Object?>[null, 5, 'x', <Object?>[], {'sessions': 7}, {'sessions': [1, null, 'a']}]) {
        final c = RoundCounter.fromJson(bad);
        expect(c.sessions, isEmpty, reason: '$bad');
        expect(c.tap(), TapResult.noSession);
      }
    });

    test('out-of-range numbers are clamped; a damaged session is dropped, the rest kept', () {
      final c = RoundCounter.fromJson({
        'v': 1,
        'sessions': [
          {'id': 'a', 'kind': 'tawaf', 'count': 99, 'undoable': 50, 'paused': true},
          {'id': 'b', 'kind': 'nope', 'count': 1},
          {'id': 'c', 'kind': 'sai', 'count': -4, 'undoable': 3},
        ],
      });
      expect(c.sessions.map((s) => s.id), ['a', 'c']);
      expect(c.sessions.first.count, 7);
      expect(c.sessions.first.undoable, 7);
      expect(c.sessions.first.paused, isFalse); // complete cannot be paused
      expect(c.sessions.last.count, 0);
      expect(c.sessions.last.undoable, 0);
    });

    test('a newer format version is still read (a lost count is worse than a misread field)', () {
      final c = RoundCounter.fromJson({
        'v': 99,
        'sessions': [
          {'id': 'a', 'kind': 'tawaf', 'count': 3, 'future': true},
        ],
      });
      expect(c.active!.count, 3);
    });
  });
}
