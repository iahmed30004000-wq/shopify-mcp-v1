// The pure rules of the kids shell: screen time at its boundary, across
// midnight, with the clock changed and with the limit off; the gate's pause;
// what is stored; and the router's one-way redirect.
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/features/kids/shell/domain/kids_logic.dart';

void main() {
  final noon = DateTime(2026, 9, 28, 12);

  group('screen time at the limit', () {
    const limit = 30;

    test('limit - 1 second still plays, the limit and limit + 1 end', () {
      expect(ScreenTimeRules.statusOf(limit, limit * 60 - 1), isNot(ScreenTimeStatus.ended));
      expect(ScreenTimeRules.statusOf(limit, limit * 60), ScreenTimeStatus.ended);
      expect(ScreenTimeRules.statusOf(limit, limit * 60 + 1), ScreenTimeStatus.ended);
      expect(ScreenTimeRules.remainingSeconds(limit, limit * 60 + 500), 0, reason: 'never negative');
    });

    test('limit - 1 minute is the warning, well before is plain play', () {
      expect(ScreenTimeRules.statusOf(limit, 0), ScreenTimeStatus.playing);
      expect(ScreenTimeRules.statusOf(limit, (limit - 5) * 60 - 1), ScreenTimeStatus.playing);
      expect(ScreenTimeRules.statusOf(limit, (limit - 5) * 60), ScreenTimeStatus.warning);
      expect(ScreenTimeRules.statusOf(limit, (limit - 1) * 60), ScreenTimeStatus.warning);
    });

    test('a limit of 0 is "off": nothing ever ends', () {
      expect(ScreenTimeRules.statusOf(0, 0), ScreenTimeStatus.off);
      expect(ScreenTimeRules.statusOf(0, 99 * 3600), ScreenTimeStatus.off);
      expect(ScreenTimeRules.remainingSeconds(0, 5), isNull);
    });

    test('the stepper moves by five minutes inside 0 to the maximum', () {
      expect(ScreenTimeRules.stepped(0, up: true), 5);
      expect(ScreenTimeRules.stepped(5, up: false), 0);
      expect(ScreenTimeRules.stepped(0, up: false), 0);
      expect(ScreenTimeRules.stepped(ScreenTimeRules.maxLimitMinutes, up: true), ScreenTimeRules.maxLimitMinutes);
    });
  });

  group('the daily ledger', () {
    test('adds play on the same day', () {
      var l = const ScreenTimeLedger().add(60, noon);
      l = l.add(30, noon.add(const Duration(minutes: 5)));
      expect(l.usedSeconds, 90);
      expect(l.dayKey, kidsDayKey(noon));
    });

    test('midnight starts a fresh day', () {
      final late = DateTime(2026, 9, 28, 23, 59, 59);
      final l = const ScreenTimeLedger().add(1700, late);
      expect(l.usedSeconds, 1700);
      final next = l.rolledTo(DateTime(2026, 9, 29, 0, 0, 0));
      expect(next.usedSeconds, 0);
      expect(next.dayKey, 20260929);
      // Adding play after midnight also rolls first.
      expect(l.add(5, DateTime(2026, 9, 29, 0, 0, 1)).usedSeconds, 5);
    });

    test('a clock turned BACK never hands out a fresh day', () {
      final l = const ScreenTimeLedger().add(1700, noon);
      final back = l.rolledTo(noon.subtract(const Duration(days: 2)));
      expect(back.usedSeconds, 1700);
      expect(back.dayKey, kidsDayKey(noon));
      expect(l.add(10, noon.subtract(const Duration(days: 2))).usedSeconds, 1710);
    });

    test('negative play is ignored', () {
      expect(const ScreenTimeLedger().add(-50, noon).usedSeconds, 0);
    });

    test('a month and a year end roll over too', () {
      expect(const ScreenTimeLedger(dayKey: 20260930, usedSeconds: 9).rolledTo(DateTime(2026, 10, 1)).usedSeconds, 0);
      expect(const ScreenTimeLedger(dayKey: 20261231, usedSeconds: 9).rolledTo(DateTime(2027, 1, 1)).usedSeconds, 0);
    });
  });

  group('one tick of play', () {
    test('is the time since the last tick, rounded', () {
      expect(ScreenTimeRules.tickSeconds(noon, noon.add(const Duration(seconds: 1))), 1);
      expect(ScreenTimeRules.tickSeconds(noon, noon.add(const Duration(milliseconds: 1400))), 1);
    });

    test('a clock set forward (an hour) counts at most two seconds', () {
      expect(ScreenTimeRules.tickSeconds(noon, noon.add(const Duration(hours: 1))), 2);
    });

    test('a clock set back counts nothing', () {
      expect(ScreenTimeRules.tickSeconds(noon, noon.subtract(const Duration(hours: 3))), 0);
      expect(ScreenTimeRules.tickSeconds(noon, noon), 0);
    });
  });

  group('the gate pause', () {
    test('two wrong tries are free; the third starts 30 seconds', () {
      var b = GateBackoff.none;
      b = b.afterWrong(noon);
      expect(b.pausedAt(noon), isFalse);
      b = b.afterWrong(noon);
      expect(b.pausedAt(noon), isFalse);
      b = b.afterWrong(noon);
      expect(b.pausedAt(noon), isTrue);
      expect(b.remaining(noon), const Duration(seconds: 30));
      expect(b.pausedAt(noon.add(const Duration(seconds: 29))), isTrue);
      expect(b.pausedAt(noon.add(const Duration(seconds: 30))), isFalse);
      expect(b.failures, 0, reason: 'three fresh tries after the pause');
    });

    test('a clock turned back cannot stretch the pause', () {
      final b = GateBackoff.none.afterWrong(noon).afterWrong(noon).afterWrong(noon);
      final back = noon.subtract(const Duration(hours: 5));
      expect(b.normalizedAt(back).remaining(back), const Duration(seconds: 30));
      expect(b.normalizedAt(noon), b, reason: 'a normal pause is left alone');
    });

    test('survives storage', () {
      final b = GateBackoff.none.afterWrong(noon).afterWrong(noon);
      expect(GateBackoff.fromJson(b.toJson()), b);
      expect(GateBackoff.fromJson('junk'), GateBackoff.none);
    });
  });

  group('what is stored', () {
    test('round-trips', () {
      final s = KidsModeState(
        on: true,
        limitMinutes: 45,
        ledger: const ScreenTimeLedger(dayKey: 20260928, usedSeconds: 600),
        backoff: GateBackoff.none.afterWrong(noon),
      );
      expect(KidsModeState.decode(s.encode()), s);
    });

    test('nothing stored is off; junk is off; junk that still says on stays on', () {
      expect(KidsModeState.decode(null), KidsModeState.off);
      expect(KidsModeState.decode(''), KidsModeState.off);
      expect(KidsModeState.decode('not json'), KidsModeState.off);
      expect(KidsModeState.decode('{"on":true,"limit":'), isA<KidsModeState>().having((s) => s.on, 'on', isTrue));
    });

    test('an absurd limit is kept in range, a negative one is none', () {
      expect(KidsModeState.decode('{"on":true,"limit":99999}').limitMinutes, ScreenTimeRules.maxLimitMinutes);
      expect(KidsModeState.decode('{"on":true,"limit":-4}').limitMinutes, 0);
    });
  });

  group('the router redirect', () {
    String? r(bool on, String loc) => kidsModeRedirect(kidsOn: on, location: loc);

    test('kids mode on: everything outside /kids goes to /kids', () {
      for (final loc in [
        '/',
        '/settings',
        '/ledger/wallet/x',
        '/planet/health?item=a:b',
        '/meds?tab=meds',
        '/onboarding',
      ]) {
        expect(r(true, loc), AppRoutes.kids, reason: loc);
      }
    });

    test('kids mode on: /kids and below stay', () {
      for (final loc in ['/kids', '/kids/s/letters', '/kids?x=1', '/kids/s/letters?x=%2Fsettings']) {
        expect(r(true, loc), isNull, reason: loc);
      }
    });

    test('look-alikes and path tricks do not count as kids', () {
      for (final loc in ['/kidsx', '/kids-more', '//kids', '/kids/../settings', '/kids/s/../../ledger', '/x/kids']) {
        expect(isKidsLocation(loc), isFalse, reason: loc);
        expect(r(true, loc), AppRoutes.kids, reason: loc);
      }
    });

    test('kids mode off: the shell is closed and goes home', () {
      expect(r(false, '/kids'), AppRoutes.home);
      expect(r(false, '/kids/s/letters'), AppRoutes.home);
      expect(r(false, '/settings'), isNull);
      expect(r(false, '/'), isNull);
    });
  });
}
