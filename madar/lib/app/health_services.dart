import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import '../core/db/repositories/repositories.dart';
import '../core/notifications/notifications.dart';
import '../core/routing/health_route_pages.dart';
import '../core/routing/routes.dart';
import '../features/health/hub/health_dose_slots.dart';
import '../features/health/meds/meds.dart'
    show MedsNotificationTaps, MedsTab, medsNotificationBridgeProvider, medsReminderSyncProvider;
import '../features/health/record/record.dart'
    show AppointmentReminderTaps, recordNavigationProvider, recordReminderSyncProvider;
import '../features/health/wellbeing/wellbeing.dart' show WellbeingTab, WorryReminderTaps, worryReminderSyncProvider;
import '../features/orbit/data/orbit_providers.dart' show orbitClockProvider, orbitRepositoryProvider;
import '../features/orbit/data/orbit_repository.dart';

/// The Phase 4 health packages' cross-feature hooks, wired once for the
/// whole app (bootstrap and the test harness share them through
/// `madarAppOverrides`):
///
/// * the medical record opens its lab tests, its appointments and its tabs
///   as routes;
/// * the orbit reads the Health world's doses from the medication tracker's
///   own plan ([trackerDoseSlots]): courses dose on their own days, anchors
///   and timing rules move doses, snoozes delay them – so the balance and
///   the Neglect Radar agree with the medications screen.
List<Override> healthHookOverrides() => [
  recordNavigationProvider.overrideWithValue(const RoutedRecordNavigation()),
  orbitRepositoryProvider.overrideWith((ref) {
    final repos = ref.watch(repositoriesProvider);
    return OrbitRepository(repos, clock: ref.watch(orbitClockProvider), doseSlots: trackerDoseSlots(repos));
  }),
];

/// The health services the unlocked app keeps running (watched by
/// `AppServices`, inside the database gate and outside the app lock):
///
/// * the next 48 hours of dose reminders, re-planned on every change of
///   medications, courses, rules, the dose log, settings, prayer times or
///   language, at midnight and every six hours ([medsReminderSyncProvider]);
/// * the dose notifications' Taken / Snooze / Skip answers – forwarded from
///   the background isolate while the app runs, or delivered through the
///   taps stream – recorded with the refill alert after
///   ([medsNotificationBridgeProvider]; with the app closed the background
///   entry `medsNotificationBackgroundTap` records them itself);
/// * appointment reminders ([recordReminderSyncProvider]) and the worry
///   window's gentle notice for the next week ([worryReminderSyncProvider]).
void watchHealthServices(WidgetRef ref) {
  ref.watch(medsReminderSyncProvider);
  ref.watch(medsNotificationBridgeProvider);
  ref.watch(recordReminderSyncProvider);
  ref.watch(worryReminderSyncProvider);
}

/// Where a tap on a health notification leads (pure), or null when [tap] is
/// not one of them (or is a dose's action button – those are recorded, never
/// opened):
///
/// * a dose, refill or "not recorded" notice → the medications (a refill on
///   the list of medications);
/// * an appointment reminder → the appointments, that one lit;
/// * the worry window → wellbeing's worries tab (the review).
String? healthNotificationLocation(NotificationTap tap) {
  if (MedsNotificationTaps.opensMeds(tap)) {
    final refill = tap.data['k'] == MedsNotificationTaps.kRefill;
    return AppRoutes.medsOf(tab: refill ? MedsTab.meds.name : null);
  }
  final appointment = AppointmentReminderTaps.appointmentOf(tap);
  if (appointment != null) return AppRoutes.appointmentsOf(highlightId: appointment);
  if (WorryReminderTaps.matches(tap)) return AppRoutes.wellbeingOf(tab: WellbeingTab.worries.name);
  return null;
}
