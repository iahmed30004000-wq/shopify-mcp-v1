import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/fasting/domain/fasting_log.dart';
import 'package:madar/features/fasting/domain/fasting_models.dart';
import 'package:madar/features/wird/domain/calendar_days.dart';

import 'fasting_test_support.dart';

FastLogEntry fasted(DateTime day, {FastKind? kind, FastLogSource source = FastLogSource.reminded}) =>
    FastLogEntry(day: day, kind: kind, fasted: true, source: source);

void main() {
  final y = HijriYearView(1448);

  group('settings JSON', () {
    test('round trip and defaults', () {
      const c = FastingConfig(hijriOffset: -1, shawwalStartDay: 9, nudgeDay: 15, disabled: {FastKind.thursday, FastKind.arafah});
      expect(FastingConfig.fromJson(c.toJson()), c);
      expect(FastingConfig.fromJson(null), const FastingConfig());
      expect(const FastingConfig().hijriOffset, 0);
      expect(const FastingConfig().effectiveShawwalStart, 2);
      expect(const FastingConfig().effectiveNudgeDay, 1);
      expect(const FastingConfig().disabled, isEmpty, reason: 'fresh install reminds everything');
    });

    test('garbage is tolerated', () {
      final c = FastingConfig.fromJson({'hijriOffset': 9, 'shawwalStartDay': 'x', 'disabled': ['nope', 'monday', 3]});
      expect(c.hijriOffset, 2);
      expect(c.shawwalStartDay, 2);
      expect(c.disabled, {FastKind.monday});
    });
  });

  group('intention and log JSON', () {
    test('intention round trip; malformed rows are dropped', () {
      final i = FastIntention(day: DateTime(2026, 11, 16, 15, 40), choice: FastIntentionChoice.no);
      expect(i.day, DateTime(2026, 11, 16));
      expect(FastIntention.fromJson(i.toJson()), i);
      expect(i.toJson(), {'day': '2026-11-16', 'choice': 'no'});
      expect(FastIntention.fromJson({'day': 'x', 'choice': 'yes'}), isNull);
      expect(FastIntention.fromJson({'day': '2026-11-16', 'choice': 'maybe'}), isNull);
      expect(FastIntention.fromJson('nope'), isNull);
    });

    test('log entry round trip, with and without a kind', () {
      final e = FastLogEntry(day: DateTime(2026, 11, 16), kind: FastKind.monday, fasted: true, source: FastLogSource.reminded);
      expect(FastLogEntry.fromJson(e.toJson()), e);
      final manual = FastLogEntry(day: DateTime(2026, 11, 17), fasted: false, source: FastLogSource.manual);
      expect(FastLogEntry.fromJson(manual.toJson()), manual);
      expect(manual.toJson()['kind'], isNull);
      expect(FastLogEntry.fromJson({'day': '2026-11-17', 'fasted': 'yes'}), isNull);
      expect(FastLogEntry.fromJson({'day': '2026-11-17', 'fasted': true, 'source': '???'})!.source, FastLogSource.manual);
    });

    test('upsert keeps one entry per day', () {
      final a = fasted(DateTime(2026, 11, 16), kind: FastKind.monday);
      final b = FastLogEntry(day: DateTime(2026, 11, 16), fasted: false, source: FastLogSource.manual);
      final log = FastLogEntry.upsert([a], b);
      expect(log, [b]);
      expect(FastLogEntry.upsert(log, fasted(DateTime(2026, 11, 17))).length, 2);
    });
  });

  group('counting', () {
    test('per Hijri month / year and Gregorian month / year', () {
      final log = [
        fasted(y.civil(2, 3, 0)),
        fasted(y.civil(2, 4, 0)),
        fasted(y.civil(3, 1, 0)),
        FastLogEntry(day: y.civil(3, 2, 0), fasted: false, source: FastLogSource.manual),
        fasted(y.civil(3, 1, 0), source: FastLogSource.manual), // same day twice
      ];
      final s = FastingStats(log, cfg(0));
      expect(s.totalFastedDays, 3, reason: 'a day counts once, not-fasted entries never');
      expect(s.fastedInHijriMonth(1448, 2), 2);
      expect(s.fastedInHijriMonth(1448, 3), 1);
      expect(s.fastedInHijriYear(1448), 3);
      expect(s.fastedInHijriYear(1449), 0);
      final g = y.civil(2, 3, 0);
      expect(s.fastedInGregorianMonth(g.year, g.month), greaterThan(0));
      expect(s.fastedInGregorianYear(g.year) + s.fastedInGregorianYear(g.year + 1), 3);
    });

    test('the last entry for a day wins (fasted then un-fasted)', () {
      final d = y.civil(2, 3, 0);
      final s = FastingStats([fasted(d), FastLogEntry(day: d, fasted: false, source: FastLogSource.manual)], cfg(0));
      expect(s.totalFastedDays, 0);
    });

    test('the offset moves which Hijri month a logged day belongs to', () {
      // The last day of Rajab, calculated: with +1 it is already 1 Sha\'ban.
      final lastRajab = CalendarDays.add(y.starts[8]!, -1);
      final s0 = FastingStats([fasted(lastRajab)], cfg(0));
      final s1 = FastingStats([fasted(lastRajab)], cfg(1));
      expect(s0.fastedInHijriMonth(1448, 7), 1);
      expect(s1.fastedInHijriMonth(1448, 8), 1);
      expect(s1.fastedInHijriMonth(1448, 7), 0);
    });

    test('six of Shawwal: n of 6, counted apart from the white days', () {
      final log = [
        for (var d = 2; d <= 4; d++) fasted(y.civil(10, d, 0), kind: FastKind.sixShawwal),
        fasted(y.civil(10, 14, 0), kind: FastKind.whiteDay),
        fasted(y.civil(10, 15, 0), kind: FastKind.whiteDay),
        fasted(y.civil(11, 13, 0), kind: FastKind.whiteDay),
        fasted(y.civil(9, 5, 0), source: FastLogSource.manual), // Ramadan: a day, not a white day
      ];
      final s = FastingStats(log, cfg(0));
      expect(s.sixShawwalProgress(1448), (done: 5, goal: 6), reason: 'days 2,3,4,14,15 of Shawwal');
      expect(s.whiteDaysFastedInMonth(1448, 10), 2);
      expect(s.whiteDaysFastedInMonth(1448, 11), 1);
      expect(s.whiteDaysFastedInYear(1448), 3);
      expect(s.fastedInHijriMonth(1448, 9), 1, reason: 'Ramadan days still count as fasted days');
      expect(s.sixShawwalProgress(1449), (done: 0, goal: 6));
    });

    test('progress is capped at six, and never counts 1 Shawwal', () {
      final log = [for (var d = 1; d <= 10; d++) fasted(y.civil(10, d, 0))];
      expect(FastingStats(log, cfg(0)).sixShawwalProgress(1448), (done: 6, goal: 6));
    });

    test('13 Dhu al-Hijjah, if logged by hand, is no white day', () {
      final s = FastingStats([fasted(y.civil(12, 13, 0), source: FastLogSource.manual), fasted(y.civil(12, 14, 0))], cfg(0));
      expect(s.whiteDaysFastedInMonth(1448, 12), 1);
      expect(s.fastedInHijriMonth(1448, 12), 2);
    });
  });
}
