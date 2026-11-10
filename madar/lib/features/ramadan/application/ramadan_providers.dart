import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/repositories/repositories.dart';
import '../../../core/notifications/notification_models.dart';
import '../../../core/notifications/notification_providers.dart';
import '../../../core/settings/app_settings.dart';
import '../../home/home_providers.dart' show appForegroundProvider, homeNowProvider;
import '../../notification_center/data/center_hooks.dart' show notificationReplanHooksProvider;
import '../../notification_center/data/center_providers.dart' show notificationDescribersProvider;
import '../../orbit/data/orbit_providers.dart'
    show orbitClockProvider, orbitRepositoryProvider, orbitTodayProvider, prayerScheduleProvider, prayerSettingsProvider;
import '../../prayer/application/prayer_settings_controller.dart' show prayerSettingsControllerProvider;
import '../data/ramadan_background.dart';
import '../data/ramadan_describer.dart';
import '../data/ramadan_notifications.dart';
import '../data/ramadan_repository.dart';
import '../data/ramadan_texts.dart';
import '../domain/khatmah_plan.dart';
import '../domain/khatmah_record.dart';
import '../domain/qadr_supplication.dart';
import '../domain/ramadan_calendar.dart';
import '../domain/ramadan_config.dart';
import '../domain/ramadan_today.dart';
import '../domain/ramadan_year_log.dart';
import '../domain/taraweeh_log.dart';

// ---------------------------------------------------------------------------
// Records

final ramadanRepositoryProvider = Provider<RamadanRepository>(
  (ref) => RamadanRepository(ref.watch(repositoriesProvider).keyValues),
);

/// The stored config (the atmosphere, which reminders are on and their lead).
final ramadanStoredConfigProvider = StreamProvider<RamadanConfig>(
  (ref) => ref.watch(ramadanRepositoryProvider).watchConfig(),
);

final ramadanConfigProvider = Provider<RamadanConfig>(
  (ref) => ref.watch(ramadanStoredConfigProvider).value ?? const RamadanConfig(),
);

/// Every year's log, side by side.
final ramadanLogBookProvider = StreamProvider<RamadanLogBook>(
  (ref) => ref.watch(ramadanRepositoryProvider).watchLogBook(),
);

final ramadanKhatmahsProvider = StreamProvider<Map<int, KhatmahRecord>>(
  (ref) => ref.watch(ramadanRepositoryProvider).watchKhatmahs(),
);

/// The supplication he typed (null until he does).
final ramadanSupplicationProvider = StreamProvider<QadrSupplication?>(
  (ref) => ref.watch(ramadanRepositoryProvider).watchSupplication(),
);

// ---------------------------------------------------------------------------
// The month, derived

/// The app's clock (so tests freeze it).
final ramadanClockProvider = Provider<DateTime Function()>((ref) => ref.watch(orbitClockProvider));

/// Ramadan on the Hijri calendar **with the prayer settings' day shift laid
/// over it** - the same setting Part 9b's fasting rules use, so the date shown
/// in the prayer times, the fasting reminders and Ramadan's first day can
/// never disagree.
final ramadanCalendarProvider = Provider<RamadanCalendar>((ref) {
  final offset = ref.watch(prayerSettingsProvider.select((s) => s.value?.hijriOffsetDays ?? 0));
  return RamadanCalendar(offsetDays: offset);
});

/// Today in Ramadan terms; turns by itself at local midnight (and when the
/// app returns to the foreground), so the month starts and ends with no
/// action from him - also when the app was closed across the start or the Eid.
final ramadanStatusProvider = Provider<RamadanStatus>(
  (ref) => ref.watch(ramadanCalendarProvider).statusOn(ref.watch(orbitTodayProvider)),
);

/// The Faith planet's Ramadan atmosphere: on from the first day, off on
/// 1 Shawwal, and only while he has not switched «أجواء رمضان» off.
final ramadanAtmosphereProvider = Provider<bool>(
  (ref) => ref.watch(ramadanConfigProvider.select((c) => c.atmosphere)) && ref.watch(ramadanStatusProvider).atmosphereOn,
);

/// Where Ramadan stands now, to the minute (the home clock ticks at every
/// minute and at every prayer start, so it turns exactly at Maghrib): the day,
/// the night, the countdown's target. The seconds are the widget's own ticker.
final ramadanTodayProvider = Provider.autoDispose<RamadanToday>((ref) {
  final now = ref.watch(homeNowProvider);
  final schedule = ref.watch(prayerScheduleProvider);
  return RamadanToday.compute(
    now: schedule.wallClock(now),
    calendar: ref.watch(ramadanCalendarProvider),
    timesOf: schedule.timesFor,
  );
});

/// The Ramadan the screens work on: the one being lived, else the next.
final ramadanFocusSpanProvider = Provider.autoDispose<RamadanSpan>((ref) {
  final today = ref.watch(ramadanTodayProvider);
  return today.span ?? ref.watch(ramadanCalendarProvider).nextSpanAfter(today.date);
});

/// The khatmah of the focus Ramadan: what is stored, else the default plan
/// (shown and used as is; the first change stores it).
final ramadanKhatmahProvider = Provider.autoDispose<KhatmahRecord>((ref) {
  final span = ref.watch(ramadanFocusSpanProvider);
  return ref.watch(ramadanKhatmahsProvider).value?[span.hijriYear] ?? KhatmahRecord.defaultFor(span);
});

/// Today's portion and the re-planned rest.
final ramadanKhatmahTodayProvider = Provider.autoDispose<KhatmahToday>((ref) {
  final record = ref.watch(ramadanKhatmahProvider);
  return record.plan.today(ref.watch(ramadanTodayProvider).date, record.progress);
});

/// The Hijri year the Taraweeh log shows: the one being lived; outside
/// Ramadan the newest year he logged (null when there is none).
final ramadanLogYearProvider = Provider.autoDispose<int?>((ref) {
  final today = ref.watch(ramadanTodayProvider);
  return today.hijriYear ?? ref.watch(ramadanLogBookProvider).value?.years.firstOrNull;
});

// ---------------------------------------------------------------------------
// Writing

/// Undoes one change.
typedef RamadanUndo = Future<void> Function();

/// Every write of «رمضان»; each returns its undo closure.
class RamadanService {
  RamadanService(this._ref);

  final Ref _ref;

  RamadanRepository get _repo => _ref.read(ramadanRepositoryProvider);

  /// The one-tap button: marks night [night] done, or clears it when it was.
  /// A rakaat count or note already written is kept when un-marking.
  Future<RamadanUndo> toggleTaraweeh(int hijriYear, int night) async {
    final book = await _repo.logBook();
    final current = book.of(hijriYear)?.taraweeh.entryOf(night);
    final next = current == null ? TaraweehEntry(night: night) : current.copyWith(done: !current.done);
    final previous = await _repo.setTaraweeh(hijriYear, night, next);
    return () async {
      await _repo.setTaraweeh(hijriYear, night, previous);
    };
  }

  /// Sets how many rakaat night [night] had (null clears it). A count means
  /// the night was prayed, so it marks the night done.
  Future<RamadanUndo> setRakaat(int hijriYear, int night, int? rakaat) async {
    final book = await _repo.logBook();
    final current = book.of(hijriYear)?.taraweeh.entryOf(night);
    final base = current ?? TaraweehEntry(night: night, done: false);
    final count = rakaat?.clamp(0, 99);
    final next = base.copyWith(done: count != null && count > 0 ? true : base.done, rakaat: count, clearRakaat: count == null);
    final previous = await _repo.setTaraweeh(hijriYear, night, next);
    return () async {
      await _repo.setTaraweeh(hijriYear, night, previous);
    };
  }

  /// His note for night [night] (blank clears it). A note alone does not mark
  /// the night prayed.
  Future<RamadanUndo> setNightNote(int hijriYear, int night, String note) async {
    final book = await _repo.logBook();
    final current = book.of(hijriYear)?.taraweeh.entryOf(night);
    final text = note.trim();
    TaraweehEntry? next;
    if (current == null) {
      if (text.isNotEmpty) next = TaraweehEntry(night: night, done: false, note: text);
    } else {
      final changed = current.copyWith(note: text.isEmpty ? null : text, clearNote: text.isEmpty);
      // An entry that says nothing any more is removed.
      next = (!changed.done && changed.rakaat == null && changed.note == null) ? null : changed;
    }
    final previous = await _repo.setTaraweeh(hijriYear, night, next);
    return () async {
      await _repo.setTaraweeh(hijriYear, night, previous);
    };
  }

  /// Marks today's whole portion read ([read] true) or takes today's reading
  /// back ([read] false). Works on the plan shown (the default until stored).
  Future<RamadanUndo> setKhatmahTodayRead(bool read) async {
    final record = _ref.read(ramadanKhatmahProvider);
    final today = _ref.read(ramadanTodayProvider).date;
    final plan = record.plan;
    final index = plan.dayIndexOf(today).clamp(0, plan.days);
    final KhatmahProgress progress;
    if (read) {
      final portion = plan.today(today, record.progress).portion;
      progress = record.progress.markPortionRead(index, portion, totalPages: plan.totalPages);
    } else {
      progress = record.progress.markReadThrough(index, record.progress.frontierBefore(index), totalPages: plan.totalPages);
    }
    return _saveKhatmah(record.copyWith(progress: progress));
  }

  /// The most pages a day may ask for. The plan never goes above it.
  Future<RamadanUndo> setKhatmahCeiling(int pages) {
    final record = _ref.read(ramadanKhatmahProvider);
    return _saveKhatmah(record.copyWith(plan: record.plan.copyWith(ceilingPages: pages.clamp(1, record.plan.totalPages))));
  }

  Future<RamadanUndo> _saveKhatmah(KhatmahRecord next) async {
    final year = next.hijriYear;
    final previous = await _repo.setKhatmah(next);
    return () => _repo.restoreKhatmah(year, previous);
  }

  /// What he typed for the last ten nights (null clears it).
  Future<RamadanUndo> saveSupplication(QadrSupplication? value) async {
    final previous = await _repo.saveSupplication(value);
    return () async {
      await _repo.saveSupplication(previous);
    };
  }

  /// Changes the stored config. Undo puts the old one back.
  Future<RamadanUndo> changeConfig(RamadanConfig Function(RamadanConfig current) change) async {
    final before = await _repo.config();
    final next = change(before);
    if (next == before) return () async {};
    await _repo.saveConfig(next);
    return () => _repo.saveConfig(before);
  }

  /// Sets the Hijri day shift - the prayer settings' own `hijriOffsetDays`.
  /// Undo puts the old prayer settings back.
  Future<RamadanUndo> setHijriShift(int days) async {
    final controller = _ref.read(prayerSettingsControllerProvider.notifier);
    final before = await controller.setHijriOffset(days);
    return () => controller.restore(before);
  }
}

final ramadanServiceProvider = Provider<RamadanService>(RamadanService.new);

// ---------------------------------------------------------------------------
// Texts and the scheduler

/// Notification / screen texts in the app's language and digit style.
final ramadanTextsProvider = Provider<RamadanTexts>((ref) {
  final (language, digits) = ref.watch(appSettingsProvider.select((s) => (s.languageCode, s.digits)));
  return RamadanTexts.forLanguage(language, digits: digits);
});

final ramadanSchedulerProvider = Provider<RamadanScheduler>(
  (ref) => RamadanScheduler(
    notifications: ref.watch(notificationServiceProvider),
    clock: ref.watch(ramadanClockProvider),
  ),
);

// ---------------------------------------------------------------------------
// Auto re-scheduling

@immutable
class RamadanSyncState {
  const RamadanSyncState({this.last, this.syncing = false, this.error, this.crossed = RamadanBoundaries.none});

  final RamadanSyncResult? last;
  final bool syncing;
  final Object? error;

  /// The edges of Ramadan (its first day, the Eid) the calendar crossed
  /// between the previous run and this one - set when the app was closed
  /// across one of them.
  final RamadanBoundaries crossed;
}

/// Keeps Ramadan's reminders planned: at start, and whenever the switches,
/// the prayer settings (the Hijri shift, the location, the calculation - Fajr,
/// Maghrib and Isha move with them), the language or the day change; when the
/// app returns to the foreground after a time-zone change or more than
/// [refreshAfter]; and after a restore (the centre's re-plan hook,
/// [ramadanRegistrationProvider]). Watched once from the app shell.
///
/// It reads the records and the prayer settings fresh from the database on
/// every run, never from a provider's cached state - so a run right after a
/// restore sees the restored data and never the old.
final ramadanSyncProvider = NotifierProvider<RamadanSync, RamadanSyncState>(RamadanSync.new);

class RamadanSync extends Notifier<RamadanSyncState> {
  static const debounce = Duration(milliseconds: 350);
  static const refreshAfter = Duration(hours: 6);

  Timer? _debounce;
  Future<RamadanSyncResult?>? _running;
  bool _again = false;
  Duration? _offset;

  @override
  RamadanSyncState build() {
    ref.listen(ramadanStoredConfigProvider, (_, _) => _schedule());
    ref.listen(prayerSettingsProvider, (_, _) => _schedule());
    ref.listen(ramadanTextsProvider, (_, _) => _schedule());
    ref.listen(orbitTodayProvider, (_, _) => _schedule());
    final foreground = ref.read(appForegroundProvider);
    void onResume() {
      if (!foreground.value) return;
      final now = ref.read(ramadanClockProvider)();
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
    return const RamadanSyncState();
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(debounce, () => unawaited(syncNow()));
  }

  /// Plans now (awaits a running sync and runs once more after it).
  Future<RamadanSyncResult?> syncNow() async {
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

  Future<RamadanSyncResult?> _run() async {
    if (!ref.mounted) return null;
    state = RamadanSyncState(last: state.last, syncing: true, crossed: state.crossed);
    try {
      final repo = ref.read(ramadanRepositoryProvider);
      final prayer = await ref.read(orbitRepositoryProvider).prayerSettings();
      final config = await repo.config();
      final lastSeen = await repo.lastSeen();
      if (!ref.mounted) return null;
      final schedule = ref.read(orbitRepositoryProvider).scheduleFor(prayer);
      final calendar = RamadanCalendar(offsetDays: prayer.hijriOffsetDays);
      final now = ref.read(ramadanClockProvider)();
      // The app may have been closed across the first day or the Eid: say so
      // (the month itself needs no catching up - it is derived from the date
      // every time, so the atmosphere is already right).
      final crossed = lastSeen == null ? RamadanBoundaries.none : calendar.boundariesBetween(lastSeen, now);
      final result = await ref
          .read(ramadanSchedulerProvider)
          .sync(
            config: config,
            calendar: calendar,
            timesOf: schedule.timesFor,
            texts: ref.read(ramadanTextsProvider),
            wallClock: schedule.wallClock,
          );
      await repo.setLastSeen(DateTime(now.year, now.month, now.day));
      _offset = now.timeZoneOffset;
      if (ref.mounted) state = RamadanSyncState(last: result, crossed: crossed);
      return result;
    } catch (e, s) {
      debugPrint('RamadanSync failed: $e\n$s');
      if (ref.mounted) state = RamadanSyncState(last: state.last, error: e, crossed: state.crossed);
      return null;
    }
  }
}

// ---------------------------------------------------------------------------
// «صلّيت» answered on the notification

/// Handles «صلّيت» while Madar is running: taps that reach the app, and
/// answers the background isolate forwards over its port
/// ([RamadanActionReceiver]) - one database connection writes the night and
/// the screen updates at once. With the app closed the background entry point
/// writes it itself.
final ramadanBridgeProvider = Provider<RamadanBridge>((ref) {
  final bridge = RamadanBridge(ref);
  ref.onDispose(bridge.dispose);
  return bridge;
});

class RamadanBridge {
  RamadanBridge(this._ref) {
    _receiver = RamadanActionReceiver(handle)..open();
    _taps = _ref.read(notificationServiceProvider).taps.listen(_onTap);
  }

  final Ref _ref;
  late final RamadanActionReceiver _receiver;
  late final StreamSubscription<NotificationTap> _taps;

  void _onTap(NotificationTap tap) {
    if (!RamadanNotificationTaps.isRamadan(tap) || tap.actionId == null) return;
    unawaited(handle(tap));
  }

  /// Handles one answer; true when the app dealt with it (the background
  /// isolate then does nothing).
  Future<bool> handle(NotificationTap tap) async {
    final answer = RamadanNotificationTaps.prayedOf(tap);
    if (answer == null || !_ref.mounted) return false;
    try {
      await _ref.read(ramadanRepositoryProvider).markTaraweehDone(answer.hijriYear, answer.night);
      return true;
    } catch (e) {
      debugPrint('ramadan: handling an answer in the app failed: $e');
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

/// Registers «رمضان» with the notification centre, once, before the first
/// plan reaches the gate:
///
/// * its describer - the Prayer group, so a Faith mute holds the reminders
///   and an un-mute re-arms them;
/// * its re-plan hook - the centre calls it after an un-mute, after loading a
///   policy and after a **restore**, so the restored records and settings are
///   what the alarms are planned from.
final ramadanRegistrationProvider = Provider<void>((ref) {
  ref.read(notificationDescribersProvider).register(const RamadanDescriber());
  ref.read(notificationReplanHooksProvider).register(NotificationNamespaces.ramadan.name, () async {
    if (ref.exists(ramadanSyncProvider)) await ref.read(ramadanSyncProvider.notifier).syncNow();
  });
});
