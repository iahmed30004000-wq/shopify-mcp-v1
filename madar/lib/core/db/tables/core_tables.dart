import 'package:drift/drift.dart';

import '../../domain/enums.dart';
import 'converters.dart';

/// Areas of life rendered as planets on the Astrolabe Orbit.
@DataClassName('PlanetRow')
class Planets extends Table with Entity, Ordered {
  /// Stable key: faith, health, family, work, money, growth, body, travel or
  /// `custom_<id>` for user-added planets.
  TextColumn get key => text().unique()();
  TextColumn get nameAr => text()();
  TextColumn get nameEn => text()();
  IntColumn get color => integer()();
  TextColumn get archetype => textEnum<PlanetArchetype>()();
  TextColumn get icon => text().withDefault(const Constant('star'))();
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();

  /// Importance of this planet in the overall balance.
  RealColumn get weight => real().withDefault(const Constant(1.0))();

  /// Data sources feeding the planet score and their weights,
  /// e.g. `{"prayers": 0.6, "adhkar": 0.2, "quran": 0.2}`.
  TextColumn get sources => text().map(const JsonMapConverter()).withDefault(const Constant('{}'))();
}

/// Encrypted key/value settings (location, prayer config, fasting config …).
/// UI-only preferences (theme, language) live in SharedPreferences so the lock
/// screen can render before the database is opened.
@DataClassName('KeyValueRow')
class KeyValues extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// A reminder attached to any record (`ownerTable` + `ownerId`).
///
/// `rule` examples:
/// `{"kind":"once","at":"2026-10-01T09:00:00"}`
/// `{"kind":"daily","time":"08:30"}`
/// `{"kind":"weekly","time":"08:30","weekdays":[1,3,5]}`
/// `{"kind":"prayer","window":"asr","offsetMin":10}`
/// `{"kind":"beforeDue","minutes":1440}`
@DataClassName('ReminderRow')
class Reminders extends Table with Entity {
  TextColumn get ownerTable => text()();
  TextColumn get ownerId => text()();
  TextColumn get title => text().nullable()();
  TextColumn get rule => text().map(const JsonMapConverter())();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
}

/// Append-only activity stream that feeds planet balance scores and the
/// Neglect Radar (e.g. "task completed", "dose taken", "contacted person").
@DataClassName('ActivityRow')
class ActivityLog extends Table with Entity {
  TextColumn get planetKey => text()();
  TextColumn get kind => text()();
  TextColumn get refTable => text().nullable()();
  TextColumn get refId => text().nullable()();
  DateTimeColumn get at => dateTime().clientDefault(DateTime.now)();
  RealColumn get value => real().nullable()();
  TextColumn get payload => text().map(const JsonMapConverter()).withDefault(const Constant('{}'))();
}

/// Tasks placed into prayer windows.
@DataClassName('TaskRow')
class Tasks extends Table with Entity, Ordered {
  TextColumn get title => text()();
  TextColumn get notes => text().nullable()();
  TextColumn get window => textEnum<PrayerWindow>().withDefault(Constant(PrayerWindow.anytime.name))();

  /// Day the task belongs to; null = inbox / someday.
  DateTimeColumn get date => dateTime().nullable()();

  /// Optional repeat rule, e.g. `{"every":"day"}` / `{"every":"week","weekdays":[5]}`.
  TextColumn get recurrence => text().map(const JsonMapConverter()).nullable()();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  DateTimeColumn get doneAt => dateTime().nullable()();
  TextColumn get planetKey => text().nullable()();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  BoolColumn get isTop3 => boolean().withDefault(const Constant(false))();
  TextColumn get projectId => text().nullable()();
  TextColumn get cardId => text().nullable()();
}

/// Prayer tracker – one row per (date, prayer).
@DataClassName('PrayerLogRow')
class PrayerLogs extends Table with Entity {
  /// Local calendar day, `yyyy-MM-dd`.
  TextColumn get day => text()();
  TextColumn get prayer => textEnum<Prayer>()();
  TextColumn get status => textEnum<PrayerStatus>().withDefault(Constant(PrayerStatus.prayed.name))();
  BoolColumn get inJamaah => boolean().withDefault(const Constant(false))();
  BoolColumn get atMosque => boolean().withDefault(const Constant(false))();
  DateTimeColumn get loggedAt => dateTime().clientDefault(DateTime.now)();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {day, prayer},
      ];
}

/// Raw copies of imported files so nothing is ever lost, including sections the
/// importer could not map yet.
@DataClassName('ImportArchiveRow')
class ImportArchive extends Table with Entity {
  TextColumn get source => text()();
  TextColumn get raw => text()();
  TextColumn get summary => text().map(const JsonMapConverter()).withDefault(const Constant('{}'))();
}
