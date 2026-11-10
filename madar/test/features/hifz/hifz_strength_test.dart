// «قوّة الآية» (Part 14): the strength comes from results that happened and
// from nothing else – it goes up after a clean recitation, down after a
// failed one, fades with time, never appears out of thin air, and obeys his
// own marks.
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/quran/ayah.dart';
import 'package:madar/features/hifz/hifz_memorisation.dart';
import 'package:madar/features/tasmee/tasmee.dart';

import 'hifz_plan_fixtures.dart';

void main() {
  const kahf1 = AyahRef(18, 1);
  const kahf2 = AyahRef(18, 2);
  final today = DateTime(2026, 10, 15);

  HifzStrengths strengthsOf(List<TasmeeSession> log, {HifzMarks marks = HifzMarks.empty, DateTime? day}) =>
      HifzStrengths.of(log, today: day ?? today, marks: marks);

  test('an ayah with no result is unknown, not weak and not zero', () {
    final s = strengthsOf(const []).of(kahf1);
    expect(s.band, StrengthBand.unknown);
    expect(s.isKnown, isFalse);
    expect(s.attempts, 0);
    expect(s.strength, 0, reason: 'no number is invented, and the band says why');
    expect(s.lastDay, isNull);
  });

  test('a clean recitation today makes it solid; a failed one afterwards drops it', () {
    final clean = strengthsOf([
      sessionOf(at: today.add(const Duration(hours: 9)), ayat: {kahf1: cleanCounts(10)}),
    ]).of(kahf1);
    expect(clean.band, StrengthBand.solid);
    expect(clean.strength, closeTo(1.0, 1e-9));
    expect(clean.cleanRun, 1);

    final afterFailure = strengthsOf([
      sessionOf(at: today.add(const Duration(hours: 9)), ayat: {kahf1: cleanCounts(10)}),
      sessionOf(at: today.add(const Duration(hours: 11)), ayat: {
        kahf1: counts(words: 10, wrong: 4, skipped: 2),
      }),
    ]).of(kahf1);
    expect(afterFailure.strength, lessThan(clean.strength));
    expect(afterFailure.cleanRun, 0, reason: 'the run of clean attempts is broken');
    expect(afterFailure.band, isNot(StrengthBand.solid));
  });

  test('a clean attempt raises it again, and the newest attempt weighs most', () {
    final down = strengthsOf([
      sessionOf(at: today.add(const Duration(hours: 9)), ayat: {kahf1: counts(words: 10, wrong: 6)}),
    ]).of(kahf1);
    final up = strengthsOf([
      sessionOf(at: today.add(const Duration(hours: 9)), ayat: {kahf1: counts(words: 10, wrong: 6)}),
      sessionOf(at: today.add(const Duration(hours: 10)), ayat: {kahf1: cleanCounts(10)}),
    ]).of(kahf1);
    expect(up.strength, greaterThan(down.strength));
    expect(up.recall, greaterThan(0.5), reason: 'the newest attempt carries the most weight');
  });

  test('a peek is half a mistake: it lowers the strength without being called one', () {
    final honest = strengthsOf([
      sessionOf(at: today, ayat: {kahf1: cleanCounts(10)}),
    ]).of(kahf1);
    final peeked = strengthsOf([
      sessionOf(at: today, ayat: {kahf1: counts(words: 10, hints: 4)}),
    ]).of(kahf1);
    expect(peeked.strength, lessThan(honest.strength));
    expect(peeked.hints, 4);
    expect(peeked.cleanRun, 0, reason: 'a hinted attempt is not a clean one');
  });

  test('it fades with the days, and a run of clean attempts makes it fade slower', () {
    final fresh = strengthsOf([
      sessionOf(at: today, ayat: {kahf1: cleanCounts(10)}),
    ]).of(kahf1);
    final old = strengthsOf([
      sessionOf(at: DateTime(2026, 9, 15), ayat: {kahf1: cleanCounts(10)}),
    ]).of(kahf1);
    expect(old.strength, lessThan(fresh.strength));
    expect(old.freshness, lessThan(0.2), reason: 'a month on one attempt');

    final practised = strengthsOf([
      for (var d = 20; d >= 10; d -= 2)
        sessionOf(at: DateTime(2026, 10, 15 - d), ayat: {kahf1: cleanCounts(10)}, id: 's$d'),
    ]).of(kahf1);
    expect(practised.cleanRun, 6);
    expect(practised.halfLifeDays, greaterThan(30), reason: 'six clean attempts in a row stretch the half-life');
    expect(practised.strength, greaterThan(old.strength));
  });

  test('«شازام القرآن» is a lookup, so it is not an attempt – and nor is an empty row', () {
    final find = strengthsOf([
      sessionOf(at: today, mode: TasmeeMode.find, ayat: {kahf1: cleanCounts(10)}),
    ]).of(kahf1);
    expect(find.band, StrengthBand.unknown);

    final nothing = strengthsOf([
      sessionOf(at: today, ayat: {kahf1: counts(words: 10, pending: 10)}),
    ]).of(kahf1);
    expect(nothing.band, StrengthBand.unknown, reason: 'he never reached a word of it');
  });

  test('writing from memory counts exactly like reciting it', () {
    final written = strengthsOf([
      sessionOf(at: today, mode: TasmeeMode.write, ayat: {kahf1: cleanCounts(10)}),
    ]).of(kahf1);
    expect(written.band, StrengthBand.solid);
    expect(written.attempts, 1);
  });

  test('«مش عليّ» takes an ayah out of the numbers entirely', () {
    final marks = HifzMarks.of([
      HifzMark(
        id: 'm1',
        kind: HifzMarkKind.skipReview,
        range: const AyahRange(kahf1, kahf2),
        createdAt: today,
      ),
    ]);
    final s = strengthsOf([
      sessionOf(at: today, ayat: {kahf1: cleanCounts(10)}),
    ], marks: marks);
    expect(s.of(kahf1).band, StrengthBand.skipped);
    expect(s.of(kahf1).isKnown, isFalse);
    expect(s.weakestOf([kahf1, kahf2]), isEmpty, reason: 'a skipped ayah is never queued for review');
  });

  test('«صفّر القوة» ignores what came before the day, and deletes nothing', () {
    final log = [
      sessionOf(at: DateTime(2026, 10, 1), ayat: {kahf1: cleanCounts(10)}, id: 'old'),
      sessionOf(at: DateTime(2026, 10, 2), ayat: {kahf1: cleanCounts(10)}, id: 'old2'),
    ];
    final before = strengthsOf(log).of(kahf1);
    expect(before.attempts, 2);

    final marks = HifzMarks.of([
      HifzMark(
        id: 'm1',
        kind: HifzMarkKind.resetStrength,
        range: const AyahRange(kahf1, kahf1),
        createdAt: DateTime(2026, 10, 10),
        since: DateTime(2026, 10, 10),
      ),
    ]);
    final after = strengthsOf(log, marks: marks).of(kahf1);
    expect(after.band, StrengthBand.unknown);
    expect(after.attempts, 0);
    expect(after.resetSince, DateTime(2026, 10, 10));
    expect(log.first.ayat, isNotEmpty, reason: 'the log itself is untouched');
  });

  test('the weakest order puts known-and-weak first and never-tested last', () {
    const kahf3 = AyahRef(18, 3);
    final s = strengthsOf([
      sessionOf(at: today, ayat: {
        kahf1: counts(words: 10, wrong: 7),
        kahf2: cleanCounts(10),
      }),
    ]);
    final order = s.weakestOf([kahf3, kahf2, kahf1]).map((x) => x.ref).toList();
    expect(order, [kahf1, kahf2, kahf3]);
  });
}
