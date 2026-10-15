/// «التسميع» – recitation checked on the phone (PLAN.md Part 13), **step 1:
/// the engine**.
///
/// Import `package:madar/features/tasmee/tasmee.dart`.
///
/// The owner, 2026-10-15: he recites, Madar follows him verse by verse and
/// flags wrong, missed and extra words against the exact text; a mode that
/// hides the verses and reveals each word as he recites it; fill in the
/// blank; «شازام القرآن» – recite a phrase and be told where it is; a log
/// of his mistakes and statistics over time. All of it **offline**, and
/// **no audio and no transcript ever leave the phone**.
///
/// ## What is in this package, and what is not
///
/// * **There is no speech model in this build.** Step 1 is the engine and
///   its data, developed and tested against [FakeQuranRecogniser], a stub
///   that replays a script. Nothing was downloaded, no dependency was
///   added, no plugin exists. Step 2 brings the real on-device model and
///   the screens, and swaps one implementation behind [QuranRecogniser].
/// * **The verified text is never touched.** Every word, every position and
///   every ayah number comes from `assets/quran/quran-uthmani.txt` through
///   `lib/features/quran/`. Nothing religious is generated anywhere, and
///   the text is never reflowed, normalised in place or regenerated.
/// * **Audio has no shape in this API.** No type here holds bytes, a
///   buffer, a file path or a waveform – not in the recogniser interface,
///   not in the engine, not in the three database tables. There is nothing
///   to delete after scoring because nothing was ever kept.
/// * **Pronunciation (makharij) is not here** – Part 13 leaves it to a
///   later part on purpose.
/// * **Tashkeel checking is experimental, labelled and off by default**
///   ([TasmeeSettings.checkTashkeel]). Word level first, and a tashkeel
///   difference never changes a verdict or counts as a mistake.
/// * **The result is a hint for him, never a ruling.** Every screen must
///   say so, and the engine helps: a word the recogniser was unsure about
///   is [WordVerdict.unsure] and not a mistake.
///
/// ## The recogniser the real model must satisfy (step 2's shopping list)
///
/// `domain/recogniser.dart` carries the whole contract in its own doc
/// comment. In short: it owns the microphone, it is asked
/// [QuranRecogniser.availability] **before** anything is recorded, and
/// [QuranRecogniser.start] streams [HeardWord]s – a word, its start and end
/// from the start of listening, a confidence in `0.0 … 1.0`, and `isFinal`.
/// It closes the microphone and destroys every buffer on
/// [RecognitionRun.stop] or [RecognitionRun.cancel]. It runs with no
/// network. It names itself, its version and its **licence** in
/// [RecogniserInfo], because the About screen credits it and the log
/// records which model judged which session.
///
/// ## The engine
///
/// | file | what it does |
/// |---|---|
/// | `domain/recogniser.dart` | the boundary: audio in, words out, nothing else |
/// | `domain/fake_recogniser.dart` | the scripted stub the tests drive |
/// | `domain/ayah_words.dart` | the verified text cut into words, with their ranges in the original |
/// | `domain/alignment.dart` | right · wrong · skipped · extra, per word, positioned in the original |
/// | `domain/recite_to_find.dart` | «شازام القرآن»: an n-gram index, ranked, honest when unsure |
/// | `domain/hidden_verse.dart` | the hidden page; a peek is recorded as a hint |
/// | `domain/blanks.dart` | fill in the blank, deterministic from a seed |
/// | `domain/mistake_log.dart` | the log and the statistics read off it |
/// | `domain/mistake_export.dart` | the documented JSON «فلك» will read |
/// | `domain/tasmee_settings.dart` | his own choices |
/// | `data/tasmee_service.dart` | the three tables of schema v7, every write with an undo |
/// | `data/tasmee_providers.dart` | what the screens of step 2 read |
///
/// ## Where a screen starts
///
/// 1. `ref.watch(tasmeeAvailabilityProvider)` – **before** anything else.
///    Not ready ⇒ say so plainly and keep reading and listening working.
/// 2. `ref.watch(tasmeeTargetProvider(range))` – the words of the verified
///    text, with their positions in it.
/// 3. For live checking: feed every [HeardWord] into
///    [TasmeeAligner.align] (or into a [HiddenVerseMachine] / [BlankDrill],
///    which do it for you) and draw [RecitationCheck.words]: a
///    [WordCheck] carries the verified word, its range in the original
///    ayah text, the verdict, and – labelled «اللي سمعه التطبيق» and in a
///    different type – [WordCheck.heard].
/// 4. For «شازام القرآن»: `ref.watch(reciteIndexProvider)` and
///    [ReciteIndex.findHeard]. Respect [ReciteFindResult.confidence]:
///    [ReciteConfidence.several] means *offer them all*, and
///    [ReciteFindResult.only] is null unless the engine is sure.
/// 5. When he stops: `tasmeeServiceProvider.recordCheck(...)`, which writes
///    the session, its ayat and the words that went wrong, and returns the
///    undo.
///
/// ## The data (schema v7)
///
/// | table | what it is |
/// |---|---|
/// | `tasmee_sessions` | one recitation: the range, the counts, how long, which recogniser |
/// | `tasmee_ayat` | one ayah of that session – the attempt itself, so a clean recitation leaves a trace |
/// | `tasmee_mistakes` | one word that went wrong: expected, where, what was heard, whether a hint was used |
library;

export 'data/tasmee_providers.dart';
export 'data/tasmee_service.dart';
export 'domain/alignment.dart';
export 'domain/ayah_words.dart';
export 'domain/blanks.dart';
export 'domain/fake_recogniser.dart';
export 'domain/hidden_verse.dart';
export 'domain/mistake_export.dart';
export 'domain/mistake_log.dart';
export 'domain/recite_to_find.dart';
export 'domain/recogniser.dart';
export 'domain/tasmee_settings.dart';
