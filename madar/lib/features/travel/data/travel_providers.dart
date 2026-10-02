import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/repositories/repositories.dart';
import '../../../core/notifications/notification_models.dart';
import '../../../core/notifications/notification_providers.dart';
import '../../../core/settings/app_settings.dart';
import '../../orbit/data/orbit_providers.dart' show orbitClockProvider, orbitTodayProvider;
import '../../prayer/application/prayer_providers.dart' show cityDatabaseProvider;
import '../../prayer/application/prayer_settings_controller.dart' show prayerSettingsControllerProvider;
import '../../prayer/domain/cities.dart';
import '../domain/destination_prayer.dart';
import '../domain/packing.dart';
import '../domain/travel_overview.dart';
import '../domain/trip_timeline.dart';
import '../travel_texts.dart';
import 'travel_notifications.dart';
import 'travel_service.dart';

/// The travel feature's wall clock (follows the orbit's / home's, so tests
/// freeze them all at once).
final travelClockProvider = Provider<DateTime Function()>((ref) => ref.watch(orbitClockProvider));

/// "Now" for countdowns: re-read when the calendar day turns.
final travelNowProvider = Provider<DateTime>((ref) {
  ref.watch(orbitTodayProvider);
  return ref.watch(travelClockProvider)();
});

final travelServiceProvider = Provider<TravelService>(
  (ref) => TravelService(ref.watch(repositoriesProvider), clock: ref.watch(travelClockProvider)),
);

final travelTripsProvider = StreamProvider<List<TripRow>>((ref) => ref.watch(travelServiceProvider).watchTrips());

final travelTripRowProvider = StreamProvider.autoDispose.family<TripRow?, String>(
  (ref, id) => ref.watch(travelServiceProvider).watchTrip(id),
);

/// One trip's packing list, in its stored order.
final travelItemsProvider = StreamProvider.autoDispose.family<List<TripItemRow>, String>(
  (ref, tripId) => ref.watch(travelServiceProvider).watchItems(tripId),
);

/// Every packing item (for the lists' progress rings).
final travelAllItemsProvider = StreamProvider<List<TripItemRow>>(
  (ref) => ref.watch(travelServiceProvider).watchAllItems(),
);

final travelTemplatesProvider = StreamProvider<List<PackingTemplateRow>>(
  (ref) => ref.watch(travelServiceProvider).watchTemplates(),
);

final travelTemplateProvider = StreamProvider.autoDispose.family<PackingTemplateRow?, String>(
  (ref, id) => ref.watch(travelServiceProvider).watchTemplate(id),
);

final travelDocumentsProvider = StreamProvider<List<TravelDocumentRow>>(
  (ref) => ref.watch(travelServiceProvider).watchDocuments(),
);

/// Ids of the trips whose status was set by hand.
final travelManualStatusProvider = StreamProvider<Set<String>>(
  (ref) => ref.watch(travelServiceProvider).watchManualStatus(),
);

/// The offline city list once loaded (null while loading).
final travelCitiesProvider = Provider<CityDatabase?>((ref) => ref.watch(cityDatabaseProvider).value);

/// A stored trip's destination as a place (null when typed freely).
TripPlace? tripPlaceOf(TripRow row, CityDatabase? cities) =>
    TripPlace.resolve(latitude: row.latitude, longitude: row.longitude, country: row.country, cities: cities);

/// Every trip as the screens show it (null while loading).
final travelTripViewsProvider = Provider<List<TripView>?>((ref) {
  final trips = ref.watch(travelTripsProvider).value;
  final items = ref.watch(travelAllItemsProvider).value;
  final manual = ref.watch(travelManualStatusProvider).value;
  if (trips == null || items == null || manual == null) return null;
  final cities = ref.watch(travelCitiesProvider);
  final now = ref.watch(travelNowProvider);
  final byTrip = <String, List<bool>>{};
  for (final i in items) {
    byTrip.putIfAbsent(i.tripId, () => []).add(i.packed);
  }
  return [
    for (final t in trips)
      TripView.of(
        t,
        now: now,
        manual: manual.contains(t.id),
        packing: PackingProgress.of(byTrip[t.id] ?? const []),
        place: tripPlaceOf(t, cities),
      ),
  ];
});

/// The travel lists and document warnings (null while loading).
final travelOverviewProvider = Provider<TravelOverview?>((ref) {
  final trips = ref.watch(travelTripViewsProvider);
  final docs = ref.watch(travelDocumentsProvider).value;
  if (trips == null || docs == null) return null;
  return TravelOverview.of(trips: trips, documents: [for (final d in docs) docFactsOf(d)]);
});

/// One trip's view (null while loading or once deleted).
final travelTripViewProvider = Provider.autoDispose.family<TripView?, String>((ref, id) {
  final trips = ref.watch(travelTripViewsProvider);
  return trips?.where((t) => t.id == id).firstOrNull;
});

/// Prayer times and qibla at a trip's destination with the user's
/// calculation settings (null for a destination typed freely).
final travelDestinationPrayerProvider = Provider.autoDispose.family<DestinationPrayer?, String>((ref, tripId) {
  final place = ref.watch(travelTripViewProvider(tripId).select((t) => t?.place));
  if (place == null) return null;
  final settings = ref.watch(prayerSettingsControllerProvider);
  return DestinationPrayer(place, settings);
});

/// Localised texts for notifications (follows the app language / digits).
final travelNotificationTextsProvider = Provider<TravelTexts>((ref) {
  final (language, digits) = ref.watch(appSettingsProvider.select((s) => (s.languageCode, s.digits)));
  return TravelTexts.forLanguage(language, digits: digits);
});

/// "Use this as my prayer location while travelling": the app wires it to
/// the prayer settings (e.g. `prayerSettingsControllerProvider.notifier`
/// `.setCity(place.city!)`, or `.setFix(...)` for bare coordinates). Null
/// (the default) hides the action.
typedef TravelUsePrayerLocation = Future<void> Function(BuildContext context, TripPlace place);

final travelUsePrayerLocationProvider = Provider<TravelUsePrayerLocation?>((ref) => null);

/// Keeps the stored trip statuses in step with their dates (the orbit reads
/// the stored column): on every change of trips, manual choices or day.
/// Watch it where travel data is shown (the travel screens do), or at the
/// app root to keep the orbit exact without opening travel.
final travelStatusSyncProvider = NotifierProvider<TravelStatusSync, int>(TravelStatusSync.new);

class TravelStatusSync extends Notifier<int> {
  static const Duration debounce = Duration(milliseconds: 400);
  Timer? _timer;
  bool _running = false;

  @override
  int build() {
    ref.listen(travelTripViewsProvider, (_, next) {
      if (next != null && next.any((t) => !t.manual && t.status != t.row.status)) _schedule();
    }, fireImmediately: true);
    ref.onDispose(() => _timer?.cancel());
    return 0;
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(run()));
  }

  /// Writes the derived statuses now (tests call it directly).
  Future<int> run() async {
    if (_running) return 0;
    _running = true;
    try {
      final views = ref.read(travelTripViewsProvider) ?? const [];
      final now = ref.read(travelClockProvider)();
      final changed = await ref
          .read(travelServiceProvider)
          .syncStatuses(
            todayByTrip: {for (final v in views) v.id: TravelToday.at(now, zone: v.place?.zone)},
          );
      if (ref.mounted) state = state + changed;
      return changed;
    } catch (e) {
      debugPrint('travel: status sync failed: $e');
      return 0;
    } finally {
      _running = false;
    }
  }
}

/// Keeps the document-expiry reminders scheduled: on every change of the
/// documents or the language, and when the day turns. Watch it at the app
/// root (or while travel screens are open).
final travelReminderSyncProvider = NotifierProvider<TravelReminderSync, NotificationSyncReport?>(
  TravelReminderSync.new,
);

class TravelReminderSync extends Notifier<NotificationSyncReport?> {
  static const Duration debounce = Duration(milliseconds: 700);
  Timer? _timer;
  bool _running = false;
  bool _again = false;

  @override
  NotificationSyncReport? build() {
    ref.listen(travelDocumentsProvider, (_, next) {
      if (next.hasValue) _schedule();
    }, fireImmediately: true);
    ref.listen(travelNotificationTextsProvider, (_, _) => _schedule());
    ref.listen(orbitTodayProvider, (_, _) => _schedule());
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(run()));
  }

  /// Syncs now (tests call it directly).
  Future<NotificationSyncReport?> run() async {
    if (_running) {
      _again = true;
      return null;
    }
    _running = true;
    try {
      final docs = await ref.read(travelServiceProvider).repos.travelDocuments.getAll();
      final notifier = TravelDocumentNotifier(
        notifications: ref.read(notificationServiceProvider),
        texts: () => ref.read(travelNotificationTextsProvider),
      );
      final report = await notifier.sync([for (final d in docs) docFactsOf(d)], now: ref.read(travelClockProvider)());
      if (ref.mounted) state = report;
      return report;
    } catch (e) {
      debugPrint('travel: reminder sync failed: $e');
      return null;
    } finally {
      _running = false;
      if (_again && ref.mounted) {
        _again = false;
        _schedule();
      }
    }
  }
}
