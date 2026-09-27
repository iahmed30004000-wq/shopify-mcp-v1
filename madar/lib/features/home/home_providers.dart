import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/db/repositories/repositories.dart';
import '../../core/domain/enums.dart';
import '../../core/i18n/gen/app_localizations.dart';
import '../../core/interaction/quick_add/quick_add_handler.dart';
import '../../core/settings/app_settings.dart';
import 'domain/home_tasks.dart';
import 'domain/prayer_day.dart';
import 'domain/quick_add_handlers.dart';

/// The wall clock used by home (overridden in tests with a fixed time).
final homeClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Prayer window times of the day. Phase 0: [PrayerDayTimes.placeholder];
/// Phase 2 overrides this with computed times.
final prayerDayProvider = Provider<PrayerDayTimes>((ref) => PrayerDayTimes.placeholder);

/// "Now", refreshed at every minute boundary while someone listens.
final homeNowProvider = NotifierProvider.autoDispose<HomeNow, DateTime>(HomeNow.new);

class HomeNow extends Notifier<DateTime> {
  Timer? _timer;

  @override
  DateTime build() {
    final clock = ref.watch(homeClockProvider);
    final now = clock();
    _schedule(now, clock);
    ref.onDispose(() => _timer?.cancel());
    return now;
  }

  void _schedule(DateTime now, DateTime Function() clock) {
    _timer?.cancel();
    final wait = Duration(seconds: 60 - now.second, milliseconds: -now.millisecond);
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

final homeTasksServiceProvider = Provider<HomeTasksService>(
  (ref) => HomeTasksService(ref.watch(repositoriesProvider), clock: ref.watch(homeClockProvider)),
);

/// A window's list on one day.
typedef HomeTaskQuery = ({PrayerWindow window, DateTime day});

final homeTasksProvider = StreamProvider.autoDispose.family<List<TaskRow>, HomeTaskQuery>(
  (ref, q) => ref.watch(homeTasksServiceProvider).watchWindow(q.window, q.day),
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
