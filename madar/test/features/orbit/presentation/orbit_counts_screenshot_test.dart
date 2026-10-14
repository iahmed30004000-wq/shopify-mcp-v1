// The sky at every world count the owner can reach, rendered for review:
//   TZ=Asia/Amman flutter test --tags screenshot \
//     test/features/orbit/presentation/orbit_counts_screenshot_test.dart
//
// Madar was composed for eight worlds; «السفرة» and «الألعاب» made ten, and
// he can add his own. These shots are the eye-check behind
// `orbit_orrery_test.dart`: at 1, 2, 5, 8, 10, 13 and 16 worlds the sky must
// still read as one deliberate orrery – nothing cut off by the screen edge,
// no clump, no empty half, no lane across the brass, and discs that look
// like a family. The three themes, both languages and text scale 1.3 are
// shot at the real ten, where the name labels are tightest.
@Tags(['screenshot'])
library;

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/orbit/data/orbit_repository.dart';
import 'package:madar/features/orbit/domain/planet_archetypes.dart';
import 'package:madar/features/orbit/presentation/scene/orbit_scene.dart';
import 'package:madar/features/orbit/presentation/scene/scene_controller.dart';

import '../../../helpers/test_app.dart';
import '../data/orbit_fixtures.dart';
import 'orbit_scene_fixtures.dart';

const _dir = 'orrery';

/// The styles a user-added world can take (the two borrowed shaders first,
/// then the built-in looks), so a sky of sixteen shows real variety.
const _extraStyles = [
  PlanetArchetype.ice,
  PlanetArchetype.desert,
  PlanetArchetype.verdant,
  PlanetArchetype.crystal,
  PlanetArchetype.gasGiant,
  PlanetArchetype.ocean,
  PlanetArchetype.volcanic,
  PlanetArchetype.industrial,
];

/// Leaves exactly [count] worlds in the sky: the seeded ten are hidden from
/// the back when fewer are wanted, and plain user-added worlds are appended
/// when more are.
Future<void> _worldCount(MadarDatabase db, int count) async {
  final rows = await (db.select(db.planets)..orderBy([(t) => OrderingTerm(expression: t.sortOrder)])).get();
  for (var i = count; i < rows.length; i++) {
    await (db.update(db.planets)..where((t) => t.id.equals(rows[i].id))).write(
      const PlanetsCompanion(hidden: Value(true)),
    );
  }
  for (var i = rows.length; i < count; i++) {
    final a = _extraStyles[(i - rows.length) % _extraStyles.length];
    await db
        .into(db.planets)
        .insert(
          PlanetsCompanion.insert(
            key: 'custom_x$i',
            nameAr: 'عالمي ${i + 1}',
            nameEn: 'World ${i + 1}',
            color: OrbitArchetypes.defaultColor(a).toARGB32(),
            archetype: a,
            sortOrder: Value(i),
          ),
        );
  }
}

Future<SceneShots> _home(
  WidgetTester tester, {
  required int count,
  MadarThemeId theme = MadarThemeId.lapis,
  String lang = 'ar',
  double textScale = 1,
}) async {
  final now = DateTime(2026, 9, 27, 12, 30);
  if (textScale != 1) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  final setup = await buildMadarTestApp(
    tester,
    now: now,
    settings: AppSettings(onboarded: true, themeId: theme, languageCode: lang),
    beforePump: (MadarDatabase db) async {
      final r = Repositories(db);
      await OrbitRepository(r).setPrayerSettings(hostPrayerSettings());
      await seedLivedIn(r, now: now, thriving: true, arabic: lang == 'ar');
      await _worldCount(db, count);
    },
  );
  final shots = SceneShots(tester);
  await shots.start(setup.app, settle: const Duration(milliseconds: 2200));
  return shots;
}

SceneController _scene(WidgetTester tester) => tester.state<OrbitSceneState>(find.byType(OrbitScene)).controller;

void main() {
  group('the sky at every count', () {
    for (final n in [1, 2, 5, 8, 10, 13, 16]) {
      testWidgets('$n worlds', (tester) async {
        final shots = await _home(tester, count: n);
        try {
          final c = _scene(tester);
          expect(c.planets.bodies.length, n);
          await shots.snap('$_dir/orrery_${n.toString().padLeft(2, '0')}_worlds');
        } finally {
          shots.finish();
        }
      }, timeout: const Timeout(Duration(minutes: 10)));
    }
  });

  group('ten worlds, every theme and language', () {
    for (final theme in MadarThemeId.values) {
      for (final lang in ['ar', 'en']) {
        testWidgets('${theme.name}, $lang', (tester) async {
          final shots = await _home(tester, count: 10, theme: theme, lang: lang);
          try {
            await shots.snap('$_dir/orrery_10_${lang}_${theme.name}');
          } finally {
            shots.finish();
          }
        }, timeout: const Timeout(Duration(minutes: 10)));
      }
    }
  });

  group('ten worlds at text scale 1.3 (the names must not collide)', () {
    for (final lang in ['ar', 'en']) {
      testWidgets(lang, (tester) async {
        final shots = await _home(tester, count: 10, lang: lang, textScale: 1.3);
        try {
          await shots.snap('$_dir/orrery_10_${lang}_lapis_text13');
        } finally {
          shots.finish();
        }
      }, timeout: const Timeout(Duration(minutes: 10)));
    }
  });
}
