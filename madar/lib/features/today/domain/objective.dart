import '../../../core/domain/enums.dart';
import 'day_snapshot.dart';

/// What kind of thing an objective is. Each kind belongs to one ordering rule
/// of «مهمتك هلّق» (see [rule]).
enum ObjectiveKind {
  prayer(1),
  medicine(2),
  task(3),
  adhkar(4),
  wird(4),
  meal(5),
  workout(5),
  planet(6);

  const ObjectiveKind(this.rule);

  /// The ordering rule (1 = most important) this kind belongs to.
  final int rule;
}

/// Why the objective is shown: the UI turns each value into a sentence.
enum ObjectiveReason {
  /// A prayer whose adhan is within the look-ahead.
  prayerAdhanSoon,

  /// A prayer whose time has begun and is not logged.
  prayerBegun,

  /// Same two, for the Friday midday prayer on a Friday.
  fridayPrayerSoon,
  fridayPrayerBegun,

  /// A dose due within the window ahead / right now / a little late.
  medicineSoon,
  medicineDueNow,
  medicineLate,

  /// A timed task starting within the hour / now / a little overdue.
  taskSoon,
  taskDueNow,
  taskOverdue,

  /// An untimed task (day list only; never the card).
  taskToday,

  adhkarMorning,
  adhkarEvening,
  wirdDue,
  mealPlanned,
  workoutPlanned,
  planetNeglected,
}

/// How pressing: [now] it is due or has begun, [soon] it is coming up in its
/// look-ahead, [later] it has no clock (a nudge).
enum ObjectiveUrgency { now, soon, later }

/// Source-table names used in [Objective.sourceTable] (the real Drift tables).
abstract final class ObjectiveSources {
  static const prayerLogs = 'prayer_logs';
  static const medDoses = 'med_doses';
  static const tasks = 'tasks';
  static const adhkar = 'adhkar_sessions';
  static const wirdPlans = 'wird_plans';
  static const mealSlots = 'meal_slots';
  static const workouts = 'workout_templates';
  static const planets = 'planets';
}

/// One thing to do, with everything the card needs and nothing user-facing
/// typed in: text comes from [reason] (+ [title], the user's own words).
class Objective {
  const Objective({
    required this.id,
    required this.kind,
    required this.sourceTable,
    required this.sourceId,
    required this.at,
    required this.urgency,
    required this.reason,
    this.title,
    this.prayer,
    this.adhkar,
    this.planetKey,
    this.actionKey,
  });

  /// Stable across rebuilds and restarts (`prayer:fajr`, `task:<id>`, …):
  /// the key of snooze / skip / done in `ObjectiveState`.
  final String id;
  final ObjectiveKind kind;

  /// The record this objective is about (table + id as strings).
  final String sourceTable;
  final String sourceId;

  /// When it is due (prayer time, dose time, task time, window start, …).
  final DateTime at;
  final ObjectiveUrgency urgency;
  final ObjectiveReason reason;

  /// The user's own name for it (medicine name, task title) when known.
  final String? title;

  /// Set for [ObjectiveKind.prayer].
  final Prayer? prayer;

  /// Set for [ObjectiveKind.adhkar].
  final AdhkarWindowKind? adhkar;

  /// Set for [ObjectiveKind.planet].
  final String? planetKey;
  final String? actionKey;

  int get rule => kind.rule;

  @override
  bool operator ==(Object other) =>
      other is Objective &&
      other.id == id &&
      other.kind == kind &&
      other.sourceTable == sourceTable &&
      other.sourceId == sourceId &&
      other.at == at &&
      other.urgency == urgency &&
      other.reason == reason &&
      other.title == title &&
      other.prayer == prayer &&
      other.adhkar == adhkar &&
      other.planetKey == planetKey &&
      other.actionKey == actionKey;

  @override
  int get hashCode =>
      Object.hash(id, kind, sourceTable, sourceId, at, urgency, reason, title, prayer, adhkar, planetKey, actionKey);

  @override
  String toString() => 'Objective($id, ${reason.name}, at $at)';
}

/// Where an item of the day stands.
enum DayEntryStatus {
  /// Not done, not hidden, still to come or in its window.
  pending,

  /// Handled (logged, taken, ticked, or «تم»).
  done,

  /// Hidden by «بعدين» until [DayEntry.hiddenUntil].
  snoozed,

  /// Cleared by «تخطّي» for today.
  skipped,

  /// Not handled and its window is over (a missed dose, an unlogged prayer
  /// whose window ended): only the day list shows it now.
  lapsed,
}

/// One line of «يومك».
class DayEntry {
  const DayEntry({required this.objective, required this.status, this.hiddenUntil, this.isCurrent = false, this.hasClock = true});

  /// The objective this line stands for (its [Objective.at] is the line's
  /// time; for an untimed task it is the start of the day).
  final Objective objective;
  final DayEntryStatus status;

  /// For [DayEntryStatus.snoozed]: when it comes back.
  final DateTime? hiddenUntil;

  /// This is the objective on the card right now.
  final bool isCurrent;

  /// False for untimed tasks (they sort after the timed lines).
  final bool hasClock;

  String get id => objective.id;

  @override
  bool operator ==(Object other) =>
      other is DayEntry &&
      other.objective == objective &&
      other.status == status &&
      other.hiddenUntil == hiddenUntil &&
      other.isCurrent == isCurrent &&
      other.hasClock == hasClock;

  @override
  int get hashCode => Object.hash(objective, status, hiddenUntil, isCurrent, hasClock);
}

/// The next thing that will become the objective, for the "nothing now" card.
class UpcomingObjective {
  const UpcomingObjective({required this.objective, required this.showAt});

  final Objective objective;

  /// When it will appear on the card (its look-ahead start, or the end of a
  /// snooze).
  final DateTime showAt;

  @override
  bool operator ==(Object other) => other is UpcomingObjective && other.objective == objective && other.showAt == showAt;

  @override
  int get hashCode => Object.hash(objective, showAt);
}

/// What `ObjectiveEngine.next` returns.
class ObjectiveResult {
  const ObjectiveResult({required this.current, required this.upNext, required this.agenda, this.later});

  /// The one thing to do now; null = "nothing now".
  final Objective? current;

  /// The rest of the day still to come, in time order (pending entries only,
  /// without [current]): the «يومك» preview.
  final List<DayEntry> upNext;

  /// The whole day in time order with every status (done ones included).
  final List<DayEntry> agenda;

  /// The next objective that will appear on the card after [current].
  final UpcomingObjective? later;

  bool get isNothingNow => current == null;

  @override
  bool operator ==(Object other) =>
      other is ObjectiveResult &&
      other.current == current &&
      other.later == later &&
      _listEq(other.upNext, upNext) &&
      _listEq(other.agenda, agenda);

  @override
  int get hashCode => Object.hash(current, later, Object.hashAll(upNext), Object.hashAll(agenda));

  static bool _listEq<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
