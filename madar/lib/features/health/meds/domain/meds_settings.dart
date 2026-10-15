import 'package:flutter/foundation.dart';

import 'med_models.dart';

/// The medication tracker's own settings (`key_values` `meds.settings`).
///
/// Meal times are generic starting values the user edits; they only anchor
/// "with breakfast"-style times and food rules.
@immutable
class MedsSettings {
  const MedsSettings({
    this.meals = defaultMeals,
    this.emptyStomachLead = 30,
    this.lateAfter = 60,
    this.missedAfter = 240,
    this.snoozeMinutes = 10,
    this.notify = true,
    this.maxShift = 240,
  });

  static const Map<MealSlot, ClockHm> defaultMeals = {
    MealSlot.breakfast: ClockHm(8, 0),
    MealSlot.lunch: ClockHm(14, 0),
    MealSlot.dinner: ClockHm(20, 0),
    MealSlot.bedtime: ClockHm(23, 0),
  };

  static const snoozeChoices = [10, 30, 60];

  /// Meal (and bedtime) times.
  final Map<MealSlot, ClockHm> meals;

  /// "On an empty stomach" = this many minutes before breakfast.
  final int emptyStomachLead;

  /// A dose not taken this long after its time is "late".
  final int lateAfter;

  /// …and "missed" after this long (or when the next dose of the same
  /// medication comes due, whichever is first).
  final int missedAfter;

  /// The snooze of a notification's Snooze button.
  final int snoozeMinutes;

  /// Dose reminders on / off.
  final bool notify;

  /// The furthest a timing rule may move a dose from its time.
  final int maxShift;

  ClockHm mealTime(MealSlot slot) => meals[slot] ?? defaultMeals[slot]!;

  MedsSettings copyWith({
    Map<MealSlot, ClockHm>? meals,
    int? emptyStomachLead,
    int? lateAfter,
    int? missedAfter,
    int? snoozeMinutes,
    bool? notify,
    int? maxShift,
  }) => MedsSettings(
    meals: meals ?? this.meals,
    emptyStomachLead: emptyStomachLead ?? this.emptyStomachLead,
    lateAfter: lateAfter ?? this.lateAfter,
    missedAfter: missedAfter ?? this.missedAfter,
    snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
    notify: notify ?? this.notify,
    maxShift: maxShift ?? this.maxShift,
  );

  Map<String, Object?> toJson() => {
    'meals': {for (final e in meals.entries) e.key.name: e.value.hhmm},
    'emptyStomachLead': emptyStomachLead,
    'lateAfter': lateAfter,
    'missedAfter': missedAfter,
    'snoozeMinutes': snoozeMinutes,
    'notify': notify,
    'maxShift': maxShift,
  };

  static MedsSettings fromJson(Object? raw) {
    if (raw is! Map) return const MedsSettings();
    int intOf(String key, int fallback, {int min = 0, int max = 1440}) {
      final v = raw[key];
      return v is num ? v.toInt().clamp(min, max) : fallback;
    }

    final meals = Map<MealSlot, ClockHm>.of(defaultMeals);
    final rawMeals = raw['meals'];
    if (rawMeals is Map) {
      for (final slot in MealSlot.values) {
        final t = ClockHm.tryParse(rawMeals[slot.name]);
        if (t != null) meals[slot] = t;
      }
    }
    const d = MedsSettings();
    return MedsSettings(
      meals: meals,
      emptyStomachLead: intOf('emptyStomachLead', d.emptyStomachLead, max: 240),
      lateAfter: intOf('lateAfter', d.lateAfter, min: 5, max: 720),
      missedAfter: intOf('missedAfter', d.missedAfter, min: 15, max: 1440),
      snoozeMinutes: intOf('snoozeMinutes', d.snoozeMinutes, min: 1, max: 240),
      notify: raw['notify'] is bool ? raw['notify'] as bool : d.notify,
      maxShift: intOf('maxShift', d.maxShift, min: 0, max: 720),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MedsSettings &&
      mapEquals(other.meals, meals) &&
      other.emptyStomachLead == emptyStomachLead &&
      other.lateAfter == lateAfter &&
      other.missedAfter == missedAfter &&
      other.snoozeMinutes == snoozeMinutes &&
      other.notify == notify &&
      other.maxShift == maxShift;

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(meals.entries.map((e) => Object.hash(e.key, e.value))),
    emptyStomachLead,
    lateAfter,
    missedAfter,
    snoozeMinutes,
    notify,
    maxShift,
  );
}
