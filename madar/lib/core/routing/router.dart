import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/adhan/presentation/adhan_settings_screen.dart';
import '../../features/adhkar/adhkar.dart' show AdhkarCategoryId, TasbeehScreen;
import '../../features/cinema/hall/hall.dart' show CinemaGameScreen, CinemaHallScreen, SavedGamesScreen;
import '../../features/gallery/design_gallery_screen.dart';
import '../../features/hifz/hifz.dart' show HifzCard;
import '../../features/home/home_screen.dart';
import '../../features/import/import_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/orbit/presentation/planet/planet_route.dart';
import '../../features/prayer/presentation/prayer_settings_screen.dart';
import '../../features/qibla/qibla.dart' show QiblaScreen;
import '../../features/recitation/recitation.dart' show RecitationSettingsScreen;
import '../../features/settings/appearance_screen.dart';
import '../../features/settings/health_settings_screen.dart';
import '../../features/settings/licenses_screen.dart';
import '../../features/settings/quran_settings_screen.dart';
import '../../features/settings/reminders_settings_screen.dart';
import '../../features/settings/security_settings_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/settings/sound_settings_screen.dart';
import '../motion/motion.dart';
import '../motion/transitions.dart';
import '../settings/app_settings.dart';
import 'cinema_route_pages.dart';
import 'health_route_pages.dart';
import 'life_route_pages.dart';
import 'money_route_pages.dart';
import 'now_playing_dock.dart';
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
/// faith pages (prayer times, tracker, adhkar, the Quran's home, reader and
/// search, the wird, Hifz and its reviews, recitation and its downloads)
/// and the health pages (medications, the medical record, a lab test, the
/// appointments, wellbeing, Settings › Health) and the money pages (the
/// ledger, a wallet, the transactions, the currencies, the budget, the
/// goals and a jar) and the life pages (Work, a board, the projects, a
/// project, Family, a person, Travel on its tabs, a trip, a packing
/// template, the learning goals, a learning goal, the Body on its tabs, the
/// trackers and a tracker) and the saved web games (`/saved-games`) move
/// along the reading direction (shared axis); the cinema hall (`/cinema`)
/// fades through, and a show (`/cinema/game/<id>`) opens through the hall's
/// iris over black; the tasbeeh, the qibla compass, guided
/// breathing and the design gallery zoom in (scaled shared axis); the
/// importer rises as a sheet, and the full recitation player
/// (`/now-playing`) as an interaction sheet over the page beneath; a planet
/// page is a transparent route whose animation drives the orbit's fly-in /
/// fly-out underneath it.
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
          GoRoute(
            path: 'quran',
            pageBuilder: (context, state) => MadarTransitions.sharedAxis<void>(
              context: context,
              key: state.pageKey,
              child: const QuranSettingsScreen(),
            ),
          ),
          GoRoute(
            path: 'recitation',
            pageBuilder: (context, state) => MadarTransitions.sharedAxis<void>(
              context: context,
              key: state.pageKey,
              child: const RecitationSettingsScreen(),
            ),
            routes: [
              GoRoute(
                path: 'downloads',
                redirect: (context, state) =>
                    RecitationDownloadsRoutePage.reciterOf(state.uri.queryParameters['reciter']) == null
                    ? AppRoutes.recitationSettings
                    : null,
                pageBuilder: (context, state) => MadarTransitions.sharedAxis<void>(
                  context: context,
                  key: state.pageKey,
                  child: RecitationDownloadsRoutePage(
                    reciter: RecitationDownloadsRoutePage.reciterOf(state.uri.queryParameters['reciter'])!,
                  ),
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'reminders',
            pageBuilder: (context, state) => MadarTransitions.sharedAxis<void>(
              context: context,
              key: state.pageKey,
              child: const RemindersSettingsScreen(),
            ),
          ),
          GoRoute(
            path: 'health',
            pageBuilder: (context, state) => MadarTransitions.sharedAxis<void>(
              context: context,
              key: state.pageKey,
              child: const HealthSettingsScreen(),
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
        path: 'quran',
        pageBuilder: (context, state) =>
            MadarTransitions.sharedAxis<void>(context: context, key: state.pageKey, child: const QuranHomeRoutePage()),
        routes: [
          GoRoute(
            path: 'read',
            pageBuilder: (context, state) => MadarTransitions.sharedAxis<void>(
              context: context,
              key: state.pageKey,
              child: QuranReaderRoutePage(
                ayah: QuranReaderRoutePage.ayahOf(state.uri.queryParameters['ayah']),
                page: QuranReaderRoutePage.pageOf(state.uri.queryParameters['page']),
              ),
            ),
          ),
          GoRoute(
            path: 'search',
            pageBuilder: (context, state) => MadarTransitions.sharedAxis<void>(
              context: context,
              key: state.pageKey,
              child: QuranSearchRoutePage(query: state.uri.queryParameters['q'] ?? ''),
            ),
          ),
        ],
      ),
      GoRoute(
        path: 'wird',
        pageBuilder: (context, state) => MadarTransitions.sharedAxis<void>(
          context: context,
          key: state.pageKey,
          child: WirdRoutePage(planId: state.uri.queryParameters['plan']),
        ),
      ),
      GoRoute(
        path: 'hifz',
        pageBuilder: (context, state) =>
            MadarTransitions.sharedAxis<void>(context: context, key: state.pageKey, child: const HifzRoutePage()),
        routes: [
          GoRoute(
            path: 'review',
            pageBuilder: (context, state) => MadarTransitions.sharedAxis<void>(
              context: context,
              key: state.pageKey,
              child: HifzReviewRoutePage(
                cardId: state.uri.queryParameters['card'],
                card: state.extra is HifzCard ? state.extra! as HifzCard : null,
              ),
            ),
          ),
        ],
      ),
      GoRoute(
        path: 'qibla',
        pageBuilder: (context, state) => MadarTransitions.sharedAxis<void>(
          context: context,
          key: state.pageKey,
          axis: MadarSharedAxis.scaled,
          child: const QiblaScreen(),
        ),
      ),
      // Phase 4 – health.
      GoRoute(
        path: 'meds',
        pageBuilder: (context, state) => MadarTransitions.sharedAxis<void>(
          context: context,
          key: state.pageKey,
          child: MedsRoutePage(tab: MedsRoutePage.tabOf(state.uri.queryParameters['tab'])),
        ),
      ),
      GoRoute(
        path: 'record',
        pageBuilder: (context, state) => MadarTransitions.sharedAxis<void>(
          context: context,
          key: state.pageKey,
          child: RecordRoutePage(tab: RecordRoutePage.tabOf(state.uri.queryParameters['tab'])),
        ),
        routes: [
          GoRoute(
            path: 'appointments',
            pageBuilder: (context, state) => MadarTransitions.sharedAxis<void>(
              context: context,
              key: state.pageKey,
              child: AppointmentsRoutePage(highlightId: state.uri.queryParameters['highlight']),
            ),
          ),
          GoRoute(
            path: 'lab/:id',
            pageBuilder: (context, state) => MadarTransitions.sharedAxis<void>(
              context: context,
              key: state.pageKey,
              child: LabTestRoutePage(testId: state.pathParameters['id']!),
            ),
          ),
        ],
      ),
      GoRoute(
        path: 'wellbeing',
        pageBuilder: (context, state) => MadarTransitions.sharedAxis<void>(
          context: context,
          key: state.pageKey,
          child: WellbeingRoutePage(tab: WellbeingRoutePage.tabOf(state.uri.queryParameters['tab'])),
        ),
        routes: [
          GoRoute(
            path: 'breathing',
            pageBuilder: (context, state) => MadarTransitions.sharedAxis<void>(
              context: context,
              key: state.pageKey,
              axis: MadarSharedAxis.scaled,
              child: BreathingRoutePage(pattern: BreathingRoutePage.patternOf(state.uri.queryParameters['pattern'])),
            ),
          ),
        ],
      ),
      // Phase 5 – money.
      GoRoute(
        path: 'ledger',
        pageBuilder: (context, state) =>
            MadarTransitions.sharedAxis<void>(context: context, key: state.pageKey, child: const LedgerRoutePage()),
        routes: [
          GoRoute(
            path: 'wallet/:id',
            pageBuilder: (context, state) => MadarTransitions.sharedAxis<void>(
              context: context,
              key: state.pageKey,
              child: WalletRoutePage(walletId: state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: 'transactions',
            pageBuilder: (context, state) => MadarTransitions.sharedAxis<void>(
              context: context,
              key: state.pageKey,
              child: TransactionsRoutePage(filter: TransactionsRoutePage.filterOf(state.uri.queryParametersAll)),
            ),
          ),
          GoRoute(
            path: 'currencies',
            pageBuilder: (context, state) => MadarTransitions.sharedAxis<void>(
              context: context,
              key: state.pageKey,
              child: const CurrenciesRoutePage(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: 'budget',
        pageBuilder: (context, state) => MadarTransitions.sharedAxis<void>(
          context: context,
          key: state.pageKey,
          child: BudgetRoutePage(tab: BudgetRoutePage.tabOf(state.uri.queryParameters['tab'])),
        ),
      ),
      GoRoute(
        path: 'goals',
        pageBuilder: (context, state) {
          final q = state.uri.queryParameters;
          return MadarTransitions.sharedAxis<void>(
            context: context,
            key: state.pageKey,
            child: GoalsRoutePage(
              // A new debt / obligation in the location opens its sheet anew.
              key: ValueKey('goals:${state.uri.query}'),
              tab: GoalsRoutePage.tabFor(tab: q['tab'], debtId: q['debt'], obligationId: q['obligation']),
              debtId: q['debt'],
              obligationId: q['obligation'],
            ),
          );
        },
        routes: [
          GoRoute(
            path: 'jar/:id',
            pageBuilder: (context, state) => MadarTransitions.sharedAxis<void>(
              context: context,
              key: state.pageKey,
              child: JarRoutePage(jarId: state.pathParameters['id']!),
            ),
          ),
        ],
      ),
      // Phase 6 – life.
      GoRoute(
        path: 'work',
        pageBuilder: (context, state) =>
            MadarTransitions.sharedAxis<void>(context: context, key: state.pageKey, child: const WorkRoutePage()),
        routes: [
          GoRoute(
            path: 'board/:id',
            pageBuilder: (context, state) => MadarTransitions.sharedAxis<void>(
              context: context,
              key: state.pageKey,
              child: BoardRoutePage(boardId: state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: 'projects',
            pageBuilder: (context, state) => MadarTransitions.sharedAxis<void>(
              context: context,
              key: state.pageKey,
              child: const ProjectsRoutePage(),
            ),
          ),
          GoRoute(
            path: 'project/:id',
            pageBuilder: (context, state) => MadarTransitions.sharedAxis<void>(
              context: context,
              key: state.pageKey,
              child: ProjectRoutePage(projectId: state.pathParameters['id']!),
            ),
          ),
        ],
      ),
      GoRoute(
        path: 'family',
        pageBuilder: (context, state) =>
            MadarTransitions.sharedAxis<void>(context: context, key: state.pageKey, child: const FamilyRoutePage()),
        routes: [
          GoRoute(
            path: 'person/:id',
            pageBuilder: (context, state) => MadarTransitions.sharedAxis<void>(
              context: context,
              key: state.pageKey,
              child: PersonRoutePage(personId: state.pathParameters['id']!),
            ),
          ),
        ],
      ),
      GoRoute(
        path: 'travel',
        pageBuilder: (context, state) => MadarTransitions.sharedAxis<void>(
          context: context,
          key: state.pageKey,
          child: TravelRoutePage(tab: TravelRoutePage.tabOf(state.uri.queryParameters['tab'])),
        ),
        routes: [
          GoRoute(
            path: 'trip/:id',
            pageBuilder: (context, state) => MadarTransitions.sharedAxis<void>(
              context: context,
              key: state.pageKey,
              child: TripRoutePage(tripId: state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: 'template/:id',
            pageBuilder: (context, state) => MadarTransitions.sharedAxis<void>(
              context: context,
              key: state.pageKey,
              child: PackingTemplateRoutePage(templateId: state.pathParameters['id']!),
            ),
          ),
        ],
      ),
      GoRoute(
        path: 'growth',
        pageBuilder: (context, state) =>
            MadarTransitions.sharedAxis<void>(context: context, key: state.pageKey, child: const GrowthRoutePage()),
        routes: [
          GoRoute(
            path: 'goal/:id',
            pageBuilder: (context, state) => MadarTransitions.sharedAxis<void>(
              context: context,
              key: state.pageKey,
              child: GrowthGoalRoutePage(goalId: state.pathParameters['id']!),
            ),
          ),
        ],
      ),
      GoRoute(
        path: 'body',
        pageBuilder: (context, state) => MadarTransitions.sharedAxis<void>(
          context: context,
          key: state.pageKey,
          child: BodyRoutePage(tab: BodyRoutePage.tabOf(state.uri.queryParameters['tab'])),
        ),
      ),
      GoRoute(
        path: 'food',
        redirect: (context, state) => state.uri.path == '/food' ? AppRoutes.foodLibrary : null,
        builder: (context, state) => const FoodLibraryRoutePage(),
        routes: [
          GoRoute(
            path: 'library',
            pageBuilder: (context, state) => MadarTransitions.sharedAxis<void>(
              context: context,
              key: state.pageKey,
              child: const FoodLibraryRoutePage(),
            ),
          ),
          GoRoute(
            path: 'plan',
            pageBuilder: (context, state) => MadarTransitions.sharedAxis<void>(
              context: context,
              key: state.pageKey,
              child: const FoodPlanRoutePage(),
            ),
          ),
          GoRoute(
            path: 'rules',
            pageBuilder: (context, state) => MadarTransitions.sharedAxis<void>(
              context: context,
              key: state.pageKey,
              child: const FoodRulesRoutePage(),
            ),
          ),
          GoRoute(
            path: 'insights',
            pageBuilder: (context, state) => MadarTransitions.sharedAxis<void>(
              context: context,
              key: state.pageKey,
              child: const FoodInsightsRoutePage(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: 'modules',
        pageBuilder: (context, state) =>
            MadarTransitions.sharedAxis<void>(context: context, key: state.pageKey, child: const ModulesRoutePage()),
        routes: [
          GoRoute(
            path: 'module/:id',
            pageBuilder: (context, state) => MadarTransitions.sharedAxis<void>(
              context: context,
              key: state.pageKey,
              child: ModuleRoutePage(moduleId: state.pathParameters['id']!),
            ),
          ),
        ],
      ),
      // Phase 7 – Madar Cinema.
      GoRoute(
        path: 'cinema',
        pageBuilder: (context, state) =>
            MadarTransitions.fadeThrough<void>(context: context, key: state.pageKey, child: const CinemaHallScreen()),
        routes: [
          GoRoute(
            path: 'game/:id',
            pageBuilder: (context, state) => CinemaRoutePages.iris(
              context: context,
              key: state.pageKey,
              child: CinemaGameScreen(gameId: state.pathParameters['id']!),
            ),
          ),
        ],
      ),
      GoRoute(
        path: 'saved-games',
        pageBuilder: (context, state) => MadarTransitions.sharedAxis<void>(
          context: context,
          key: state.pageKey,
          child: SavedGamesScreen(initialSharedText: state.uri.queryParameters['text']),
        ),
      ),
      GoRoute(
        path: 'now-playing',
        pageBuilder: (context, state) => NowPlayingSheetPage(key: state.pageKey, name: state.uri.toString()),
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
