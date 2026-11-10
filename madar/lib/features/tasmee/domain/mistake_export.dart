/// «تصدير سجل التسميع» · the mistake log as documented JSON, for «فلك»
/// (Part 13, step 1).
///
/// Pure Dart, plain data (pass it to `jsonEncode`), and the format is
/// written down here because another program – the PC app «فلك» – has to
/// read it without asking anyone. Syncing is a later phase: this is a
/// one-way, human-readable dump.
///
/// ## The format
///
/// ```json
/// {
///   "format": "madar.tasmee.log",
///   "formatVersion": 1,
///   "exportedAt": "2026-10-15T19:20:00.000Z",
///   "text": {"source": "tanzil-uthmani", "script": "uthmani", "riwaya": "hafs"},
///   "notice": "…what every field means, in one paragraph…",
///   "sessions": [
///     {
///       "id": "a1b2…",
///       "startedAt": "2026-10-15T19:12:03.000Z",
///       "day": "2026-10-15",
///       "mode": "hidden",
///       "range": {"from": "2:255", "to": "2:255"},
///       "seconds": 41,
///       "recogniser": {"id": "fake", "version": "1"},
///       "textSource": "tanzil-uthmani",
///       "tashkeelChecked": false,
///       "seed": null,
///       "note": null,
///       "counts": {"words": 50, "right": 47, "wrong": 1, "skipped": 1,
///                  "unsure": 1, "pending": 0, "extras": 0, "hints": 1,
///                  "tashkeelDifferent": 0},
///       "ayat": [
///         {"ref": "2:255", "surah": 2, "ayah": 255, "clean": false,
///          "counts": {…same shape…}}
///       ],
///       "mistakes": [
///         {"ref": "2:255", "surah": 2, "ayah": 255, "word": 7,
///          "kind": "wrong", "expected": "ٱلْحَىُّ",
///          "span": {"start": 34, "end": 41},
///          "heard": "الحي", "hinted": false, "confidence": 0.74,
///          "tashkeelOnly": false, "at": "2026-10-15T19:12:09.000Z"}
///       ]
///     }
///   ],
///   "stats": {
///     "sessions": 12, "ayatRecited": 40, "distinctAyat": 18,
///     "seconds": 900, "streakDays": 3,
///     "firstAt": "…", "lastAt": "…",
///     "counts": {…same shape…},
///     "days": [{"day": "2026-10-15", "sessions": 2, "ayat": 6, "words": 90,
///               "right": 85, "mistakes": 5, "hints": 1, "seconds": 120}],
///     "weakWords": [{"ref": "2:255", "surah": 2, "ayah": 255, "word": 7,
///                    "expected": "ٱلْحَىُّ", "times": 3, "hinted": 1,
///                    "kinds": ["wrong"], "lastHeard": "الحي",
///                    "lastAt": "…"}],
///     "weakAyat": [{"ref": "2:255", "surah": 2, "ayah": 255, "attempts": 4,
///                   "cleanAttempts": 1, "words": 200, "right": 188,
///                   "mistakes": 12, "hints": 2, "lastAt": "2026-10-15"}]
///   }
/// }
/// ```
///
/// ## The rules a reader must know
///
/// * **`heard` is not Quran text.** It is what the on-device recogniser
///   thought it heard. A reader must label it as such and must never render
///   it in a Quran typeface, beside a verse, or as a correction. `expected`
///   is the verified word, verbatim, from the edition named in `text`.
/// * **`span` is a code-unit range of the original ayah text** of that
///   edition (`start` inclusive, `end` exclusive), not of a folded or
///   normalised form. For `kind: "extra"` the text expected nothing, so
///   `expected` is `""` and `start == end` marks where the extra word was
///   heard; `word` is then the index of the word it came **before**.
/// * **`word` is 0-based inside its own ayah**, counting only real words:
///   the Uthmani pause and hizb signs (`ۖ ۗ ۚ ۛ ۘ ۙ ۞`) are not words.
/// * **`kind`** is `wrong` · `skipped` · `extra`. Nothing else is a mistake:
///   a word he never reached, a word the recogniser was unsure about, the
///   basmala before a surah and words of the text recited twice are not in
///   this list at all.
/// * **`tashkeelOnly: true`** marks the experimental diacritics check: the
///   letters were right and the harakat differed. It is **not** counted in
///   `counts` and must be shown, if at all, as experimental.
/// * **Dates**: `at`, `startedAt`, `firstAt`, `lastAt` are full ISO-8601
///   UTC instants; `day` and the `lastAt` of `weakAyat` are calendar days
///   `YYYY-MM-DD` with no zone, because a day must not move when the phone
///   changes country.
/// * **Counts** always have the same nine keys, so one reader does for a
///   session, an ayah and the whole history.
/// * **There is no audio in this file, ever**, and no field for it: the
///   recording is gone the moment the recitation was scored.
/// * Numbers are decimal in the JSON (a reader formats them however it
///   likes); `confidence` is `0.0 … 1.0` or absent.
library;

import '../../../core/domain/enums.dart';
import '../../../core/quran/ayah.dart';
import 'alignment.dart';
import 'mistake_log.dart';

/// The export's own name and version, written into every file.
const String tasmeeExportFormat = 'madar.tasmee.log';

/// Bumped when a reader would have to change.
const int tasmeeExportFormatVersion = 1;

/// The one-paragraph notice shipped inside every export, so a reader that
/// never saw this file still knows the two rules that matter.
const String tasmeeExportNotice =
    'كل كلمة بـ "expected" هي من النص المصحفي المعتمد بالتطبيق وما تغيّرت ولا حرف. '
    'أمّا "heard" فهو اللي سمعه برنامج التعرّف على الصوت من قراءته، وهو مش قرآن: '
    'ما ينفع يُعرض بخط المصحف ولا جانب الآية ولا كأنه تصحيح. المواقع (span) هي أرقام '
    'الأحرف بنص الآية الأصلي نفسه. وما في بهذا الملف أي صوت، ولا حتى خانة له.';

/// Builds the export.
abstract final class TasmeeExport {
  /// The whole log plus the statistics read off it.
  ///
  /// [includeHeard] writes what the recogniser heard. It is on by default
  /// because the owner asked for «اللي سمعه التطبيق منك» to be in the log;
  /// turning it off strips every `heard` and `lastHeard` and leaves the
  /// positions and the verified words, for an export he wants to hand to
  /// someone else.
  static Map<String, Object?> build(
    Iterable<TasmeeSession> log, {
    required DateTime exportedAt,
    DateTime? today,
    bool includeHeard = true,
    String script = 'uthmani',
    String riwaya = 'hafs',
  }) {
    final sessions = log.toList()..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    final stats = TasmeeStats.of(sessions, today: today);
    return {
      'format': tasmeeExportFormat,
      'formatVersion': tasmeeExportFormatVersion,
      'exportedAt': exportedAt.toUtc().toIso8601String(),
      'text': {
        'source': sessions.isEmpty ? null : sessions.first.textSource,
        'script': script,
        'riwaya': riwaya,
      },
      'notice': tasmeeExportNotice,
      'sessions': [for (final s in sessions) session(s, includeHeard: includeHeard)],
      'stats': statistics(stats, includeHeard: includeHeard),
    };
  }

  /// One session, with its ayat and its mistakes.
  static Map<String, Object?> session(TasmeeSession s, {bool includeHeard = true}) => {
    'id': s.id,
    'startedAt': s.startedAt.toUtc().toIso8601String(),
    'day': day(s.day),
    'mode': s.mode.name,
    'range': {'from': s.range.first.toString(), 'to': s.range.last.toString()},
    'seconds': s.seconds,
    'recogniser': {'id': s.recogniserId, 'version': s.recogniserVersion},
    'textSource': s.textSource,
    'tashkeelChecked': s.tashkeelChecked,
    'seed': s.seed,
    'note': s.note,
    'counts': s.counts.toJson(),
    'ayat': [
      for (final a in s.ayat)
        {...ref(a.ref), 'clean': a.isClean, 'counts': a.counts.toJson()},
    ],
    'mistakes': [
      for (final m in s.mistakes)
        {
          ...ref(m.ref),
          'word': m.wordIndex,
          'kind': m.kind.name,
          'expected': m.expected,
          'span': {'start': m.start, 'end': m.end},
          if (includeHeard) 'heard': m.heard,
          'hinted': m.hinted,
          'confidence': m.confidence,
          'tashkeelOnly': m.tashkeelOnly,
          'at': m.at.toUtc().toIso8601String(),
        },
    ],
  };

  /// The statistics block.
  static Map<String, Object?> statistics(TasmeeStats stats, {bool includeHeard = true}) => {
    'sessions': stats.sessions,
    'ayatRecited': stats.ayatRecited,
    'distinctAyat': stats.distinctAyat,
    'seconds': stats.seconds,
    'streakDays': stats.streakDays,
    'firstAt': stats.firstAt?.toUtc().toIso8601String(),
    'lastAt': stats.lastAt?.toUtc().toIso8601String(),
    'counts': stats.counts.toJson(),
    'days': [
      for (final d in stats.days)
        {
          'day': day(d.day),
          'sessions': d.sessions,
          'ayat': d.ayat,
          'words': d.words,
          'right': d.right,
          'mistakes': d.mistakes,
          'hints': d.hints,
          'seconds': d.seconds,
        },
    ],
    'weakWords': [
      for (final w in stats.weakWords)
        {
          ...ref(w.ref),
          'word': w.wordIndex,
          'expected': w.expected,
          'times': w.times,
          'hinted': w.hinted,
          'kinds': [for (final k in MistakeKind.values) if (w.kinds.contains(k)) k.name],
          if (includeHeard) 'lastHeard': w.lastHeard,
          'lastAt': w.lastAt.toUtc().toIso8601String(),
        },
    ],
    'weakAyat': [
      for (final a in stats.weakAyat)
        {
          ...ref(a.ref),
          'attempts': a.attempts,
          'cleanAttempts': a.cleanAttempts,
          'words': a.words,
          'right': a.right,
          'mistakes': a.mistakes,
          'hints': a.hints,
          'lastAt': day(a.lastAt),
        },
    ],
  };

  /// `{"ref": "2:255", "surah": 2, "ayah": 255}` – the string for a human,
  /// the two numbers for a program.
  static Map<String, Object?> ref(AyahRef r) => {'ref': r.toString(), 'surah': r.surah, 'ayah': r.ayah};

  /// A zone-free calendar day, `YYYY-MM-DD`.
  static String day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// The counts of a [RecitationCheck], for a caller that wants the nine
  /// keys without going through the log.
  static Map<String, Object?> counts(RecitationCounts c) => c.toJson();
}
