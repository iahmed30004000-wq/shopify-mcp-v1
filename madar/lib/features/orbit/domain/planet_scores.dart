import 'dart:math' as math;

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
  const CardIn({required this.id, required this.boardName, required this.done, this.dueDate, this.doneAt});
  final String id;
  final String boardName;
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

  Map<String, PlanetScore> compute(
    ScoreInputs inp, {
    Iterable<String> planetKeys = const ['faith', 'health', 'family', 'work', 'money', 'growth', 'body', 'travel'],
    Map<String, Map<String, double>> weights = const {},
  }) {
    final result = <String, PlanetScore>{};
    for (final key in planetKeys) {
      final sources = <String, double>{};
      final reasons = <NeglectReason>[];
      _collect(key, inp, sources, reasons);

      final w = {...?kDefaultSourceWeights[key], ...?weights[key]};
      var sum = 0.0, wsum = 0.0;
      for (final e in sources.entries) {
        final wi = w[e.key] ?? (e.key.startsWith('module:') ? 0.3 : 0.2);
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

  void _collect(String key, ScoreInputs inp, Map<String, double> src, List<NeglectReason> reasons) {
    _tasks(key, inp, src, reasons);
    for (final m in inp.modules.where((m) => m.planetKey == key)) {
      final last = m.lastEntry ?? m.createdAt;
      final days = _daysBetween(last, inp.now);
      src['module:${m.id}'] = _decay(days, halfLifeDays: 4);
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
    switch (key) {
      case 'faith':
        _prayers(inp, src, reasons);
      case 'health':
        _doses(inp, src, reasons);
      case 'family':
        _contacts(inp, src, reasons);
      case 'work':
        _cards(inp, src, reasons);
      case 'money':
        _money(inp, src, reasons);
      case 'growth':
        _goals(inp, src, reasons);
      case 'body':
        _body(inp, src, reasons);
      case 'travel':
        _travel(inp, src, reasons);
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
    src['tasks'] = momentum.clamp(0.0, 1.0);
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

  void _prayers(ScoreInputs inp, Map<String, double> src, List<NeglectReason> reasons) {
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
    src['prayers'] = v.clamp(0.0, 1.0);
    final logged = inp.prayerLogs7d.where((l) => l.status != 'missed').length;
    final missed = math.max(0, expected - logged);
    if (missed > 0) {
      reasons.add(NeglectReason(
        planetKey: 'faith',
        code: ReasonCode.prayersMissed,
        severity: math.min(1, 0.35 + missed / math.max(1, expected) * 1.5),
        args: {'count': missed},
      ));
    }
  }

  void _doses(ScoreInputs inp, Map<String, double> src, List<NeglectReason> reasons) {
    const grace = Duration(minutes: 30);
    final due = inp.doses3d.where((d) => inp.now.difference(d.scheduledAt) > grace).toList();
    if (due.isEmpty) return;
    final taken = due.where((d) => d.taken).length;
    src['doses'] = taken / due.length;
    final today = _startOfDay(inp.now);
    final pastDueToday = due.where((d) => !d.taken && !d.scheduledAt.isBefore(today)).toList();
    if (pastDueToday.isNotEmpty) {
      reasons.add(NeglectReason(
        planetKey: 'health',
        code: ReasonCode.dosesPastDue,
        severity: math.min(1, 0.6 + pastDueToday.length * 0.15),
        args: {'count': pastDueToday.length},
        refTable: 'medications',
        refId: pastDueToday.length == 1 ? pastDueToday.first.medId : null,
      ));
    }
  }

  void _contacts(ScoreInputs inp, Map<String, double> src, List<NeglectReason> reasons) {
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
          planetKey: 'family',
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
    src['contacts'] = total / withRhythm.length;
  }

  void _cards(ScoreInputs inp, Map<String, double> src, List<NeglectReason> reasons) {
    if (inp.cards.isEmpty) return;
    final today = _startOfDay(inp.now);
    final overdue = inp.cards.where((c) => !c.done && c.dueDate != null && c.dueDate!.isBefore(today)).toList();
    final doneRecent = inp.cards.where((c) => c.done && c.doneAt != null && inp.now.difference(c.doneAt!) <= const Duration(days: 7)).length;
    final open = inp.cards.where((c) => !c.done).length;
    final base = open == 0 ? 1.0 : 1 - overdue.length / open;
    final momentum = doneRecent == 0 ? 0.0 : math.min(0.2, doneRecent * 0.04);
    src['cards'] = (base * 0.9 + momentum).clamp(0.0, 1.0);
    final byBoard = <String, int>{};
    for (final c in overdue) {
      byBoard[c.boardName] = (byBoard[c.boardName] ?? 0) + 1;
    }
    for (final e in byBoard.entries) {
      reasons.add(NeglectReason(
        planetKey: 'work',
        code: ReasonCode.cardsOverdue,
        severity: math.min(1, 0.35 + e.value * 0.12),
        args: {'count': e.value, 'board': e.key},
        refTable: 'boards',
      ));
    }
  }

  void _money(ScoreInputs inp, Map<String, double> src, List<NeglectReason> reasons) {
    final planned = inp.budget.where((b) => b.planMilli > 0).toList();
    if (planned.isNotEmpty) {
      var totalPlan = 0, okPlan = 0;
      for (final b in planned) {
        totalPlan += b.planMilli;
        if (b.spentMilli <= b.planMilli) {
          okPlan += b.planMilli;
        } else {
          final pct = ((b.spentMilli - b.planMilli) * 100 / b.planMilli).round();
          reasons.add(NeglectReason(
            planetKey: 'money',
            code: ReasonCode.budgetOverspent,
            severity: math.min(1, 0.4 + pct / 100),
            args: {'item': b.name, 'percent': pct},
            refTable: 'budget_items',
            refId: b.id,
          ));
        }
      }
      src['budget'] = totalPlan == 0 ? 1 : okPlan / totalPlan;
    }
    if (inp.obligations.isNotEmpty) {
      var overdueCount = 0;
      for (final o in inp.obligations) {
        final days = _daysBetween(o.nextDue, inp.now);
        if (o.nextDue.isBefore(inp.now) && days >= 1) {
          overdueCount++;
          reasons.add(NeglectReason(
            planetKey: 'money',
            code: ReasonCode.obligationOverdue,
            severity: math.min(1, 0.55 + days * 0.05),
            args: {'name': o.name, 'days': days},
            refTable: 'obligations',
            refId: o.id,
          ));
        }
      }
      src['obligations'] = 1 - overdueCount / inp.obligations.length;
    }
    final myDebts = inp.debts.where((d) => d.iOwe && !d.settled && d.dueDate != null).toList();
    if (myDebts.isNotEmpty) {
      var overdueCount = 0;
      for (final d in myDebts) {
        final days = _daysBetween(d.dueDate!, inp.now);
        if (d.dueDate!.isBefore(inp.now) && days >= 1) {
          overdueCount++;
          reasons.add(NeglectReason(
            planetKey: 'money',
            code: ReasonCode.debtOverdue,
            severity: math.min(1, 0.5 + days * 0.05),
            args: {'person': d.person, 'days': days},
            refTable: 'debts',
            refId: d.id,
          ));
        }
      }
      src['debts'] = 1 - overdueCount / myDebts.length;
    }
  }

  void _goals(ScoreInputs inp, Map<String, double> src, List<NeglectReason> reasons) {
    if (inp.goals.isEmpty) return;
    var total = 0.0;
    for (final g in inp.goals) {
      final actual = g.target <= 0 ? 1.0 : (g.progress / g.target).clamp(0.0, 1.0);
      double v;
      if (g.deadline != null && g.deadline!.isAfter(g.start)) {
        final span = g.deadline!.difference(g.start).inMinutes;
        final elapsed = inp.now.difference(g.start).inMinutes.clamp(0, span);
        final expected = span == 0 ? 1.0 : elapsed / span;
        v = expected <= 0.02 ? 1.0 : (actual / expected).clamp(0.0, 1.0);
      } else {
        // No deadline: recency of logging.
        v = _decay(_daysBetween(g.lastLog ?? g.start, inp.now), halfLifeDays: 7);
      }
      total += v;
      if (v < 0.7 && actual < 1) {
        reasons.add(NeglectReason(
          planetKey: 'growth',
          code: ReasonCode.goalBehind,
          severity: (1 - v).clamp(0.0, 1.0),
          args: {'name': g.name, 'percent': (v * 100).round()},
          refTable: 'learning_goals',
          refId: g.id,
        ));
      }
    }
    src['goals'] = total / inp.goals.length;
  }

  void _body(ScoreInputs inp, Map<String, double> src, List<NeglectReason> reasons) {
    if (inp.workoutsExpected7d > 0) {
      src['workouts'] = (inp.workoutsDone7d / inp.workoutsExpected7d).clamp(0.0, 1.0);
      final missed = inp.workoutsExpected7d - inp.workoutsDone7d;
      if (missed > 0) {
        reasons.add(NeglectReason(
          planetKey: 'body',
          code: ReasonCode.workoutsMissed,
          severity: math.min(1, 0.3 + missed / inp.workoutsExpected7d),
          args: {'count': missed},
          refTable: 'exercises',
        ));
      }
    }
    if (inp.fastsPlanned7d > 0) {
      src['fasting'] = (inp.fastsCompleted7d / inp.fastsPlanned7d).clamp(0.0, 1.0);
    }
    if (inp.waterTargetMl > 0) {
      final hour = inp.now.hour + inp.now.minute / 60;
      final expectedFraction = ((hour - 7) / 14).clamp(0.0, 1.0);
      if (expectedFraction > 0.1) {
        final actual = inp.waterTodayMl / inp.waterTargetMl;
        final v = (actual / expectedFraction).clamp(0.0, 1.0);
        src['water'] = v;
        if (v < 0.6) {
          reasons.add(NeglectReason(
            planetKey: 'body',
            code: ReasonCode.waterLow,
            severity: (0.9 - v).clamp(0.1, 0.8),
            args: {'percent': (actual * 100).round()},
          ));
        }
      }
    }
  }

  void _travel(ScoreInputs inp, Map<String, double> src, List<NeglectReason> reasons) {
    final docs = inp.documents.where((d) => d.expiry != null).toList();
    if (docs.isNotEmpty) {
      var expiring = 0;
      for (final d in docs) {
        final days = d.expiry!.difference(inp.now).inDays;
        if (days <= d.remindDaysBefore) {
          expiring++;
          reasons.add(NeglectReason(
            planetKey: 'travel',
            code: ReasonCode.documentExpiring,
            severity: days <= 0 ? 1.0 : math.min(1, 0.4 + (d.remindDaysBefore - days) / math.max(1, d.remindDaysBefore)),
            args: {'name': d.name, 'days': days},
            refTable: 'travel_documents',
            refId: d.id,
          ));
        }
      }
      src['documents'] = 1 - expiring / docs.length;
    }
    final upcoming = inp.trips
        .where((t) => t.startDate != null && t.startDate!.isAfter(inp.now) && t.startDate!.difference(inp.now).inDays <= 14)
        .toList();
    if (upcoming.isNotEmpty) {
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
            planetKey: 'travel',
            code: ReasonCode.tripUnpacked,
            severity: (1 - v).clamp(0.2, 0.9),
            args: {'destination': t.destination, 'days': days, 'percent': (packed * 100).round()},
            refTable: 'trips',
            refId: t.id,
          ));
        }
      }
      src['trips'] = total / upcoming.length;
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
