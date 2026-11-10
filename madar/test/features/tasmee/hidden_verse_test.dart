// The hidden-verse mode: a word appears because he recited it, never
// because time passed – and a peek is recorded as a hint.
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/quran/ayah.dart';
import 'package:madar/features/tasmee/tasmee.dart';

import 'tasmee_fixtures.dart';

void main() {
  const fatiha2 = AyahRef(1, 2);
  late RecitationTarget target;
  late List<HeardWord> heard;

  setUp(() {
    target = targetOfAyah(fatiha2);
    heard = cleanScript(target).heardWords();
  });

  group('the page starts hidden', () {
    test('nothing is visible and no screen can read a word out of it', () {
      final machine = HiddenVerseMachine(target: target);
      expect(machine.page.map((w) => w.state).toSet(), {WordState.hidden});
      expect(machine.page.map((w) => w.text).toSet(), {null}, reason: 'a hidden word has no text to draw');
      expect(machine.page.map((w) => w.isVisible).toSet(), {false});
      expect(machine.cursor, 0);
      expect(machine.revealedCount, 0);
      expect(machine.isComplete, isFalse);
    });
  });

  group('a word appears because he recited it', () {
    test('one word at a time, in order, driven by the alignment and not a timer', () {
      final machine = HiddenVerseMachine(target: target);
      for (var i = 0; i < heard.length; i++) {
        machine.hear(heard[i]);
        expect(machine.revealedCount, i + 1);
        expect(machine.cursor, i + 1 < target.wordCount ? i + 1 : null);
        final page = machine.page;
        for (var k = 0; k < target.wordCount; k++) {
          expect(page[k].state, k <= i ? WordState.revealed : WordState.hidden, reason: 'word $k after $i heard');
          expect(page[k].text, k <= i ? target.words[k].text : isNull);
        }
      }
      expect(machine.isComplete, isTrue);
      expect(machine.check.isClean, isTrue);
      expect(machine.hintCount, 0);
    });

    test('a wrong word shows the verified word with the mistake, and what was heard beside it', () {
      final machine = HiddenVerseMachine(target: target);
      machine.hearAll(cleanScript(target).replace(2, 'ملك').heardWords());
      final page = machine.page;
      expect(page[2].state, WordState.wrong);
      expect(page[2].text, target.words[2].text, reason: 'the verified word is shown so he sees the right one');
      expect(page[2].heard, 'ملك');
      expect(machine.check.counts.wrong, 1);
    });

    test('a word the recogniser was unsure about is shown as «not sure», not as a mistake', () {
      final machine = HiddenVerseMachine(target: target);
      machine.hearAll(cleanScript(target).replace(1, 'ربي', confidence: 0.1).heardWords());
      expect(machine.page[1].state, WordState.unsure);
      expect(machine.check.counts.mistakes, 0);
    });

    test('a partial hypothesis reveals nothing', () {
      final machine = HiddenVerseMachine(target: target);
      machine.hear(heard.first.copyWith(isFinal: false));
      expect(machine.revealedCount, 0);
      expect(machine.heardCount, 0);
      expect(machine.page.first.state, WordState.hidden);
    });
  });

  group('a peek', () {
    test('it reveals the word, and it is recorded as a hint', () {
      final machine = HiddenVerseMachine(target: target);
      final word = machine.peek(0);
      expect(word, isNotNull);
      expect(word!.text, target.words[0].text);
      expect(machine.hints, [0]);
      expect(machine.hintCount, 1);
      expect(machine.page[0].state, WordState.peeked);
      expect(machine.page[0].text, target.words[0].text);
      expect(machine.revealedCount, 0, reason: 'a peek is not a recitation');
      expect(machine.isComplete, isFalse, reason: 'he still has to say it');
    });

    test('«ورّيني كلمة» reveals the one he is stuck on', () {
      final machine = HiddenVerseMachine(target: target);
      machine.hear(heard[0]);
      final word = machine.peekNext();
      expect(word!.index, 1);
      expect(machine.hints, [1]);
      expect(machine.page[1].state, WordState.peeked);
    });

    test('the hint stays on the record after he recites the word correctly', () {
      final machine = HiddenVerseMachine(target: target);
      machine.peek(2);
      machine.hearAll(heard);
      expect(machine.check.isClean, isTrue);
      expect(machine.page[2].state, WordState.revealed);
      expect(machine.check.words[2].hinted, isTrue, reason: 'the strength must know he was shown it');
      expect(machine.check.counts.hints, 1);
      expect(machine.check.ayah(fatiha2).counts.hints, 1);
    });

    test('a hint reaches the log, so Part 14 reads an honest strength', () {
      final machine = HiddenVerseMachine(target: target);
      machine.peek(1);
      machine.hearAll(cleanScript(target).drop(1).heardWords());
      final draft = TasmeeSessionDraft.ofCheck(
        machine.check,
        startedAt: DateTime(2026, 10, 15, 20),
        mode: TasmeeMode.hidden,
        recogniser: const RecogniserInfo(id: 'fake', version: '1', name: 'stub', licence: 'none'),
      );
      expect(draft.counts.hints, 1);
      final missed = draft.mistakes.single;
      expect(missed.kind, MistakeKind.skipped);
      expect(missed.hinted, isTrue);
      expect(missed.wordIndex, 1);
      expect(missed.expected, target.words[1].text);
    });

    test('a peek outside the target is refused rather than invented', () {
      final machine = HiddenVerseMachine(target: target);
      expect(machine.peek(-1), isNull);
      expect(machine.peek(target.wordCount), isNull);
      expect(machine.hintCount, 0);
    });
  });

  group('starting over', () {
    test('a reset forgets what was heard and what was peeked', () {
      final machine = HiddenVerseMachine(target: target);
      machine.peek(0);
      machine.hearAll(heard);
      machine.reset();
      expect(machine.hintCount, 0);
      expect(machine.heardCount, 0);
      expect(machine.page.map((w) => w.state).toSet(), {WordState.hidden});
    });
  });

  group('a range', () {
    test('each ayah can be drawn on its own, in its own order', () {
      final t = targetOf(const AyahRange(AyahRef(1, 1), AyahRef(1, 3)));
      final machine = HiddenVerseMachine(target: t);
      machine.hearAll(cleanScript(t).heardWords());
      final second = machine.ayahPage(const AyahRef(1, 2));
      expect(second, hasLength(t.ayat[1].wordCount));
      expect(second.map((w) => w.state).toSet(), {WordState.revealed});
      expect(second.first.word.ref, const AyahRef(1, 2));
    });
  });

  group('the experimental tashkeel check', () {
    test('it is off until he turns it on, and turning it on recomputes', () {
      final machine = HiddenVerseMachine(target: target);
      machine.hearAll(cleanScript(target).heardWords());
      expect(machine.tashkeelChecked, isFalse);
      expect(machine.check.counts.tashkeelDifferent, 0);
      machine.setTashkeelCheck(true);
      expect(machine.tashkeelChecked, isTrue);
      expect(machine.check.tashkeelChecked, isTrue);
      expect(machine.check.counts.tashkeelDifferent, 0, reason: 'a perfect recitation has nothing to flag');
    });
  });
}
