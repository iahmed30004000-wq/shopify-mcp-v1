import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/cinema/engine/cinema_engine.dart';
import 'package:madar/features/cinema/engine/rig/rig_kit.dart';

import 'model_sheet.dart' show run;

/// Paints [rig] once into a throw-away recorder.
void paintOnce(RigCharacter rig, RigPaintContext ctx) {
  final rec = PictureRecorder();
  rig.paint(Canvas(rec), ctx);
  rec.endRecording().dispose();
}

RigPaintContext ctxFor(Era era, {FilmClock? clock}) => RigPaintContext(
  skin: EraSkins.of(era),
  clock: clock ?? FilmClock(boilFps: EraSkins.of(era).ink.boilFps),
);

void main() {
  setUpAll(() async {
    await CinemaShaders.preload();
  });

  group('createRig (ToonRig)', () {
    test('is the procedural rubber-hose rig and honours the spec', () {
      const spec = RigSpec(id: 'x', height: 120, body: RigBody.pear);
      final rig = createRig(spec);
      expect(rig, isA<ToonRig>());
      expect(rig.spec, same(spec));
      expect(rig.action, RigAction.idle);
      expect(rig.bounds.height, greaterThan(100));
      rig.dispose();
    });

    test('act switches, re-acting is a no-op unless restart', () {
      final rig = createRig(const RigSpec(id: 'a')) as HoseRig;
      rig.act(RigAction.run);
      run(rig, 0.3);
      expect(rig.action, RigAction.run);
      expect(rig.actionTime, greaterThan(0.25));
      rig.act(RigAction.run);
      expect(rig.actionTime, greaterThan(0.25), reason: 'same action without restart keeps playing');
      rig.act(RigAction.run, restart: true);
      expect(rig.actionTime, 0);
      rig.dispose();
    });

    test('one-shots return to idle; loops and holds persist', () {
      final rig = createRig(const RigSpec(id: 'b'));
      for (final a in [RigAction.land, RigAction.hurt, RigAction.attack]) {
        rig.act(a);
        run(rig, 0.1);
        expect(rig.action, a);
        run(rig, 0.8);
        expect(rig.action, RigAction.idle, reason: '$a returns to idle');
      }
      for (final a in [RigAction.run, RigAction.jump, RigAction.fall, RigAction.cheer, RigAction.defeated]) {
        rig.act(a);
        run(rig, 2);
        expect(rig.action, a, reason: '$a holds');
      }
      rig.dispose();
    });

    test('squash is a springy impulse that overshoots and settles', () {
      final rig = createRig(const RigSpec(id: 'c')) as HoseRig;
      rig.squash(0.3);
      var maxS = 0.0, minS = 0.0;
      for (var i = 0; i < 90; i++) {
        rig.update(1 / 60);
        maxS = maxS > rig.squashAmount ? maxS : rig.squashAmount;
        minS = minS < rig.squashAmount ? minS : rig.squashAmount;
      }
      expect(maxS, greaterThan(0.1));
      expect(minS, lessThan(0), reason: 'rubber overshoots into a stretch');
      run(rig, 2);
      expect(rig.squashAmount.abs(), lessThan(0.14), reason: 'back to the idle bounce');
      rig.dispose();
    });

    test('fast motion stretches the body (velocity-driven)', () {
      final rig = createRig(const RigSpec(id: 'v')) as HoseRig;
      rig
        ..act(RigAction.jump)
        ..velocity = const Offset(0, -1400);
      run(rig, 1);
      expect(rig.squashAmount, lessThan(-0.08));
      rig.velocity = Offset.zero;
      run(rig, 2);
      expect(rig.squashAmount, greaterThan(-0.09));
      rig.dispose();
    });

    test('facing flips through the front view', () {
      final rig = createRig(const RigSpec(id: 'd')) as HoseRig;
      run(rig, 0.5);
      rig.facing = -1;
      expect(rig.facing, -1);
      var sawFront = false;
      for (var i = 0; i < 60; i++) {
        rig.update(1 / 60);
        if (rig.turn < 0.2) sawFront = true;
      }
      expect(sawFront, isTrue);
      expect(rig.facingShown, closeTo(-1, 0.02));
      expect(rig.dir, -1);
      rig.dispose();
    });

    test('draws on twos for idle loops and on ones for travel', () {
      final rig = createRig(const RigSpec(id: 'e')) as HoseRig;
      final clock = FilmClock(boilFps: 12);
      final ctx = ctxFor(Era.rubberHose, clock: clock);
      rig.update(0.5);
      clock.advance(0.5);
      paintOnce(rig, ctx);
      var before = rig.drawings;
      for (var i = 0; i < 120; i++) {
        rig.update(1 / 120);
        clock.advance(1 / 120);
        paintOnce(rig, ctx);
      }
      expect(rig.drawings - before, inInclusiveRange(11, 14), reason: 'idle: ~12 drawings per second at 120 Hz');

      rig
        ..speed = 200
        ..act(RigAction.run);
      before = rig.drawings;
      for (var i = 0; i < 120; i++) {
        rig.update(1 / 120);
        clock.advance(1 / 120);
        paintOnce(rig, ctx);
      }
      expect(rig.drawings - before, inInclusiveRange(23, 27), reason: 'run: ~24 drawings per second');
      rig.dispose();
    });

    test('replays the cached drawing without rebuilding or allocating paths', () {
      final rig = createRig(const RigSpec(id: 'f')) as HoseRig;
      final clock = FilmClock(boilFps: 12);
      final ctx = ctxFor(Era.rubberHose, clock: clock);
      rig.act(RigAction.run);
      for (var i = 0; i < 120; i++) {
        rig.update(1 / 60);
        clock.advance(1 / 60);
        paintOnce(rig, ctx);
      }
      final pool = rig.ink.list.pathPool;
      final drawings = rig.drawings;
      paintOnce(rig, ctx);
      paintOnce(rig, ctx);
      expect(rig.drawings, drawings, reason: 'same instant → replay');
      for (var i = 0; i < 240; i++) {
        rig.update(1 / 60);
        clock.advance(1 / 60);
        paintOnce(rig, ctx);
      }
      expect(rig.ink.list.pathPool, lessThanOrEqualTo(pool + 8), reason: 'the path pool stops growing');
      rig.dispose();
    });

    test('the same boil frame gives the same drawing (deterministic)', () {
      RigCharacter make() => createRig(const RigSpec(id: 'g'));
      final a = make() as HoseRig, b = make() as HoseRig;
      final clock = FilmClock(boilFps: 12)..advance(0.4);
      final ctx = ctxFor(Era.noir, clock: clock);
      run(a, 0.4);
      run(b, 0.4);
      paintOnce(a, ctx);
      paintOnce(b, ctx);
      expect(a.ink.list.opCount, b.ink.list.opCount);
      final ba = a.ink.list.opCount;
      expect(ba, greaterThan(20));
      a.dispose();
      b.dispose();
    });

    test('every body, action and expression paints in every era', () {
      for (final era in Era.values) {
        final ctx = ctxFor(era)..clock.advance(0.3);
        for (final body in RigBody.values) {
          final rig = createRig(RigSpec(id: 'h_${body.name}', body: body));
          for (final a in RigAction.values) {
            rig
              ..act(a)
              ..expression = RigExpression.values[a.index % RigExpression.values.length];
            run(rig, 0.2);
            paintOnce(rig, ctx);
          }
          rig.dispose();
        }
      }
    });

    test('lookAt is in character space (mirrored when facing left)', () {
      final rig = createRig(const RigSpec(id: 'look')) as HoseRig;
      rig
        ..lookAt(const Offset(1, 0))
        ..facing = 1;
      run(rig, 1);
      expect(rig.lookSpring.x, greaterThan(0.8));
      rig.facing = -1;
      run(rig, 1);
      expect(rig.lookSpring.x, lessThan(-0.8), reason: 'looking screen-right while facing left = looking back');
      rig.lookAt(null);
      rig.dispose();
    });

    test('hand overrides and dispose are safe', () {
      final rig = createRig(const RigSpec(id: 'i')) as HoseRig;
      rig
        ..setHand(1, HandShape.point)
        ..flash();
      expect(rig.handOverride(1), HandShape.point);
      expect(rig.flashTime, greaterThan(0));
      paintOnce(rig, ctxFor(Era.rubberHose));
      rig
        ..dispose()
        ..dispose();
    });
  });

  group('the cast', () {
    test('every member builds, acts and paints in every era', () {
      for (final m in RigCast.all) {
        final rig = m.build();
        expect(rig.spec.height, m.height);
        for (final era in Era.values) {
          final ctx = ctxFor(era)..clock.advance(0.25);
          for (final a in RigAction.values) {
            rig.act(a);
            run(rig, 0.15);
            paintOnce(rig, ctx);
          }
          expect(rig.bounds.isEmpty, isFalse);
        }
        rig.dispose();
      }
    });

    test('ids are unique and names are localised', () async {
      final ids = RigCast.all.map((m) => m.id).toSet();
      expect(ids.length, RigCast.all.length);
      final ar = await L10n.delegate.load(const Locale('ar'));
      final en = await L10n.delegate.load(const Locale('en'));
      for (final m in RigCast.all) {
        expect(m.name(ar), isNotEmpty);
        expect(m.role(ar), isNotEmpty);
        expect(m.name(en), isNot(m.name(ar)));
        expect(RigCast.byId(m.id), same(m));
      }
      expect(RigCast.byId('nobody'), isNull);
    });

    test('the clockwork boss has three phases, attacks and anchors', () {
      final boss = RigCast.clockworkBoss(height: 280);
      final ctx = ctxFor(Era.silent)..clock.advance(0.2);
      boss.phase = 5;
      expect(boss.phase, 2);
      boss.phase = -1;
      expect(boss.phase, 0);
      for (final attack in BossAttack.values) {
        boss
          ..attack = attack
          ..act(RigAction.attack);
        run(boss, 0.4);
        paintOnce(boss, ctx);
        expect(boss.action, RigAction.attack);
        run(boss, 0.6);
        expect(boss.action, RigAction.idle);
      }
      boss
        ..attack = BossAttack.punch
        ..act(RigAction.attack);
      run(boss, 0.33);
      ctx.clock.advance(0.1);
      paintOnce(boss, ctx);
      expect(boss.fistAnchor(1).dx, greaterThan(100), reason: 'the punch reaches far forward');
      expect(boss.mouthAnchor.dy, lessThan(-150));
      expect(boss.coreAnchor.dy, lessThan(-80));
      boss.dispose();
    });

    test('the star-bird flaps on every jump and pops feathers when hurt', () {
      final bird = RigCast.starBird();
      bird.act(RigAction.jump);
      run(bird, 0.3);
      bird.act(RigAction.jump, restart: true);
      expect(bird.action, RigAction.jump);
      expect(bird.squashAmount, lessThan(0.05));
      bird.pitch = 0.4;
      bird.act(RigAction.hurt);
      run(bird, 0.2);
      paintOnce(bird, ctxFor(Era.rubberHose));
      bird.dispose();
    });
  });

  group('props', () {
    test('props paint, animate and cache', () {
      final ctx = ctxFor(Era.rubberHose);
      final props = <InkProp>[
        InkCloud(size: 100, mood: PropMood.sleepy),
        InkStar(size: 40, mood: PropMood.happy),
        InkGear(size: 80, speed: 2),
        InkCrate(size: 60),
        InkMoon(size: 80),
        InkPuff(size: 40),
        InkSketch(
          size: 60,
          extent: const Rect.fromLTRB(-32, -32, 32, 32),
          draw: (b) {
            b.layer();
            b.shape(b.colors.fill(PaletteRole.midtone));
            b.pen.circle(0, 0, 30);
            b.endLayer();
          },
        ),
      ];
      for (final p in props) {
        p.update(0.2);
        final rec = PictureRecorder();
        p.paint(Canvas(rec), ctx);
        rec.endRecording().dispose();
        expect(p.ink.list.opCount, greaterThan(0));
        expect(p.bounds.isEmpty, isFalse);
      }
      final gear = props[2] as InkGear;
      final a0 = gear.angle;
      gear.update(0.5);
      expect(gear.angle, closeTo(a0 + 1, 1e-9));
      final puff = props[5] as InkPuff;
      puff.update(2);
      expect(puff.done, isTrue);
      puff.restart();
      expect(puff.done, isFalse);
      (props[3] as InkCrate).hit();
      for (final p in props) {
        p.dispose();
      }
    });
  });

  group('ink toolkit', () {
    test('pen maps through its transform stack', () {
      final pen = InkPen()
        ..translate(10, 0)
        ..scale(2);
      expect(pen.x(1, 0), 12);
      pen
        ..save()
        ..rotate(1.5707963267948966);
      expect(pen.x(1, 0), closeTo(10, 1e-9));
      expect(pen.y(1, 0), closeTo(2, 1e-9));
      pen.restore();
      expect(pen.y(1, 0), 0);
      pen.scale(-1, 1);
      expect(pen.mirrored, isTrue);
    });

    test('contours: area, wobble, crescent and brush', () {
      final pen = InkPen();
      final c = Contour(64)..ellipse(pen, 0, 0, 10, 10, samples: 32);
      expect(c.length, 32);
      expect(c.signedArea().abs(), closeTo(314, 6));
      final b0 = c.bounds;
      c.wobble(1, 3, 7, 1);
      expect(c.length, 32);
      expect(c.bounds.width, closeTo(b0.width, 3));
      final p = Path();
      c.writeCrescent(p, kShadowX, kShadowY, 3);
      final area = p.getBounds();
      expect(area.right, greaterThan(5));
      final open = Contour(16)
        ..clear(closed: false)
        ..quad(pen, 0, 0, 10, 10, 20, 0);
      final bp = Path();
      open.writeBrush(bp, 4);
      expect(bp.getBounds().width, greaterThan(18));
    });

    test('springs settle on their targets', () {
      final s = Spring1();
      final s2 = Spring2();
      for (var i = 0; i < 600; i++) {
        s.step(1 / 120, 5, 20, 0.5);
        s2.step(1 / 120, 3, -4, 20, 0.5);
      }
      expect(s.value, closeTo(5, 1e-3));
      expect(s2.x, closeTo(3, 1e-3));
      expect(s2.y, closeTo(-4, 1e-3));
      expect(Bounce.hop(0), closeTo(0, 1e-9));
      expect(Bounce.hop(0.5), closeTo(1, 1e-9));
      expect(Bounce.contact(1), closeTo(1, 1e-9));
    });

    test('boil noise is deterministic and bounded', () {
      for (var i = 0; i < 500; i++) {
        final n = boilNoise(i, 3, 7);
        expect(n, inInclusiveRange(-1.0, 1.0));
        expect(boilNoise(i, 3, 7), n);
      }
      expect(seedOf('nujaym'), seedOf('nujaym'));
      expect(seedOf('nujaym'), isNot(seedOf('zajil')));
    });
  });

  testWidgets('RigComponent hosts a cast member', (tester) async {
    // The contract's Flame host works with the richer builders too.
    final c = RigComponent(rig: RigCast.camelCourier(), position: Vector2(10, 20));
    expect(c.size.y, 120);
    expect(c.anchor, Anchor.bottomCenter);
  });
}
