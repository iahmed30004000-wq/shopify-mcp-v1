import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/home/home_screen.dart';
import 'package:madar/features/import/import_screen.dart';
import 'package:madar/features/onboarding/onboarding_screen.dart';
import 'package:madar/features/settings/widgets/appearance_pickers.dart';

import '../../helpers/test_app.dart';

final _ar = lookupL10n(const Locale('ar'));
final _en = lookupL10n(const Locale('en'));

void main() {
  testWidgets('three steps, live language + theme, start fresh → home', (tester) async {
    final app = await pumpMadarApp(tester, settings: const AppSettings());
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text(_ar.onboardingWelcomeTagline), findsOneWidget);

    await tester.tap(find.text(_ar.onboardingBegin));
    await settleApp(tester);
    expect(find.text(_ar.onboardingStyleTitle), findsOneWidget);

    // Language flips the layout immediately, on the same screen.
    await tester.tap(find.text(_ar.settingsLanguageEnglish));
    await tester.pump();
    expect(app.settings.languageCode, 'en');
    expect(Directionality.of(tester.element(find.byType(OnboardingScreen))), TextDirection.ltr);
    await settleApp(tester);
    expect(find.text(_en.onboardingStyleTitle), findsOneWidget);

    await tester.tap(find.byWidgetPredicate((w) => w is ThemePreviewCard && w.id == MadarThemeId.aurora));
    await settleApp(tester);
    expect(app.settings.themeId, MadarThemeId.aurora);

    await tester.tap(find.text(_en.actionContinue));
    await settleApp(tester);
    expect(find.text(_en.onboardingStartTitle), findsOneWidget);

    await tester.tap(find.text(_en.onboardingStartFresh));
    await settleApp(tester);
    expect(app.settings.onboarded, isTrue);
    expect(app.location, AppRoutes.home);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('skip jumps to the last step; import hands over to the importer', (tester) async {
    final app = await pumpMadarApp(tester, settings: const AppSettings());
    await tester.tap(find.text(_ar.onboardingSkip));
    await settleApp(tester);
    expect(find.text(_ar.onboardingStartTitle), findsOneWidget);
    await tester.tap(find.text(_ar.onboardingImport));
    await settleApp(tester);
    expect(app.settings.onboarded, isTrue);
    expect(app.location, AppRoutes.import);
    expect(find.byType(ImportScreen), findsOneWidget);
  });
}
