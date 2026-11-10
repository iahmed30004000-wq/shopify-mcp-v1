import '../../../core/domain/enums.dart';

/// Everything the objective engine needs to know about the moment, as plain
/// immutable values. The engine never reads a database or a provider: an
/// adapter (written by the integrator) builds one [DaySnapshot] from the real
/// providers and calls `ObjectiveEngine.next` with it, so the engine is
/// testable with a fake clock and a hand-made day.
///
/// All instants are device-local `DateTime`s, like the rest of the app.

/// One obligatory prayer of the day.
class PrayerSlot {
  const PrayerSlot({
    required this.prayer,
    required this.at,
    this.endsAt,
    this.logged = false,
    this.adhanOn = true,
    this.refId,
  });

  final Prayer prayer;

  /// When the prayer time (and its adhan) begins.
  final DateTime at;

  /// When its window ends (the next prayer; sunrise for Fajr). When null the
  /// engine uses the next slot's time, or the end of the day for the last one.
  final DateTime? endsAt;

  /// Logged by any route (home, tracker, notification, by hand elsewhere).
  final bool logged;

  /// The adhan is switched on for this prayer. Off: only "the time has begun"
  /// triggers the objective, never the 15-minute look-ahead.
  final bool adhanOn;

  /// Id of the prayer-log row when one exists (else null).
  final String? refId;
}

/// One scheduled dose of a medicine.
class MedDose {
  const MedDose({required this.id, required this.at, this.taken = false, this.title, this.medId});

  /// Dose row id (stable for that scheduled dose).
  final String id;
  final DateTime at;

  /// Taken or deliberately skipped: either way handled.
  final bool taken;

  /// The medicine's name as the user typed it (carried through for the card).
  final String? title;
  final String? medId;
}

/// A task with a clock time today.
class TimedTask {
  const TimedTask({required this.id, required this.at, this.done = false, this.title});

  final String id;
  final DateTime at;
  final bool done;
  final String? title;
}

/// A task for today without a clock time (it only shows in the day list).
class UntimedTask {
  const UntimedTask({required this.id, this.done = false, this.title});

  final String id;
  final bool done;
  final String? title;
}

/// Which adhkar window.
enum AdhkarWindowKind { morning, evening }

/// A time window in which a set of adhkar is due.
class AdhkarWindowSlot {
  const AdhkarWindowSlot({required this.kind, required this.startsAt, required this.endsAt, this.done = false});

  final AdhkarWindowKind kind;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool done;

  /// The two windows from the owner's rule, built from the day's prayer times:
  /// morning from Fajr until Dhuhr, evening from Asr until Isha (the same
  /// spans `AdhkarTiming.suggested` uses). Pass whether each is done.
  static List<AdhkarWindowSlot> standard({
    required DateTime fajr,
    required DateTime dhuhr,
    required DateTime asr,
    required DateTime isha,
    bool morningDone = false,
    bool eveningDone = false,
  }) => [
    AdhkarWindowSlot(kind: AdhkarWindowKind.morning, startsAt: fajr, endsAt: dhuhr, done: morningDone),
    AdhkarWindowSlot(kind: AdhkarWindowKind.evening, startsAt: asr, endsAt: isha, done: eveningDone),
  ];
}

/// Today's wird (Quran portion) when one is owed.
class WirdSlot {
  const WirdSlot({required this.id, this.from, this.done = false, this.title});

  /// The plan id.
  final String id;

  /// When it becomes the thing to do (the user's wird time, or after Fajr).
  /// Null: from Fajr (or the start of the day when no Fajr is known).
  final DateTime? from;
  final bool done;
  final String? title;
}

/// A planned meal (from the meal plan) today.
class PlannedMeal {
  const PlannedMeal({required this.id, required this.at, this.done = false, this.title});

  final String id;
  final DateTime at;
  final bool done;
  final String? title;
}

/// A planned workout today.
class PlannedWorkout {
  const PlannedWorkout({required this.id, required this.at, this.done = false, this.title});

  final String id;
  final DateTime at;
  final bool done;
  final String? title;
}

/// The one suggested action of the most neglected planet.
class NeglectSuggestion {
  const NeglectSuggestion({
    required this.planetKey,
    required this.actionKey,
    this.score = 0,
    this.refTable,
    this.refId,
    this.title,
  });

  final String planetKey;

  /// What to do, as an id the UI turns into text (a `ReasonCode` name, or a
  /// planet action key).
  final String actionKey;

  /// 0 (neglected) .. 1 (thriving), as in `PlanetScore.score`.
  final double score;
  final String? refTable;
  final String? refId;
  final String? title;

  /// Picks the most neglected of [candidates] (lowest score, then key) so the
  /// adapter can reuse one rule: only planets whose score says "neglected"
  /// should be passed in.
  static NeglectSuggestion? mostNeglected(Iterable<NeglectSuggestion> candidates) {
    NeglectSuggestion? best;
    for (final c in candidates) {
      if (best == null ||
          c.score < best.score ||
          (c.score == best.score && c.planetKey.compareTo(best.planetKey) < 0)) {
        best = c;
      }
    }
    return best;
  }
}

/// The moment: clock + the day's records + a few flags.
class DaySnapshot {
  const DaySnapshot({
    required this.now,
    this.day,
    this.prayers = const [],
    this.doses = const [],
    this.timedTasks = const [],
    this.untimedTasks = const [],
    this.adhkar = const [],
    this.wird,
    this.meals = const [],
    this.workouts = const [],
    this.neglected,
    this.isRamadan = false,
    this.isFasting = false,
    this.isFriday = false,
    this.travelling = false,
  });

  final DateTime now;

  /// The calendar day the records belong to (local midnight). Defaults to the
  /// day of [now]. Skips and "done" marks are kept per this day.
  final DateTime? day;

  final List<PrayerSlot> prayers;
  final List<MedDose> doses;
  final List<TimedTask> timedTasks;
  final List<UntimedTask> untimedTasks;
  final List<AdhkarWindowSlot> adhkar;
  final WirdSlot? wird;
  final List<PlannedMeal> meals;
  final List<PlannedWorkout> workouts;
  final NeglectSuggestion? neglected;

  /// Ramadan: no meal is an objective between Fajr and Maghrib.
  final bool isRamadan;

  /// A voluntary fasting day (same effect on meals as [isRamadan]).
  final bool isFasting;

  /// Friday: the Dhuhr objective carries the Friday-prayer reason.
  final bool isFriday;

  /// Travelling: routine nudges (planned workout, neglected-planet) step aside.
  final bool travelling;

  /// Local midnight of the snapshot's day.
  DateTime get dayStart {
    final d = day ?? now;
    return DateTime(d.year, d.month, d.day);
  }

  /// Local midnight after the snapshot's day.
  DateTime get dayEnd => DateTime(dayStart.year, dayStart.month, dayStart.day + 1);
}
