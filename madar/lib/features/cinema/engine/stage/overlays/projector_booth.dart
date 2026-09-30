import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/cinema_game.dart';
import '../../core/era_labels.dart';
import '../hud/hud_paint.dart';
import '../hud/reel_hud_kit.dart';
import '../stage_ornaments.dart';
import 'overlay_kit.dart';

/// The intermission menu (CinemaOverlays.pause) styled as the projection
/// booth: the projector idles on its stand – reels turning, lamp flickering,
/// its beam leaving through the booth's porthole with dust in it (a VCR
/// paused on "‖" in the 80s) – above the era's title plate and three real
/// buttons: resume, restart, leave. Animated on game time (the stage beat).
class ProjectorBoothOverlay extends StatefulWidget {
  const ProjectorBoothOverlay({super.key, required this.game});

  final CinemaGame game;

  @override
  State<ProjectorBoothOverlay> createState() => _ProjectorBoothOverlayState();
}

class _ProjectorBoothOverlayState extends State<ProjectorBoothOverlay> {
  late final OverlayScene _scene = OverlayScene(widget.game);
  late final OverlayTimer _timer = OverlayTimer(_scene);
  final ui.FragmentShader? _paper = overlayPaperShader();

  @override
  void dispose() {
    _paper?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final l10n = game.l10n;
    final s = _scene;
    final score = hudDigits('${game.hud.score}', game.env.languageCode);
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: l10n.cinemaIntermission,
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _DimPainter(s, _timer)),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: AnimatedBuilder(
                      animation: s.repaint,
                      builder: (context, child) {
                        // Drops in from above and settles with a bounce.
                        final t = (_timer.elapsed / 0.55).clamp(0.0, 1.0);
                        final e = Curves.elasticOut.transform(t);
                        return Transform.translate(
                          offset: Offset(0, -60 * (1 - e)),
                          child: Opacity(opacity: math.min(1, t * 3), child: child),
                        );
                      },
                      child: SizedBox(
                        width: 340,
                        child: CustomPaint(
                          painter: CardBackgroundPainter(s, _paper, seed: 11),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  height: 172,
                                  width: double.infinity,
                                  child: CustomPaint(painter: _BoothPainter(s)),
                                ),
                                const SizedBox(height: 4),
                                Text(l10n.cinemaIntermission, textAlign: TextAlign.center, style: s.title(38)),
                                const SizedBox(height: 4),
                                Text(l10n.cinemaStageBoothNote, textAlign: TextAlign.center, style: s.body(15)),
                                const SizedBox(height: 6),
                                Text(
                                  '${game.era.label(l10n)}  ·  ${l10n.cinemaScoreLine(score)}',
                                  textAlign: TextAlign.center,
                                  style: s.body(13, color: s.text.withValues(alpha: 0.65)),
                                ),
                                const SizedBox(height: 18),
                                StageButton(
                                  scene: s,
                                  label: l10n.cinemaResume,
                                  onPressed: game.resumeGame,
                                  primary: true,
                                  icon: Icons.play_arrow_rounded,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: StageButton(scene: s, label: l10n.cinemaRestart, onPressed: game.requestRestart),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: StageButton(scene: s, label: l10n.cinemaLeave, onPressed: game.requestExit),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dims the paused scene (fading in) with a vignette.
class _DimPainter extends CustomPainter {
  _DimPainter(this.scene, this.timer) : super(repaint: scene.repaint);

  final OverlayScene scene;
  final OverlayTimer timer;

  @override
  void paint(Canvas canvas, Size size) {
    final a = (timer.elapsed / 0.3).clamp(0.0, 1.0);
    final ink = scene.skin.palette.ink;
    final r = Offset.zero & size;
    canvas.drawRect(
      r,
      Paint()
        ..shader = ui.Gradient.radial(r.center, size.longestSide * 0.7, [ink.withValues(alpha: 0.5 * a), ink.withValues(alpha: 0.86 * a)]),
    );
  }

  @override
  bool shouldRepaint(covariant _DimPainter old) => false;
}

/// The projector (or, in the 80s, the VCR) idling in its booth.
class _BoothPainter extends CustomPainter {
  _BoothPainter(this.scene) : super(repaint: scene.repaint);

  final OverlayScene scene;
  final ReelGlyph _reel = ReelGlyph();
  final Paint _p = Paint();
  final Paint _add = Paint()..blendMode = BlendMode.plus;

  @override
  void paint(Canvas canvas, Size size) {
    final rtl = scene.hud.direction == TextDirection.rtl;
    if (rtl) {
      canvas
        ..save()
        ..translate(size.width, 0)
        ..scale(-1, 1);
    }
    if (scene.neon) {
      _vcr(canvas, size);
    } else {
      _projector(canvas, size);
    }
    if (rtl) canvas.restore();
  }

  void _projector(Canvas canvas, Size size) {
    final m = scene.materials;
    final pal = scene.skin.palette;
    final t = scene.beat == null ? 0.4 : scene.clock.time;
    final ink = m.ink;
    const lw = 1.6;
    final w = size.width, h = size.height;
    final metal = scene.skin.era.isMonochrome ? Color.lerp(m.paper, m.gilt, 0.6)! : m.gilt;
    final metalDark = m.giltDark;
    final cx = w * 0.4;
    // Porthole in the booth wall.
    final port = Offset(w * 0.92, h * 0.5);
    Ornaments.inked(canvas, Path()..addOval(Rect.fromCircle(center: port, radius: 25)), metalDark, ink, lw);
    _p.color = Color.lerp(pal.shadow, pal.ink, 0.5)!;
    canvas.drawCircle(port, 19, _p);
    for (var i = 0; i < 8; i++) {
      final a = math.pi * 2 * i / 8;
      _p.color = m.giltLight;
      canvas.drawCircle(port + Offset(math.cos(a), math.sin(a)) * 22, 1.3, _p);
    }
    // Floor line.
    Ornaments.line(
      canvas,
      Path()
        ..moveTo(0, h - 3)
        ..lineTo(w, h - 3),
      ink.withValues(alpha: 0.5),
      2,
    );
    // Stand.
    final stand = Path()
      ..moveTo(cx - 34, h - 3)
      ..lineTo(cx - 16, h - 48)
      ..lineTo(cx + 16, h - 48)
      ..lineTo(cx + 34, h - 3)
      ..close();
    Ornaments.inked(canvas, stand, metalDark, ink, lw);
    Ornaments.inked(
      canvas,
      Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx - 44, h - 9, 88, 7), const Radius.circular(3))),
      metal,
      ink,
      lw,
    );
    // Film path (behind the body).
    final rearReel = Offset(cx - 38, h * 0.2);
    final frontReel = Offset(cx + 30, h * 0.24);
    final film = Path()
      ..moveTo(rearReel.dx + 4, rearReel.dy + 28)
      ..quadraticBezierTo(cx - 20, h * 0.5, cx - 6, h * 0.5)
      ..moveTo(cx + 18, h * 0.52)
      ..quadraticBezierTo(frontReel.dx + 26, h * 0.5, frontReel.dx + 8, frontReel.dy + 26);
    Ornaments.line(canvas, film, ink, 4);
    // Reel arms.
    final arms = Path()
      ..moveTo(cx - 20, h * 0.52)
      ..lineTo(rearReel.dx, rearReel.dy)
      ..moveTo(cx + 12, h * 0.52)
      ..lineTo(frontReel.dx, frontReel.dy);
    Ornaments.line(canvas, arms, ink, 6);
    Ornaments.line(canvas, arms, metalDark, 3);
    // Beam: the lens throws the picture through the porthole.
    final lens = Offset(cx + 84, h * 0.62);
    final flicker = 0.75 + 0.25 * math.sin(t * 47) * math.sin(t * 13.3);
    final beam = Path()
      ..moveTo(lens.dx, lens.dy - 5)
      ..lineTo(port.dx + 30, port.dy - 34)
      ..lineTo(port.dx + 30, port.dy + 34)
      ..lineTo(lens.dx, lens.dy + 5)
      ..close();
    _add
      ..shader = ui.Gradient.linear(lens, port + const Offset(30, 0), [
        m.glow.withValues(alpha: 0.55 * flicker),
        m.glow.withValues(alpha: 0.12 * flicker),
      ])
      ..color = const Color(0xFFFFFFFF);
    canvas.drawPath(beam, _add);
    _add.shader = null;
    // Dust in the beam.
    for (var k = 0; k < 9; k++) {
      final ph = (t * (0.12 + k * 0.013) + k * 0.37) % 1;
      final x = lens.dx + (port.dx - lens.dx + 20) * ph;
      final spread = 4 + 26 * ph;
      final y = lens.dy + math.sin(k * 3.7 + t * 0.9) * spread;
      _add.color = pal.highlight.withValues(alpha: 0.5 * (1 - ph) * flicker);
      canvas.drawCircle(Offset(x, y), 1.1, _add);
    }
    // Lamp house body.
    final body = RRect.fromRectAndRadius(Rect.fromLTWH(cx - 56, h * 0.44, 118, 52), const Radius.circular(10));
    Ornaments.inked(
      canvas,
      Path()..addRRect(body),
      metal,
      ink,
      lw,
      shader: ui.Gradient.linear(
        body.outerRect.topCenter,
        body.outerRect.bottomCenter,
        [m.giltLight, metal, metalDark],
        const [0, 0.35, 1],
      ),
    );
    // Chimney with a curl of heat.
    final chimney = Rect.fromLTWH(cx - 46, h * 0.44 - 18, 16, 20);
    Ornaments.inked(canvas, Path()..addRect(chimney), metalDark, ink, lw);
    Ornaments.inked(canvas, Path()..addRect(Rect.fromLTWH(chimney.left - 3, chimney.top - 4, 22, 5)), metal, ink, lw);
    // Vents glowing with the lamp.
    for (var k = 0; k < 4; k++) {
      final r = RRect.fromRectAndRadius(Rect.fromLTWH(cx - 48 + k * 10, h * 0.44 + 14, 5, 24), const Radius.circular(2.5));
      _p.color = ink;
      canvas.drawRRect(r, _p);
      _add.color = m.glow.withValues(alpha: 0.6 * flicker);
      canvas.drawRRect(r.deflate(1.2), _add);
    }
    // Badge with the orbit emblem.
    final badge = Offset(cx + 22, h * 0.44 + 26);
    Ornaments.inked(canvas, Path()..addOval(Rect.fromCircle(center: badge, radius: 14)), m.paper, ink, lw);
    Ornaments.orbitEmblem(
      canvas,
      badge,
      8.5,
      ring: m.gilt,
      planet: scene.skin.era.isMonochrome ? m.ink : pal.accent,
      ink: ink,
      lineWidth: 1,
    );
    // Lens barrel.
    final barrel = Path()
      ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx + 60, h * 0.62 - 10, 16, 20), const Radius.circular(3)))
      ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx + 74, h * 0.62 - 8, 12, 16), const Radius.circular(3)));
    Ornaments.inked(canvas, barrel, metalDark, ink, lw);
    _add.color = m.glow.withValues(alpha: 0.9 * flicker);
    canvas.drawCircle(lens, 4, _add);
    // Reels turning (on twos, like everything inked).
    final boil = scene.beat == null ? 0 : scene.clock.boilFrame;
    final ctx = scene.hud;
    final saved = ctx.scale;
    ctx.scale = 1.1;
    _reel.paint(canvas, rearReel, 30, -boil * 0.42, 0.85, ctx);
    _reel.paint(canvas, frontReel, 26, -boil * 0.5 + 1, 0.4, ctx);
    ctx.scale = saved;
  }

  void _vcr(Canvas canvas, Size size) {
    final m = scene.materials;
    final pal = scene.skin.palette;
    final t = scene.beat == null ? 0.4 : scene.clock.time;
    final w = size.width, h = size.height;
    // A tape on top, the deck below.
    final deck = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.08, h * 0.46, w * 0.84, h * 0.4), const Radius.circular(6));
    _p.shader = ui.Gradient.linear(deck.outerRect.topCenter, deck.outerRect.bottomCenter, [m.wallLight, m.wallDark]);
    canvas.drawRRect(deck, _p);
    _p.shader = null;
    Ornaments.neon(canvas, Path()..addRRect(deck), m.neonA, 1.3);
    // Cassette slot with a tape half in.
    final slot = Rect.fromLTWH(deck.left + 18, deck.top + 12, deck.width * 0.52, 14);
    _p.color = const Color(0xFF000000);
    canvas.drawRect(slot, _p);
    final tape = Rect.fromLTWH(slot.left + 10, slot.top - 38, slot.width - 20, 46);
    _p.color = const Color(0xFF15101F);
    canvas.drawRRect(RRect.fromRectAndRadius(tape, const Radius.circular(3)), _p);
    Ornaments.neon(canvas, Path()..addRRect(RRect.fromRectAndRadius(tape, const Radius.circular(3))), m.neonB, 0.9, intensity: 0.8);
    _p.color = pal.paper.withValues(alpha: 0.85);
    canvas.drawRect(Rect.fromLTWH(tape.left + 12, tape.top + 7, tape.width - 24, 9), _p);
    for (final x in [tape.left + tape.width * 0.32, tape.left + tape.width * 0.68]) {
      _p.color = m.wall;
      canvas.drawCircle(Offset(x, tape.top + 30), 7, _p);
      Ornaments.neon(canvas, Path()..addOval(Rect.fromCircle(center: Offset(x, tape.top + 30), radius: 7)), m.neonB, 0.7, intensity: 0.7);
    }
    // Display: a blinking pause.
    final disp = Rect.fromLTWH(deck.right - deck.width * 0.36, deck.top + 12, deck.width * 0.3, 26);
    _p.color = const Color(0xFF050309);
    canvas.drawRRect(RRect.fromRectAndRadius(disp, const Radius.circular(3)), _p);
    if ((t * 1.6).floor().isEven) {
      final c = disp.center;
      final bars = Path()
        ..addRect(Rect.fromCenter(center: c - const Offset(5, 0), width: 4, height: 14))
        ..addRect(Rect.fromCenter(center: c + const Offset(5, 0), width: 4, height: 14));
      Ornaments.neon(canvas, bars, m.neonB, 1.1);
    }
    // Buttons.
    for (var k = 0; k < 4; k++) {
      final r = Rect.fromLTWH(deck.left + 18 + k * 26, deck.bottom - 22, 20, 9);
      _p.color = m.wallLight;
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(2)), _p);
    }
    _add.color = m.neonA.withValues(alpha: 0.5 + 0.5 * math.sin(t * 5).abs());
    canvas.drawCircle(Offset(deck.right - 16, deck.bottom - 17), 3, _add);
  }

  @override
  bool shouldRepaint(covariant _BoothPainter old) => old.scene != scene;
}
