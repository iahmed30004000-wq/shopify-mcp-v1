/// Meal reminders: which slot of the active plan gets a notification, when,
/// and under which id. Pure logic – no plugin and no clock of its own.
library;

import 'package:meta/meta.dart';

import '../../../core/notifications/notification_models.dart';
import '../../body/domain/body_clock.dart';
import 'meal_plan.dart';

/// Nutrition's block inside the shared `reminders` notification namespace
/// (130000–139999): **139000–139499** (offsets 9000–9499).
///
/// The namespace's blocks in use when this was written, so the choice is
/// free on every side: Goals 132000–132999, Family 136000–136999, Custom
/// Modules 137000–137999, Travel 138000–138999, Body (fasting)
/// 139800–139803. Outside the namespace: the notification centre's snooze
/// ids 160000–160999 and Together 170000–170999. Nutrition therefore sits in
/// the gap below Body's block – next to the planet it lives on and clear of
/// it by 300 ids.
///
/// Syncing only ever touches ids this block [owns], so every other feature's
/// pending reminders survive a re-plan.
abstract final class MealReminderIds {
  static const NotificationNamespace namespace = NotificationNamespaces.reminders;
  static const int firstOffset = 9000;
  static const int size = 500;

  /// How many days ahead meal reminders are planned: a full week, so a slot
  /// that repeats on one weekday only («غدا الجمعة») is always covered even
  /// if the app is not opened for days. Re-planned on every day change.
  static const int days = 7;

  /// Ids per day, so one slot keeps the same id inside a day (71 meals a day
  /// is far beyond any real plan).
  static const int perDay = size ~/ days; // 71

  static int get first => namespace.first + firstOffset;
  static int get last => first + size - 1;

  static bool owns(int id) => id >= first && id <= last;

  /// The id of the [slotIndex]-th reminding slot on day [dayOffset] ahead
  /// (0 = today). Slots are indexed in plan order (earliest meal first), so
  /// re-planning replaces a notification instead of duplicating it.
  static int of(int dayOffset, int slotIndex) {
    if (dayOffset < 0 || dayOffset >= days) throw RangeError.range(dayOffset, 0, days - 1, 'dayOffset');
    if (slotIndex < 0 || slotIndex >= perDay) throw RangeError.range(slotIndex, 0, perDay - 1, 'slotIndex');
    return namespace.id(firstOffset + dayOffset * perDay + slotIndex);
  }
}

/// One planned meal notification (texts come from the scheduler, so the
/// domain stays free of strings).
@immutable
class MealNotice {
  const MealNotice({
    required this.id,
    required this.at,
    required this.slotId,
    required this.slotName,
    required this.timeLabel,
    required this.foods,
  });

  final int id;
  final DateTime at;
  final String slotId;

  /// The slot's name, his own word («فطور»).
  final String slotName;

  /// `"08:00"`.
  final String timeLabel;

  /// The planned foods' names, in plan order (may be empty).
  final List<String> foods;

  @override
  bool operator ==(Object other) =>
      other is MealNotice &&
      other.id == id &&
      other.at == at &&
      other.slotId == slotId &&
      other.slotName == slotName &&
      other.timeLabel == timeLabel &&
      other.foods.length == foods.length &&
      other.foods.join('|') == foods.join('|');

  @override
  int get hashCode => Object.hash(id, at, slotId, slotName, timeLabel, foods.join('|'));

  @override
  String toString() => 'MealNotice#$id($slotName@$at)';
}

/// Plans the meal reminders of the active plan (pure).
abstract final class MealReminderPlanner {
  /// The notifications for the next [days] days from [now] (at most
  /// [MealReminderIds.days], the block's width): every slot of [plan] that
  /// repeats on that weekday **and** has its reminder switched on, skipping
  /// times already past.
  ///
  /// A draft plan plans nothing (only the active plan reminds). The result is
  /// ordered by time, so the scheduler can hand it straight to `sync`.
  static List<MealNotice> plan({
    required MealPlan plan,
    required DateTime now,
    BodyWallClock clock = const LocalBodyWallClock(),
    int days = MealReminderIds.days,
  }) {
    if (plan.isEmpty || !plan.active) return const [];
    final out = <MealNotice>[];
    final today = clock.dayOf(now);
    final span = days.clamp(1, MealReminderIds.days);
    for (var offset = 0; offset < span; offset++) {
      final day = BodyDays.add(today, offset);
      final slots = [
        for (final s in plan.slotsOn(day))
          if (s.remind) s,
      ];
      for (var i = 0; i < slots.length && i < MealReminderIds.perDay; i++) {
        final slot = slots[i];
        final at = slot.timeOn(day, clock: clock);
        if (!at.isAfter(now)) continue;
        out.add(
          MealNotice(
            id: MealReminderIds.of(offset, i),
            at: at,
            slotId: slot.id,
            slotName: slot.name,
            timeLabel: slot.timeLabel,
            foods: [for (final f in slot.foods) f.name],
          ),
        );
      }
    }
    out.sort((a, b) => a.at.compareTo(b.at));
    return out;
  }
}
