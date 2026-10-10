import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/lock/domain/lock_record.dart';
import 'package:madar/features/lock/domain/lock_session.dart';
import 'package:madar/features/lock/render/assembly.dart';

import 'lock_test_utils.dart';

void main() {
  group('PinBackoff', () {
    test('four free mistakes, then 30 s doubling, capped at an hour', () {
      expect([for (var n = 0; n < 5; n++) PinBackoff.lockoutAfter(n)], everyElement(Duration.zero));
      expect(PinBackoff.lockoutAfter(4), Duration.zero);
      expect(PinBackoff.lockoutAfter(5), const Duration(seconds: 30));
      expect(PinBackoff.lockoutAfter(6), const Duration(minutes: 1));
      expect(PinBackoff.lockoutAfter(7), const Duration(minutes: 2));
      expect(PinBackoff.lockoutAfter(8), const Duration(minutes: 4));
      expect(PinBackoff.lockoutAfter(11), const Duration(minutes: 32));
      expect(PinBackoff.lockoutAfter(12), const Duration(hours: 1));
      expect(PinBackoff.lockoutAfter(500), const Duration(hours: 1));
    });

    test('remaining tries before the first lockout', () {
      expect(PinBackoff.remainingBeforeLockout(0), 5);
      expect(PinBackoff.remainingBeforeLockout(1), 4);
      expect(PinBackoff.remainingBeforeLockout(5), 0);
      expect(PinBackoff.remainingBeforeLockout(9), 0);
    });
  });

  group('LockRecord', () {
    final now = DateTime(2026, 9, 28, 12);

    test('failures accumulate and lock the keypad from the fifth', () {
      var r = LockRecord.empty;
      for (var i = 0; i < 4; i++) {
        r = r.afterFailure(now);
        expect(r.lockedOutAt(now), isFalse);
      }
      r = r.afterFailure(now);
      expect(r.failures, 5);
      expect(r.lockedOutAt(now), isTrue);
      expect(r.remainingLockout(now), const Duration(seconds: 30));
      expect(r.lockedOutAt(now.add(const Duration(seconds: 30))), isFalse);
      r = r.afterFailure(now.add(const Duration(seconds: 31)));
      expect(r.remainingLockout(now.add(const Duration(seconds: 31))), const Duration(minutes: 1));
      r = r.afterSuccess();
      expect(r.failures, 0);
      expect(r.lockedUntil, isNull);
    });

    test('round trip through secure-storage JSON', () async {
      final record = LockRecord(
        pin: await fastHasher().hash('2580'),
        biometrics: true,
        failures: 3,
        lockedUntil: DateTime.fromMillisecondsSinceEpoch(1790000000000),
      );
      expect(LockRecord.decode(record.encode()), record);
      expect(record.encode(), isNot(contains('2580')));
    });

    test('missing or damaged entries decode to an unarmed record', () {
      expect(LockRecord.decode(null), LockRecord.empty);
      expect(LockRecord.decode(''), LockRecord.empty);
      expect(LockRecord.decode('{not json'), LockRecord.empty);
      expect(LockRecord.decode('{"pin": {"alg": "x"}, "bio": true}').hasPin, isFalse);
    });

    test('hint mirrors the record (fingerprint only with a PIN)', () async {
      expect(LockHint.of(LockRecord.empty), LockHint.none);
      expect(LockHint.of(const LockRecord(biometrics: true)), LockHint.none);
      final armed = LockRecord(pin: await fastHasher().hash('1397'), biometrics: true);
      expect(LockHint.of(armed), const LockHint(pin: true, biometrics: true));
      expect(LockHint.decode(LockHint.of(armed).encode()), LockHint.of(armed));
      expect(LockHint.decode('garbage'), LockHint.none);
    });
  });

  group('LockSession', () {
    late TestClock clock;
    LockSession session({bool armed = true, Duration after = const Duration(minutes: 2)}) =>
        LockSession(clock: clock.call, armed: armed, lockAfter: after)..coldStart();

    void leave(LockSession s) {
      s
        ..onLifecycle(AppLifecycleState.inactive)
        ..onLifecycle(AppLifecycleState.hidden)
        ..onLifecycle(AppLifecycleState.paused);
    }

    void comeBack(LockSession s) {
      s
        ..onLifecycle(AppLifecycleState.hidden)
        ..onLifecycle(AppLifecycleState.inactive)
        ..onLifecycle(AppLifecycleState.resumed);
    }

    void unlock(LockSession s) {
      s
        ..authenticated()
        ..revealed();
    }

    setUp(() => clock = TestClock(DateTime(2026, 9, 28, 9)));

    test('cold start: locked when armed, open when not', () {
      expect(session().phase, LockPhase.locked);
      expect(session(armed: false).phase, LockPhase.open);
    });

    test('unlock goes through revealing to open', () {
      final s = session();
      s.authenticated();
      expect(s.phase, LockPhase.revealing);
      s.revealed();
      expect(s.phase, LockPhase.open);
    });

    test('back within the time-out stays open; after it, locks', () {
      final s = session();
      unlock(s);
      leave(s);
      clock.advance(const Duration(minutes: 1, seconds: 59));
      comeBack(s);
      expect(s.phase, LockPhase.open);

      leave(s);
      clock.advance(const Duration(minutes: 2));
      comeBack(s);
      expect(s.phase, LockPhase.locked);
    });

    test('the time-out counts from when the app was hidden, not paused again', () {
      final s = session();
      unlock(s);
      s.onLifecycle(AppLifecycleState.inactive);
      s.onLifecycle(AppLifecycleState.hidden);
      clock.advance(const Duration(minutes: 1));
      s.onLifecycle(AppLifecycleState.paused);
      clock.advance(const Duration(minutes: 1));
      comeBack(s);
      expect(s.phase, LockPhase.locked);
    });

    test('lock after 0 locks on every return; configurable', () {
      final s = session(after: Duration.zero);
      unlock(s);
      leave(s);
      comeBack(s);
      expect(s.phase, LockPhase.locked);

      final t = session(after: const Duration(minutes: 15));
      unlock(t);
      leave(t);
      clock.advance(const Duration(minutes: 14));
      comeBack(t);
      expect(t.phase, LockPhase.open);
      t.lockAfter = const Duration(minutes: 5);
      leave(t);
      clock.advance(const Duration(minutes: 5));
      comeBack(t);
      expect(t.phase, LockPhase.locked);
    });

    test('a clock that moved backwards locks (when in doubt, lock)', () {
      final s = session();
      unlock(s);
      leave(s);
      clock.advance(const Duration(hours: -3));
      comeBack(s);
      expect(s.phase, LockPhase.locked);
      expect(
        LockSession.shouldLock(leftAt: DateTime(2026), now: DateTime(2025), lockAfter: const Duration(days: 9)),
        isTrue,
      );
    });

    test('inactive raises the privacy shield over an open app; resume lowers it', () {
      final s = session();
      unlock(s);
      s.onLifecycle(AppLifecycleState.inactive);
      expect(s.shielded, isTrue);
      s.onLifecycle(AppLifecycleState.resumed);
      expect(s.shielded, isFalse);
      expect(s.phase, LockPhase.open, reason: 'the notification shade never locks');
    });

    test('no shield while locked, or when disarmed', () {
      final s = session();
      s.onLifecycle(AppLifecycleState.inactive);
      expect(s.shielded, isFalse);
      final d = session(armed: false);
      leave(d);
      expect(d.shielded, isFalse);
      clock.advance(const Duration(hours: 1));
      comeBack(d);
      expect(d.phase, LockPhase.open);
    });

    test('suspended (own prompt / picker): no shield, time-out stretched to the grace – never dropped', () {
      final s = session(after: Duration.zero);
      unlock(s);
      s.suspend();
      leave(s);
      expect(s.shielded, isFalse);
      clock.advance(LockSession.suspendedGrace - const Duration(seconds: 1));
      comeBack(s);
      s.unsuspend();
      expect(s.phase, LockPhase.open);
      // …and works again afterwards.
      leave(s);
      comeBack(s);
      expect(s.phase, LockPhase.locked);
      // A flow left open while the owner walks away still locks.
      unlock(s);
      s.suspend();
      leave(s);
      clock.advance(const Duration(hours: 1));
      comeBack(s);
      s.unsuspend();
      expect(s.phase, LockPhase.locked);
    });

    test('arming never locks by itself; disarming opens', () {
      final s = session(armed: false);
      s.setArmed(true);
      expect(s.phase, LockPhase.open);
      s.setArmed(true, lockNow: true);
      expect(s.phase, LockPhase.locked);
      s.setArmed(false);
      expect(s.phase, LockPhase.open);
      s.lock();
      expect(s.phase, LockPhase.open, reason: 'lock() needs an armed lock');
    });
  });

  group('AssemblyTimeline', () {
    test('every part is scattered at 0 and at rest at 1', () {
      for (final part in AstrolabePart.values) {
        expect(AssemblyTimeline.local(part, 0), 0, reason: '$part');
        expect(AssemblyTimeline.local(part, 1), 1, reason: '$part');
        expect(AssemblyTimeline.pose(part, 1).isRest, isTrue, reason: '$part');
        expect(AssemblyTimeline.pose(part, 1).opacity, 1, reason: '$part');
      }
      expect(AssemblyTimeline.pose(AstrolabePart.limb, 0).isRest, isFalse);
      expect(AssemblyTimeline.pose(AstrolabePart.hub, 0).opacity, 0);
    });

    test('parts arrive in order: limb, plate, numerals, rete, stars, rule, hub', () {
      double end(AstrolabePart p) => AssemblyTimeline.windows[p]!.$2;
      final order = AstrolabePart.values.map(end).toList();
      expect(order, orderedEquals([...order]..sort()));
    });

    test('the lock-in spring overshoots a little and settles', () {
      final ds = [for (var i = 0; i <= 100; i++) AssemblyTimeline.displacement(i / 100)];
      expect(ds.first, 1);
      expect(ds.last, 0);
      final minimum = ds.reduce((a, b) => a < b ? a : b);
      expect(minimum, lessThan(0), reason: 'overshoot');
      expect(minimum, greaterThan(-0.15), reason: 'only a hair');
    });

    test('hold and reading targets stop short of completion', () {
      expect(AssemblyTimeline.holdTarget, lessThan(AssemblyTimeline.readingTarget));
      expect(
        AssemblyTimeline.local(AstrolabePart.hub, AssemblyTimeline.readingTarget),
        0,
        reason: 'the core star ignites only on success',
      );
    });

    test('each PIN digit assembles more; the hub waits for acceptance', () {
      final steps = [for (var d = 0; d <= 6; d++) AssemblyTimeline.pinTarget(d, 6)];
      for (var i = 1; i < steps.length; i++) {
        expect(steps[i], greaterThan(steps[i - 1]));
      }
      expect(steps.first, AssemblyTimeline.pinBase);
      expect(AssemblyTimeline.local(AstrolabePart.hub, steps.last), lessThan(0.25));
    });

    test('lockedBetween reports parts crossing their end going forward only', () {
      expect(AssemblyTimeline.lockedBetween(0, 0.4), [AstrolabePart.limb]);
      expect(AssemblyTimeline.lockedBetween(0.37, 1), hasLength(6));
      expect(AssemblyTimeline.lockedBetween(1, 0), isEmpty);
    });

    test('staggered items start one after another', () {
      final firsts = [for (var i = 0; i < 24; i++) AssemblyTimeline.staggered(AstrolabePart.numerals, i, 24, 0.3)];
      for (var i = 1; i < firsts.length; i++) {
        expect(firsts[i], lessThanOrEqualTo(firsts[i - 1]));
      }
      expect(AssemblyTimeline.staggered(AstrolabePart.numerals, 23, 24, 1), 1);
    });
  });
}
