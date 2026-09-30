@Tags(['screenshot'])
library;

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
              for (final a in [RigAction.idle, RigAction.walk, RigAction.run, RigAction.jump, RigAction.fall, RigAction.land])
                _rig(a.name, mk, (r) {
                  r
                    ..speed = a == RigAction.run ? 220 : 80
                    ..act(a);
                  run(r, a == RigAction.land ? 0.06 : 0.62);
                }),
            ]),
            SheetRow('ACTIONS II', [
              for (final a in [RigAction.hurt, RigAction.attack, RigAction.cheer, RigAction.taunt, RigAction.talk, RigAction.defeated])
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
                  _rig(body.name, () => createRig(RigSpec(id: 'b_${body.name}', body: body, fill: era == Era.technicolor ? PaletteRole.midtone : PaletteRole.paper)), (r) {
                    r
                      ..facing = 0.6
                      ..expression = RigExpression.happy;
                    run(r, 0.4);
                  }),
              ]),
          ],
        ),
      ),
      'cinema/rig/body_types',
      settle: const Duration(milliseconds: 100),
    );
  });
}
