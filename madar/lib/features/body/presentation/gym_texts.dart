/// The gym's words: a set, a rest, a personal best, and the four lines of
/// [NextLoad].
///
/// Every line about the next session says **what he did** and what his own
/// difference comes to. Nothing here tells him to do anything; the wording
/// is part of the health rule, not decoration.
library;

import 'package:flutter/widgets.dart';

import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../domain/gym.dart';
import '../domain/training.dart';
import 'body_texts.dart';

class GymTexts {
  GymTexts(this.tx);

  factory GymTexts.of(BuildContext context) => GymTexts(BodyTexts.of(context));

  final BodyTexts tx;

  L10n get l => tx.l;

  MadarFormatter get fmt => tx.fmt;

  /// "١٠ × ٥٠ كغ", "١٠ تكرار" without a weight, "٥٠ كغ" without reps.
  String repsWeight(int? reps, double? weight) {
    final hasReps = reps != null && reps > 0;
    final hasWeight = weight != null && weight > 0;
    if (hasReps && hasWeight) {
      return fmt.localizeDigits(l.gymSetBy(fmt.formatInt(reps), tx.kg(weight)));
    }
    if (hasReps) return tx.reps(reps);
    if (hasWeight) return tx.kg(weight);
    return l.bodyNotSet;
  }

  String set(LoggedSet s) => repsWeight(s.reps, s.weight);

  /// "٩٠ ث".
  String seconds(int value) => fmt.localizeDigits(l.gymSecondsValue(fmt.formatInt(value)));

  /// A running rest: `01:30`.
  String clock(Duration d) {
    final v = d.isNegative ? Duration.zero : d;
    final m = v.inMinutes, s = v.inSeconds.remainder(60);
    return fmt.localizeDigits('${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}');
  }

  /// The muscles he typed, as one line.
  String muscles(List<String> muscles) => muscles.isEmpty ? l.gymNoMuscles : muscles.join(l.bodyListSep);

  /// What the arithmetic comes to: "٥٢٫٥ كغ × ١٠", or reps alone for a
  /// movement he does without a weight.
  String loadValue(NextLoad n) => n.byReps ? repsWeight(n.reps, null) : repsWeight(n.reps, n.weight);

  /// What he actually did last time.
  String lastValue(NextLoad n) => n.byReps ? repsWeight(n.lastReps, null) : repsWeight(n.lastReps, n.last);

  /// The difference he put there himself.
  String stepValue(NextLoad n) {
    final step = n.step;
    if (step == null) return l.bodyNotSet;
    if (n.byReps || n.basis == LoadBasis.repsUp) return tx.reps(step.round());
    return tx.kg(step);
  }

  /// The one line that carries the number, worded as his own arithmetic.
  String headline(NextLoad n) => switch (n.basis) {
    LoadBasis.nothingYet => l.gymNothingYetBody,
    LoadBasis.sameStep => l.gymSameStepLine(loadValue(n)),
    LoadBasis.repsUp => l.gymRepsUpLine(loadValue(n)),
    LoadBasis.lastTime => l.gymRepeatLine(loadValue(n)),
  };

  /// The supporting lines, in reading order: what he lifted last time, the
  /// step he took, and how many of his own days were read.
  List<String> evidence(NextLoad n) => [
    if (n.lastReps != null || n.last != null) l.gymLastTimeValue(lastValue(n)),
    if (n.step != null && n.basis == LoadBasis.sameStep) l.gymYourStep(stepValue(n)),
    if (n.sessions > 0) fmt.localizeDigits(l.gymFromDays(n.sessions)),
  ];

  /// What a screen reader says for the whole card: the number, then where
  /// it came from, then that it is not advice.
  String loadSemantics(NextLoad n) => [l.gymNextTitle, headline(n), ...evidence(n), l.gymNotAdvice].join('. ');
}
