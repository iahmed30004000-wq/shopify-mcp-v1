// Screenshot harness for the stage agent: composes a frame exactly like
// CinemaGame.render does (stage back → world → stage front → HUD →
// transitions), without Flame, at a chosen moment, and grades it through the
// era's real film stock (ReelFilmFx) – so the PNGs show what a player sees.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/cinema/engine/cinema_engine.dart';
import 'package:madar/features/cinema/engine/fx/fx.dart';
import 'package:madar/features/cinema/engine/rig/rig_kit.dart';

import '../../../helpers/screenshot_harness.dart';

/// A stage, its HUD and transitions for one era, driven by hand.
class StageScene {
  StageScene(this.era, {this.direction = TextDirection.rtl, this.reducedMotion = false}) : skin = EraSkins.of(era) {
    env = CinemaEnv(skin: skin, direction: direction, reducedMotion: reducedMotion, seed: 3);
    stage = CinemaEngine.standardKit.stage(env);
    hudKit = CinemaEngine.standardKit.hud(env);
    transitions = CinemaEngine.standardKit.transitions(env);
    clock = FilmClock(boilFps: skin.ink.boilFps, projectionFps: skin.grade.projectionFps, seed: 3);
    hud = HudContext(skin: skin, clock: clock, model: model, direction: direction);
  }

  final Era era;
  final EraSkin skin;
  final TextDirection direction;
  final bool reducedMotion;
  late final CinemaEnv env;
  late final StageFrame stage;
  late final HudKit hudKit;
  late final CinemaTransitions transitions;
  late final FilmClock clock;
  final HudModel model = HudModel();
  late final HudContext hud;
  final List<(HudSlot, HudItem)> items = [];
  final List<Rect> _rects = [];
  Size size = Size.zero;

  /// Draws the world inside the play area (defaults to [paintWorld]).
  void Function(Canvas canvas, Rect play, StageScene scene)? world;

  void layout(Size screen) {
    size = screen;
    stage.layout(screen, EdgeInsets.zero);
    transitions.layout(screen, stage.playRect);
    hud.scale = (screen.width / 412).clamp(0.8, 1.4);
    _layoutHud();
  }

  void place(HudSlot slot, HudItem item) {
    items.add((slot, item));
    _layoutHud();
  }

  // Mirrors core's HudLayer layout.
  void _layoutHud() {
    _rects
      ..clear()
      ..addAll(List.filled(items.length, Rect.zero));
    final area = stage.hudRect;
    if (area.isEmpty) return;
    final rtl = direction == TextDirection.rtl;
    const gap = 10.0;
    for (final slot in HudSlot.values) {
      var cursor = 0.0;
      var total = 0.0;
      final centre = slot == HudSlot.topCenter || slot == HudSlot.bottomCenter;
      if (centre) {
        for (final (s, it) in items) {
          if (s == slot) total += it.layoutSize(hud).width + gap;
        }
        total -= gap;
      }
      for (var i = 0; i < items.length; i++) {
        final (s, it) = items[i];
        if (s != slot) continue;
        final sz = it.layoutSize(hud);
        final top = switch (slot) {
          HudSlot.topStart || HudSlot.topCenter || HudSlot.topEnd => area.top,
          _ => area.bottom - sz.height,
        };
        final start = slot == HudSlot.topStart || slot == HudSlot.bottomStart;
        double left;
        if (!centre) {
          final fromLeft = start != rtl;
          left = fromLeft ? area.left + cursor : area.right - cursor - sz.width;
        } else {
          final o = area.center.dx - total / 2;
          left = rtl ? o + total - cursor - sz.width : o + cursor;
        }
        _rects[i] = Rect.fromLTWH(left, top, sz.width, sz.height);
        cursor += sz.width + gap;
      }
    }
  }

  /// Runs the scene for [seconds] of game time.
  void run(double seconds, {void Function(double t)? each}) {
    const dt = 1 / 60;
    for (var t = 0.0; t < seconds - 1e-9; t += dt) {
      clock.advance(dt);
      stage.update(dt, clock);
      transitions.update(dt, clock);
      for (final (_, it) in items) {
        it.update(dt, hud);
      }
      each?.call(t);
    }
    _layoutHud();
  }

  void paint(Canvas canvas) {
    stage.paintBack(canvas);
    final play = stage.playRect;
    canvas
      ..save()
      ..clipRect(play);
    (world ?? paintWorld)(canvas, play, this);
    canvas.restore();
    stage.paintFront(canvas);
    for (var i = 0; i < items.length; i++) {
      items[i].$2.paint(canvas, _rects[i], hud);
    }
    transitions.paint(canvas);
  }

  void dispose() {
    for (final (_, it) in items) {
      it.dispose();
    }
    stage.dispose();
    transitions.dispose();
  }
}

/// A simple painted set: sky, far hills, the stage floor and the era's star
/// from the rig cast.
void paintWorld(Canvas canvas, Rect play, StageScene scene) {
  final pal = scene.skin.palette;
  final sky = Paint()
    ..shader = ui.Gradient.linear(
      play.topCenter,
      play.bottomCenter,
      [Color.lerp(pal.backdrop, pal.highlight, 0.25)!, pal.backdrop, Color.lerp(pal.backdrop, pal.midtone, 0.5)!],
      const [0, 0.6, 1],
    );
  canvas.drawRect(play, sky);
  final floorY = play.top + play.height * 0.8;
  final hills = Path()
    ..moveTo(play.left, floorY - 60)
    ..quadraticBezierTo(play.left + play.width * 0.3, floorY - 150, play.center.dx, floorY - 70)
    ..quadraticBezierTo(play.right - play.width * 0.2, floorY - 10, play.right, floorY - 90)
    ..lineTo(play.right, floorY)
    ..lineTo(play.left, floorY)
    ..close();
  canvas
    ..drawPath(hills, Paint()..color = Color.lerp(pal.midtone, pal.backdrop, 0.3)!)
    ..drawPath(
      hills,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = pal.ink,
    )
    ..drawRect(
      Rect.fromLTRB(play.left, floorY, play.right, play.bottom),
      Paint()..color = Color.lerp(pal.midtone, pal.shadow, 0.35)!,
    );
  final boards = Paint()
    ..color = pal.ink.withValues(alpha: 0.55)
    ..strokeWidth = 1.4;
  for (var k = 1; k < 5; k++) {
    final y = floorY + (play.bottom - floorY) * k / 5;
    canvas.drawLine(Offset(play.left, y), Offset(play.right, y), boards);
  }
  canvas.drawLine(Offset(play.left, floorY), Offset(play.right, floorY), boards..strokeWidth = 2.6);
  // The era's star.
  final member = RigCast.all.firstWhere((m) => m.era == scene.era, orElse: () => RigCast.all.last);
  final rig = member.build(height: member.height > 200 ? 200 : 120);
  final ctx = RigPaintContext(skin: scene.skin, clock: scene.clock)..pixelScale = 1.4;
  rig
    ..act(RigAction.cheer)
    ..update(0.4);
  canvas
    ..save()
    ..translate(play.center.dx, floorY + 6)
    ..scale(1.4);
  rig.paint(canvas, ctx);
  canvas.restore();
  rig.dispose();
}

/// Grades [scene] through the era's film stock.
class GradedScenePainter extends CustomPainter {
  GradedScenePainter(this.fx, this.scene, this.dpr, {this.film});

  final FilmFx fx;
  final StageScene scene;
  final double dpr;
  final FilmFrame? film;

  @override
  void paint(Canvas canvas, Size size) {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec)..scale(dpr * fx.resolutionScale);
    scene.paint(c);
    final pic = rec.endRecording();
    final img = pic.toImageSync(
      (size.width * dpr * fx.resolutionScale).ceil(),
      (size.height * dpr * fx.resolutionScale).ceil(),
    );
    pic.dispose();
    fx.apply(canvas, img, Offset.zero & size, scene.clock, film ?? FilmFrame());
    img.dispose();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Renders a prepared [scene] (laid out at 412×915) to
/// `screenshots/cinema/stage/<name>.png` through the film grade.
Future<void> shootScene(
  WidgetTester tester,
  StageScene scene,
  String name, {
  Size logicalSize = const Size(412, 915),
  FilmFrame? film,
  bool graded = true,
}) async {
  final fx = ReelFilmFx(scene.env, quality: FilmQuality.full);
  await tester.runAsync(fx.load);
  for (var i = 0; i < 20; i++) {
    fx.update(1 / 60, scene.clock);
  }
  await captureScreen(
    tester,
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Builder(
        builder: (context) => CustomPaint(
          painter: graded
              ? GradedScenePainter(fx, scene, MediaQuery.devicePixelRatioOf(context), film: film)
              : _Plain(scene),
          size: Size.infinite,
        ),
      ),
    ),
    'cinema/stage/$name',
    logicalSize: logicalSize,
    settle: const Duration(milliseconds: 100),
    trailingFrames: 0,
  );
  fx.dispose();
}

class _Plain extends CustomPainter {
  _Plain(this.scene);
  final StageScene scene;
  @override
  void paint(Canvas canvas, Size size) => scene.paint(canvas);
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

Future<L10n> arabic() => L10n.delegate.load(const Locale('ar'));
