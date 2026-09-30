@Tags(['screenshot'])
library;

// TEMPORARY iteration harness (rig agent) – deleted before hand-off.
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/engine/cinema_engine.dart';
import 'package:madar/features/cinema/engine/rig/rig_kit.dart';

import '../../../helpers/screenshot_harness.dart';
import 'model_sheet.dart';

SheetCell _c(String label, RigCharacter Function() make, void Function(RigCharacter r) setup) {
  final rig = make();
  setup(rig);
  return SheetCell(label: label, paint: rig.paint);
}

void main() {
  setUpAll(() async {
    await loadMadarFonts();
    await CinemaShaders.preload();
  });

  final who = Platform.environment['RIG'] ?? 'nujaym';
  final era = Era.values.firstWhere((e) => e.name == (Platform.environment['ERA'] ?? 'rubberHose'));
  RigCharacter mk() => switch (who) {
    'nujaym' => RigCast.starBird(),
    'zajil' => RigCast.camelCourier(),
    'sarab' => RigCast.neonRider(),
    'mishmish' => RigCast.detectiveCat(),
    'zunbruk' => RigCast.clockworkBoss(),
    _ => RigCast.bean(),
  };

  testWidgets('scratch', (tester) async {
    await captureScreen(
      tester,
      madarScreenshotApp(
        home: ModelSheet(
          title: 'SCRATCH $who',
          subtitle: era.name,
          era: era,
          dark: era == Era.vhs,
          rows: [
            SheetRow('A', [
              for (final f in [-1.0, 0.0, 1.0])
                _c('facing $f', mk, (r) {
                  r.facing = f;
                  run(r, 1.2);
                }),
            ]),
            SheetRow('B', [
              for (final e in [RigExpression.happy, RigExpression.angry, RigExpression.scared])
                _c(e.name, mk, (r) {
                  r
                    ..facing = 0.6
                    ..expression = e;
                  run(r, 0.5);
                }),
            ]),
            SheetRow('C', [
              for (final a in [RigAction.jump, RigAction.run, RigAction.hurt])
                _c(a.name, mk, (r) {
                  r
                    ..speed = 200
                    ..act(a);
                  run(r, a == RigAction.hurt ? 0.12 : 0.3);
                }),
            ]),
          ],
        ),
      ),
      'cinema/rig/_scratch',
      logicalSize: const Size(900, 1250),
      dpr: 1.2,
    );
  });
}
