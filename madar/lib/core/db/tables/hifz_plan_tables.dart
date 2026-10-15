import 'package:drift/drift.dart';

import '../../domain/enums.dart';
import 'converters.dart';

// ------------------------------------------- «الحفظ» · memorisation (v8) ----
//
// Part 14, on top of the Hifz tracking of v2 (`hifz_items`, `hifz_reviews`)
// and the recitation log of v7 (`tasmee_sessions`, `tasmee_ayat`,
// `tasmee_mistakes`).
//
// **What is NOT in here: the strength.** The strength of an ayah is never
// stored. It is computed, every time, from the results that actually
// happened – the attempts and the hints in `tasmee_ayat` and
// `tasmee_mistakes` – so it can never drift away from them, and opening a
// screen can never raise it. The only thing kept here is what the owner
// himself decided: his goals, and the stretches he marked.
//
// **No verse text.** A goal names a range by its numbers (`from_surah` …
// `to_ayah`) and carries the owner's **own** title («الكهف كل جمعة»).
// Nothing religious is generated or stored: every letter of a verse comes
// from the verified text at run time.

/// One of the owner's memorisation goals, in his own words.
@DataClassName('HifzGoalRow')
class HifzGoals extends Table with Entity, Ordered {
  /// His own words for it («الكهف كل جمعة»). Never generated.
  TextColumn get title => text()();

  TextColumn get kind => textEnum<HifzGoalKind>()();

  /// The stretch the goal is about (inclusive, may cross a surah). Null for
  /// [HifzGoalKind.amountPerDay], which is about an amount, not a place.
  IntColumn get fromSurah => integer().nullable()();
  IntColumn get fromAyah => integer().nullable()();
  IntColumn get toSurah => integer().nullable()();
  IntColumn get toAyah => integer().nullable()();

  /// For [HifzGoalKind.rangeOnWeekday]: `DateTime.monday … DateTime.sunday`
  /// (1 … 7). Friday is 5.
  IntColumn get weekday => integer().nullable()();

  /// For [HifzGoalKind.amountPerDay]: how much a day, in [unit].
  RealColumn get amount => real().nullable()();
  TextColumn get unit => textEnum<WirdUnit>().withDefault(Constant(WirdUnit.pages.name))();

  /// The prayer the reminder hangs off – never a bare clock. Null means no
  /// reminder is wanted even when [remind] is on.
  TextColumn get window => textEnum<PrayerWindow>().nullable()();

  /// Minutes after that prayer.
  IntColumn get offsetMinutes => integer().withDefault(const Constant(15))();

  BoolColumn get remind => boolean().withDefault(const Constant(true))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
}

/// One stretch of the mushaf he marked: «مش عليّ» or «صفّر القوة».
@DataClassName('HifzMarkRow')
class HifzMarks extends Table with Entity {
  TextColumn get kind => textEnum<HifzMarkKind>()();

  /// The stretch (inclusive, may cross a surah).
  IntColumn get fromSurah => integer()();
  IntColumn get fromAyah => integer()();
  IntColumn get toSurah => integer()();
  IntColumn get toAyah => integer()();

  /// For [HifzMarkKind.resetStrength]: the day the strength starts again
  /// from; results before it are ignored and nothing is deleted. Stored
  /// zone-free, like every day in Madar.
  DateTimeColumn get since => dateTime().map(const CalendarDayConverter()).nullable()();

  /// His own note, when he wrote one.
  TextColumn get note => text().nullable()();
}
