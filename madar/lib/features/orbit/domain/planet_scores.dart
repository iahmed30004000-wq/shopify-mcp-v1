import 'dart:math' as math;

import 'score_sources.dart';

/// Balance scores for every planet, computed from the user's real activity.
///
/// The engine is pure: the data layer gathers plain input records
/// ([ScoreInputs]) and the engine turns them into a 0..1 score per planet plus
/// concrete, localisable "neglect reasons" for the Neglect Radar
/// (e.g. `personOverdue {name: Father, days: 3}`).
///
/// Scores drive the living state of each world on the Astrolabe Orbit:
/// ≥ 0.75 thriving (auroras, city lights, sparkling rings), 0.45–0.75 steady,
/// < 0.45 neglected (dust storms, desaturation, cracks, distress pulse).

/// Why a planet is slipping. `args` hold the values for the localised message.
enum ReasonCode {
  personOverdue, // name, days
  dosesPastDue, // count
  prayersMissed, // count
  tasksOverdue, // count
  cardsOverdue, // count, board
  budgetOverspent, // item, percent
  obligationOverdue, // name, days
  debtOverdue, // person, days
  goalBehind, // name, percent (of expected progress achieved)
  workoutsMissed, // count
  waterLow, // percent
  documentExpiring, // name, days
  tripUnpacked, // destination, days, percent
  moduleStale, // name, days
  noActivity, // days
  habitsSlipping, // count (+ name, days when count == 1)
  projectItemsOverdue, // count, project
  jarBehind, // name, percent (of expected savings achieved)
  sourceStale, // source (ScoreSources key), days
}

class NeglectReason {
  const NeglectReason({
    required this.planetKey,
    required this.code,
    required this.severity,
    this.args = const {},
    this.refTable,
    this.refId,
  });

  final String planetKey;
  final ReasonCode code;

  /// 0..1 – how urgent (sorts the radar).
  final double severity;
  final Map<String, Object> args;

  /// The record to open when the reason is tapped.
  final String? refTable;
  final String? refId;

  @override
  String toString() => 'NeglectReason($planetKey, ${code.name}, $args, ${severity.toStringAsFixed(2)})';
}

class PlanetScore {
  const PlanetScore({
    required this.planetKey,
    required this.score,
    required this.sources,
    required this.reasons,
    this.dormant = false,
  });

  final String planetKey;

  /// 0 (neglected) … 1 (thriving).
  final double score;

  /// Per-source values that produced the score.
  final Map<String, double> sources;

  /// Sorted by severity, most urgent first.
  final List<NeglectReason> reasons;

  /// No data at all for this planet yet – rendered in a calm neutral state and
  /// excluded from the Neglect Radar.
  final bool dormant;

  PlanetState get state => dormant
      ? PlanetState.dormant
      : score >= 0.75
          ? PlanetState.thriving
          : score >= 0.45
              ? PlanetState.steady
              : PlanetState.neglected;
}

enum PlanetState { thriving, steady, neglected, dormant }

// ------------------------------------------------------------------ inputs --

class PrayerLogIn {
  const PrayerLogIn({required this.day, required this.status, this.inJamaah = false});

  /// Local day of the log.
  final DateTime day;

  /// 'prayed' | 'late' | 'missed' | 'qada'.
  final String status;
  final bool inJamaah;
}

class DoseIn {
  const DoseIn({required this.medId, required this.medName, required this.scheduledAt, required this.taken});
  final String medId;
  final String medName;
  final DateTime scheduledAt;

  /// Taken (or deliberately skipped) – either way handled.
  final bool taken;
}

class PersonIn {
  const PersonIn({required this.id, required this.name, this.rhythmDays, this.lastContact, required this.createdAt});
  final String id;
  final String name;
  final int? rhythmDays;
  final DateTime? lastContact;
  final DateTime createdAt;
}

class TaskIn {
  const TaskIn({required this.id, this.planetKey, required this.done, this.date, this.doneAt});
  final String id;
  final String? planetKey;
  final bool done;
  final DateTime? date;
  final DateTime? doneAt;
}

class CardIn {
  const CardIn({required this.id, required this.boardName, required this.done, this.dueDate, this.doneAt, this.boardId});
  final String id;
  final String boardName;

  /// The board row (lets the radar open it); optional.
  final String? boardId;
  final bool done;
  final DateTime? dueDate;
  final DateTime? doneAt;
}

class BudgetStatusIn {
  const BudgetStatusIn({required this.id, required this.name, required this.planMilli, required this.spentMilli});
  final String id;
  final String name;
  final int planMilli;
  final int spentMilli;
}

class ObligationIn {
  const ObligationIn({required this.id, required this.name, required this.nextDue});
  final String id;
  final String name;
  final DateTime nextDue;
}

class DebtIn {
  const DebtIn({required this.id, required this.person, required this.iOwe, this.dueDate, required this.settled});
  final String id;
  final String person;
  final bool iOwe;
  final DateTime? dueDate;
  final bool settled;
}

class GoalIn {
  const GoalIn({
    required this.id,
    required this.name,
    required this.target,
    required this.progress,
    required this.start,
    this.deadline,
    this.lastLog,
  });
  final String id;
  final String name;
  final double target;
  final double progress;
  final DateTime start;
  final DateTime? deadline;
  final DateTime? lastLog;
}

class DocumentIn {
  const DocumentIn({required this.id, required this.name, this.expiry, this.remindDaysBefore = 30});
  final String id;
  final String name;
  final DateTime? expiry;
  final int remindDaysBefore;
}

class TripIn {
  const TripIn({required this.id, required this.destination, this.startDate, required this.itemsTotal, required this.itemsPacked});
  final String id;
  final String destination;
  final DateTime? startDate;
  final int itemsTotal;
  final int itemsPacked;
}

class ModuleIn {
  const ModuleIn({required this.id, required this.name, required this.planetKey, this.lastEntry, required this.createdAt});
  final String id;
  final String name;
  final String planetKey;
  final DateTime? lastEntry;
  final DateTime createdAt;
}

/// A habit with its recent history. Only habits done at least once in the
/// last 30 days are "tracked" (the seeded checklist does not count until the
/// user starts using it).
class HabitIn {
  const HabitIn({required this.id, required this.name, this.planetKey, required this.doneDays7d, this.lastDone});
  final String id;
  final String name;

  /// Null → [ScoreSources.attachedFallback] (health).
  final String? planetKey;

  /// Distinct days in the last 7 (today included) the habit was done.
  final int doneDays7d;
  final DateTime? lastDone;
}

class MoodIn {
  const MoodIn({required this.at, this.mood, this.stress});
  final DateTime at;

  /// 1..5.
  final int? mood;

  /// 0..10.
  final int? stress;
}

class PainIn {
  const PainIn({required this.at, required this.score});
  final DateTime at;

  /// 0..10.
  final int score;
}

class AppointmentIn {
  const AppointmentIn({required this.id, required this.title, required this.at, required this.done});
  final String id;
  final String title;
  final DateTime at;
  final bool done;
}

class ProjectItemIn {
  const ProjectItemIn({
    required this.id,
    required this.projectId,
    required this.projectName,
    this.planetKey,
    required this.done,
    this.dueDate,
    this.doneAt,
  });
  final String id;
  final String projectId;
  final String projectName;

  /// The project's planet; null → [ScoreSources.attachedFallback] (work).
  final String? planetKey;
  final bool done;
  final DateTime? dueDate;
  final DateTime? doneAt;
}

class JarIn {
  const JarIn({
    required this.id,
    required this.name,
    required this.targetMilli,
    required this.savedMilli,
    required this.start,
    this.deadline,
  });
  final String id;
  final String name;
  final int targetMilli;
  final int savedMilli;
  final DateTime start;
  final DateTime? deadline;
}

/// A devotional practice logged through the activity stream (adhkar, Quran).
class PracticeIn {
  const PracticeIn({required this.daysDone7d, this.last});

  /// Distinct days in the last 7 with an entry.
  final int daysDone7d;
  final DateTime? last;
}

/// Everything the engine needs, gathered by the data layer.
class ScoreInputs {
  const ScoreInputs({
    required this.now,
    this.prayerLogs7d = const [],
    this.obligatoryPrayersExpected7d = 0,
    this.doses3d = const [],
    this.people = const [],
    this.tasks = const [],
    this.cards = const [],
    this.budget = const [],
    this.obligations = const [],
    this.debts = const [],
    this.goals = const [],
    this.workoutsExpected7d = 0,
    this.workoutsDone7d = 0,
    this.fastsPlanned7d = 0,
    this.fastsCompleted7d = 0,
    this.waterTodayMl = 0,
    this.waterTargetMl = 0,
    this.documents = const [],
    this.trips = const [],
    this.modules = const [],
    this.lastActivity = const {},
    this.habits = const [],
    this.moods7d = const [],
    this.pains7d = const [],
    this.appointments = const [],
    this.projectItems = const [],
    this.jars = const [],
    this.lastTransactionAt,
    this.practices = const {},
  });

  final DateTime now;
  final List<PrayerLogIn> prayerLogs7d;

  /// Obligatory prayers whose time has started in the last 7 days (from the
  /// prayer schedule).
  final int obligatoryPrayersExpected7d;

  /// Doses scheduled in the last 3 days up to now.
  final List<DoseIn> doses3d;
  final List<PersonIn> people;
  final List<TaskIn> tasks;
  final List<CardIn> cards;
  final List<BudgetStatusIn> budget;
  final List<ObligationIn> obligations;
  final List<DebtIn> debts;
  final List<GoalIn> goals;
  final int workoutsExpected7d;
  final int workoutsDone7d;
  final int fastsPlanned7d;
  final int fastsCompleted7d;
  final int waterTodayMl;
  final int waterTargetMl;
  final List<DocumentIn> documents;
  final List<TripIn> trips;
  final List<ModuleIn> modules;

  /// Last ActivityLog entry per planet key.
  final Map<String, DateTime> lastActivity;

  final List<HabitIn> habits;
  final List<MoodIn> moods7d;
  final List<PainIn> pains7d;

  /// Appointments from 30 days ago to 14 days ahead.
  final List<AppointmentIn> appointments;

  /// Items of active projects: open ones, and ones done in the last 7 days.
  final List<ProjectItemIn> projectItems;

  /// Savings jars that are not archived.
  final List<JarIn> jars;

  /// Newest transaction ever (null = the user does not track spending).
  final DateTime? lastTransactionAt;

  /// Practices by source key ([ScoreSources.adhkar], [ScoreSources.quran]).
  final Map<String, PracticeIn> practices;
}

// ------------------------------------------------------------------ engine --

/// Default source weights per planet; users override them per planet
/// (`planets.sources` JSON: `{"prayers": 0.7, "tasks": 0.3}`).
const Map<String, Map<String, double>> kDefaultSourceWeights = {
  'faith': {'prayers': 0.8, 'tasks': 0.2},
  'health': {'doses': 0.7, 'tasks': 0.3},
  'family': {'contacts': 0.8, 'tasks': 0.2},
  'work': {'cards': 0.6, 'tasks': 0.4},
  'money': {'budget': 0.4, 'obligations': 0.3, 'debts': 0.2, 'tasks': 0.1},
  'growth': {'goals': 0.8, 'tasks': 0.2},
  'body': {'workouts': 0.5, 'fasting': 0.2, 'water': 0.2, 'tasks': 0.1},
  'travel': {'documents': 0.5, 'trips': 0.4, 'tasks': 0.1},
};

class PlanetScoreEngine {
  const PlanetScoreEngine();

  static const _day = Duration(days: 1);

  /// Days without any activity after which a non-dormant planet gets a
  /// [ReasonCode.noActivity] reason.
  static const quietDays = 7;

  /// Scores every planet in [planetKeys].
  ///
  /// [weights] maps a planet key to its source weights (the planet's
  /// `sources` JSON; aliases such as `medications` are accepted). They are
  /// merged over [kDefaultSourceWeights]. A weight of 0 switches a source off
  /// completely – it neither counts nor produces neglect reasons. A positive
  /// weight for a source that is not one of the planet's built-in sources
  /// ([ScoreSources.builtIn]) makes the engine derive it for that planet too
  /// (e.g. a custom "Sport" planet fed by `workouts`).
  Map<String, PlanetScore> compute(
    ScoreInputs inp, {
    Iterable<String> planetKeys = const ['faith', 'health', 'family', 'work', 'money', 'growth', 'body', 'travel'],
    Map<String, Map<String, double>> weights = const {},
  }) {
    final result = <String, PlanetScore>{};
    for (final key in planetKeys) {
      final sources = <String, double>{};
      final reasons = <NeglectReason>[];
      final w = {...?kDefaultSourceWeights[key], ...ScoreSources.canonicalWeights(weights[key] ?? const {})};
      _collect(key, inp, w, sources, reasons);

      var sum = 0.0, wsum = 0.0;
      for (final e in sources.entries) {
        final wi = w[e.key] ?? (e.key.startsWith(ScoreSources.modulePrefix) ? 0.3 : 0.2);
        if (wi <= 0) continue;
        sum += e.value * wi;
        wsum += wi;
      }
      final dormant = wsum == 0;
      var score = dormant ? 0.6 : sum / wsum;
      // Freshness: something done for this planet today lifts it slightly.
      final last = inp.lastActivity[key];
      if (!dormant && last != null && inp.now.difference(last) < _day) {
        score = math.min(1.0, score + 0.05);
      }
      if (!dormant && last != null) {
        final quiet = _daysBetween(last, inp.now);
        if (quiet >= quietDays) {
          reasons.add(NeglectReason(
            planetKey: key,
            code: ReasonCode.noActivity,
            severity: math.min(0.6, 0.2 + quiet / 30),
            args: {'days': quiet},
          ));
        }
      }
      reasons.sort((a, b) => b.severity.compareTo(a.severity));
      result[key] = PlanetScore(
        planetKey: key,
        score: score.clamp(0.0, 1.0),
        sources: sources,
        reasons: dormant ? const [] : reasons,
        dormant: dormant,
      );
    }
    return result;
  }

  /// The three weakest non-dormant planets for the Neglect Radar, each with its
  /// most urgent reason (planets without reasons are skipped).
  List<(PlanetScore, NeglectReason)> neglectRadar(Map<String, PlanetScore> scores, {int count = 3}) {
    final candidates = scores.values.where((s) => !s.dormant && s.reasons.isNotEmpty).toList()
      ..sort((a, b) {
        final c = a.score.compareTo(b.score);
        return c != 0 ? c : b.reasons.first.severity.compareTo(a.reasons.first.severity);
      });
    return [for (final s in candidates.take(count)) (s, s.reasons.first)];
  }

  // ------------------------------------------------------------ sources ----

  void _collect(
    String key,
    ScoreInputs inp,
    Map<String, double> w,
    Map<String, double> src,
    List<NeglectReason> reasons,
  ) {
    bool off(String source) => (w[source] ?? 1) <= 0;

    if (!off(ScoreSources.tasks)) _tasks(key, inp, src, reasons);
    if (!off(ScoreSources.habits)) _habits(key, inp, src, reasons);
    if (!off(ScoreSources.projects)) _projects(key, inp, src, reasons);
    for (final m in inp.modules.where((m) => m.planetKey == key)) {
      final id = '${ScoreSources.modulePrefix}${m.id}';
      if (off(id)) continue;
      final last = m.lastEntry ?? m.createdAt;
      final days = _daysBetween(last, inp.now);
      src[id] = _decay(days, halfLifeDays: 4);
      if (days >= 3) {
        reasons.add(NeglectReason(
          planetKey: key,
          code: ReasonCode.moduleStale,
          severity: math.min(1, days / 10),
          args: {'name': m.name, 'days': days},
          refTable: 'custom_modules',
          refId: m.id,
        ));
      }
    }
    final requested = <String>{
      ...?ScoreSources.builtIn[key],
      for (final e in w.entries)
        if (e.value > 0 && ScoreSources.all.contains(e.key)) e.key,
    }..removeAll(ScoreSources.attached);
    for (final s in requested) {
      if (!off(s)) _source(s, key, inp, src, reasons);
    }
  }

  void _source(String source, String key, ScoreInputs inp, Map<String, double> src, List<NeglectReason> reasons) {
    switch (source) {
      case ScoreSources.prayers:
        _prayers(key, inp, src, reasons);
      case ScoreSources.doses:
        _doses(key, inp, src, reasons);
      case ScoreSources.contacts:
        _contacts(key, inp, src, reasons);
      case ScoreSources.cards:
        _cards(key, inp, src, reasons);
      case ScoreSources.budget:
        _budget(key, inp, src, reasons);
      case ScoreSources.obligations:
        _obligations(key, inp, src, reasons);
      case ScoreSources.debts:
        _debts(key, inp, src, reasons);
      case ScoreSources.goals:
        _goals(key, inp, src, reasons);
      case ScoreSources.workouts:
        _workouts(key, inp, src, reasons);
      case ScoreSources.fasting:
        _fasting(inp, src);
      case ScoreSources.water:
        _water(key, inp, src, reasons);
      case ScoreSources.documents:
        _documents(key, inp, src, reasons);
      case ScoreSources.trips:
        _trips(key, inp, src, reasons);
      case ScoreSources.mood:
        _mood(inp, src);
      case ScoreSources.pain:
        _pain(inp, src);
      case ScoreSources.appointments:
        _appointments(inp, src);
      case ScoreSources.jars:
        _jars(key, inp, src, reasons);
      case ScoreSources.transactions:
        _transactions(key, inp, src, reasons);
      case ScoreSources.adhkar || ScoreSources.quran:
        _practice(source, key, inp, src, reasons);
    }
  }

  void _tasks(String key, ScoreInputs inp, Map<String, double> src, List<NeglectReason> reasons) {
    final mine = inp.tasks.where((t) => t.planetKey == key).toList();
    if (mine.isEmpty) return;
    final today = _startOfDay(inp.now);
    final overdue = mine.where((t) => !t.done && t.date != null && t.date!.isBefore(today)).toList();
    final recentDone = mine.where((t) => t.done && t.doneAt != null && inp.now.difference(t.doneAt!) <= const Duration(days: 7)).length;
    final open = mine.where((t) => !t.done).length;
    final denom = recentDone + overdue.length;
    final momentum = denom == 0 ? (open == 0 ? 1.0 : 0.7) : recentDone / denom;
    src[ScoreSources.tasks] = momentum.clamp(0.0, 1.0);
    if (overdue.isNotEmpty) {
      reasons.add(NeglectReason(
        planetKey: key,
        code: ReasonCode.tasksOverdue,
        severity: math.min(1, 0.3 + overdue.length * 0.15),
        args: {'count': overdue.length},
        refTable: 'tasks',
        refId: overdue.length == 1 ? overdue.first.id : null,
      ));
    }
  }

  void _habits(String key, ScoreInputs inp, Map<String, double> src, List<NeglectReason> reasons) {
    final tracked = inp.habits
        .where((h) =>
            (h.planetKey ?? ScoreSources.attachedFallback[ScoreSources.habits]) == key &&
            h.lastDone != null &&
            _daysBetween(h.lastDone!, inp.now) <= 30)
        .toList();
    if (tracked.isEmpty) return;
    var adherence = 0.0;
    for (final h in tracked) {
      adherence += (h.doneDays7d / 7).clamp(0.0, 1.0);
    }
    // 70 % of days is full marks – a checklist is a practice, not an exam.
    src[ScoreSources.habits] = (adherence / tracked.length / 0.7).clamp(0.0, 1.0);
    final slipping = tracked.where((h) => _daysBetween(h.lastDone!, inp.now) >= 3).toList();
    if (slipping.isNotEmpty) {
      final single = slipping.length == 1 ? slipping.first : null;
      reasons.add(NeglectReason(
        planetKey: key,
        code: ReasonCode.habitsSlipping,
        severity: math.min(0.8, 0.25 + slipping.length * 0.1),
        args: {
          'count': slipping.length,
          if (single != null) 'name': single.name,
          if (single != null) 'days': _daysBetween(single.lastDone!, inp.now),
        },
        refTable: 'habits',
        refId: single?.id,
      ));
    }
  }

  void _projects(String key, ScoreInputs inp, Map<String, double> src, List<NeglectReason> reasons) {
    final mine = inp.projectItems
        .where((i) => (i.planetKey ?? ScoreSources.attachedFallback[ScoreSources.projects]) == key)
        .toList();
    if (mine.isEmpty) return;
    final today = _startOfDay(inp.now);
    final overdue = mine.where((i) => !i.done && i.dueDate != null && i.dueDate!.isBefore(today)).toList();
    final recentDone = mine.where((i) => i.done && i.doneAt != null && inp.now.difference(i.doneAt!) <= const Duration(days: 7)).length;
    final open = mine.where((i) => !i.done).length;
    final denom = recentDone + overdue.length;
    final momentum = denom == 0 ? (open == 0 ? 1.0 : 0.7) : recentDone / denom;
    src[ScoreSources.projects] = momentum.clamp(0.0, 1.0);
    final byProject = <String, List<ProjectItemIn>>{};
    for (final i in overdue) {
      (byProject[i.projectId] ??= []).add(i);
    }
    for (final items in byProject.values) {
      reasons.add(NeglectReason(
        planetKey: key,
        code: ReasonCode.projectItemsOverdue,
        severity: math.min(1, 0.3 + items.length * 0.12),
        args: {'count': items.length, 'project': items.first.projectName},
        refTable: 'projects',
        refId: items.first.projectId,
      ));
    }
  }

  void _prayers(String key, ScoreInputs inp, Map<String, double> src, List<NeglectReason> reasons) {
    final expected = inp.obligatoryPrayersExpected7d;
    if (expected <= 0 && inp.prayerLogs7d.isEmpty) return;
    var credit = 0.0;
    var jamaah = 0;
    for (final l in inp.prayerLogs7d) {
      credit += switch (l.status) { 'prayed' => 1.0, 'late' => 0.7, 'qada' => 0.5, _ => 0.0 };
      if (l.inJamaah && l.status != 'missed') jamaah++;
    }
    final denom = math.max(expected, inp.prayerLogs7d.length);
    var v = denom == 0 ? 1.0 : credit / denom;
    if (denom > 0) v += 0.1 * (jamaah / denom);
    src[ScoreSources.prayers] = v.clamp(0.0, 1.0);
    final logged = inp.prayerLogs7d.where((l) => l.status != 'missed').length;
    final missed = math.max(0, expected - logged);
    if (missed > 0) {
      reasons.add(NeglectReason(
        planetKey: key,
        code: ReasonCode.prayersMissed,
        severity: math.min(1, 0.35 + missed / math.max(1, expected) * 1.5),
        args: {'count': missed},
      ));
    }
  }

  void _doses(String key, ScoreInputs inp, Map<String, double> src, List<NeglectReason> reasons) {
    const grace = Duration(minutes: 30);
    final due = inp.doses3d.where((d) => inp.now.difference(d.scheduledAt) > grace).toList();
    if (due.isEmpty) return;
    final taken = due.where((d) => d.taken).length;
    src[ScoreSources.doses] = taken / due.length;
    final today = _startOfDay(inp.now);
    final pastDueToday = due.where((d) => !d.taken && !d.scheduledAt.isBefore(today)).toList();
    if (pastDueToday.isNotEmpty) {
      final meds = {for (final d in pastDueToday) d.medId};
      final single = meds.length == 1 ? pastDueToday.first : null;
      reasons.add(NeglectReason(
        planetKey: key,
        code: ReasonCode.dosesPastDue,
        severity: math.min(1, 0.6 + pastDueToday.length * 0.15),
        args: {'count': pastDueToday.length, if (single != null) 'name': single.medName},
        refTable: 'medications',
        refId: single?.medId,
      ));
    }
  }

  void _contacts(String key, ScoreInputs inp, Map<String, double> src, List<NeglectReason> reasons) {
    final withRhythm = inp.people.where((p) => (p.rhythmDays ?? 0) > 0).toList();
    if (withRhythm.isEmpty) return;
    var total = 0.0;
    for (final p in withRhythm) {
      final rhythm = p.rhythmDays!;
      final since = _daysBetween(p.lastContact ?? p.createdAt, inp.now);
      final overdue = since - rhythm;
      if (overdue > 0) {
        total += (1 - overdue / rhythm).clamp(0.0, 1.0);
        reasons.add(NeglectReason(
          planetKey: key,
          code: ReasonCode.personOverdue,
          severity: math.min(1, 0.4 + overdue / rhythm * 0.6),
          args: {'name': p.name, 'days': overdue},
          refTable: 'people',
          refId: p.id,
        ));
      } else {
        total += 1;
      }
    }
    src[ScoreSources.contacts] = total / withRhythm.length;
  }

  void _cards(String key, ScoreInputs inp, Map<String, double> src, List<NeglectReason> reasons) {
    if (inp.cards.isEmpty) return;
    final today = _startOfDay(inp.now);
    final overdue = inp.cards.where((c) => !c.done && c.dueDate != null && c.dueDate!.isBefore(today)).toList();
    final doneRecent = inp.cards.where((c) => c.done && c.doneAt != null && inp.now.difference(c.doneAt!) <= const Duration(days: 7)).length;
    final open = inp.cards.where((c) => !c.done).length;
    final base = open == 0 ? 1.0 : 1 - overdue.length / open;
    final momentum = doneRecent == 0 ? 0.0 : math.min(0.2, doneRecent * 0.04);
    src[ScoreSources.cards] = (base * 0.9 + momentum).clamp(0.0, 1.0);
    final byBoard = <String, List<CardIn>>{};
    for (final c in overdue) {
      (byBoard[c.boardId ?? c.boardName] ??= []).add(c);
    }
    for (final cards in byBoard.values) {
      reasons.add(NeglectReason(
        planetKey: key,
        code: ReasonCode.cardsOverdue,
        severity: math.min(1, 0.35 + cards.length * 0.12),
        args: {'count': cards.length, 'board': cards.first.boardName},
        refTable: 'boards',
        refId: cards.first.boardId,
      ));
    }
  }

  void _budget(String key, ScoreInputs inp, Map<String, double> src, List<NeglectReason> reasons) {
    final planned = inp.budget.where((b) => b.planMilli > 0).toList();
    if (planned.isEmpty) return;
    var totalPlan = 0, okPlan = 0;
    for (final b in planned) {
      totalPlan += b.planMilli;
      if (b.spentMilli <= b.planMilli) {
        okPlan += b.planMilli;
      } else {
        final pct = ((b.spentMilli - b.planMilli) * 100 / b.planMilli).round();
        reasons.add(NeglectReason(
          planetKey: key,
          code: ReasonCode.budgetOverspent,
          severity: math.min(1, 0.4 + pct / 100),
          args: {'item': b.name, 'percent': pct},
          refTable: 'budget_items',
          refId: b.id,
        ));
      }
    }
    src[ScoreSources.budget] = totalPlan == 0 ? 1 : okPlan / totalPlan;
  }

  void _obligations(String key, ScoreInputs inp, Map<String, double> src, List<NeglectReason> reasons) {
    if (inp.obligations.isEmpty) return;
    var overdueCount = 0;
    for (final o in inp.obligations) {
      final days = _daysBetween(o.nextDue, inp.now);
      if (o.nextDue.isBefore(inp.now) && days >= 1) {
        overdueCount++;
        reasons.add(NeglectReason(
          planetKey: key,
          code: ReasonCode.obligationOverdue,
          severity: math.min(1, 0.55 + days * 0.05),
          args: {'name': o.name, 'days': days},
          refTable: 'obligations',
          refId: o.id,
        ));
      }
    }
    src[ScoreSources.obligations] = 1 - overdueCount / inp.obligations.length;
  }

  void _debts(String key, ScoreInputs inp, Map<String, double> src, List<NeglectReason> reasons) {
    final myDebts = inp.debts.where((d) => d.iOwe && !d.settled && d.dueDate != null).toList();
    if (myDebts.isEmpty) return;
    var overdueCount = 0;
    for (final d in myDebts) {
      final days = _daysBetween(d.dueDate!, inp.now);
      if (d.dueDate!.isBefore(inp.now) && days >= 1) {
        overdueCount++;
        reasons.add(NeglectReason(
          planetKey: key,
          code: ReasonCode.debtOverdue,
          severity: math.min(1, 0.5 + days * 0.05),
          args: {'person': d.person, 'days': days},
          refTable: 'debts',
          refId: d.id,
        ));
      }
    }
    src[ScoreSources.debts] = 1 - overdueCount / myDebts.length;
  }

  void _goals(String key, ScoreInputs inp, Map<String, double> src, List<NeglectReason> reasons) {
    if (inp.goals.isEmpty) return;
    var total = 0.0;
    for (final g in inp.goals) {
      final actual = g.target <= 0 ? 1.0 : (g.progress / g.target).clamp(0.0, 1.0);
      double v;
      int? quietDays;
      if (g.deadline != null && g.deadline!.isAfter(g.start)) {
        final span = g.deadline!.difference(g.start).inMinutes;
        final elapsed = inp.now.difference(g.start).inMinutes.clamp(0, span);
        final expected = span == 0 ? 1.0 : elapsed / span;
        v = expected <= 0.02 ? 1.0 : (actual / expected).clamp(0.0, 1.0);
      } else {
        // No deadline: recency of logging.
        quietDays = _daysBetween(g.lastLog ?? g.start, inp.now);
        v = _decay(quietDays, halfLifeDays: 7);
      }
      total += v;
      if (v < 0.7 && actual < 1) {
        reasons.add(NeglectReason(
          planetKey: key,
          code: ReasonCode.goalBehind,
          severity: (1 - v).clamp(0.0, 1.0),
          args: {'name': g.name, 'percent': (v * 100).round(), 'days': ?quietDays},
          refTable: 'learning_goals',
          refId: g.id,
        ));
      }
    }
    src[ScoreSources.goals] = total / inp.goals.length;
  }

  void _workouts(String key, ScoreInputs inp, Map<String, double> src, List<NeglectReason> reasons) {
    if (inp.workoutsExpected7d <= 0) return;
    src[ScoreSources.workouts] = (inp.workoutsDone7d / inp.workoutsExpected7d).clamp(0.0, 1.0);
    final missed = inp.workoutsExpected7d - inp.workoutsDone7d;
    if (missed > 0) {
      reasons.add(NeglectReason(
        planetKey: key,
        code: ReasonCode.workoutsMissed,
        severity: math.min(1, 0.3 + missed / inp.workoutsExpected7d),
        args: {'count': missed},
        refTable: 'exercises',
      ));
    }
  }

  void _fasting(ScoreInputs inp, Map<String, double> src) {
    if (inp.fastsPlanned7d <= 0) return;
    src[ScoreSources.fasting] = (inp.fastsCompleted7d / inp.fastsPlanned7d).clamp(0.0, 1.0);
  }

  void _water(String key, ScoreInputs inp, Map<String, double> src, List<NeglectReason> reasons) {
    if (inp.waterTargetMl <= 0) return;
    final hour = inp.now.hour + inp.now.minute / 60;
    final expectedFraction = ((hour - 7) / 14).clamp(0.0, 1.0);
    if (expectedFraction <= 0.1) return;
    final actual = inp.waterTodayMl / inp.waterTargetMl;
    final v = (actual / expectedFraction).clamp(0.0, 1.0);
    src[ScoreSources.water] = v;
    if (v < 0.6) {
      reasons.add(NeglectReason(
        planetKey: key,
        code: ReasonCode.waterLow,
        severity: (0.9 - v).clamp(0.1, 0.8),
        args: {'percent': (actual * 100).round()},
      ));
    }
  }

  void _documents(String key, ScoreInputs inp, Map<String, double> src, List<NeglectReason> reasons) {
    final docs = inp.documents.where((d) => d.expiry != null).toList();
    if (docs.isEmpty) return;
    var expiring = 0;
    for (final d in docs) {
      final days = d.expiry!.difference(inp.now).inDays;
      if (days <= d.remindDaysBefore) {
        expiring++;
        reasons.add(NeglectReason(
          planetKey: key,
          code: ReasonCode.documentExpiring,
          severity: days <= 0 ? 1.0 : math.min(1, 0.4 + (d.remindDaysBefore - days) / math.max(1, d.remindDaysBefore)),
          args: {'name': d.name, 'days': days},
          refTable: 'travel_documents',
          refId: d.id,
        ));
      }
    }
    src[ScoreSources.documents] = 1 - expiring / docs.length;
  }

  void _trips(String key, ScoreInputs inp, Map<String, double> src, List<NeglectReason> reasons) {
    final upcoming = inp.trips
        .where((t) => t.startDate != null && t.startDate!.isAfter(inp.now) && t.startDate!.difference(inp.now).inDays <= 14)
        .toList();
    if (upcoming.isEmpty) return;
    var total = 0.0;
    for (final t in upcoming) {
      final packed = t.itemsTotal == 0 ? 1.0 : t.itemsPacked / t.itemsTotal;
      final days = t.startDate!.difference(inp.now).inDays;
      // Expect packing to ramp up over the last 7 days.
      final expected = ((7 - days) / 7).clamp(0.0, 1.0);
      final v = expected == 0 ? 1.0 : (packed / expected).clamp(0.0, 1.0);
      total += v;
      if (v < 0.6) {
        reasons.add(NeglectReason(
          planetKey: key,
          code: ReasonCode.tripUnpacked,
          severity: (1 - v).clamp(0.2, 0.9),
          args: {'destination': t.destination, 'days': days, 'percent': (packed * 100).round()},
          refTable: 'trips',
          refId: t.id,
        ));
      }
    }
    src[ScoreSources.trips] = total / upcoming.length;
  }

  /// Mood is a gentle mirror, never an alarm: it moves its source between
  /// 0.5 and 1 and produces no neglect reason.
  void _mood(ScoreInputs inp, Map<String, double> src) {
    final parts = <double>[];
    for (final m in inp.moods7d) {
      final mood = m.mood;
      final stress = m.stress;
      if (mood != null) parts.add(((mood - 1) / 4).clamp(0.0, 1.0));
      if (stress != null) parts.add((1 - stress / 10).clamp(0.0, 1.0));
    }
    if (parts.isEmpty) return;
    src[ScoreSources.mood] = 0.5 + 0.5 * parts.reduce((a, b) => a + b) / parts.length;
  }

  /// Pain lowers its source to 0.4 at worst and produces no neglect reason.
  void _pain(ScoreInputs inp, Map<String, double> src) {
    if (inp.pains7d.isEmpty) return;
    final avg = inp.pains7d.fold<double>(0, (a, p) => a + p.score.clamp(0, 10)) / inp.pains7d.length;
    src[ScoreSources.pain] = 1 - 0.6 * avg / 10;
  }

  void _appointments(ScoreInputs inp, Map<String, double> src) {
    final from = inp.now.subtract(const Duration(days: 30));
    final relevant = inp.appointments.where((a) => a.at.isAfter(from)).toList();
    if (relevant.isEmpty) return;
    final pending = relevant.where((a) => !a.done && inp.now.difference(a.at) > const Duration(hours: 12)).length;
    src[ScoreSources.appointments] = 1 - pending / relevant.length;
  }

  void _jars(String key, ScoreInputs inp, Map<String, double> src, List<NeglectReason> reasons) {
    final withPlan = inp.jars.where((j) => j.targetMilli > 0 && j.deadline != null && j.deadline!.isAfter(j.start)).toList();
    if (withPlan.isEmpty) return;
    var total = 0.0;
    for (final j in withPlan) {
      final actual = (j.savedMilli / j.targetMilli).clamp(0.0, 1.0);
      final span = j.deadline!.difference(j.start).inMinutes;
      final elapsed = inp.now.difference(j.start).inMinutes.clamp(0, span);
      final expected = span == 0 ? 1.0 : elapsed / span;
      final v = expected <= 0.02 ? 1.0 : (actual / expected).clamp(0.0, 1.0);
      total += v;
      if (v < 0.7 && actual < 1) {
        reasons.add(NeglectReason(
          planetKey: key,
          code: ReasonCode.jarBehind,
          severity: ((1 - v) * 0.8).clamp(0.1, 0.8),
          args: {'name': j.name, 'percent': (v * 100).round()},
          refTable: 'jars',
          refId: j.id,
        ));
      }
    }
    src[ScoreSources.jars] = total / withPlan.length;
  }

  void _transactions(String key, ScoreInputs inp, Map<String, double> src, List<NeglectReason> reasons) {
    final last = inp.lastTransactionAt;
    if (last == null) return;
    final days = _daysBetween(last, inp.now);
    src[ScoreSources.transactions] = _decay(days, halfLifeDays: 5);
    if (days >= 5) {
      reasons.add(NeglectReason(
        planetKey: key,
        code: ReasonCode.sourceStale,
        severity: math.min(0.7, 0.2 + days / 20),
        args: {'source': ScoreSources.transactions, 'days': days},
        refTable: 'transactions',
      ));
    }
  }

  void _practice(String source, String key, ScoreInputs inp, Map<String, double> src, List<NeglectReason> reasons) {
    final p = inp.practices[source];
    final last = p?.last;
    if (p == null || last == null) return;
    final days = _daysBetween(last, inp.now);
    if (days > 30) return;
    // Five days a week is full marks.
    src[source] = (p.daysDone7d / 5).clamp(0.0, 1.0);
    if (days >= 3) {
      reasons.add(NeglectReason(
        planetKey: key,
        code: ReasonCode.sourceStale,
        severity: math.min(0.8, 0.25 + days / 15),
        args: {'source': source, 'days': days},
      ));
    }
  }

  // ------------------------------------------------------------- helpers ---

  static DateTime _startOfDay(DateTime t) => DateTime(t.year, t.month, t.day);

  /// Whole calendar days from [a] to [b] (local dates).
  static int _daysBetween(DateTime a, DateTime b) =>
      (_startOfDay(b).difference(_startOfDay(a)).inHours / 24).round();

  /// 1.0 today, halving every [halfLifeDays].
  static double _decay(int days, {required double halfLifeDays}) =>
      days <= 0 ? 1.0 : math.pow(0.5, days / halfLifeDays).toDouble();
}
