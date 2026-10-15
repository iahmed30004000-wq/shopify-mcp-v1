import 'package:drift/drift.dart';

import '../../domain/enums.dart';
import 'converters.dart';

// ---------------------------------------------------------------- People ----

@DataClassName('PersonRow')
class People extends Table with Entity, Ordered {
  TextColumn get name => text()();
  TextColumn get relation => text().nullable()();

  /// Contact rhythm: reach out every N days (null = no rhythm).
  IntColumn get rhythmDays => integer().nullable()();
  DateTimeColumn get lastContact => dateTime().nullable()();
  TextColumn get phone => text().nullable()();
  DateTimeColumn get birthday => dateTime().map(const CalendarDayConverter()).nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get color => integer().nullable()();

  /// Orbit the Family planet as a moon.
  BoolColumn get showAsMoon => boolean().withDefault(const Constant(true))();
}

@DataClassName('ContactLogRow')
class ContactLogs extends Table with Entity {
  TextColumn get personId => text()();
  DateTimeColumn get at => dateTime()();
  TextColumn get channel => textEnum<ContactChannel>().withDefault(Constant(ContactChannel.other.name))();
  TextColumn get note => text().nullable()();
}

// -------------------------------------------------------------- Projects ----

@DataClassName('ProjectRow')
class Projects extends Table with Entity, Ordered {
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get deadline => dateTime().map(const CalendarDayConverter()).nullable()();
  TextColumn get status => textEnum<ProjectStatus>().withDefault(Constant(ProjectStatus.active.name))();
  TextColumn get planetKey => text().nullable()();
  IntColumn get color => integer().nullable()();
}

@DataClassName('ProjectItemRow')
class ProjectItems extends Table with Entity, Ordered {
  TextColumn get projectId => text()();
  TextColumn get body => text()();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  DateTimeColumn get dueDate => dateTime().map(const CalendarDayConverter()).nullable()();
}

// ------------------------------------------------------------------ Work ----

/// Kanban board per country / business. `columns`:
/// `[{"id":"todo","label":"To-do"},{"id":"doing","label":"Doing"},{"id":"done","label":"Done"}]`.
@DataClassName('BoardRow')
class Boards extends Table with Entity, Ordered {
  TextColumn get name => text()();
  TextColumn get country => text().nullable()();
  IntColumn get color => integer().nullable()();
  TextColumn get columns => text()
      .map(const JsonListConverter())
      .withDefault(const Constant('[{"id":"todo","label":"To-do"},{"id":"doing","label":"Doing"},{"id":"done","label":"Done"}]'))();
}

@DataClassName('BoardCardRow')
class BoardCards extends Table with Entity, Ordered {
  TextColumn get boardId => text()();
  TextColumn get columnId => text().withDefault(const Constant('todo'))();
  TextColumn get title => text()();
  TextColumn get notes => text().nullable()();
  TextColumn get assignee => text().nullable()();
  DateTimeColumn get dueDate => dateTime().map(const CalendarDayConverter()).nullable()();
  BoolColumn get isTop3 => boolean().withDefault(const Constant(false))();
  TextColumn get window => textEnum<PrayerWindow>().nullable()();

  /// A short label of his own on the card («مرتجعات», «عميل مهم») with its
  /// own colour, so one look at the board says what kind of work a card is.
  /// Null until he gives the card one; the colour is an ARGB value from the
  /// curated palette and means nothing without the label.
  TextColumn get tag => text().nullable()();
  IntColumn get tagColor => integer().nullable()();
}

// ---------------------------------------------------------------- Travel ----

@DataClassName('TripRow')
class Trips extends Table with Entity, Ordered {
  TextColumn get destination => text()();
  TextColumn get country => text().nullable()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  DateTimeColumn get startDate => dateTime().map(const CalendarDayConverter()).nullable()();
  DateTimeColumn get endDate => dateTime().map(const CalendarDayConverter()).nullable()();
  TextColumn get status => textEnum<TripStatus>().withDefault(Constant(TripStatus.planned.name))();
  TextColumn get notes => text().nullable()();
  IntColumn get color => integer().nullable()();
}

@DataClassName('TripItemRow')
class TripItems extends Table with Entity, Ordered {
  TextColumn get tripId => text()();
  TextColumn get body => text()();
  TextColumn get category => text().nullable()();
  BoolColumn get packed => boolean().withDefault(const Constant(false))();
}

@DataClassName('PackingTemplateRow')
class PackingTemplates extends Table with Entity, Ordered {
  TextColumn get name => text()();
  TextColumn get items => text().map(const StringListConverter()).withDefault(const Constant('[]'))();
}

/// Passports, visas, licences … with expiry reminders.
@DataClassName('TravelDocumentRow')
class TravelDocuments extends Table with Entity, Ordered {
  TextColumn get name => text()();
  TextColumn get holder => text().nullable()();
  TextColumn get number => text().nullable()();
  DateTimeColumn get expiry => dateTime().map(const CalendarDayConverter()).nullable()();
  IntColumn get remindDaysBefore => integer().withDefault(const Constant(30))();
  TextColumn get notes => text().nullable()();
}

// ---------------------------------------------------------------- Growth ----

@DataClassName('LearningGoalRow')
class LearningGoals extends Table with Entity, Ordered {
  TextColumn get name => text()();
  TextColumn get unit => text().withDefault(const Constant(''))();
  RealColumn get target => real()();
  RealColumn get initial => real().withDefault(const Constant(0.0))();
  DateTimeColumn get deadline => dateTime().map(const CalendarDayConverter()).nullable()();
  IntColumn get color => integer().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
}

@DataClassName('GoalLogRow')
class GoalLogs extends Table with Entity {
  TextColumn get goalId => text()();
  RealColumn get amount => real()();
  DateTimeColumn get at => dateTime()();
  TextColumn get note => text().nullable()();
}

// ------------------------------------------------------------------ Body ----

@DataClassName('ExerciseRow')
class Exercises extends Table with Entity, Ordered {
  TextColumn get name => text()();

  /// ISO weekdays 1 (Mon) … 7 (Sun).
  TextColumn get weekdays => text().map(const IntListConverter()).withDefault(const Constant('[]'))();
  IntColumn get sets => integer().nullable()();
  IntColumn get reps => integer().nullable()();
  IntColumn get durationMin => integer().nullable()();
  RealColumn get weight => real().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();

  /// The machine's picture: a **file name** in Madar's own folder
  /// (`gym_photos/a1b2c3.jpg`), never a path into the gallery – the picked
  /// image is copied in, so deleting the original changes nothing. See
  /// `features/body/data/gym_media.dart`.
  TextColumn get photo => text().nullable()();

  /// The movement's video: his own file path on the phone, or a link. It is
  /// **not** copied (a clip is tens or hundreds of megabytes); Madar only
  /// remembers where it is.
  TextColumn get video => text().nullable()();

  /// The muscles he says it works, in his own words (`["صدر","كتف"]`).
  /// Nothing of ours is written here: a fresh install has no library.
  TextColumn get muscles => text().map(const StringListConverter()).withDefault(const Constant('[]'))();

  /// Rest between sets, in seconds (null: no timer offered).
  IntColumn get restSec => integer().nullable()();

  /// How many of the sets are warm-ups (they are logged, and left out of
  /// the heaviest-set and volume arithmetic).
  IntColumn get warmupSets => integer().nullable()();
}

/// One set of a logged workout: the reps and the weight of that set alone.
/// A log with no set rows is the older one-line kind and still reads.
@DataClassName('WorkoutSetRow')
class WorkoutSets extends Table with Entity, Ordered {
  TextColumn get logId => text()();
  IntColumn get reps => integer().nullable()();
  RealColumn get weight => real().nullable()();

  /// A warm-up set: it counts as done, never as a personal best and never
  /// in the volume.
  BoolColumn get warmup => boolean().withDefault(const Constant(false))();
}

/// A named training day of his own («يوم صدر»), on the weekdays he gives
/// it. Nothing of ours is written: a fresh install has no template.
@DataClassName('WorkoutTemplateRow')
class WorkoutTemplates extends Table with Entity, Ordered {
  TextColumn get name => text()();

  /// ISO weekdays 1 (Mon) … 7 (Sun).
  TextColumn get weekdays => text().map(const IntListConverter()).withDefault(const Constant('[]'))();
  TextColumn get notes => text().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
}

/// One exercise inside a template, in the order he wants to do it. The
/// numbers here override the exercise's own for that day only; null means
/// "whatever the exercise says".
@DataClassName('WorkoutTemplateItemRow')
class WorkoutTemplateItems extends Table with Entity, Ordered {
  TextColumn get templateId => text()();
  TextColumn get exerciseId => text()();
  IntColumn get sets => integer().nullable()();
  IntColumn get reps => integer().nullable()();
  RealColumn get weight => real().nullable()();
  IntColumn get restSec => integer().nullable()();
  IntColumn get warmupSets => integer().nullable()();
}

@DataClassName('WorkoutLogRow')
class WorkoutLogs extends Table with Entity {
  TextColumn get exerciseId => text().nullable()();
  TextColumn get name => text()();
  DateTimeColumn get at => dateTime()();
  IntColumn get sets => integer().nullable()();
  IntColumn get reps => integer().nullable()();
  RealColumn get weight => real().nullable()();
  IntColumn get durationMin => integer().nullable()();
  TextColumn get notes => text().nullable()();
}

/// User-editable "avoid" list (movements, foods …).
@DataClassName('AvoidItemRow')
class AvoidItems extends Table with Entity, Ordered {
  TextColumn get body => text()();
  TextColumn get reason => text().nullable()();
}

@DataClassName('FastingSessionRow')
class FastingSessions extends Table with Entity {
  DateTimeColumn get start => dateTime()();
  DateTimeColumn get end => dateTime().nullable()();
  RealColumn get targetHours => real()();
  TextColumn get note => text().nullable()();
}

@DataClassName('WaterLogRow')
class WaterLogs extends Table with Entity {
  DateTimeColumn get at => dateTime()();
  IntColumn get ml => integer()();
}

// -------------------------------------------------------- Custom modules ----

/// A user-built tracker or list. `fields`:
/// `[{"id":"f1","label":"Pages","type":"number","unit":"p","required":true,
///   "options":[]}]` – see [FieldType].
@DataClassName('CustomModuleRow')
class CustomModules extends Table with Entity, Ordered {
  TextColumn get name => text()();
  TextColumn get kind => textEnum<CustomModuleKind>().withDefault(Constant(CustomModuleKind.tracker.name))();
  TextColumn get icon => text().withDefault(const Constant('star'))();
  IntColumn get color => integer()();
  TextColumn get planetKey => text().nullable()();
  TextColumn get window => textEnum<PrayerWindow>().nullable()();
  TextColumn get fields => text().map(const JsonListConverter()).withDefault(const Constant('[]'))();

  /// `{"type":"line","fieldId":"f1","range":30}`.
  TextColumn get chart => text().map(const JsonMapConverter()).nullable()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

@DataClassName('CustomEntryRow')
class CustomEntries extends Table with Entity, Ordered {
  TextColumn get moduleId => text()();
  DateTimeColumn get at => dateTime().clientDefault(DateTime.now)();

  /// Field id → value.
  TextColumn get entryValues => text().map(const JsonMapConverter()).withDefault(const Constant('{}'))();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
}
