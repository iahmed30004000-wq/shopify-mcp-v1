/// The meal plan: named slots with a time of day that repeat by weekday,
/// each holding the foods he planned to eat.
///
/// Pure Dart. A plan is either active or a draft; nothing here is a
/// prescription, only what the user wrote down for himself.
library;

import 'package:meta/meta.dart';

import '../../body/domain/body_clock.dart';

/// A food planned inside one slot (a library food or free text).
@immutable
class PlannedFood {
  const PlannedFood({required this.id, required this.name, this.foodId, this.portion, this.unit});

  final String id;
  final String? foodId;
  final String name;
  final double? portion;
  final String? unit;

  @override
  String toString() => 'PlannedFood($name)';
}

/// One meal of a plan: «٨:٠٠ فطور» with its planned foods.
@immutable
class MealSlot {
  const MealSlot({
    required this.id,
    required this.planId,
    required this.name,
    required this.timeMinutes,
    this.weekdays = const [],
    this.remind = false,
    this.notes,
    this.foods = const [],
    this.sortOrder = 0,
  });

  final String id;
  final String planId;
  final String name;

  /// Minutes after local midnight (08:00 → 480).
  final int timeMinutes;

  /// `DateTime.weekday` values (1 = Monday … 7 = Sunday). Empty: every day.
  final List<int> weekdays;

  /// Whether this slot has its own reminder switched on.
  final bool remind;
  final String? notes;
  final List<PlannedFood> foods;
  final int sortOrder;

  /// `"08:00"` (always Western digits; the UI localises them).
  String get timeLabel => BodyTimes.format(timeMinutes);

  /// Whether the slot repeats on the weekday of [day].
  bool onDay(DateTime day) => weekdays.isEmpty || weekdays.contains(day.weekday);

  /// The instant this slot falls on, on local calendar [day].
  DateTime timeOn(DateTime day, {BodyWallClock clock = const LocalBodyWallClock()}) =>
      clock.at(BodyDays.of(day), timeMinutes);

  @override
  String toString() => 'MealSlot($name @$timeLabel, days ${weekdays.isEmpty ? 'all' : weekdays.join(',')})';
}

/// A whole plan with its slots.
@immutable
class MealPlan {
  const MealPlan({required this.id, required this.name, this.notes, this.active = false, this.slots = const []});

  /// The plan shown when the user has none (so the UI never holds a null).
  static const MealPlan none = MealPlan(id: '', name: '');

  final String id;
  final String name;
  final String? notes;

  /// Active (the plan today is compared against) or a draft.
  final bool active;

  /// The plan's slots (any order; [ordered] and [slotsOn] sort them).
  final List<MealSlot> slots;

  bool get isEmpty => id.isEmpty;

  /// The slots that fall on local calendar [day], earliest first (ties keep
  /// the user's own order).
  List<MealSlot> slotsOn(DateTime day) {
    final out = [
      for (final s in slots)
        if (s.onDay(day)) s,
    ]..sort(byTime);
    return out;
  }

  /// Every slot, earliest in the day first.
  List<MealSlot> get ordered => slots.toList()..sort(byTime);

  /// How many slots the plan has per weekday (1 = Monday … 7 = Sunday).
  Map<int, int> get slotsPerWeekday => {
    for (var w = 1; w <= 7; w++)
      w: slots.where((s) => s.weekdays.isEmpty || s.weekdays.contains(w)).length,
  };

  /// Slots with their reminder switched on, earliest first.
  List<MealSlot> get reminding => [
    for (final s in ordered)
      if (s.remind) s,
  ];

  static int byTime(MealSlot a, MealSlot b) {
    final byMinute = a.timeMinutes.compareTo(b.timeMinutes);
    if (byMinute != 0) return byMinute;
    final byOrder = a.sortOrder.compareTo(b.sortOrder);
    return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
  }

  /// The active plan of [plans], or [none].
  static MealPlan activeOf(Iterable<MealPlan> plans) =>
      plans.where((p) => p.active).firstOrNull ?? none;

  @override
  String toString() => 'MealPlan($name, ${slots.length} slots${active ? ', active' : ', draft'})';
}
