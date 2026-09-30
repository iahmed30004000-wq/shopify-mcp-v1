import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/db/repositories/repositories.dart';
import '../../core/domain/enums.dart';
import '../../core/i18n/gen/app_localizations.dart';
import '../../core/interaction/quick_add/quick_add_handler.dart';
import '../../core/settings/app_settings.dart';
import '../../core/astro/astronomy.dart';
import '../orbit/data/orbit_providers.dart' show orbitPrayerDayProvider, orbitPulseHubProvider, prayerSettingsProvider;
import '../orbit/domain/prayer_schedule.dart' show PrayerSettings;
import '../orbit/render/sky/sky_model.dart' show SkyModel;
import 'domain/home_tasks.dart';
import 'domain/prayer_day.dart';
import 'domain/quick_add_handlers.dart';

/// The wall clock used by home (overridden in tests with a fixed time).
final homeClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Prayer window times of the day: the real schedule for the stored
/// location and calculation settings (Amman, Jordanian preset by default),
/// refreshed at midnight. Tests may override it with fixed times.
final prayerDayProvider = Provider<PrayerDayTimes>((ref) => ref.watch(orbitPrayerDayProvider));

/// Whether the app is in the foreground (resumed or merely inactive). Dart
/// timers stop while the device sleeps: clocks re-arm against the wall
/// clock when this turns true again, and background work waits for it.
final appForegroundProvider = Provider<ValueListenable<bool>>((ref) {
  final foreground = ValueNotifier<bool>(true);
  AppLifecycleListener? listener;
  try {
    listener = AppLifecycleListener(
      onStateChange: (s) => foreground.value = s == AppLifecycleState.resumed || s == AppLifecycleState.inactive,
    );
  } catch (_) {
    // No widgets binding (pure unit tests): always in the foreground.
  }
  ref.onDispose(() {
    listener?.dispose();
    foreground.dispose();
  });
  return foreground;
});

/// "Now", refreshed at every minute boundary and at the very start of every
/// prayer window (the chips' "now" dot and countdown switch together with
/// the dial, not up to a minute later) while someone listens – and at once
/// when the app comes back from the background.
final homeNowProvider = NotifierProvider.autoDispose<HomeNow, DateTime>(HomeNow.new);

class HomeNow extends Notifier<DateTime> {
  Timer? _timer;
  PrayerDayTimes? _times;

  /// How long after [now] the clock must tick next: the next minute
  /// boundary, or the next window start of [times] if that comes first.
  static Duration nextTick(DateTime now, PrayerDayTimes? times) {
    var wait = Duration(seconds: 60 - now.second, milliseconds: -now.millisecond, microseconds: -now.microsecond);
    if (times != null) {
      final today = PrayerDayTimes.dateOnly(now);
      for (final day in [today, today.add(const Duration(days: 1))]) {
        for (final w in PrayerDayTimes.windows) {
          final d = times.startOn(w, day).difference(now);
          if (d > Duration.zero && d < wait) wait = d;
        }
      }
    }
    return wait <= Duration.zero ? const Duration(milliseconds: 1) : wait;
  }

  @override
  DateTime build() {
    final clock = ref.watch(homeClockProvider);
    final foreground = ref.watch(appForegroundProvider);
    _times = ref.watch(prayerDayProvider);
    void onForeground() {
      if (!foreground.value) return;
      final now = clock();
      state = now;
      _schedule(now, clock);
    }

    foreground.addListener(onForeground);
    final now = clock();
    _schedule(now, clock);
    ref.onDispose(() {
      _timer?.cancel();
      foreground.removeListener(onForeground);
    });
    return now;
  }

  void _schedule(DateTime now, DateTime Function() clock) {
    _timer?.cancel();
    final wait = nextTick(now, _times);
    _timer = Timer(wait, () {
      final next = clock();
      state = next;
      _schedule(next, clock);
    });
  }
}

/// The window the user picked on home; `null` follows the current window.
final homeWindowProvider = NotifierProvider<HomeWindowController, PrayerWindow?>(HomeWindowController.new);

class HomeWindowController extends Notifier<PrayerWindow?> {
  @override
  PrayerWindow? build() => null;

  /// Focuses [window]; picking the current window resumes following it.
  void focus(PrayerWindow? window) => state = window;
}

/// The window currently containing "now".
final homeCurrentWindowProvider = Provider.autoDispose<PrayerWindow>(
  (ref) => ref.watch(prayerDayProvider).windowAt(ref.watch(homeNowProvider)),
);

/// The window whose tasks home shows.
final homeFocusedWindowProvider = Provider.autoDispose<PrayerWindow>(
  (ref) => ref.watch(homeWindowProvider) ?? ref.watch(homeCurrentWindowProvider),
);

/// The prayer day home shows (the hours before Fajr belong to yesterday).
final homeDayProvider = Provider.autoDispose<DateTime>(
  (ref) => ref.watch(prayerDayProvider).prayerDayOf(ref.watch(homeNowProvider)),
);

/// Task operations; completions go through the orbit's completion hook, so
/// the task's planet pulses at once.
final homeTasksServiceProvider = Provider<HomeTasksService>((ref) {
  final hub = ref.watch(orbitPulseHubProvider);
  return HomeTasksService(
    ref.watch(repositoriesProvider),
    clock: ref.watch(homeClockProvider),
    recordCompletion: (planetKey, kind, refTable, refId, at) =>
        hub.recordCompletion(planetKey, kind, refTable, refId, at: at),
  );
});

/// A window's list on one day.
typedef HomeTaskQuery = ({PrayerWindow window, DateTime day});

final homeTasksProvider = StreamProvider.autoDispose.family<List<TaskRow>, HomeTaskQuery>(
  (ref, q) => ref.watch(homeTasksServiceProvider).watchWindow(q.window, q.day, times: ref.watch(prayerDayProvider)),
);

/// Today's tasks of one world (its planet page lists them).
final planetTasksTodayProvider = StreamProvider.autoDispose.family<List<TaskRow>, String>(
  (ref, planetKey) => ref
      .watch(homeTasksServiceProvider)
      .watchPlanet(planetKey, ref.watch(homeDayProvider), times: ref.watch(prayerDayProvider)),
);

/// Task id → reminder rule.
final homeTaskRemindersProvider = StreamProvider.autoDispose<Map<String, Map<String, Object?>>>(
  (ref) => ref.watch(homeTasksServiceProvider).watchReminders(),
);

/// Visible planets keyed by `key` (colours, names and icons for task rows).
final homePlanetsProvider = StreamProvider.autoDispose<Map<String, PlanetRow>>(
  (ref) => ref
      .watch(repositoriesProvider)
      .planets
      .watchAll(where: (p) => p.hidden.equals(false))
      .map((rows) => {for (final p in rows) p.key: p}),
);

/// The shell's quick-add handler (tasks, money, water, pain, mood, contact).
/// Registered in the root scope through [quickAddHandlerProvider].
final shellQuickAddHandlerProvider = Provider<QuickAddHandler>(
  (ref) => shellQuickAddHandler(
    QuickAddContext(
      repositories: () => ref.read(repositoriesProvider),
      clock: () => ref.read(homeClockProvider)(),
      prayerDay: () => ref.read(prayerDayProvider),
      focusedWindow: () =>
          ref.read(homeWindowProvider) ?? ref.read(prayerDayProvider).windowAt(ref.read(homeClockProvider)()),
      defaultWalletName: () => lookupL10n(ref.read(appSettingsProvider).locale).homeDefaultWallet,
    ),
  ),
);

/// How bright the real sky behind the home scene is: 0 at night … 1 in full
/// day, from the sun's altitude at the configured prayer location. Glass over
/// the scene deepens with it so its text keeps contrast by day and at Maghrib.
final homeSkyDaylightProvider = Provider.autoDispose<double>((ref) {
  final now = ref.watch(homeNowProvider);
  final settings = ref.watch(prayerSettingsProvider).value ?? const PrayerSettings();
  final altitude = Astro.sun(now, latitude: settings.latitude, longitude: settings.longitude).altitude;
  return 1 - SkyModel.nightFactor(altitude);
});
