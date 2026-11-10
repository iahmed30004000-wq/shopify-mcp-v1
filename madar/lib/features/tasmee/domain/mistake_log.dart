/// «سجل الأخطاء» · the mistake log and the statistics read off it
/// (Part 13, step 1).
///
/// Pure Dart. Three shapes, and they are exactly the three tables of schema
/// v7: one row per **session** (he pressed record, recited a range, stopped),
/// one row per **ayah** of that session, and one row per **word** that went
/// wrong. Part 14 reads the same rows from the other side to build its
/// weak-spots list and its review queue, which is why the per-ayah row
/// exists at all instead of being recomputed every time.
///
/// Every expected word, every position and every ayah number in here comes
/// from the verified text; nothing religious is generated anywhere. What
/// the recogniser thought it heard is stored under the name [heard] and
/// nowhere called text, so no screen and no export can mistake it for the
/// Quran.
///
/// **No audio.** There is no field for a recording, a file or a waveform,
/// in any of the three shapes. A session is scored and what is left is
/// words.
library;

import 'package:meta/meta.dart';

import '../../../core/domain/enums.dart';
import '../../../core/quran/ayah.dart';
import 'alignment.dart';
import 'ayah_words.dart';
import 'recogniser.dart';

/// One word that went wrong, on the day it went wrong.
@immutable
final class TasmeeMistake {
  const TasmeeMistake({
    required this.id,
    required this.sessionId,
    required this.at,
    required this.day,
    required this.ref,
    required this.wordIndex,
    required this.kind,
    required this.expected,
    required this.start,
    required this.end,
    this.heard,
    this.hinted = false,
    this.confidence,
    this.tashkeelOnly = false,
  });

  final String id;
  final String sessionId;

  /// When it happened.
  final DateTime at;

  /// The calendar day, zone-free (what the statistics group by).
  final DateTime day;

  final AyahRef ref;

  /// Which word of [ref], 0-based. For [MistakeKind.extra] it is the word
  /// the extra came **before** (so it can be drawn in the right place).
  final int wordIndex;

  final MistakeKind kind;

  /// The verified word, verbatim – empty for an extra word, where the text
  /// expected nothing.
  final String expected;

  /// Code-unit range of [expected] in the original text of [ref]. For an
  /// extra word, `start == end` at the point it was heard.
  final int start;
  final int end;

  /// What the recogniser thought it heard. **Not Quran text.** Null when
  /// nothing was heard (a skipped word).
  final String? heard;

  /// A peek had already revealed this word, so it was not his memory alone.
  final bool hinted;

  final double? confidence;

  /// The letters were right and only the harakat differed – the
  /// **experimental** check, recorded so it can be looked at later and
  /// never counted with the real mistakes.
  final bool tashkeelOnly;

  @override
  String toString() => 'TasmeeMistake($ref#$wordIndex ${kind.name}${hinted ? ', hinted' : ''})';
}

/// One ayah of one session.
@immutable
final class TasmeeAyahResult {
  const TasmeeAyahResult({
    required this.id,
    required this.sessionId,
    required this.day,
    required this.ref,
    required this.counts,
  });

  final String id;
  final String sessionId;
  final DateTime day;
  final AyahRef ref;
  final RecitationCounts counts;

  bool get isClean => counts.isClean;

  @override
  String toString() => 'TasmeeAyahResult($ref, $counts)';
}

/// One time he pressed record and recited.
@immutable
final class TasmeeSession {
  const TasmeeSession({
    required this.id,
    required this.startedAt,
    required this.day,
    required this.mode,
    required this.range,
    required this.counts,
    required this.seconds,
    required this.recogniserId,
    required this.recogniserVersion,
    required this.textSource,
    this.tashkeelChecked = false,
    this.seed,
    this.note,
    this.ayat = const [],
    this.mistakes = const [],
  });

  final String id;
  final DateTime startedAt;
  final DateTime day;
  final TasmeeMode mode;
  final AyahRange range;
  final RecitationCounts counts;

  /// How long the recitation ran.
  final int seconds;

  /// Which recogniser judged it – so a result is never read as the verdict
  /// of a different model.
  final String recogniserId;
  final String recogniserVersion;

  /// Which edition of the text it was checked against.
  final String textSource;

  /// Whether the experimental tashkeel check was on.
  final bool tashkeelChecked;

  /// The fill-in-the-blank seed, when the mode used one.
  final int? seed;
  final String? note;

  /// The per-ayah rows of this session (empty when read without them).
  final List<TasmeeAyahResult> ayat;

  /// The per-word rows of this session (empty when read without them).
  final List<TasmeeMistake> mistakes;

  TasmeeSession withChildren({List<TasmeeAyahResult>? ayat, List<TasmeeMistake>? mistakes}) => TasmeeSession(
    id: id,
    startedAt: startedAt,
    day: day,
    mode: mode,
    range: range,
    counts: counts,
    seconds: seconds,
    recogniserId: recogniserId,
    recogniserVersion: recogniserVersion,
    textSource: textSource,
    tashkeelChecked: tashkeelChecked,
    seed: seed,
    note: note,
    ayat: ayat ?? this.ayat,
    mistakes: mistakes ?? this.mistakes,
  );

  @override
  String toString() => 'TasmeeSession($range, ${mode.name}, $counts)';
}

/// A session about to be written: the same three shapes without ids, so the
/// service can mint them and the engine stays free of the database.
@immutable
final class TasmeeSessionDraft {
  const TasmeeSessionDraft({
    required this.startedAt,
    required this.mode,
    required this.range,
    required this.counts,
    required this.seconds,
    required this.recogniserId,
    required this.recogniserVersion,
    required this.textSource,
    required this.ayat,
    required this.mistakes,
    this.tashkeelChecked = false,
    this.seed,
    this.note,
  });

  /// Everything a finished [RecitationCheck] says, ready to write.
  ///
  /// Only real mistakes become rows: a word he has not reached, a word the
  /// recogniser was unsure about, the basmala before a surah and words of
  /// the text he said twice are **not** written as mistakes, because they
  /// are not mistakes. A word whose letters matched and whose harakat did
  /// not is written with [TasmeeMistake.tashkeelOnly] and is kept out of
  /// every count.
  factory TasmeeSessionDraft.ofCheck(
    RecitationCheck check, {
    required DateTime startedAt,
    required TasmeeMode mode,
    required RecogniserInfo recogniser,
    int? seed,
    String? note,
  }) {
    final day = DateTime(startedAt.year, startedAt.month, startedAt.day);
    final mistakes = <TasmeeMistakeDraft>[];
    for (final w in check.words) {
      final kind = switch (w.verdict) {
        WordVerdict.wrong => MistakeKind.wrong,
        WordVerdict.skipped => MistakeKind.skipped,
        _ => null,
      };
      if (kind == null) {
        if (w.tashkeel == TashkeelCheck.different) {
          mistakes.add(
            TasmeeMistakeDraft(
              at: startedAt.add(w.at ?? Duration.zero),
              day: day,
              ref: w.ref,
              wordIndex: w.word.indexInAyah,
              kind: MistakeKind.wrong,
              expected: w.word.text,
              start: w.word.start,
              end: w.word.end,
              heard: w.heard,
              hinted: w.hinted,
              confidence: w.confidence,
              tashkeelOnly: true,
            ),
          );
        }
        continue;
      }
      mistakes.add(
        TasmeeMistakeDraft(
          at: startedAt.add(w.at ?? Duration.zero),
          day: day,
          ref: w.ref,
          wordIndex: w.word.indexInAyah,
          kind: kind,
          expected: w.word.text,
          start: w.word.start,
          end: w.word.end,
          heard: w.heard,
          hinted: w.hinted,
          confidence: w.confidence,
        ),
      );
    }
    for (final e in check.extras) {
      if (!e.isMistake) continue;
      mistakes.add(
        TasmeeMistakeDraft(
          at: startedAt.add(e.at ?? Duration.zero),
          day: day,
          ref: e.ref,
          wordIndex: e.beforeWordInAyah,
          kind: MistakeKind.extra,
          expected: '',
          start: e.atCodeUnit,
          end: e.atCodeUnit,
          heard: e.heard,
          confidence: e.confidence,
        ),
      );
    }
    return TasmeeSessionDraft(
      startedAt: startedAt,
      mode: mode,
      range: check.range,
      counts: check.counts,
      seconds: check.listenedFor.inSeconds,
      recogniserId: recogniser.id,
      recogniserVersion: recogniser.version,
      textSource: check.target.textSource,
      tashkeelChecked: check.tashkeelChecked,
      seed: seed,
      note: note,
      ayat: [
        for (final a in check.ayat) TasmeeAyahDraft(day: day, ref: a.ref, counts: a.counts),
      ],
      mistakes: mistakes,
    );
  }

  final DateTime startedAt;
  final TasmeeMode mode;
  final AyahRange range;
  final RecitationCounts counts;
  final int seconds;
  final String recogniserId;
  final String recogniserVersion;
  final String textSource;
  final bool tashkeelChecked;
  final int? seed;
  final String? note;
  final List<TasmeeAyahDraft> ayat;
  final List<TasmeeMistakeDraft> mistakes;

  DateTime get day => DateTime(startedAt.year, startedAt.month, startedAt.day);
}

/// One ayah row about to be written.
@immutable
final class TasmeeAyahDraft {
  const TasmeeAyahDraft({required this.day, required this.ref, required this.counts});

  final DateTime day;
  final AyahRef ref;
  final RecitationCounts counts;
}

/// One mistake row about to be written.
@immutable
final class TasmeeMistakeDraft {
  const TasmeeMistakeDraft({
    required this.at,
    required this.day,
    required this.ref,
    required this.wordIndex,
    required this.kind,
    required this.expected,
    required this.start,
    required this.end,
    this.heard,
    this.hinted = false,
    this.confidence,
    this.tashkeelOnly = false,
  });

  final DateTime at;
  final DateTime day;
  final AyahRef ref;
  final int wordIndex;
  final MistakeKind kind;
  final String expected;
  final int start;
  final int end;
  final String? heard;
  final bool hinted;
  final double? confidence;
  final bool tashkeelOnly;
}

// ------------------------------------------------------- the statistics ----

/// One word he keeps getting wrong.
@immutable
final class WeakWord {
  const WeakWord({
    required this.ref,
    required this.wordIndex,
    required this.expected,
    required this.times,
    required this.hinted,
    required this.lastAt,
    required this.kinds,
    this.lastHeard,
  });

  final AyahRef ref;
  final int wordIndex;

  /// The verified word, verbatim.
  final String expected;

  /// How many times it went wrong.
  final int times;

  /// How many of those times a hint was involved.
  final int hinted;
  final DateTime lastAt;

  /// Which kinds of mistake happened here.
  final Set<MistakeKind> kinds;

  /// The last thing heard in its place. **Not Quran text.**
  final String? lastHeard;

  @override
  String toString() => 'WeakWord($ref#$wordIndex ×$times)';
}

/// One ayah, over all his attempts at it.
@immutable
final class WeakAyah {
  const WeakAyah({
    required this.ref,
    required this.attempts,
    required this.cleanAttempts,
    required this.words,
    required this.right,
    required this.mistakes,
    required this.hints,
    required this.lastAt,
  });

  final AyahRef ref;

  /// How many times he recited it.
  final int attempts;

  /// How many of those had nothing wrong at all.
  final int cleanAttempts;

  /// Words of the verified text he went through, added up over attempts.
  final int words;
  final int right;
  final int mistakes;
  final int hints;
  final DateTime lastAt;

  /// Right out of the words he reached, over all attempts; null when he
  /// reached none.
  double? get accuracy => words == 0 ? null : right / words;

  @override
  String toString() => 'WeakAyah($ref, $attempts attempts, $mistakes mistakes)';
}

/// One day of recitation.
@immutable
final class TasmeeDay {
  const TasmeeDay({
    required this.day,
    required this.sessions,
    required this.ayat,
    required this.words,
    required this.right,
    required this.mistakes,
    required this.hints,
    required this.seconds,
  });

  final DateTime day;
  final int sessions;
  final int ayat;
  final int words;
  final int right;
  final int mistakes;
  final int hints;
  final int seconds;

  double? get accuracy => words == 0 ? null : right / words;

  @override
  String toString() => 'TasmeeDay(${day.year}-${day.month}-${day.day}, $sessions sessions)';
}

/// Everything the progress screens show, read off the log and nothing else.
@immutable
final class TasmeeStats {
  const TasmeeStats({
    required this.sessions,
    required this.ayatRecited,
    required this.distinctAyat,
    required this.counts,
    required this.seconds,
    required this.weakWords,
    required this.weakAyat,
    required this.days,
    required this.streakDays,
    required this.firstAt,
    required this.lastAt,
  });

  static const TasmeeStats empty = TasmeeStats(
    sessions: 0,
    ayatRecited: 0,
    distinctAyat: 0,
    counts: RecitationCounts.zero,
    seconds: 0,
    weakWords: [],
    weakAyat: [],
    days: [],
    streakDays: 0,
    firstAt: null,
    lastAt: null,
  );

  /// Reads the statistics off [log]. Nothing is stored: the numbers are
  /// always the log's own.
  ///
  /// [today] is only used for the streak (how many days in a row up to and
  /// including today, or up to yesterday when he has not recited today yet).
  factory TasmeeStats.of(Iterable<TasmeeSession> log, {DateTime? today}) {
    final sessions = log.toList()..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    if (sessions.isEmpty) return empty;
    var words = 0, right = 0, wrong = 0, skipped = 0, unsure = 0, pending = 0, extras = 0, hints = 0, tashkeel = 0;
    var seconds = 0;
    var ayatRecited = 0;
    final byWord = <(AyahRef, int), List<TasmeeMistake>>{};
    final byAyah = <AyahRef, List<TasmeeAyahResult>>{};
    final byDay = <DateTime, List<TasmeeSession>>{};
    for (final s in sessions) {
      words += s.counts.words;
      right += s.counts.right;
      wrong += s.counts.wrong;
      skipped += s.counts.skipped;
      unsure += s.counts.unsure;
      pending += s.counts.pending;
      extras += s.counts.extras;
      hints += s.counts.hints;
      tashkeel += s.counts.tashkeelDifferent;
      seconds += s.seconds;
      ayatRecited += s.ayat.length;
      (byDay[s.day] ??= []).add(s);
      for (final a in s.ayat) {
        (byAyah[a.ref] ??= []).add(a);
      }
      for (final m in s.mistakes) {
        if (m.tashkeelOnly) continue; // experimental; never a weak spot yet
        (byWord[(m.ref, m.wordIndex)] ??= []).add(m);
      }
    }

    final weakWords = <WeakWord>[];
    for (final MapEntry(key: (ref, index), value: hits) in byWord.entries) {
      final sorted = [...hits]..sort((a, b) => a.at.compareTo(b.at));
      final last = sorted.last;
      weakWords.add(
        WeakWord(
          ref: ref,
          wordIndex: index,
          expected: sorted.map((m) => m.expected).firstWhere((e) => e.isNotEmpty, orElse: () => ''),
          times: sorted.length,
          hinted: sorted.where((m) => m.hinted).length,
          lastAt: last.at,
          kinds: {for (final m in sorted) m.kind},
          lastHeard: last.heard,
        ),
      );
    }
    weakWords.sort((a, b) {
      final byTimes = b.times.compareTo(a.times);
      if (byTimes != 0) return byTimes;
      final byDate = b.lastAt.compareTo(a.lastAt);
      return byDate != 0 ? byDate : a.ref.compareTo(b.ref);
    });

    final weakAyat = <WeakAyah>[];
    for (final MapEntry(key: ref, value: rows) in byAyah.entries) {
      var w = 0, r = 0, m = 0, h = 0, clean = 0;
      DateTime? last;
      for (final row in rows) {
        w += row.counts.reached;
        r += row.counts.right;
        m += row.counts.mistakes;
        h += row.counts.hints;
        if (row.isClean) clean++;
        if (last == null || row.day.isAfter(last)) last = row.day;
      }
      weakAyat.add(
        WeakAyah(
          ref: ref,
          attempts: rows.length,
          cleanAttempts: clean,
          words: w,
          right: r,
          mistakes: m,
          hints: h,
          lastAt: last!,
        ),
      );
    }
    weakAyat.sort((a, b) {
      final byMistakes = b.mistakes.compareTo(a.mistakes);
      return byMistakes != 0 ? byMistakes : a.ref.compareTo(b.ref);
    });

    final days = <TasmeeDay>[];
    final dayKeys = byDay.keys.toList()..sort();
    for (final key in dayKeys) {
      final mine = byDay[key]!;
      var w = 0, r = 0, m = 0, h = 0, sec = 0, ay = 0;
      for (final s in mine) {
        w += s.counts.reached;
        r += s.counts.right;
        m += s.counts.mistakes;
        h += s.counts.hints;
        sec += s.seconds;
        ay += s.ayat.length;
      }
      days.add(
        TasmeeDay(day: key, sessions: mine.length, ayat: ay, words: w, right: r, mistakes: m, hints: h, seconds: sec),
      );
    }

    return TasmeeStats(
      sessions: sessions.length,
      ayatRecited: ayatRecited,
      distinctAyat: byAyah.length,
      counts: RecitationCounts(
        words: words,
        right: right,
        wrong: wrong,
        skipped: skipped,
        unsure: unsure,
        pending: pending,
        extras: extras,
        hints: hints,
        tashkeelDifferent: tashkeel,
      ),
      seconds: seconds,
      weakWords: List.unmodifiable(weakWords),
      weakAyat: List.unmodifiable(weakAyat),
      days: List.unmodifiable(days),
      streakDays: _streak(dayKeys.toSet(), today),
      firstAt: sessions.first.startedAt,
      lastAt: sessions.last.startedAt,
    );
  }

  final int sessions;

  /// Ayah attempts, counting an ayah recited twice as two.
  final int ayatRecited;

  /// Distinct ayat he has ever recited.
  final int distinctAyat;

  final RecitationCounts counts;
  final int seconds;

  /// Worst first.
  final List<WeakWord> weakWords;
  final List<WeakAyah> weakAyat;

  /// Every day he recited, oldest first.
  final List<TasmeeDay> days;

  /// Days in a row up to today (or up to yesterday when today is still
  /// empty, so a streak is not broken before the day is over).
  final int streakDays;

  final DateTime? firstAt;
  final DateTime? lastAt;

  bool get isEmpty => sessions == 0;

  /// The weak words of one ayah.
  List<WeakWord> weakWordsOf(AyahRef ref) => [for (final w in weakWords) if (w.ref == ref) w];

  static int _streak(Set<DateTime> days, DateTime? today) {
    if (days.isEmpty || today == null) return 0;
    var cursor = DateTime(today.year, today.month, today.day);
    if (!days.contains(cursor)) {
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
      if (!days.contains(cursor)) return 0;
    }
    var n = 0;
    while (days.contains(cursor)) {
      n++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    return n;
  }
}
