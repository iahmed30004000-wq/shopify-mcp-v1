// Phase 2 theme × language matrix of the Astrolabe Orbit screens: home (the
// scene and its glass panel), a planet page and the prayer sheet.
//
//   TZ=Asia/Amman flutter test --tags screenshot test/core/design/theme_matrix_orbit_screenshot_test.dart
//
// Writes screenshots/phase2/themes/{home,home_noon,home_night,planet,prayer_sheet}_<lang>_<theme>.png.
@Tags(['screenshot'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/orbit/data/orbit_repository.dart';
import 'package:madar/features/orbit/presentation/scene/orbit_scene.dart';

import '../../features/orbit/data/orbit_fixtures.dart';
import '../../features/orbit/presentation/orbit_scene_fixtures.dart';
import '../../helpers/test_app.dart';
import 'theme_matrix.dart';

final DateTime _now = DateTime(2026, 9, 27, 18, 40);

Future<SceneShots> _start(
  WidgetTester tester,
  MadarThemeId theme,
  String lang, {
  String location = '/',
  DateTime? now,
}) async {
  final clock = now ?? _now;
  final setup = await buildMadarTestApp(
    tester,
    now: clock,
    settings: AppSettings(onboarded: true, themeId: theme, languageCode: lang),
    initialLocation: location,
    beforePump: (MadarDatabase db) async {
      final r = Repositories(db);
      await OrbitRepository(r).setPrayerSettings(hostPrayerSettings());
      await seedLivedIn(r, now: clock, thriving: true, arabic: lang == 'ar');
    },
  );
  final shots = SceneShots(tester);
  await shots.start(setup.app, settle: const Duration(milliseconds: 2200));
  return shots;
}

void main() {
  for (final lang in matrixLanguages) {
    for (final theme in matrixThemes) {
      group('${lang}_${theme.name} –', () {
        testWidgets('home', (tester) async {
          final shots = await _start(tester, theme, lang);
          await shots.snap(matrixShot('home', lang, theme));
          shots.finish();
        });

        // The header and panel over the real sky at noon and at night
        // (Pearl's night sky is a deep slate: its header turns pearl).
        for (final (name, at) in [
          ('home_noon', DateTime(2026, 9, 27, 13, 10)),
          ('home_night', DateTime(2026, 9, 27, 22, 30)),
        ]) {
          testWidgets(name, (tester) async {
            final shots = await _start(tester, theme, lang, now: at);
            await shots.snap(matrixShot(name, lang, theme));
            shots.finish();
          });
        }

        testWidgets('planet page (Faith)', (tester) async {
          final shots = await _start(tester, theme, lang, location: '/planet/faith');
          await shots.snap(matrixShot('planet', lang, theme));
          shots.finish();
        });

        testWidgets('prayer sheet', (tester) async {
          final shots = await _start(tester, theme, lang);
          final c = tester.state<OrbitSceneState>(find.byType(OrbitScene)).controller;
          await tester.tapAt(c.prayerRect(Prayer.maghrib)!.center);
          await shots.frames(const Duration(milliseconds: 900));
          await shots.snap(matrixShot('prayer_sheet', lang, theme));
          shots.finish();
        });
      });
    }
  }
}
