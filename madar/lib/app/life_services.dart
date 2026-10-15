import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:go_router/go_router.dart';

import '../core/i18n/formatters.dart';
import '../core/i18n/gen/app_localizations.dart';
import '../core/interaction/interaction.dart';
import '../core/notifications/notifications.dart';
import '../core/routing/life_route_pages.dart';
import '../core/routing/routes.dart';
import '../core/sound/sound_api.dart';
import '../features/body/body.dart' show BodyReminderTaps, BodyTab, bodyReminderSyncProvider;
import '../features/custom_modules/custom_modules.dart'
    show CustomModuleNotificationTaps, customModulesReminderSyncProvider;
import '../features/family/family.dart' show FamilyNotificationTaps, familyReminderSyncProvider;
import '../features/growth/growth.dart' show growthOpenGoalProvider;
import '../features/nutrition/nutrition.dart' show MealReminderTaps, nutritionReminderSyncProvider;
import '../features/orbit/data/orbit_providers.dart' show orbitTodayProvider;
import '../features/prayer/prayer.dart' show GeoFix, prayerSettingsControllerProvider;
import '../features/travel/travel.dart'
    show
        TravelReminderTaps,
        TravelTab,
        TripPlace,
        travelReminderSyncProvider,
        travelStatusSyncProvider,
        travelUsePrayerLocationProvider;
import '../features/work/work.dart' show workCardTaskSyncProvider, workRoutesProvider, workServiceProvider;

/// The Phase 6 life packages' cross-feature hooks, wired once for the whole
/// app (bootstrap and the test harness share them through
/// `madarAppOverrides`):
///
/// * Work's boards, projects and screen open as routes
///   ([RoutedWorkRoutes]);
/// * a learning goal opens as its route (`/growth/goal/<id>`);
/// * a trip's destination can become the prayer location while travelling
///   ([useTripAsPrayerLocation]; undoable).
List<Override> lifeHookOverrides() => [
  workRoutesProvider.overrideWithValue(const RoutedWorkRoutes()),
  growthOpenGoalProvider.overrideWithValue(
    (context, goalId) => unawaited(context.push<void>(AppRoutes.growthGoalOf(goalId))),
  ),
  travelUsePrayerLocationProvider.overrideWith(
    (ref) =>
        (context, place) => useTripAsPrayerLocation(ref, context, place),
  ),
];

/// The life services the unlocked app keeps running (watched by
/// `AppServices`, inside the database gate and outside the app lock):
///
/// * a card placed in a prayer window and its task on the home panel stay
///   in step – done, window, title, Top 3 – even while no Work screen is
///   open ([workCardTaskSyncProvider]);
/// * yesterday's finished Top 3 is cleared quietly at start and at
///   midnight, so the home-screen widget never shows a stale focus
///   ([workTop3SettleProvider]);
/// * the family's reach-out digest and birthdays ([familyReminderSyncProvider]),
///   the travel documents' expiry ([travelReminderSyncProvider]), the
///   fasting goal and eating window ([bodyReminderSyncProvider]), the meal
///   reminders of the active meal plan ([nutritionReminderSyncProvider]) and
///   the trackers' own reminders ([customModulesReminderSyncProvider]) stay
///   planned;
/// * a trip's status follows its dates, so a finished trip stops being a
///   moon of Travel ([travelStatusSyncProvider]).
///
/// The notification centre's re-plan hook for the shared `reminders`
/// namespace (Money + these four syncs) is registered by the system
/// services, not here.
void watchLifeServices(WidgetRef ref) {
  ref.watch(workCardTaskSyncProvider);
  ref.watch(workTop3SettleProvider);
  ref.watch(familyReminderSyncProvider);
  ref.watch(travelStatusSyncProvider);
  ref.watch(travelReminderSyncProvider);
  ref.watch(bodyReminderSyncProvider);
  ref.watch(nutritionReminderSyncProvider);
  ref.watch(customModulesReminderSyncProvider);
}

/// Settles an earlier day's Top 3 when nothing needs asking (finished
/// flags cleared; an unfinished one still waits for the morning question on
/// the Top 3 card): once at start and again whenever the day turns.
final workTop3SettleProvider = Provider<void>((ref) {
  ref.listen(orbitTodayProvider, (_, _) => unawaited(_settleTop3(ref)), fireImmediately: true);
});

Future<void> _settleTop3(Ref ref) async {
  try {
    await ref.read(workServiceProvider).settleTop3();
  } catch (e, s) {
    if (kDebugMode) debugPrint('Madar: Top 3 settle failed: $e\n$s');
  }
}

/// Makes [place] (a trip's destination) the prayer location – the city of
/// the offline list, or its coordinates and zone – with an undo that
/// restores the settings from before.
@visibleForTesting
Future<void> useTripAsPrayerLocation(Ref ref, BuildContext context, TripPlace place) async {
  final controller = ref.read(prayerSettingsControllerProvider.notifier);
  final city = place.city;
  final before = city != null
      ? await controller.setCity(city)
      : await controller.setFix(GeoFix(latitude: place.latitude, longitude: place.longitude), deviceZone: place.timeZone);
  if (!context.mounted) return;
  final l = L10n.of(context);
  final name = city == null
      ? l.lifeHubPrayerDestination
      : BidiIsolate.isolate(MadarFormatter.of(context).isArabic ? city.nameAr : city.nameEn);
  Fx.fire(Sfx.complete);
  unawaited(
    showUndoToast(
      context,
      UndoableAction(label: l.travelPrayerUsed(name), undo: () => controller.restore(before)),
    ),
  );
}

/// Where a tap on a life notification leads (pure), or null when [tap] is
/// not one:
///
/// * the family's reach-out digest → Family (`/family`); a birthday → that
///   person's page (`/family/person/<id>`);
/// * a travel document's expiry → the documents (`/travel?tab=documents`);
/// * a fasting goal or eating-window notice → the fasting tab
///   (`/body?tab=fasting`);
/// * a meal reminder → the food of that day, the day it fires for
///   (`/body?tab=food`), where the meal it named is the next one up;
/// * a tracker's reminder → that tracker (`/modules/module/<id>`).
String? lifeNotificationLocation(NotificationTap tap) {
  if (FamilyNotificationTaps.isFamily(tap)) {
    final person = FamilyNotificationTaps.personOf(tap);
    return person == null ? AppRoutes.family : AppRoutes.familyPersonOf(person);
  }
  if (TravelReminderTaps.documentOf(tap) != null) return AppRoutes.travelOf(tab: TravelTab.documents.name);
  if (BodyReminderTaps.matches(tap)) return AppRoutes.bodyOf(tab: BodyTab.fasting.name);
  if (MealReminderTaps.matches(tap)) return AppRoutes.bodyOf(tab: BodyTab.food.name);
  final module = CustomModuleNotificationTaps.moduleOf(tap);
  if (module != null) return AppRoutes.moduleOf(module);
  return null;
}
