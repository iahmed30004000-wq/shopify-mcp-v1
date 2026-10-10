@Tags(['screenshot'])
library;

import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/engine/cinema_engine.dart';
import 'package:madar/features/cinema/engine/rig/rig_kit.dart';

import '../../../helpers/screenshot_harness.dart';

// The cast in context: each character in its home era on the real stage,
// through the real film pass (standard kit) – screenshots/cinema/rig/stage_*.png.

/// A painted flat: backdrop colour and a floor with an ink edge.
class _Flat extends Component with HasGameReference<CinemaGame> {
  _Flat(this.floorY);

  final double floorY;
  final Paint _p = Paint();

  @override
  void render(Canvas canvas) {
    final pal = game.skin.palette;
    final w = game.worldSize;
    _p
      ..style = PaintingStyle.fill
      ..color = pal.backdrop;
    canvas.drawRect(Rect.fromLTWH(-200, -200, w.x + 400, floorY + 200), _p);
    _p.color = pal.midtone;
    canvas.drawRect(Rect.fromLTWH(-200, floorY, w.x + 400, w.y), _p);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = pal.ink;
    canvas.drawLine(Offset(-200, floorY), Offset(w.x + 200, floorY), _p);
    _p.strokeWidth = 2;
    for (var i = 0; i < 9; i++) {
      final x = i * 48.0 - 20;
      canvas.drawLine(Offset(x, floorY + 12), Offset(x - 18, floorY + 60), _p);
    }
  }
}

class _Showcase extends CinemaGame {
  _Showcase({required super.context, required Era era, required this.scene}) : super(skin: EraSkins.of(era));

  final void Function(_Showcase g) scene;

  @override
  String get gameId => 'rig_showcase';

  @override
  Vector2 get worldSize => Vector2(360, 640);

  @override
  IntertitleCard? openingCard() => null;

  @override
  Future<void> onSceneLoad() async {
    world.add(_Flat(520)..priority = -10);
    scene(this);
  }

  RigComponent put(RigCharacter rig, double x, double y, {int priority = 10}) {
    final c = RigComponent(rig: rig, position: Vector2(x, y), priority: priority);
    world.add(c);
    return c;
  }

  void prop(InkProp p, double x, double y, {int priority = 0}) =>
      world.add(PropComponent(prop: p, position: Vector2(x, y), priority: priority));
}

Future<void> _shoot(WidgetTester tester, String name, Era era, void Function(_Showcase g) scene) async {
  await captureScreen(
    tester,
    ProviderScope(
      child: madarScreenshotApp(
        home: CinemaGameView(
          skipOpening: true,
          builder: (ctx) => _Showcase(context: ctx, era: era, scene: scene),
        ),
      ),
    ),
    'cinema/rig/stage_$name',
    settle: const Duration(milliseconds: 1400),
  );
}

void main() {
  setUpAll(() async {
    await loadMadarFonts();
    await CinemaShaders.preload();
  });

  testWidgets('Nujaym over the clouds (1930s)', (tester) async {
    await _shoot(tester, 'nujaym', Era.rubberHose, (g) {
      g
        ..prop(InkCloud(size: 150, mood: PropMood.sleepy), 90, 180)
        ..prop(InkCloud(size: 110), 290, 300)
        ..prop(InkStar(size: 46, mood: PropMood.happy), 300, 120)
        ..prop(InkStar(size: 30), 60, 330);
      final bird = RigCast.starBird(height: 130)..expression = RigExpression.happy;
      g.put(bird, 180, 420);
      final hero = RigCast.bean(height: 118)
        ..act(RigAction.cheer)
        ..facing = 0.6;
      g.put(hero, 90, 520);
      g.prop(InkCrate(size: 70), 290, 520);
    });
  });

  testWidgets('Baron Zunbruk in the machine hall (1920s)', (tester) async {
    await _shoot(tester, 'zunbruk', Era.silent, (g) {
      g
        ..prop(InkGear(size: 150, speed: 0.5), 40, 160, priority: -5)
        ..prop(InkGear(size: 100, teeth: 10, speed: -0.75), 330, 240, priority: -5)
        ..prop(InkGear(size: 70, teeth: 8, speed: 1), 300, 110, priority: -5);
      final boss = RigCast.clockworkBoss(height: 330)
        ..phase = 1
        ..expression = RigExpression.sly
        ..facing = -0.7
        ..act(RigAction.taunt);
      g.put(boss, 215, 520);
      final hero = RigCast.bean(height: 96)
        ..expression = RigExpression.determined
        ..facing = 0.7;
      g.put(hero, 60, 520);
    });
  });

  testWidgets('Zajil on the dunes (1950s)', (tester) async {
    await _shoot(tester, 'zajil', Era.technicolor, (g) {
      g
        ..prop(InkCloud(size: 140, mood: PropMood.happy), 110, 150)
        ..prop(InkCloud(size: 90), 300, 250);
      final camel = RigCast.camelCourier(height: 170)
        ..expression = RigExpression.happy
        ..speed = 260
        ..act(RigAction.run);
      g.put(camel, 180, 520);
      g.prop(InkCrate(size: 56), 320, 520);
    });
  });

  testWidgets('Mishmish on the rooftops (1940s)', (tester) async {
    await _shoot(tester, 'mishmish', Era.noir, (g) {
      g
        ..prop(InkMoon(size: 120), 270, 150)
        ..prop(InkStar(size: 22), 80, 110)
        ..prop(InkStar(size: 16), 150, 220);
      final cat = RigCast.detectiveCat(height: 170)
        ..speed = 90
        ..act(RigAction.walk);
      g.put(cat, 170, 520);
      g
        ..prop(InkCrate(size: 80), 50, 520)
        ..prop(InkCrate(size: 60), 320, 520);
    });
  });

  testWidgets('Sarab in the neon souk (1980s)', (tester) async {
    await _shoot(tester, 'sarab', Era.vhs, (g) {
      g
        ..prop(InkMoon(size: 90, mood: PropMood.none), 290, 120)
        ..prop(InkStar(size: 26), 70, 140);
      final rider = RigCast.neonRider(height: 170)
        ..expression = RigExpression.determined
        ..speed = 400
        ..act(RigAction.run);
      g.put(rider, 190, 500);
    });
  });
}
