import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/widgets/ambient_motion.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/motion/motion.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/orbit/domain/orbit_moons.dart';
import 'package:madar/features/orbit/domain/planet_pulse.dart';
import 'package:madar/features/orbit/domain/scene_math.dart';
import 'package:madar/features/orbit/render/orbit_shaders.dart';
import 'package:madar/features/orbit/render/planet_params.dart';
import 'package:madar/features/orbit/render/planets/planets.dart';
import 'package:madar/features/orbit/render/uniform_writer.dart';

import 'planet_fixtures.dart';

class _Haptics implements HapticsService {
  final List<Haptic> fired = [];
  @override
  bool enabled = true;
  @override
  void fire(Haptic haptic) => fired.add(haptic);
}

const _phone = Size(412, 915);

Widget _app(Widget child, {bool reduced = false, String lang = 'ar', VoidCallback? onBackgroundTap}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: buildMadarTheme(MadarThemeId.lapis, arabic: lang == 'ar'),
  locale: Locale(lang),
  supportedLocales: L10n.supportedLocales,
  localizationsDelegates: L10n.localizationsDelegates,
  home: MotionScope(
    reduced: reduced,
    child: Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onBackgroundTap),
        ),
        Positioned.fill(child: child),
      ],
    ),
  ),
);

PlanetSceneController _controller({String? zoomOn}) {
  final c = PlanetSceneController()..setBodies(PlanetFixtures.system(), animate: false);
  if (zoomOn != null) {
    c
      ..camera = c.framingCamera(zoomOn, from: c.camera, viewport: _phone, fill: 0.36)!
      ..setFocus(zoomOn, 1);
  }
  return c;
}

void _phoneView(WidgetTester tester) {
  tester.view.physicalSize = _phone;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  late SilentSoundService sound;
  late _Haptics haptics;

  setUp(() {
    sound = SilentSoundService();
    haptics = _Haptics();
    Fx.install(FeedbackService(sound, haptics));
  });

  testWidgets('orbit shaders load once and warm up offscreen (splash-time pre-warm)', (tester) async {
    // First in this file: later layers must find the programs loaded (the
    // noise texture cannot decode inside the fake-async zone).
    await tester.runAsync(() async {
      final shaders = await OrbitShaders.load();
      expect(identical(await OrbitShaders.load(), shaders), isTrue);
      for (final s in OrbitShader.values.where((s) => s.isBody)) {
        expect(shaders.program(s), isNotNull, reason: s.name);
      }
      await shaders.warmUp();
    });
  });

  testWidgets('a world whose program did not compile falls back to a lit sphere (portrait too)', (tester) async {
    late OrbitShaders full;
    await tester.runAsync(() async => full = await OrbitShaders.load());
    addTearDown(() => OrbitShaders.debugSetInstance(full));
    final body = PlanetFixtures.system().first;
    final partial = full.debugOnly({
      for (final s in OrbitShader.values)
        if (s != body.shader) s,
    });
    final renderer = PlanetRenderer(partial);
    final complete = PlanetRenderer(full);
    addTearDown(renderer.dispose);
    addTearDown(complete.dispose);
    expect(renderer.canDraw(body), isFalse);
    expect(renderer.canDrawMoons, isTrue);
    expect(complete.canDraw(body), isTrue);

    OrbitShaders.debugSetInstance(partial);
    await tester.pumpWidget(
      _app(
        Center(
          child: SizedBox.square(dimension: 120, child: PlanetPortrait(body: body)),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the uniform buffer writes exactly the PlanetParams contract (same pixels)', (tester) async {
    await tester.runAsync(() async {
      final shaders = await OrbitShaders.load();
      const size = Size(96, 96);
      const light = V3(-0.6, 0.4, 0.69);
      final params = PlanetParams(
        center: const Offset(48, 48),
        radius: 30,
        time: 7.5,
        light: light,
        score: 0.37,
        palette: PlanetPalettes.work,
        pulse: 0.2,
        spin: const V3(1.1, 0.3, 0),
        detail: 0.3,
        seed: 4.2,
        extra: const [3, 0.7, 0, 0],
      );
      Future<Uint8List> render(void Function(ui.FragmentShader s) write) async {
        final shader = shaders.shader(OrbitShader.planetIndustrial);
        write(shader);
        final rec = ui.PictureRecorder();
        Canvas(rec).drawRect(params.drawRect, Paint()..shader = shader);
        final image = await rec.endRecording().toImage(96, 96);
        final bytes = (await image.toByteData())!.buffer.asUint8List();
        image.dispose();
        shader.dispose();
        return bytes;
      }

      final viaParams = await render((s) => params.write(UniformWriter(s), size));
      final viaBuffer = await render((s) {
        (PlanetUniforms()..set(
              canvas: size,
              center: params.center,
              radius: params.radius,
              time: params.time,
              lightX: light.x,
              lightY: light.y,
              lightZ: light.z,
              score: params.score,
              pulse: params.pulse,
              spin: params.spin.x,
              tilt: params.spin.y,
              colorA: params.palette.surface,
              colorB: params.palette.glow,
              colorC: params.palette.deep,
              detail: params.detail,
              seed: params.seed,
              extra: params.extra,
            ))
            .applyTo(s);
      });
      expect(viaBuffer.where((b) => b != 0), isNotEmpty, reason: 'the world was drawn');
      expect(viaBuffer, viaParams);
    });
  });

  testWidgets('one shader instance per body, released when it leaves; ships follow the trips', (tester) async {
    late OrbitShaders shaders;
    await tester.runAsync(() async => shaders = await OrbitShaders.load());
    final renderer = PlanetRenderer(shaders);
    addTearDown(renderer.dispose);
    final c = _controller();
    addTearDown(c.dispose);
    void paint() {
      final rec = ui.PictureRecorder();
      PlanetBodiesPainter(controller: c, renderer: renderer).paint(Canvas(rec), _phone);
      rec.endRecording().dispose();
    }

    paint();
    final f = c.frameFor(_phone);
    final drawn =
        f.drawOrder.where((b) => b.visible).length +
        f.drawOrder.fold<int>(0, (n, b) => n + b.moons.where((m) => m.visible).length);
    expect(renderer.instanceCount, drawn);
    // Travel's ships: uExtra.x = upcoming trips (3 in the fixture).
    final travel = renderer.debugPlanetUniforms('travel');
    if (travel != null) {
      expect(travel.values[PlanetUniforms.iExtra], 3);
      expect(travel.values[PlanetUniforms.iScore], closeTo(0.88, 1e-6));
      expect(travel.values[PlanetUniforms.iDetail], greaterThanOrEqualTo(0.04));
    }
    final before = renderer.instanceCount;
    paint();
    expect(renderer.instanceCount, before, reason: 'reused, not recreated');

    // Six trips → six ships.
    c.setBodies([
      for (final b in PlanetFixtures.system())
        b.key == 'travel' ? PlanetFixtures.body('travel', trips: 6, score: 0.88) : b,
    ]);
    c.camera = c.framingCamera('travel', from: c.camera, viewport: _phone, fill: 0.3)!;
    paint();
    expect(renderer.debugPlanetUniforms('travel')!.values[PlanetUniforms.iExtra], 6);

    // Travel leaves the scene: its shaders (world + moon) are released.
    c.setBodies(PlanetFixtures.system().where((b) => b.key != 'travel').toList());
    paint();
    expect(renderer.debugPlanetUniforms('travel'), isNull);
    expect(renderer.debugMoonUniforms('trips:t0'), isNull);
  });

  testWidgets('moons get their own colour, kind and selection ring', (tester) async {
    late OrbitShaders shaders;
    await tester.runAsync(() async => shaders = await OrbitShaders.load());
    final renderer = PlanetRenderer(shaders);
    addTearDown(renderer.dispose);
    final c = _controller(zoomOn: 'money')..selectedMoonId = 'wallets:w1';
    addTearDown(c.dispose);
    final rec = ui.PictureRecorder();
    PlanetBodiesPainter(controller: c, renderer: renderer).paint(Canvas(rec), _phone);
    rec.endRecording().dispose();
    for (final m in PlanetFixtures.walletMoons()) {
      final u = renderer.debugMoonUniforms(m.id);
      if (u == null) continue; // culled (off screen)
      expect(u.values[PlanetUniforms.iExtra], MoonKind.metallic.shaderLook);
      expect(u.values[PlanetUniforms.iExtra + 1], m.id == 'wallets:w1' ? 1 : 0);
      expect(u.values[PlanetUniforms.iColorA], closeTo(m.color.r, 1e-6));
      expect(u.values[PlanetUniforms.iColorB + 3], 0, reason: 'glow derived in the shader');
    }
  });

  testWidgets('tapping a world flies in (Sfx.navigate); empty sky falls through to the scene', (tester) async {
    await tester.runAsync(OrbitShaders.load);
    _phoneView(tester);
    final c = _controller();
    addTearDown(c.dispose);
    final tapped = <String>[];
    Rect? rect;
    var background = 0;
    await tester.pumpWidget(
      _app(
        PlanetLayer(
          controller: c,
          onPlanetTap: (key, r) {
            tapped.add(key);
            rect = r;
          },
        ),
        onBackgroundTap: () => background++,
      ),
    );
    await tester.pump();
    final f = c.frameFor(_phone);
    final target = f.drawOrder.lastWhere((b) => b.visible);
    await tester.tapAt(target.center);
    expect(tapped, [target.key]);
    expect(rect!.center, target.center);
    expect(sound.played, [Sfx.navigate]);
    expect(background, 0);
    await tester.tapAt(const Offset(20, 880));
    expect(background, 1);
    expect(tapped.length, 1);
  });

  testWidgets('without handlers the worlds never claim a tap', (tester) async {
    await tester.runAsync(OrbitShaders.load);
    _phoneView(tester);
    final c = _controller();
    addTearDown(c.dispose);
    var background = 0;
    await tester.pumpWidget(_app(PlanetLayer(controller: c), onBackgroundTap: () => background++));
    await tester.pump();
    await tester.tapAt(c.frameFor(_phone).drawOrder.lastWhere((b) => b.visible).center);
    expect(background, 1);
    expect(sound.played, isEmpty);
  });

  testWidgets('tapping a moon opens its record (Sfx.tap)', (tester) async {
    await tester.runAsync(OrbitShaders.load);
    _phoneView(tester);
    final c = _controller(zoomOn: 'family');
    addTearDown(c.dispose);
    final opened = <OrbitMoon>[];
    await tester.pumpWidget(_app(PlanetLayer(controller: c, onMoonTap: (m, planet, r) => opened.add(m))));
    await tester.pump();
    final f = c.frameFor(_phone);
    final moon = f.body('family')!.moons.firstWhere((m) => m.visible && f.hitTest(m.center)?.moon?.id == m.id);
    await tester.tapAt(moon.center);
    expect(opened.single.refTable, 'people');
    expect(opened.single.id, moon.id);
    expect(sound.played, [Sfx.tap]);
  });

  testWidgets('long-pressing a world opens its customisation (Sfx.pickUp)', (tester) async {
    await tester.runAsync(OrbitShaders.load);
    _phoneView(tester);
    final c = _controller();
    addTearDown(c.dispose);
    final pressed = <String>[];
    await tester.pumpWidget(_app(PlanetLayer(controller: c, onPlanetLongPress: (key, r) => pressed.add(key))));
    await tester.pump();
    final target = c.frameFor(_phone).drawOrder.lastWhere((b) => b.visible);
    await tester.longPressAt(target.center);
    expect(pressed, [target.key]);
    expect(sound.played, contains(Sfx.pickUp));
  });

  testWidgets('a completion pulse answers with particles and a chime at the world', (tester) async {
    await tester.runAsync(OrbitShaders.load);
    _phoneView(tester);
    final c = _controller();
    addTearDown(c.dispose);
    final feedback = <(String, Offset)>[];
    await tester.pumpWidget(
      _app(PlanetLayer(controller: c, onPulse: (p, center, r) => feedback.add((p.planetKey, center)))),
    );
    await tester.pump();
    final work = c.frameFor(_phone).body('work')!;
    c.pulse(PlanetPulse(planetKey: 'work', kind: 'task.done', at: DateTime(2026)));
    await tester.pump();
    expect(feedback.single.$1, 'work');
    expect(feedback.single.$2, work.center);

    // Default feedback: the stardust burst's chime.
    await tester.pumpWidget(_app(PlanetLayer(key: const ValueKey('default'), controller: c)));
    await tester.pump();
    c.pulse(PlanetPulse(planetKey: 'work', kind: 'task.done', at: DateTime(2026)));
    await tester.pump();
    expect(sound.played, contains(Sfx.sparkle));
  });

  testWidgets('screen readers get the system, each world and each moon, with actions', (tester) async {
    await tester.runAsync(OrbitShaders.load);
    _phoneView(tester);
    final handle = tester.ensureSemantics();
    final c = PlanetSceneController()..setBodies(PlanetFixtures.system(lang: 'en'), animate: false);
    addTearDown(c.dispose);
    final tapped = <String>[];
    final opened = <String>[];
    await tester.pumpWidget(
      _app(
        PlanetLayer(controller: c, onPlanetTap: (k, r) => tapped.add(k), onMoonTap: (m, p, r) => opened.add(m.id)),
        lang: 'en',
      ),
    );
    await tester.pump();
    expect(find.bySemanticsLabel("Your life's orbit: 8 worlds circling your star"), findsOneWidget);
    final visible = c.frameFor(_phone).bodies.where((b) => b.visible).toList();
    expect(visible, isNotEmpty);
    final first = visible.first;
    final label = RegExp('^\u2068?${first.body.name}\u2069?, ');
    expect(find.semantics.byLabel(label), findsOne);
    final node = find.semantics.byLabel(label).evaluate().single;
    expect(node.getSemanticsData().hasAction(ui.SemanticsAction.tap), isTrue);
    tester.semantics.tap(find.semantics.byLabel(label));
    expect(tapped, [first.key]);
    // Family's node counts its moons (as its value).
    final family = find.semantics.byLabel(RegExp('^\u2068?Family\u2069?, '));
    expect(family, findsOne);
    expect(family.evaluate().single.getSemanticsData().value, '8 moons');
    handle.dispose();
  });

  testWidgets('reduced motion keeps the scene static (no ticker)', (tester) async {
    await tester.runAsync(OrbitShaders.load);
    _phoneView(tester);
    AmbientMotion.debugOverride = true;
    addTearDown(() => AmbientMotion.debugOverride = null);
    final c = _controller();
    addTearDown(c.dispose);
    await tester.pumpWidget(_app(PlanetLayer(controller: c, tick: true), reduced: true));
    final t = c.time;
    await tester.pump(const Duration(milliseconds: 500));
    expect(c.reducedMotion, isTrue);
    expect(c.time, t);
  });

  testWidgets('its own ticker drifts at 30 fps when idle, full rate while animating, and pauses when hidden', (
    tester,
  ) async {
    await tester.runAsync(OrbitShaders.load);
    _phoneView(tester);
    AmbientMotion.debugOverride = true;
    addTearDown(() => AmbientMotion.debugOverride = null);
    final c = _controller();
    addTearDown(c.dispose);
    var ticks = 0;
    c.addListener(() => ticks++);
    final visible = ValueNotifier(true);
    await tester.pumpWidget(
      _app(
        ValueListenableBuilder<bool>(
          valueListenable: visible,
          builder: (context, on, child) => TickerMode(enabled: on, child: child!),
          child: PlanetLayer(controller: c, tick: true),
        ),
      ),
    );
    // Let the labels finish fading in (full rate while they do).
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(microseconds: 16667));
    }
    expect(c.isAnimating, isFalse);
    ticks = 0;
    final t0 = c.time;
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(microseconds: 16667));
    }
    expect(c.time - t0, closeTo(1, 0.1));
    expect(ticks, inInclusiveRange(25, 35), reason: 'idle: ~30 advances per second');

    ticks = 0;
    c.pulse(PlanetPulse(planetKey: 'faith', kind: 'prayer.logged', at: DateTime(2026)));
    ticks = 0;
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(microseconds: 16667));
    }
    expect(ticks, greaterThanOrEqualTo(28), reason: 'animating: every frame');

    visible.value = false;
    await tester.pump();
    final hidden = c.time;
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(c.time, hidden, reason: 'paused while hidden');
  });

  testWidgets('without ambient motion the layer idles, but still plays a pulse through', (tester) async {
    await tester.runAsync(OrbitShaders.load);
    _phoneView(tester);
    final c = _controller();
    addTearDown(c.dispose);
    await tester.pumpWidget(_app(PlanetLayer(controller: c, tick: true)));
    final t0 = c.time;
    await tester.pump(const Duration(milliseconds: 300));
    expect(c.time, t0, reason: 'decorative drift is off under flutter test');
    c.pulse(PlanetPulse(planetKey: 'faith', kind: 'prayer.logged', at: DateTime(2026)));
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(microseconds: 16667));
    }
    expect(c.time, greaterThan(t0 + 1.4));
    expect(c.isAnimating, isFalse);
    final settled = c.time;
    await tester.pump(const Duration(milliseconds: 300));
    expect(c.time, settled, reason: 'stops once the pulse is over');
  });

  testWidgets('battery saver still: the same painters, one image', (tester) async {
    await tester.runAsync(() async {
      final c = _controller();
      final image = await PlanetStill.render(
        controller: c,
        size: const Size(206, 458),
        pixelRatio: 2,
        style: PlanetLayerStyle.fromTokens(MadarPalettes.tokensFor(MadarThemeId.lapis)),
        textDirection: TextDirection.rtl,
      );
      expect(image.width, 412);
      expect(image.height, 916);
      final bytes = (await image.toByteData())!;
      var lit = 0;
      for (var i = 3; i < bytes.lengthInBytes; i += 4 * 97) {
        if (bytes.getUint8(i) > 0) lit++;
      }
      expect(lit, greaterThan(20), reason: 'worlds and guides were drawn');
      image.dispose();
      c.dispose();
    });
  });

  testWidgets('a portrait draws one world in its box', (tester) async {
    await tester.runAsync(OrbitShaders.load);
    await tester.pumpWidget(
      _app(
        Center(
          child: SizedBox.square(
            dimension: 120,
            child: PlanetPortrait(body: PlanetFixtures.body('travel'), score: 0.2),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(PlanetPortrait), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
