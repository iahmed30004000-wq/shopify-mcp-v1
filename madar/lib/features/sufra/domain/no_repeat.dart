/// «بدون تكرار»: never the same dish twice inside the window she sets.
///
/// Pure Dart (no Flutter, no database). The window reads a **real cooked
/// log** (`cooked_meals`), not a guess from what Madar suggested: a dish is
/// held back because she actually cooked it, and she can always override –
/// which is recorded too, so the history stays honest.
library;

import 'package:meta/meta.dart';

/// One dish actually cooked (a plain copy of a `cooked_meals` row).
@immutable
class CookedMeal {
  const CookedMeal({
    required this.id,
    required this.name,
    required this.day,
    this.recipeId,
    this.servings,
    this.overrode = false,
    this.note,
  });

  final String id;

  /// The recipe, or null for something she cooked without one.
  final String? recipeId;

  /// The dish's name on the day she cooked it.
  final String name;

  /// The calendar day.
  final DateTime day;
  final int? servings;

  /// She chose it although the window held it back.
  final bool overrode;
  final String? note;

  @override
  String toString() => 'CookedMeal($name, ${day.year}-${day.month}-${day.day})';
}

/// Why a dish is held back, or that it is not.
@immutable
class RepeatHold {
  const RepeatHold._({required this.held, this.lastCooked, this.daysAgo, this.freeFrom});

  /// Not held: she has not cooked it inside the window.
  static const RepeatHold free = RepeatHold._(held: false);

  final bool held;

  /// The day she last cooked it (null when never).
  final DateTime? lastCooked;

  /// How many days ago that was (0 = today).
  final int? daysAgo;

  /// The first day it is free again (the day after the window passes).
  final DateTime? freeFrom;

  @override
  String toString() => held ? 'RepeatHold(held, $daysAgo days ago)' : 'RepeatHold(free)';
}

/// The window and the question it answers.
abstract final class NoRepeat {
  /// The window Madar starts with until she changes it: two weeks, which is
  /// what the owner's own example asked for («مش بآخر أسبوعين»).
  static const int defaultWindowDays = 14;

  /// Her choices on the settings screen, in days. `0` turns the rule off.
  static const List<int> windowChoices = [0, 3, 7, 14, 21, 30];

  static const int maxWindowDays = 365;

  /// The window in days, clamped to something sane. `0` means she turned
  /// the rule off, and then nothing is ever held back.
  static int window(int? days) {
    if (days == null) return defaultWindowDays;
    if (days <= 0) return 0;
    return days > maxWindowDays ? maxWindowDays : days;
  }

  /// Whether [recipeId] is held back on [today], given her cooked log.
  ///
  /// A dish cooked **exactly** [windowDays] days ago is still held (a
  /// 14-day window covers the fourteen days behind today, today included);
  /// one cooked `windowDays + 1` days ago is free. A window of 0 never
  /// holds anything.
  static RepeatHold check(
    Iterable<CookedMeal> log, {
    required String recipeId,
    required DateTime today,
    int? windowDays,
  }) {
    final days = window(windowDays);
    final day = DateTime(today.year, today.month, today.day);
    DateTime? last;
    for (final meal in log) {
      if (meal.recipeId != recipeId) continue;
      final cooked = DateTime(meal.day.year, meal.day.month, meal.day.day);
      if (cooked.isAfter(day)) continue; // a day in the future is not history
      if (last == null || cooked.isAfter(last)) last = cooked;
    }
    if (last == null) return RepeatHold.free;
    final ago = day.difference(last).inDays;
    if (days == 0 || ago >= days) {
      return RepeatHold._(held: false, lastCooked: last, daysAgo: ago);
    }
    return RepeatHold._(
      held: true,
      lastCooked: last,
      daysAgo: ago,
      freeFrom: last.add(Duration(days: days)),
    );
  }

  /// [check] for every dish at once, keyed by recipe id – one pass over the
  /// log instead of one per dish.
  static Map<String, RepeatHold> checkAll(
    Iterable<CookedMeal> log, {
    required Iterable<String> recipeIds,
    required DateTime today,
    int? windowDays,
  }) {
    final day = DateTime(today.year, today.month, today.day);
    final last = <String, DateTime>{};
    for (final meal in log) {
      final id = meal.recipeId;
      if (id == null) continue;
      final cooked = DateTime(meal.day.year, meal.day.month, meal.day.day);
      if (cooked.isAfter(day)) continue;
      final seen = last[id];
      if (seen == null || cooked.isAfter(seen)) last[id] = cooked;
    }
    final days = window(windowDays);
    return {
      for (final id in recipeIds)
        id: last[id] == null
            ? RepeatHold.free
            : () {
                final ago = day.difference(last[id]!).inDays;
                return days == 0 || ago >= days
                    ? RepeatHold._(held: false, lastCooked: last[id], daysAgo: ago)
                    : RepeatHold._(
                        held: true,
                        lastCooked: last[id],
                        daysAgo: ago,
                        freeFrom: last[id]!.add(Duration(days: days)),
                      );
              }(),
    };
  }

  /// How many times each dish was cooked, keyed by recipe id (what the
  /// history screen counts).
  static Map<String, int> counts(Iterable<CookedMeal> log) {
    final out = <String, int>{};
    for (final meal in log) {
      final id = meal.recipeId;
      if (id == null) continue;
      out[id] = (out[id] ?? 0) + 1;
    }
    return out;
  }
}
