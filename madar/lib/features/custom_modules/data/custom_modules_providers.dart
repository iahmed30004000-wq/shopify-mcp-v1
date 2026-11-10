import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/repositories/repositories.dart';
import '../../../core/domain/enums.dart';
import '../../../core/notifications/notification_models.dart';
import '../../../core/notifications/notification_providers.dart';
import '../../../core/settings/app_settings.dart';
import '../../home/home_providers.dart' show homeClockProvider;
import '../../orbit/data/orbit_providers.dart' show orbitPulseHubProvider, orbitTodayProvider, prayerScheduleProvider;
import '../custom_texts.dart';
import '../domain/module_schema.dart';
import '../domain/module_summary.dart';
import 'custom_modules_notifications.dart';
import 'custom_modules_service.dart';

/// The wall clock of the Custom Modules screens (the home clock: tests
/// override either).
final customModulesClockProvider = Provider<DateTime Function()>((ref) => ref.watch(homeClockProvider));

/// Logs entry activity through the orbit's pulse hub (the planet pulses at
/// once).
final customModulesActivityRecorderProvider = Provider<CustomActivityRecorder>((ref) {
  final hub = ref.watch(orbitPulseHubProvider);
  return ({required planetKey, required kind, required refTable, required refId, required at, payload = const {}}) =>
      hub.recordCompletion(planetKey, kind, refTable, refId, at: at, payload: payload);
});

final customModulesServiceProvider = Provider<CustomModulesService>(
  (ref) => CustomModulesService(
    ref.watch(repositoriesProvider),
    clock: ref.watch(customModulesClockProvider),
    recorder: ref.watch(customModulesActivityRecorderProvider),
  ),
);

/// Every module (archived ones included), in the user's order.
final customModulesProvider = StreamProvider<List<ModuleDefinition>>(
  (ref) => ref.watch(customModulesServiceProvider).watchModules(),
);

/// Every entry, by module id.
final customModuleEntriesByModuleProvider = StreamProvider<Map<String, List<ModuleEntry>>>(
  (ref) => ref.watch(customModulesServiceProvider).watchAllEntries(),
);

/// One module (null once deleted).
final customModuleProvider = StreamProvider.autoDispose.family<ModuleDefinition?, String>(
  (ref, id) => ref.watch(customModulesServiceProvider).watchModule(id),
);

/// One module's entries (list order).
final customModuleEntriesProvider = StreamProvider.autoDispose.family<List<ModuleEntry>, String>(
  (ref, id) => ref.watch(customModulesServiceProvider).watchEntries(id),
);

/// One module's reminder rows.
final customModuleRemindersProvider = StreamProvider.autoDispose.family<List<ReminderRow>, String>(
  (ref, id) => ref.watch(customModulesServiceProvider).watchReminders(id),
);

/// The planets a module can attach to (built-in and user-added), in orbit
/// order, hidden ones left out.
final customPlanetChoicesProvider = StreamProvider<List<PlanetRow>>(
  (ref) => ref.watch(repositoriesProvider).planets.watchAll(where: (p) => p.hidden.equals(false)),
);

/// Planet key → name in the app's language (empty while loading).
final customPlanetNamesProvider = Provider<Map<String, String>>((ref) {
  final planets = ref.watch(customPlanetChoicesProvider).value ?? const [];
  final ar = ref.watch(appSettingsProvider.select((s) => s.languageCode)) != 'en';
  return {for (final p in planets) p.key: ar ? p.nameAr : p.nameEn};
});

/// Today (refreshed at local midnight, like the orbit).
final customModulesTodayProvider = Provider<DateTime>((ref) => ref.watch(orbitTodayProvider));

/// Tile / card summaries of every module at the current time.
final customModuleSummariesProvider = Provider<AsyncValue<List<ModuleSummary>>>((ref) {
  final modules = ref.watch(customModulesProvider);
  final entries = ref.watch(customModuleEntriesByModuleProvider);
  ref.watch(customModulesTodayProvider);
  final now = ref.watch(customModulesClockProvider)();
  if (modules case AsyncData(value: final ms)) {
    if (entries case AsyncData(value: final es)) {
      return AsyncData([for (final m in ms) ModuleSummary.build(m, es[m.id] ?? const [], now)]);
    }
  }
  if (modules case AsyncError(:final error, :final stackTrace)) return AsyncError(error, stackTrace);
  if (entries case AsyncError(:final error, :final stackTrace)) return AsyncError(error, stackTrace);
  return const AsyncLoading();
});

/// Live (not archived) modules attached to [planetKey], for planet hubs.
final customPlanetModulesProvider = Provider.family<AsyncValue<List<ModuleSummary>>, String>((ref, planetKey) {
  return ref
      .watch(customModuleSummariesProvider)
      .whenData((all) => [
            for (final s in all)
              if (!s.module.archived && s.module.planetKey == planetKey) s,
          ]);
});

/// Live trackers placed in [window] that have nothing logged today – for
/// the home panel's current prayer window ("log your reading after Fajr").
final customWindowModulesProvider = Provider.family<AsyncValue<List<ModuleSummary>>, PrayerWindow>((ref, window) {
  return ref
      .watch(customModuleSummariesProvider)
      .whenData((all) => [
            for (final s in all)
              if (!s.module.archived && s.module.isTracker && s.module.window == window && s.todayCount == 0) s,
          ]);
});

/// Texts for notifications, in the app's language and digit style.
final customModulesNotificationTextsProvider = Provider<CustomTexts>((ref) {
  final (language, digits) = ref.watch(appSettingsProvider.select((s) => (s.languageCode, s.digits)));
  return CustomTexts.forLanguage(language, digits: digits);
});

/// Keeps the module reminders planned: on every change of modules or
/// reminders, at each new day, when the language or prayer settings change,
/// and every six hours while the app runs. Watch it once from the app's
/// services (below the database gate).
final customModulesReminderSyncProvider = NotifierProvider<CustomModulesReminderSync, NotificationSyncReport?>(
  CustomModulesReminderSync.new,
);

class CustomModulesReminderSync extends Notifier<NotificationSyncReport?> {
  static const Duration debounce = Duration(milliseconds: 700);
  static const Duration refreshEvery = Duration(hours: 6);

  Timer? _debounce;
  Timer? _periodic;
  bool _running = false;
  bool _again = false;
  CustomModulesReminderEngine? _engine;

  CustomModulesReminderEngine get engine => _engine ??= CustomModulesReminderEngine(
    service: ref.read(customModulesServiceProvider),
    notifications: ref.read(notificationServiceProvider),
    texts: ref.read(customModulesNotificationTextsProvider),
    prayerStart: CustomModulesReminderEngine.prayerStartFrom(ref.read(prayerScheduleProvider)),
    clock: ref.read(customModulesClockProvider),
  );

  @override
  NotificationSyncReport? build() {
    void changed() {
      _engine = null;
      _schedule();
    }

    ref.listen(customModulesProvider, (_, _) => _schedule());
    ref.listen(
      customAllRemindersProvider,
      (_, _) => _schedule(),
    );
    ref.listen(customModulesTodayProvider, (_, _) => _schedule());
    ref.listen(customModulesNotificationTextsProvider, (_, _) => changed());
    ref.listen(prayerScheduleProvider, (_, _) => changed());
    ref.listen(customModulesServiceProvider, (_, _) => changed());
    _periodic = Timer.periodic(refreshEvery, (_) => _schedule());
    ref.onDispose(() {
      _debounce?.cancel();
      _periodic?.cancel();
    });
    _schedule();
    return null;
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(debounce, _run);
  }

  Future<void> _run() async {
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      final report = await engine.resync();
      if (ref.mounted) state = report;
    } catch (e) {
      debugPrint('custom module reminders: $e');
    } finally {
      _running = false;
      if (_again && ref.mounted) {
        _again = false;
        _schedule();
      }
    }
  }

  /// Re-plans now (tests, app start, after a change).
  Future<void> syncNow() async {
    _debounce?.cancel();
    await _run();
  }
}

/// Every module reminder row.
final customAllRemindersProvider = StreamProvider<List<ReminderRow>>(
  (ref) => ref.watch(customModulesServiceProvider).watchAllReminders(),
);
