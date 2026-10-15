// Fill in the blank: the same seed always gives the same blanks, and only
// the blanks are scored.
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/quran/ayah.dart';
import 'package:madar/features/tasmee/tasmee.dart';

import 'tasmee_fixtures.dart';

void main() {
  const long = AyahRef(2, 255);
  late RecitationTarget target;

  setUp(() => target = targetOfAyah(long));

  group('the blanks come from the seed', () {
    test('the same seed gives exactly the same blanks, every time', () {
      final first = Blanks.plan(target, seed: 1234);
      for (var i = 0; i < 5; i++) {
        expect(Blanks.plan(target, seed: 1234).blanks, first.blanks);
      }
      // And from a target built again from the same verified text.
      expect(Blanks.plan(targetOfAyah(long), seed: 1234).blanks, first.blanks);
    });

    test('a different seed gives different blanks', () {
      final a = Blanks.plan(target, seed: 1).blanks;
      final b = Blanks.plan(target, seed: 2).blanks;
      expect(a, isNot(b));
      expect(a, hasLength(b.length));
    });

    test('the same seed on another ayah gives that ayah its own pattern', () {
      final a = Blanks.plan(targetOfAyah(const AyahRef(1, 7)), seed: 7).blanks;
      final b = Blanks.plan(targetOfAyah(const AyahRef(1, 6)), seed: 7).blanks;
      expect(a, isNot(b));
    });

    test('never the first word, never two side by side, always inside the ayah', () {
      for (var seed = 0; seed < 40; seed++) {
        final plan = Blanks.plan(target, seed: seed);
        expect(plan.blanks, isNot(contains(0)), reason: 'he needs somewhere to start');
        expect(plan.blanks, orderedEquals([...plan.blanks]..sort()));
        for (var i = 1; i < plan.blanks.length; i++) {
          expect(plan.blanks[i] - plan.blanks[i - 1], greaterThan(1), reason: 'seed $seed');
        }
        expect(plan.blanks.every((b) => b > 0 && b < target.wordCount), isTrue);
      }
    });

    test('a count is honoured, and never more than there is room for', () {
      expect(Blanks.plan(target, seed: 3, count: 5).count, 5);
      final short = targetOfAyah(const AyahRef(1, 1));
      final crowded = Blanks.plan(short, seed: 3, count: 100);
      expect(crowded.count, lessThanOrEqualTo(short.wordCount ~/ 2));
      expect(crowded.count, greaterThan(0));
    });

    test('the rhyme-only spread blanks the last word of every ayah', () {
      final t = targetOf(const AyahRange(AyahRef(1, 2), AyahRef(1, 4)));
      final plan = Blanks.plan(t, seed: 9, spread: BlankSpread.ayahEnds);
      expect(plan.blanks, [for (final a in t.ayat) a.lastWord]);
      expect(plan.spread, BlankSpread.ayahEnds);
    });
  });

  group('only the blanks are scored', () {
    test('a clean recitation fills every blank', () {
      final drill = BlankDrill.of(target, seed: 11, count: 4);
      drill.hearAll(cleanScript(target).heardWords());
      final score = drill.score;
      expect(score.blanks, 4);
      expect(score.right, 4);
      expect(score.accuracy, 1.0);
      expect(score.isClean, isTrue);
    });

    test('a mistake outside a blank does not count against him', () {
      final drill = BlankDrill.of(target, seed: 11, count: 4);
      final blanks = drill.plan.blanks;
      final notBlank = List.generate(target.wordCount, (i) => i).firstWhere((i) => i > 0 && !blanks.contains(i));
      drill.hearAll(cleanScript(target).replace(notBlank, 'ملك').heardWords());
      final score = drill.score;
      expect(score.right, 4, reason: 'the blanks were all said correctly');
      expect(score.isClean, isTrue);
      expect(score.check.counts.wrong, 1, reason: 'the full alignment still knows about it');
    });

    test('a mistake inside a blank is the whole score', () {
      final drill = BlankDrill.of(target, seed: 11, count: 4);
      final at = drill.plan.blanks.first;
      drill.hearAll(cleanScript(target).replace(at, 'ملك').heardWords());
      final score = drill.score;
      expect(score.wrong, 1);
      expect(score.right, 3);
      expect(score.accuracy, closeTo(0.75, 1e-9));
      expect(score.isClean, isFalse);
      expect(score.answers.firstWhere((a) => a.word.index == at).heard, 'ملك');
    });

    test('a blank he went past is skipped, with its own position in the original text', () {
      final drill = BlankDrill.of(target, seed: 11, count: 4);
      final at = drill.plan.blanks.first;
      drill.hearAll(cleanScript(target).drop(at).heardWords());
      final answer = drill.score.answers.firstWhere((a) => a.word.index == at);
      expect(answer.verdict, WordVerdict.skipped);
      expect(ayahText(long).substring(answer.word.start, answer.word.end), answer.word.text);
    });

    test('a blank he has not reached yet is pending, not wrong', () {
      final drill = BlankDrill.of(target, seed: 11, count: 4);
      drill.hearAll(cleanScript(target).heardWords().take(3));
      final score = drill.score;
      expect(score.pending, greaterThan(0));
      expect(score.wrong, 0);
      expect(score.skipped, 0);
    });
  });

  group('showing a blank', () {
    test('it is a hint, exactly like a peek', () {
      final drill = BlankDrill.of(target, seed: 11, count: 4);
      final at = drill.plan.blanks.first;
      expect(drill.peek(at)!.text, target.words[at].text);
      expect(drill.score.hints, 1);
      expect(drill.peek(0), isNull, reason: 'word 0 is not a blank');
    });

    test('the text on screen hides a blank until it is answered or shown', () {
      final drill = BlankDrill.of(target, seed: 11, count: 4);
      final at = drill.plan.blanks.first;
      expect(drill.shown[at], isNull);
      expect(drill.shown[0], target.words[0].text);
      drill.peek(at);
      expect(drill.shown[at], target.words[at].text);
    });
  });
}
