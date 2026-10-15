/// Planned vs eaten: a pure comparison of one day's meal-plan slots against
/// the food log.
///
/// It describes, it never judges: a slot comes out "eaten on time", "eaten
/// late", "swapped" (he ate something else at that meal), "skipped" or still
/// "pending", with the entries behind each answer. Everything else he ate is
/// listed as unplanned.
library;

import 'package:meta/meta.dart';

import '../../body/domain/body_clock.dart';
import 'food_library.dart';
import 'food_log.dart';
import 'meal_plan.dart';

/// What became of one planned slot on one day.
enum SlotStatus {
  /// Something of the plan was eaten inside the on-time window.
  eatenOnTime,

  /// Something of the plan was eaten, but later than the late window.
  eatenLate,

  /// He ate at that meal, but none of the planned foods.
  swapped,

  /// Nothing was logged for that meal and its window has passed.
  skipped,

  /// The meal is still ahead today (or `now` is before its window closes).
  pending,
}

/// One planned slot on one day, with what answered it.
@immutable
class SlotOutcome {
  const SlotOutcome({
    required this.slot,
    required this.plannedAt,
    required this.status,
    this.entries = const [],
    this.matchedNames = const [],
  });

  final MealSlot slot;

  /// When the slot fell on this day.
  final DateTime plannedAt;
  final SlotStatus status;

  /// The log entries counted against this slot, earliest first.
  final List<FoodEntry> entries;

  /// The planned foods that were actually eaten (their planned names).
  final List<String> matchedNames;

  bool get eaten => status == SlotStatus.eatenOnTime || status == SlotStatus.eatenLate;

  /// The first entry of this slot, or null.
  FoodEntry? get first => entries.isEmpty ? null : entries.first;

  /// How late the first entry was (zero when on time or nothing was eaten).
  Duration get lateBy {
    final f = first;
    if (f == null || !f.at.isAfter(plannedAt)) return Duration.zero;
    return f.at.difference(plannedAt);
  }

  @override
  String toString() => 'SlotOutcome(${slot.name}@$plannedAt → ${status.name}, ${entries.length} entries)';
}

/// One day's planned-vs-eaten picture.
@immutable
class DayPlan {
  const DayPlan({
    required this.day,
    required this.planId,
    this.outcomes = const [],
    this.unplanned = const [],
  });

  /// A day without an active plan: nothing planned, everything unplanned.
  factory DayPlan.unplannedOnly(DateTime day, List<FoodEntry> entries) =>
      DayPlan(day: BodyDays.of(day), planId: '', outcomes: const [], unplanned: entries);

  final DateTime day;

  /// The plan compared against (empty when there is none).
  final String planId;

  /// The day's slots, earliest first.
  final List<SlotOutcome> outcomes;

  /// Entries that answered no slot, earliest first.
  final List<FoodEntry> unplanned;

  bool get hasPlan => planId.isNotEmpty;
  int get planned => outcomes.length;
  int count(SlotStatus status) => outcomes.where((o) => o.status == status).length;
  int get eaten => outcomes.where((o) => o.eaten).length;
  int get onTime => count(SlotStatus.eatenOnTime);
  int get late => count(SlotStatus.eatenLate);
  int get swapped => count(SlotStatus.swapped);
  int get skipped => count(SlotStatus.skipped);
  int get pending => count(SlotStatus.pending);

  /// Slots already settled (not pending).
  int get settled => planned - pending;

  /// Share of settled slots that were eaten (on time or late), 0‥1, or null
  /// when nothing is settled yet – the UI shows «ما بعد» instead of 0%.
  double? get adherence => settled == 0 ? null : eaten / settled;

  /// The next slot still ahead, or null.
  SlotOutcome? get next => outcomes.where((o) => o.status == SlotStatus.pending).firstOrNull;

  @override
  String toString() =>
      'DayPlan(${BodyDays.key(day)}: $onTime on time, $late late, $swapped swapped, $skipped skipped, '
      '$pending pending, ${unplanned.length} unplanned)';
}

/// The pure planned-vs-eaten comparison.
///
/// How an entry is counted against a slot:
/// 1. an entry whose `slotId` names the slot always counts for it (the user
///    said so himself);
/// 2. otherwise an entry counts for the nearest slot whose window it falls
///    in – from [graceBeforeMinutes] before the slot's time to
///    [graceAfterMinutes] after it. Each entry answers at most one slot;
/// 3. entries left over are [DayPlan.unplanned].
///
/// The status of a slot:
/// * **eatenOnTime** – at least one counted entry matches a planned food
///   (same food id, or the same name after Arabic folding) and the first
///   counted entry is no more than [lateAfterMinutes] after the slot's time;
/// * **eatenLate** – the same, but the first counted entry is later than
///   that;
/// * **swapped** – entries were counted but none matches a planned food;
///   also when the slot has no planned foods at all and he ate at its time;
/// * **skipped** – nothing counted and [now] is past the slot's window;
/// * **pending** – nothing counted and the window is still open.
abstract final class PlanCompare {
  /// How long before a slot's time an entry still belongs to it.
  static const int graceBeforeMinutes = 90;

  /// How long after a slot's time an entry still belongs to it.
  static const int graceAfterMinutes = 180;

  /// Later than this after the slot's time counts as late.
  static const int lateAfterMinutes = 60;

  /// Compares [plan]'s slots on local calendar [day] against [entries] (the
  /// whole log; only that day's entries are looked at).
  ///
  /// [now] decides pending vs skipped – pass the app clock's value. With no
  /// plan (or a plan with no slot on that day) the result holds no outcomes
  /// and every entry is unplanned.
  static DayPlan compare({
    required MealPlan plan,
    required Iterable<FoodEntry> entries,
    required DateTime day,
    required DateTime now,
    BodyWallClock clock = const LocalBodyWallClock(),
    int graceBefore = graceBeforeMinutes,
    int graceAfter = graceAfterMinutes,
    int lateAfter = lateAfterMinutes,
  }) {
    final theDay = BodyDays.of(day);
    final dayEntries = FoodLogStats.onDay(entries, theDay, clock: clock);
    final slots = plan.isEmpty ? const <MealSlot>[] : plan.slotsOn(theDay);
    if (slots.isEmpty) return DayPlan.unplannedOnly(theDay, dayEntries);

    final times = {for (final s in slots) s.id: s.timeOn(theDay, clock: clock)};
    final taken = <String, List<FoodEntry>>{for (final s in slots) s.id: []};
    final leftOver = <FoodEntry>[];

    for (final entry in dayEntries) {
      final named = entry.slotId;
      if (named != null && taken.containsKey(named)) {
        taken[named]!.add(entry);
        continue;
      }
      if (named != null) {
        // The entry names a slot of another day or another plan.
        leftOver.add(entry);
        continue;
      }
      MealSlot? best;
      var bestDistance = 0;
      for (final slot in slots) {
        final at = times[slot.id]!;
        final diff = entry.at.difference(at).inMinutes;
        if (diff < -graceBefore || diff > graceAfter) continue;
        final distance = diff.abs();
        if (best == null || distance < bestDistance) {
          best = slot;
          bestDistance = distance;
        }
      }
      if (best == null) {
        leftOver.add(entry);
      } else {
        taken[best.id]!.add(entry);
      }
    }

    final outcomes = <SlotOutcome>[];
    for (final slot in slots) {
      final at = times[slot.id]!;
      final mine = taken[slot.id]!..sort((a, b) => a.at.compareTo(b.at));
      if (mine.isEmpty) {
        final closes = at.add(Duration(minutes: graceAfter));
        outcomes.add(
          SlotOutcome(
            slot: slot,
            plannedAt: at,
            status: now.isAfter(closes) ? SlotStatus.skipped : SlotStatus.pending,
          ),
        );
        continue;
      }
      final matched = <String>[];
      for (final planned in slot.foods) {
        final hit = mine.any(
          (e) =>
              (planned.foodId != null && e.foodId == planned.foodId) ||
              FoodLookup.sameWord(planned.name, e.name),
        );
        if (hit) matched.add(planned.name);
      }
      final SlotStatus status;
      if (matched.isEmpty) {
        status = SlotStatus.swapped;
      } else {
        status = mine.first.at.difference(at).inMinutes > lateAfter ? SlotStatus.eatenLate : SlotStatus.eatenOnTime;
      }
      outcomes.add(SlotOutcome(slot: slot, plannedAt: at, status: status, entries: mine, matchedNames: matched));
    }
    outcomes.sort((a, b) => a.plannedAt.compareTo(b.plannedAt));
    leftOver.sort((a, b) => a.at.compareTo(b.at));
    return DayPlan(day: theDay, planId: plan.id, outcomes: outcomes, unplanned: leftOver);
  }

  /// [compare] over the [days] days ending on [today], oldest first – the
  /// week strip and the adherence number of `NutritionSummary`.
  static List<DayPlan> lastDays({
    required MealPlan plan,
    required Iterable<FoodEntry> entries,
    required DateTime today,
    required DateTime now,
    int days = 7,
    BodyWallClock clock = const LocalBodyWallClock(),
  }) {
    final out = <DayPlan>[];
    for (var i = days - 1; i >= 0; i--) {
      final day = BodyDays.add(BodyDays.of(today), -i);
      out.add(compare(plan: plan, entries: entries, day: day, now: now, clock: clock));
    }
    return out;
  }
}
