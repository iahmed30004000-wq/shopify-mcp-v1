@Tags(['screenshot'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/tokens.dart';
import 'package:madar/core/design/typography.dart';
import 'package:madar/core/design/widgets/cosmos_backdrop.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/motion/motion_kit.dart';
import 'package:madar/features/orbit/domain/planet_pulse.dart';
import 'package:madar/features/orbit/render/orbit_shaders.dart';
import 'package:madar/features/orbit/render/planets/planets.dart';

import '../../../../helpers/screenshot_harness.dart';
import 'planet_fixtures.dart';

// ------------------------------------------------------------------ sheets --

/// One world of a contact sheet.
class _Cell {
  _Cell(this.body, this.score, {this.caption, this.pulse = 0});
  final PlanetBody body;
  final double score;
  final String? caption;
  final double pulse;
  double get time => 12;
}

/// Worlds in rows at a fixed disc radius, lit by the portrait light, each
/// cell as wide as its halo (the gas giant's rings get their room).
class _SheetPainter extends CustomPainter {
  _SheetPainter({required this.renderer, required this.rows, required this.radius, required this.tokens});

  final PlanetRenderer renderer;
  final List<List<_Cell>> rows;
  final double radius;
  final MadarTokens tokens;

  static double cellWidth(_Cell c, double radius) => 2 * radius * c.body.haloFactor + radius * 0.35;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = tokens.space0);
    final rowH = size.height / rows.length;
    final frame = BodyFrame(rows.first.first.body);
    for (var r = 0; r < rows.length; r++) {
      var x = 0.0;
      final caption = radius < 60 ? 14.0 : 0.0;
      for (final c in rows[r]) {
        final w = cellWidth(c, radius);
        final center = Offset(x + w / 2, rowH * r + (rowH - caption) / 2);
        preparePortraitFrame(
          frame,
          body: c.body,
          center: center,
          radius: radius,
          score: c.score,
          pulse: c.pulse,
          time: c.time,
        );
        renderer.paintPlanet(canvas, size, frame, c.time);
        if (c.caption != null && caption > 0) {
          final tp = TextPainter(
            text: TextSpan(
              text: c.caption,
              style: TextStyle(fontFamily: MadarTypography.displayFamily, fontSize: 10, color: tokens.textSecondary),
            ),
            textDirection: TextDirection.rtl,
          )..layout();
          tp.paint(canvas, Offset(center.dx - tp.width / 2, rowH * (r + 1) - caption - 2));
        }
        x += w;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Future<void> _sheet(
  WidgetTester tester,
  String name, {
  required List<List<_Cell>> rows,
  required double radius,
  double dpr = 2.625,
}) async {
  late OrbitShaders shaders;
  await tester.runAsync(() async => shaders = await OrbitShaders.load());
  final renderer = PlanetRenderer(shaders);
  addTearDown(renderer.dispose);
  final width = rows
      .map((row) => row.fold<double>(0, (a, c) => a + _SheetPainter.cellWidth(c, radius)))
      .reduce((a, b) => a > b ? a : b);
  final rowH = 2 * radius * 1.35 + (radius < 60 ? 14 : 0) + radius * 0.2;
  final tokens = MadarPalettes.tokensFor(MadarThemeId.lapis);
  await captureScreen(
    tester,
    madarScreenshotApp(
      home: CustomPaint(
        size: Size.infinite,
        painter: _SheetPainter(renderer: renderer, rows: rows, radius: radius, tokens: tokens),
      ),
    ),
    name,
    logicalSize: Size(width.ceilToDouble(), (rowH * rows.length).ceilToDouble()),
    dpr: dpr,
    settle: const Duration(milliseconds: 100),
  );
}

List<_Cell> _row(Iterable<String> keys, double score, {String lang = 'ar'}) => [
  for (final k in keys)
    _Cell(
      PlanetFixtures.body(k, score: score, lang: lang, moons: false),
      score,
      caption: PlanetFixtures.nameOf(k, lang),
    ),
];

// ------------------------------------------------------------------- scene --

class _Stage extends StatelessWidget {
  const _Stage({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.tokens.space0,
    child: CosmosBackdrop(intensity: 0.8, animate: false, child: child),
  );
}

Future<void> _scene(
  WidgetTester tester,
  String name, {
  required PlanetSceneController controller,
  MadarThemeId theme = MadarThemeId.lapis,
  String lang = 'ar',
  Size size = const Size(412, 915),
  double dpr = 2.625,
  Future<void> Function(WidgetTester tester)? beforeCapture,
  Duration settle = const Duration(milliseconds: 800),
  Widget Function(Widget layer)? wrap,
}) async {
  await tester.runAsync(OrbitShaders.load);
  final layer = PlanetLayer(controller: controller, tick: true);
  await captureScreen(
    tester,
    madarScreenshotApp(
      theme: theme,
      locale: Locale(lang),
      home: CelebrationOverlay(child: _Stage(child: wrap == null ? layer : wrap(layer))),
    ),
    name,
    logicalSize: size,
    dpr: dpr,
    settle: settle,
    beforeCapture: beforeCapture,
  );
}

void main() {
  const keys = PlanetFixtures.keys;

  group('eight worlds', () {
    testWidgets('overview scale (r 24): thriving over neglected', (tester) async {
      await _sheet(tester, 'planets_row_overview', rows: [_row(keys, 0.95), _row(keys, 0.12)], radius: 24);
    });

    testWidgets('hero scale (r 220): faith … work, thriving over neglected', (tester) async {
      final k = keys.take(4);
      await _sheet(tester, 'planets_row_hero_a', rows: [_row(k, 0.95), _row(k, 0.12)], radius: 220, dpr: 1);
    });

    testWidgets('hero scale (r 220): money … travel, thriving over neglected', (tester) async {
      final k = keys.skip(4);
      await _sheet(tester, 'planets_row_hero_b', rows: [_row(k, 0.95), _row(k, 0.12)], radius: 220, dpr: 1);
    });

    testWidgets('mid scale (r 70): thriving / steady / neglected', (tester) async {
      await _sheet(
        tester,
        'planets_row_mid',
        rows: [_row(keys, 0.95), _row(keys, 0.6), _row(keys, 0.12)],
        radius: 70,
        dpr: 1.5,
      );
    });

    testWidgets('living-state curve: 20 / 37 / 50 / 65 / 80 / 95 % on every world', (tester) async {
      const scores = [0.2, 0.37, 0.5, 0.65, 0.8, 0.95];
      await _sheet(
        tester,
        'planets_row_curve',
        rows: [
          for (final k in keys) [for (final s in scores) _Cell(PlanetFixtures.body(k, score: s, moons: false), s)],
        ],
        radius: 40,
        dpr: 1.5,
      );
    });

    testWidgets('user styles: ice beside crystal, desert beside terracotta', (tester) async {
      Iterable<_Cell> pair(double s) => [
        _Cell(PlanetFixtures.body('money', score: s, moons: false), s),
        _Cell(PlanetFixtures.custom('ice', PlanetArchetype.ice, score: s), s),
        _Cell(PlanetFixtures.body('family', score: s, moons: false), s),
        _Cell(PlanetFixtures.custom('dune', PlanetArchetype.desert, score: s), s),
      ];
      await _sheet(
        tester,
        'planets_row_styles',
        rows: [pair(0.95).toList(), pair(0.15).toList()],
        radius: 90,
        dpr: 1.5,
      );
    });

    testWidgets('a completion at its peak (uPulse 0.9) on every world', (tester) async {
      await _sheet(
        tester,
        'planets_row_pulse',
        rows: [
          [for (final k in keys) _Cell(PlanetFixtures.body(k, score: 0.6, moons: false), 0.6, pulse: 0.9)],
        ],
        radius: 36,
        dpr: 2,
      );
    });

    testWidgets('living state: a completion morphs neglected → thriving over ~1.2 s', (tester) async {
      // The real animator drives the frames: t = 0, 0.15, 0.3, 0.5, 0.8, 1.2 s.
      const times = [0.0, 0.15, 0.3, 0.5, 0.8, 1.2];
      List<_Cell> strip(String key) {
        final a = LivingStateAnimator()..setScore(key, 0.12);
        a
          ..setScore(key, 0.95)
          ..pulse(key);
        final cells = <_Cell>[];
        var t = 0.0;
        for (final at in times) {
          while (t < at - 1e-9) {
            a.advance(1 / 60);
            t += 1 / 60;
          }
          cells.add(_Cell(PlanetFixtures.body(key, moons: false), a.score(key), pulse: a.pulseOf(key)));
        }
        return cells;
      }

      await _sheet(
        tester,
        'planets_row_morph',
        rows: [strip('body'), strip('growth'), strip('family')],
        radius: 60,
        dpr: 1.5,
      );
    });

    testWidgets('travel ships: 0 / 2 / 6 upcoming trips', (tester) async {
      _Cell ships(int n) => _Cell(PlanetFixtures.body('travel', trips: n, moons: false), 0.9);
      await _sheet(
        tester,
        'planets_row_ships',
        rows: [
          [ships(0), ships(2), ships(6)],
        ],
        radius: 90,
        dpr: 1.5,
      );
    });
  });

  group('scene', () {
    testWidgets('system overview, Arabic, Lapis', (tester) async {
      final c = PlanetSceneController()..setBodies(PlanetFixtures.system(), animate: false);
      addTearDown(c.dispose);
      await _scene(tester, 'planets_system_ar_lapis', controller: c);
    });

    testWidgets('system overview, English, Pearl, Travel selected', (tester) async {
      final c = PlanetSceneController(initialTime: 70)
        ..setBodies(PlanetFixtures.system(lang: 'en'), animate: false)
        ..selectedKey = 'travel';
      addTearDown(c.dispose);
      await _scene(tester, 'planets_system_en_pearl', controller: c, lang: 'en', theme: MadarThemeId.pearl);
    });

    testWidgets('Family with eight people as moons (Arabic names)', (tester) async {
      final c = PlanetSceneController()..setBodies(PlanetFixtures.system(), animate: false);
      addTearDown(c.dispose);
      c
        ..camera = c.framingCamera(
          'family',
          from: c.camera.copyWith(elevation: 0.5),
          viewport: const Size(412, 915),
          fill: 0.3,
        )!
        ..selectedKey = 'family'
        ..setFocus('family', 1);
      await _scene(tester, 'planets_family_moons_ar', controller: c);
    });

    testWidgets('Family neglected, a completion pulsing', (tester) async {
      final bodies = PlanetFixtures.system(scores: const {'family': 0.15});
      final c = PlanetSceneController()..setBodies(bodies, animate: false);
      addTearDown(c.dispose);
      c
        ..camera = c.framingCamera(
          'family',
          from: c.camera.copyWith(elevation: 0.5),
          viewport: const Size(412, 915),
          fill: 0.3,
        )!
        ..setFocus('family', 1);
      await _scene(
        tester,
        'planets_family_pulse_ar',
        controller: c,
        beforeCapture: (tester) async {
          c.pulse(
            PlanetPulse(
              planetKey: 'family',
              kind: 'contact.logged',
              at: DateTime(2026),
              refTable: 'people',
              refId: 'p0',
            ),
          );
          await tester.pump(const Duration(milliseconds: 100));
        },
      );
    });

    testWidgets('fly-in close-up: Work at hero scale', (tester) async {
      final c = PlanetSceneController()..setBodies(PlanetFixtures.system(), animate: false);
      addTearDown(c.dispose);
      c
        ..camera = c.framingCamera(
          'work',
          from: c.camera.copyWith(elevation: 0.3),
          viewport: const Size(412, 915),
          fill: 0.95,
        )!
        ..setFocus('work', 1);
      await _scene(tester, 'planets_flyin_work', controller: c);
    });
  });
}
