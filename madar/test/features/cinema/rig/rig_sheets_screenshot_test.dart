@Tags(['screenshot'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/engine/cinema_engine.dart';
import 'package:madar/features/cinema/engine/rig/rig_kit.dart';

import '../../../helpers/screenshot_harness.dart';
import 'model_sheet.dart';

// Model sheets of the procedural rubber-hose rig and the original cast:
// turnarounds, expressions and pose cycles, painted by the real rig code
// into screenshots/cinema/rig/*.png. LOOK at them after every rig change.

SheetCell _rig(String label, RigCharacter Function() make, void Function(RigCharacter r) setup, {double height = 100}) {
  final rig = make();
  setup(rig);
  return SheetCell(label: label, paint: rig.paint, height: height);
}

/// A standard character sheet: turnaround, expressions, two rows of actions.
ModelSheet _castSheet(
  String title,
  String subtitle,
  Era era,
  RigCharacter Function() make, {
  double height = 100,
  bool dark = false,
  double runSpeed = 220,
}) {
  SheetCell cell(String label, void Function(RigCharacter r) setup) => _rig(label, make, setup, height: height);
  return ModelSheet(
    title: title,
    subtitle: subtitle,
    era: era,
    dark: dark,
    rows: [
      SheetRow('TURNAROUND', [
        for (final f in [-1.0, -0.4, 0.0, 0.4, 1.0])
          cell('facing $f', (r) {
            r.facing = f;
            run(r, 1.2);
          }),
      ]),
      SheetRow('EXPRESSIONS', [
        for (final e in RigExpression.values)
          cell(e.name, (r) {
            r
              ..facing = 0.5
              ..expression = e;
            run(r, 0.5);
          }),
      ]),
      SheetRow('ACTIONS I', [
        for (final a in [RigAction.idle, RigAction.walk, RigAction.run, RigAction.jump, RigAction.fall, RigAction.land])
          cell(a.name, (r) {
            r
              ..speed = a == RigAction.run ? runSpeed : runSpeed * 0.4
              ..act(a);
            run(r, a == RigAction.land ? 0.06 : 0.62);
          }),
      ]),
      SheetRow('ACTIONS II', [
        for (final a in [
          RigAction.hurt,
          RigAction.attack,
          RigAction.cheer,
          RigAction.taunt,
          RigAction.talk,
          RigAction.defeated,
        ])
          cell(a.name, (r) {
            r.act(a);
            run(r, a == RigAction.hurt ? 0.12 : (a == RigAction.attack ? 0.2 : 0.9));
          }),
      ]),
    ],
  );
}

const _sheetSize = Size(1000, 1250);

void main() {
  setUpAll(() async {
    await loadMadarFonts();
    await CinemaShaders.preload();
  });

  const hero = RigSpec(id: 'sheet_hero', accent: PaletteRole.accent);

  testWidgets('hero model sheet', (tester) async {
    RigCharacter mk() => createRig(hero);
    await captureScreen(
      tester,
      madarScreenshotApp(
        home: ModelSheet(
          title: 'MODEL SHEET — "Rehearsal" bean',
          subtitle: 'procedural rubber-hose rig · 1930s ink · turnaround / expressions / actions',
          rows: [
            SheetRow('TURNAROUND', [
              for (final f in [-1.0, -0.5, 0.0, 0.5, 1.0])
                _rig('facing $f', mk, (r) {
                  r.facing = f;
                  run(r, 1.2);
                }),
            ]),
            SheetRow('EXPRESSIONS', [
              for (final e in RigExpression.values)
                _rig(e.name, mk, (r) {
                  r
                    ..facing = 0.4
                    ..expression = e;
                  run(r, 0.5);
                }),
            ]),
            SheetRow('ACTIONS I', [
              for (final a in [
                RigAction.idle,
                RigAction.walk,
                RigAction.run,
                RigAction.jump,
                RigAction.fall,
                RigAction.land,
              ])
                _rig(a.name, mk, (r) {
                  r
                    ..speed = a == RigAction.run ? 220 : 80
                    ..act(a);
                  run(r, a == RigAction.land ? 0.06 : 0.62);
                }),
            ]),
            SheetRow('ACTIONS II', [
              for (final a in [
                RigAction.hurt,
                RigAction.attack,
                RigAction.cheer,
                RigAction.taunt,
                RigAction.talk,
                RigAction.defeated,
              ])
                _rig(a.name, mk, (r) {
                  r.act(a);
                  run(r, a == RigAction.hurt ? 0.12 : (a == RigAction.attack ? 0.2 : 0.7));
                }),
            ]),
          ],
        ),
      ),
      'cinema/rig/hero_sheet',
      settle: const Duration(milliseconds: 100),
      logicalSize: _sheetSize,
      dpr: 1.5,
    );
  });

  testWidgets('body types', (tester) async {
    await captureScreen(
      tester,
      madarScreenshotApp(
        home: ModelSheet(
          title: 'BODY TYPES',
          subtitle: 'RigSpec.body · bean / ball / egg / pear / tall',
          rows: [
            for (final era in [Era.rubberHose, Era.technicolor])
              SheetRow(era: era, era.name.toUpperCase(), [
                for (final body in RigBody.values)
                  _rig(
                    body.name,
                    () => createRig(
                      RigSpec(
                        id: 'b_${body.name}',
                        body: body,
                        fill: era == Era.technicolor ? PaletteRole.midtone : PaletteRole.paper,
                      ),
                    ),
                    (r) {
                      r
                        ..facing = 0.6
                        ..expression = RigExpression.happy;
                      run(r, 0.4);
                    },
                  ),
              ]),
          ],
        ),
      ),
      'cinema/rig/body_types',
      settle: const Duration(milliseconds: 100),
      logicalSize: _sheetSize,
      dpr: 1.5,
    );
  });

  testWidgets('star-bird model sheet', (tester) async {
    await captureScreen(
      tester,
      madarScreenshotApp(
        home: _castSheet(
          'NUJAYM · نُجيم',
          'the star-bird of "Flappy Orbit" · 1930s rubber-hose',
          Era.rubberHose,
          () => RigCast.starBird(height: 100),
        ),
      ),
      'cinema/rig/cast_nujaym',
      settle: const Duration(milliseconds: 100),
      logicalSize: _sheetSize,
      dpr: 1.5,
    );
  });

  testWidgets('camel courier model sheet', (tester) async {
    await captureScreen(
      tester,
      madarScreenshotApp(
        home: _castSheet(
          'ZAJIL · زاجل',
          'the camel courier of "Caravan Dash" · 1950s Technicolor',
          Era.technicolor,
          () => RigCast.camelCourier(height: 100),
          runSpeed: 200,
        ),
      ),
      'cinema/rig/cast_zajil',
      settle: const Duration(milliseconds: 100),
      logicalSize: _sheetSize,
      dpr: 1.5,
    );
  });

  testWidgets('detective cat model sheet', (tester) async {
    await captureScreen(
      tester,
      madarScreenshotApp(
        home: _castSheet(
          'INSPECTOR MISHMISH · المفتش مِشمِش',
          'the detective cat of "Noir Rooftops" · 1940s noir',
          Era.noir,
          () => RigCast.detectiveCat(height: 100),
        ),
      ),
      'cinema/rig/cast_mishmish',
      settle: const Duration(milliseconds: 100),
      logicalSize: _sheetSize,
      dpr: 1.5,
    );
  });

  testWidgets('neon rider model sheet', (tester) async {
    await captureScreen(
      tester,
      madarScreenshotApp(
        home: _castSheet(
          'SARAB · سراب',
          'the hover-bike courier of "Neon Souk Racer" · 1980s VHS neon',
          Era.vhs,
          () => RigCast.neonRider(height: 100),
          dark: true,
        ),
      ),
      'cinema/rig/cast_sarab',
      settle: const Duration(milliseconds: 100),
      logicalSize: _sheetSize,
      dpr: 1.5,
    );
  });

  testWidgets('clockwork boss model sheet', (tester) async {
    RigCharacter mk() => RigCast.clockworkBoss(height: 100);
    SheetCell cell(String label, void Function(ClockworkBoss r) setup) =>
        _rig(label, mk, (r) => setup(r as ClockworkBoss));
    await captureScreen(
      tester,
      madarScreenshotApp(
        home: ModelSheet(
          title: 'BARON ZUNBRUK · البارون زُنبُرك',
          subtitle: 'the clockwork foreman of "Metropolis Machine" · boss phases and attacks',
          era: Era.silent,
          rows: [
            SheetRow('PHASES', [
              for (final p in [0, 1, 2])
                cell('phase $p', (r) {
                  r
                    ..phase = p
                    ..facing = 0.6
                    ..expression = p == 2 ? RigExpression.scared : (p == 1 ? RigExpression.angry : RigExpression.sly);
                  run(r, 1.1);
                }),
              cell('defeated', (r) {
                r
                  ..phase = 2
                  ..act(RigAction.defeated);
                run(r, 1.2);
              }),
            ]),
            SheetRow('ATTACKS', [
              cell('tell', (r) {
                r.windUp = 1;
                run(r, 0.6);
              }),
              cell('slam up', (r) {
                r
                  ..attack = BossAttack.slam
                  ..act(RigAction.attack);
                run(r, 0.36);
              }),
              cell('slam!', (r) {
                r
                  ..attack = BossAttack.slam
                  ..act(RigAction.attack);
                run(r, 0.5);
              }),
              cell('punch', (r) {
                r
                  ..attack = BossAttack.punch
                  ..act(RigAction.attack);
                run(r, 0.38);
              }),
              cell('blast', (r) {
                r
                  ..attack = BossAttack.blast
                  ..act(RigAction.attack);
                run(r, 0.35);
              }),
            ]),
            SheetRow('MOODS', [
              for (final a in [RigAction.idle, RigAction.taunt, RigAction.talk, RigAction.hurt, RigAction.run])
                cell(a.name, (r) {
                  r
                    ..speed = 60
                    ..act(a);
                  run(r, a == RigAction.hurt ? 0.12 : 0.7);
                }),
            ]),
          ],
        ),
      ),
      'cinema/rig/cast_zunbruk',
      settle: const Duration(milliseconds: 100),
      logicalSize: _sheetSize,
      dpr: 1.5,
    );
  });

  testWidgets('props sheet', (tester) async {
    SheetCell prop(String label, InkProp Function() make, {double height = 100, double run = 0.5}) {
      final p = make();
      var t = 0.0;
      while (t < run) {
        p.update(1 / 60);
        t += 1 / 60;
      }
      // Props are centred on their origin (a crate stands on it): lift them
      // onto the sheet's baseline.
      final lift = p is InkCrate ? 0.0 : p.bounds.bottom;
      return SheetCell(
        label: label,
        paint: (canvas, ctx) {
          canvas.translate(0, -lift - 6);
          p.paint(canvas, ctx);
        },
        height: height,
        guide: false,
      );
    }

    await captureScreen(
      tester,
      madarScreenshotApp(
        home: ModelSheet(
          title: 'PROPS',
          subtitle: 'clouds, stars, gears, crates, moon, puffs · same ink, same boil',
          rows: [
            for (final era in [Era.rubberHose, Era.technicolor, Era.noir])
              SheetRow(era: era, era.name.toUpperCase(), [
                prop('cloud', () => InkCloud(size: 100, mood: PropMood.happy), height: 110),
                prop('star', () => InkStar(size: 70, mood: PropMood.happy), height: 110),
                prop('gear', () => InkGear(size: 80), height: 110),
                prop('crate', () => InkCrate(size: 70), height: 110),
                prop('moon', () => InkMoon(size: 80), height: 110),
                prop('puff', () => InkPuff(size: 60), height: 110, run: 0.3),
              ]),
          ],
        ),
      ),
      'cinema/rig/props',
      settle: const Duration(milliseconds: 100),
      logicalSize: _sheetSize,
      dpr: 1.5,
    );
  });

  testWidgets('pose cycles sheet', (tester) async {
    SheetRow strip(
      String title,
      RigCharacter Function() make,
      RigAction action,
      double speed,
      double period, {
      int frames = 8,
      Era? era,
      double height = 100,
    }) {
      return SheetRow(era: era, title, [
        for (var k = 0; k < frames; k++)
          _rig('${k + 1}', make, (r) {
            r
              ..speed = speed
              ..act(action);
            run(r, 1.0 + period * k / frames);
          }, height: height),
      ]);
    }

    await captureScreen(
      tester,
      madarScreenshotApp(
        home: ModelSheet(
          title: 'POSE CYCLES',
          subtitle: 'one cycle per row, evenly spaced drawings · rubber-hose bounce timing',
          rows: [
            strip('HABBA · WALK (strut)', () => RigCast.bean(height: 100), RigAction.walk, 90, 1 / 1.5),
            strip('HABBA · RUN (wheel legs)', () => RigCast.bean(height: 100), RigAction.run, 220, 1 / 2.59),
            strip('HABBA · IDLE (bounce on the beat)', () => RigCast.bean(height: 100), RigAction.idle, 0, 1.0),
            strip('NUJAYM · HOVER (wing beat)', () => RigCast.starBird(height: 100), RigAction.idle, 0, 1 / 2.8),
            strip(
              'ZAJIL · GALLOP',
              () => RigCast.camelCourier(height: 100),
              RigAction.run,
              200,
              1 / 1.82,
              era: Era.technicolor,
            ),
            strip(
              'MISHMISH · SNEAK',
              () => RigCast.detectiveCat(height: 100),
              RigAction.walk,
              60,
              1 / 0.9,
              era: Era.noir,
            ),
          ],
        ),
      ),
      'cinema/rig/pose_cycles',
      settle: const Duration(milliseconds: 100),
      logicalSize: _sheetSize,
      dpr: 1.5,
    );
  });
}
