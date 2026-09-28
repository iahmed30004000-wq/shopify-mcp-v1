import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/adhkar/adhkar.dart';
import '../../features/prayer/prayer.dart';
import '../../features/prayer_tracker/prayer_tracker.dart';
import '../domain/enums.dart';
import '../settings/app_settings.dart';
import '../sound/sound_api.dart';
import 'routes.dart';

/// Adapters between the router and the Phase 2 feature screens: each feature
/// navigates through callbacks, and these route them to the app's
/// locations (so back, deep links and notification taps all share one
/// stack) instead of the features' own fallback pushes.
///
/// In-app links `push` (back returns to wherever they were opened – the
/// Faith page, Settings …); notification deep links `go` (see
/// `AppNotificationRouter`).
abstract final class FaithNav {
  static void prayerTimes(BuildContext context) => context.push(AppRoutes.prayerTimes);

  static void prayerSettings(BuildContext context) => context.push(AppRoutes.prayerSettings);

  static void adhanSettings(BuildContext context) => context.push(AppRoutes.adhanSettings);

  static void tracker(BuildContext context, {bool history = false}) =>
      context.push(history ? AppRoutes.prayerTrackerHistory : AppRoutes.prayerTracker);

  static void adhkar(BuildContext context) => context.push(AppRoutes.adhkar);

  static void adhkarSet(BuildContext context, AdhkarCategoryId set, Prayer? prayer) =>
      context.push(AppRoutes.adhkarSetOf(set.name, prayer: set == AdhkarCategoryId.afterPrayer ? prayer?.name : null));

  static void tasbeeh(BuildContext context) => context.push(AppRoutes.tasbeeh);
}

/// `/prayer-times`: its settings button opens the routed settings page.
class PrayerTimesRoutePage extends StatelessWidget {
  const PrayerTimesRoutePage({super.key});

  @override
  Widget build(BuildContext context) => PrayerTimesScreen(onOpenSettings: () => FaithNav.prayerSettings(context));
}

/// `/prayer-tracker[?tab=history]`; the backdrop rests in battery saver.
class PrayerTrackerRoutePage extends ConsumerWidget {
  const PrayerTrackerRoutePage({super.key, this.tab = TrackerTab.today});

  final TrackerTab tab;

  /// The tab named by the `tab` query parameter.
  static TrackerTab tabOf(String? name) => name == TrackerTab.history.name ? TrackerTab.history : TrackerTab.today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saver = ref.watch(appSettingsProvider.select((s) => s.powerMode == PowerMode.batterySaver));
    return PrayerTrackerScreen(initialTab: tab, animateBackdrop: !saver);
  }
}

/// `/adhkar`: sets and the tasbeeh open as routes.
class AdhkarHomeRoutePage extends StatelessWidget {
  const AdhkarHomeRoutePage({super.key});

  @override
  Widget build(BuildContext context) => AdhkarHomeScreen(
    onOpenSet: (context, set, prayer) {
      // The package's own navigation sounds the step; routed, so do we.
      Fx.fire(Sfx.navigate);
      FaithNav.adhkarSet(context, set, prayer);
    },
    // The tasbeeh card sounds its own tap.
    onOpenTasbeeh: FaithNav.tasbeeh,
  );
}

/// `/adhkar/:set[?prayer=…]`.
class AdhkarReaderRoutePage extends StatelessWidget {
  const AdhkarReaderRoutePage({super.key, required this.set, this.prayer});

  final AdhkarCategoryId set;
  final Prayer? prayer;

  /// The prayer named by the `prayer` query parameter (after-prayer set).
  static Prayer? prayerOf(String? name) {
    for (final p in Prayer.values) {
      if (p.name == name) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => AdhkarReaderScreen(category: set, prayer: prayer);
}
