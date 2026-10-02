// Art-direction matrix of the integrated Life worlds inside the real app
// (router, AppGate, app lock, real fonts and shaders): the hubs of Work,
// Family, Travel, Growth and Body on their planet pages (the packages'
// "today" cards, the tools, the world's trackers) in Arabic and English
// across Lapis, Pearl and Aurora; each hub at text scale 1.3 (a layout
// overflow fails the test); the moon sheets of a person and a board with
// their "Open …" button; Settings › Life; and a custom world's page with
// its trackers. Text contrast is measured on the painted pixels and
// printed (a review aid, not a gate). Writes PNGs to
// madar/screenshots/phase6/integrated/.
//
//   flutter test --tags screenshot test/features/life/life_integrated_screenshot_test.dart
@Tags(['screenshot'])
@Timeout(Duration(minutes: 60))
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/routing/router.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/body/body.dart' show BodyTodayCard;
import 'package:madar/features/custom_modules/custom_modules.dart';
import 'package:madar/features/family/family.dart' show FamilyTodayCard;
import 'package:madar/features/growth/growth.dart' show GrowthTodayCard;
import 'package:madar/features/orbit/data/planet_customization_service.dart';
import 'package:madar/features/orbit/presentation/planet/planet_page.dart';
import 'package:madar/features/prayer/prayer.dart' show cityDatabaseProvider;
import 'package:madar/features/settings/life_settings_section.dart';
import 'package:madar/features/travel/travel.dart' show TravelTodayCard;
import 'package:madar/features/work/work.dart' show Top3Card;

import '../../core/design/rendered_contrast.dart';
import '../../helpers/screenshot_harness.dart';
import '../../helpers/test_app.dart';
import '../body/body_harness.dart' show bodyTestNow;
import '../body/body_seed.dart';
import '../custom_modules/custom_harness.dart' show customTestNow, seedCustom;
import '../family/family_seed.dart';
import '../growth/growth_harness.dart' show growthTestNow, seedScenario;
import '../lock/lock_test_utils.dart';
import '../orbit/presentation/orbit_scene_fixtures.dart' show preloadOrbitShaders;
import '../travel/travel_harness.dart' show seedTravelScenario, travelTestCities, travelTestNow;
import '../work/work_harness.dart' as wh;

const _dir = 'phase6/integrated';

/// A world's example: its package's own sample data, plus the trackers
/// (some attached to this world), at the package's sample "now".
typedef _World = ({String key, DateTime now, Future<void> Function(MadarDatabase db, String lang) seed, Type first});

final List<_World> _worlds = [
  (
    key: 'work',
    now: wh.workTestNow,
    seed: (db, lang) async {
      await wh.seedWork(wh.WorkTestEnv(db, wh.RecordingHaptics(), SilentSoundService(), wh.workTestNow), lang: lang);
      await seedCustom(db, languageCode: lang, now: wh.workTestNow);
    },
    first: Top3Card,
  ),
  (
    key: 'family',
    now: familyTestNow,
    seed: (db, lang) async {
      await seedFamily(db, arabic: lang == 'ar');
      await seedCustom(db, languageCode: lang, now: familyTestNow);
    },
    first: FamilyTodayCard,
  ),
  (
    key: 'travel',
    now: travelTestNow,
    seed: (db, lang) async {
      await seedTravelScenario(db, lang: lang);
      await seedCustom(db, languageCode: lang, now: travelTestNow);
    },
    first: TravelTodayCard,
  ),
  (
    key: 'growth',
    now: growthTestNow,
    seed: (db, lang) async {
      await seedScenario(db, lang: lang);
      await seedCustom(db, languageCode: lang, now: growthTestNow);
    },
    first: GrowthTodayCard,
  ),
  (
    key: 'body',
    now: bodyTestNow,
    seed: (db, lang) async {
      await seedBody(db, BodySeed.full, now: bodyTestNow, arabic: lang == 'ar');
      await seedCustom(db, languageCode: lang, now: bodyTestNow);
    },
    first: BodyTodayCard,
  ),
];

Future<void> _frames(WidgetTester tester, [int n = 16]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// The planet page's scrolling sheet.
Finder _planetSheet() => find.descendant(
  of: find.byType(PlanetModulePage),
  matching: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down),
);

/// Scrolls the planet sheet (building lazily) until [target] sits [below]
/// its top edge.
Future<void> _sheetTo(WidgetTester tester, Finder target, {double below = 60}) async {
  final scrollable = _planetSheet().first;
  final position = tester.state<ScrollableState>(scrollable).position;
  for (var i = 0; i < 12 && target.evaluate().isEmpty; i++) {
    position.jumpTo((position.pixels + 300).clamp(position.minScrollExtent, position.maxScrollExtent));
    await _frames(tester, 2);
  }
  for (var pass = 0; pass < 3; pass++) {
    await _frames(tester, 4);
    final dy = tester.getTopLeft(target.first).dy - tester.getTopLeft(scrollable).dy - below;
    if (dy.abs() < 2) break;
    position.jumpTo((position.pixels + dy).clamp(position.minScrollExtent, position.maxScrollExtent));
  }
  await _frames(tester, 12);
}

/// Global rects of the sheet's text that sits (partly) above the sheet's
/// top edge, where the sheet clips it.
List<Rect> _clippedUnderPlanet(WidgetTester tester) {
  final sheet = _planetSheet();
  if (sheet.evaluate().isEmpty) return const [];
  final top = tester.getTopLeft(sheet.first).dy;
  return [
    for (final e in find.descendant(of: sheet.first, matching: find.byType(RichText)).evaluate())
      if (e.renderObject case final RenderBox box when box.attached && box.hasSize)
        if ((box.localToGlobal(Offset.zero) & box.size) case final rect when rect.top < top - 0.5) rect,
  ];
}

/// Text worth measuring (a separator is a few anti-aliased pixels).
final RegExp _readable = RegExp(r'[\p{L}\p{N}]', unicode: true);

Future<void> _shot(
  WidgetTester tester, {
  required String name,
  required String lang,
  required MadarThemeId theme,
  required String start,
  required DateTime now,
  required Future<void> Function(MadarDatabase db) seed,
  Future<void> Function(WidgetTester tester)? before,
  double textScale = 1,
  List<Override> overrides = const [],
}) async {
  if (textScale != 1) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  await preloadOrbitShaders(tester);
  final setup = await buildMadarTestApp(
    tester,
    settings: AppSettings(onboarded: true, languageCode: lang, themeId: theme),
    initialLocation: start,
    now: now,
    beforePump: seed,
    overrides: [
      ...LockFixture.empty().overrides,
      cityDatabaseProvider.overrideWith((ref) async => travelTestCities()),
      ...overrides,
    ],
  );
  final suffix = textScale == 1 ? '' : '_x${(textScale * 10).round()}';
  final boundary = GlobalKey();
  final misses = <TextContrast>[];
  await captureScreen(
    tester,
    RepaintBoundary(key: boundary, child: setup.app),
    '$_dir/${name}_${lang}_${theme.name}$suffix',
    settle: const Duration(milliseconds: 1400),
    beforeCapture: (tester) async {
      await before?.call(tester);
      await _frames(tester, 10);
      // On a planet page, the sheet's text scrolled up past its top edge is
      // clipped away under the planet – not on screen at all.
      final clipped = _clippedUnderPlanet(tester);
      misses.addAll([
        for (final r in await measureRenderedContrast(tester, boundary))
          if (!r.passes &&
              !r.icon &&
              _readable.hasMatch(r.text) &&
              !clipped.any((c) => c.inflate(1).contains(r.rect.center)))
            r,
      ]);
    },
    trailingFrames: 4,
  );
  expect(tester.takeException(), isNull, reason: 'a layout overflow');
  if (misses.isNotEmpty) {
    // ignore: avoid_print
    print('CONTRAST $name $lang ${theme.name}$suffix:\n  ${misses.join('\n  ')}');
  }
}

void main() {
  const themes = [MadarThemeId.lapis, MadarThemeId.pearl, MadarThemeId.aurora];
  for (final w in _worlds) {
    for (final lang in ['ar', 'en']) {
      final l = lookupL10n(Locale(lang));
      for (final theme in themes) {
        testWidgets('hub ${w.key} $lang ${theme.name}', (tester) async {
          await _shot(
            tester,
            name: 'hub_${w.key}',
            lang: lang,
            theme: theme,
            start: AppRoutes.planetOf(w.key),
            now: w.now,
            seed: (db) => w.seed(db, lang),
            before: (tester) => _sheetTo(tester, find.byType(w.first), below: 16),
          );
        });
      }
      testWidgets('hub ${w.key} $lang tools', (tester) async {
        await _shot(
          tester,
          name: 'hub_${w.key}_tools',
          lang: lang,
          theme: lang == 'ar' ? MadarThemeId.lapis : MadarThemeId.pearl,
          start: AppRoutes.planetOf(w.key),
          now: w.now,
          seed: (db) => w.seed(db, lang),
          before: (tester) => _sheetTo(tester, find.text(l.lifeHubToolsTitle), below: 16),
        );
      });
      testWidgets('hub ${w.key} $lang text x1.3', (tester) async {
        await _shot(
          tester,
          name: 'hub_${w.key}',
          lang: lang,
          theme: lang == 'ar' ? MadarThemeId.lapis : MadarThemeId.pearl,
          start: AppRoutes.planetOf(w.key),
          now: w.now,
          seed: (db) => w.seed(db, lang),
          textScale: 1.3,
          before: (tester) async {
            // Lay out every part of the hub on the way down.
            await _sheetTo(tester, find.byType(w.first), below: 16);
            await _sheetTo(tester, find.text(l.lifeHubToolsTitle), below: 16);
            await _sheetTo(tester, find.byType(CustomModulesCard), below: 16);
          },
        );
      });
    }
  }

  for (final lang in ['ar', 'en']) {
    final l = lookupL10n(Locale(lang));
    testWidgets('moon person $lang', (tester) async {
      late String mother;
      await _shot(
        tester,
        name: 'moon_person',
        lang: lang,
        theme: MadarThemeId.lapis,
        start: AppRoutes.home,
        now: familyTestNow,
        seed: (db) async => mother = (await seedFamily(db, arabic: lang == 'ar'))['mother']!.id,
        before: (tester) async {
          _go(tester, AppRoutes.planetOf('family', item: 'people:$mother'));
          await _frames(tester, 60);
          expect(find.text(l.lifeHubMoonOpenPerson), findsOneWidget);
        },
      );
    });

    testWidgets('moon board $lang', (tester) async {
      late String board;
      await _shot(
        tester,
        name: 'moon_board',
        lang: lang,
        theme: MadarThemeId.pearl,
        start: AppRoutes.home,
        now: wh.workTestNow,
        seed: (db) async => board = (await wh.seedWork(
          wh.WorkTestEnv(db, wh.RecordingHaptics(), SilentSoundService(), wh.workTestNow),
          lang: lang,
        )).store.id,
        before: (tester) async {
          _go(tester, AppRoutes.planetOf('work', item: 'boards:$board'));
          await _frames(tester, 60);
          expect(find.text(l.lifeHubMoonOpenBoard), findsOneWidget);
        },
      );
    });

    for (final theme in [MadarThemeId.lapis, MadarThemeId.pearl]) {
      testWidgets('settings life $lang ${theme.name}', (tester) async {
        await _shot(
          tester,
          name: 'settings_life',
          lang: lang,
          theme: theme,
          start: AppRoutes.settings,
          now: customTestNow,
          seed: (db) => seedCustom(db, languageCode: lang),
          before: (tester) async {
            final section = find.byType(LifeSettingsSection);
            await tester.scrollUntilVisible(section, 300, scrollable: find.byType(Scrollable).first);
            await Scrollable.ensureVisible(tester.element(section), alignment: 0.15);
            await _frames(tester, 8);
          },
        );
      });
    }

    testWidgets('custom world $lang', (tester) async {
      late String key;
      await _shot(
        tester,
        name: 'custom_world',
        lang: lang,
        theme: MadarThemeId.aurora,
        start: AppRoutes.home,
        now: customTestNow,
        seed: (db) async {
          final repos = Repositories(db);
          final (row, _) = await PlanetCustomizationService(repos)
              .addPlanet(name: lang == 'ar' ? 'حديقتي' : 'My garden', archetype: PlanetArchetype.values[4]);
          key = row.key;
          final ids = await seedCustom(db, languageCode: lang);
          final service = CustomModulesService(repos);
          for (final k in [ModuleTemplateKey.dailyHabit, ModuleTemplateKey.sleepLog]) {
            final m = (await service.module(ids[k]!))!;
            await service.updateModule(m.copyWith(planetKey: key));
          }
        },
        before: (tester) async {
          _go(tester, AppRoutes.planetOf(key));
          await _frames(tester, 60);
          await _sheetTo(tester, find.byType(CustomModulesCard), below: 16);
        },
      );
    });
  }
}

/// `go` on the running app's router.
void _go(WidgetTester tester, String location) =>
    GoRouter.of(tester.element(find.byType(Navigator).first)).go(location);
