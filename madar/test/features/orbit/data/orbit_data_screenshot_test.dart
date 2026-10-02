@Tags(['screenshot'])
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart' show SeedOptions;
import 'package:madar/core/db/open.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/tokens.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/orbit/data/orbit_repository.dart';
import 'package:madar/features/orbit/domain/neglect_text.dart';
import 'package:madar/features/orbit/domain/orbit_labels.dart';
import 'package:madar/features/orbit/domain/scene_math.dart';
import 'package:madar/features/orbit/domain/scene_snapshot.dart';
import 'package:madar/features/orbit/render/noise_texture.dart';
import 'package:madar/features/orbit/render/planet_params.dart';
import 'package:madar/features/orbit/render/uniform_writer.dart';

import '../../../helpers/screenshot_harness.dart';
import 'orbit_fixtures.dart';

// A data-driven contact sheet: two lived-in databases (every record kept up /
// the same records slipping) → OrbitRepository snapshots → the real planet
// and data-moon shaders, fed ONLY from the snapshot (uScore, palette, uExtra,
// seed; each moon's kind, state, colour and size). Checks that every world
// visibly changes between thriving and neglected from real rows, that uExtra
// carries the data (two metropolises for two boards, one ship per upcoming
// trip, fasting + training rivers …) and that the radar reads naturally.

const _assets = {
  PlanetArchetype.faith: 'shaders/orbit/planet_faith.frag',
  PlanetArchetype.ocean: 'shaders/orbit/planet_ocean.frag',
  PlanetArchetype.terracotta: 'shaders/orbit/planet_terracotta.frag',
  PlanetArchetype.industrial: 'shaders/orbit/planet_industrial.frag',
  PlanetArchetype.crystal: 'shaders/orbit/planet_crystal.frag',
  PlanetArchetype.verdant: 'shaders/orbit/planet_verdant.frag',
  PlanetArchetype.volcanic: 'shaders/orbit/planet_volcanic.frag',
  PlanetArchetype.gasGiant: 'shaders/orbit/planet_gas_giant.frag',
};

class _Programs {
  _Programs(this.planets, this.moon, this.noise);
  final Map<PlanetArchetype, ui.FragmentProgram> planets;
  final ui.FragmentProgram moon;
  final ui.Image noise;
}

/// One world and its moons, straight from an [OrbitPlanet].
class _WorldPainter extends CustomPainter {
  _WorldPainter(this.planet, this.programs, {required this.night});
  final OrbitPlanet planet;
  final _Programs programs;

  /// Light from behind-left so the night side (city lights, lanterns) shows.
  final bool night;

  static const _time = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    final giant = planet.shaderArchetype == PlanetArchetype.gasGiant;
    final halo = giant ? 2.3 : 1.35;
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 / (giant ? 2.45 : 1.75);
    final light = night ? const V3(-0.9, 0.25, -0.35).normalized : const V3(-0.72, 0.38, 0.58).normalized;

    // Moons behind the planet first (upper half of the orbit), then the world,
    // then the moons in front.
    final moons = planet.moons;
    final orbit = radius * (giant ? 2.2 : 1.55);
    Offset moonAt(int i) {
      final a = -math.pi / 2 + (i + 0.5) * 2 * math.pi / math.max(1, moons.length) + 0.35;
      return center + Offset(math.cos(a) * orbit, math.sin(a) * orbit * 0.42);
    }

    void drawMoon(int i) {
      final m = moons[i];
      final c = moonAt(i);
      final r = radius * (0.12 + 0.1 * m.size);
      final s = programs.moon.fragmentShader();
      final w = UniformWriter(s)
        ..size(size)
        ..offset(c)
        ..f(r)
        ..f(_time)
        ..v3(light)
        ..f(m.score)
        ..f(0)
        ..v3(V3(m.seed, 0.3, 0))
        ..color(m.color)
        ..color(const Color(0x00000000))
        ..color(const Color(0x00000000))
        ..f(0.5)
        ..f(m.seed)
        ..v4(m.kind.shaderLook, 0, 0, 0);
      assert(w.index == 32);
      s.setImageSampler(0, programs.noise, filterQuality: FilterQuality.low);
      canvas.drawRect(Rect.fromCircle(center: c, radius: r * 1.6), Paint()..shader = s);
      s.dispose();
    }

    for (var i = 0; i < moons.length; i++) {
      if (moonAt(i).dy < center.dy) drawMoon(i);
    }
    final shader = programs.planets[planet.shaderArchetype]!.fragmentShader();
    PlanetParams(
      center: center,
      radius: radius,
      time: _time,
      light: light,
      score: planet.uScore,
      palette: planet.palette,
      spin: V3(planet.seed * 0.37, 0.35, 0),
      detail: 0.55,
      seed: planet.seed,
      extra: planet.extras,
      haloFactor: halo,
    ).write(UniformWriter(shader), size);
    shader.setImageSampler(0, programs.noise, filterQuality: FilterQuality.low);
    canvas.drawRect(Rect.fromCircle(center: center, radius: radius * halo), Paint()..shader = shader);
    shader.dispose();
    for (var i = 0; i < moons.length; i++) {
      if (moonAt(i).dy >= center.dy) drawMoon(i);
    }
  }

  @override
  bool shouldRepaint(covariant _WorldPainter old) => old.planet != planet || old.night != night;
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.thriving, required this.neglected, required this.programs});
  final SceneSnapshot thriving, neglected;
  final _Programs programs;

  List<Widget> _details(BuildContext context, OrbitPlanet p, L10n l, MadarFormatter fmt) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return [
      const SizedBox(height: 2),
      Text(
        '${planetStateLabel(l, p.state)} · ${fmt.formatPercent(p.uScore)}',
        style: text.bodySmall?.copyWith(color: p.palette.glow),
      ),
      if (p.moonOverflow > 0) Text(moonOverflowText(l, fmt, p.moonOverflow), style: text.bodySmall),
      SizedBox(
        height: p.score.reasons.isEmpty ? 6 : 40,
        child: p.score.reasons.isEmpty
            ? null
            : Padding(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 6),
                child: Text(
                  neglectReasonText(l, p.score.reasons.first, fmt),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(color: t.textSecondary, height: 1.3),
                ),
              ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter(languageCode: Localizations.localeOf(context).languageCode);
    final text = Theme.of(context).textTheme;

    Widget row(SceneSnapshot snap, {required bool night, bool details = true}) => Row(
      children: [
        for (final p in snap.planets)
          Expanded(
            child: Column(
              children: [
                AspectRatio(
                  aspectRatio: night ? 1.25 : 1,
                  child: CustomPaint(painter: _WorldPainter(p, programs, night: night)),
                ),
                if (details) Text(p.name, style: text.titleSmall?.copyWith(color: t.textPrimary)),
                if (details) ..._details(context, p, l, fmt),
              ],
            ),
          ),
      ],
    );

    Widget header(SceneSnapshot snap, String title, {IconData icon = Icons.wb_sunny_outlined}) => Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(24, 12, 24, 0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: t.gold),
          const SizedBox(width: 10),
          Text(title, style: text.titleLarge?.copyWith(color: t.gold)),
          const SizedBox(width: 16),
          Text(balanceSemanticsLabel(l, fmt, snap), style: text.titleMedium?.copyWith(color: t.textSecondary)),
        ],
      ),
    );

    return ColoredBox(
      color: t.space0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header(thriving, l.orbitStateThriving),
          row(thriving, night: false),
          header(thriving, l.orbitStateThriving, icon: Icons.nightlight_outlined),
          row(thriving, night: true, details: false),
          header(neglected, l.orbitStateNeglected),
          row(neglected, night: false),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(24, 6, 24, 16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: t.glassFill,
                border: Border.all(color: t.glassBorder),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    for (final r in neglected.radar)
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: r.palette.glow,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: r.palette.glow, blurRadius: 8)],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r.planetName, style: text.labelMedium?.copyWith(color: r.palette.glow)),
                                  Text(r.text, style: text.bodyMedium?.copyWith(color: t.textPrimary)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  late _Programs programs;
  late SceneSnapshot thrivingAr, neglectedAr, thrivingEn, neglectedEn;

  setUpAll(() async {
    Future<(SceneSnapshot, SceneSnapshot)> build(bool arabic) async {
      final out = <SceneSnapshot>[];
      for (final thriving in [true, false]) {
        final db = await openInMemoryMadarDatabase(seed: SeedOptions(languageCode: arabic ? 'ar' : 'en'));
        final repos = Repositories(db);
        await seedLivedIn(repos, thriving: thriving, arabic: arabic);
        out.add(await OrbitRepository(repos, clock: () => fixtureNow).snapshot(languageCode: arabic ? 'ar' : 'en'));
        await db.close();
      }
      return (out[0], out[1]);
    }

    (thrivingAr, neglectedAr) = await build(true);
    (thrivingEn, neglectedEn) = await build(false);
  });

  Future<void> loadPrograms(WidgetTester tester) async {
    await tester.runAsync(() async {
      final planets = <PlanetArchetype, ui.FragmentProgram>{};
      for (final e in _assets.entries) {
        planets[e.key] = await ui.FragmentProgram.fromAsset(e.value);
      }
      programs = _Programs(
        planets,
        await ui.FragmentProgram.fromAsset('shaders/orbit/data_moon.frag'),
        await NoiseTexture.image(),
      );
    });
  }

  testWidgets('orbit data → worlds (Arabic)', (tester) async {
    await loadPrograms(tester);
    await captureScreen(
      tester,
      madarScreenshotApp(
        home: _Sheet(thriving: thrivingAr, neglected: neglectedAr, programs: programs),
      ),
      'orbit_data_worlds_ar',
      logicalSize: const Size(1280, 790),
      dpr: 1.5,
      settle: const Duration(milliseconds: 200),
    );
  });

  testWidgets('orbit data → worlds (English, Emerald)', (tester) async {
    await loadPrograms(tester);
    await captureScreen(
      tester,
      madarScreenshotApp(
        home: _Sheet(thriving: thrivingEn, neglected: neglectedEn, programs: programs),
        theme: MadarThemeId.emerald,
        locale: const Locale('en'),
      ),
      'orbit_data_worlds_en',
      logicalSize: const Size(1280, 790),
      dpr: 1.5,
      settle: const Duration(milliseconds: 200),
    );
  });
}
