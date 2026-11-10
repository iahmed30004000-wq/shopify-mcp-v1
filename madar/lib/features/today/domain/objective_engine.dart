import '../../../core/domain/enums.dart';
import 'day_snapshot.dart';
import 'objective.dart';
import 'objective_state.dart';

/// The numbers behind the ordering rules. Defaults are the owner's.
class ObjectiveRules {
  const ObjectiveRules({
    this.prayerLead = const Duration(minutes: 15),
    this.medicineWindow = const Duration(minutes: 30),
    this.taskLead = const Duration(hours: 1),
    this.taskGrace = const Duration(hours: 1),
    this.planLead = const Duration(minutes: 30),
    this.planGrace = const Duration(hours: 1),
    this.dueNowSlack = const Duration(minutes: 10),
  });

  /// Rule 1: how long before the adhan a prayer becomes the objective (only
  /// when the adhan is on for it).
  final Duration prayerLead;

  /// Rule 2: a dose is the objective this long before and after its time.
  final Duration medicineWindow;

  /// Rule 3: a timed task is the objective this long before its time …
  final Duration taskLead;

  /// … and this long after (then only «يومك» shows it as overdue).
  final Duration taskGrace;

  /// Rule 5: a planned meal / workout is the objective this long before its
  /// time … and [planGrace] after.
  final Duration planLead;
  final Duration planGrace;

  /// After its time an item is "due now" for this long, then "late".
  final Duration dueNowSlack;
}

/// Chooses «مهمتك هلّق» and builds «يومك». Pure: same snapshot + same state
/// => same result, no clock, no I/O, never throws on any snapshot.
///
/// Priority (the owner's), first match wins; inside a rule the earliest first,
/// then by id:
/// 1. a prayer whose adhan is within 15 minutes (adhan on) or whose time has
///    begun and is not logged;
/// 2. a medicine due within 30 minutes either side;
/// 3. a timed task due within the hour;
/// 4. the adhkar window (morning after Fajr, evening after Asr) or the wird;
/// 5. a planned meal or workout;
/// 6. the most neglected planet's suggested action;
/// else nothing now (and [ObjectiveResult.later] says what comes next).
class ObjectiveEngine {
  const ObjectiveEngine({this.rules = const ObjectiveRules()});

  final ObjectiveRules rules;

  ObjectiveResult next(DaySnapshot s, ObjectiveState state) {
    final items = _evaluate(s, state);

    final eligible = items.where((c) => c.isEligible(s.now)).toList()..sort(_byPriority);
    final current = eligible.isEmpty ? null : eligible.first;

    UpcomingObjective? later;
    if (eligible.length > 1) {
      later = UpcomingObjective(objective: eligible[1].objective, showAt: _showAt(eligible[1], s.now));
    } else {
      final future = items.where((c) => c.isFuture(s.now)).toList()
        ..sort((a, b) {
          final t = _showAt(a, s.now).compareTo(_showAt(b, s.now));
          return t != 0 ? t : _byPriority(a, b);
        });
      if (future.isNotEmpty) {
        later = UpcomingObjective(objective: future.first.objective, showAt: _showAt(future.first, s.now));
      }
    }

    final agenda = <DayEntry>[
      for (final c in items)
        if (c.inAgenda)
          DayEntry(
            objective: c.objective,
            status: c.status,
            hiddenUntil: c.status == DayEntryStatus.snoozed ? c.snoozedUntil : null,
            isCurrent: identical(c, current),
            hasClock: c.hasClock,
          ),
    ]..sort(_byAgenda);

    final upNext = [
      for (final e in agenda)
        if (!e.isCurrent && (e.status == DayEntryStatus.pending || e.status == DayEntryStatus.snoozed)) e,
    ];

    return ObjectiveResult(current: current?.objective, upNext: upNext, agenda: agenda, later: later);
  }

  /// Every objective eligible at [s.now], in the order they would take the
  /// card (the first is [ObjectiveResult.current]). For tests and the UI's
  /// "what is waiting behind this one".
  List<Objective> eligibleNow(DaySnapshot s, ObjectiveState state) {
    final list = _evaluate(s, state).where((c) => c.isEligible(s.now)).toList()..sort(_byPriority);
    return [for (final c in list) c.objective];
  }

  // ---------------------------------------------------------------- ordering

  static int _byPriority(_Item a, _Item b) {
    final r = a.objective.rule.compareTo(b.objective.rule);
    if (r != 0) return r;
    final t = a.objective.at.compareTo(b.objective.at);
    if (t != 0) return t;
    return a.objective.id.compareTo(b.objective.id);
  }

  static int _byAgenda(DayEntry a, DayEntry b) {
    if (a.hasClock != b.hasClock) return a.hasClock ? -1 : 1;
    final t = a.objective.at.compareTo(b.objective.at);
    if (t != 0) return t;
    final r = a.objective.rule.compareTo(b.objective.rule);
    if (r != 0) return r;
    return a.objective.id.compareTo(b.objective.id);
  }

  static DateTime _showAt(_Item c, DateTime now) {
    final u = c.snoozedUntil;
    if (c.status == DayEntryStatus.snoozed && u != null && u.isAfter(c.showFrom)) return u;
    return c.showFrom;
  }

  // -------------------------------------------------------------- evaluation

  List<_Item> _evaluate(DaySnapshot s, ObjectiveState state) {
    final now = s.now;
    final dayKey = ObjectiveState.dayKey(s.dayStart);
    final out = <_Item>[];
    final seen = <String>{};

    void add(_Item item) {
      if (seen.add(item.objective.id)) out.add(item);
    }

    ObjectiveUrgency urgency(DateTime at) => at.isAfter(now) ? ObjectiveUrgency.soon : ObjectiveUrgency.now;

    _Item make({
      required Objective objective,
      required DateTime from,
      required DateTime to,
      required bool handled,
      bool endInclusive = false,
      bool hasClock = true,
      bool inAgenda = true,
      bool neverLapses = false,
      bool cardAllowed = true,
    }) {
      final mark = state.markFor(objective.id, dayKey);
      var status = DayEntryStatus.pending;
      DateTime? until;
      final over = neverLapses ? false : (endInclusive ? now.isAfter(to) : !now.isBefore(to));
      if (handled || mark?.kind == ObjectiveMarkKind.done) {
        status = DayEntryStatus.done;
      } else if (mark?.kind == ObjectiveMarkKind.skipped) {
        status = DayEntryStatus.skipped;
      } else if (over) {
        status = DayEntryStatus.lapsed;
      } else if (mark?.kind == ObjectiveMarkKind.snoozed && mark!.until != null && now.isBefore(mark.until!)) {
        status = DayEntryStatus.snoozed;
        until = mark.until;
      }
      return _Item(
        objective: objective,
        showFrom: from,
        showTo: to,
        endInclusive: endInclusive,
        status: status,
        snoozedUntil: until,
        hasClock: hasClock,
        inAgenda: inAgenda,
        cardAllowed: cardAllowed,
      );
    }

    // The fasting span (Fajr → Maghrib) on a Ramadan / fasting day.
    DateTime? fajrAt, maghribAt;
    for (final p in s.prayers) {
      if (p.prayer == Prayer.fajr) fajrAt = p.at;
      if (p.prayer == Prayer.maghrib) maghribAt = p.at;
    }
    final fasting = (s.isRamadan || s.isFasting) && fajrAt != null && maghribAt != null;

    // ---- 1. prayers
    final prayers = [...s.prayers]..sort((a, b) {
      final t = a.at.compareTo(b.at);
      return t != 0 ? t : a.prayer.index.compareTo(b.prayer.index);
    });
    for (var i = 0; i < prayers.length; i++) {
      final p = prayers[i];
      final end = p.endsAt ?? (i + 1 < prayers.length ? prayers[i + 1].at : s.dayEnd);
      final from = p.adhanOn ? p.at.subtract(rules.prayerLead) : p.at;
      final begun = !p.at.isAfter(now);
      final friday = s.isFriday && p.prayer == Prayer.dhuhr;
      add(
        make(
          objective: Objective(
            id: 'prayer:${p.prayer.name}',
            kind: ObjectiveKind.prayer,
            sourceTable: ObjectiveSources.prayerLogs,
            sourceId: p.refId ?? p.prayer.name,
            at: p.at,
            urgency: urgency(p.at),
            reason: begun
                ? (friday ? ObjectiveReason.fridayPrayerBegun : ObjectiveReason.prayerBegun)
                : (friday ? ObjectiveReason.fridayPrayerSoon : ObjectiveReason.prayerAdhanSoon),
            prayer: p.prayer,
          ),
          from: from,
          to: end,
          handled: p.logged,
        ),
      );
    }

    // ---- 2. medicine
    for (final d in s.doses) {
      final late = now.isAfter(d.at.add(rules.dueNowSlack));
      add(
        make(
          objective: Objective(
            id: 'med:${d.id}',
            kind: ObjectiveKind.medicine,
            sourceTable: ObjectiveSources.medDoses,
            sourceId: d.id,
            at: d.at,
            urgency: urgency(d.at),
            reason: d.at.isAfter(now)
                ? ObjectiveReason.medicineSoon
                : (late ? ObjectiveReason.medicineLate : ObjectiveReason.medicineDueNow),
            title: d.title,
          ),
          from: d.at.subtract(rules.medicineWindow),
          to: d.at.add(rules.medicineWindow),
          endInclusive: true,
          handled: d.taken,
        ),
      );
    }

    // ---- 3. timed tasks
    for (final t in s.timedTasks) {
      final late = now.isAfter(t.at.add(rules.dueNowSlack));
      add(
        make(
          objective: Objective(
            id: 'task:${t.id}',
            kind: ObjectiveKind.task,
            sourceTable: ObjectiveSources.tasks,
            sourceId: t.id,
            at: t.at,
            urgency: urgency(t.at),
            reason: t.at.isAfter(now)
                ? ObjectiveReason.taskSoon
                : (late ? ObjectiveReason.taskOverdue : ObjectiveReason.taskDueNow),
            title: t.title,
          ),
          from: t.at.subtract(rules.taskLead),
          to: t.at.add(rules.taskGrace),
          endInclusive: true,
          handled: t.done,
        ),
      );
    }

    // ---- 3b. untimed tasks: only in the day list, never the card.
    for (final t in s.untimedTasks) {
      add(
        make(
          objective: Objective(
            id: 'task:${t.id}',
            kind: ObjectiveKind.task,
            sourceTable: ObjectiveSources.tasks,
            sourceId: t.id,
            at: s.dayStart,
            urgency: ObjectiveUrgency.later,
            reason: ObjectiveReason.taskToday,
            title: t.title,
          ),
          from: s.dayEnd,
          to: s.dayEnd,
          handled: t.done,
          hasClock: false,
          neverLapses: true,
        ),
      );
    }

    // ---- 4. adhkar windows, wird
    for (final a in s.adhkar) {
      add(
        make(
          objective: Objective(
            id: 'adhkar:${a.kind.name}',
            kind: ObjectiveKind.adhkar,
            sourceTable: ObjectiveSources.adhkar,
            sourceId: a.kind.name,
            at: a.startsAt,
            urgency: urgency(a.startsAt),
            reason: a.kind == AdhkarWindowKind.morning ? ObjectiveReason.adhkarMorning : ObjectiveReason.adhkarEvening,
            adhkar: a.kind,
          ),
          from: a.startsAt,
          to: a.endsAt,
          handled: a.done,
        ),
      );
    }
    final w = s.wird;
    if (w != null) {
      final from = w.from ?? fajrAt ?? s.dayStart;
      add(
        make(
          objective: Objective(
            id: 'wird:${w.id}',
            kind: ObjectiveKind.wird,
            sourceTable: ObjectiveSources.wirdPlans,
            sourceId: w.id,
            at: from,
            urgency: urgency(from),
            reason: ObjectiveReason.wirdDue,
            title: w.title,
          ),
          from: from,
          to: s.dayEnd,
          handled: w.done,
        ),
      );
    }

    // ---- 5. planned meals and workouts
    for (final m in s.meals) {
      var from = m.at.subtract(rules.planLead);
      var to = m.at.add(rules.planGrace);
      var clipped = false;
      if (fasting) {
        // No meal between Fajr and Maghrib on a fasting day: a meal planned
        // inside the span is not offered at all, and one just outside has its
        // window clipped so it never reaches into the span.
        if (!m.at.isBefore(fajrAt) && m.at.isBefore(maghribAt)) continue;
        if (!m.at.isBefore(maghribAt) && from.isBefore(maghribAt)) from = maghribAt;
        if (m.at.isBefore(fajrAt) && to.isAfter(fajrAt)) {
          to = fajrAt;
          clipped = true;
        }
      }
      add(
        make(
          objective: Objective(
            id: 'meal:${m.id}',
            kind: ObjectiveKind.meal,
            sourceTable: ObjectiveSources.mealSlots,
            sourceId: m.id,
            at: m.at,
            urgency: urgency(m.at),
            reason: ObjectiveReason.mealPlanned,
            title: m.title,
          ),
          from: from,
          to: to,
          endInclusive: !clipped,
          handled: m.done,
        ),
      );
    }
    for (final k in s.workouts) {
      add(
        make(
          objective: Objective(
            id: 'workout:${k.id}',
            kind: ObjectiveKind.workout,
            sourceTable: ObjectiveSources.workouts,
            sourceId: k.id,
            at: k.at,
            urgency: urgency(k.at),
            reason: ObjectiveReason.workoutPlanned,
            title: k.title,
          ),
          from: k.at.subtract(rules.planLead),
          to: k.at.add(rules.planGrace),
          endInclusive: true,
          handled: k.done,
          // Travelling: the routine steps aside (still in «يومك»).
          cardAllowed: !s.travelling,
        ),
      );
    }

    // ---- 6. the neglected planet's suggestion (a nudge, not on the day list)
    final n = s.neglected;
    if (n != null && !(s.travelling && n.planetKey != 'travel')) {
      final from = fajrAt ?? s.dayStart;
      add(
        make(
          objective: Objective(
            id: 'planet:${n.planetKey}:${n.actionKey}',
            kind: ObjectiveKind.planet,
            sourceTable: n.refTable ?? ObjectiveSources.planets,
            sourceId: n.refId ?? n.planetKey,
            at: from,
            urgency: ObjectiveUrgency.later,
            reason: ObjectiveReason.planetNeglected,
            title: n.title,
            planetKey: n.planetKey,
            actionKey: n.actionKey,
          ),
          from: from,
          to: s.dayEnd,
          handled: false,
          inAgenda: false,
        ),
      );
    }

    return out;
  }
}

/// An objective plus where it stands (internal).
class _Item {
  const _Item({
    required this.objective,
    required this.showFrom,
    required this.showTo,
    required this.endInclusive,
    required this.status,
    required this.snoozedUntil,
    required this.hasClock,
    required this.inAgenda,
    this.cardAllowed = true,
  });

  final Objective objective;
  final DateTime showFrom;
  final DateTime showTo;
  final bool endInclusive;
  final DayEntryStatus status;
  final DateTime? snoozedUntil;
  final bool hasClock;
  final bool inAgenda;
  final bool cardAllowed;

  bool _inWindow(DateTime now) =>
      !now.isBefore(showFrom) && (endInclusive ? !now.isAfter(showTo) : now.isBefore(showTo));

  /// Can take the card at [now].
  bool isEligible(DateTime now) =>
      cardAllowed && hasClock && status == DayEntryStatus.pending && _inWindow(now);

  /// Will take the card later today (window not open yet, or snoozed).
  bool isFuture(DateTime now) {
    if (!cardAllowed || !hasClock) return false;
    if (status == DayEntryStatus.snoozed) {
      final u = snoozedUntil;
      return u != null && (endInclusive ? !u.isAfter(showTo) : u.isBefore(showTo));
    }
    return status == DayEntryStatus.pending && now.isBefore(showFrom);
  }
}
