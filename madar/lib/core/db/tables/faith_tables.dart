import 'package:drift/drift.dart';

import '../../domain/enums.dart';
import 'converters.dart';

// Quran, daily wird and Hifz (schema v2). Ayat are addressed by
// surah (1–114) and ayah number within the surah.

/// Bookmarks and highlights in the Quran reader.
@DataClassName('QuranBookmarkRow')
class QuranBookmarks extends Table with Entity, Ordered {
  IntColumn get surah => integer()();
  IntColumn get ayah => integer()();
  TextColumn get label => text().nullable()();
  TextColumn get note => text().nullable()();
  IntColumn get color => integer().nullable()();
}

/// One reading / listening / review session over a range of ayat.
@DataClassName('QuranSessionRow')
class QuranSessions extends Table with Entity {
  DateTimeColumn get day => dateTime().map(const CalendarDayConverter())();
  TextColumn get mode => textEnum<QuranSessionMode>().withDefault(Constant(QuranSessionMode.read.name))();
  IntColumn get fromSurah => integer()();
  IntColumn get fromAyah => integer()();
  IntColumn get toSurah => integer()();
  IntColumn get toAyah => integer()();
  IntColumn get ayahCount => integer().withDefault(const Constant(0))();

  /// Mushaf pages covered (Madani 604-page layout), fractional.
  RealColumn get pages => real().withDefault(const Constant(0.0))();
  IntColumn get seconds => integer().withDefault(const Constant(0))();
  TextColumn get planId => text().nullable()();
}

/// Daily wird plans, e.g. a khatma in 30 days or two pages a day.
@DataClassName('WirdPlanRow')
class WirdPlans extends Table with Entity, Ordered {
  TextColumn get name => text()();
  TextColumn get unit => textEnum<WirdUnit>().withDefault(Constant(WirdUnit.pages.name))();
  RealColumn get amountPerDay => real()();
  IntColumn get startSurah => integer().withDefault(const Constant(1))();
  IntColumn get startAyah => integer().withDefault(const Constant(1))();
  DateTimeColumn get startDate => dateTime().map(const CalendarDayConverter())();

  /// Optional finish date (a khatma plan); null = open-ended daily amount.
  DateTimeColumn get targetDate => dateTime().map(const CalendarDayConverter()).nullable()();

  /// Prayer window the wird belongs to (reminders, home panel).
  TextColumn get window => textEnum<PrayerWindow>().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
}

/// Items memorised with SM-2 spaced repetition.
@DataClassName('HifzItemRow')
class HifzItems extends Table with Entity, Ordered {
  TextColumn get kind => textEnum<HifzKind>().withDefault(Constant(HifzKind.ayat.name))();
  TextColumn get title => text().nullable()();

  /// Ayah range for [HifzKind.ayat].
  IntColumn get surah => integer().nullable()();
  IntColumn get ayahFrom => integer().nullable()();
  IntColumn get ayahTo => integer().nullable()();

  /// Text of a hadith / custom item, and where it comes from.
  TextColumn get body => text().nullable()();
  TextColumn get source => text().nullable()();

  // SM-2 state.
  RealColumn get easeFactor => real().withDefault(const Constant(2.5))();
  IntColumn get intervalDays => integer().withDefault(const Constant(0))();
  IntColumn get repetitions => integer().withDefault(const Constant(0))();
  IntColumn get lapses => integer().withDefault(const Constant(0))();

  /// Next review day; null = new, not yet studied.
  DateTimeColumn get due => dateTime().map(const CalendarDayConverter()).nullable()();
  DateTimeColumn get lastReviewedAt => dateTime().nullable()();
  BoolColumn get suspended => boolean().withDefault(const Constant(false))();
}

/// Review log of a Hifz item (SM-2 quality 0–5).
@DataClassName('HifzReviewRow')
class HifzReviews extends Table with Entity {
  TextColumn get itemId => text()();
  DateTimeColumn get at => dateTime()();
  IntColumn get grade => integer()();
  IntColumn get intervalBefore => integer()();
  IntColumn get intervalAfter => integer()();
  RealColumn get easeAfter => real()();
}
