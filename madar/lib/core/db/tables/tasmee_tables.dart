import 'package:drift/drift.dart';

import '../../domain/enums.dart';
import 'converters.dart';

// ------------------------------ «التسميع» · recitation checked (v7) ----
//
// Part 13. The owner, 2026-10-15: «سجل لأخطائه السابقة، وإحصائيات تقدّم».
// Three tables, and they are the whole log: one row per **session** (he
// pressed record and recited a range), one row per **ayah** of that
// session, and one row per **word** that went wrong.
//
// **Why the per-ayah row exists.** Everything in `tasmee_ayat` could be
// recomputed from `tasmee_mistakes`, except the thing Part 14 needs most:
// how many words he actually went through and how many were right. A
// mistake row only exists where something went wrong, so a clean
// recitation of al-Kahf would leave no trace at all and his strength would
// read as "never recited". The ayah row is the attempt itself.
//
// **What is NOT in here.**
// * **No audio, no recording, no file path, no waveform** – not a column,
//   not a note, nowhere. The microphone is open only while he recites and
//   what is left after scoring is words. There is nothing to delete after
//   a session because there was never anything kept.
// * **No verse text of ours.** `expected` is one word copied verbatim out
//   of the app's own verified Uthmani text, with its own code-unit range in
//   that ayah (`start`, `end`); `text_source` says which edition, so a row
//   is never read against a different one. Nothing religious is generated.
// * **No judgement.** `heard` is what the on-device recogniser thought it
//   heard. It is deliberately not called `text`: it is **not Quran**, and a
//   screen must label it «اللي سمعه التطبيق» and style it differently. The
//   result is a hint for him, never a ruling.
// * **No model.** Which recogniser judged a session is recorded as
//   `recogniser_id` + `recogniser_version`, so a result is never read as
//   the verdict of a different model.
//
// **Tashkeel is experimental.** `tashkeel_only` marks a row where the
// letters were right and only the harakat differed, and
// `tashkeel_checked` says the check was even on. It is off by default, it
// is never counted with the real mistakes, and it is labelled wherever it
// is shown.

/// One time he pressed record and recited.
@DataClassName('TasmeeSessionRow')
class TasmeeSessions extends Table with Entity {
  /// When he started.
  DateTimeColumn get startedAt => dateTime()();

  /// The calendar day, stored zone-free like every day in Madar – what the
  /// statistics and the streak group by.
  DateTimeColumn get day => dateTime().map(const CalendarDayConverter())();

  TextColumn get mode => textEnum<TasmeeMode>().withDefault(Constant(TasmeeMode.recite.name))();

  /// The range he recited (inclusive, may cross a surah).
  IntColumn get fromSurah => integer()();
  IntColumn get fromAyah => integer()();
  IntColumn get toSurah => integer()();
  IntColumn get toAyah => integer()();

  // The counts of the whole session. `words` is the verified words of the
  // range; `pending` is what he never reached, which is not a mistake.
  IntColumn get wordCount => integer().withDefault(const Constant(0))();
  IntColumn get rightCount => integer().withDefault(const Constant(0))();
  IntColumn get wrongCount => integer().withDefault(const Constant(0))();
  IntColumn get skippedCount => integer().withDefault(const Constant(0))();

  /// Heard, but the recogniser was not sure enough to judge. Never a
  /// mistake.
  IntColumn get unsureCount => integer().withDefault(const Constant(0))();
  IntColumn get pendingCount => integer().withDefault(const Constant(0))();

  /// Words that are not in the text here. The basmala before a surah and
  /// words of the text said again are **not** counted in.
  IntColumn get extraCount => integer().withDefault(const Constant(0))();

  /// Peeks: words he was shown instead of remembering, so Part 14's
  /// strength stays honest.
  IntColumn get hintCount => integer().withDefault(const Constant(0))();

  /// Words whose letters matched and whose harakat did not (experimental).
  IntColumn get tashkeelDiffCount => integer().withDefault(const Constant(0))();

  /// How long the recitation ran.
  IntColumn get seconds => integer().withDefault(const Constant(0))();

  /// Which recogniser judged it, and which version of it.
  TextColumn get recogniserId => text().withDefault(const Constant(''))();
  TextColumn get recogniserVersion => text().withDefault(const Constant(''))();

  /// Which edition of the text it was checked against.
  TextColumn get textSource => text().withDefault(const Constant('tanzil-uthmani'))();

  /// Whether the **experimental** tashkeel check was on.
  BoolColumn get tashkeelChecked => boolean().withDefault(const Constant(false))();

  /// The fill-in-the-blank seed, when the mode used one – so the same drill
  /// can be rebuilt exactly.
  IntColumn get seed => integer().nullable()();

  TextColumn get note => text().nullable()();
}

/// One ayah of one session: the attempt itself, right or wrong.
@DataClassName('TasmeeAyahRow')
class TasmeeAyat extends Table with Entity {
  /// The session it belongs to (`tasmee_sessions.id`). Deleted with it by
  /// the service, exactly as a recipe deletes its ingredient lines.
  TextColumn get sessionId => text()();

  DateTimeColumn get day => dateTime().map(const CalendarDayConverter())();
  IntColumn get surah => integer()();
  IntColumn get ayah => integer()();

  IntColumn get wordCount => integer().withDefault(const Constant(0))();
  IntColumn get rightCount => integer().withDefault(const Constant(0))();
  IntColumn get wrongCount => integer().withDefault(const Constant(0))();
  IntColumn get skippedCount => integer().withDefault(const Constant(0))();
  IntColumn get unsureCount => integer().withDefault(const Constant(0))();
  IntColumn get pendingCount => integer().withDefault(const Constant(0))();
  IntColumn get extraCount => integer().withDefault(const Constant(0))();
  IntColumn get hintCount => integer().withDefault(const Constant(0))();
  IntColumn get tashkeelDiffCount => integer().withDefault(const Constant(0))();
}

/// One word that went wrong, on the day it went wrong.
@DataClassName('TasmeeMistakeRow')
class TasmeeMistakes extends Table with Entity {
  /// The session it belongs to (`tasmee_sessions.id`).
  TextColumn get sessionId => text()();

  /// The moment it happened.
  DateTimeColumn get at => dateTime()();

  /// Its calendar day, zone-free.
  DateTimeColumn get day => dateTime().map(const CalendarDayConverter())();

  IntColumn get surah => integer()();
  IntColumn get ayah => integer()();

  /// Which word of the ayah, 0-based, counting real words only (the Uthmani
  /// pause and hizb signs are not words). For [MistakeKind.extra] it is the
  /// word the extra came **before**.
  IntColumn get wordIndex => integer()();

  TextColumn get kind => textEnum<MistakeKind>()();

  /// The verified word, verbatim. Empty for an extra word, where the text
  /// expected nothing.
  TextColumn get expected => text()();

  /// Code-unit range of [expected] in the **original** ayah text. For an
  /// extra word `span_start == span_end`, at the point it was heard.
  IntColumn get spanStart => integer()();
  IntColumn get spanEnd => integer()();

  /// What the recogniser thought it heard. **Not Quran text**; null when
  /// nothing was heard (a skipped word).
  TextColumn get heard => text().nullable()();

  /// A peek had already revealed this word.
  BoolColumn get hinted => boolean().withDefault(const Constant(false))();

  /// The recogniser's own confidence, `0.0 … 1.0`.
  RealColumn get confidence => real().nullable()();

  /// The letters were right and only the harakat differed – the
  /// experimental check. Kept out of every count.
  BoolColumn get tashkeelOnly => boolean().withDefault(const Constant(false))();
}
