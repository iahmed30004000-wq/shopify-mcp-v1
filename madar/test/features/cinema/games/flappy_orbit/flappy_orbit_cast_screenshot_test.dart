@Tags(['screenshot'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/engine/cinema_engine.dart';
import 'package:madar/features/cinema/games/flappy_orbit/flappy_orbit_conductor.dart';
import 'package:madar/features/cinema/games/flappy_orbit/flappy_orbit_pilot.dart';

import '../../../../helpers/screenshot_harness.dart';
import '../../rig/model_sheet.dart';

// Model sheets of the Flappy Orbit cast, painted by the game's own rig code
// into screenshots/cinema/games/flappy_orbit/cast_*.png: Maestro Ghaym in
// his three phases, tells and attacks, and Falak the pilot. LOOK at them
// after every change to a character.

const _sheetSize = Size(1000, 1250);

/// One scale for every row of Falak's sheet, so the drawings compare.
const _falakScale = 1.45;

SheetCell _cell<T extends RigCharacter>(String label, T Function() make, void Function(T r) setup, {double height = 100}) {
  final rig = make();
  setup(rig);
  return SheetCell(label: label, paint: rig.paint, height: height);
}

void main() {
  setUpAll(() async {
    await loadMadarFonts();
    await CinemaShaders.preload();
  });

  testWidgets('Maestro Ghaym model sheet', (tester) async {
    ConductorCloud mk() => ConductorCloud(height: 100)..expression = RigExpression.angry;
    SheetCell cell(String label, void Function(ConductorCloud r) setup) => _cell(label, mk, setup, height: 130);
    await captureScreen(
      tester,
      madarScreenshotApp(
        home: ModelSheet(
          title: 'MAESTRO GHAYM · المايسترو غَيم',
          subtitle: 'the conductor-cloud of "Flappy Orbit" · phases, tells and attacks',
          rows: [
            SheetRow('PHASES', [
              for (final p in [0, 1, 2])
                cell('phase $p', (r) {
                  r
                    ..phase = p
                    ..facing = -0.6;
                  run(r, 1.1);
                }),
              cell('sly (shrugs a hit off)', (r) {
                r
                  ..facing = -0.6
                  ..expression = RigExpression.sly;
                run(r, 1.1);
              }),
              cell('defeated', (r) {
                r
                  ..phase = 2
                  ..act(RigAction.defeated);
                run(r, 1.2);
              }),
            ]),
            SheetRow('TELLS AND ATTACKS', [
              cell('gust tell', (r) {
                r
                  ..facing = -1
                  ..attack = CloudAttack.gust
                  ..windUp = 1;
                run(r, 0.6);
              }),
              cell('gust!', (r) {
                r
                  ..facing = -1
                  ..attack = CloudAttack.gust
                  ..act(RigAction.attack);
                run(r, 0.3);
              }),
              cell('baton tell', (r) {
                r
                  ..facing = -1
                  ..attack = CloudAttack.thunder
                  ..windUp = 1;
                run(r, 0.6);
              }),
              cell('thunder flick', (r) {
                r
                  ..facing = -1
                  ..attack = CloudAttack.thunder
                  ..act(RigAction.attack);
                run(r, 0.2);
              }),
              cell('hurt', (r) {
                r
                  ..facing = -1
                  ..expression = RigExpression.surprised
                  ..act(RigAction.hurt);
                run(r, 0.12);
              }),
            ]),
            SheetRow('MOODS', [
              for (final e in [RigExpression.neutral, RigExpression.angry, RigExpression.happy, RigExpression.surprised])
                cell(e.name, (r) {
                  r
                    ..facing = 0
                    ..expression = e;
                  run(r, 0.8);
                }),
              cell('taunt', (r) {
                r
                  ..facing = -0.6
                  ..act(RigAction.taunt);
                run(r, 0.7);
              }),
            ]),
          ],
        ),
      ),
      'cinema/games/flappy_orbit/cast_maestro',
      settle: const Duration(milliseconds: 100),
      logicalSize: _sheetSize,
      dpr: 1.5,
    );
  });

  testWidgets('Falak model sheet', (tester) async {
    OrbitPilot mk() => OrbitPilot(height: 84)..expression = RigExpression.determined;
    // The rocket is about two and a half heads long: three drawings a row.
    SheetCell cell(String label, void Function(OrbitPilot r) setup) => _cell(label, mk, setup, height: 160);
    SheetCell pose(RigAction a) => cell(a.name, (r) {
      r.act(a);
      run(r, a == RigAction.jump ? 0.15 : (a == RigAction.hurt ? 0.12 : 0.8));
    });
    SheetCell mood(RigExpression e) => cell(e.name, (r) {
      r.expression = e;
      run(r, 0.8);
    });
    await captureScreen(
      tester,
      madarScreenshotApp(
        home: ModelSheet(
          title: 'FALAK · فَلَك',
          subtitle: 'the astrolabe-headed pilot of "Flappy Orbit" · poses and moods',
          rows: [
            SheetRow('POSES', [pose(RigAction.idle), pose(RigAction.jump), pose(RigAction.hurt)], scale: _falakScale),
            SheetRow('', [pose(RigAction.cheer), pose(RigAction.defeated)], scale: _falakScale),
            SheetRow('MOODS', [mood(RigExpression.determined), mood(RigExpression.happy), mood(RigExpression.scared)], scale: _falakScale),
            SheetRow('', [mood(RigExpression.surprised), mood(RigExpression.dizzy)], scale: _falakScale),
          ],
        ),
      ),
      'cinema/games/flappy_orbit/cast_falak',
      settle: const Duration(milliseconds: 100),
      logicalSize: const Size(1000, 1500),
      dpr: 1.5,
    );
  });
}
