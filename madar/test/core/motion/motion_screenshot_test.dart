// Visual critic pass for the motion kit: particles mid-flight, a cosmic
// zoom mid-reveal and a staggered entrance mid-way, rendered with the real
// fonts and shaders into madar/screenshots/.
//
//   flutter test --tags screenshot test/core/motion/motion_screenshot_test.dart
@Tags(['screenshot'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/tokens.dart';
import 'package:madar/core/design/widgets/cosmos_backdrop.dart';
import 'package:madar/core/design/widgets/glass.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/motion/motion_kit.dart';

import '../../helpers/screenshot_harness.dart';

Widget _cosmos({Widget? child}) => Stack(fit: StackFit.expand, children: [const CosmosBackdrop(), ?child]);

Widget _particleApp(MadarThemeId theme) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: buildMadarTheme(theme, arabic: true),
  locale: const Locale('ar'),
  supportedLocales: L10n.supportedLocales,
  localizationsDelegates: L10n.localizationsDelegates,
  builder: (context, child) => CelebrationOverlay(child: child!),
  home: Scaffold(
    body: _cosmos(
      child: const Center(child: Text('✦', key: ValueKey('anchor'))),
    ),
  ),
);

/// The harness pumps 600 ms after `beforeCapture`; a timer fires [trigger]
/// inside that window so the capture shows the effect [age] old.
Future<void> Function(WidgetTester) _at(Duration age, void Function(BuildContext context) trigger) => (tester) async {
  final context = tester.element(find.byKey(const ValueKey('anchor')));
  Timer(const Duration(milliseconds: 600) - age, () => trigger(context));
};

const _screen = Size(412, 915);

void _all(BuildContext context) {
  Celebrate.burst(context, Offset(_screen.width * 0.3, _screen.height * 0.24));
  Celebrate.burst(
    context,
    Offset(_screen.width * 0.68, _screen.height * 0.44),
    kind: CelebrationKind.orbitalRing,
    radius: 70,
  );
  Celebrate.burst(context, Offset(_screen.width * 0.3, _screen.height * 0.72), kind: CelebrationKind.lanternSparks);
  Celebrate.burst(context, Offset(_screen.width * 0.72, _screen.height * 0.82), kind: CelebrationKind.lightRain);
}

void main() {
  testWidgets('particles – Lapis (additive)', (tester) async {
    final file = await captureScreen(
      tester,
      _particleApp(MadarThemeId.lapis),
      'motion_particles_lapis',
      settle: const Duration(milliseconds: 200),
      beforeCapture: _at(const Duration(milliseconds: 300), _all),
    );
    expect(file.existsSync(), isTrue);
  });

  testWidgets('particles – Pearl (normal blending)', (tester) async {
    final file = await captureScreen(
      tester,
      _particleApp(MadarThemeId.pearl),
      'motion_particles_pearl',
      settle: const Duration(milliseconds: 200),
      beforeCapture: _at(const Duration(milliseconds: 300), _all),
    );
    expect(file.existsSync(), isTrue);
  });

  for (final (kind, theme, age) in [
    (CelebrationKind.stardust, MadarThemeId.lapis, 220),
    (CelebrationKind.stardust, MadarThemeId.lapis, 520),
    (CelebrationKind.orbitalRing, MadarThemeId.emerald, 380),
    (CelebrationKind.lanternSparks, MadarThemeId.desert, 560),
    (CelebrationKind.lightRain, MadarThemeId.aurora, 420),
  ]) {
    testWidgets('burst ${kind.name} at ${age}ms – ${theme.name}', (tester) async {
      final file = await captureScreen(
        tester,
        _particleApp(theme),
        'motion_burst_${kind.name}_${age}ms',
        settle: const Duration(milliseconds: 200),
        beforeCapture: _at(
          Duration(milliseconds: age),
          (c) => Celebrate.burst(c, Offset(_screen.width / 2, _screen.height * 0.45), kind: kind, radius: 90),
        ),
      );
      expect(file.existsSync(), isTrue);
    });
  }

  testWidgets('ambient – Maghrib lanterns + light rain – Desert', (tester) async {
    final file = await captureScreen(
      tester,
      _particleApp(MadarThemeId.desert),
      'motion_ambient_desert',
      settle: const Duration(milliseconds: 200),
      beforeCapture: (tester) async {
        final context = tester.element(find.byKey(const ValueKey('anchor')));
        Celebrate.ambient(context, kind: CelebrationKind.lanternSparks, duration: null);
        Celebrate.ambient(
          context,
          kind: CelebrationKind.orbitalRing,
          center: const Offset(206, 300),
          radius: 96,
          duration: null,
        );
        for (var i = 0; i < 160; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
      },
    );
    expect(file.existsSync(), isTrue);
  });

  for (final ms in [180, 420]) {
    testWidgets('cosmic zoom at ${ms}ms – Aurora', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) => MadarTransitions.fadeThrough(
              context: context,
              key: state.pageKey,
              child: Scaffold(
                body: _cosmos(
                  child: Align(
                    alignment: const Alignment(-0.4, -0.35),
                    child: Builder(
                      builder: (context) => Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            center: const Alignment(-0.3, -0.4),
                            colors: [
                              PlanetPalettes.health.glow,
                              PlanetPalettes.health.surface,
                              PlanetPalettes.health.deep,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            routes: [
              GoRoute(
                path: 'planet',
                pageBuilder: (context, state) => MadarTransitions.cosmicZoom(
                  context: context,
                  key: state.pageKey,
                  originRect: Rect.fromCenter(center: Offset(412 * 0.3, 915 * 0.325), width: 90, height: 90),
                  child: Scaffold(
                    body: _cosmos(
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsetsDirectional.all(Space.gutter),
                          child: StaggerIn(
                            spacing: Space.l,
                            children: [
                              for (var i = 0; i < 4; i++)
                                GlassPanel(
                                  seed: i.toDouble(),
                                  child: SizedBox(
                                    height: 72,
                                    child: Builder(
                                      builder: (context) => Align(
                                        alignment: AlignmentDirectional.centerStart,
                                        child: RollingNumber(
                                          from: 0,
                                          value: 1200 + i * 345,
                                          style: TextStyle(fontSize: 28, color: context.tokens.textPrimary),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
      final file = await captureScreen(
        tester,
        MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: buildMadarTheme(MadarThemeId.aurora, arabic: true),
          locale: const Locale('ar'),
          supportedLocales: L10n.supportedLocales,
          localizationsDelegates: L10n.localizationsDelegates,
          routerConfig: router,
        ),
        'motion_cosmic_zoom_${ms}ms',
        settle: const Duration(milliseconds: 200),
        // Captured [ms] into the 760 ms fly-in.
        beforeCapture: (tester) async => Timer(Duration(milliseconds: 600 - ms), () => router.go('/planet')),
      );
      expect(file.existsSync(), isTrue);
    });
  }

  testWidgets('stagger entrance mid-way – Emerald RTL', (tester) async {
    final file = await captureScreen(
      tester,
      madarScreenshotApp(
        theme: MadarThemeId.emerald,
        home: Scaffold(
          body: _cosmos(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsetsDirectional.all(Space.gutter),
                child: StaggerIn(
                  spacing: Space.m,
                  children: [
                    for (var i = 0; i < 7; i++)
                      GlassPanel(
                        seed: i.toDouble(),
                        child: SizedBox(
                          height: 64,
                          child: Builder(
                            builder: (context) => Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Text('${i + 1}', style: Theme.of(context).textTheme.headlineSmall),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      'motion_stagger_mid',
      settle: const Duration(milliseconds: 150),
    );
    expect(file.existsSync(), isTrue);
  });
}
