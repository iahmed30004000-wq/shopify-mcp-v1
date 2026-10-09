import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/features/orbit/data/orbit_providers.dart';
import 'package:madar/features/orbit/data/orbit_repository.dart';
import 'package:madar/features/orbit/presentation/scene/orbit_scene.dart';
import 'package:madar/features/orbit/presentation/scene/scene_controller.dart';

import '../../../helpers/test_app.dart';
import '../data/orbit_fixtures.dart';
import 'orbit_scene_fixtures.dart';

SceneController _scene(WidgetTester tester) => tester.state<OrbitSceneState>(find.byType(OrbitScene)).controller;

void main() {
  testWidgets('diag moons', (tester) async {
    final app = await pumpMadarApp(
      tester,
      beforePump: (db) async {
        final r = Repositories(db);
        await OrbitRepository(r).setPrayerSettings(hostPrayerSettings());
        await seedLivedIn(r, now: testNow, thriving: true);
      },
    );
    await tester.pump(const Duration(milliseconds: 400));
    await settleApp(tester);
    final snap = app.container.read(sceneSnapshotProvider).value!;
    for (final p in snap.planets) {
      // ignore: avoid_print
      print('PLANET ${p.key} moons=${p.moons.length} overflow=${p.moonOverflow}');
    }
    final c = _scene(tester);
    for (var step = 0; step < 4; step++) {
      final f = c.planets.frameFor(c.viewport);
      // ignore: avoid_print
      print('--- step $step  core r=${f.coreRadius.toStringAsFixed(1)} at ${f.coreCenter}');
      for (final b in f.bodies) {
        final ms = b.moons
            .map(
              (m) =>
                  '${m.moon.label}:r=${m.radius.toStringAsFixed(1)},vis=${m.visible},d=${(m.center - b.center).distance.toStringAsFixed(0)},dial=${((m.center - f.coreCenter).distance < f.coreRadius && m.depth > f.coreDepth)}',
            )
            .join(' | ');
        // ignore: avoid_print
        print('  ${b.key} R=${b.radius.toStringAsFixed(1)} vis=${b.visible} behindCore=${b.behindCore} :: $ms');
      }
      c.planets.advanceSeconds(7);
      c.refresh();
    }
  });
}
