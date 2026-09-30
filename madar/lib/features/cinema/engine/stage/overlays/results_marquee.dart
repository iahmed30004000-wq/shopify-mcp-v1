import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../../core/i18n/formatters.dart';
import '../../core/cinema_game.dart';
import '../../core/era_skin.dart';
import '../../core/shader_uniforms.dart';
import '../hud/hud_paint.dart';
import '../stage_ornaments.dart';
import 'overlay_kit.dart';

/// The end-of-show card (CinemaOverlays.results): a marquee board ringed by
/// chasing bulbs, "The End" / "Show's Over" in the era's lettering, and a
/// ticket stub where the score counts up, with the best score, the running
/// time and – when beaten – a "New record!" rubber stamp thumping down.
/// Buttons: play again (lit), leave. Animated on game time.
class ResultsMarqueeOverlay extends StatefulWidget {
  const ResultsMarqueeOverlay({super.key, required this.game});

  final CinemaGame game;

  @override
  State<ResultsMarqueeOverlay> createState() => _ResultsMarqueeOverlayState();
}

class _ResultsMarqueeOverlayState extends State<ResultsMarqueeOverlay> {
  late final OverlayScene _scene = OverlayScene(widget.game);
  late final OverlayTimer _timer = OverlayTimer(_scene);
  final ui.FragmentShader? _paper = overlayPaperShader();
  final ui.FragmentShader? _ticketPaper = overlayPaperShader();

  @override
  void initState() {
    super.initState();
    // Curtain call: the lens opens on the stage and the house curtains
    // swing shut behind the card.
    final game = widget.game;
    unawaited(game.transitions.irisIn(duration: const Duration(milliseconds: 650)));
    unawaited(game.stage.closeCurtains(duration: const Duration(milliseconds: 1700)));
  }

  @override
  void dispose() {
    _paper?.dispose();
    _ticketPaper?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final l10n = game.l10n;
    final s = _scene;
    final r = game.result;
    final won = r?.won ?? false;
    final score = r?.score ?? game.hud.score;
    final best = game.hud.best;
    final record = score > 0 && score > (best ?? 0);
    final fmt = MadarFormatter.of(context);
    final time = r == null ? null : fmt.formatDuration(r.playTime, seconds: true);
    final title = won ? l10n.cinemaTheEnd : l10n.cinemaGameOver;
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: '$title. ${l10n.cinemaScoreLine(fmt.formatInt(score))}',
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: s.skin.palette.ink.withValues(alpha: 0.42)),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: AnimatedBuilder(
                      animation: s.repaint,
                      builder: (context, child) {
                        final t = (_timer.elapsed / 0.6).clamp(0.0, 1.0);
                        final e = Curves.easeOutBack.transform(t);
                        return Transform.scale(
                          scale: 0.7 + 0.3 * e,
                          child: Opacity(opacity: math.min(1, t * 2.5), child: child),
                        );
                      },
                      child: SizedBox(
                        width: 340,
                        child: CustomPaint(
                          painter: _MarqueeBoardPainter(s, _paper),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(30, 30, 30, 30),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(height: 26, width: 180, child: CustomPaint(painter: _StarsPainter(s, won))),
                                const SizedBox(height: 6),
                                Text(title, textAlign: TextAlign.center, style: s.title(44)),
                                const SizedBox(height: 14),
                                AnimatedBuilder(
                                  animation: s.repaint,
                                  builder: (context, _) {
                                    final t = _timer.elapsed;
                                    final count = ((t - 0.45) / 1.1).clamp(0.0, 1.0);
                                    final shown = (score * Curves.easeOutCubic.transform(count)).round();
                                    final stamp = ((t - 1.6) / 0.28).clamp(0.0, 1.0);
                                    return _Ticket(
                                      scene: s,
                                      paper: _ticketPaper,
                                      admit: l10n.cinemaStageAdmitOne,
                                      scoreLabel: l10n.cinemaStageScore,
                                      score: fmt.formatInt(shown),
                                      best: best == null
                                          ? null
                                          : l10n.cinemaBestLine(fmt.formatInt(math.max(best, record ? score : best))),
                                      time: time == null ? null : '${l10n.cinemaStageRunningTime}: $time',
                                      stamp: record ? l10n.cinemaStageNewRecord : null,
                                      stampT: stamp,
                                    );
                                  },
                                ),
                                const SizedBox(height: 20),
                                StageButton(
                                  scene: s,
                                  label: l10n.cinemaPlayAgain,
                                  onPressed: game.requestRestart,
                                  primary: true,
                                  icon: Icons.replay_rounded,
                                ),
                                const SizedBox(height: 12),
                                StageButton(
                                  scene: s,
                                  label: l10n.cinemaLeave,
                                  onPressed: game.requestExit,
                                  icon: Icons.logout_rounded,
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

/// The marquee board: the era's card with a ring of chasing bulbs.
class _MarqueeBoardPainter extends CustomPainter {
  _MarqueeBoardPainter(this.scene, this.paper)
    : _card = CardBackgroundPainter(scene, paper, seed: 17),
      super(repaint: scene.repaint);

  final OverlayScene scene;
  final ui.FragmentShader? paper;
  final CardBackgroundPainter _card;
  final Paint _p = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    _card.paint(canvas, size);
    final m = scene.materials;
    final r = (Offset.zero & size).deflate(13);
    final t = scene.beat == null ? 0.0 : scene.clock.time;
    if (scene.neon) {
      Ornaments.neon(
        canvas,
        Path()..addRRect(RRect.fromRectAndRadius(r, const Radius.circular(8))),
        m.neonB,
        1.3,
        intensity: 0.85 + 0.15 * math.sin(t * 30),
      );
      return;
    }
    // Bulbs round the board, chasing.
    final per = r.width * 2 + r.height * 2;
    final n = (per / 21).floor();
    for (var i = 0; i < n; i++) {
      var d = per * i / n;
      Offset c;
      if (d < r.width) {
        c = Offset(r.left + d, r.top);
      } else if ((d -= r.width) < r.height) {
        c = Offset(r.right, r.top + d);
      } else if ((d -= r.height) < r.width) {
        c = Offset(r.right - d, r.bottom);
      } else {
        d -= r.width;
        c = Offset(r.left, r.bottom - d);
      }
      final lit = ((i + (t * 7).floor()) % 3 == 0) ? 1.0 : 0.3;
      if (lit > 0.5) {
        _p.color = m.glow.withValues(alpha: 0.4);
        canvas.drawCircle(c, 8, _p);
      }
      _p.color = m.ink;
      canvas.drawCircle(c, 4.4, _p);
      _p.color = Color.lerp(m.bulbOff, m.bulb, lit)!;
      canvas.drawCircle(c, 3.3, _p);
    }
  }

  @override
  bool shouldRepaint(covariant _MarqueeBoardPainter old) => false;
}

/// Three stars that twinkle for a happy ending (a single dim one otherwise).
class _StarsPainter extends CustomPainter {
  _StarsPainter(this.scene, this.won) : super(repaint: scene.repaint);

  final OverlayScene scene;
  final bool won;

  @override
  void paint(Canvas canvas, Size size) {
    final m = scene.materials;
    final t = scene.beat == null ? 0.0 : scene.clock.time;
    final c = size.center(Offset.zero);
    final fill = scene.skin.era.isMonochrome ? m.paper : m.gilt;
    final positions = won ? const [-1.0, 0.0, 1.0] : const [0.0];
    for (final k in positions) {
      final r = (k == 0 ? 12.0 : 9.0) * (1 + 0.08 * math.sin(t * 5 + k * 2));
      final p = Ornaments.starPath(
        c + Offset(k * 36, k == 0 ? -1 : 3),
        r,
        r * 0.45,
        5,
        rotation: -math.pi / 2 + k * 0.2,
      );
      if (scene.neon) {
        Ornaments.neon(canvas, p, m.neonA, 1.1);
      } else {
        Ornaments.inked(canvas, p, won ? fill : m.bulbOff, m.ink, 1.4);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StarsPainter old) => false;
}

/// A cinema ticket stub: notched ends, a perforated tear line, the score
/// and the stamp.
class _Ticket extends StatelessWidget {
  const _Ticket({
    required this.scene,
    required this.paper,
    required this.admit,
    required this.scoreLabel,
    required this.score,
    required this.best,
    required this.time,
    required this.stamp,
    required this.stampT,
  });

  final OverlayScene scene;
  final ui.FragmentShader? paper;
  final String admit;
  final String scoreLabel;
  final String score;
  final String? best;
  final String? time;
  final String? stamp;
  final double stampT;

  @override
  Widget build(BuildContext context) {
    final s = scene;
    final ink = s.neon ? s.materials.neonB : s.materials.ink;
    final muted = ink.withValues(alpha: 0.7);
    return CustomPaint(
      painter: _TicketPainter(s, paper),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(26, 12, 26, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  admit,
                  style: s.body(12, color: muted, weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(scoreLabel, style: s.body(14, color: muted)),
                Text(score, style: hudTextStyle(s.skin, 46, ink, glow: s.neon)),
                if (best != null) Text(best!, style: s.body(14, color: ink)),
                if (time != null) Text(time!, style: s.body(12.5, color: muted)),
              ],
            ),
          ),
          if (stamp != null && stampT > 0)
            PositionedDirectional(
              top: -16,
              end: -30,
              child: Transform.rotate(
                angle: -0.22,
                child: Transform.scale(
                  scale: 2.2 - 1.2 * Curves.easeIn.transform(stampT),
                  child: Opacity(
                    opacity: stampT,
                    child: _Stamp(scene: s, text: stamp!),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Stamp extends StatelessWidget {
  const _Stamp({required this.scene, required this.text});

  final OverlayScene scene;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = scene.neon
        ? scene.materials.neonA
        : (scene.skin.era.isMonochrome ? scene.materials.ink : scene.skin.palette.accent);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.85), width: 2.4),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: scene.title(15, color: color.withValues(alpha: 0.9))),
    );
  }
}

class _TicketPainter extends CustomPainter {
  _TicketPainter(this.scene, this.paper);

  final OverlayScene scene;
  final ui.FragmentShader? paper;
  final Paint _p = Paint();
  final Paint _s = Paint()..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final m = scene.materials;
    final pal = scene.skin.palette;
    final r = Offset.zero & size;
    // Ticket outline: notches halfway down both ends.
    final notch = 9.0;
    final path = Path()
      ..moveTo(r.left + 6, r.top)
      ..lineTo(r.right - 6, r.top)
      ..quadraticBezierTo(r.right, r.top, r.right, r.top + 6)
      ..lineTo(r.right, r.center.dy - notch)
      ..arcToPoint(Offset(r.right, r.center.dy + notch), radius: Radius.circular(notch), clockwise: false)
      ..lineTo(r.right, r.bottom - 6)
      ..quadraticBezierTo(r.right, r.bottom, r.right - 6, r.bottom)
      ..lineTo(r.left + 6, r.bottom)
      ..quadraticBezierTo(r.left, r.bottom, r.left, r.bottom - 6)
      ..lineTo(r.left, r.center.dy + notch)
      ..arcToPoint(Offset(r.left, r.center.dy - notch), radius: Radius.circular(notch), clockwise: false)
      ..lineTo(r.left, r.top + 6)
      ..quadraticBezierTo(r.left, r.top, r.left + 6, r.top)
      ..close();
    final ticketColor = switch (scene.skin.titles.frame) {
      TitleFrame.plain => m.paper,
      TitleFrame.osd => m.wall,
      _ => scene.skin.era.isMonochrome ? pal.highlight : Color.lerp(pal.paper, pal.accent, 0.12)!,
    };
    if (!scene.neon) {
      _p.color = pal.ink.withValues(alpha: 0.5);
      canvas.drawPath(path.shift(const Offset(0, 3)), _p);
    }
    final shader = paper;
    if (shader != null && !scene.neon) {
      PaperUniforms.write(shader, rect: r, paper: ticketColor, stain: pal.shadow, age: 0.4, seed: 23, vignette: 0.4);
      _p
        ..shader = shader
        ..color = const Color(0xFFFFFFFF);
    } else {
      _p
        ..shader = null
        ..color = ticketColor;
    }
    canvas.drawPath(path, _p);
    _p.shader = null;
    final ink = scene.neon ? m.neonB : pal.ink;
    _s
      ..color = ink
      ..strokeWidth = 2;
    canvas.drawPath(path, _s);
    // Perforation lines near both ends.
    _p.color = ink.withValues(alpha: 0.55);
    for (final x in [r.left + 14.0, r.right - 14.0]) {
      for (var y = r.top + 6; y < r.bottom - 4; y += 7) {
        if ((y - r.center.dy).abs() < notch + 2) continue;
        canvas.drawCircle(Offset(x, y), 1.3, _p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TicketPainter old) => false;
}
