import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/app/app_gate.dart';
import 'package:madar/app/splash.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/db_errors.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/tokens.dart';
import 'package:madar/core/design/widgets/ambient_motion.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/motion/motion.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/home/home_screen.dart';
import 'package:madar/features/onboarding/onboarding_screen.dart';
import 'package:madar/features/settings/settings_screen.dart';

import '../helpers/test_app.dart';

final _ar = lookupL10n(const Locale('ar'));
final _en = lookupL10n(const Locale('en'));

void main() {
  group('boot and routing', () {
    testWidgets('an onboarded app boots straight into home (Arabic, RTL)', (tester) async {
      final app = await pumpMadarApp(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(app.location, AppRoutes.home);
      expect(Directionality.of(tester.element(find.byType(HomeScreen))), TextDirection.rtl);
      expect(find.text(_ar.appName), findsWidgets);
    });

    testWidgets('first launch redirects to onboarding', (tester) async {
      final app = await pumpMadarApp(tester, settings: const AppSettings());
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(app.location, AppRoutes.onboarding);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('deep links respect onboarding too', (tester) async {
      final app = await pumpMadarApp(tester, settings: const AppSettings(), initialLocation: AppRoutes.settings);
      expect(app.location, AppRoutes.onboarding);
    });

    testWidgets('settings opens from home and back returns home', (tester) async {
      final app = await pumpMadarApp(tester);
      await tester.tap(find.bySemanticsLabel(_ar.homeOpenSettings));
      await settleApp(tester);
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(app.location, AppRoutes.settings);
      expect(app.sound.played, isNotEmpty);
      await tester.tap(find.bySemanticsLabel(_ar.actionBack));
      await settleApp(tester);
      expect(app.location, AppRoutes.home);
      expect(find.byType(SettingsScreen), findsNothing);
    });
  });

  group('instant language switch', () {
    testWidgets('flips Directionality and strings without a restart', (tester) async {
      final app = await pumpMadarApp(tester);
      final homeState = tester.state(find.byType(HomeScreen));
      final router = app.router;
      expect(Directionality.of(tester.element(find.byType(HomeScreen))), TextDirection.rtl);

      app.updateSettings((s) => s.copyWith(languageCode: 'en'));
      await tester.pump();
      // One frame later the whole tree reads left-to-right in English …
      expect(Directionality.of(tester.element(find.byType(HomeScreen))), TextDirection.ltr);
      expect(find.text(_en.appName), findsWidgets);
      expect(find.text(_ar.homeRadarTitle), findsNothing);
      // … on the same router and the same (never rebuilt) home screen.
      expect(identical(app.router, router), isTrue);
      expect(identical(tester.state(find.byType(HomeScreen)), homeState), isTrue);

      app.updateSettings((s) => s.copyWith(languageCode: 'ar'));
      await tester.pump();
      expect(Directionality.of(tester.element(find.byType(HomeScreen))), TextDirection.rtl);
      await settleApp(tester);
    });
  });

  group('theme switch', () {
    testWidgets('applies the new tokens, cross-fading through MadarTokens.lerp', (tester) async {
      final app = await pumpMadarApp(tester);
      MadarTokens tokens() => tester.element(find.byType(HomeScreen)).tokens;
      final lapis = MadarPalettes.tokensFor(MadarThemeId.lapis);
      final emerald = MadarPalettes.tokensFor(MadarThemeId.emerald);
      expect(tokens().space0, lapis.space0);

      app.updateSettings((s) => s.copyWith(themeId: MadarThemeId.emerald));
      await tester.pump();
      await tester.pump(MadarMotion.long ~/ 2);
      final mid = tokens().space0;
      expect(mid, isNot(lapis.space0));
      expect(mid, isNot(emerald.space0));
      await settleApp(tester);
      expect(tokens().space0, emerald.space0);
      expect(tokens().accent, emerald.accent);
    });

    testWidgets('custom accent and Pearl apply', (tester) async {
      final app = await pumpMadarApp(tester);
      const accent = Color(0xFF1FB5C9);
      app.updateSettings((s) => s.copyWith(themeId: MadarThemeId.pearl, customAccent: accent));
      await settleApp(tester);
      final t = tester.element(find.byType(HomeScreen)).tokens;
      expect(t.brightness, Brightness.light);
      expect(t.accent, accent);
    });

    testWidgets('with a custom accent, unrelated settings changes never replay the theme animation', (tester) async {
      final app = await pumpMadarApp(tester);
      app.updateSettings((s) => s.copyWith(customAccent: const Color(0xFF00AA88)));
      await settleApp(tester);
      bool animating() => ((tester.state(find.byType(AnimatedTheme)) as dynamic).controller as AnimationController).isAnimating;
      final theme = Theme.of(tester.element(find.byType(HomeScreen)));

      app.updateSettings((s) => s.copyWith(soundEnabled: !s.soundEnabled));
      await tester.pump();
      expect(animating(), isFalse);
      app.updateSettings((s) => s.copyWith(digits: DigitStyle.western));
      await tester.pump();
      expect(animating(), isFalse);
      expect(identical(Theme.of(tester.element(find.byType(HomeScreen))), theme), isTrue);

      // A real theme change still animates.
      app.updateSettings((s) => s.copyWith(themeId: MadarThemeId.desert));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(animating(), isTrue);
      await settleApp(tester);
    });

    testWidgets('battery saver turns the ambient loops off app-wide', (tester) async {
      final app = await pumpMadarApp(tester, initialLocation: AppRoutes.settings);
      bool ambientOf() => tester.element(find.byType(SettingsScreen)).ambientMotion;
      AmbientMotion.debugOverride = true;
      addTearDown(() => AmbientMotion.debugOverride = null);
      app.updateSettings((s) => s.copyWith(powerMode: PowerMode.batterySaver));
      await tester.pump();
      expect(ambientOf(), isFalse);
      app.updateSettings((s) => s.copyWith(powerMode: PowerMode.auto));
      await tester.pump();
      expect(ambientOf(), isTrue);
      AmbientMotion.debugOverride = null;
      await settleApp(tester);
    });

    testWidgets('reduced motion setting reaches MotionScope', (tester) async {
      final app = await pumpMadarApp(tester);
      expect(tester.element(find.byType(HomeScreen)).reducedMotion, isFalse);
      app.updateSettings((s) => s.copyWith(motion: MotionPreference.reduced));
      await tester.pump();
      expect(tester.element(find.byType(HomeScreen)).reducedMotion, isTrue);
      await settleApp(tester);
    });
  });

  group('database gate', () {
    testWidgets('shows the astrolabe splash until the database opens', (tester) async {
      final pending = Completer<MadarDatabase>();
      await pumpMadarApp(
        tester,
        database: false,
        settle: false,
        overrides: [databaseOpenerProvider.overrideWithValue((_) => pending.future)],
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(AstrolabeSplash), findsOneWidget);
      expect(find.text(_ar.shellSplashAssembling), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);

      final db = await openTestDatabase(tester);
      pending.complete(db);
      await tester.pump();
      await tester.pump(AstrolabeSplash.assembly);
      await settleApp(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(AstrolabeSplash), findsNothing);
    });

    testWidgets('a missing key offers retry and start-fresh (with confirmation)', (tester) async {
      var attempts = 0;
      var resets = 0;
      late MadarDatabase db;
      db = await openTestDatabase(tester);
      await pumpMadarApp(
        tester,
        database: false,
        settle: false,
        overrides: [
          databaseOpenerProvider.overrideWithValue((_) async {
            attempts++;
            if (resets == 0) {
              throw const DatabaseKeyException(DatabaseKeyProblem.missing, 'gone');
            }
            return db;
          }),
          databaseResetProvider.overrideWithValue(() async => resets++),
        ],
      );
      await tester.pump(AstrolabeSplash.assembly);
      await settleApp(tester);
      expect(find.text(_ar.shellGateErrorTitle), findsOneWidget);
      expect(find.text(_ar.dbErrorKeyMissing), findsOneWidget);

      await tester.tap(find.text(_ar.shellGateRetry));
      await tester.pump();
      await tester.pump(AstrolabeSplash.assembly);
      await settleApp(tester);
      expect(attempts, 2);
      expect(find.text(_ar.shellGateErrorTitle), findsOneWidget);

      await tester.tap(find.text(_ar.shellGateReset));
      await settleApp(tester);
      expect(find.text(_ar.shellGateResetTitle), findsOneWidget);
      expect(resets, 0);
      await tester.tap(find.text(_ar.shellGateResetConfirm));
      await tester.pump();
      await tester.pump(AstrolabeSplash.assembly);
      await settleApp(tester);
      expect(resets, 1);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('a malformed key offers start-fresh right away', (tester) async {
      await pumpMadarApp(
        tester,
        database: false,
        settle: false,
        overrides: [
          databaseOpenerProvider.overrideWithValue(
            (_) async => throw const DatabaseKeyException(DatabaseKeyProblem.malformed, 'bad'),
          ),
        ],
      );
      await tester.pump(AstrolabeSplash.assembly);
      await settleApp(tester);
      expect(find.text(_ar.dbErrorKeyMalformed), findsOneWidget);
      expect(find.text(_ar.shellGateReset), findsOneWidget);
    });

    testWidgets('unavailable secure storage offers start-fresh after a failed retry', (tester) async {
      var attempts = 0;
      await pumpMadarApp(
        tester,
        database: false,
        settle: false,
        overrides: [
          databaseOpenerProvider.overrideWithValue((_) async {
            attempts++;
            throw const DatabaseKeyException(DatabaseKeyProblem.storageUnavailable, 'keystore');
          }),
        ],
      );
      await tester.pump(AstrolabeSplash.assembly);
      await settleApp(tester);
      expect(find.text(_ar.dbErrorKeyStorage), findsOneWidget);
      expect(find.text(_ar.shellGateReset), findsNothing);

      await tester.tap(find.text(_ar.shellGateRetry));
      await tester.pump();
      await tester.pump(AstrolabeSplash.assembly);
      await settleApp(tester);
      expect(attempts, 2);
      expect(find.text(_ar.dbErrorKeyStorage), findsOneWidget);
      expect(find.text(_ar.shellGateReset), findsOneWidget);
    });

    testWidgets('a broken build (no cipher) offers retry only', (tester) async {
      await pumpMadarApp(
        tester,
        database: false,
        settle: false,
        overrides: [databaseOpenerProvider.overrideWithValue((_) async => throw CipherUnavailableError('no cipher'))],
      );
      await tester.pump(AstrolabeSplash.assembly);
      await settleApp(tester);
      expect(find.text(_ar.dbErrorCipherUnavailable), findsOneWidget);
      expect(find.text(_ar.shellGateRetry), findsOneWidget);
      expect(find.text(_ar.shellGateReset), findsNothing);
    });
  });

  test('canResetAfter only for unreadable files', () {
    expect(canResetAfter(const DatabaseKeyException(DatabaseKeyProblem.missing, '')), isTrue);
    expect(canResetAfter(const DatabaseKeyException(DatabaseKeyProblem.wrongKey, '')), isTrue);
    expect(canResetAfter(const DatabaseKeyException(DatabaseKeyProblem.malformed, '')), isTrue);
    expect(canResetAfter(const DatabaseKeyException(DatabaseKeyProblem.storageUnavailable, '')), isFalse);
    expect(
      canResetAfter(const DatabaseKeyException(DatabaseKeyProblem.storageUnavailable, ''), failedRetries: 1),
      isTrue,
    );
    expect(canResetAfter(CipherUnavailableError('x')), isFalse);
    expect(canResetAfter(CipherUnavailableError('x'), failedRetries: 3), isFalse);
  });
}
