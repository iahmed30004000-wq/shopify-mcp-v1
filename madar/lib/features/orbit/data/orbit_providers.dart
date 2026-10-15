import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/repositories/repositories.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/settings/app_settings.dart';
import '../../home/domain/prayer_day.dart';
import '../../home/home_providers.dart' show appForegroundProvider, homeClockProvider;
import '../domain/planet_pulse.dart';
import '../domain/prayer_schedule.dart';
import '../domain/scene_snapshot.dart';
import 'orbit_pulses.dart';
import 'orbit_repository.dart';
import 'planet_customization_service.dart';
import 'scene_snapshot_watcher.dart';

/// The orbit's wall clock (follows home's, so tests freeze both at once).
final orbitClockProvider = Provider<DateTime Function()>((ref) => ref.watch(homeClockProvider));

/// Language + digit style of every text the orbit derives (radar reasons,
/// planet names). Follows the app settings; override in tests.
final orbitFormatterProvider = Provider<MadarFormatter>((ref) {
  final (language, digits) = ref.watch(appSettingsProvider.select((s) => (s.languageCode, s.digits)));
  return MadarFormatter(languageCode: language, digits: digits);
});

final orbitRepositoryProvider = Provider<OrbitRepository>(
  (ref) => OrbitRepository(ref.watch(repositoriesProvider), clock: ref.watch(orbitClockProvider)),
);

/// Location and calculation settings (`key_values` `prayer.settings`;
/// default Amman with the Jordanian preset).
final prayerSettingsProvider = StreamProvider<PrayerSettings>(
  (ref) => ref.watch(orbitRepositoryProvider).watchPrayerSettings(),
);

/// The real prayer schedule for the stored settings (defaults until they
/// have loaded).
final prayerScheduleProvider = Provider<PrayerSchedule>((ref) {
  final settings = ref.watch(prayerSettingsProvider).value ?? const PrayerSettings();
  return ref.watch(orbitRepositoryProvider).scheduleFor(settings);
});

/// Today's calendar day, refreshed at local midnight (and re-armed against
/// the wall clock when the app comes back from the background: the timer
/// does not run while the device sleeps).
final orbitTodayProvider = NotifierProvider<OrbitToday, DateTime>(OrbitToday.new);

class OrbitToday extends Notifier<DateTime> {
  Timer? _timer;

  @override
  DateTime build() {
    final clock = ref.watch(orbitClockProvider);
    final foreground = ref.watch(appForegroundProvider);
    void onForeground() {
      if (!foreground.value) return;
      final today = _arm(clock);
      if (today != state) state = today;
    }

    foreground.addListener(onForeground);
    ref.onDispose(() {
      _timer?.cancel();
      foreground.removeListener(onForeground);
    });
    return _arm(clock);
  }

  DateTime _arm(DateTime Function() clock) {
    _timer?.cancel();
    final now = clock();
    final today = DateTime(now.year, now.month, now.day);
    final next = DateTime(now.year, now.month, now.day + 1);
    _timer = Timer(next.difference(now) + const Duration(seconds: 1), () => state = _arm(clock));
    return today;
  }
}

/// Real prayer-window times for home's dial and task windows (home's
/// `prayerDayProvider` reads it).
final orbitPrayerDayProvider = Provider<PrayerDayTimes>(
  (ref) => prayerDayTimesOf(ref.watch(prayerScheduleProvider).timesFor(ref.watch(orbitTodayProvider))),
);

/// [DayTimes] as home's [PrayerDayTimes]: wall-clock offsets from the day's
/// local midnight. A time on the next calendar day (Isha after midnight in a
/// high-latitude summer) becomes an offset beyond 24 h, so it still follows
/// Maghrib and the window order holds.
PrayerDayTimes prayerDayTimesOf(DayTimes t) {
  final day = DateTime.utc(t.day.year, t.day.month, t.day.day);
  Duration offset(DateTime at) {
    final days = DateTime.utc(at.year, at.month, at.day).difference(day).inDays;
    final d = Duration(days: days) + PrayerDayTimes.sinceMidnight(at);
    return d.isNegative ? Duration.zero : d;
  }

  return PrayerDayTimes(
    fajr: offset(t.fajr),
    sunrise: offset(t.sunrise),
    dhuhr: offset(t.dhuhr),
    asr: offset(t.asr),
    maghrib: offset(t.maghrib),
    isha: offset(t.isha),
  );
}

/// Tuning of the live snapshot stream (tests shorten it).
typedef SnapshotTiming = ({Duration debounce, Duration maxWait, Duration? tick});

final sceneSnapshotTimingProvider = Provider<SnapshotTiming>(
  (ref) => (
    debounce: const Duration(milliseconds: 250),
    maxWait: const Duration(seconds: 1),
    tick: const Duration(seconds: 60),
  ),
);

/// The live [SceneSnapshot]: recomputed when any relevant table changes
/// (debounced), every minute and when the prayer window ends; emits only
/// real changes.
final sceneSnapshotProvider = StreamProvider.autoDispose<SceneSnapshot>((ref) {
  final repo = ref.watch(orbitRepositoryProvider);
  final fmt = ref.watch(orbitFormatterProvider);
  final timing = ref.watch(sceneSnapshotTimingProvider);
  final watcher = SceneSnapshotWatcher.forTables(
    repo.db,
    repo.watchedTables,
    clock: ref.watch(orbitClockProvider),
    debounce: timing.debounce,
    maxWait: timing.maxWait,
    tick: timing.tick,
    active: ref.watch(appForegroundProvider),
    compute: (now) => repo.snapshot(now: now, languageCode: fmt.languageCode, digits: fmt.digits),
  );
  return watcher.watch();
});

/// Planet customisation (rename, recolour, reorder, hide, weights, add /
/// delete custom planets) with undo.
final planetCustomizationProvider = Provider<PlanetCustomizationService>(
  (ref) => PlanetCustomizationService(ref.watch(repositoriesProvider)),
);

/// The completion hook + planet pulse stream.
final orbitPulseHubProvider = Provider<OrbitPulseHub>((ref) {
  final hub = OrbitPulseHub(ref.watch(repositoriesProvider), clock: ref.watch(orbitClockProvider));
  ref.onDispose(hub.dispose);
  return hub;
});

/// Planet pulses as a provider (each completion is a new value); the scene
/// may also listen to `ref.watch(orbitPulseHubProvider).pulses` directly.
final planetPulsesProvider = StreamProvider.autoDispose<PlanetPulse>((ref) => ref.watch(orbitPulseHubProvider).pulses);
