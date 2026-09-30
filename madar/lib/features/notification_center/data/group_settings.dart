import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/enums.dart' show PrayerWindow;
import '../../adhan/application/adhan_providers.dart' show adhanSettingsProvider;
import '../../adhan/domain/adhan_slot.dart' show AdhanSlot;
import '../../adhkar/data/adhkar_providers.dart' show adhkarReminderSettingsProvider;
import '../../body/data/body_providers.dart' show bodyFastingPlanProvider;
import '../../custom_modules/data/custom_modules_providers.dart' show customAllRemindersProvider;
import '../../family/data/family_providers.dart' show familySettingsProvider;
import '../../health/meds/data/meds_providers.dart' show medsSettingsProvider;
import '../../health/record/data/record_providers.dart' show recordSettingsProvider;
import '../../health/wellbeing/data/wellbeing_providers.dart' show wellbeingSettingsProvider;
import '../../money/goals/data/goals_providers.dart' show goalsReminderSettingsProvider;
import '../../wird/data/wird_providers.dart' show wirdPlansProvider;
import '../domain/center_models.dart';

/// A group's own reminder switches, as its features expose them (read-only;
/// the switches stay in each feature's settings).
@immutable
class GroupReminderSettings {
  const GroupReminderSettings({required this.group, this.on = 0, this.total = 0, this.hasToggle = true});

  /// No switch to read: the group's reminders are set per item (a travel
  /// document's reminder days) or it has no settings (other).
  const GroupReminderSettings.perItem(this.group) : on = 0, total = 0, hasToggle = false;

  final NotificationGroup group;

  /// Switches on / switches there are (e.g. 4 of 6 prayer alerts).
  final int on;
  final int total;

  /// The feature exposes on/off settings for this group.
  final bool hasToggle;

  bool get enabled => on > 0;
  bool get allOn => total > 0 && on >= total;

  @override
  bool operator ==(Object other) =>
      other is GroupReminderSettings &&
      other.group == group &&
      other.on == on &&
      other.total == total &&
      other.hasToggle == hasToggle;

  @override
  int get hashCode => Object.hash(group, on, total, hasToggle);

  @override
  String toString() => 'GroupReminderSettings(${group.name}: ${hasToggle ? '$on/$total' : 'per item'})';
}

/// Every group's switches, read from each feature's own settings where it
/// exposes them:
///
/// | group          | read from                                             |
/// |----------------|-------------------------------------------------------|
/// | prayer         | adhan settings: each prayer's adhan / reminder + sunrise (6) |
/// | adhkar         | adhkar reminders: morning, evening (2)                |
/// | medications    | meds settings: dose reminders (1)                     |
/// | health         | record: appointment reminders; wellbeing: worry window reminder; body: fasting notifications (3) |
/// | money          | goals: due reminders (1)                              |
/// | family         | family settings: digest, birthdays (2)                |
/// | wird           | each remindable plan's reminder                       |
/// | customModules  | each module reminder row (enabled)                    |
/// | travel         | **no exposed toggle** – per document (reminder days)  |
/// | other          | **no settings**                                       |
///
/// A feature whose settings are not available (no database yet, a test)
/// reads as all off.
final notificationGroupSettingsProvider = Provider<Map<NotificationGroup, GroupReminderSettings>>((ref) {
  T? read<T>(T? Function() f) {
    try {
      return f();
    } catch (_) {
      return null;
    }
  }

  int b(bool? v) => v == true ? 1 : 0;

  final adhan = read(() => ref.watch(adhanSettingsProvider).value);
  final adhkar = read(() => ref.watch(adhkarReminderSettingsProvider).value);
  final meds = read(() => ref.watch(medsSettingsProvider).value);
  final record = read(() => ref.watch(recordSettingsProvider).value);
  final wellbeing = read(() => ref.watch(wellbeingSettingsProvider).value);
  final fasting = read(() => ref.watch(bodyFastingPlanProvider).value);
  final goals = read(() => ref.watch(goalsReminderSettingsProvider).value);
  final family = read(() => ref.watch(familySettingsProvider).value);
  final plans = read(() => ref.watch(wirdPlansProvider).value) ?? const [];
  final modules = read(() => ref.watch(customAllRemindersProvider).value) ?? const [];

  final prayerOn = adhan == null
      ? 0
      : AdhanSlot.prayers.where((s) => adhan.alertOf(s).adhan || adhan.alertOf(s).hasReminder).length +
            b(adhan.sunriseAlert);
  final remindable = [
    for (final p in plans)
      if (p.active && p.window != null && p.window != PrayerWindow.anytime) p,
  ];
  return {
    NotificationGroup.prayer: GroupReminderSettings(group: NotificationGroup.prayer, on: prayerOn, total: 6),
    NotificationGroup.adhkar: GroupReminderSettings(
      group: NotificationGroup.adhkar,
      on: b(adhkar?.morning) + b(adhkar?.evening),
      total: 2,
    ),
    NotificationGroup.medications: GroupReminderSettings(
      group: NotificationGroup.medications,
      on: b(meds?.notify),
      total: 1,
    ),
    NotificationGroup.health: GroupReminderSettings(
      group: NotificationGroup.health,
      on:
          b(record?.remindersEnabled) +
          b(wellbeing != null && wellbeing.worry.enabled && wellbeing.worry.remind) +
          b(fasting != null && (fasting.notifyGoal || fasting.notifyEatingClose)),
      total: 3,
    ),
    NotificationGroup.money: GroupReminderSettings(group: NotificationGroup.money, on: b(goals?.enabled), total: 1),
    NotificationGroup.family: GroupReminderSettings(
      group: NotificationGroup.family,
      on: b(family?.digestEnabled) + b(family?.birthdaysEnabled),
      total: 2,
    ),
    NotificationGroup.travel: const GroupReminderSettings.perItem(NotificationGroup.travel),
    NotificationGroup.wird: GroupReminderSettings(
      group: NotificationGroup.wird,
      on: remindable.where((p) => p.meta.remind).length,
      total: remindable.length,
    ),
    NotificationGroup.customModules: GroupReminderSettings(
      group: NotificationGroup.customModules,
      on: modules.where((r) => r.enabled).length,
      total: modules.length,
    ),
    NotificationGroup.other: const GroupReminderSettings.perItem(NotificationGroup.other),
  };
});
