// Art-direction pass over the integrated Money world inside the real app
// (router, AppGate, adhan host, app lock) with the real fonts and shaders:
// the Money planet's hub – the net worth, one-tap entries, the wallets,
// this month's plan, the dues and savings, the tools – lived-in and on a
// fresh install; and Settings › Money. Arabic/English across Lapis, Pearl
// and Aurora (Desert and Emerald for a few). Writes PNGs to
// madar/screenshots/phase5/hub/.
//
//   TZ=Asia/Amman flutter test --tags screenshot test/features/money/hub/money_hub_screenshot_test.dart
@Tags(['screenshot'])
// The whole app renders in software here: a scene of glass cards costs about
// a second a frame on a busy host.
@Timeout(Duration(minutes: 40))
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/routing/router.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/money/budget/budget.dart' show BudgetStatusCard;
import 'package:madar/features/money/hub/money_hub.dart';
import 'package:madar/features/orbit/presentation/planet/planet_page.dart';
import 'package:madar/features/settings/money_settings_section.dart';
import 'package:madar/features/settings/settings_screen.dart';

import '../../../helpers/screenshot_harness.dart';
import '../../../helpers/test_app.dart';
import '../../lock/lock_test_utils.dart';
import '../../orbit/presentation/orbit_scene_fixtures.dart' show preloadOrbitShaders;
import 'money_hub_seed.dart';

const _dir = 'phase5/hub';

Future<void> _frames(WidgetTester tester, [int n = 16]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _shot(
  WidgetTester tester,
  String name, {
  required String lang,
  required MadarThemeId theme,
  String location = '/planet/money',
  bool lived = true,
  Future<void> Function(WidgetTester tester)? beforeCapture,
}) async {
  await preloadOrbitShaders(tester);
  final setup = await buildMadarTestApp(
    tester,
    settings: AppSettings(onboarded: true, languageCode: lang, themeId: theme),
    initialLocation: location,
    now: moneyHubNow,
    beforePump: (MadarDatabase db) => lived ? seedMoneyHub(db, arabic: lang == 'ar') : seedMoneyFresh(db),
    overrides: LockFixture.empty().overrides,
  );
  await captureScreen(tester, setup.app, '$_dir/${name}_${lang}_${theme.name}', beforeCapture: beforeCapture);
}

/// Scrolls the planet sheet so [target] sits [below] its top edge.
Future<void> _sheetTo(WidgetTester tester, Finder target, {double below = 60}) async {
  final scrollable = find
      .descendant(
        of: find.byType(PlanetModulePage),
        matching: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down),
      )
      .first;
  final position = tester.state<ScrollableState>(scrollable).position;
  for (var pass = 0; pass < 3; pass++) {
    await _frames(tester, 4);
    final dy = tester.getTopLeft(target).dy - tester.getTopLeft(scrollable).dy - below;
    if (dy.abs() < 2) break;
    position.jumpTo((position.pixels + dy).clamp(position.minScrollExtent, position.maxScrollExtent));
  }
  await _frames(tester, 12);
}

/// Scrolls the settings root until the Money group sits near the top.
Future<void> _settingsToMoney(WidgetTester tester) async {
  final scrollable = find.descendant(of: find.byType(SettingsScreen), matching: find.byType(Scrollable)).first;
  final position = tester.state<ScrollableState>(scrollable).position;
  for (var pass = 0; pass < 6; pass++) {
    await _frames(tester, 4);
    final target = find.byType(MoneySettingsSection);
    if (target.evaluate().isEmpty) {
      position.jumpTo((position.pixels + 400).clamp(position.minScrollExtent, position.maxScrollExtent));
      continue;
    }
    final dy = tester.getTopLeft(target).dy - tester.getTopLeft(scrollable).dy - 90;
    if (dy.abs() < 2) break;
    position.jumpTo((position.pixels + dy).clamp(position.minScrollExtent, position.maxScrollExtent));
  }
  await _frames(tester, 16);
}

void main() {
  for (final lang in ['ar', 'en']) {
    for (final theme in [MadarThemeId.lapis, MadarThemeId.pearl, MadarThemeId.aurora]) {
      testWidgets('hub top $lang ${theme.name}', (tester) async {
        await _shot(
          tester,
          'hub_top',
          lang: lang,
          theme: theme,
          beforeCapture: (tester) => _sheetTo(tester, find.byType(MoneyNetWorthCard), below: 130),
        );
      });
    }

    for (final theme in [MadarThemeId.lapis, MadarThemeId.pearl]) {
      testWidgets('hub plan $lang ${theme.name}', (tester) async {
        await _shot(
          tester,
          'hub_plan',
          lang: lang,
          theme: theme,
          beforeCapture: (tester) => _sheetTo(tester, find.byType(BudgetStatusCard), below: 80),
        );
      });
    }

    testWidgets('hub tools $lang', (tester) async {
      await _shot(
        tester,
        'hub_tools',
        lang: lang,
        theme: lang == 'ar' ? MadarThemeId.desert : MadarThemeId.emerald,
        beforeCapture: (tester) => _sheetTo(tester, find.byType(MoneyTools), below: 60),
      );
    });

    testWidgets('hub fresh $lang', (tester) async {
      await _shot(
        tester,
        'hub_fresh',
        lang: lang,
        theme: lang == 'ar' ? MadarThemeId.lapis : MadarThemeId.pearl,
        lived: false,
        beforeCapture: (tester) => _sheetTo(tester, find.byType(MoneyNetWorthCard), below: 130),
      );
    });

    testWidgets('settings money $lang', (tester) async {
      await _shot(
        tester,
        'settings_money',
        lang: lang,
        theme: lang == 'ar' ? MadarThemeId.lapis : MadarThemeId.pearl,
        location: AppRoutes.settings,
        beforeCapture: _settingsToMoney,
      );
    });
  }
}
