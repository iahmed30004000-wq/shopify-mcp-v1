import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/repositories/repositories.dart';
import '../../../core/notifications/notification_models.dart';
import '../../../core/notifications/notification_providers.dart';
import '../../../core/settings/app_settings.dart';
import '../../home/home_providers.dart' show appForegroundProvider, homeClockProvider;
import '../../orbit/data/orbit_providers.dart' show orbitPulseHubProvider;
import '../domain/contact_stats.dart';
import '../domain/family_models.dart';
import '../domain/rhythm.dart';
import '../family_texts.dart';
import 'contact_launcher.dart';
import 'family_notifications.dart';
import 'family_service.dart';

/// The wall clock of the Family screens (the home clock: tests override
/// either).
final familyClockProvider = Provider<DateTime Function()>((ref) => ref.watch(homeClockProvider));

/// "Now" for the rhythm views: refreshed at every local midnight and when
/// the app returns to the foreground (rhythms count whole days).
final familyNowProvider = NotifierProvider<FamilyNow, DateTime>(FamilyNow.new);

class FamilyNow extends Notifier<DateTime> {
  Timer? _timer;

  @override
  DateTime build() {
    final clock = ref.watch(familyClockProvider);
    final foreground = ref.watch(appForegroundProvider);
    void onForeground() {
      if (foreground.value) _refresh();
    }

    foreground.addListener(onForeground);
    ref.onDispose(() {
      _timer?.cancel();
      foreground.removeListener(onForeground);
    });
    final now = clock();
    _arm(now);
    return now;
  }

  void _arm(DateTime now) {
    _timer?.cancel();
    final next = CalendarDays.add(now, 1).add(const Duration(seconds: 1));
    _timer = Timer(next.difference(now), _refresh);
  }

  void _refresh() {
    if (!ref.mounted) return;
    final now = ref.read(familyClockProvider)();
    _arm(now);
    if (!CalendarDays.sameDay(now, state)) state = now;
  }
}

/// Logs a contact activity through the orbit's pulse hub (the Family planet
/// pulses at once).
final familyActivityRecorderProvider = Provider<FamilyActivityRecorder>((ref) {
  final hub = ref.watch(orbitPulseHubProvider);
  return ({required kind, required refTable, required refId, required at}) =>
      hub.recordCompletion(FamilyService.planetKey, kind, refTable, refId, at: at);
});

final familyServiceProvider = Provider<FamilyService>(
  (ref) => FamilyService(
    ref.watch(repositoriesProvider),
    clock: ref.watch(familyClockProvider),
    recorder: ref.watch(familyActivityRecorderProvider),
  ),
);

/// Opens the dialer / SMS / WhatsApp (tests override with
/// [RecordingContactLauncher]).
final familyContactLauncherProvider = Provider<ContactLauncher>((ref) => const UrlContactLauncher());

/// Everyone, in the manual order.
final familyPeopleProvider = StreamProvider<List<PersonRow>>((ref) => ref.watch(familyServiceProvider).watchPeople());

/// Every logged contact.
final familyContactLogsProvider = StreamProvider<List<ContactLogRow>>(
  (ref) => ref.watch(familyServiceProvider).watchLogs(),
);

final familySettingsProvider = StreamProvider<FamilySettings>(
  (ref) => ref.watch(familyServiceProvider).watchSettings(),
);

/// The Family model (people with their rhythm, groups, birthdays) at
/// [familyNowProvider] – with the clock's current time of day.
final familyOverviewProvider = Provider<AsyncValue<FamilyOverview>>((ref) {
  final people = ref.watch(familyPeopleProvider);
  final logs = ref.watch(familyContactLogsProvider);
  ref.watch(familyNowProvider);
  final now = ref.watch(familyClockProvider)();
  if (people case AsyncData(value: final p)) {
    if (logs case AsyncData(value: final l)) {
      return AsyncData(FamilyOverview.build(p, FamilyService.points(l), now));
    }
  }
  if (people case AsyncError(:final error, :final stackTrace)) return AsyncError(error, stackTrace);
  if (logs case AsyncError(:final error, :final stackTrace)) return AsyncError(error, stackTrace);
  return const AsyncLoading();
});

/// One person's row (null once deleted).
final familyPersonProvider = StreamProvider.autoDispose.family<PersonRow?, String>(
  (ref, id) => ref.watch(familyServiceProvider).watchPerson(id),
);

/// One person's contacts, newest first.
final familyPersonLogsProvider = StreamProvider.autoDispose.family<List<ContactLogRow>, String>(
  (ref, id) => ref.watch(familyServiceProvider).watchLogsOf(id),
);

/// One person evaluated now (null while loading or once deleted).
final familyPersonViewProvider = Provider.autoDispose.family<PersonView?, String>((ref, id) {
  final row = ref.watch(familyPersonProvider(id)).value;
  final logs = ref.watch(familyPersonLogsProvider(id)).value;
  if (row == null || logs == null) return null;
  ref.watch(familyNowProvider);
  final now = ref.watch(familyClockProvider)();
  return PersonView.build(row, [for (final l in logs) (at: l.at, channel: l.channel)], now);
});

/// One person's statistics.
final familyPersonStatsProvider = Provider.autoDispose.family<ContactStats?, String>((ref, id) {
  final row = ref.watch(familyPersonProvider(id)).value;
  final logs = ref.watch(familyPersonLogsProvider(id)).value;
  if (row == null || logs == null) return null;
  ref.watch(familyNowProvider);
  return ContactStatsMath.of(
    [for (final l in logs) (at: l.at, channel: l.channel)],
    rhythmDays: row.rhythmDays,
    now: ref.watch(familyClockProvider)(),
  );
});

/// Texts for notifications, in the app's language and digit style.
final familyNotificationTextsProvider = Provider<FamilyTexts>((ref) {
  final (language, digits) = ref.watch(appSettingsProvider.select((s) => (s.languageCode, s.digits)));
  return FamilyTexts.forLanguage(language, digits: digits);
});

/// Keeps the Family notifications (daily digest + birthdays) planned: on
/// every change of people, contacts or settings, at each new day, when the
/// language changes, and every six hours while the app runs. Watch it once
/// from the app's services (below the database gate).
final familyReminderSyncProvider = NotifierProvider<FamilyReminderSync, NotificationSyncReport?>(
  FamilyReminderSync.new,
);

class FamilyReminderSync extends Notifier<NotificationSyncReport?> {
  static const Duration debounce = Duration(milliseconds: 700);
  static const Duration refreshEvery = Duration(hours: 6);

  Timer? _debounce;
  Timer? _periodic;
  bool _running = false;
  bool _again = false;
  FamilyReminderEngine? _engine;

  FamilyReminderEngine get engine => _engine ??= FamilyReminderEngine(
    service: ref.read(familyServiceProvider),
    notifications: ref.read(notificationServiceProvider),
    texts: ref.read(familyNotificationTextsProvider),
    clock: ref.read(familyClockProvider),
  );

  @override
  NotificationSyncReport? build() {
    void changed() {
      _engine = null;
      _schedule();
    }

    ref.listen(familyPeopleProvider, (_, _) => _schedule());
    ref.listen(familyContactLogsProvider, (_, _) => _schedule());
    ref.listen(familySettingsProvider, (_, _) => _schedule());
    ref.listen(familyNowProvider, (_, _) => _schedule());
    ref.listen(familyNotificationTextsProvider, (_, _) => changed());
    ref.listen(familyServiceProvider, (_, _) => changed());
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
      debugPrint('family reminders: $e');
    } finally {
      _running = false;
      if (_again && ref.mounted) {
        _again = false;
        _schedule();
      }
    }
  }

  /// Re-plans now (tests, app start, after a settings change).
  Future<void> syncNow() async {
    _debounce?.cancel();
    await _run();
  }
}
