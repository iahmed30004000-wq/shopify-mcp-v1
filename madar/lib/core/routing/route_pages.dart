import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/adhkar/adhkar.dart';
import '../../features/hifz/hifz.dart' show HifzCard, HifzReviewScreen, HifzScreen, hifzCardsProvider;
import '../../features/prayer/prayer.dart';
import '../../features/prayer_tracker/prayer_tracker.dart';
import '../../features/quran/quran.dart' show QuranHomeScreen, QuranReaderScreen, QuranSearchScreen;
import '../../features/recitation/recitation.dart' show Reciter, RecitationDownloadsScreen, Reciters;
import '../../features/wird/wird.dart' show WirdScreen;
import '../design/widgets/widgets.dart' show MadarScaffold, OrbitLoader;
import '../domain/enums.dart';
import '../quran/ayah.dart';
import '../settings/app_settings.dart';
import '../sound/sound_api.dart';
import 'now_playing_dock.dart';
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

  // Phase 3 – the Quran, recitation, the wird, Hifz and the qibla. The
  // features sound their own taps before calling these.

  static void quran(BuildContext context) => context.push(AppRoutes.quran);

  static void quranReader(BuildContext context, {AyahRef? ayah, int? page}) =>
      context.push(AppRoutes.quranReaderOf(ayah: ayah, page: page));

  static void quranSearch(BuildContext context) => context.push(AppRoutes.quranSearch);

  static void wird(BuildContext context, {String? planId}) => context.push(AppRoutes.wirdOf(planId));

  static void hifz(BuildContext context) => context.push(AppRoutes.hifz);

  /// A review of today's queue, or of [only] (handed over as `extra`, so
  /// the page never waits for it).
  static void hifzReview(BuildContext context, {HifzCard? only}) =>
      context.push(AppRoutes.hifzReviewOf(only?.id), extra: only);

  static void qibla(BuildContext context) => context.push(AppRoutes.qibla);

  static void recitation(BuildContext context) => context.push(AppRoutes.recitationSettings);

  static void recitationDownloads(BuildContext context, Reciter reciter) =>
      context.push(AppRoutes.recitationDownloadsOf(reciter.id));

  static void quranSettings(BuildContext context) => context.push(AppRoutes.quranSettings);

  static void reminders(BuildContext context) => context.push(AppRoutes.reminders);
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

// ------------------------------------------------------------- Phase 3 ----

/// Whether decorative backdrops rest (battery saver).
bool _saver(WidgetRef ref) => ref.watch(appSettingsProvider.select((s) => s.powerMode == PowerMode.batterySaver));

/// `/quran`: the reader and the search open as routes; the mini player
/// docks at the bottom while a recitation plays.
class QuranHomeRoutePage extends StatelessWidget {
  const QuranHomeRoutePage({super.key});

  @override
  Widget build(BuildContext context) => NowPlayingDock(
    child: QuranHomeScreen(
      onOpenReader: (context, {ayah, page}) => FaithNav.quranReader(context, ayah: ayah, page: page),
      onOpenSearch: FaithNav.quranSearch,
    ),
  );
}

/// `/quran/read[?ayah=2:255|?page=42]`.
class QuranReaderRoutePage extends StatelessWidget {
  const QuranReaderRoutePage({super.key, this.ayah, this.page});

  final AyahRef? ayah;
  final int? page;

  /// The ayah named by the `ayah` query parameter (`2:255`).
  static AyahRef? ayahOf(String? value) => value == null ? null : AyahRef.tryParse(value);

  /// The mushaf page named by the `page` query parameter (1–604).
  static int? pageOf(String? value) {
    final p = int.tryParse(value ?? '');
    return p != null && p >= 1 && p <= 604 ? p : null;
  }

  @override
  Widget build(BuildContext context) => NowPlayingDock(
    // A new target is a new visit (the reader reads its start once).
    child: QuranReaderScreen(key: ValueKey('quran-reader:$ayah:$page'), start: ayah, page: page),
  );
}

/// `/quran/search[?q=…]`: a result opens the reader as a route.
class QuranSearchRoutePage extends StatelessWidget {
  const QuranSearchRoutePage({super.key, this.query = ''});

  final String query;

  @override
  Widget build(BuildContext context) => NowPlayingDock(
    child: QuranSearchScreen(
      initialQuery: query,
      onOpenReader: (context, {ayah, page}) => FaithNav.quranReader(context, ayah: ayah, page: page),
    ),
  );
}

/// `/wird[?plan=<id>]`; "read now" goes to the reader through the app-wide
/// `wirdReadNowProvider`.
class WirdRoutePage extends ConsumerWidget {
  const WirdRoutePage({super.key, this.planId});

  final String? planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      NowPlayingDock(child: WirdScreen(initialPlanId: planId, animateBackdrop: !_saver(ref)));
}

/// `/hifz`: reviews open as routes.
class HifzRoutePage extends ConsumerWidget {
  const HifzRoutePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => NowPlayingDock(
    child: HifzScreen(
      onStartReview: (context, {only}) => FaithNav.hifzReview(context, only: only),
      animateBackdrop: !_saver(ref),
    ),
  );
}

/// `/hifz/review[?card=<id>]`: the card comes as `extra` from in-app links,
/// or is looked up by id (a deep link); an unknown id reviews today's queue.
class HifzReviewRoutePage extends ConsumerWidget {
  const HifzReviewRoutePage({super.key, this.cardId, this.card});

  final String? cardId;
  final HifzCard? card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var only = card;
    if (only == null && cardId != null) {
      final cards = ref.watch(hifzCardsProvider);
      if (cards.isLoading && !cards.hasValue) return const MadarScaffold(body: _Loading());
      for (final c in cards.value ?? const <HifzCard>[]) {
        if (c.id == cardId) only = c;
      }
    }
    return NowPlayingDock(
      child: HifzReviewScreen(key: ValueKey('hifz-review:${only?.id}'), only: only, animateBackdrop: !_saver(ref)),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Center(child: OrbitLoader(size: 40));
}

/// `/settings/recitation/downloads?reciter=<id>` (an unknown reciter falls
/// back to the recitation settings – see the router's redirect).
class RecitationDownloadsRoutePage extends StatelessWidget {
  const RecitationDownloadsRoutePage({super.key, required this.reciter});

  final Reciter reciter;

  /// The reciter named by the `reciter` query parameter, or null.
  static Reciter? reciterOf(String? id) => Reciters.byIdOrNull(id);

  @override
  Widget build(BuildContext context) => RecitationDownloadsScreen(reciter: reciter);
}
