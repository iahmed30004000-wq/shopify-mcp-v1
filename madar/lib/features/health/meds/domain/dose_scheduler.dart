import 'package:flutter/foundation.dart';

import '../../../../core/domain/enums.dart';
import 'course_schedule.dart';
import 'med_models.dart';
import 'meds_settings.dart';

/// Turns a calendar day and a wall-clock minute into an instant.
///
/// Production uses the device's zone ([LocalWallClock]); tests inject a zone
/// with daylight-saving transitions to prove the plan survives them.
abstract interface class WallClock {
  /// The instant of [minuteOfDay] (may be negative or ≥ 1440: it rolls into
  /// the neighbouring day) on [day]'s calendar date.
  DateTime at(DateTime day, int minuteOfDay);
}

/// The device's wall clock: a time skipped by a spring-forward transition
/// resolves forward (02:30 → 03:30), a repeated one to its first occurrence
/// – `DateTime`'s own normalisation, which the orbit's score shares.
class LocalWallClock implements WallClock {
  const LocalWallClock();

  @override
  DateTime at(DateTime day, int minuteOfDay) => DateTime(day.year, day.month, day.day, 0, minuteOfDay);
}

/// The instant of one of [day]'s prayer moments (null when unknown – the
/// dose then falls back to its stored time).
typedef PrayerTimeOf = DateTime? Function(DateTime day, AnchorBase prayer);

/// Where a planned dose comes from.
enum DoseSource { daily, titration, course }

/// One dose in the plan.
@immutable
class PlannedDose {
  const PlannedDose({
    required this.med,
    required this.day,
    required this.slot,
    required this.baseAt,
    required this.at,
    this.dose,
    this.doseAmount,
    this.source = DoseSource.daily,
    this.courseId,
    this.courseDose,
    this.anchor,
    this.pinned = false,
    this.ruleIds = const [],
    this.meal,
  });

  final MedSpec med;

  /// The calendar day the dose belongs to (its slot's day, even when a rule
  /// moved it past midnight).
  final DateTime day;

  /// Identity: [day] at the medication's stored time (`MedDoses.scheduledAt`).
  final DateTime slot;

  /// Its time before timing rules (anchor resolved).
  final DateTime baseAt;

  /// Its time in the plan (after timing rules; the actual time once taken).
  final DateTime at;
  final String? dose;
  final double? doseAmount;
  final DoseSource source;
  final String? courseId;
  final CourseDoseDay? courseDose;
  final TimeAnchor? anchor;

  /// Fixed by a food rule or by having been taken.
  final bool pinned;

  /// The rules that set or moved its time.
  final List<String> ruleIds;

  /// The meal a food rule tied it to.
  final MealSlot? meal;

  String get medId => med.id;

  String get key => doseKey(med.id, slot);

  /// How far the timing rules moved it.
  Duration get shift => at.difference(baseAt);

  bool get shifted => shift.inMinutes != 0;

  /// It moved into the next calendar day.
  bool get pastMidnight => at.isAfter(day) && !MedDays.same(at, day);

  static String doseKey(String medId, DateTime slot) => '$medId@${slot.millisecondsSinceEpoch ~/ 60000}';

  PlannedDose copyWith({DateTime? at, bool? pinned, List<String>? ruleIds, MealSlot? meal}) => PlannedDose(
    med: med,
    day: day,
    slot: slot,
    baseAt: baseAt,
    at: at ?? this.at,
    dose: dose,
    doseAmount: doseAmount,
    source: source,
    courseId: courseId,
    courseDose: courseDose,
    anchor: anchor,
    pinned: pinned ?? this.pinned,
    ruleIds: ruleIds ?? this.ruleIds,
    meal: meal ?? this.meal,
  );

  @override
  String toString() => 'PlannedDose(${med.name} slot=$slot at=$at${shifted ? ' shifted ${shift.inMinutes}m' : ''})';
}

enum DoseConflictKind {
  /// A separation rule could not be met within the allowed shift.
  separation,

  /// A food rule found no free meal for the dose (every meal already has a
  /// dose of that medication).
  noMeal,

  /// Two food rules of one medication disagree; the first one wins.
  ruleClash,
}

/// A rule the plan could not satisfy. The doses stay in the plan (never
/// dropped) at their best-effort times.
@immutable
class DoseConflict {
  const DoseConflict({
    required this.kind,
    required this.rule,
    required this.a,
    this.b,
    this.requiredMinutes = 0,
    this.actualMinutes = 0,
  });

  final DoseConflictKind kind;
  final RuleSpec rule;
  final PlannedDose a;
  final PlannedDose? b;
  final int requiredMinutes;
  final int actualMinutes;

  String get key => '${kind.name}|${rule.id}|${a.key}|${b?.key ?? ''}';

  @override
  String toString() => 'DoseConflict(${kind.name} ${a.med.name}/${b?.med.name} $actualMinutes<$requiredMinutes)';
}

/// The dose plan of one day.
@immutable
class DayPlan {
  const DayPlan({required this.day, required this.doses, this.conflicts = const []});

  final DateTime day;

  /// Sorted by planned time.
  final List<PlannedDose> doses;
  final List<DoseConflict> conflicts;

  bool get isEmpty => doses.isEmpty;
}

/// Builds dose plans from medications, courses, titration steps and timing
/// rules – pure Dart, deterministic, independent of "now".
///
/// 1. **Expansion** – every active medication's daily times (or its linked
///    courses' dose days), each time resolved through its anchor ("20 min
///    after Fajr" follows Fajr; "with breakfast" the user's breakfast); the
///    day's dose text comes from the course phase, else the titration step,
///    else the medication.
/// 2. **Food rules** pin a dose to a meal ± minutes (the meal its "taken
///    with" slot or its anchor names, else the nearest free one).
/// 3. **Separation rules** move the later dose of a too-close pair later
///    (when it cannot, the earlier one earlier), within
///    [MedsSettings.maxShift] of its own time and without passing the
///    medication's neighbouring doses; a dose only ever moves one way, so
///    chains of rules settle. Taken doses are pinned at their real time, so
///    taking A late moves B.
/// 4. Whatever cannot be satisfied is reported as a [DoseConflict]. No dose
///    is ever dropped.
///
/// Doses near midnight see the neighbouring days: a plan is computed over
/// the requested days plus one day on each side.
class DoseScheduler {
  DoseScheduler({
    required List<MedSpec> meds,
    this.courses = const [],
    this.rules = const [],
    this.settings = const MedsSettings(),
    this.prayerTime,
    this.wallClock = const LocalWallClock(),
  }) : meds = _stableByOrder(meds);

  static List<MedSpec> _stableByOrder(List<MedSpec> meds) {
    final indexed = [for (var i = 0; i < meds.length; i++) (i, meds[i])];
    indexed.sort((a, b) {
      final c = a.$2.sortOrder.compareTo(b.$2.sortOrder);
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
    return [for (final (_, m) in indexed) m];
  }

  final List<MedSpec> meds;
  final List<CourseSpec> courses;
  final List<RuleSpec> rules;
  final MedsSettings settings;
  final PrayerTimeOf? prayerTime;
  final WallClock wallClock;

  /// The time a course dose takes when its medication has no time at all.
  static const courseDefaultTime = ClockHm(9, 0);

  /// Fewest minutes a rule may leave between two doses of one medication.
  static const sameMedGap = 60;

  static const _maxPasses = 64;

  /// The courses that drive [med] (linked either way).
  List<CourseSpec> coursesOf(MedSpec med) => [
    for (final c in courses)
      if (c.medicationId == med.id || (med.courseId != null && c.id == med.courseId)) c,
  ];

  /// The dose text / amount of [med] on [day] outside courses: the latest
  /// titration step on or before [day] (null result = a "stop" step).
  static ({String? dose, double? amount, bool titrated})? doseOn(MedSpec med, DateTime day) {
    final d = MedDays.dateOnly(day);
    TitrationStep? step;
    for (final s in med.titration) {
      if (!s.from.isAfter(d)) step = s;
    }
    if (step == null) return (dose: med.dose, amount: med.doseAmount, titrated: false);
    if (step.stop) return null;
    return (dose: step.dose ?? med.dose, amount: step.doseAmount ?? (step.dose == null ? med.doseAmount : null), titrated: true);
  }

  /// The instant of [slot] on [day] before any rule: its anchor resolved, or
  /// its stored time.
  DateTime resolve(MedSlot slot, DateTime day) {
    final anchor = slot.anchor;
    if (anchor != null) {
      if (anchor.base.isPrayer) {
        final p = prayerTime?.call(day, anchor.base);
        if (p != null) return p.add(Duration(minutes: anchor.offsetMinutes));
      } else {
        final meal = settings.mealTime(anchor.base.meal!);
        return wallClock.at(day, meal.minutes + anchor.offsetMinutes);
      }
    }
    return wallClock.at(day, slot.key.minutes);
  }

  /// The daily slots of [med]: its times, else the meal of its "taken with"
  /// slot (empty stomach = before breakfast).
  List<MedSlot> slotsOf(MedSpec med) {
    if (med.slots.isNotEmpty) return med.slots;
    final meal = med.implicitMeal;
    if (meal == null) return const [];
    final offset = med.takenWith == TakenWith.emptyStomach ? -settings.emptyStomachLead : 0;
    final key = ClockHm.fromMinutes(settings.mealTime(meal).minutes + offset);
    return [MedSlot(key, TimeAnchor(AnchorBaseX.ofMeal(meal), offset))];
  }

  /// The doses of [day] before timing rules, sorted by time.
  List<PlannedDose> expandDay(DateTime day) {
    final d = MedDays.dateOnly(day);
    final out = <PlannedDose>[];
    for (final med in meds) {
      if (!med.active) continue;
      final linked = coursesOf(med);
      if (linked.isNotEmpty) {
        final seen = <String>{};
        for (final c in linked) {
          if (!c.active) continue;
          final cd = CourseSchedule.doseOn(c, d);
          if (cd == null) continue;
          var slots = slotsOf(med);
          if (slots.isEmpty) slots = const [MedSlot(courseDefaultTime)];
          final base = doseOn(med, d);
          for (final s in slots) {
            final slot = wallClock.at(d, s.key.minutes);
            if (!seen.add(PlannedDose.doseKey(med.id, slot))) continue;
            final at = resolve(s, d);
            out.add(
              PlannedDose(
                med: med,
                day: d,
                slot: slot,
                baseAt: at,
                at: at,
                dose: cd.dose ?? base?.dose ?? med.dose,
                doseAmount: cd.doseAmount ?? (cd.dose == null ? (base?.amount ?? med.doseAmount) : null),
                source: DoseSource.course,
                courseId: c.id,
                courseDose: cd,
                anchor: s.anchor,
              ),
            );
          }
        }
        continue;
      }
      final dose = doseOn(med, d);
      if (dose == null) continue; // a titration "stop" step
      for (final s in slotsOf(med)) {
        final at = resolve(s, d);
        out.add(
          PlannedDose(
            med: med,
            day: d,
            slot: wallClock.at(d, s.key.minutes),
            baseAt: at,
            at: at,
            dose: dose.dose,
            doseAmount: dose.amount,
            source: dose.titrated ? DoseSource.titration : DoseSource.daily,
            anchor: s.anchor,
          ),
        );
      }
    }
    out.sort(_byTime);
    return out;
  }

  /// The plan of [day]. [taken] maps dose keys to the moment they were taken
  /// (pinned there); [skipped] doses neither move nor constrain others.
  DayPlan planDay(DateTime day, {Map<String, DateTime> taken = const {}, Set<String> skipped = const {}}) =>
      planDays(day, 1, taken: taken, skipped: skipped).single;

  /// Plans [count] consecutive days from [from].
  List<DayPlan> planDays(
    DateTime from,
    int count, {
    Map<String, DateTime> taken = const {},
    Set<String> skipped = const {},
  }) {
    if (count <= 0) return const [];
    final first = MedDays.dateOnly(from);
    final work = <_Work>[];
    for (var i = -1; i <= count; i++) {
      for (final dose in expandDay(MedDays.add(first, i))) {
        final t = taken[dose.key];
        work.add(
          _Work(dose)
            ..at = t ?? dose.at
            ..pinned = t != null
            ..skipped = skipped.contains(dose.key),
        );
      }
    }
    final conflicts = <DoseConflict>[];
    _applyFoodRules(work, conflicts);
    _applySeparation(work);
    _checkSeparation(work, conflicts);

    final plans = <DayPlan>[];
    for (var i = 0; i < count; i++) {
      final day = MedDays.add(first, i);
      final doses = [
        for (final w in work)
          if (MedDays.same(w.dose.day, day)) w.result(),
      ]..sort(_byTime);
      final keys = {for (final d in doses) d.key};
      final seen = <String>{};
      final mine = [
        for (final c in conflicts)
          if ((keys.contains(c.a.key) || (c.b != null && keys.contains(c.b!.key))) && seen.add(c.key)) c,
      ];
      plans.add(DayPlan(day: day, doses: doses, conflicts: mine));
    }
    return plans;
  }

  static int _byTime(PlannedDose a, PlannedDose b) {
    final c = a.at.compareTo(b.at);
    if (c != 0) return c;
    final o = a.med.sortOrder.compareTo(b.med.sortOrder);
    return o != 0 ? o : a.med.id.compareTo(b.med.id);
  }

  // ------------------------------------------------------------ food rules --

  void _applyFoodRules(List<_Work> work, List<DoseConflict> conflicts) {
    final byMed = <String, List<RuleSpec>>{};
    for (final r in rules) {
      if (r.isFood) (byMed[r.medAId] ??= []).add(r);
    }
    if (byMed.isEmpty) return;
    // Per medication and day, doses in time order claim meals.
    final groups = <String, List<_Work>>{};
    for (final w in work) {
      if (!byMed.containsKey(w.dose.medId)) continue;
      (groups['${w.dose.medId}|${MedDays.key(w.dose.day)}'] ??= []).add(w);
    }
    for (final group in groups.values) {
      group.sort((a, b) => a.dose.baseAt.compareTo(b.dose.baseAt));
      final medRules = byMed[group.first.dose.medId]!;
      final rule = medRules.first;
      for (final extra in medRules.skip(1)) {
        if (extra.kind != rule.kind || extra.minutes != rule.minutes) {
          conflicts.add(DoseConflict(kind: DoseConflictKind.ruleClash, rule: extra, a: group.first.result()));
        }
      }
      final used = <MealSlot>{};
      for (final w in group) {
        final meal = _mealFor(w.dose, used);
        if (meal == null) {
          conflicts.add(DoseConflict(kind: DoseConflictKind.noMeal, rule: rule, a: w.result()));
          continue;
        }
        used.add(meal);
        w.meal = meal;
        if (w.pinned || w.skipped) continue; // taken: its real time stands
        final mealAt = wallClock.at(w.dose.day, settings.mealTime(meal).minutes);
        final minutes = switch (rule.kind) {
          MedRuleKind.beforeFood => -rule.minutes.abs(),
          MedRuleKind.afterFood => rule.minutes.abs(),
          _ => 0,
        };
        w.at = mealAt.add(Duration(minutes: minutes));
        w.pinned = true;
        w.ruleIds.add(rule.id);
      }
    }
  }

  MealSlot? _mealFor(PlannedDose dose, Set<MealSlot> used) {
    const meals = [MealSlot.breakfast, MealSlot.lunch, MealSlot.dinner];
    final anchored = dose.anchor?.base.meal;
    if (anchored != null && anchored != MealSlot.bedtime) return used.contains(anchored) ? null : anchored;
    final fixed = switch (dose.med.takenWith) {
      TakenWith.emptyStomach || TakenWith.breakfast => MealSlot.breakfast,
      TakenWith.lunch => MealSlot.lunch,
      TakenWith.dinner => MealSlot.dinner,
      _ => null,
    };
    // A single daily dose follows its slot; several spread over the meals.
    if (fixed != null && !used.contains(fixed)) return fixed;
    MealSlot? best;
    Duration? bestGap;
    for (final m in meals) {
      if (used.contains(m)) continue;
      final gap = wallClock.at(dose.day, settings.mealTime(m).minutes).difference(dose.baseAt).abs();
      if (bestGap == null || gap < bestGap) {
        best = m;
        bestGap = gap;
      }
    }
    return best;
  }

  // ------------------------------------------------------------ separation --

  Iterable<RuleSpec> get _separations => rules.where((r) => r.isSeparation && r.minutes > 0);

  void _applySeparation(List<_Work> work) {
    final seps = _separations.toList();
    if (seps.isEmpty) return;
    final byMed = <String, List<_Work>>{};
    for (final w in work) {
      (byMed[w.dose.medId] ??= []).add(w);
    }
    for (final list in byMed.values) {
      list.sort((a, b) => a.dose.baseAt.compareTo(b.dose.baseAt));
      for (var i = 0; i < list.length; i++) {
        list[i]
          ..prev = i > 0 ? list[i - 1] : null
          ..next = i < list.length - 1 ? list[i + 1] : null;
      }
    }
    for (var pass = 0; pass < _maxPasses; pass++) {
      var changed = false;
      for (final r in seps) {
        final xs = byMed[r.medAId] ?? const <_Work>[];
        final ys = byMed[r.medBId] ?? const <_Work>[];
        for (final x in xs) {
          if (x.skipped) continue;
          for (final y in ys) {
            if (y.skipped) continue;
            // Ties: B yields to A.
            final (first, second) = y.at.isBefore(x.at) ? (y, x) : (x, y);
            final gap = second.at.difference(first.at);
            final need = Duration(minutes: r.minutes) - gap;
            if (need <= Duration.zero) continue;
            if (_canMove(second, need)) {
              second.move(need, r.id);
              changed = true;
            } else if (_canMove(first, -need)) {
              first.move(-need, r.id);
              changed = true;
            }
          }
        }
      }
      if (!changed) break;
    }
  }

  bool _canMove(_Work w, Duration delta) {
    if (w.pinned || w.skipped) return false;
    // A dose moves one way only: two rules pulling it apart can never make
    // it oscillate, and the relaxation always settles.
    if (w.direction != 0 && w.direction != delta.inMicroseconds.sign) return false;
    final to = w.at.add(delta);
    if (to.difference(w.dose.baseAt).abs() > Duration(minutes: settings.maxShift)) return false;
    final prev = w.prev, next = w.next;
    if (prev != null && to.difference(prev.at) < _gapTo(prev, w)) return false;
    if (next != null && next.at.difference(to) < _gapTo(w, next)) return false;
    return true;
  }

  static Duration _gapTo(_Work a, _Work b) {
    final natural = b.dose.baseAt.difference(a.dose.baseAt);
    final half = Duration(microseconds: natural.inMicroseconds ~/ 2);
    const floor = Duration(minutes: sameMedGap);
    return half < floor ? half : floor;
  }

  void _checkSeparation(List<_Work> work, List<DoseConflict> conflicts) {
    for (final r in _separations) {
      final xs = work.where((w) => w.dose.medId == r.medAId && !w.skipped).toList();
      final ys = work.where((w) => w.dose.medId == r.medBId && !w.skipped).toList();
      for (final x in xs) {
        for (final y in ys) {
          final (first, second) = y.at.isBefore(x.at) ? (y, x) : (x, y);
          final gap = second.at.difference(first.at);
          if (gap >= Duration(minutes: r.minutes)) continue;
          conflicts.add(
            DoseConflict(
              kind: DoseConflictKind.separation,
              rule: r,
              a: first.result(),
              b: second.result(),
              requiredMinutes: r.minutes,
              actualMinutes: gap.inMinutes,
            ),
          );
        }
      }
    }
  }
}

class _Work {
  _Work(this.dose) : at = dose.at;

  final PlannedDose dose;
  DateTime at;
  bool pinned = false;
  bool skipped = false;
  MealSlot? meal;
  final List<String> ruleIds = [];
  _Work? prev, next;

  /// +1 once moved later, -1 once moved earlier.
  int direction = 0;

  void move(Duration delta, String ruleId) {
    at = at.add(delta);
    direction = delta.inMicroseconds.sign;
    if (!ruleIds.contains(ruleId)) ruleIds.add(ruleId);
  }

  PlannedDose result() => dose.copyWith(at: at, pinned: pinned, ruleIds: List.unmodifiable(ruleIds), meal: meal);
}
