/// Every route location of the app. Navigate with `context.go(AppRoutes.x)`
/// (routes below `/` are nested, so `go` builds the whole stack and the back
/// button returns to the parent).
abstract final class AppRoutes {
  static const String home = '/';
  static const String onboarding = '/onboarding';
  static const String settings = '/settings';
  static const String appearance = '/settings/appearance';
  static const String sound = '/settings/sound';
  static const String licenses = '/settings/licenses';
  static const String import = '/import';
  static const String gallery = '/gallery';

  // Phase 2 – the day around the five prayers.

  /// Prayer times (day and month views, next prayer, Hijri date).
  static const String prayerTimes = '/prayer-times';

  /// Calculation method, location, adjustments, Hijri offset, clock.
  static const String prayerSettings = '/settings/prayer';

  /// The adhan: sounds, reminders, full-screen, permissions.
  static const String adhanSettings = '/settings/adhan';

  /// Settings › Security (app lock: PIN, fingerprint, time-out).
  static const String security = '/settings/security';

  /// The prayer tracker (`?tab=history` opens the history tab).
  static const String prayerTracker = '/prayer-tracker';

  /// Location of the tracker's history tab.
  static const String prayerTrackerHistory = '/prayer-tracker?tab=history';

  /// Adhkar (Hisn al-Muslim): the sets of the day.
  static const String adhkar = '/adhkar';

  /// The tasbeeh ring.
  static const String tasbeeh = '/adhkar/tasbeeh';

  /// One adhkar set in the reader (`/adhkar/morning`,
  /// `/adhkar/afterPrayer?prayer=asr`).
  static const String adhkarSet = '/adhkar/:set';

  /// Location of the reader of [set] (an `AdhkarCategoryId` name), for the
  /// after-prayer set optionally of [prayer] (a `Prayer` name).
  static String adhkarSetOf(String set, {String? prayer}) => Uri(
    path: '/adhkar/${Uri.encodeComponent(set)}',
    queryParameters: prayer == null ? null : {'prayer': prayer},
  ).toString();

  /// A planet's page over the orbit (`/planet/faith?item=people:<id>`); the
  /// orbit scene flies in underneath it.
  static const String planet = '/planet/:key';

  /// Location of [key]'s planet page, optionally highlighting the moon or
  /// record [item] (`refTable:refId`).
  static String planetOf(String key, {String? item}) => Uri(
    path: '/planet/${Uri.encodeComponent(key)}',
    queryParameters: item == null ? null : {'item': item},
  ).toString();

  /// Locations reachable before onboarding is finished (onboarding can hand
  /// over to the importer).
  static const Set<String> beforeOnboarding = {onboarding, import};
}

/// Where the router must send [location] (a matched location such as
/// `/settings/sound`), or null to stay. Pure – unit-tested.
///
/// * Not onboarded → everything except [AppRoutes.beforeOnboarding] goes to
///   onboarding.
/// * Onboarded → onboarding is closed and goes home.
String? onboardingRedirect({required bool onboarded, required String location}) {
  final path = location.isEmpty ? AppRoutes.home : location;
  if (!onboarded) {
    return AppRoutes.beforeOnboarding.contains(path) ? null : AppRoutes.onboarding;
  }
  return path == AppRoutes.onboarding ? AppRoutes.home : null;
}
