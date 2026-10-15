@Tags(['screenshot'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/features/lock/render/lock_astrolabe.dart';
import 'package:madar/features/orbit/render/astrolabe/astrolabe_shaders.dart';

import '../../helpers/screenshot_harness.dart';

void main() {
  for (final theme in MadarThemeId.values) {
    testWidgets('dial assembly frames – ${theme.name}', (tester) async {
      await tester.runAsync(AstrolabePrograms.load);
      Widget cell(double p) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LockAstrolabe(
            progress: AlwaysStoppedAnimation(p),
            size: 190,
            animate: false,
            scan: AlwaysStoppedAnimation(p == 0.65 ? 1.0 : 0.0),
            ignite: AlwaysStoppedAnimation(p == 1.0 ? 0.35 : 0.0),
            error: AlwaysStoppedAnimation(p == 0.2 ? 1.0 : 0.0),
          ),
          Text('$p'),
        ],
      );
      await captureScreen(
        tester,
        madarScreenshotApp(
          theme: theme,
          home: Scaffold(
            backgroundColor: Colors.transparent,
            body: CosmosBackdrop(
              animate: false,
              child: SafeArea(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    for (final p in [0.0, 0.2, 0.35, 0.5, 0.65, 0.8, 0.9, 1.0]) cell(p),
                  ],
                ),
              ),
            ),
          ),
        ),
        'phase2/lock/lock_dial_assembly_${theme.name}',
      );
    });
  }
}
