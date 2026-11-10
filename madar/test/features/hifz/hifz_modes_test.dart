// The seven methods of «الحفظ» (Part 14), each against the app's own
// verified text: the first-letters stage is a slice and never a letter of
// ours, writing from memory is judged by Part 13's aligner with the same
// honesty rules, and every mode says plainly whether it can run on this
// phone.
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/quran/ayah.dart';
import 'package:madar/features/hifz/hifz_memorisation.dart';
import 'package:madar/features/tasmee/tasmee.dart';

import '../tasmee/tasmee_fixtures.dart';
import 'hifz_plan_fixtures.dart';

void main() {
  final shape = testShape();
  const fatiha = AyahRange(AyahRef(1, 1), AyahRef(1, 7));
  const kahfStart = AyahRange(AyahRef(18, 1), AyahRef(18, 3));

  group('what this phone can do', () {
    test('with no speech model: «سمّع» is out, the written modes are in, the rest are untouched', () {
      final states = {for (final s in methodsWithoutRecogniser()) s.method: s};
      expect(states[HifzMethod.reciting]!.status, HifzMethodStatus.unavailable);
      expect(states[HifzMethod.reciting]!.blocker, HifzMethodBlocker.noRecogniser);
      expect(states[HifzMethod.writing]!.status, HifzMethodStatus.ready);
      expect(states[HifzMethod.listenRepeat]!.status, HifzMethodStatus.ready);
      expect(states[HifzMethod.chunking]!.status, HifzMethodStatus.ready);
      expect(states[HifzMethod.blanks]!.status, HifzMethodStatus.typedOnly);
      expect(states[HifzMethod.progressiveHiding]!.status, HifzMethodStatus.typedOnly);
      expect(states[HifzMethod.linking]!.status, HifzMethodStatus.typedOnly);
    });

    test('a reciter whose audio is not downloaded takes «اسمع وردّد» out, and nothing else', () {
      final states = {
        for (final s in HifzMethods.all(recogniser: const RecogniserAvailability.ready(), audioDownloaded: false))
          s.method: s,
      };
      expect(states[HifzMethod.listenRepeat]!.status, HifzMethodStatus.unavailable);
      expect(states[HifzMethod.listenRepeat]!.blocker, HifzMethodBlocker.audioNotDownloaded);
      expect(states[HifzMethod.reciting]!.status, HifzMethodStatus.ready);
    });

    test('listening and chunking judge nothing, so they write no result', () {
      expect(HifzMethods.logModeOf(HifzMethod.listenRepeat), isNull);
      expect(HifzMethods.logModeOf(HifzMethod.chunking), isNull);
      expect(HifzMethods.logModeOf(HifzMethod.writing), TasmeeMode.write);
      expect(HifzMethods.logModeOf(HifzMethod.linking), TasmeeMode.link);
      expect(HifzMethods.logModeOf(HifzMethod.progressiveHiding), TasmeeMode.hidden);
      expect(HifzMethods.logModeOf(HifzMethod.blanks), TasmeeMode.blanks);
    });
  });

  group('اسمع وردّد', () {
    test('plays each ayah N times with a pause, and counts what it will play', () {
      final plan = ListenRepeatPlan.build(shape, kahfStart, reciterId: 'husary', timesPerAyah: 3, passes: 2);
      expect(plan.ayahCount, 3);
      expect(plan.totalPlays, 18);
      expect(plan.gap, const Duration(seconds: 2));
      expect(plan.playsOffline, isTrue, reason: 'nothing was claimed about the files, so nothing is missing');
    });

    test('says exactly which ayat the chosen reciter does not have on the phone', () {
      final plan = ListenRepeatPlan.build(
        shape,
        kahfStart,
        reciterId: 'husary',
        downloaded: (ref) => ref.ayah == 1,
      );
      expect(plan.playsOffline, isFalse);
      expect(plan.ayatMissingAudio, const [AyahRef(18, 2), AyahRef(18, 3)]);
    });
  });

  group('التقطيع', () {
    test('ayah → group → page, and a group never crosses a surah', () {
      final ladder = ChunkLadder.build(shape, const AyahRange(AyahRef(93, 1), AyahRef(95, 8)), groupSize: 5);
      expect(ladder.stepOf(ChunkLevel.ayah).chunks.length, Mushaf.count(shape, ladder.range));
      for (final c in ladder.stepOf(ChunkLevel.group).chunks) {
        expect(c.first.surah, c.last.surah, reason: 'a chunk he repeats should not straddle two surahs');
        expect(Mushaf.count(shape, c), lessThanOrEqualTo(5));
      }
      final pages = ladder.stepOf(ChunkLevel.page).chunks;
      expect(pages.first.first, const AyahRef(93, 1), reason: 'the first page chunk starts where the range does');
      expect(pages.last.last, const AyahRef(95, 8));
    });
  });

  group('الإخفاء التدريجي', () {
    test('the first-letters stage is a verbatim prefix of the verified word', () {
      final target = targetOf(fatiha);
      final hints = FirstLetters.ofTarget(target);
      expect(hints.length, target.wordCount);
      for (final h in hints) {
        expect(h.hint, isNotEmpty);
        expect(h.word.text.startsWith(h.hint), isTrue, reason: '${h.word.text} vs ${h.hint}');
        expect(h.hint.length, lessThanOrEqualTo(h.word.text.length));
        expect(h.start, h.word.start);
        expect(h.end, lessThanOrEqualTo(h.word.end));
      }
    });

    test('a word with the definite article keeps its lam, so the hint is readable', () {
      const alhamd = 'ٱلْحَمْدُ';
      final hint = FirstLetters.of(alhamd);
      expect(alhamd.startsWith(hint), isTrue);
      expect(hint.contains('ل'), isTrue);
      expect(hint.length, lessThan(alhamd.length));
      expect(FirstLetters.of(alhamd, withArticle: false).contains('ل'), isFalse);
    });

    test('the ladder starts where the strength says, and hardens one step at a time', () {
      expect(FirstLetters.stageFor(StrengthBand.unknown), HidingStage.full);
      expect(FirstLetters.stageFor(StrengthBand.weak), HidingStage.full);
      expect(FirstLetters.stageFor(StrengthBand.shaky), HidingStage.firstLetters);
      expect(FirstLetters.stageFor(StrengthBand.solid), HidingStage.hidden);
      expect(FirstLetters.harder(HidingStage.full), HidingStage.firstLetters);
      expect(FirstLetters.harder(HidingStage.firstLetters), HidingStage.hidden);
      expect(FirstLetters.harder(HidingStage.hidden), isNull);
    });
  });

  group('اكتب من حفظك', () {
    test('writing it exactly is clean, and the result is Part 13\'s own check', () {
      final target = targetOf(kahfStart);
      final drill = WritingDrill(target)..write(verifiedWords(target).join(' '));
      final result = drill.result;
      expect(result.isClean, isTrue);
      expect(result.counts.right, target.wordCount);
      expect(result.missed, isEmpty);
      expect(result.extras, isEmpty);
      expect(result.accuracy, 1.0);
    });

    test('a word he left out is marked where it is in the original text, never guessed', () {
      final target = targetOf(const AyahRange(AyahRef(18, 1), AyahRef(18, 1)));
      final words = verifiedWords(target);
      final dropped = words.removeAt(2);
      final result = (WritingDrill(target)..write(words.join(' '))).result;
      final missed = result.missed;
      expect(missed, isNotEmpty);
      expect(missed.first.word.text, dropped);
      expect(missed.first.word.start, target.words[2].start, reason: 'the position is the original text\'s own');
      expect(missed.first.word.end, target.words[2].end);
      expect(missed.first.verdict, WordVerdict.skipped);
    });

    test('a word he changed is wrong, and what he typed is kept apart from the verse', () {
      final target = targetOf(const AyahRange(AyahRef(18, 1), AyahRef(18, 1)));
      final words = verifiedWords(target);
      words[1] = 'كلمة';
      final result = (WritingDrill(target)..write(words.join(' '))).result;
      final wrong = result.words[1];
      expect(wrong.verdict, WordVerdict.wrong);
      expect(wrong.heard, 'كلمة');
      expect(wrong.word.text, isNot('كلمة'), reason: 'the verified word is untouched beside it');
    });

    test('an empty sheet is not a mistake: it is simply not reached', () {
      final target = targetOf(kahfStart);
      final result = WritingDrill(target).result;
      expect(result.counts.pending, target.wordCount);
      expect(result.counts.mistakes, 0);
      expect(result.counts.accuracy, isNull, reason: 'no result, not a zero');
    });

    test('a typed answer is recorded as typed, never as a model\'s verdict', () {
      expect(TypedWords.byHand.id, 'typed');
      final heard = TypedWords.of('  كلمتين   هون ');
      expect(heard.length, 2);
      expect(heard.first.confidence, 1.0);
      expect(heard.first.isFinal, isTrue);
    });

    test('writing a range that crosses a surah is judged ayah by ayah', () {
      final target = targetOf(const AyahRange(AyahRef(93, 10), AyahRef(94, 2)));
      final result = (WritingDrill(target)..write(verifiedWords(target).join(' '))).result;
      expect(result.isClean, isTrue);
      expect(result.check.ayat.map((a) => a.ref), [
        const AyahRef(93, 10),
        const AyahRef(93, 11),
        const AyahRef(94, 1),
        const AyahRef(94, 2),
      ]);
      for (final a in result.check.ayat) {
        expect(a.counts.isClean, isTrue);
      }
    });
  });

  group('الربط', () {
    test('one join per pair of verses, with the tail of one and the head of the next', () {
      final target = targetOf(kahfStart);
      final links = Linking.of(target, tailWords: 2, headWords: 3);
      expect(links.length, 2);
      expect(links.first.from, const AyahRef(18, 1));
      expect(links.first.to, const AyahRef(18, 2));
      expect(links.first.tail.length, 2);
      expect(links.first.head.length, 3);
      expect(links.first.tail.last.text, target.ayat.first.lastWord >= 0 ? target.words[target.ayat.first.lastWord].text : '');
    });

    test('a join he got right is right; one he never reached is pending, not wrong', () {
      final target = targetOf(kahfStart);
      final links = Linking.of(target, tailWords: 2, headWords: 2);
      final firstAyah = target.ayat.first;
      final secondAyah = target.ayat[1];
      final said = [
        for (var i = firstAyah.firstWord; i <= secondAyah.firstWord + 1; i++) target.words[i].text,
      ];
      final check = TasmeeAligner.align(target, [
        for (final w in said) HeardWord(heard: w, at: Duration(milliseconds: said.indexOf(w) * 500)),
      ]);
      final results = Linking.score(check, links);
      expect(results.first.isRight, isTrue);
      expect(results.last.isPending, isTrue);
      expect(results.last.isRight, isFalse);
    });
  });
}
