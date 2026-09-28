import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/adhan/presentation/adhan_settings_screen.dart';
import '../../features/adhkar/adhkar.dart' show AdhkarCategoryId, TasbeehScreen;
import '../../features/gallery/design_gallery_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/import/import_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/orbit/presentation/planet/planet_route.dart';
import '../../features/prayer/presentation/prayer_settings_screen.dart';
import '../../features/settings/appearance_screen.dart';
import '../../features/settings/licenses_screen.dart';
import '../../features/settings/security_settings_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/settings/sound_settings_screen.dart';
import '../motion/motion.dart';
import '../motion/transitions.dart';
import '../settings/app_settings.dart';
import 'route_pages.dart';
import 'routes.dart';

export 'routes.dart';

/// Where the router starts (tests start deeper, e.g. at `/settings`).
final routerInitialLocationProvider = Provider<String>((ref) => AppRoutes.home);

/// The app's [GoRouter]. Created once per app scope; it reads (never
/// watches) the settings, so theme or language changes never rebuild the
/// navigation stack. Onboarding changes re-run the redirect through
/// `refreshListenable`.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.listen(appSettingsProvider.select((s) => s.onboarded), (_, _) => refresh.ping());
  final router = GoRouter(
    initialLocation: ref.read(routerInitialLocationProvider),
    refreshListenable: refresh,
    debugLogDiagnostics: false,
    redirect: (context, state) =>
        onboardingRedirect(onboarded: ref.read(appSettingsProvider).onboarded, location: state.matchedLocation),
    onException: (context, state, router) => router.go(AppRoutes.home),
    routes: madarRoutes(),
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

/// The route tree. Everything but onboarding is nested below home so `go`
/// always leaves home underneath (back returns there).
///
/// Transitions: home and onboarding fade through; settings pages and the
/// faith pages (prayer times, tracker, adhkar) move along the reading
/// direction (shared axis); the tasbeeh and the design gallery zoom in
/// (scaled shared axis); the importer rises as a sheet; a planet page is a
/// transparent route whose animation drives the orbit's fly-in / fly-out
/// underneath it.
///
/// The full-screen adhan is not a route: `AdhanHost` presents it above the
/// router and the app lock (see `AppGate`).
List<RouteBase> madarRoutes() => [
  GoRoute(
    path: AppRoutes.home,
    pageBuilder: (context, state) =>
        MadarTransitions.fadeThrough<void>(context: context, key: state.pageKey, child: const HomeScreen()),
    routes: [
      GoRoute(
        path: 'settings',
        pageBuilder: (context, state) =>
            MadarTransitions.sharedAxis<void>(context: context, key: state.pageKey, child: const SettingsScreen()),
        routes: [
          GoRoute(
            path: 'appearance',
            pageBuilder: (context, state) => MadarTransitions.sharedAxis<void>(
              context: context,
              key: state.pageKey,
              child: const AppearanceScreen(),
            ),
          ),
          GoRoute(
            path: 'sound',
            pageBuilder: (context, state) => MadarTransitions.sharedAxis<void>(
              context: context,
              key: state.pageKey,
              child: const SoundSettingsScreen(),
            ),
          ),
          GoRoute(
            path: 'licenses',
            pageBuilder: (context, state) =>
                MadarTransitions.sharedAxis<void>(context: context, key: state.pageKey, child: const LicensesScreen()),
          ),
          GoRoute(
            path: 'prayer',
            pageBuilder: (context, state) => MadarTransitions.sharedAxis<void>(
              context: context,
              key: state.pageKey,
              child: const PrayerSettingsScreen(),
            ),
          ),
          GoRoute(
            path: 'adhan',
            pageBuilder: (context, state) => MadarTransitions.sharedAxis<void>(
              context: context,
              key: state.pageKey,
              child: const AdhanSettingsScreen(),
            ),
          ),
          GoRoute(
            path: 'security',
            pageBuilder: (context, state) => MadarTransitions.sharedAxis<void>(
              context: context,
              key: state.pageKey,
              child: const SecuritySettingsScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: 'prayer-times',
        pageBuilder: (context, state) => MadarTransitions.sharedAxis<void>(
          context: context,
          key: state.pageKey,
          child: const PrayerTimesRoutePage(),
        ),
      ),
      GoRoute(
        path: 'prayer-tracker',
        pageBuilder: (context, state) => MadarTransitions.sharedAxis<void>(
          context: context,
          key: state.pageKey,
          child: PrayerTrackerRoutePage(tab: PrayerTrackerRoutePage.tabOf(state.uri.queryParameters['tab'])),
        ),
      ),
      GoRoute(
        path: 'adhkar',
        pageBuilder: (context, state) =>
            MadarTransitions.sharedAxis<void>(context: context, key: state.pageKey, child: const AdhkarHomeRoutePage()),
        routes: [
          // Before ':set', so it is never read as a set name.
          GoRoute(
            path: 'tasbeeh',
            pageBuilder: (context, state) => MadarTransitions.sharedAxis<void>(
              context: context,
              key: state.pageKey,
              axis: MadarSharedAxis.scaled,
              child: const TasbeehScreen(),
            ),
          ),
          GoRoute(
            path: ':set',
            redirect: (context, state) =>
                AdhkarCategoryId.tryParse(state.pathParameters['set']) == null ? AppRoutes.adhkar : null,
            pageBuilder: (context, state) => MadarTransitions.sharedAxis<void>(
              context: context,
              key: state.pageKey,
              child: AdhkarReaderRoutePage(
                set: AdhkarCategoryId.tryParse(state.pathParameters['set'])!,
                prayer: AdhkarReaderRoutePage.prayerOf(state.uri.queryParameters['prayer']),
              ),
            ),
          ),
        ],
      ),
      GoRoute(
        path: 'import',
        pageBuilder: (context, state) =>
            MadarTransitions.sheetRise<void>(context: context, key: state.pageKey, child: const ImportScreen()),
      ),
      GoRoute(
        path: 'planet/:key',
        pageBuilder: (context, state) => PlanetRoutePage(
          key: state.pageKey,
          name: state.uri.toString(),
          planetKey: state.pathParameters['key']!,
          item: state.uri.queryParameters['item'],
          reducedMotion: context.reducedMotion,
        ),
      ),
      GoRoute(
        path: 'gallery',
        pageBuilder: (context, state) => MadarTransitions.sharedAxis<void>(
          context: context,
          key: state.pageKey,
          axis: MadarSharedAxis.scaled,
          child: const DesignGalleryScreen(),
        ),
      ),
    ],
  ),
  GoRoute(
    path: AppRoutes.onboarding,
    pageBuilder: (context, state) =>
        MadarTransitions.fadeThrough<void>(context: context, key: state.pageKey, child: const OnboardingScreen()),
  ),
];

class _RouterRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}

/// Debug helper: the current location of [context]'s router.
@visibleForTesting
String currentLocation(BuildContext context) => GoRouter.of(context).state.matchedLocation;
