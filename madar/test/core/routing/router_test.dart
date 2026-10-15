import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/onboarding/onboarding_screen.dart';

void main() {
  group('onboardingRedirect', () {
    test('first launch: everything goes to onboarding except the importer', () {
      for (final l in [AppRoutes.home, AppRoutes.settings, AppRoutes.sound, AppRoutes.gallery, '']) {
        expect(onboardingRedirect(onboarded: false, location: l), AppRoutes.onboarding, reason: l);
      }
      expect(onboardingRedirect(onboarded: false, location: AppRoutes.onboarding), isNull);
      expect(onboardingRedirect(onboarded: false, location: AppRoutes.import), isNull);
    });

    test('after onboarding: onboarding closes, everything else stays', () {
      expect(onboardingRedirect(onboarded: true, location: AppRoutes.onboarding), AppRoutes.home);
      for (final l in [AppRoutes.home, AppRoutes.settings, AppRoutes.appearance, AppRoutes.import]) {
        expect(onboardingRedirect(onboarded: true, location: l), isNull, reason: l);
      }
    });
  });

  test('completeOnboarding marks onboarded and picks the exit', () {
    const s = AppSettings(languageCode: 'en');
    final home = completeOnboarding(s, OnboardingExit.home);
    expect(home.settings.onboarded, isTrue);
    expect(home.settings.languageCode, 'en');
    expect(home.location, AppRoutes.home);
    expect(completeOnboarding(s, OnboardingExit.import).location, AppRoutes.import);
  });
}
