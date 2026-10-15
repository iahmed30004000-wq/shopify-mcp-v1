import 'dart:ui' show TextDirection;

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/adhkar/adhkar.dart';

import 'adhkar_harness.dart';

Map<String, Object?> _dhikr(String id, {int count = 1, Object? segments, Map<String, Object?> extra = const {}}) => {
  'id': id,
  'segments':
      segments ??
      [
        {'text': 'سُبْحَانَ اللَّهِ'},
      ],
  'count': count,
  'reference': {'ar': 'مسلم', 'en': 'Muslim'},
  ...extra,
};

Map<String, Object?> _library(List<Map<String, Object?>> morning, {List<Map<String, Object?>>? afterPrayer}) => {
  'schema': 1,
  'title': {'ar': 'حصن المسلم', 'en': 'Hisn'},
  'author': {'ar': 'القحطاني', 'en': 'al-Qahtani'},
  'sources': [
    {'id': 's', 'url': 'https://example.org', 'commit': 'x', 'license': 'MIT'},
  ],
  'categories': [
    {'id': 'morning', 'items': morning},
    {
      'id': 'evening',
      'items': [_dhikr('evening.01')],
    },
    {
      'id': 'afterPrayer',
      'items': afterPrayer ?? [_dhikr('afterPrayer.01')],
    },
    {
      'id': 'sleep',
      'items': [_dhikr('sleep.01')],
    },
    {
      'id': 'waking',
      'items': [_dhikr('waking.01')],
    },
  ],
};

AdhkarCategory _cat(List<int> counts) =>
    AdhkarLibrary.fromJson(_library([for (final (i, c) in counts.indexed) _dhikr('morning.$i', count: c)]))
        .category(AdhkarCategoryId.morning);

final _t = DateTime(2026, 9, 28, 6, 30);

void main() {
  group('parser', () {
    AdhkarFormatException? error(Map<String, Object?> json) {
      try {
        AdhkarLibrary.fromJson(json);
        return null;
      } on AdhkarFormatException catch (e) {
        return e;
      }
    }

    test('accepts a well-formed library', () {
      expect(error(_library([_dhikr('morning.1')])), isNull);
    });

    test('rejects a count below 1, empty text, bad verses, unknown sets and duplicate ids', () {
      expect(error(_library([_dhikr('morning.1', count: 0)]))?.message, contains('count'));
      expect(
        error(
          _library([
            _dhikr(
              'morning.1',
              segments: [
                {'text': '  '},
              ],
            ),
          ]),
        )?.message,
        contains('text'),
      );
      expect(
        error(
          _library([
            _dhikr(
              'morning.1',
              segments: [
                {
                  'surah': 112,
                  'ayahs': [1, 4],
                  'verses': ['قُلْ هُوَ اللَّهُ أَحَدٌ'],
                },
              ],
            ),
          ]),
        )?.message,
        contains('verses'),
      );
      expect(
        error(
          _library([
            _dhikr(
              'morning.1',
              segments: [
                {
                  'surah': 115,
                  'ayahs': [1, 1],
                  'verses': ['x'],
                },
              ],
            ),
          ]),
        )?.message,
        contains('surah'),
      );
      expect(error(_library([_dhikr('morning.1'), _dhikr('morning.1')]))?.message, contains('duplicate'));
      expect(
        error({
          ..._library([_dhikr('morning.1')]),
          'schema': 2,
        })?.message,
        contains('schema'),
      );
      final missing = _library([_dhikr('morning.1')]);
      (missing['categories']! as List).removeLast();
      expect(error(missing)?.message, contains('waking'));
      expect(
        error(
          _library(
            [_dhikr('morning.1')],
            afterPrayer: [
              _dhikr(
                'afterPrayer.1',
                extra: {
                  'onlyAfter': ['sunrise'],
                },
              ),
            ],
          ),
        )?.message,
        contains('obligatory'),
      );
      expect(
        error(
          _library([
            _dhikr(
              'morning.1',
              extra: {
                'reference': {'ar': ''},
              },
            ),
          ]),
        )?.message,
        contains('reference'),
      );
    });

    test('localised text falls back to Arabic', () {
      const t = LocalizedText('عربي');
      expect(t.of('en'), 'عربي');
      expect(const LocalizedText('عربي', 'English').of('en'), 'English');
      expect(const LocalizedText('عربي', 'English').of('ar'), 'عربي');
    });

    test('Quran segments keep their ayah numbers', () {
      final lib = loadBundledLibrary();
      final q = lib.dhikrById('waking.04')!.quranSegments.single;
      expect(q.surah, 3);
      expect(q.ayahAt(0), 190);
      expect(q.ayahAt(q.verses.length - 1), 200);
    });
  });

  group('set keys', () {
    test('storage keys round-trip', () {
      for (final k in [
        const AdhkarSetKey(AdhkarCategoryId.morning),
        const AdhkarSetKey(AdhkarCategoryId.afterPrayer, Prayer.maghrib),
      ]) {
        expect(AdhkarSetKey.parse(k.storageKey), k);
      }
      expect(AdhkarSetKey.parse('afterPrayer.witr'), isNull);
      expect(AdhkarSetKey.parse('nope'), isNull);
    });
  });

  group('counter state machine', () {
    test('taps count until the target, then the dhikr is complete', () {
      var s = AdhkarSession.start(_cat([3, 1, 2]));
      expect(s.index, 0);
      expect(s.remainingAt(0), 3);
      AdhkarTapOutcome o;
      (s, o) = s.tap(_t);
      expect(o, AdhkarTapOutcome.counted);
      (s, o) = s.tap(_t);
      expect(o, AdhkarTapOutcome.counted);
      expect(s.remainingAt(0), 1);
      (s, o) = s.tap(_t);
      expect(o, AdhkarTapOutcome.dhikrCompleted);
      expect(s.isDoneAt(0), isTrue);
      expect(s.doneCount, 1);
      // A finished dhikr counts no further.
      final (same, again) = s.tap(_t);
      expect(again, AdhkarTapOutcome.alreadyDone);
      expect(same.countAt(0), 3);
    });

    test('advance goes to the next unfinished dhikr, wrapping around', () {
      var s = AdhkarSession.start(_cat([1, 1, 1]));
      s = s.goTo(1);
      s = s.tap(_t).$1; // #1 done
      s = s.advance();
      expect(s.index, 2);
      s = s.tap(_t).$1; // #2 done
      s = s.advance();
      expect(s.index, 0, reason: 'wraps to the one skipped');
    });

    test('the last open dhikr completes the set with a timestamp', () {
      var s = AdhkarSession.start(_cat([1, 2]));
      s = s.tap(_t).$1.advance();
      expect(s.index, 1);
      s = s.tap(_t).$1;
      final (done, o) = s.tap(_t);
      expect(o, AdhkarTapOutcome.setCompleted);
      expect(done.completedAt, _t);
      expect(done.isComplete, isTrue);
      expect(done.progress, 1);
      expect(done.advance().index, 1, reason: 'nothing left: stays');
    });

    test('progress weighs every dhikr the same and counts partial repetitions', () {
      var s = AdhkarSession.start(_cat([4, 1]));
      s = s.tap(_t).$1;
      expect(s.progress, closeTo((0.25 + 0) / 2, 1e-9));
      s = s.goTo(1).tap(_t).$1;
      expect(s.progress, closeTo((0.25 + 1) / 2, 1e-9));
    });

    test('resume: counts and page come back, clamped to the targets', () {
      final cat = _cat([3, 5]);
      final saved = AdhkarProgress(index: 1, counts: {'morning.0': 9, 'morning.1': 2, 'gone': 4});
      final s = AdhkarSession.start(cat, resume: saved);
      expect(s.index, 1);
      expect(s.countAt(0), 3);
      expect(s.countAt(1), 2);
      expect(s.counts.containsKey('gone'), isFalse);
      final roundTrip = AdhkarProgress.fromJson(s.toProgress().toJson());
      expect(roundTrip, s.toProgress());
      expect(AdhkarSession.start(cat, resume: const AdhkarProgress(index: 99)).index, 1);
      expect(AdhkarProgress.fromJson('garbage'), const AdhkarProgress());
      expect(
        AdhkarProgress.fromJson({
          'index': -3,
          'counts': {'a': 'x'},
        }),
        const AdhkarProgress(),
      );
    });

    test('reset current, reset all, mark done', () {
      var s = AdhkarSession.start(_cat([1, 1]));
      s = s.tap(_t).$1.advance().tap(_t).$1;
      expect(s.isComplete, isTrue);
      final recount = s.resetCurrent();
      expect(recount.isComplete, isFalse);
      expect(recount.countAt(1), 0);
      expect(recount.countAt(0), 1);
      final fresh = s.markLogged().resetAll();
      expect(fresh.counts, isEmpty);
      expect(fresh.index, 0);
      expect(fresh.logged, isTrue, reason: 'a logged completion is not logged twice the same day');
      final marked = AdhkarSession.start(_cat([33, 3])).markDone(_t);
      expect(marked.isComplete, isTrue);
      expect(marked.markedDone, isTrue);
      expect(marked.progress, 1);
    });

    test('after-prayer: items and counts follow the prayer', () {
      final lib = loadBundledLibrary();
      final c = lib.category(AdhkarCategoryId.afterPrayer);
      final fajr = AdhkarSession.start(c, prayer: Prayer.fajr);
      final asr = AdhkarSession.start(c, prayer: Prayer.asr);
      expect(fajr.length, 12);
      expect(asr.length, 10);
      final i = fajr.items.indexWhere((d) => d.id == 'afterPrayer.09');
      expect(fajr.targetAt(i), 3);
      expect(asr.targetAt(asr.items.indexWhere((d) => d.id == 'afterPrayer.09')), 1);
      expect(fajr.key.storageKey, 'afterPrayer.fajr');
      // Other sets ignore the prayer.
      expect(AdhkarSession.start(lib.category(AdhkarCategoryId.sleep), prayer: Prayer.isha).key.prayer, isNull);
    });
  });

  group('timing', () {
    test('suggested set and prayer per window', () {
      expect(AdhkarTiming.suggested(PrayerWindow.fajr), AdhkarCategoryId.morning);
      expect(AdhkarTiming.suggested(PrayerWindow.duha), AdhkarCategoryId.morning);
      expect(AdhkarTiming.suggested(PrayerWindow.dhuhr), AdhkarCategoryId.afterPrayer);
      expect(AdhkarTiming.suggested(PrayerWindow.asr), AdhkarCategoryId.evening);
      expect(AdhkarTiming.suggested(PrayerWindow.maghrib), AdhkarCategoryId.evening);
      expect(AdhkarTiming.suggested(PrayerWindow.isha), AdhkarCategoryId.sleep);
      expect(AdhkarTiming.lastPrayer(PrayerWindow.duha), Prayer.fajr);
      expect(AdhkarTiming.lastPrayer(PrayerWindow.maghrib), Prayer.maghrib);
      expect(AdhkarTiming.dayKey(DateTime(2026, 1, 5, 23)), '2026-01-05');
    });

    // Amman, late September: Maghrib 18:32, next Fajr 05:05.
    final night = AdhkarNight(maghrib: DateTime(2026, 9, 28, 18, 32), fajr: DateTime(2026, 9, 29, 5, 5));
    final monday = DateTime(2026, 9, 28);

    test('the night: its middle and its last third', () {
      expect(night.midpoint, DateTime(2026, 9, 28, 23, 48, 30));
      expect(night.lastThird, DateTime(2026, 9, 29, 1, 34));
    });

    test('on-waking adhkar before Fajr belong to the coming day; every other set to the prayer day', () {
      expect(AdhkarTiming.wakingDay(monday, DateTime(2026, 9, 28, 22, 30), night), monday);
      expect(AdhkarTiming.wakingDay(monday, DateTime(2026, 9, 29, 4, 40), night), DateTime(2026, 9, 29));
      expect(AdhkarTiming.wakingDay(monday, DateTime(2026, 9, 29, 0, 10), night), DateTime(2026, 9, 29));
      for (final c in AdhkarCategoryId.values) {
        final day = AdhkarTiming.dayFor(c, monday, DateTime(2026, 9, 29, 4, 40), night);
        expect(day, c == AdhkarCategoryId.waking ? DateTime(2026, 9, 29) : monday, reason: c.name);
      }
    });

    test('the suggestion follows the night and skips a set already said', () {
      AdhkarCategoryId at(DateTime now, PrayerWindow w, {Set<AdhkarCategoryId> done = const {}, Set<Prayer> after = const {}}) =>
          AdhkarTiming.suggestAt(
            window: w,
            now: now,
            night: night,
            isDone: (c, p) => c == AdhkarCategoryId.afterPrayer ? after.contains(p) : done.contains(c),
          );
      // Evening, then sleep after Isha.
      expect(at(DateTime(2026, 9, 28, 16), PrayerWindow.asr), AdhkarCategoryId.evening);
      expect(at(DateTime(2026, 9, 28, 21), PrayerWindow.isha), AdhkarCategoryId.sleep);
      // Past the middle of the night: still up → sleep; slept (sleep adhkar
      // said) and awake again → waking.
      expect(at(DateTime(2026, 9, 29, 0, 30), PrayerWindow.isha), AdhkarCategoryId.sleep);
      expect(
        at(DateTime(2026, 9, 29, 0, 30), PrayerWindow.isha, done: {AdhkarCategoryId.sleep}),
        AdhkarCategoryId.waking,
      );
      // The last third of the night (Qiyam, waking for Fajr) → waking.
      expect(at(DateTime(2026, 9, 29, 4, 40), PrayerWindow.isha), AdhkarCategoryId.waking);
      // Evening adhkar said: the adhkar after Asr, then – both said – the
      // evening set stays (the screen shows it as done).
      expect(at(DateTime(2026, 9, 28, 16), PrayerWindow.asr, done: {AdhkarCategoryId.evening}), AdhkarCategoryId.afterPrayer);
      expect(
        at(DateTime(2026, 9, 28, 16), PrayerWindow.asr, done: {AdhkarCategoryId.evening}, after: {Prayer.asr}),
        AdhkarCategoryId.evening,
      );
      // Morning adhkar said: after Fajr prayer still in its window, but not
      // in the forenoon.
      expect(at(DateTime(2026, 9, 29, 5, 30), PrayerWindow.fajr, done: {AdhkarCategoryId.morning}), AdhkarCategoryId.afterPrayer);
      expect(at(DateTime(2026, 9, 29, 9), PrayerWindow.duha, done: {AdhkarCategoryId.morning}), AdhkarCategoryId.morning);
      // A waking set already said is not swapped for "after Isha".
      expect(
        at(DateTime(2026, 9, 29, 4, 40), PrayerWindow.isha, done: {AdhkarCategoryId.waking}),
        AdhkarCategoryId.waking,
      );
    });

    test('the next boundary: window end, the night\'s middle and last third, or midnight', () {
      final windowEnd = DateTime(2026, 9, 29, 5, 5);
      expect(AdhkarTiming.nextBoundary(DateTime(2026, 9, 28, 21), windowEnd: windowEnd, night: night), night.midpoint);
      expect(
        AdhkarTiming.nextBoundary(DateTime(2026, 9, 28, 23, 50), windowEnd: windowEnd, night: night),
        DateTime(2026, 9, 29),
      );
      expect(AdhkarTiming.nextBoundary(DateTime(2026, 9, 29, 0, 5), windowEnd: windowEnd, night: night), night.lastThird);
      expect(AdhkarTiming.nextBoundary(DateTime(2026, 9, 29, 3), windowEnd: windowEnd, night: night), windowEnd);
      expect(
        AdhkarTiming.nextBoundary(DateTime(2026, 9, 28, 16), windowEnd: DateTime(2026, 9, 28, 18, 32), night: night),
        DateTime(2026, 9, 28, 18, 32),
      );
    });
  });

  group('tasbeeh', () {
    test('rounds of 33', () {
      var c = const TasbeehCounter(target: 33);
      expect(c.inRound, 0);
      TasbeehTapOutcome o = TasbeehTapOutcome.bead;
      for (var i = 0; i < 32; i++) {
        (c, o) = c.tap();
        expect(o, TasbeehTapOutcome.bead);
      }
      (c, o) = c.tap();
      expect(o, TasbeehTapOutcome.round);
      expect(c.count, 33);
      expect(c.inRound, 33, reason: 'a finished round shows full until the next tap');
      expect(c.rounds, 1);
      expect(c.litBeads, 33);
      (c, o) = c.tap();
      expect(o, TasbeehTapOutcome.bead);
      expect(c.inRound, 1);
      expect(c.litBeads, 1);
      for (var i = 0; i < 65; i++) {
        (c, o) = c.tap();
      }
      expect(c.count, 99);
      expect(c.rounds, 3);
      expect(o, TasbeehTapOutcome.round);
      expect(c.reset(), const TasbeehCounter(target: 33));
    });

    test('custom targets above 100 share 100 beads', () {
      var c = const TasbeehCounter(target: 1000);
      expect(c.beads, 100);
      for (var i = 0; i < 15; i++) {
        c = c.tap().$1;
      }
      expect(c.litBeads, 1);
      expect(c.roundProgress, closeTo(0.015, 1e-9));
      expect(const TasbeehCounter(target: 7, count: 7).beads, 7);
    });

    test('custom target parsing', () {
      expect(TasbeehCounter.parseTarget('250'), 250);
      expect(TasbeehCounter.parseTarget(12.4), 12);
      expect(TasbeehCounter.parseTarget(0), isNull);
      expect(TasbeehCounter.parseTarget(10000), isNull);
      expect(TasbeehCounter.parseTarget('abc'), isNull);
    });

    test('ring geometry: the counted bead sits at the marker; beads flow toward the reading start', () {
      const top = -1.5707963267948966;
      expect(TasbeehRingGeometry.angleOf(5, 5, 33, TextDirection.ltr), closeTo(top, 1e-9));
      final ltr = TasbeehRingGeometry.angleOf(4, 5, 33, TextDirection.ltr);
      final rtl = TasbeehRingGeometry.angleOf(4, 5, 33, TextDirection.rtl);
      expect(ltr, lessThan(top), reason: 'LTR: passed beads to the left (counter-clockwise)');
      expect(rtl, greaterThan(top), reason: 'RTL: passed beads to the right (clockwise)');
      expect(TasbeehRingGeometry.separators(33), {11, 22});
      expect(TasbeehRingGeometry.separators(99), {33, 66});
      expect(TasbeehRingGeometry.separators(10), isEmpty);
      expect(TasbeehRingGeometry.beadRadius(33, 150), lessThanOrEqualTo(12.5));
      expect(TasbeehRingGeometry.beadRadius(100, 150), greaterThanOrEqualTo(1.8));
    });

    test('phrases: defaults and JSON', () {
      expect(TasbeehDefaults.phrases.map((p) => p.id).toSet(), hasLength(TasbeehDefaults.phrases.length));
      expect(
        TasbeehPhrase.fromJson(const TasbeehPhrase(id: 'a', text: 'ب').toJson()),
        const TasbeehPhrase(id: 'a', text: 'ب'),
      );
      expect(TasbeehPhrase.fromJson({'id': 'a', 'text': ' '}), isNull);
    });
  });
}
