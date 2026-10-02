import 'package:drift/drift.dart';

import '../../domain/enums.dart';
import 'converters.dart';

/// Standing alerts pinned at the top of Health (e.g. "No cortisone — AVN").
@DataClassName('HealthAlertRow')
class HealthAlerts extends Table with Entity, Ordered {
  TextColumn get body => text()();
  TextColumn get severity => textEnum<Severity>().withDefault(Constant(Severity.critical.name))();
  BoolColumn get pinned => boolean().withDefault(const Constant(true))();
}

@DataClassName('ConditionRow')
class Conditions extends Table with Entity, Ordered {
  TextColumn get name => text()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get since => dateTime().map(const CalendarDayConverter()).nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
}

/// Medications and supplements.
@DataClassName('MedicationRow')
class Medications extends Table with Entity, Ordered {
  TextColumn get name => text()();
  TextColumn get kind => textEnum<MedKind>().withDefault(Constant(MedKind.medication.name))();

  /// Human dose text as the user writes it ("10 mg", "2 caps").
  TextColumn get dose => text().nullable()();
  RealColumn get doseAmount => real().nullable()();
  TextColumn get doseUnit => text().nullable()();

  /// Any number of daily times, `HH:mm`.
  TextColumn get times => text().map(const StringListConverter()).withDefault(const Constant('[]'))();
  TextColumn get takenWith => textEnum<TakenWith>().withDefault(Constant(TakenWith.anytime.name))();
  TextColumn get takenWithNote => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();

  /// Units left (refill count) and the threshold that triggers a refill alert.
  IntColumn get stock => integer().nullable()();
  IntColumn get refillAt => integer().nullable()();
  TextColumn get courseId => text().nullable()();

  /// Titration schedule: `[{"from":"2026-10-01","dose":"5 mg","doseAmount":5}, …]`.
  TextColumn get titration => text().map(const JsonListConverter()).withDefault(const Constant('[]'))();
  IntColumn get color => integer().nullable()();
}

/// Injection / treatment courses with phases, e.g. daily ×10 → weekly ×4 →
/// monthly. `phases`: `[{"label":"Loading","frequency":"daily","interval":1,
/// "count":10,"dose":"1 amp"}, …]`.
@DataClassName('MedCourseRow')
class MedCourses extends Table with Entity, Ordered {
  TextColumn get name => text()();
  TextColumn get medicationId => text().nullable()();
  DateTimeColumn get startDate => dateTime().map(const CalendarDayConverter())();
  TextColumn get phases => text().map(const JsonListConverter()).withDefault(const Constant('[]'))();
  TextColumn get notes => text().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
}

/// Timing rules the scheduler enforces ("separate A and B by 2 hours").
@DataClassName('MedRuleRow')
class MedRules extends Table with Entity, Ordered {
  TextColumn get kind => textEnum<MedRuleKind>()();
  TextColumn get medAId => text()();
  TextColumn get medBId => text().nullable()();
  IntColumn get minutes => integer().withDefault(const Constant(0))();
  TextColumn get note => text().nullable()();
}

/// Dose log (Taken / Snooze / Skip).
@DataClassName('MedDoseRow')
class MedDoses extends Table with Entity {
  TextColumn get medicationId => text()();
  DateTimeColumn get scheduledAt => dateTime().nullable()();
  DateTimeColumn get takenAt => dateTime().nullable()();
  TextColumn get status => textEnum<DoseStatus>()();
  TextColumn get dose => text().nullable()();
  TextColumn get note => text().nullable()();
}

/// User-defined lab tests with reference range.
@DataClassName('LabTestRow')
class LabTests extends Table with Entity, Ordered {
  TextColumn get name => text()();
  TextColumn get unit => text().nullable()();
  RealColumn get low => real().nullable()();
  RealColumn get high => real().nullable()();
  TextColumn get category => text().nullable()();
  TextColumn get notes => text().nullable()();
}

@DataClassName('LabReadingRow')
class LabReadings extends Table with Entity {
  TextColumn get testId => text()();
  DateTimeColumn get date => dateTime().map(const CalendarDayConverter())();
  RealColumn get value => real().nullable()();

  /// Qualitative results ("negative", "trace").
  TextColumn get valueText => text().nullable()();
  TextColumn get note => text().nullable()();
}

@DataClassName('AppointmentRow')
class Appointments extends Table with Entity {
  TextColumn get title => text()();
  TextColumn get doctor => text().nullable()();
  TextColumn get place => text().nullable()();
  DateTimeColumn get at => dateTime()();
  TextColumn get notes => text().nullable()();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
}

/// "Questions for my doctor" (optionally tied to an appointment).
@DataClassName('DoctorQuestionRow')
class DoctorQuestions extends Table with Entity, Ordered {
  TextColumn get appointmentId => text().nullable()();
  TextColumn get question => text()();
  BoolColumn get answered => boolean().withDefault(const Constant(false))();
  TextColumn get answer => text().nullable()();
}

@DataClassName('PainEntryRow')
class PainEntries extends Table with Entity {
  DateTimeColumn get at => dateTime()();
  IntColumn get score => integer()(); // 0..10
  TextColumn get locations => text().map(const StringListConverter()).withDefault(const Constant('[]'))();
  TextColumn get triggers => text().map(const StringListConverter()).withDefault(const Constant('[]'))();

  /// Body-map points `[{"x":0.42,"y":0.31,"side":"front"}]` (normalised).
  TextColumn get bodyPoints => text().map(const JsonListConverter()).withDefault(const Constant('[]'))();
  TextColumn get notes => text().nullable()();
}

@DataClassName('MoodEntryRow')
class MoodEntries extends Table with Entity {
  DateTimeColumn get at => dateTime()();
  IntColumn get mood => integer().nullable()(); // 1..5
  IntColumn get stress => integer().nullable()(); // 0..10
  IntColumn get anxiety => integer().nullable()(); // 0..10
  IntColumn get energy => integer().nullable()(); // 0..10
  RealColumn get sleepHours => real().nullable()();
  IntColumn get caffeineCups => integer().nullable()();
  TextColumn get factors => text().map(const StringListConverter()).withDefault(const Constant('[]'))();
  TextColumn get notes => text().nullable()();
}

/// User-editable option lists (pain locations/triggers, mood factor tags …).
@DataClassName('TagOptionRow')
class TagOptions extends Table with Entity, Ordered {
  TextColumn get kind => textEnum<TagKind>()();
  TextColumn get label => text()();
  IntColumn get color => integer().nullable()();
}

/// Habit checklists (e.g. stress-reduction habits).
@DataClassName('HabitRow')
class Habits extends Table with Entity, Ordered {
  TextColumn get name => text()();
  TextColumn get category => text().withDefault(const Constant('stress'))();
  TextColumn get planetKey => text().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
}

@DataClassName('HabitLogRow')
class HabitLogs extends Table with Entity {
  TextColumn get habitId => text()();
  TextColumn get day => text()(); // yyyy-MM-dd
  BoolColumn get done => boolean().withDefault(const Constant(true))();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {habitId, day},
      ];
}

/// Worry window: parked worries reviewed at a user-set time.
@DataClassName('WorryRow')
class Worries extends Table with Entity, Ordered {
  TextColumn get body => text()();
  BoolColumn get resolved => boolean().withDefault(const Constant(false))();
  TextColumn get reflection => text().nullable()();
}
