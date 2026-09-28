import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/domain/enums.dart';
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

  testWidgets('defaults seeded in Arabic on first launch follow English picked in onboarding', (tester) async {
    // First launch: the database is seeded before onboarding, in the default
    // language (Arabic) – exactly what the unlock provider does.
    final app = await pumpMadarApp(tester, settings: const AppSettings());
    Future<List<String>> habits() async => (await tester.runAsync(
      () => (app.db.select(app.db.habits)..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).get(),
    ))!.map((h) => h.name).toList();
    Future<List<String>> painLocations() async => (await tester.runAsync(
      () => (app.db.select(app.db.tagOptions)
            ..where((t) => t.kind.equalsValue(TagKind.painLocation))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get(),
    ))!.map((t) => t.label).toList();
    expect((await habits()).first, _ar.dbSeedHabitBreathing);

    await tester.tap(find.text(_ar.onboardingBegin));
    await settleApp(tester);
    await tester.tap(find.text(_ar.settingsLanguageEnglish));
    await settleApp(tester);
    await tester.tap(find.text(_en.actionContinue));
    await settleApp(tester);
    await tester.tap(find.text(_en.onboardingStartFresh));
    await settleApp(tester);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await settleApp(tester);

    expect(app.settings.languageCode, 'en');
    expect((await habits()).first, _en.dbSeedHabitBreathing);
    expect(await habits(), isNot(contains(_ar.dbSeedHabitWalk)));
    expect((await painLocations()).first, _en.dbSeedPainHead);
  });

  testWidgets('system back walks the steps back before it can leave onboarding', (tester) async {
    await pumpMadarApp(tester, settings: const AppSettings());
    await tester.tap(find.text(_ar.onboardingBegin));
    await settleApp(tester);
    expect(find.text(_ar.onboardingStyleTitle), findsOneWidget);

    final popped = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      popped.add(call.method);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.binding.handlePopRoute();
    await settleApp(tester);
    expect(find.text(_ar.onboardingWelcomeTagline), findsOneWidget);
    expect(popped, isNot(contains('SystemNavigator.pop')));
  });

  testWidgets('skip jumps to the last step; import hands over to the importer', (tester) async {
    final app = await pumpMadarApp(tester, settings: const AppSettings());
    await tester.tap(find.text(_ar.onboardingSkip));
    await settleApp(tester);
    expect(find.text(_ar.onboardingStartTitle), findsOneWidget);
    // Choice cards use the self-mirroring chevron (never a second flip).
    expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
    expect(find.byIcon(Icons.chevron_right_rounded), findsWidgets);
    await tester.tap(find.text(_ar.onboardingImport));
    await settleApp(tester);
    expect(app.settings.onboarded, isTrue);
    expect(app.location, AppRoutes.import);
    expect(find.byType(ImportScreen), findsOneWidget);
  });
}
