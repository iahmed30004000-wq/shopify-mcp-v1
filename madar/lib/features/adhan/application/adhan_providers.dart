import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/repositories/repositories.dart';
import '../../../core/domain/enums.dart';
import '../../../core/notifications/notification_models.dart';
import '../../../core/notifications/notification_providers.dart';
import '../../../core/providers.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/sound/prayer_mute.dart';
import '../../home/home_providers.dart' show appForegroundProvider;
import '../../orbit/data/orbit_providers.dart';
import '../../orbit/domain/prayer_schedule.dart';
import '../../orbit/presentation/prayer/prayer_sheet.dart' show prayerLogServiceProvider;
import '../data/adhan_audio.dart';
import '../data/adhan_permissions.dart';
import '../data/adhan_scheduler.dart';
import '../data/adhan_settings_repository.dart';
import '../data/adhan_system.dart';
import '../data/adhan_texts.dart';
import '../data/muezzin_library.dart';
import '../domain/adhan_event.dart';
import '../domain/adhan_plan.dart';
import '../domain/adhan_settings.dart';
import '../domain/adhan_slot.dart';

// ---------------------------------------------------------------------------
// Platform seams (override in tests)

/// Madar's Android side of the adhan (MainActivity.kt).
final adhanSystemProvider = Provider<AdhanSystem>((ref) => const MethodChannelAdhanSystem());

final batteryGateProvider = Provider<BatteryOptimizationGate>((ref) => const PermissionHandlerBatteryGate());

final audioFilePickerProvider = Provider<AudioFilePicker>((ref) => const SystemAudioFilePicker());

/// The adhan's wall clock (follows the orbit's, so tests freeze both).
final adhanClockProvider = Provider<DateTime Function()>((ref) => ref.watch(orbitClockProvider));

/// Logs a prayer as prayed from the adhan screen ("I prayed"). Defaults to
/// the prayer tracker (via the orbit's `PrayerLogService`, so the Faith
/// world reacts).
final adhanMarkPrayedProvider = Provider<Future<void> Function(DateTime day, Prayer prayer)>((ref) {
  return (day, prayer) async {
    await ref.read(prayerLogServiceProvider).log(day, prayer, PrayerStatus.prayed);
  };
});

// ---------------------------------------------------------------------------
// Settings

final adhanSettingsRepositoryProvider = Provider<AdhanSettingsRepository>(
  (ref) => AdhanSettingsRepository(ref.watch(repositoriesProvider).keyValues),
);

/// The adhan settings (encrypted `key_values`), live.
final adhanSettingsProvider = StreamNotifierProvider<AdhanSettingsController, AdhanSettings>(
  AdhanSettingsController.new,
);

class AdhanSettingsController extends StreamNotifier<AdhanSettings> {
  @override
  Stream<AdhanSettings> build() => ref.watch(adhanSettingsRepositoryProvider).watch();

  /// Applies [change] and stores the result (the stream then re-plans the
  /// alarms through [adhanSyncProvider]).
  Future<AdhanSettings> change(AdhanSettings Function(AdhanSettings current) change) async {
    final repo = ref.read(adhanSettingsRepositoryProvider);
    final current = state.value ?? await repo.load();
    final next = change(current);
    if (next == current) return current;
    state = AsyncData(next);
    await repo.save(next);
    return next;
  }
}

// ---------------------------------------------------------------------------
// Services

final muezzinLibraryProvider = Provider<MuezzinLibrary>(
  (ref) => MuezzinLibrary(system: ref.watch(adhanSystemProvider), picker: ref.watch(audioFilePickerProvider)),
);

/// In-app playback (previews; the adhan screen when no notification sounds).
final adhanAudioProvider = Provider<AdhanAudio>((ref) {
  final library = ref.watch(muezzinLibraryProvider);
  final audio = SoloudAdhanAudio(ref.watch(soundServiceProvider), readFile: library.bytesOf);
  ref.onDispose(audio.dispose);
  return audio;
});

final adhanSchedulerProvider = Provider<AdhanScheduler>(
  (ref) => AdhanScheduler(
    notifications: ref.watch(notificationServiceProvider),
    system: ref.watch(adhanSystemProvider),
    clock: ref.watch(adhanClockProvider),
  ),
);

final adhanPermissionsProvider = Provider<AdhanPermissions>(
  (ref) => AdhanPermissions(
    notifications: ref.watch(notificationServiceProvider),
    system: ref.watch(adhanSystemProvider),
    battery: ref.watch(batteryGateProvider),
    clock: ref.watch(adhanClockProvider),
  ),
);

/// Notification / screen texts in the app's language and digit style, prayer
/// times on the location's clock.
final adhanTextsProvider = Provider<AdhanTexts>((ref) {
  final (language, digits) = ref.watch(appSettingsProvider.select((s) => (s.languageCode, s.digits)));
  final schedule = ref.watch(prayerScheduleProvider);
  return AdhanTexts.forLanguage(
    language,
    digits: digits,
    wallClock: schedule.wallClock,
    clock24h: schedule.settings.clock24h,
  );
});

/// The prayer times as the planner reads them.
typedef AdhanTimes = ({AdhanTimesFor timesFor, LocalDayOf localDayOf});

/// Adapts a [PrayerSchedule] (days on the location's calendar).
AdhanTimes adhanTimesFromSchedule(PrayerSchedule schedule) => (
  timesFor: (day) {
    final t = schedule.timesFor(DateTime(day.year, day.month, day.day));
    return AdhanDayTimes(day, {
      AdhanSlot.fajr: t.fajr,
      AdhanSlot.sunrise: t.sunrise,
      AdhanSlot.dhuhr: t.dhuhr,
      AdhanSlot.asr: t.asr,
      AdhanSlot.maghrib: t.maghrib,
      AdhanSlot.isha: t.isha,
    });
  },
  localDayOf: (instant) {
    final d = schedule.dateOf(instant);
    return DateTime.utc(d.year, d.month, d.day);
  },
);

final adhanTimesProvider = Provider<AdhanTimes>((ref) => adhanTimesFromSchedule(ref.watch(prayerScheduleProvider)));

/// Whether the stored prayer settings (location, method…) have loaded.
/// Until then [prayerScheduleProvider] answers with the default city, which
/// may not be where the user lives: nothing is planned or muted on it.
final adhanTimesReadyProvider = Provider<bool>((ref) {
  final settings = ref.watch(prayerSettingsProvider);
  return settings.hasValue || settings.hasError;
});

/// An instant on the location's wall clock (prayer times read the same as
/// on the prayer screens even when the device is set to another zone).
final adhanWallClockProvider = Provider<DateTime Function(DateTime instant)>(
  (ref) => ref.watch(prayerScheduleProvider).wallClock,
);

// ---------------------------------------------------------------------------
// Permissions (live)

final adhanPermissionStatusProvider = AsyncNotifierProvider<AdhanPermissionStatusController, AdhanPermissionStatus>(
  AdhanPermissionStatusController.new,
);

/// Live permission status: re-checked whenever the app returns to the
/// foreground (the user may have changed something in system settings).
class AdhanPermissionStatusController extends AsyncNotifier<AdhanPermissionStatus> {
  @override
  Future<AdhanPermissionStatus> build() async {
    final foreground = ref.watch(appForegroundProvider);
    void onResume() {
      if (foreground.value) unawaited(refresh());
    }

    foreground.addListener(onResume);
    ref.onDispose(() => foreground.removeListener(onResume));
    return ref.read(adhanPermissionsProvider).check();
  }

  Future<void> refresh() async {
    final status = await ref.read(adhanPermissionsProvider).check();
    if (ref.mounted) state = AsyncData(status);
  }

  /// Requests [p]; re-checks everything afterwards and re-plans the alarms
  /// (exact alarms change how they are scheduled).
  Future<bool> request(AdhanPermission p) async {
    final granted = await ref.read(adhanPermissionsProvider).request(p);
    await refresh();
    if (granted && ref.mounted) unawaited(ref.read(adhanSyncProvider.notifier).syncNow());
    return granted;
  }
}

// ---------------------------------------------------------------------------
// Auto re-scheduling

@immutable
class AdhanSyncState {
  const AdhanSyncState({this.last, this.syncing = false, this.error});

  final AdhanSyncResult? last;
  final bool syncing;
  final Object? error;

  AdhanSyncState copyWith({AdhanSyncResult? last, bool? syncing, Object? error, bool clearError = false}) =>
      AdhanSyncState(
        last: last ?? this.last,
        syncing: syncing ?? this.syncing,
        error: clearError ? null : error ?? this.error,
      );
}

/// Keeps the adhan alarms planned: on start, whenever the adhan settings,
/// the prayer settings (location, method…), the language or the day change,
/// and when the app returns to the foreground after a time-zone change or
/// more than [refreshAfter]. Watch it once from the app root ([AdhanHost]
/// does).
final adhanSyncProvider = NotifierProvider<AdhanSync, AdhanSyncState>(AdhanSync.new);

class AdhanSync extends Notifier<AdhanSyncState> {
  static const debounce = Duration(milliseconds: 350);
  static const refreshAfter = Duration(hours: 6);

  Timer? _debounce;
  Future<AdhanSyncResult?>? _running;
  bool _again = false;
  Duration? _offset;

  @override
  AdhanSyncState build() {
    ref.listen(adhanSettingsProvider, (_, _) => _schedule());
    ref.listen(adhanTimesReadyProvider, (_, _) => _schedule());
    ref.listen(adhanTimesProvider, (_, _) => _schedule());
    ref.listen(adhanTextsProvider, (_, _) => _schedule());
    ref.listen(orbitTodayProvider, (_, _) => _schedule());
    final foreground = ref.read(appForegroundProvider);
    void onResume() {
      if (!foreground.value) return;
      final now = ref.read(adhanClockProvider)();
      final last = state.last?.at;
      final zoneChanged = _offset != null && now.timeZoneOffset != _offset;
      if (zoneChanged || last == null || now.difference(last).abs() > refreshAfter) _schedule();
    }

    foreground.addListener(onResume);
    ref.onDispose(() {
      foreground.removeListener(onResume);
      _debounce?.cancel();
    });
    _schedule();
    return const AdhanSyncState();
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(debounce, () => unawaited(syncNow()));
  }

  /// Plans now (awaits a running sync and runs once more after it).
  Future<AdhanSyncResult?> syncNow() async {
    if (_running != null) {
      _again = true;
      return _running;
    }
    final run = _run();
    _running = run;
    try {
      return await run;
    } finally {
      _running = null;
      if (_again && ref.mounted) {
        _again = false;
        _schedule();
      }
    }
  }

  Future<AdhanSyncResult?> _run() async {
    if (!ref.mounted) return null;
    final settings = ref.read(adhanSettingsProvider).value;
    if (settings == null || !ref.read(adhanTimesReadyProvider)) {
      // Not loaded yet (the adhan settings, or the location the prayer
      // times are for): the listeners re-trigger once they arrive.
      return null;
    }
    state = state.copyWith(syncing: true);
    try {
      final times = ref.read(adhanTimesProvider);
      final result = await ref
          .read(adhanSchedulerProvider)
          .sync(
            settings: settings,
            timesFor: times.timesFor,
            localDayOf: times.localDayOf,
            texts: ref.read(adhanTextsProvider),
          );
      _offset = ref.read(adhanClockProvider)().timeZoneOffset;
      unawaited(ref.read(muezzinLibraryProvider).pruneOrphans({for (final m in settings.muezzins) m.fileName}));
      if (ref.mounted) state = AdhanSyncState(last: result);
      return result;
    } catch (e, s) {
      debugPrint('AdhanSync failed: $e\n$s');
      if (ref.mounted) state = state.copyWith(syncing: false, error: e);
      return null;
    }
  }
}

// ---------------------------------------------------------------------------
// Events: what the adhan screen shows

/// The adhan / reminder being presented (null = none). Fed by notification
/// taps, the launch notification (full-screen intent on a cold start) and –
/// while Madar is open – the exact adhan time itself.
final adhanEventProvider = NotifierProvider<AdhanEventHub, AdhanEvent?>(AdhanEventHub.new);

class AdhanEventHub extends Notifier<AdhanEvent?> {
  /// An adhan screen left open (e.g. the phone locked over it) is retired
  /// this long after its alarm, when the app next comes to the foreground –
  /// it never greets the user over the lock screen hours later.
  static const staleAfter = Duration(hours: 1);

  StreamSubscription<NotificationTap>? _taps;
  Timer? _next;
  Timer? _oneOff;
  final Set<String> _handled = {};

  @override
  AdhanEvent? build() {
    final service = ref.read(notificationServiceProvider);
    _taps = service.taps.listen(_onTap);
    unawaited(_readLaunch());
    ref.listen(adhanSyncProvider, (_, _) => _arm());
    final foreground = ref.read(appForegroundProvider);
    void onForeground() {
      if (foreground.value) _retireStale();
      _arm();
    }

    foreground.addListener(onForeground);
    ref.onDispose(() {
      unawaited(_taps?.cancel());
      _next?.cancel();
      _oneOff?.cancel();
      foreground.removeListener(onForeground);
    });
    return null;
  }

  /// Presents [event] at its time if Madar is still in the foreground then
  /// (e.g. "test adhan now": the device is in use, so Android shows a
  /// heads-up instead of the full-screen view).
  void presentWhenDue(AdhanEvent event) {
    _oneOff?.cancel();
    final wait = event.firedAt.difference(ref.read(adhanClockProvider)());
    _oneOff = Timer(wait.isNegative ? Duration.zero : wait, () {
      if (!ref.mounted || !ref.read(appForegroundProvider).value) return;
      present(event.copyWith(source: AdhanEventSource.foreground));
    });
  }

  Future<void> _readLaunch() async {
    try {
      // Never keep the app hidden for long if the plugin does not answer.
      // Only the adhan's own launch notification: another feature's (an
      // adhkar reminder …) is left for the app shell to route.
      final tap = await ref
          .read(notificationServiceProvider)
          .takeLaunchTap(where: (t) => t.namespace == NotificationNamespaces.adhan.name)
          .timeout(const Duration(seconds: 2), onTimeout: () => null);
      if (tap != null && ref.mounted) _onTap(tap);
    } catch (e) {
      debugPrint('AdhanEventHub: reading the launch notification failed: $e');
    } finally {
      if (ref.mounted) {
        // Nothing to show over the lock screen: make sure the window is not
        // allowed there (e.g. Android re-created the activity from recents
        // with the old full-screen intent – the plugin reports no launch,
        // so no adhan screen would ever release the mode).
        if (state == null) unawaited(ref.read(adhanSystemProvider).setLockScreenMode(false));
        ref.read(adhanLaunchCheckedProvider.notifier).done();
      }
    }
  }

  void _onTap(NotificationTap tap) {
    final event = AdhanEvent.fromTap(tap);
    if (event == null) return;
    if (event.actionId == AdhanActions.stop) {
      // The plugin already cancelled the notification (its sound stops).
      if (state?.key == event.key) dismiss();
      return;
    }
    present(event);
  }

  void _retireStale() {
    final current = state;
    if (current == null || !ref.mounted) return;
    final age = ref.read(adhanClockProvider)().difference(current.firedAt);
    if (age > staleAfter) dismiss();
  }

  /// Shows [event] (ignored if that very alarm is already showing).
  void present(AdhanEvent event) {
    if (!ref.mounted) return;
    if (state?.key == event.key) return;
    _handled.add(event.key);
    state = event;
  }

  /// Closes the adhan screen and releases the lock-screen mode.
  ///
  /// An adhan that came from a notification may be showing over the lock
  /// screen: the app beneath stays veiled ([adhanVeilProvider]) until the
  /// phone is unlocked, so not one frame of it is painted over the keyguard
  /// while the window drops behind it.
  void dismiss() {
    if (!ref.mounted) return;
    final closing = state;
    if (closing != null && closing.source != AdhanEventSource.foreground) {
      ref.read(adhanVeilProvider.notifier).raise();
    }
    state = null;
    unawaited(ref.read(adhanSystemProvider).setLockScreenMode(false));
  }

  /// While Madar is in the foreground, present the next adhan at its exact
  /// time (the notification sounds; this brings the full-screen view).
  void _arm() {
    _next?.cancel();
    _next = null;
    if (!ref.mounted || !ref.read(appForegroundProvider).value) return;
    final settings = ref.read(adhanSettingsProvider).value;
    final plan = ref.read(adhanSyncProvider).last?.plan;
    if (settings == null || plan == null || !settings.fullScreen) return;
    final now = ref.read(adhanClockProvider)();
    final next = AdhanPlanner.nextCall(plan, now.add(const Duration(milliseconds: 1)));
    if (next == null) return;
    final wait = next.at.difference(now);
    if (wait > const Duration(days: 2)) return;
    _next?.cancel();
    _next = Timer(wait, () async {
      if (!ref.mounted) return;
      final event = AdhanEvent.fromAlarm(next, source: AdhanEventSource.foreground);
      if (!_handled.contains(event.key)) {
        final notifying = await ref.read(notificationServiceProvider).notificationsEnabled();
        if (!ref.mounted) return;
        present(event.copyWith(playInApp: !notifying));
      }
      _arm();
    });
  }
}

/// Whether the notification that launched the app has been read. Until
/// then [AdhanHost] keeps the app unpainted: a cold start from the adhan's
/// full-screen intent runs over the lock screen, and nothing personal may
/// flash there before the adhan screen covers it.
final adhanLaunchCheckedProvider = NotifierProvider<AdhanLaunchChecked, bool>(AdhanLaunchChecked.new);

class AdhanLaunchChecked extends Notifier<bool> {
  @override
  bool build() => false;

  void done() => state = true;
}

/// Whether [AdhanHost] keeps the app unpainted after an adhan that may have
/// shown over the lock screen closed: raised by [AdhanEventHub.dismiss],
/// lifted as soon as the keyguard is found unlocked (checked right away,
/// whenever the app returns to the foreground and every [poll] while
/// raised). Nothing personal is ever painted over the keyguard while the
/// window is dropping behind it.
final adhanVeilProvider = NotifierProvider<AdhanVeil, bool>(AdhanVeil.new);

class AdhanVeil extends Notifier<bool> {
  static const poll = Duration(milliseconds: 750);

  Timer? _timer;
  int _generation = 0;

  @override
  bool build() {
    final foreground = ref.watch(appForegroundProvider);
    void onForeground() {
      if (state && foreground.value) unawaited(_check());
    }

    foreground.addListener(onForeground);
    ref.onDispose(() {
      foreground.removeListener(onForeground);
      _timer?.cancel();
    });
    return false;
  }

  /// Veils the app until the keyguard is unlocked.
  void raise() {
    if (!ref.mounted) return;
    state = true;
    _timer?.cancel();
    _timer = Timer.periodic(poll, (_) => unawaited(_check()));
    unawaited(_check());
  }

  void lift() {
    if (!ref.mounted) return;
    _generation++;
    _timer?.cancel();
    _timer = null;
    if (state) state = false;
  }

  Future<void> _check() async {
    final generation = _generation;
    bool locked;
    try {
      locked = await ref.read(adhanSystemProvider).isKeyguardLocked();
    } catch (_) {
      locked = false;
    }
    if (!ref.mounted || generation != _generation || !state) return;
    if (!locked) lift();
  }
}

// ---------------------------------------------------------------------------
// Prayer quiet: auto-mute game music and ambience

/// Holds a prayer-mute lease from each adhan until the settings' quiet time
/// after it (at least while the adhan sounds), while Madar is open. The
/// adhan screen holds its own lease while it shows.
final adhanQuietProvider = NotifierProvider<AdhanQuietGuard, QuietWindow?>(AdhanQuietGuard.new);

class AdhanQuietGuard extends Notifier<QuietWindow?> {
  Timer? _timer;
  PrayerMuteLease? _lease;

  @override
  QuietWindow? build() {
    ref.listen(adhanSettingsProvider, (_, _) => _evaluate());
    ref.listen(adhanTimesReadyProvider, (_, _) => _evaluate());
    ref.listen(adhanTimesProvider, (_, _) => _evaluate());
    ref.listen(adhanEventProvider, (_, _) => _evaluate());
    final foreground = ref.read(appForegroundProvider);
    void onForeground() => _evaluate();
    foreground.addListener(onForeground);
    ref.onDispose(() {
      foreground.removeListener(onForeground);
      _timer?.cancel();
      _lease?.release();
    });
    Timer.run(_evaluate);
    return null;
  }

  static List<DateTime> adhanTimesAround(AdhanSettings settings, AdhanTimes times, DateTime now) {
    final today = times.localDayOf(now);
    final out = <DateTime>[];
    for (final offset in const [-1, 0, 1]) {
      final day = DateTime.utc(today.year, today.month, today.day + offset);
      final t = times.timesFor(day);
      for (final slot in AdhanSlot.prayers) {
        final at = t[slot];
        if (at != null && settings.alertOf(slot).adhan) out.add(at);
      }
    }
    out.sort();
    return out;
  }

  void _evaluate() {
    if (!ref.mounted) return;
    _timer?.cancel();
    final settings = ref.read(adhanSettingsProvider).value;
    if (settings == null || !ref.read(adhanTimesReadyProvider)) return;
    final now = ref.read(adhanClockProvider)();
    final times = ref.read(adhanTimesProvider);
    final adhans = adhanTimesAround(settings, times, now);
    final length = settings.soundFor(AdhanSlot.dhuhr).tone?.length ?? const Duration(minutes: 4);
    final window = QuietWindow.covering(
      adhans,
      now,
      quiet: Duration(minutes: settings.quietMinutes),
      adhanLength: length,
    );
    if (window != null) {
      _lease ??= ref.read(prayerMuteProvider).acquire('adhan quiet');
    } else {
      _lease?.release();
      _lease = null;
    }
    if (state != window) state = window;
    // Wake at the window's end or the next adhan.
    DateTime? wake = window?.end;
    for (final t in adhans) {
      if (t.isAfter(now) && (wake == null || t.isBefore(wake))) wake = t;
    }
    if (wake != null) {
      final wait = wake.difference(now) + const Duration(milliseconds: 50);
      if (wait < const Duration(days: 1)) {
        // Reading providers above may have re-entered _evaluate: never leak
        // the timer it armed.
        _timer?.cancel();
        _timer = Timer(wait, _evaluate);
      }
    }
  }
}
