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

  /// Colour the user picked for the condition's chip (schema v3), so meals,
  /// rules and pain entries linked to it read as one thing. Null: the UI
  /// picks one.
  IntColumn get color => integer().nullable()();
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

// ----------------------------------------------- nutrition (schema v3) ----
//
// Food, the meal plan and the user's own food rules. Tracking and
// visualising only: nothing here carries nutrition facts or any judgement of
// ours. Every tag, rule and weight is the user's own writing, and a fresh
// install starts empty.

/// A food the user defines once and reuses: his own name for it, his own
/// tags («حلو»، «نشويات»، «مقلي») and the portion he usually eats.
@DataClassName('FoodRow')
class Foods extends Table with Entity, Ordered {
  TextColumn get name => text()();
  TextColumn get notes => text().nullable()();

  /// The user's own vocabulary. Food rules match on these tags, so they are
  /// the handle that ties a food to a condition.
  TextColumn get tags => text().map(const StringListConverter()).withDefault(const Constant('[]'))();

  /// How much he normally eats, in [unit] (e.g. 2 «رغيف»).
  RealColumn get defaultPortion => real().nullable()();

  /// The user's own unit word («رغيف»، «كوب»، «غرام»). No unit maths is
  /// performed across different words.
  TextColumn get unit => text().nullable()();

  /// Pinned for one-tap logging.
  BoolColumn get favorite => boolean().withDefault(const Constant(false))();

  /// Kept for old entries but out of the pickers.
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

/// One thing eaten: a food of the library or free text, when, how much, and
/// optionally the meal-plan slot it belongs to.
@DataClassName('FoodLogRow')
class FoodLogs extends Table with Entity {
  /// The library food, or null for a free-text entry.
  TextColumn get foodId => text().nullable()();

  /// What was eaten as it should read in the log (the food's name at the
  /// time, or free text), so the log survives renaming or deleting a food.
  TextColumn get name => text()();
  DateTimeColumn get at => dateTime()();
  RealColumn get portion => real().nullable()();
  TextColumn get unit => text().nullable()();

  /// Extra tags for this entry only, on top of the food's own.
  TextColumn get tags => text().map(const StringListConverter()).withDefault(const Constant('[]'))();
  TextColumn get note => text().nullable()();

  /// The `meal_slots` row this entry fills, when the user says so (planned
  /// vs eaten also matches by time when this is null).
  TextColumn get slotId => text().nullable()();
}

/// A named meal plan: either the active one or a draft he is preparing.
@DataClassName('MealPlanRow')
class MealPlans extends Table with Entity, Ordered {
  TextColumn get name => text()();
  TextColumn get notes => text().nullable()();

  /// At most one plan is active at a time; the rest are drafts.
  BoolColumn get active => boolean().withDefault(const Constant(false))();
}

/// One meal of a plan: a name, a time of day and the weekdays it repeats on
/// («٨:٠٠ فطور» كل يوم).
@DataClassName('MealSlotRow')
class MealSlots extends Table with Entity, Ordered {
  TextColumn get planId => text()();
  TextColumn get name => text()();

  /// Minutes after local midnight (08:00 → 480).
  IntColumn get timeMinutes => integer()();

  /// `DateTime.weekday` values (1 = Monday … 7 = Sunday). Empty: every day.
  TextColumn get weekdays => text().map(const IntListConverter()).withDefault(const Constant('[]'))();

  /// Whether this slot gets its own reminder.
  BoolColumn get remind => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
}

/// A food planned inside one slot (a library food or free text).
@DataClassName('MealSlotFoodRow')
class MealSlotFoods extends Table with Entity, Ordered {
  TextColumn get slotId => text()();
  TextColumn get foodId => text().nullable()();
  TextColumn get name => text()();
  RealColumn get portion => real().nullable()();
  TextColumn get unit => text().nullable()();
}

/// A rule **the user writes himself**, connecting a food, one of his tags or
/// a quantity to one of his [Conditions] with a weight he chooses.
///
/// Example: target `tag`, tag «ملح عالي», condition «الضغط», weight `high`,
/// note «الملح يرفع ضغطي». The risk rating is computed from these rows only;
/// with no rows there is no rating at all.
@DataClassName('FoodRuleRow')
class FoodRules extends Table with Entity, Ordered {
  /// The condition this rule speaks about, or null for a general rule.
  TextColumn get conditionId => text().nullable()();
  TextColumn get target => textEnum<FoodRuleTarget>().withDefault(Constant(FoodRuleTarget.tag.name))();

  /// Set when [target] is `food`.
  TextColumn get foodId => text().nullable()();

  /// Set when [target] is `tag` (one of his own tags).
  TextColumn get tag => text().nullable()();

  /// Only from this portion up (in the food's own unit), e.g. "from 3 cups".
  RealColumn get minPortion => real().nullable()();

  /// Only inside this wall-clock window, minutes after midnight; the window
  /// wraps when `from > to` (22:00 → 06:00). Null: any time.
  IntColumn get fromMinutes => integer().nullable()();
  IntColumn get toMinutes => integer().nullable()();

  /// Set to make this a **day** rule: it counts only when the day holds more
  /// than this many matching entries ("more than two fried things a day").
  IntColumn get maxPerDay => integer().nullable()();
  TextColumn get weight => textEnum<RiskWeight>().withDefault(Constant(RiskWeight.medium.name))();

  /// The user's own wording, shown as the reason for a rating.
  TextColumn get note => text().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
}
