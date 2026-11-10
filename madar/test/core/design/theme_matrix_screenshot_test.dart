// Phase 2 theme × language matrix of the app's own screens (onboarding,
// settings and its sub-pages, import, design gallery), rendered with the
// real fonts and shaders for the visual contrast / RTL audit:
//
//   flutter test --tags screenshot test/core/design/theme_matrix_screenshot_test.dart
//
// Writes screenshots/phase2/themes/<screen>_<lang>_<theme>.png. The orbit
// screens (home, planet page, prayer sheet) and the interaction sheets have
// their own matrix files next to this one.
@Tags(['screenshot'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/settings/app_settings.dart';

import '../../helpers/screenshot_harness.dart';
import '../../helpers/test_app.dart';
import 'theme_matrix.dart';

Future<void> _pumpFor(WidgetTester tester, Duration d) async {
  for (var t = Duration.zero; t < d; t += const Duration(milliseconds: 50)) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  for (final lang in matrixLanguages) {
    for (final theme in matrixThemes) {
      final suffix = '${lang}_${theme.name}';
      final settings = AppSettings(onboarded: true, themeId: theme, languageCode: lang);

      group('$suffix –', () {
        for (final (screen, location) in [
          ('settings', '/settings'),
          ('appearance', '/settings/appearance'),
          ('sound', '/settings/sound'),
          ('licenses', '/settings/licenses'),
          ('import', '/import'),
          ('gallery', '/gallery'),
        ]) {
          testWidgets(screen, (tester) async {
            final setup = await buildMadarTestApp(tester, settings: settings, initialLocation: location);
            await captureScreen(tester, setup.app, matrixShot(screen, lang, theme));
          });
        }

        testWidgets('appearance, scrolled to digits', (tester) async {
          final setup = await buildMadarTestApp(tester, settings: settings, initialLocation: '/settings/appearance');
          await captureScreen(
            tester,
            setup.app,
            matrixShot('appearance_lower', lang, theme),
            beforeCapture: (tester) async {
              await tester.drag(find.byType(Scrollable).last, const Offset(0, -700));
              await _pumpFor(tester, const Duration(milliseconds: 800));
            },
          );
        });

        final fresh = AppSettings(themeId: theme, languageCode: lang);
        testWidgets('onboarding welcome', (tester) async {
          final setup = await buildMadarTestApp(tester, settings: fresh);
          await captureScreen(tester, setup.app, matrixShot('onboarding_welcome', lang, theme));
        });

        for (final (step, name) in [(1, 'onboarding_style'), (2, 'onboarding_start')]) {
          testWidgets(name, (tester) async {
            final setup = await buildMadarTestApp(tester, settings: fresh);
            await captureScreen(
              tester,
              setup.app,
              matrixShot(name, lang, theme),
              beforeCapture: (tester) async {
                final l = lookupL10n(Locale(lang));
                for (var i = 0; i < step; i++) {
                  await tester.tap(find.text(i == 0 ? l.onboardingBegin : l.actionContinue));
                  await _pumpFor(tester, const Duration(milliseconds: 900));
                }
              },
            );
          });
        }
      });
    }

    // A custom accent, adapted per theme (a pale mint deepens on Pearl; a
    // hue picked on the rail).
    for (final (name, accent) in [('mint', Color(0xFF7FE3C4)), ('rail', Color(0xFFD65CBF))]) {
      for (final theme in [MadarThemeId.lapis, MadarThemeId.pearl]) {
        if (!matrixThemes.contains(theme)) continue;
        for (final (screen, location) in [('appearance', '/settings/appearance'), ('settings', '/settings')]) {
          testWidgets('custom accent $name, $screen, $lang ${theme.name}', (tester) async {
            final setup = await buildMadarTestApp(
              tester,
              settings: AppSettings(onboarded: true, themeId: theme, languageCode: lang, customAccent: accent),
              initialLocation: location,
            );
            await captureScreen(tester, setup.app, 'phase2/themes/accent_${name}_${screen}_${lang}_${theme.name}');
          });
        }
      }
    }

    // Follow the device: a light system → Pearl, a dark one → the chosen
    // (dark) theme.
    for (final brightness in Brightness.values) {
      testWidgets('follow system, $lang, ${brightness.name} device', (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        final setup = await buildMadarTestApp(
          tester,
          settings: AppSettings(onboarded: true, followSystem: true, themeId: MadarThemeId.emerald, languageCode: lang),
          initialLocation: '/settings/appearance',
        );
        await captureScreen(tester, setup.app, 'phase2/themes/follow_system_${lang}_${brightness.name}');
      });
    }
  }
}
