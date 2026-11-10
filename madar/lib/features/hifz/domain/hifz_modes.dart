/// «طرق الحفظ» · the seven methods, as modes he chooses between (Part 14).
///
/// Pure Dart. Nothing here owns a microphone, a player or a screen: each
/// mode is a small piece of arithmetic over the verified text and over
/// Part 13's engine, which already knows how to judge words.
///
/// | mode | what it is | what it needs |
/// |---|---|---|
/// | [HifzMethod.listenRepeat] | «اسمع وردّد»: a range played N times with a pause between | the reciter's audio |
/// | [HifzMethod.chunking] | «التقطيع»: ayah → group → page | nothing |
/// | [HifzMethod.progressiveHiding] | «الإخفاء التدريجي»: the whole text → first letters → hidden | his words (spoken or typed) for the last stage |
/// | [HifzMethod.blanks] | «املأ الفراغ» (Part 13's `BlankDrill`) | his words |
/// | [HifzMethod.writing] | «اكتب من حفظك» and compare word by word | the keyboard |
/// | [HifzMethod.linking] | «الربط»: the end of a verse to the start of the next | his words |
/// | [HifzMethod.reciting] | «سمّع» through Part 13's checker | the on-device model |
///
/// **Nothing religious is generated.** The first-letters stage is a
/// *verbatim prefix* of the word in the verified text – the engine slices
/// the string the Quran package handed it and never writes a letter of its
/// own. The blanks, the links and the writing comparison are all positions
/// in that same original text.
///
/// **It degrades, it does not break.** Part 13's recogniser throws in this
/// build, so [HifzMethods.statusOf] answers, for every mode, whether it is
/// ready, whether it works by typing instead, or whether this phone cannot
/// do it yet – and the daily plan never schedules a mode that cannot run.
library;

import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../../../core/quran/ayah.dart';
import '../../tasmee/tasmee.dart';
import 'hifz_strength.dart';
import 'mushaf_shape.dart';

/// The seven methods, in the owner's own order.
enum HifzMethod { listenRepeat, chunking, progressiveHiding, blanks, writing, linking, reciting }

/// Whether a mode can run right now.
enum HifzMethodStatus {
  /// It runs as it should.
  ready,

  /// It runs, but only by typing: there is no speech model on this phone
  /// yet, so he answers with the keyboard instead of his voice.
  typedOnly,

  /// It cannot run at all right now (and the plan will not schedule it).
  unavailable,
}

/// Why a mode cannot run, in terms a screen can turn into one plain line.
enum HifzMethodBlocker {
  none,

  /// There is no on-device recitation model in this build.
  noRecogniser,

  /// The phone cannot run the model, or the microphone was refused.
  recogniserUnavailable,

  /// The chosen reciter's audio is not on the phone.
  audioNotDownloaded,
}

/// What one mode can do right now.
@immutable
final class HifzMethodState {
  const HifzMethodState({required this.method, required this.status, this.blocker = HifzMethodBlocker.none});

  final HifzMethod method;
  final HifzMethodStatus status;
  final HifzMethodBlocker blocker;

  bool get canRun => status != HifzMethodStatus.unavailable;
  bool get needsTyping => status == HifzMethodStatus.typedOnly;

  @override
  String toString() => 'HifzMethodState(${method.name} ${status.name}'
      '${blocker == HifzMethodBlocker.none ? '' : ', ${blocker.name}'})';
}

/// Which modes run, given what the phone can do.
abstract final class HifzMethods {
  /// The [TasmeeMode] a mode's results are written under, or null when the
  /// mode produces no judgement at all (listening and chunking do not: he
  /// heard a verse, which is no evidence that he remembers it).
  static TasmeeMode? logModeOf(HifzMethod method) => switch (method) {
    HifzMethod.listenRepeat || HifzMethod.chunking => null,
    HifzMethod.progressiveHiding => TasmeeMode.hidden,
    HifzMethod.blanks => TasmeeMode.blanks,
    HifzMethod.writing => TasmeeMode.write,
    HifzMethod.linking => TasmeeMode.link,
    HifzMethod.reciting => TasmeeMode.recite,
  };

  /// Whether the mode can be answered with the keyboard instead of the
  /// voice. «سمّع» cannot: reciting out loud is the whole point of it.
  static bool canBeTyped(HifzMethod method) => switch (method) {
    HifzMethod.progressiveHiding || HifzMethod.blanks || HifzMethod.writing || HifzMethod.linking => true,
    HifzMethod.listenRepeat || HifzMethod.chunking || HifzMethod.reciting => false,
  };

  /// What [method] can do, given the recogniser's own answer and whether
  /// the chosen reciter's audio is on the phone.
  static HifzMethodState statusOf(
    HifzMethod method, {
    required RecogniserAvailability recogniser,
    bool audioDownloaded = true,
  }) {
    if (method == HifzMethod.listenRepeat && !audioDownloaded) {
      return const HifzMethodState(
        method: HifzMethod.listenRepeat,
        status: HifzMethodStatus.unavailable,
        blocker: HifzMethodBlocker.audioNotDownloaded,
      );
    }
    if (method == HifzMethod.listenRepeat || method == HifzMethod.chunking || method == HifzMethod.writing) {
      return HifzMethodState(method: method, status: HifzMethodStatus.ready);
    }
    if (recogniser.isReady) return HifzMethodState(method: method, status: HifzMethodStatus.ready);
    final blocker = recogniser.trouble == RecogniserTrouble.notImplemented
        ? HifzMethodBlocker.noRecogniser
        : HifzMethodBlocker.recogniserUnavailable;
    if (canBeTyped(method)) {
      return HifzMethodState(method: method, status: HifzMethodStatus.typedOnly, blocker: blocker);
    }
    return HifzMethodState(method: method, status: HifzMethodStatus.unavailable, blocker: blocker);
  }

  /// Every mode's state, in the owner's order.
  static List<HifzMethodState> all({required RecogniserAvailability recogniser, bool audioDownloaded = true}) => [
    for (final m in HifzMethod.values) statusOf(m, recogniser: recogniser, audioDownloaded: audioDownloaded),
  ];

  /// The mode the plan suggests for a portion, from its strength alone:
  /// something he has never been tested on is listened to and repeated,
  /// something weak is hidden stage by stage, something firm is recited.
  /// A mode that cannot run today is never suggested.
  static HifzMethod suggestFor(
    StrengthBand band, {
    required List<HifzMethodState> states,
    bool isNew = false,
  }) {
    bool can(HifzMethod m) => states.firstWhere((s) => s.method == m, orElse: () => HifzMethodState(method: m, status: HifzMethodStatus.unavailable)).canRun;
    final wanted = isNew
        ? [HifzMethod.listenRepeat, HifzMethod.chunking, HifzMethod.progressiveHiding, HifzMethod.writing]
        : switch (band) {
            StrengthBand.unknown => [HifzMethod.progressiveHiding, HifzMethod.writing, HifzMethod.reciting],
            StrengthBand.weak => [HifzMethod.listenRepeat, HifzMethod.progressiveHiding, HifzMethod.writing],
            StrengthBand.shaky => [HifzMethod.blanks, HifzMethod.progressiveHiding, HifzMethod.writing],
            StrengthBand.firm => [HifzMethod.reciting, HifzMethod.linking, HifzMethod.writing],
            StrengthBand.solid => [HifzMethod.reciting, HifzMethod.linking, HifzMethod.blanks],
            StrengthBand.skipped => <HifzMethod>[],
          };
    for (final m in wanted) {
      if (can(m)) return m;
    }
    return HifzMethod.chunking; // always runs: it only cuts the range up
  }
}

// ------------------------------------------------------- typed answers ----

/// Words he typed, in the shape Part 13's aligner already understands.
///
/// There is no recogniser involved, so the confidence is 1.0: he typed
/// these letters himself and the engine is not guessing at a sound. The
/// times are a plain running index – nothing was recorded and no audio
/// exists anywhere in this path.
abstract final class TypedWords {
  /// Who "judged" a typed answer: nobody. The log records this instead of
  /// a model's name, so a reader of the export can tell at a glance that
  /// no speech model was involved.
  static const RecogniserInfo byHand = RecogniserInfo(
    id: 'typed',
    version: '1',
    name: 'typed by hand',
    licence: 'n/a',
    credit: null,
  );

  /// [text] cut into words, each one a [HeardWord] the aligner can take.
  static List<HeardWord> of(String text) {
    final out = <HeardWord>[];
    var i = 0;
    for (final part in text.split(RegExp(r'\s+'))) {
      if (TasmeeFold.word(part).isEmpty) continue;
      out.add(HeardWord(heard: part, at: Duration(milliseconds: i * 1000), confidence: 1.0));
      i++;
    }
    return out;
  }
}

// ----------------------------------------------------- listen and repeat ----

/// «اسمع وردّد»: what to play, how many times, with what pause.
///
/// It produces a *plan*, not sound: the player of `lib/features/recitation/`
/// takes these numbers (they are exactly `RecitationQueue.build`'s). It
/// also says, honestly, which ayat of the range the chosen reciter does
/// **not** have on the phone, so a screen can offer to download them or to
/// stream instead of failing mid-verse.
@immutable
final class ListenRepeatPlan {
  const ListenRepeatPlan({
    required this.range,
    required this.reciterId,
    required this.timesPerAyah,
    required this.passes,
    required this.gap,
    required this.ayatMissingAudio,
    required this.ayahCount,
  });

  /// Builds the plan. [downloaded] answers whether one ayah's audio is on
  /// the phone; when it is not given, nothing is claimed about the files
  /// and [ayatMissingAudio] is empty.
  factory ListenRepeatPlan.build(
    MushafShape shape,
    AyahRange range, {
    required String reciterId,
    int timesPerAyah = 3,
    int passes = 1,
    Duration gap = const Duration(seconds: 2),
    bool Function(AyahRef ref)? downloaded,
  }) {
    final clamped = Mushaf.clamp(shape, range);
    final ayat = Mushaf.ayatIn(shape, clamped);
    return ListenRepeatPlan(
      range: clamped,
      reciterId: reciterId,
      timesPerAyah: timesPerAyah < 1 ? 1 : timesPerAyah,
      passes: passes < 1 ? 1 : passes,
      gap: gap.isNegative ? Duration.zero : gap,
      ayahCount: ayat.length,
      ayatMissingAudio: List.unmodifiable(
        downloaded == null ? const <AyahRef>[] : [for (final a in ayat) if (!downloaded(a)) a],
      ),
    );
  }

  final AyahRange range;
  final String reciterId;

  /// How many times each ayah is played before moving on.
  final int timesPerAyah;

  /// How many times the whole range is gone through.
  final int passes;

  /// The silence after every playing of an ayah – his turn to repeat.
  final Duration gap;

  /// Ayat of the range whose audio is not on the phone.
  final List<AyahRef> ayatMissingAudio;

  final int ayahCount;

  /// Everything is on the phone, so it plays in flight mode.
  bool get playsOffline => ayatMissingAudio.isEmpty;

  /// How many times a verse is heard in all.
  int get totalPlays => ayahCount * timesPerAyah * passes;

  @override
  String toString() => 'ListenRepeatPlan($range ×$timesPerAyah ×$passes${playsOffline ? '' : ', audio missing'})';
}

// ------------------------------------------------------------ chunking ----

/// How big one chunk is.
enum ChunkLevel {
  /// One ayah at a time.
  ayah,

  /// A group of ayat.
  group,

  /// A whole page.
  page,
}

/// «التقطيع»: the ladder from one ayah to the whole page.
@immutable
final class ChunkLadder {
  const ChunkLadder({required this.range, required this.groupSize, required this.steps});

  /// Builds the three levels over [range]: every ayah on its own, then
  /// groups of [groupSize] (cut at surah ends, never across one), then the
  /// pages the range touches, clipped to it.
  factory ChunkLadder.build(MushafShape shape, AyahRange range, {int groupSize = 5}) {
    final clamped = Mushaf.clamp(shape, range);
    final ayat = Mushaf.ayatIn(shape, clamped);
    final size = groupSize < 1 ? 1 : groupSize;
    final groups = <AyahRange>[];
    var i = 0;
    while (i < ayat.length) {
      var j = i;
      while (j + 1 < ayat.length && j - i + 1 < size && ayat[j + 1].surah == ayat[i].surah) {
        j++;
      }
      groups.add(AyahRange(ayat[i], ayat[j]));
      i = j + 1;
    }
    final pages = <AyahRange>[];
    for (final p in Mushaf.pagesOf(shape, clamped)) {
      final start = shape.pageStart(p);
      final end = shape.pageEnd(p);
      final first = start < clamped.first ? clamped.first : start;
      final last = clamped.last < end ? clamped.last : end;
      if (last < first) continue;
      pages.add(AyahRange(first, last));
    }
    return ChunkLadder(
      range: clamped,
      groupSize: size,
      steps: List.unmodifiable([
        ChunkStep(level: ChunkLevel.ayah, chunks: List.unmodifiable([for (final a in ayat) AyahRange.single(a)])),
        ChunkStep(level: ChunkLevel.group, chunks: List.unmodifiable(groups)),
        ChunkStep(level: ChunkLevel.page, chunks: List.unmodifiable(pages)),
      ]),
    );
  }

  final AyahRange range;
  final int groupSize;
  final List<ChunkStep> steps;

  ChunkStep stepOf(ChunkLevel level) => steps.firstWhere((s) => s.level == level);

  @override
  String toString() => 'ChunkLadder($range, ${steps.map((s) => s.chunks.length).join('/')})';
}

/// One level of the ladder.
@immutable
final class ChunkStep {
  const ChunkStep({required this.level, required this.chunks});

  final ChunkLevel level;
  final List<AyahRange> chunks;

  @override
  String toString() => 'ChunkStep(${level.name}, ${chunks.length})';
}

// -------------------------------------------------- progressive hiding ----

/// The three stages of «الإخفاء التدريجي».
enum HidingStage {
  /// The whole verified text in front of him.
  full,

  /// Only the first letters of each word – a verbatim prefix of the word,
  /// never a letter of the engine's own.
  firstLetters,

  /// Nothing, until he recites it (Part 13's [HiddenVerseMachine]).
  hidden,
}

/// One word reduced to its first letters, as a slice of the original.
@immutable
final class LetterHint {
  const LetterHint({required this.word, required this.hint, required this.start, required this.end});

  final AyahWord word;

  /// The first letters, **copied** out of the verified word.
  final String hint;

  /// The hint's code-unit range in the original ayah text, so a screen can
  /// place it exactly where the word is.
  final int start;
  final int end;

  /// How many code units of the word are hidden behind the hint.
  int get hiddenLength => word.end - end;

  @override
  String toString() => 'LetterHint(${word.ref}#${word.indexInAyah} $hint)';
}

/// The first-letters stage: slicing, never writing.
abstract final class FirstLetters {
  /// The first letter cluster of [word] – its first letter together with
  /// the marks sitting on it. With [withArticle] (the default) a word that
  /// starts with the definite article keeps its lam, so «ٱلْحَمْدُ» hints
  /// as «ٱلْ» and not as a bare alef.
  static String of(String word, {bool withArticle = true}) {
    if (word.isEmpty) return word;
    var i = _afterLetter(word, 0);
    if (withArticle && i < word.length && _isLam(word.codeUnitAt(i)) && _isAlef(word.codeUnitAt(0))) {
      i = _afterLetter(word, i);
    }
    return word.substring(0, i);
  }

  /// Every word of [target] as a hint, in order.
  static List<LetterHint> ofTarget(RecitationTarget target, {bool withArticle = true}) => [
    for (final w in target.words)
      LetterHint(
        word: w,
        hint: of(w.text, withArticle: withArticle),
        start: w.start,
        end: w.start + of(w.text, withArticle: withArticle).length,
      ),
  ];

  /// The stage the plan starts a portion at, from its strength: nothing
  /// known or weak starts with the text in front of him, shaky with the
  /// first letters, firm or better with nothing.
  static HidingStage stageFor(StrengthBand band) => switch (band) {
    StrengthBand.unknown || StrengthBand.weak => HidingStage.full,
    StrengthBand.shaky => HidingStage.firstLetters,
    StrengthBand.firm || StrengthBand.solid || StrengthBand.skipped => HidingStage.hidden,
  };

  /// The next stage up, or null once there is nothing left to hide.
  static HidingStage? harder(HidingStage stage) => switch (stage) {
    HidingStage.full => HidingStage.firstLetters,
    HidingStage.firstLetters => HidingStage.hidden,
    HidingStage.hidden => null,
  };

  static int _afterLetter(String word, int from) {
    var i = from + 1;
    while (i < word.length && _isMark(word.codeUnitAt(i))) {
      i++;
    }
    return i;
  }

  /// Harakat, tanween, shadda, sukun, the superscript alef, the Quranic
  /// annotation signs and the tatweel – everything that hangs on a letter
  /// rather than being one.
  static bool _isMark(int c) =>
      (c >= 0x064B && c <= 0x065F) || c == 0x0670 || (c >= 0x06D6 && c <= 0x06ED) || c == 0x0640;

  static bool _isAlef(int c) => c == 0x0627 || c == 0x0671 || c == 0x0622 || c == 0x0623 || c == 0x0625;

  static bool _isLam(int c) => c == 0x0644;
}

// -------------------------------------------------------------- linking ----

/// One join: the end of an ayah and the start of the next.
@immutable
final class AyahLink {
  const AyahLink({required this.from, required this.to, required this.tail, required this.head});

  final AyahRef from;
  final AyahRef to;

  /// The last words of [from], as the verified text writes them.
  final List<AyahWord> tail;

  /// The first words of [to] – what he has to produce.
  final List<AyahWord> head;

  @override
  String toString() => 'AyahLink($from → $to)';
}

/// How one join went.
@immutable
final class LinkResult {
  const LinkResult({required this.link, required this.words});

  final AyahLink link;

  /// The check of the head words, in order.
  final List<WordCheck> words;

  bool get isRight => words.isNotEmpty && words.every((w) => w.verdict == WordVerdict.right);
  bool get isPending => words.every((w) => w.verdict == WordVerdict.pending);
  int get hints => words.where((w) => w.hinted).length;

  @override
  String toString() => 'LinkResult(${link.from} → ${link.to}, ${isRight ? 'right' : 'not yet'})';
}

/// «الربط»: practising the joins, not the verses.
abstract final class Linking {
  /// The joins inside [target] – one per pair of neighbouring ayat, so a
  /// target of one ayah has none.
  static List<AyahLink> of(RecitationTarget target, {int tailWords = 3, int headWords = 3}) {
    final out = <AyahLink>[];
    for (var i = 0; i + 1 < target.ayat.length; i++) {
      final a = target.ayat[i];
      final b = target.ayat[i + 1];
      final tailFrom = math.max(a.firstWord, a.lastWord - tailWords + 1);
      final headTo = math.min(b.lastWord, b.firstWord + headWords - 1);
      out.add(
        AyahLink(
          from: a.ref,
          to: b.ref,
          tail: List.unmodifiable(target.words.sublist(tailFrom, a.lastWord + 1)),
          head: List.unmodifiable(target.words.sublist(b.firstWord, headTo + 1)),
        ),
      );
    }
    return out;
  }

  /// Scores the joins out of a finished check: only the head words count,
  /// everything else he recited is context.
  static List<LinkResult> score(RecitationCheck check, List<AyahLink> links) => [
    for (final link in links)
      LinkResult(
        link: link,
        words: [for (final w in link.head) check.words[w.index]],
      ),
  ];
}

// ------------------------------------------------------ writing by hand ----

/// «اكتب من حفظك»: what he wrote, against the verified text.
///
/// The comparison is Part 13's own aligner, so the honesty rules are the
/// same ones: every verdict is positioned in the **original** ayah text by
/// code-unit range, a word he never reached is `pending` and not a
/// mistake, and what he typed is kept apart from the verified word and
/// never styled as Quran.
@immutable
final class WritingResult {
  const WritingResult({required this.check, required this.typed});

  final RecitationCheck check;

  /// How many words he actually wrote.
  final int typed;

  List<WordCheck> get words => check.words;

  /// Words of the text that are not in what he wrote, in order.
  List<WordCheck> get missed => [for (final w in check.words) if (w.verdict == WordVerdict.skipped) w];

  /// Words he wrote in the wrong place or that are not in the text.
  List<ExtraWord> get extras => check.inserted;

  RecitationCounts get counts => check.counts;

  bool get isClean => check.isClean;

  double? get accuracy => counts.accuracy;

  @override
  String toString() => 'WritingResult($counts)';
}

/// A running writing drill: he types, it compares, nothing is kept but
/// words.
class WritingDrill {
  WritingDrill(this.target, {this.options = const AlignmentOptions()});

  final RecitationTarget target;
  final AlignmentOptions options;
  String _text = '';
  WritingResult? _cached;

  /// What he has written so far.
  String get text => _text;

  /// Replaces what he wrote (a text field hands the whole value over).
  void write(String text) {
    if (_text == text) return;
    _text = text;
    _cached = null;
  }

  /// The comparison as it stands.
  WritingResult get result {
    final cached = _cached;
    if (cached != null) return cached;
    final heard = TypedWords.of(_text);
    final check = TasmeeAligner.align(target, heard, options: options);
    return _cached = WritingResult(check: check, typed: heard.length);
  }

  void reset() {
    _text = '';
    _cached = null;
  }
}
