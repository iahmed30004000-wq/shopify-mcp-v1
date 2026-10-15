/// «قوّة الآية» · how strongly he holds one ayah (Part 14).
///
/// Pure Dart, and the one rule that matters: **the strength is computed
/// from results that actually happened, and from nothing else.** Opening a
/// screen, scrolling a page, playing the audio or adding an ayah to his
/// Hifz list change it by exactly zero. It is never stored either – there
/// is no strength column anywhere – so it can never drift away from the
/// log it came from: ask for it and it is recomputed from Part 13's rows.
///
/// ## What counts as a result
///
/// One row of `tasmee_ayat` – one ayah of one session of «التسميع» – is one
/// attempt. That is the only input, which is why Part 13 writes a row even
/// for a clean recitation. It covers every mode that judges words against
/// the verified text: reciting out loud, the hidden page, fill in the
/// blank, writing from memory, the first-letters stage and the linking
/// drill. «شازام القرآن» ([TasmeeMode.find]) is a lookup, not a test of his
/// memory, so it is **not** an attempt.
///
/// **Listening is not a result.** «اسمع وردّد» records nothing here: he
/// heard a verse, which is not evidence that he remembers it.
///
/// ## The number
///
/// For one attempt:
///
/// ```text
/// reached  = right + wrong + skipped + unsure        (words he got to)
/// credit   = right − mistakeWeight × (wrong + skipped)
///                  − hintWeight × hints − extraWeight × extras
/// score    = clamp(credit / reached, 0 … 1)
/// coverage = reached / words                         (how much he did)
/// ```
///
/// A wrong word costs more than the word it failed to earn
/// ([HifzStrengthModel.mistakeWeight]), so one slip in a ten-word verse
/// reads as «ثابتة» and two as «مهزوزة», instead of both passing as
/// «متينة».
///
/// A peek is half a mistake ([HifzStrengthModel.hintWeight]): he produced
/// the word, but not from memory. A word the recogniser was unsure about is
/// neither right nor wrong – it lands in `reached` and not in `credit`, so
/// it lowers the score without being called a mistake.
///
/// Over the attempts of one ayah, newest first:
///
/// ```text
/// weightᵏ  = coverageᵏ × attemptDecay^k        (k = 0 is the newest)
/// recall   = Σ scoreᵏ·weightᵏ / Σ weightᵏ
/// halfLife = freshHalfLifeDays × halfLifeGrowth^cleanRun   (capped)
/// freshness= halfLife / (halfLife + days since the last attempt)
/// strength = recall × freshness
/// ```
///
/// So: the newest attempt carries most of the weight (a clean recitation
/// today raises it, a failed one today lowers it), a run of clean attempts
/// makes it fade slowly, and a single shaky attempt makes it fade fast. The
/// forgetting curve is hyperbolic rather than exponential on purpose:
/// `halfLife / (halfLife + days)` is plain division, identical on every
/// phone and in every test, where `exp` is not.
///
/// An ayah with no attempt at all is [StrengthBand.unknown] – **not** zero
/// and not weak. The engine says "I have never heard you recite this"
/// instead of inventing a number, and the daily plan treats the two
/// differently.
library;

import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../../../core/quran/ayah.dart';
import '../../tasmee/tasmee.dart';
import '../../wird/domain/calendar_days.dart';
import 'hifz_marks.dart';

/// The constants of the strength function, in one place so they can be
/// read, argued with and tested.
@immutable
final class HifzStrengthModel {
  const HifzStrengthModel({
    this.mistakeWeight = 0.5,
    this.hintWeight = 0.5,
    this.extraWeight = 0.5,
    this.attemptDecay = 0.6,
    this.freshHalfLifeDays = 3.0,
    this.halfLifeGrowth = 1.8,
    this.maxHalfLifeDays = 180.0,
    this.weakBelow = 0.45,
    this.shakyBelow = 0.70,
    this.firmBelow = 0.88,
  });

  static const HifzStrengthModel standard = HifzStrengthModel();

  /// A word he got wrong or went past costs half a word **on top of** the
  /// word it already failed to earn, so one slip in ten words reads as
  /// «ثابتة» and two as «مهزوزة» rather than both as «متينة».
  final double mistakeWeight;

  /// A peeked word counts as half a mistake: he produced it, but not from
  /// memory.
  final double hintWeight;

  /// A word that is not in the text counts as half a mistake.
  final double extraWeight;

  /// How much weight each older attempt keeps (0 … 1).
  final double attemptDecay;

  /// Days for the strength to halve after one clean attempt.
  final double freshHalfLifeDays;

  /// How much the half-life grows per clean attempt in a row.
  final double halfLifeGrowth;

  /// The longest half-life, however many clean attempts he has.
  final double maxHalfLifeDays;

  /// Band boundaries: below [weakBelow] is weak, below [shakyBelow] shaky,
  /// below [firmBelow] firm, and at or above it solid.
  final double weakBelow;
  final double shakyBelow;
  final double firmBelow;

  /// Which modes are a test of his memory. [TasmeeMode.find] is a lookup
  /// and never counts.
  static bool judges(TasmeeMode mode) => mode != TasmeeMode.find;

  /// The half-life after [cleanRun] clean attempts in a row.
  double halfLifeFor(int cleanRun) {
    var days = freshHalfLifeDays;
    for (var i = 0; i < cleanRun; i++) {
      days *= halfLifeGrowth;
      if (days >= maxHalfLifeDays) return maxHalfLifeDays;
    }
    return days;
  }

  StrengthBand bandOf(double strength) {
    if (strength < weakBelow) return StrengthBand.weak;
    if (strength < shakyBelow) return StrengthBand.shaky;
    if (strength < firmBelow) return StrengthBand.firm;
    return StrengthBand.solid;
  }
}

/// How an ayah stands, in five plain steps – what the page map colours by.
enum StrengthBand {
  /// He has never been tested on it. Not zero, not weak: unknown.
  unknown,

  /// «ضعيفة».
  weak,

  /// «مهزوزة».
  shaky,

  /// «ثابتة».
  firm,

  /// «متينة».
  solid,

  /// «مش عليّ» – he said this one is not his to review.
  skipped,
}

/// One attempt at one ayah: one row of `tasmee_ayat`, read as evidence.
@immutable
final class HifzAttempt {
  const HifzAttempt({
    required this.ref,
    required this.sessionId,
    required this.at,
    required this.day,
    required this.mode,
    required this.counts,
  });

  final AyahRef ref;
  final String sessionId;
  final DateTime at;
  final DateTime day;
  final TasmeeMode mode;
  final RecitationCounts counts;

  /// Words he got to.
  int get reached => counts.reached;

  /// Nothing wrong, nothing peeked, and he went through the whole ayah.
  bool get isClean => counts.isClean && counts.hints == 0 && counts.pending == 0;

  /// How much of the ayah this attempt covered, 0 … 1.
  double get coverage {
    if (counts.words <= 0) return 0;
    final c = reached / counts.words;
    return c > 1 ? 1 : c;
  }

  /// The attempt's own score, 0 … 1 (see the library doc).
  double scoreWith(HifzStrengthModel model) {
    if (reached <= 0) return 0;
    final credit = counts.right -
        model.mistakeWeight * (counts.wrong + counts.skipped) -
        model.hintWeight * counts.hints -
        model.extraWeight * counts.extras;
    final s = credit / reached;
    return s.clamp(0.0, 1.0);
  }

  @override
  String toString() => 'HifzAttempt($ref ${mode.name} ${counts.right}/$reached)';
}

/// The strength of one ayah, with everything it was computed from.
@immutable
final class AyahStrength {
  const AyahStrength({
    required this.ref,
    required this.strength,
    required this.band,
    required this.attempts,
    required this.cleanAttempts,
    required this.cleanRun,
    required this.recall,
    required this.freshness,
    required this.halfLifeDays,
    required this.hints,
    required this.mistakes,
    this.lastDay,
    this.resetSince,
  });

  /// An ayah nothing is known about – never recited, never written.
  factory AyahStrength.unknown(AyahRef ref, {DateTime? resetSince}) => AyahStrength(
    ref: ref,
    strength: 0,
    band: StrengthBand.unknown,
    attempts: 0,
    cleanAttempts: 0,
    cleanRun: 0,
    recall: 0,
    freshness: 0,
    halfLifeDays: 0,
    hints: 0,
    mistakes: 0,
    resetSince: resetSince,
  );

  /// An ayah he said is not his to review.
  factory AyahStrength.skipped(AyahRef ref) => AyahStrength(
    ref: ref,
    strength: 0,
    band: StrengthBand.skipped,
    attempts: 0,
    cleanAttempts: 0,
    cleanRun: 0,
    recall: 0,
    freshness: 0,
    halfLifeDays: 0,
    hints: 0,
    mistakes: 0,
  );

  final AyahRef ref;

  /// `0.0 … 1.0`; 0 with [StrengthBand.unknown] means "no evidence", not
  /// "forgotten".
  final double strength;
  final StrengthBand band;

  /// How many attempts went into it (after a reset, only the ones since).
  final int attempts;
  final int cleanAttempts;

  /// Clean attempts in a row, counting back from the newest.
  final int cleanRun;

  /// What the attempts say on their own, before time is taken into account.
  final double recall;

  /// How much of [recall] is left after the days since the last attempt.
  final double freshness;
  final double halfLifeDays;

  final int hints;
  final int mistakes;

  /// The day of the last attempt (null when there is none).
  final DateTime? lastDay;

  /// The day he reset this stretch from, when he did.
  final DateTime? resetSince;

  bool get isKnown => band != StrengthBand.unknown && band != StrengthBand.skipped;
  bool get isSkipped => band == StrengthBand.skipped;

  /// Days since the last attempt, measured against [today]; null when there
  /// is no attempt.
  int? daysSince(DateTime today) => lastDay == null ? null : math.max(0, CalendarDays.between(lastDay!, today));

  @override
  String toString() => 'AyahStrength($ref ${band.name} ${strength.toStringAsFixed(2)}, $attempts attempts)';
}

/// The strength of every ayah he has results for, computed in one pass over
/// Part 13's log.
@immutable
final class HifzStrengths {
  const HifzStrengths._({
    required this.byRef,
    required this.today,
    required this.model,
    required this.marks,
    required this.attemptedDays,
  });

  /// Reads the log and computes a strength per ayah.
  ///
  /// [today] is the clock's day (the freshness is measured against it).
  /// [marks] applies his own decisions: an ayah he marked «مش عليّ» gets
  /// [StrengthBand.skipped] and no number, and a reset drops every result
  /// before its day.
  factory HifzStrengths.of(
    Iterable<TasmeeSession> log, {
    required DateTime today,
    HifzStrengthModel model = HifzStrengthModel.standard,
    HifzMarks marks = HifzMarks.empty,
  }) {
    final day = CalendarDays.dateOnly(today);
    final attempts = <AyahRef, List<HifzAttempt>>{};
    final days = <DateTime>{};
    for (final s in log) {
      if (!HifzStrengthModel.judges(s.mode)) continue;
      for (final a in s.ayat) {
        if (marks.skipped(a.ref)) continue;
        if (!marks.counts(a.ref, s.startedAt)) continue; // behind his own reset
        if (a.counts.reached <= 0) continue; // nothing actually happened
        (attempts[a.ref] ??= []).add(
          HifzAttempt(ref: a.ref, sessionId: s.id, at: s.startedAt, day: a.day, mode: s.mode, counts: a.counts),
        );
        days.add(a.day);
      }
    }
    final out = <AyahRef, AyahStrength>{};
    for (final MapEntry(key: ref, value: rows) in attempts.entries) {
      rows.sort((a, b) => b.at.compareTo(a.at)); // newest first
      var weighted = 0.0, weights = 0.0, decay = 1.0;
      var clean = 0, cleanRun = 0, hints = 0, mistakes = 0;
      var runOpen = true;
      for (final r in rows) {
        final w = r.coverage * decay;
        if (w > 0) {
          weighted += r.scoreWith(model) * w;
          weights += w;
        }
        if (r.isClean) {
          clean++;
          if (runOpen) cleanRun++;
        } else {
          runOpen = false;
        }
        hints += r.counts.hints;
        mistakes += r.counts.mistakes;
        decay *= model.attemptDecay;
      }
      final recall = weights <= 0 ? 0.0 : weighted / weights;
      final halfLife = model.halfLifeFor(cleanRun);
      final since = math.max(0, CalendarDays.between(rows.first.day, day));
      final freshness = halfLife / (halfLife + since);
      final strength = recall * freshness;
      out[ref] = AyahStrength(
        ref: ref,
        strength: strength,
        band: model.bandOf(strength),
        attempts: rows.length,
        cleanAttempts: clean,
        cleanRun: cleanRun,
        recall: recall,
        freshness: freshness,
        halfLifeDays: halfLife,
        hints: hints,
        mistakes: mistakes,
        lastDay: rows.first.day,
        resetSince: marks.resetDay(ref),
      );
    }
    return HifzStrengths._(
      byRef: Map.unmodifiable(out),
      today: day,
      model: model,
      marks: marks,
      attemptedDays: Set.unmodifiable(days),
    );
  }

  /// Every ayah with a result, by ref.
  final Map<AyahRef, AyahStrength> byRef;
  final DateTime today;
  final HifzStrengthModel model;
  final HifzMarks marks;

  /// Every calendar day he was tested on something (the heatmap's days).
  final Set<DateTime> attemptedDays;

  bool get isEmpty => byRef.isEmpty;

  /// The strength of [ref] – [StrengthBand.skipped] when he marked it, and
  /// [StrengthBand.unknown] when nothing was ever recorded for it.
  AyahStrength of(AyahRef ref) {
    if (marks.skipped(ref)) return AyahStrength.skipped(ref);
    return byRef[ref] ?? AyahStrength.unknown(ref, resetSince: marks.resetDay(ref));
  }

  /// Every ayah of [refs], in the order given.
  List<AyahStrength> ofAll(Iterable<AyahRef> refs) => [for (final r in refs) of(r)];

  /// The weakest known ayat of [refs] first; unknown ones come last, since
  /// "never tested" is not "weak".
  List<AyahStrength> weakestOf(Iterable<AyahRef> refs) {
    final list = ofAll(refs).where((s) => !s.isSkipped).toList();
    list.sort(compare);
    return list;
  }

  /// The order the review tracks use: weakest known first, then the ones
  /// never tested, ties broken by the ref so the plan is deterministic.
  static int compare(AyahStrength a, AyahStrength b) {
    if (a.isKnown != b.isKnown) return a.isKnown ? -1 : 1;
    final s = a.strength.compareTo(b.strength);
    return s != 0 ? s : a.ref.compareTo(b.ref);
  }

  /// The mean strength of [refs], counting only the ones with a result;
  /// null when none of them has one.
  double? meanOf(Iterable<AyahRef> refs) {
    var sum = 0.0, n = 0;
    for (final r in refs) {
      final s = of(r);
      if (!s.isKnown) continue;
      sum += s.strength;
      n++;
    }
    return n == 0 ? null : sum / n;
  }

  @override
  String toString() => 'HifzStrengths(${byRef.length} ayat)';
}
