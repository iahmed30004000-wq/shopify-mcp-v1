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
