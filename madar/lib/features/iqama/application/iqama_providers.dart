import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart' show PrayerLogRow;
import '../../../core/db/repositories/repositories.dart';
import '../../../core/domain/enums.dart';
import '../../../core/notifications/notification_models.dart';
import '../../../core/notifications/notification_providers.dart';
import '../../../core/settings/app_settings.dart';
import '../../adhan/application/adhan_providers.dart'
    show adhanClockProvider, adhanSettingsProvider, adhanSystemProvider, adhanTimesProvider, adhanTimesReadyProvider;
import '../../adhan/domain/adhan_settings.dart';
import '../../home/home_providers.dart' show appForegroundProvider;
import '../../orbit/data/orbit_providers.dart' show orbitTodayProvider, prayerScheduleProvider;
import '../../orbit/presentation/prayer/prayer_sheet.dart' show prayerLogServiceProvider;
import '../../prayer_tracker/domain/tracker_prayers.dart';
import '../data/iqama_background.dart';
import '../data/iqama_scheduler.dart';
import '../data/iqama_settings_repository.dart';
import '../data/iqama_texts.dart';
import '../domain/iqama_event.dart';
import '../domain/iqama_settings.dart';

// ---------------------------------------------------------------------------
// Settings

final iqamaSettingsRepositoryProvider = Provider<IqamaSettingsRepository>(
  (ref) => IqamaSettingsRepository(ref.watch(repositoriesProvider).keyValues),
);

/// The iqama settings (encrypted `key_values`), live.
final iqamaSettingsProvider = StreamNotifierProvider<IqamaSettingsController, IqamaSettings>(
  IqamaSettingsController.new,
);

class IqamaSettingsController extends StreamNotifier<IqamaSettings> {
  @override
  Stream<IqamaSettings> build() => ref.watch(iqamaSettingsRepositoryProvider).watch();

  /// Applies [change] and stores the result (the stream then re-plans the
  /// iqamas through [iqamaSyncProvider]).
  Future<IqamaSettings> change(IqamaSettings Function(IqamaSettings current) change) async {
    final repo = ref.read(iqamaSettingsRepositoryProvider);
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

/// Notification / screen texts in the app's language and digit style,
/// prayer times on the location's clock.
final iqamaTextsProvider = Provider<IqamaTexts>((ref) {
  final (language, digits) = ref.watch(appSettingsProvider.select((s) => (s.languageCode, s.digits)));
  final schedule = ref.watch(prayerScheduleProvider);
  return IqamaTexts.forLanguage(
    language,
    digits: digits,
    wallClock: schedule.wallClock,
    clock24h: schedule.settings.clock24h,
  );
});

final iqamaSchedulerProvider = Provider<IqamaScheduler>(
  (ref) => IqamaScheduler(
    notifications: ref.watch(notificationServiceProvider),
    system: ref.watch(adhanSystemProvider),
    clock: ref.watch(adhanClockProvider),
  ),
);

/// Logs a prayer as prayed from an iqama answer. Defaults to the prayer
/// tracker (through the orbit's `PrayerLogService`, so the Faith world
/// pulses exactly as it does when he taps the tracker's own button).
final iqamaLogPrayedProvider = Provider<Future<void> Function(DateTime day, Prayer prayer)>(
  (ref) => (day, prayer) async {
    await ref.read(prayerLogServiceProvider).log(day, prayer, PrayerStatus.prayed);
  },
);

/// Reads the log of a prayer (null = not logged), so an answer never
/// writes a second row over one he made by hand.
final iqamaLogOfProvider = Provider<Future<PrayerLogRow?> Function(DateTime day, Prayer prayer)>(
  (ref) => (day, prayer) => ref.read(prayerLogServiceProvider).logOf(day, prayer),
);

// ---------------------------------------------------------------------------
// Auto re-scheduling

@immutable
class IqamaSyncState {
  const IqamaSyncState({this.last, this.syncing = false, this.error});

  final IqamaSyncResult? last;
  final bool syncing;
  final Object? error;

  IqamaSyncState copyWith({IqamaSyncResult? last, bool? syncing, Object? error, bool clearError = false}) =>
      IqamaSyncState(
        last: last ?? this.last,
        syncing: syncing ?? this.syncing,
        error: clearError ? null : error ?? this.error,
      );
}

/// Keeps the iqamas planned: on start, whenever the iqama settings, the
/// adhan settings (a prayer's adhan switched off takes its iqama with it),
/// the prayer settings, the language or the day change, and when the app
/// returns to the foreground after a time-zone change or more than
/// [refreshAfter]. Watched once from the app shell.
final iqamaSyncProvider = NotifierProvider<IqamaSync, IqamaSyncState>(IqamaSync.new);

class IqamaSync extends Notifier<IqamaSyncState> {
  static const debounce = Duration(milliseconds: 350);
  static const refreshAfter = Duration(hours: 6);

  Timer? _debounce;
  Future<IqamaSyncResult?>? _running;
  bool _again = false;
  Duration? _offset;

  @override
  IqamaSyncState build() {
    ref.listen(iqamaSettingsProvider, (_, _) => _schedule());
    ref.listen(adhanSettingsProvider, (_, _) => _schedule());
    ref.listen(adhanTimesReadyProvider, (_, _) => _schedule());
    ref.listen(adhanTimesProvider, (_, _) => _schedule());
    ref.listen(iqamaTextsProvider, (_, _) => _schedule());
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
    return const IqamaSyncState();
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(debounce, () => unawaited(syncNow()));
  }

  /// Plans now (awaits a running sync and runs once more after it).
  Future<IqamaSyncResult?> syncNow() async {
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

  Future<IqamaSyncResult?> _run() async {
    if (!ref.mounted) return null;
    final settings = ref.read(iqamaSettingsProvider).value;
    final adhan = ref.read(adhanSettingsProvider).value;
    if (settings == null || adhan == null || !ref.read(adhanTimesReadyProvider)) return null;
    state = state.copyWith(syncing: true);
    try {
      final times = ref.read(adhanTimesProvider);
      final result = await ref
          .read(iqamaSchedulerProvider)
          .sync(
            settings: settings,
            adhan: adhan,
            timesFor: times.timesFor,
            localDayOf: times.localDayOf,
            texts: ref.read(iqamaTextsProvider),
          );
      _offset = ref.read(adhanClockProvider)().timeZoneOffset;
      if (ref.mounted) state = IqamaSyncState(last: result);
      return result;
    } catch (e, s) {
      debugPrint('IqamaSync failed: $e\n$s');
      if (ref.mounted) state = state.copyWith(syncing: false, error: e);
      return null;
    }
  }
}

// ---------------------------------------------------------------------------
// Answers given on the notification

/// Handles «صلّيت» and «بعد شوي» while Madar is running: taps that reach
/// the app, and answers the background isolate forwards over its port
/// ([IqamaActionReceiver]) – then one database connection writes the row
/// and the tracker's lists update at once.
final iqamaBridgeProvider = Provider<IqamaBridge>((ref) {
  final bridge = IqamaBridge(ref);
  ref.onDispose(bridge.dispose);
  return bridge;
});

class IqamaBridge {
  IqamaBridge(this._ref) {
    _receiver = IqamaActionReceiver(handle)..open();
    _taps = _ref.read(notificationServiceProvider).taps.listen(_onTap);
  }

  final Ref _ref;
  late final IqamaActionReceiver _receiver;
  late final StreamSubscription<NotificationTap> _taps;

  void _onTap(NotificationTap tap) {
    if (!IqamaNotificationTaps.isIqama(tap) || tap.actionId == null) return;
    unawaited(handle(tap));
  }

  /// Handles one answer; true when the app dealt with it (the background
  /// isolate then does nothing).
  Future<bool> handle(NotificationTap tap) async {
    final answer = IqamaNotificationTaps.answerOf(tap);
    if (answer == null || !_ref.mounted) return false;
    try {
      return switch (answer.kind) {
        IqamaAnswerKind.prayed => await _log(answer),
        IqamaAnswerKind.later => await _snooze(answer),
      };
    } catch (e) {
      debugPrint('iqama: handling an answer in the app failed: $e');
      return false;
    }
  }

  Future<bool> _log(IqamaAnswer answer) async {
    final day = answer.localDay;
    final existing = await _ref.read(iqamaLogOfProvider)(day, answer.prayer);
    if (existing != null && existing.status.counts) {
      // Already logged by hand: no second row, and he is told why nothing
      // happened.
      await _notice(
        IqamaNotifications.alreadyLogged(
          slot: answer.slot,
          day: answer.day,
          texts: _ref.read(iqamaTextsProvider),
          now: _ref.read(adhanClockProvider)(),
        ),
      );
      return true;
    }
    await _ref.read(iqamaLogPrayedProvider)(day, answer.prayer);
    return true;
  }

  Future<bool> _snooze(IqamaAnswer answer) async {
    final now = _ref.read(adhanClockProvider)();
    final at = now.add(Duration(minutes: answer.snoozeMinutes));
    final next = answer.nextAdhanAt;
    // Its time is over before the snooze would call: nothing is armed, and
    // the answer is still "handled" (the isolate must not try again).
    if (next != null && !at.isBefore(next)) return true;
    final settings = _ref.read(iqamaSettingsProvider).value ?? const IqamaSettings();
    final adhan = _ref.read(adhanSettingsProvider).value ?? const AdhanSettings();
    final texts = _ref.read(iqamaTextsProvider);
    final channel = answer.channelId ?? await _ref.read(iqamaSchedulerProvider).ensureChannel(settings, adhan, texts);
    await _ref
        .read(notificationServiceProvider)
        .schedule(
          IqamaNotifications.request(
            answer.asAlarm(at: at),
            settings: settings,
            texts: texts,
            channelId: channel,
            snooze: true,
            at: at,
          ),
        );
    return true;
  }

  Future<void> _notice(NotificationRequest request) async {
    try {
      await _ref.read(notificationServiceProvider).show(request);
    } catch (e) {
      debugPrint('iqama: posting a notice failed: $e');
    }
  }

  void dispose() {
    _receiver.close();
    unawaited(_taps.cancel());
  }
}
