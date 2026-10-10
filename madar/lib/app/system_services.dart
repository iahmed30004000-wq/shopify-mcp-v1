import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:go_router/go_router.dart';

import '../core/notifications/notifications.dart';
import '../core/routing/routes.dart';
import '../core/routing/system_route_pages.dart';
import '../features/adhan/adhan.dart' show AdhanEvent, adhanInAppHoldProvider;
import '../features/adhkar/adhkar.dart' show adhkarReminderSyncProvider;
import '../features/body/body.dart' show BodyReminderTaps, BodyTab, bodyReminderSyncProvider;
import '../features/custom_modules/custom_modules.dart'
    show CustomModuleNotificationTaps, customModulesReminderSyncProvider;
import '../features/family/family.dart' show familyReminderSyncProvider;
import '../features/health/record/record.dart' show AppointmentReminderTaps, recordReminderSyncProvider;
import '../features/health/wellbeing/wellbeing.dart' show worryReminderSyncProvider;
import '../features/money/goals/goals.dart' show DueReminderKind, GoalsReminderTaps, goalsReminderSyncProvider;
import '../features/notification_center/notification_center.dart'
    show
        CenterNotice,
        NotificationCenterLinks,
        NotificationGroup,
        NotificationReplanHooks,
        notificationCenterLinksProvider,
        notificationCenterProvider,
        notificationGateProvider,
        notificationReplanHooksProvider;
import '../features/nutrition/nutrition.dart' show MealReminderTaps, nutritionReminderSyncProvider;
import '../features/search/search.dart' show searchOpenerProvider;
import '../features/travel/travel.dart' show TravelTab, travelReminderSyncProvider;
import '../features/wird/wird.dart' show wirdReminderSyncProvider;
import 'app_services.dart' show AppNotificationRouter;

/// The Phase 9 system packages' cross-feature hooks, wired once for the
/// whole app (bootstrap and the test harness share them through
/// `madarAppOverrides`):
///
/// * a global-search result opens its own screen ([openSearchResult]);
/// * a notification-centre row opens what it is about, and each group's
///   "Reminder settings" opens the screen that holds those switches
///   ([centerLocationOf], [centerSettingsLinks]);
/// * the in-app full-screen adhan is held back when Prayer is muted or that
///   call was skipped in the centre ([adhanInAppHoldProvider] →
///   `NotificationGate.withholds`), so the adhan can never sound after the
///   owner silenced it.
List<Override> systemHookOverrides() => [
  searchOpenerProvider.overrideWithValue(openSearchResult),
  notificationCenterLinksProvider.overrideWith(
    (ref) => NotificationCenterLinks(
      canOpen: (tap) => centerLocationOf(tap) != null,
      open: (context, tap) {
        final location = centerLocationOf(tap);
        if (location == null) return false;
        SystemNav.to(context, location);
        return true;
      },
      settings: centerSettingsLinks,
    ),
  ),
  // The gate is the one in the platform chain (`suspendingFlowOverrides`),
  // so what it holds back is exactly what it silenced.
  adhanInAppHoldProvider.overrideWith((ref) {
    final gate = ref.watch(notificationGateProvider);
    return (alarm) => gate.withholds(
      CenterNotice(
        id: alarm.id,
        namespace: NotificationNamespaces.adhan.name,
        at: alarm.at.toUtc(),
        data: AdhanEvent.fromAlarm(alarm).toData(),
      ),
    );
  }),
];

/// The notification centre, watched **first** of all the app's services
/// (see `AppServices`): it loads the stored mute and skip policy into the
/// gate before any feature's sync re-plans, records arrivals, taps and
/// answers while the centre's screen is closed, and re-arms snoozes the
/// system dropped.
///
/// [systemReplanHooksProvider] is created in the same breath, because the
/// centre asks those hooks to re-plan on its very first look.
void watchNotificationCenter(WidgetRef ref) {
  ref.watch(systemReplanHooksProvider);
  ref.watch(notificationCenterProvider);
}

/// Where a tap on a notification leads when it is opened from the centre:
/// the app's own tap routing, plus the adhan – whose taps belong to the
/// adhan hub (it presents the full-screen adhan), so a centre row for it
/// opens the prayer times instead.
String? centerLocationOf(NotificationTap tap) =>
    AppNotificationRouter.locationOf(tap) ??
    (tap.namespace == NotificationNamespaces.adhan.name ? AppRoutes.prayerTimes : null);

/// Each group's "Reminder settings": the screen that actually holds those
/// switches, and for a group whose notifications are per record (an
/// appointment, a document, a tracker) the record's own screen.
///
/// `other` is deliberately absent: those rows show no settings link.
final Map<NotificationGroup, FutureOr<void> Function(BuildContext, NotificationGroup, CenterNotice?)>
centerSettingsLinks = {
  NotificationGroup.prayer: (context, _, _) => context.push(AppRoutes.adhanSettings),
  NotificationGroup.adhkar: (context, _, _) => context.push(AppRoutes.reminders),
  // The wird's reminder rows live in Settings › Reminders too.
  NotificationGroup.wird: (context, _, _) => context.push(AppRoutes.reminders),
  // Settings › Health holds the dose-reminder switches.
  NotificationGroup.medications: (context, _, _) => context.push(AppRoutes.healthSettings),
  NotificationGroup.health: (context, _, notice) {
    final tap = notice?.toTap();
    final appointment = tap == null ? null : AppointmentReminderTaps.appointmentOf(tap);
    if (appointment != null) return context.push(AppRoutes.appointmentsOf(highlightId: appointment));
    // Fasting and meals are grouped under Health by the centre's
    // describers, but their switches live on the Body world.
    if (tap != null && BodyReminderTaps.matches(tap)) return context.push(AppRoutes.bodyOf(tab: BodyTab.fasting.name));
    if (tap != null && MealReminderTaps.matches(tap)) return context.push(AppRoutes.foodPlan);
    return context.push(AppRoutes.healthSettings);
  },
  NotificationGroup.money: (context, _, notice) {
    final target = notice == null ? null : GoalsReminderTaps.targetOf(notice.toTap());
    return switch (target?.kind) {
      DueReminderKind.debt => context.push(AppRoutes.goalsOf(debt: target!.id)),
      DueReminderKind.obligation => context.push(AppRoutes.goalsOf(obligation: target!.id)),
      null => context.push(AppRoutes.goals),
    };
  },
  NotificationGroup.family: (context, _, _) => context.push(AppRoutes.family),
  NotificationGroup.travel: (context, _, _) => context.push(AppRoutes.travelOf(tab: TravelTab.documents.name)),
  NotificationGroup.customModules: (context, _, notice) {
    final module = notice == null ? null : CustomModuleNotificationTaps.moduleOf(notice.toTap());
    return context.push(module == null ? AppRoutes.modules : AppRoutes.moduleOf(module));
  },
};

/// The re-plan hooks of every namespace whose requests the gate may have
/// had to rebuild (after a restart the original request – its buttons, its
/// alarm-clock timing – is gone). The centre asks them after a mute or an
/// unmute, after loading a policy, and after a restore.
///
/// The centre keeps **one** hook per namespace, and `reminders` is shared
/// by Money, Family, Travel, the Body's fasting, the meal plan and the
/// trackers – so that one hook runs all six. Every sync is guarded with
/// `ref.exists`: a hook re-plans a sync that is already running and never
/// starts one.
final systemReplanHooksProvider = Provider<NotificationReplanHooks>((ref) {
  final hooks = ref.watch(notificationReplanHooksProvider);
  Future<void> all(List<Future<void> Function()> syncs) async {
    for (final sync in syncs) {
      try {
        await sync();
      } catch (e) {
        debugPrint('Madar: a notification re-plan failed (${e.runtimeType})');
      }
    }
  }

  hooks
    ..register(NotificationNamespaces.adhkar.name, () async {
      if (ref.exists(adhkarReminderSyncProvider)) await ref.read(adhkarReminderSyncProvider.notifier).syncNow();
    })
    ..register(NotificationNamespaces.wird.name, () async {
      if (ref.exists(wirdReminderSyncProvider)) await ref.read(wirdReminderSyncProvider.notifier).syncNow();
    })
    ..register(
      NotificationNamespaces.health.name,
      () => all([
        () async {
          if (ref.exists(recordReminderSyncProvider)) await ref.read(recordReminderSyncProvider.notifier).syncNow();
        },
        () async {
          if (ref.exists(worryReminderSyncProvider)) await ref.read(worryReminderSyncProvider.notifier).syncNow();
        },
      ]),
    )
    ..register(
      NotificationNamespaces.reminders.name,
      () => all([
        () async {
          if (ref.exists(goalsReminderSyncProvider)) await ref.read(goalsReminderSyncProvider.notifier).syncNow();
        },
        () async {
          if (ref.exists(familyReminderSyncProvider)) await ref.read(familyReminderSyncProvider.notifier).syncNow();
        },
        () async {
          if (ref.exists(travelReminderSyncProvider)) await ref.read(travelReminderSyncProvider.notifier).run();
        },
        () async {
          if (ref.exists(bodyReminderSyncProvider)) await ref.read(bodyReminderSyncProvider.notifier).syncNow();
        },
        () async {
          if (ref.exists(nutritionReminderSyncProvider)) {
            await ref.read(nutritionReminderSyncProvider.notifier).syncNow();
          }
        },
        () async {
          if (ref.exists(customModulesReminderSyncProvider)) {
            await ref.read(customModulesReminderSyncProvider.notifier).syncNow();
          }
        },
      ]),
    );
  return hooks;
});
