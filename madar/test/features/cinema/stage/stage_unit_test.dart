import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/engine/cinema_engine.dart';
import 'package:madar/features/cinema/engine/stage/stage_kit.dart';

/// Records a paint call into a throwaway picture.
void paintInto(void Function(Canvas c) paint) {
  final rec = ui.PictureRecorder();
  paint(Canvas(rec));
  rec.endRecording().dispose();
}

void main() {
  setUpAll(() async => CinemaShaders.preload());

  group('CurtainMotion', () {
    test('a haul opens the curtain, overshoots a little, settles and completes', () async {
      final m = CurtainMotion();
      var done = false;
      m.haul(1, const Duration(milliseconds: 1500)).then((_) => done = true);
      var peak = 0.0, swing = 0.0;
      for (var i = 0; i < 60 * 4 && !done; i++) {
        m.update(1 / 60);
        await Future<void>.delayed(Duration.zero);
        peak = peak > m.open ? peak : m.open;
        swing = swing > m.swing.abs() ? swing : m.swing.abs();
      }
      expect(done, isTrue);
      expect(m.open, closeTo(1, 0.01));
      expect(m.openClamped, lessThanOrEqualTo(1));
      expect(peak, lessThan(1.12), reason: 'a heavy drape overshoots only slightly');
      expect(swing, greaterThan(0.01), reason: 'the hem trails and swings');
      expect(m.gather, closeTo(1, 0.02));
    });

    test('closing reverses; the hem swings the other way first', () async {
      final m = CurtainMotion(open: 1);
      m.haul(0, const Duration(milliseconds: 1200));
      var minSwing = 0.0;
      for (var i = 0; i < 20; i++) {
        m.update(1 / 60);
        if (m.swing < minSwing) minSwing = m.swing;
      }
      expect(minSwing, lessThan(0), reason: 'closing accelerates inward: the hem trails outward');
      for (var i = 0; i < 60 * 4; i++) {
        m.update(1 / 60);
      }
      expect(m.open, closeTo(0, 0.01));
      expect(m.gather, 0);
    });

    test('zero duration jumps; cancel completes a pending haul; 20 fps is stable', () async {
      final m = CurtainMotion();
      await m.haul(1, Duration.zero);
      expect(m.open, 1);
      var done = false;
      m.haul(0, const Duration(seconds: 2)).then((_) => done = true);
      m.cancel();
      await Future<void>.delayed(Duration.zero);
      expect(done, isTrue);
      final slow = CurtainMotion();
      slow.haul(1, const Duration(milliseconds: 800));
      for (var i = 0; i < 80; i++) {
        slow.update(1 / 20);
        expect(slow.open.isFinite && slow.swing.isFinite, isTrue);
      }
      expect(slow.open, closeTo(1, 0.02));
    });
  });

  group('ReelStage', () {
    for (final era in Era.values) {
      test('lays out a sane theatre and paints – ${era.name}', () {
        final stage = ReelStage(CinemaEnv(skin: EraSkins.of(era)));
        const screen = Size(412, 915);
        stage.layout(screen, const EdgeInsets.only(top: 24, bottom: 16));
        final play = stage.playRect, hud = stage.hudRect;
        expect(play.left, greaterThan(10));
        expect(play.right, lessThan(screen.width - 10));
        expect(play.top, greaterThan(40));
        expect(play.bottom, lessThan(screen.height - 30));
        expect(play.width, greaterThan(330), reason: 'the frame leaves most of the width to the game');
        expect(play.contains(hud.topLeft) && play.contains(hud.bottomRight - const Offset(1, 1)), isTrue);
        expect(hud.top, greaterThan(24 + 8 - 0.1), reason: 'the HUD avoids the status bar');
        final clock = FilmClock();
        stage.openCurtains(duration: Duration.zero);
        for (var i = 0; i < 5; i++) {
          clock.advance(1 / 60);
          stage.update(1 / 60, clock);
        }
        expect(stage.curtainOpen, 1);
        stage
          ..spotlight(play.center)
          ..pulse(1);
        paintInto((c) {
          stage
            ..paintBack(c)
            ..paintFront(c);
        });
        stage.dispose();
      });
    }

    test('landscape and tiny screens stay sane', () {
      final stage = ReelStage(CinemaEnv(skin: EraSkins.of(Era.technicolor)));
      for (final s in const [Size(915, 412), Size(320, 480), Size(1024, 1366)]) {
        stage.layout(s, EdgeInsets.zero);
        expect(stage.playRect.width, greaterThan(s.width * 0.8));
        expect(stage.playRect.height, greaterThan(s.height * 0.7));
        expect(stage.hudRect.isEmpty, isFalse);
      }
      stage.dispose();
    });

    test('the beat ticks overlays on every update, also with the world paused', () {
      final stage = ReelStage(CinemaEnv(skin: EraSkins.of(Era.noir)))..layout(const Size(400, 800), EdgeInsets.zero);
      var ticks = 0;
      stage.beat.addListener(() => ticks++);
      final clock = FilmClock();
      for (var i = 0; i < 3; i++) {
        clock.advance(1 / 60);
        stage.update(1 / 60, clock);
      }
      expect(ticks, 3);
      expect(stage.beat.clock, same(clock));
      stage.dispose();
    });

    test('materials exist for every era and are cached per skin', () {
      for (final era in Era.values) {
        final skin = EraSkins.of(era);
        expect(identical(StageMaterials.of(skin), StageMaterials.of(skin)), isTrue);
      }
      expect(StageMaterials.of(EraSkins.of(Era.vhs)).isNeon, isTrue);
    });
  });

  group('HUD kit', () {
    HudContext ctx(Era era, HudModel model, FilmClock clock, {TextDirection dir = TextDirection.rtl}) =>
        HudContext(skin: EraSkins.of(era), clock: clock, model: model, direction: dir);

    test('score counts up in rolling steps, never overshooting', () {
      final env = CinemaEnv(skin: EraSkins.of(Era.rubberHose));
      final model = HudModel()..score = 0;
      final clock = FilmClock();
      final c = ctx(Era.rubberHose, model, clock);
      final item = ReelHudKit(env).score() as ScoreHudItem;
      final size0 = item.layoutSize(c);
      model
        ..score = 1250
        ..best = 900;
      for (var i = 0; i < 30; i++) {
        clock.advance(1 / 60);
        item.update(1 / 60, c);
      }
      expect(item.layoutSize(c).height, greaterThan(size0.height), reason: 'the best tab hangs below');
      for (var i = 0; i < 240; i++) {
        clock.advance(1 / 60);
        item.update(1 / 60, c);
        item.layoutSize(c);
      }
      expect(item.layoutSize(c).width, greaterThan(size0.width), reason: 'four digits need more room than two');
      paintInto((canvas) => item.paint(canvas, Offset.zero & item.layoutSize(c), c));
      item.dispose();
    });

    test('lives size by maxLives; the boss bar, timer and progress hide while null', () {
      for (final era in Era.values) {
        final env = CinemaEnv(skin: EraSkins.of(era));
        final model = HudModel();
        final clock = FilmClock();
        final c = ctx(era, model, clock);
        final kit = ReelHudKit(env);
        final lives = kit.lives();
        final boss = kit.bossBar();
        final timer = kit.timer();
        final progress = kit.progress();
        expect(lives.layoutSize(c).width, greaterThan(0));
        expect(boss.layoutSize(c), Size.zero);
        expect(timer.layoutSize(c), Size.zero);
        expect(progress.layoutSize(c), Size.zero);
        model
          ..bossHealth = 1
          ..bossName = 'Baron'
          ..timeLeft = const Duration(seconds: 7)
          ..progress = 0.4;
        expect(boss.layoutSize(c).width, greaterThan(100));
        expect(timer.layoutSize(c).width, greaterThan(40));
        expect(progress.layoutSize(c).width, greaterThan(100));
        // A hit: a life lost, the boss burnt back.
        for (final item in [lives, boss, timer, progress]) {
          item.update(1 / 60, c);
        }
        model
          ..lives = 2
          ..bossHealth = 0.5;
        for (var i = 0; i < 20; i++) {
          clock.advance(1 / 60);
          for (final item in [lives, boss, timer, progress]) {
            item.update(1 / 60, c);
          }
        }
        paintInto((canvas) {
          for (final item in [lives, boss, timer, progress]) {
            item.paint(canvas, Offset.zero & item.layoutSize(c), c);
          }
        });
        for (final item in [lives, boss, timer, progress]) {
          item.dispose();
        }
      }
    });

    test('the pause button is interactive and fires once per tap; labels re-lay out on change', () {
      final env = CinemaEnv(skin: EraSkins.of(Era.technicolor));
      final c = ctx(Era.technicolor, HudModel(), FilmClock());
      var pressed = 0;
      final pause = ReelHudKit(env).pauseButton(() => pressed++);
      expect(pause.interactive, isTrue);
      expect(pause.onTap(const Offset(10, 10), c), isTrue);
      expect(pressed, 1);
      var text = 'أ';
      final label = ReelHudKit(env).label(() => text);
      final w1 = label.layoutSize(c).width;
      text = 'مرحلة طويلة جدًا';
      expect(label.layoutSize(c).width, greaterThan(w1));
      text = '';
      expect(label.layoutSize(c), Size.zero);
    });

    test('HUD numbers use Arabic-Indic digits in Arabic', () {
      expect(hudDigits('1250', 'ar'), '١٢٥٠');
      expect(hudDigits('1250', 'en'), '1250');
      expect(hudDigits('0:07', 'ar'), '٠:٠٧');
    });
  });

  group('ReelTransitions', () {
    Future<void> run(CinemaTransitions t, FilmClock clock, double seconds) async {
      for (var i = 0; i < (seconds * 60).ceil(); i++) {
        clock.advance(1 / 60);
        t.update(1 / 60, clock);
        await Future<void>.delayed(Duration.zero);
      }
    }

    for (final era in Era.values) {
      test('iris out / card / iris in in the era style – ${era.name}', () async {
        final t = ReelTransitions(CinemaEnv(skin: EraSkins.of(era)))
          ..layout(const Size(400, 800), const Rect.fromLTWH(20, 60, 360, 680));
        final clock = FilmClock();
        var closed = false;
        t.irisOut().then((_) => closed = true);
        await run(t, clock, 0.5);
        paintInto(t.paint);
        await run(t, clock, 1.2);
        expect(closed, isTrue);
        expect(t.coverage, closeTo(1, 1e-6));
        var carded = false;
        t
            .intertitle(
              const IntertitleCard(text: 'النهاية', kind: IntertitleKind.theEnd),
              hold: const Duration(milliseconds: 300),
            )
            .then((_) => carded = true);
        await run(t, clock, 0.3);
        expect(t.isActive, isTrue);
        paintInto(t.paint);
        await run(t, clock, 1);
        expect(carded, isTrue);
        var opened = false;
        t.irisIn().then((_) => opened = true);
        await run(t, clock, 0.4);
        paintInto(t.paint);
        await run(t, clock, 1.2);
        expect(opened, isTrue);
        expect(t.coverage, lessThan(0.001));
        expect(t.isActive, isFalse);
        t.dispose();
      });
    }

    test('clear completes pending futures', () async {
      final t = ReelTransitions(CinemaEnv(skin: EraSkins.of(Era.silent)))
        ..layout(const Size(400, 800), const Rect.fromLTWH(0, 0, 400, 800));
      var done = 0;
      t.irisOut().then((_) => done++);
      t.intertitle(const IntertitleCard(text: 'x')).then((_) => done++);
      t.clear();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(done, greaterThanOrEqualTo(1));
      expect(t.coverage, 0);
      t.dispose();
    });
  });
}
