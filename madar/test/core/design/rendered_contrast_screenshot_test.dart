// Rendered-pixel WCAG audit: every text actually painted on the app's
// screens – in all five themes, a custom accent, both languages and under
// the sky at noon, dusk and night – reaches AA on what is really behind it
// (smoked glass over the nebula, a planet's sheet over its hero, the open
// sky), including the shared sheets and the undo toast. Icons are graphics
// (3:1) and only reported – the app's icons sit beside their labels, which
// makes them decorative under WCAG 1.4.11; text under a sheet's modal
// barrier and disabled (≤ 40 %) text are exempt, as in WCAG 1.4.3.
// The token contract (theme_contrast_test.dart) models the surfaces;
// this measures them, so a shader, glass or tint change cannot quietly
// undo it.
//
// Slow (real fonts and shaders), so it runs with the screenshot tag:
//   TZ=Asia/Amman flutter test --tags screenshot test/core/design/rendered_contrast_screenshot_test.dart
// Narrow it with MATRIX_THEMES / MATRIX_LANGS (see theme_matrix.dart).
@Tags(['screenshot'])
library;

import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/widgets/ambient_motion.dart';
import 'package:madar/core/design/widgets/shader_cache.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/interaction/interaction.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/home/widgets/task_actions.dart';
import 'package:madar/features/orbit/data/orbit_repository.dart';
import 'package:madar/features/settings/settings_screen.dart';

import '../../features/orbit/data/orbit_fixtures.dart';
import '../../features/orbit/presentation/orbit_scene_fixtures.dart';
import '../../helpers/screenshot_harness.dart';
import '../../helpers/test_app.dart';
import 'rendered_contrast.dart';
import 'theme_matrix.dart';

/// Renders [location] and returns every text that misses AA (icons are
/// graphics: 3 : 1, and only reported – the app's icons sit next to their
/// labels, so they are decorative under WCAG 1.4.11).
Future<List<TextContrast>> _audit(
  WidgetTester tester, {
  required MadarThemeId theme,
  required String lang,
  required String location,
  DateTime? now,
  Color? accent,
  bool onboarded = true,
  Future<void> Function(WidgetTester tester, MadarDatabase db)? open,
}) async {
  final clock = now ?? DateTime(2026, 9, 27, 18, 40);
  late MadarDatabase database;
  final setup = await buildMadarTestApp(
    tester,
    now: clock,
    settings: AppSettings(onboarded: onboarded, themeId: theme, languageCode: lang, customAccent: accent),
    initialLocation: location,
    beforePump: (MadarDatabase db) async {
      database = db;
      final r = Repositories(db);
      await OrbitRepository(r).setPrayerSettings(hostPrayerSettings());
      await seedLivedIn(r, now: clock, thriving: true, arabic: lang == 'ar');
    },
  );
  await tester.runAsync(() async {
    await loadMadarFonts();
    await MadarShaders.preload();
  });
  await preloadOrbitShaders(tester);
  tester.view.physicalSize = const Size(412, 915) * 2.625;
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  AmbientMotion.debugOverride = true;
  final shadows = debugDisableShadows;
  debugDisableShadows = false;
  try {
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(key: key, child: setup.app));
    for (var i = 0; i < 140; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    if (open != null) {
      await open(tester, database);
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }
    final all = await measureRenderedContrast(tester, key);
    expect(all.length, greaterThan(3), reason: 'nothing measured on $location');
    return [
      for (final r in all)
        if (!r.passes && !r.icon) r,
    ];
  } finally {
    debugDisableShadows = shadows;
    AmbientMotion.debugOverride = null;
  }
}

typedef _Show = void Function(TaskActions actions, TaskRow task, BuildContext context, L10n l);

final List<(String, _Show)> _sheets = [
  ('edit sheet', (a, task, _, _) => unawaited(a.edit(task))),
  ('reminder sheet', (a, task, _, _) => unawaited(a.setReminder(task))),
  (
    'undo toast',
    (_, _, context, l) => unawaited(showUndoToast(context, UndoableAction(label: l.itemDeleted, undo: () async {}))),
  ),
];

/// Adds a task and opens [show] for it from the Settings screen.
Future<void> _openOnSettings(WidgetTester tester, MadarDatabase db, String lang, _Show show) async {
  final title = lang == 'ar' ? 'الاتصال بالوالدة بعد العصر' : 'Call Mum after Asr';
  final task = (await tester.runAsync(() async {
    await db
        .into(db.tasks)
        .insert(
          TasksCompanion.insert(
            title: title,
            window: const Value(PrayerWindow.asr),
            planetKey: const Value('family'),
            notes: Value(lang == 'ar' ? 'اسألها عن موعد الطبيب يوم ١٢' : 'Ask about the doctor on the 12th'),
          ),
        );
    return (db.select(db.tasks)..where((t) => t.title.equals(title))).getSingle();
  }))!;
  final element = tester.element(find.byType(SettingsScreen));
  show(TaskActions(element as WidgetRef, element), task, element, L10n.of(element));
}

void main() {
  const screens = [
    '/settings',
    '/settings/appearance',
    '/settings/sound',
    '/settings/licenses',
    '/import',
    '/',
    '/planet/faith',
  ];

  for (final lang in matrixLanguages) {
    for (final theme in matrixThemes) {
      group('${lang}_${theme.name} –', () {
        for (final location in screens) {
          testWidgets('every text on $location reaches AA', (tester) async {
            final fails = await _audit(tester, theme: theme, lang: lang, location: location);
            expect(fails, isEmpty, reason: fails.join('\n'));
          });
        }

        testWidgets('onboarding welcome reaches AA', (tester) async {
          final fails = await _audit(tester, theme: theme, lang: lang, location: '/', onboarded: false);
          expect(fails, isEmpty, reason: fails.join('\n'));
        });

        // The shared sheets and the undo toast, opened through the app's own
        // glue over Settings.
        for (final (name, show) in _sheets) {
          testWidgets('the $name reaches AA', (tester) async {
            final fails = await _audit(
              tester,
              theme: theme,
              lang: lang,
              location: '/settings',
              open: (tester, db) => _openOnSettings(tester, db, lang, show),
            );
            expect(fails, isEmpty, reason: fails.join('\n'));
          });
        }

        // The home header and panel sit on the real sky: noon, the deep
        // dusk (mid-grey on Pearl) and night.
        for (final (name, at) in [
          ('noon', DateTime(2026, 9, 27, 13, 10)),
          ('deep dusk', DateTime(2026, 9, 27, 19, 12)),
          ('night', DateTime(2026, 9, 27, 22, 30)),
        ]) {
          testWidgets('home under the $name sky reaches AA', (tester) async {
            final fails = await _audit(tester, theme: theme, lang: lang, location: '/', now: at);
            expect(fails, isEmpty, reason: fails.join('\n'));
          });
        }
      });
    }

    // A custom accent adapted per theme (a pale mint that must deepen on
    // Pearl; a saturated blue that must lift on the night themes).
    for (final (name, accent) in [('mint', Color(0xFF7FE3C4)), ('blue', Color(0xFF0000FF))]) {
      for (final theme in [MadarThemeId.lapis, MadarThemeId.pearl]) {
        if (!matrixThemes.contains(theme)) continue;
        for (final location in ['/settings/appearance', '/']) {
          testWidgets('$lang ${theme.name}, custom $name accent: $location reaches AA', (tester) async {
            final fails = await _audit(tester, theme: theme, lang: lang, location: location, accent: accent);
            expect(fails, isEmpty, reason: fails.join('\n'));
          });
        }
      }
    }
  }
}
