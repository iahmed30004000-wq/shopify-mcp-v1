// «أي حرف هاد؟»: pure question generator. No Flutter, no clock, seeded.
//
// A question shows the target letter in one of its written forms and asks the
// child to pick the same letter among a few, written on their own. Nothing in
// here can mark an answer "wrong": [LetterQuestion.isCorrect] is just a check
// the screen uses to decide between "well done" and a soft retry.
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/arabic_letters.dart';

@immutable
class LetterQuestion {
  const LetterQuestion({required this.target, required this.form, required this.choices});

  final ArabicLetter target;

  /// The form the child sees (always a real form of the letter).
  final LetterForm form;

  /// The target and its distractors, in display order; all distinct.
  final List<ArabicLetter> choices;

  bool isCorrect(ArabicLetter picked) => picked.id == target.id;
}

class LetterQuizEngine {
  LetterQuizEngine({int seed = 0, this.choiceCount = 3, this._letters = arabicLetters})
    : assert(choiceCount >= 2 && choiceCount <= 6),
      _rng = Random(seed);

  final int choiceCount;
  final List<ArabicLetter> _letters;
  final Random _rng;
  String? _lastTarget;

  /// The next question: never the same letter twice in a row.
  LetterQuestion next() {
    ArabicLetter target;
    do {
      target = _letters[_rng.nextInt(_letters.length)];
    } while (target.id == _lastTarget && _letters.length > 1);
    _lastTarget = target.id;

    final forms = [for (final f in LetterForm.values) if (target.hasForm(f)) f];
    final form = forms[_rng.nextInt(forms.length)];

    // Distractors: letters that are not the target. Prefer look-alikes next to
    // it in the alphabet (ب ت ث) for a fair, gentle challenge.
    final index = _letters.indexOf(target);
    final near = <ArabicLetter>[], far = <ArabicLetter>[];
    for (var i = 0; i < _letters.length; i++) {
      if (i == index) continue;
      ((i - index).abs() <= 3 ? near : far).add(_letters[i]);
    }
    near.shuffle(_rng);
    far.shuffle(_rng);
    final pool = [...near, ...far];
    final choices = [target, ...pool.take(choiceCount - 1)]..shuffle(_rng);
    return LetterQuestion(target: target, form: form, choices: choices);
  }
}
