import 'package:flutter/material.dart';

import '../../../core/interaction/actions.dart' show ActionTone;
import '../../../core/notifications/notification_models.dart' show NotificationNamespaces;
import '../../adhan/domain/adhan_event.dart' show AdhanActions, AdhanEvent;
import '../../adhan/domain/adhan_slot.dart' show AdhanKind, AdhanSlot;
import '../../adhkar/data/adhkar_notifications.dart' show AdhkarReminderTaps;
import '../../adhkar/domain/adhkar_models.dart' show AdhkarCategoryId;
import '../../body/data/body_reminders.dart' show BodyReminderTaps;
import '../../body/domain/body_reminder_plan.dart' show BodyNoticeKind;
import '../../custom_modules/domain/module_reminders.dart' show CustomModuleNotificationTaps;
import '../../family/domain/family_reminders.dart' show FamilyNoticeKind, FamilyNotificationTaps;
import '../../health/meds/data/meds_notifications.dart' show MedsNotificationTaps;
import '../../health/record/data/appointment_reminders.dart' show AppointmentReminderTaps;
import '../../health/wellbeing/data/worry_reminders.dart' show WorryReminderTaps;
import '../../money/goals/data/goals_notifications.dart' show GoalsReminderTaps;
import '../../money/goals/domain/due_reminders.dart' show DueReminderKind;
import '../../travel/data/travel_notifications.dart' show TravelReminderTaps;
import '../../travel/domain/document_reminders.dart' show DocumentReminderKind;
import '../../wird/data/wird_notifications.dart' show WirdReminderTaps;
import 'center_models.dart';
import 'center_texts.dart';
import 'describers.dart';

/// Describers for every notification Madar posts today, one per feature,
/// reading the feature's own payload helpers (the same ones its tap routing
/// uses) – so a payload change in a feature shows up here as a failing
/// describer test, not a silently mislabelled row.
///
/// | namespace  | ids            | describer           | group            |
/// |------------|----------------|---------------------|------------------|
/// | adhan      | 100000–101999  | [AdhanDescriber]    | prayer           |
/// | adhkar     | 110000–111999  | [AdhkarDescriber]   | adhkar           |
/// | meds       | 120000–129999  | [MedsDescriber]     | medications      |
/// | reminders  | 132xxx goals   | [MoneyDueDescriber] | money            |
/// |            | 136xxx family  | [FamilyDescriber]   | family           |
/// |            | 137xxx modules | [CustomModuleDescriber] | customModules |
/// |            | 138xxx travel  | [TravelDescriber]   | travel           |
/// |            | 1398xx body    | [FastingDescriber]  | health           |
/// | wird       | 140000–140999  | [WirdDescriber]     | wird             |
/// | health     | 150000–150399 appointments, 1509xx worry | [HealthDescriber] | health |
List<NotificationDescriber> builtInDescribers() => const [
  AdhanDescriber(),
  AdhkarDescriber(),
  MedsDescriber(),
  HealthDescriber(),
  FastingDescriber(),
  MoneyDueDescriber(),
  FamilyDescriber(),
  TravelDescriber(),
  CustomModuleDescriber(),
  WirdDescriber(),
];

String _prayer(AdhanSlot s, CenterTexts t) => switch (s) {
  AdhanSlot.fajr => t.l.prayerFajr,
  AdhanSlot.sunrise => t.l.prayerSunrise,
  AdhanSlot.dhuhr => t.l.prayerDhuhr,
  AdhanSlot.asr => t.l.prayerAsr,
  AdhanSlot.maghrib => t.l.prayerMaghrib,
  AdhanSlot.isha => t.l.prayerIsha,
};

/// The adhan, its reminders, the sunrise alert, the test and snoozed
/// reminders – titled in the current language from the payload (prayer,
/// kind, prayer time). A sounding adhan offers Stop.
class AdhanDescriber extends NotificationDescriber {
  const AdhanDescriber();

  @override
  String get id => 'adhan';

  @override
  NotificationGroup? groupOf(CenterNotice n) =>
      n.namespace == NotificationNamespaces.adhan.name ? NotificationGroup.prayer : null;

  @override
  NotificationDescription describe(CenterNotice n, CenterTexts t) {
    final e = AdhanEvent.fromTap(n.toTap());
    if (e == null) return NotificationDescriberRegistry.fallbackDescription(n, t, group: NotificationGroup.prayer);
    final l = t.l;
    final prayer = _prayer(e.slot, t);
    final at = l.ncAtTime(t.time(e.prayerAt));
    final stop = CenterActionSpec(
      id: AdhanActions.stop,
      label: l.ncActionStop,
      icon: Icons.stop_circle_rounded,
      tone: ActionTone.danger,
      primary: true,
      liveOnly: true,
    );
    return switch (e.kind) {
      AdhanKind.adhan => NotificationDescription(
        group: NotificationGroup.prayer,
        kind: l.ncKindAdhan(prayer),
        title: l.ncKindAdhan(prayer),
        body: at,
        icon: Icons.mosque_rounded,
        actions: [stop],
        snoozable: false,
        subject: 'prayer:${e.slot.name}',
      ),
      AdhanKind.test => NotificationDescription(
        group: NotificationGroup.prayer,
        kind: l.ncKindAdhanTest,
        title: l.ncKindAdhanTest,
        body: prayer,
        icon: Icons.mosque_outlined,
        actions: [stop],
        snoozable: false,
      ),
      AdhanKind.preAdhan || AdhanKind.snooze => NotificationDescription(
        group: NotificationGroup.prayer,
        kind: l.ncKindPreAdhanShort(prayer),
        title: e.minutesBefore > 0
            ? l.ncKindPreAdhan(prayer, t.duration(Duration(minutes: e.minutesBefore)))
            : l.ncKindPreAdhanShort(prayer),
        body: at,
        icon: Icons.notifications_active_rounded,
        snoozable: false,
        subject: 'prayer:${e.slot.name}',
      ),
      AdhanKind.sunrise => NotificationDescription(
        group: NotificationGroup.prayer,
        kind: l.ncKindSunrise,
        title: l.ncKindSunrise,
        body: at,
        icon: Icons.wb_twilight_rounded,
        snoozable: false,
        subject: 'prayer:sunrise',
      ),
    };
  }
}

/// The morning / evening adhkar reminders (the set from the payload).
class AdhkarDescriber extends NotificationDescriber {
  const AdhkarDescriber();

  @override
  String get id => 'adhkar';

  @override
  NotificationGroup? groupOf(CenterNotice n) =>
      n.namespace == NotificationNamespaces.adhkar.name ? NotificationGroup.adhkar : null;

  @override
  NotificationDescription describe(CenterNotice n, CenterTexts t) {
    final set = AdhkarReminderTaps.categoryOf(n.toTap());
    final l = t.l;
    final (String title, IconData icon) = switch (set) {
      AdhkarCategoryId.morning => (l.ncKindAdhkarMorning, Icons.wb_sunny_rounded),
      AdhkarCategoryId.evening => (l.ncKindAdhkarEvening, Icons.nights_stay_rounded),
      _ => (l.ncKindAdhkar, Icons.auto_awesome_rounded),
    };
    return NotificationDescription(
      group: NotificationGroup.adhkar,
      kind: title,
      title: title,
      body: n.body,
      icon: icon,
      subject: set == null ? null : 'adhkar:${set.name}',
    );
  }
}

/// Dose reminders (with Taken / Snooze / Skip, answered through the
/// medication tracker's own recorder), refill alerts and the "answer not
/// recorded" notice.
class MedsDescriber extends NotificationDescriber {
  const MedsDescriber();

  @override
  String get id => 'meds';

  @override
  NotificationGroup? groupOf(CenterNotice n) =>
      n.namespace == NotificationNamespaces.meds.name ? NotificationGroup.medications : null;

  @override
  NotificationDescription describe(CenterNotice n, CenterTexts t) {
    final l = t.l;
    final tap = n.toTap();
    final med = MedsNotificationTaps.medOf(tap);
    final subject = med == null ? null : 'meds:$med';
    switch (n.data['k']) {
      case MedsNotificationTaps.kDose:
        final answerable = MedsNotificationTaps.doseOf(tap) != null;
        return NotificationDescription(
          group: NotificationGroup.medications,
          kind: l.ncKindDose,
          title: n.title ?? l.ncKindDose,
          body: n.body,
          icon: Icons.medication_rounded,
          snoozable: false,
          subject: subject,
          actions: [
            if (answerable) ...[
              CenterActionSpec(
                id: MedsNotificationTaps.actionTaken,
                label: l.ncActionTaken,
                icon: Icons.check_rounded,
                tone: ActionTone.success,
                primary: true,
                whenUpcoming: true,
              ),
              CenterActionSpec(id: MedsNotificationTaps.actionSnooze, label: l.ncActionSnooze, icon: Icons.snooze_rounded),
              CenterActionSpec(
                id: MedsNotificationTaps.actionSkip,
                label: l.ncActionSkip,
                icon: Icons.redo_rounded,
                tone: ActionTone.neutral,
                whenUpcoming: true,
              ),
            ],
          ],
        );
      case MedsNotificationTaps.kRefill:
        return NotificationDescription(
          group: NotificationGroup.medications,
          kind: l.ncKindRefill,
          title: n.title ?? l.ncKindRefill,
          body: n.body,
          icon: Icons.medication_liquid_rounded,
          subject: subject,
        );
      case MedsNotificationTaps.kNotice:
        return NotificationDescription(
          group: NotificationGroup.medications,
          kind: l.ncKindMedsNotice,
          title: n.title ?? l.ncKindMedsNotice,
          body: n.body,
          icon: Icons.error_outline_rounded,
          snoozable: false,
          subject: subject,
        );
    }
    return NotificationDescriberRegistry.fallbackDescription(n, t, group: NotificationGroup.medications);
  }
}

/// The health namespace: appointment reminders and the worry window.
class HealthDescriber extends NotificationDescriber {
  const HealthDescriber();

  @override
  String get id => 'health';

  @override
  NotificationGroup? groupOf(CenterNotice n) =>
      n.namespace == NotificationNamespaces.health.name ? NotificationGroup.health : null;

  @override
  NotificationDescription describe(CenterNotice n, CenterTexts t) {
    final l = t.l;
    final tap = n.toTap();
    final appointment = AppointmentReminderTaps.appointmentOf(tap);
    if (appointment != null) {
      return NotificationDescription(
        group: NotificationGroup.health,
        kind: l.ncKindAppointment,
        title: n.title ?? l.ncKindAppointment,
        body: n.body,
        icon: Icons.event_available_rounded,
        subject: 'appointment:$appointment',
      );
    }
    if (WorryReminderTaps.matches(tap)) {
      return NotificationDescription(
        group: NotificationGroup.health,
        kind: l.ncKindWorry,
        title: n.title ?? l.ncKindWorry,
        body: n.body,
        icon: Icons.self_improvement_rounded,
        subject: 'worryWindow',
      );
    }
    return NotificationDescriberRegistry.fallbackDescription(n, t, group: NotificationGroup.health);
  }
}

/// The fasting notifications of Body (goal reached, eating window closing)
/// – listed with Health.
class FastingDescriber extends NotificationDescriber {
  const FastingDescriber();

  @override
  String get id => 'body.fasting';

  @override
  NotificationGroup? groupOf(CenterNotice n) => BodyReminderTaps.matches(n.toTap()) ? NotificationGroup.health : null;

  @override
  NotificationDescription describe(CenterNotice n, CenterTexts t) {
    final l = t.l;
    final eating = n.data['notice'] == BodyNoticeKind.eatingClose.name;
    final kind = eating ? l.ncKindEatingClose : l.ncKindFastGoal;
    return NotificationDescription(
      group: NotificationGroup.health,
      kind: kind,
      title: n.title ?? kind,
      body: n.body,
      icon: eating ? Icons.restaurant_rounded : Icons.timer_rounded,
      subject: 'fasting',
    );
  }
}

/// Debt and obligation due reminders.
class MoneyDueDescriber extends NotificationDescriber {
  const MoneyDueDescriber();

  @override
  String get id => 'money.due';

  @override
  NotificationGroup? groupOf(CenterNotice n) =>
      GoalsReminderTaps.targetOf(n.toTap()) != null ? NotificationGroup.money : null;

  @override
  NotificationDescription describe(CenterNotice n, CenterTexts t) {
    final l = t.l;
    final target = GoalsReminderTaps.targetOf(n.toTap())!;
    final debt = target.kind == DueReminderKind.debt;
    final kind = debt ? l.ncKindDebt : l.ncKindObligation;
    return NotificationDescription(
      group: NotificationGroup.money,
      kind: kind,
      title: n.title ?? kind,
      body: n.body,
      icon: debt ? Icons.handshake_rounded : Icons.receipt_long_rounded,
      subject: '${target.kind.name}:${target.id}',
    );
  }
}

/// Family's "keep in touch" digest and birthday reminders.
class FamilyDescriber extends NotificationDescriber {
  const FamilyDescriber();

  @override
  String get id => 'family';

  @override
  NotificationGroup? groupOf(CenterNotice n) =>
      FamilyNotificationTaps.isFamily(n.toTap()) ? NotificationGroup.family : null;

  @override
  NotificationDescription describe(CenterNotice n, CenterTexts t) {
    final l = t.l;
    final tap = n.toTap();
    final kind = FamilyNotificationTaps.kindOf(tap);
    final person = FamilyNotificationTaps.personOf(tap);
    final (String label, IconData icon) = switch (kind) {
      FamilyNoticeKind.birthdayEve => (l.ncKindBirthdayEve, Icons.cake_outlined),
      FamilyNoticeKind.birthday => (l.ncKindBirthday, Icons.cake_rounded),
      _ => (l.ncKindFamilyDigest, Icons.favorite_rounded),
    };
    return NotificationDescription(
      group: NotificationGroup.family,
      kind: label,
      title: n.title ?? label,
      body: n.body,
      icon: icon,
      subject: person == null ? 'family' : 'person:$person',
    );
  }
}

/// Travel documents about to expire (ahead of time, and on the day).
class TravelDescriber extends NotificationDescriber {
  const TravelDescriber();

  @override
  String get id => 'travel';

  @override
  NotificationGroup? groupOf(CenterNotice n) =>
      TravelReminderTaps.documentOf(n.toTap()) != null ? NotificationGroup.travel : null;

  @override
  NotificationDescription describe(CenterNotice n, CenterTexts t) {
    final l = t.l;
    final doc = TravelReminderTaps.documentOf(n.toTap());
    final onDay = n.data['kind'] == DocumentReminderKind.onDay.name;
    final kind = onDay ? l.ncKindDocToday : l.ncKindDocAhead;
    return NotificationDescription(
      group: NotificationGroup.travel,
      kind: kind,
      title: n.title ?? kind,
      body: n.body,
      icon: onDay ? Icons.event_busy_rounded : Icons.badge_rounded,
      subject: 'travelDocument:$doc',
    );
  }
}

/// Reminders of the user's own modules.
class CustomModuleDescriber extends NotificationDescriber {
  const CustomModuleDescriber();

  @override
  String get id => 'customModules';

  @override
  NotificationGroup? groupOf(CenterNotice n) =>
      CustomModuleNotificationTaps.isCustomModule(n.toTap()) ? NotificationGroup.customModules : null;

  @override
  NotificationDescription describe(CenterNotice n, CenterTexts t) {
    final module = CustomModuleNotificationTaps.moduleOf(n.toTap());
    return NotificationDescription(
      group: NotificationGroup.customModules,
      kind: t.l.ncKindCustom,
      title: n.title ?? t.l.ncKindCustom,
      body: n.body,
      icon: Icons.dashboard_customize_rounded,
      subject: module == null ? null : 'module:$module',
    );
  }
}

/// The daily wird's reminders (after the plan's prayer).
class WirdDescriber extends NotificationDescriber {
  const WirdDescriber();

  @override
  String get id => 'wird';

  @override
  NotificationGroup? groupOf(CenterNotice n) =>
      n.namespace == NotificationNamespaces.wird.name ? NotificationGroup.wird : null;

  @override
  NotificationDescription describe(CenterNotice n, CenterTexts t) {
    final plan = WirdReminderTaps.planOf(n.toTap());
    return NotificationDescription(
      group: NotificationGroup.wird,
      kind: t.l.ncKindWird,
      title: n.title ?? t.l.ncKindWird,
      body: n.body,
      icon: Icons.menu_book_rounded,
      subject: plan == null ? null : 'wirdPlan:$plan',
    );
  }
}
