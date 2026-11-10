import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/repositories/repositories.dart';
import '../../../core/notifications/notification_models.dart';
import '../../../core/notifications/notification_providers.dart';
import '../../../core/settings/app_settings.dart';
import '../../home/home_providers.dart' show appForegroundProvider;
import '../../notification_center/data/center_hooks.dart' show notificationReplanHooksProvider;
import '../../notification_center/data/center_providers.dart' show notificationDescribersProvider;
import '../../orbit/data/orbit_providers.dart'
    show orbitClockProvider, orbitRepositoryProvider, orbitTodayProvider, prayerSettingsProvider;
import '../../orbit/domain/prayer_schedule.dart';
import '../../prayer/application/prayer_settings_controller.dart' show prayerSettingsControllerProvider;
import '../../wird/domain/calendar_days.dart';
import '../data/fasting_background.dart';
import '../data/fasting_describer.dart';
import '../data/fasting_notifications.dart';
import '../data/fasting_repository.dart';
import '../data/fasting_texts.dart';
import '../domain/fasting_log.dart';
import '../domain/fasting_models.dart';
import '../domain/fasting_overview.dart';
import '../domain/fasting_rules.dart';

// ---------------------------------------------------------------------------
// Records

final fastingRepositoryProvider = Provider<FastingRepository>(
  (ref) => FastingRepository(ref.watch(repositoriesProvider).keyValues),
);

/// The stored config (which kinds are on, the Shawwal start day). Its Hijri
/// shift is the prayer settings' - see [fastingConfigProvider].
final fastingStoredConfigProvider = StreamProvider<FastingConfig>(
  (ref) => ref.watch(fastingRepositoryProvider).watchConfig(),
);

final fastingIntentionsProvider = StreamProvider<List<FastIntention>>(
  (ref) => ref.watch(fastingRepositoryProvider).watchIntentions(),
);

final fastingLogProvider = StreamProvider<List<FastLogEntry>>(
  (ref) => ref.watch(fastingRepositoryProvider).watchLog(),
);

/// The config every rule runs on: the stored switches with the **prayer
/// settings' Hijri day shift** laid over them. One setting, never two: the
/// date shown in the prayer times and the day a reminder falls on cannot
/// disagree.
final fastingConfigProvider = Provider<FastingConfig>((ref) {
  final stored = ref.watch(fastingStoredConfigProvider).value ?? const FastingConfig();
  final offset = ref.watch(prayerSettingsProvider.select((s) => s.value?.hijriOffsetDays ?? 0));
  return stored.copyWith(hijriOffset: offset);
});

/// Today (the app's clock, so tests freeze it).
final fastingClockProvider = Provider<DateTime Function()>((ref) => ref.watch(orbitClockProvider));

// ---------------------------------------------------------------------------
// Writing

/// Undoes one change.
typedef FastingUndo = Future<void> Function();

/// Every write of «صيامي»; each returns its undo closure.
class FastingService {
  FastingService(this._ref);

  final Ref _ref;

  FastingRepository get _repo => _ref.read(fastingRepositoryProvider);

  /// «ناوي» / «لأ» for [day]. Undo puts back what the day held before.
  Future<FastingUndo> answer(DateTime day, FastIntentionChoice choice) async {
    final previous = await _repo.setIntention(FastIntention(day: day, choice: choice));
    return () async {
      if (previous == null) {
        await _repo.removeIntention(day);
      } else {
        await _repo.setIntention(previous);
      }
    };
  }

  /// Logs that he fasted [day] (today by default): the kind it carried, if
  /// the rules gave it one. Undo puts back what the day held before.
  Future<FastingUndo> logFasted(DateTime day, {FastLogSource source = FastLogSource.manual}) async {
    final config = _ref.read(fastingConfigProvider);
    final entry = FastLogEntry(
      day: day,
      kind: FastingRules.reminderOn(day, config)?.kind,
      fasted: true,
      source: source,
    );
    final previous = await _repo.setLogEntry(entry);
    return () async {
      if (previous == null) {
        await _repo.removeLogEntry(day);
      } else {
        await _repo.setLogEntry(previous);
      }
    };
  }

  /// Takes [day] out of the log. Undo puts the entry back.
  Future<FastingUndo> removeLog(DateTime day) async {
    final removed = await _repo.removeLogEntry(day);
    return () async {
      if (removed != null) await _repo.setLogEntry(removed);
    };
  }

  /// Changes the stored config. Undo puts the old one back.
  Future<FastingUndo> changeConfig(FastingConfig Function(FastingConfig current) change) async {
    final before = await _repo.config();
    final next = change(before);
    if (next == before) return () async {};
    await _repo.saveConfig(next);
    return () => _repo.saveConfig(before);
  }

  /// Sets the Hijri day shift - the prayer settings' own `hijriOffsetDays`.
  /// Undo puts the old prayer settings back.
  Future<FastingUndo> setHijriShift(int days) async {
    final controller = _ref.read(prayerSettingsControllerProvider.notifier);
    final before = await controller.setHijriOffset(days);
    return () => controller.restore(before);
  }
}

final fastingServiceProvider = Provider<FastingService>(FastingService.new);

// ---------------------------------------------------------------------------
// Texts and the scheduler

/// Notification / screen texts in the app's language and digit style.
final fastingTextsProvider = Provider<FastingTexts>((ref) {
  final (language, digits) = ref.watch(appSettingsProvider.select((s) => (s.languageCode, s.digits)));
  return FastingTexts.forLanguage(language, digits: digits);
});

final fastingSchedulerProvider = Provider<FastingScheduler>(
  (ref) => FastingScheduler(
    notifications: ref.watch(notificationServiceProvider),
    clock: ref.watch(fastingClockProvider),
  ),
);

/// The next reminders and what he answered, for the screen.
final fastingUpcomingProvider = Provider<List<UpcomingFast>>((ref) {
  final today = CalendarDays.dateOnly(ref.watch(orbitTodayProvider));
  return FastingOverview.upcoming(
    config: ref.watch(fastingConfigProvider),
    today: today,
    intentions: ref.watch(fastingIntentionsProvider).value ?? const [],
    log: ref.watch(fastingLogProvider).value ?? const [],
  );
});

// ---------------------------------------------------------------------------
// Auto re-scheduling

@immutable
class FastingSyncState {
  const FastingSyncState({this.last, this.syncing = false, this.error});

  final FastingSyncResult? last;
  final bool syncing;
  final Object? error;
}

/// Keeps the next 21 days of reminders planned: at start, and whenever the
/// switches, his answers or log, the prayer settings (the Hijri shift, the
/// location, the calculation - Isha moves with them), the language or the
/// day change; when the app returns to the foreground after a time-zone
/// change or more than [refreshAfter]; and after a restore (the centre's
/// re-plan hook, [fastingRegistrationProvider]). Watched once from the app
/// shell.
///
/// It reads the records and the prayer settings fresh from the database on
/// every run, never from a provider's cached state - so a run right after a
/// restore sees the restored data and never the old.
final fastingSyncProvider = NotifierProvider<FastingSync, FastingSyncState>(FastingSync.new);

class FastingSync extends Notifier<FastingSyncState> {
  static const debounce = Duration(milliseconds: 350);
  static const refreshAfter = Duration(hours: 6);

  Timer? _debounce;
  Future<FastingSyncResult?>? _running;
  bool _again = false;
  Duration? _offset;

  @override
  FastingSyncState build() {
    ref.listen(fastingStoredConfigProvider, (_, _) => _schedule());
    ref.listen(fastingIntentionsProvider, (_, _) => _schedule());
    ref.listen(fastingLogProvider, (_, _) => _schedule());
    ref.listen(prayerSettingsProvider, (_, _) => _schedule());
    ref.listen(fastingTextsProvider, (_, _) => _schedule());
    ref.listen(orbitTodayProvider, (_, _) => _schedule());
    final foreground = ref.read(appForegroundProvider);
    void onResume() {
      if (!foreground.value) return;
      final now = ref.read(fastingClockProvider)();
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
    return const FastingSyncState();
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(debounce, () => unawaited(syncNow()));
  }

  /// Plans now (awaits a running sync and runs once more after it).
  Future<FastingSyncResult?> syncNow() async {
    _debounce?.cancel();
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

  Future<FastingSyncResult?> _run() async {
    if (!ref.mounted) return null;
    state = FastingSyncState(last: state.last, syncing: true);
    try {
      final repo = ref.read(fastingRepositoryProvider);
      final prayer = await ref.read(orbitRepositoryProvider).prayerSettings();
      final stored = await repo.config();
      final intentions = await repo.intentions();
      final log = await repo.log();
      if (!ref.mounted) return null;
      final schedule = ref.read(orbitRepositoryProvider).scheduleFor(prayer);
      final result = await ref
          .read(fastingSchedulerProvider)
          .sync(
            config: stored.copyWith(hijriOffset: prayer.hijriOffsetDays),
            intentions: intentions,
            log: log,
            ishaOf: ishaOf(schedule),
            texts: ref.read(fastingTextsProvider),
          );
      _offset = ref.read(fastingClockProvider)().timeZoneOffset;
      if (ref.mounted) state = FastingSyncState(last: result);
      return result;
    } catch (e, s) {
      debugPrint('FastingSync failed: $e\n$s');
      if (ref.mounted) state = FastingSyncState(last: state.last, error: e);
      return null;
    }
  }

  /// Isha of a civil day from the prayer schedule (null if it cannot be
  /// computed - the planner then falls back to 21:00).
  static DateTime? Function(DateTime day) ishaOf(PrayerSchedule schedule) => (day) {
    try {
      return schedule.timesFor(day).isha;
    } catch (_) {
      return null;
    }
  };
}

// ---------------------------------------------------------------------------
// Answers given on the notification

/// Handles «ناوي» and «لأ» while Madar is running: taps that reach the app,
/// and answers the background isolate forwards over its port
/// ([FastingActionReceiver]) - one database connection writes the single
/// record and the screen updates at once. With the app closed the
/// background entry point writes it itself.
final fastingBridgeProvider = Provider<FastingBridge>((ref) {
  final bridge = FastingBridge(ref);
  ref.onDispose(bridge.dispose);
  return bridge;
});

class FastingBridge {
  FastingBridge(this._ref) {
    _receiver = FastingActionReceiver(handle)..open();
    _taps = _ref.read(notificationServiceProvider).taps.listen(_onTap);
  }

  final Ref _ref;
  late final FastingActionReceiver _receiver;
  late final StreamSubscription<NotificationTap> _taps;

  void _onTap(NotificationTap tap) {
    if (!FastingNotificationTaps.isFasting(tap) || tap.actionId == null) return;
    unawaited(handle(tap));
  }

  /// Handles one answer; true when the app dealt with it (the background
  /// isolate then does nothing).
  Future<bool> handle(NotificationTap tap) async {
    final answer = FastingNotificationTaps.answerOf(tap);
    if (answer == null || !_ref.mounted) return false;
    try {
      await _ref.read(fastingServiceProvider).answer(answer.day, answer.choice);
      return true;
    } catch (e) {
      debugPrint('fasting: handling an answer in the app failed: $e');
      return false;
    }
  }

  void dispose() {
    _receiver.close();
    unawaited(_taps.cancel());
  }
}

// ---------------------------------------------------------------------------
// Joining the notification centre

/// Registers «صيامي» with the notification centre, once, before the first
/// plan reaches the gate:
///
/// * its describer - the Prayer group, so a Faith mute holds the reminders
///   and an un-mute re-arms them;
/// * its re-plan hook - the centre calls it after an un-mute, after loading
///   a policy and after a **restore**, so the restored records and settings
///   are what the alarms are planned from.
final fastingRegistrationProvider = Provider<void>((ref) {
  ref.read(notificationDescribersProvider).register(const FastingDescriber());
  ref.read(notificationReplanHooksProvider).register(NotificationNamespaces.fasting.name, () async {
    if (ref.exists(fastingSyncProvider)) await ref.read(fastingSyncProvider.notifier).syncNow();
  });
});
