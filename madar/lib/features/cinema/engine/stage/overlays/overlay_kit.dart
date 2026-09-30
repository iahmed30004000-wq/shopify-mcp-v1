import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/audio.dart';
import '../../core/cinema_game.dart';
import '../../core/cinema_shaders.dart';
import '../../core/era_skin.dart';
import '../../core/film_clock.dart';
import '../../core/shader_uniforms.dart';
import '../../core/stage.dart';
import '../hud/hud_paint.dart';
import '../reel_stage.dart';
import '../stage_materials.dart';

/// What a Flutter overlay needs from its game: skin, materials, a HUD
/// context for the era's plaques, and a repaint signal on game time (the
/// [ReelStage]'s beat – no second ticker; static when the stage is a fake).
class OverlayScene {
  OverlayScene(this.game)
    : skin = game.skin,
      materials = StageMaterials.of(game.skin),
      beat = game.stage is ReelStage ? (game.stage as ReelStage).beat : null {
    hud = HudContext(skin: skin, clock: game.clock, model: game.hud, direction: game.env.direction);
  }

  final CinemaGame game;
  final EraSkin skin;
  final StageMaterials materials;
  final StageBeat? beat;
  late final HudContext hud;

  FilmClock get clock => game.clock;
  TitleFrame get frame => skin.titles.frame;
  bool get neon => frame == TitleFrame.osd;
  bool get dark => frame == TitleFrame.plain || frame == TitleFrame.osd;

  /// Ink colour of text on this era's cards.
  Color get text => switch (frame) {
    TitleFrame.plain => materials.paper,
    TitleFrame.osd => materials.neonB,
    _ => materials.ink,
  };

  Listenable get repaint => beat ?? const _Never();

  TextStyle title(double size, {Color? color}) => hudTextStyle(skin, size, color ?? text, glow: neon);

  TextStyle body(double size, {Color? color, FontWeight weight = FontWeight.w500}) => TextStyle(
    fontFamily: skin.titles.fontFamily == 'Amiri' ? 'Amiri' : 'PlexArabic',
    fontSize: size,
    fontWeight: weight,
    height: 1.35,
    color: color ?? text.withValues(alpha: 0.82),
  );
}

class _Never implements Listenable {
  const _Never();
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
}

/// Seconds since [start] on the game's film clock (entrance animations of
/// overlays run on game time).
class OverlayTimer {
  OverlayTimer(this.scene);

  final OverlayScene scene;
  double? _t0;

  double get elapsed {
    final now = scene.clock.time;
    final t0 = _t0 ??= now;
    return scene.beat == null ? 10 : now - t0;
  }
}

/// A card background in the era's material: aged paper (paper.frag) with an
/// inked double border for the paper eras, lacquer for noir, a dark glass
/// panel with neon for the 80s.
class CardBackgroundPainter extends CustomPainter {
  CardBackgroundPainter(this.scene, this.paper, {this.seed = 5, super.repaint});

  final OverlayScene scene;
  final ui.FragmentShader? paper;
  final double seed;
  final Paint _p = Paint();
  final Paint _s = Paint()..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final m = scene.materials;
    final pal = scene.skin.palette;
    final rr = RRect.fromRectAndRadius(r, Radius.circular(scene.frame == TitleFrame.artDeco ? 18 : 6));
    if (!scene.neon) {
      _p.color = pal.ink.withValues(alpha: 0.85);
      canvas.drawRRect(rr.shift(const Offset(0, 6)), _p);
    }
    if (scene.dark) {
      _p
        ..shader = ui.Gradient.linear(r.topCenter, r.bottomCenter, [m.wallLight, m.wall, m.wallDark], const [0, 0.4, 1])
        ..color = const Color(0xFFFFFFFF);
      canvas.drawRRect(rr, _p);
      _p.shader = null;
    } else {
      final shader = paper;
      if (shader != null) {
        PaperUniforms.write(shader, rect: r, paper: m.paper, stain: pal.shadow, age: 0.55, seed: seed, vignette: 0.6);
        _p
          ..shader = shader
          ..color = const Color(0xFFFFFFFF);
      } else {
        _p
          ..shader = null
          ..color = m.paper;
      }
      canvas
        ..save()
        ..clipRRect(rr)
        ..drawRect(r, _p)
        ..restore();
      _p.shader = null;
    }
    if (scene.neon) {
      for (final (w, a) in const [(9.0, 0.12), (4.5, 0.3), (1.8, 1.0)]) {
        _s
          ..strokeWidth = w
          ..color = m.neonA.withValues(alpha: a);
        canvas.drawRRect(rr.deflate(3), _s);
      }
      return;
    }
    _s
      ..color = scene.dark ? m.gilt : m.ink
      ..strokeWidth = 3;
    canvas.drawRRect(rr, _s);
    _s.strokeWidth = 1.2;
    canvas.drawRRect(rr.deflate(7), _s);
  }

  @override
  bool shouldRepaint(covariant CardBackgroundPainter old) => old.scene != scene;
}

/// A menu button on the era's plaque (real button semantics, game sound and
/// haptic). [primary] gets marquee bulbs round it.
class StageButton extends StatefulWidget {
  const StageButton({super.key, required this.scene, required this.label, required this.onPressed, this.primary = false, this.icon});

  final OverlayScene scene;
  final String label;
  final VoidCallback onPressed;
  final bool primary;
  final IconData? icon;

  @override
  State<StageButton> createState() => _StageButtonState();
}

class _StageButtonState extends State<StageButton> {
  bool _down = false;

  void _tap() {
    widget.scene.game.feedback(CinemaSound.tap);
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final scene = widget.scene;
    final h = widget.primary ? 58.0 : 50.0;
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      onTap: _tap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: _tap,
        child: AnimatedScale(
          scale: _down ? 0.94 : 1,
          duration: const Duration(milliseconds: 90),
          child: SizedBox(
            height: h,
            child: CustomPaint(
              painter: _ButtonPainter(scene, primary: widget.primary, down: _down),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, size: widget.primary ? 24 : 20, color: _textColor(scene)),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(widget.label, maxLines: 1, style: scene.title(widget.primary ? 21 : 17, color: _textColor(scene))),
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
    );
  }

  Color _textColor(OverlayScene s) => widget.primary && s.frame == TitleFrame.plain ? s.materials.ink : s.text;
}

class _ButtonPainter extends CustomPainter {
  _ButtonPainter(this.scene, {required this.primary, required this.down}) : super(repaint: primary ? scene.repaint : null);

  final OverlayScene scene;
  final bool primary;
  final bool down;
  final HudPlaque _plaque = HudPlaque();
  final Paint _p = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final r = (Offset.zero & size).deflate(2);
    final m = scene.materials;
    final ctx = scene.hud;
    final saved = ctx.scale;
    ctx.scale = 1.2;
    if (primary && scene.frame == TitleFrame.plain) {
      // Noir: the lit button is a pale card in the dark.
      final rr = RRect.fromRectAndRadius(r, const Radius.circular(4));
      _p.color = m.paper;
      canvas.drawRRect(rr, _p);
    } else {
      _plaque.paint(canvas, r, ctx, flash: down ? 0.4 : 0);
    }
    ctx.scale = saved;
    if (!primary) return;
    // Chasing bulbs along the top and bottom edges.
    final t = scene.beat == null ? 0.0 : scene.clock.time;
    final n = math.max(4, (r.width / 22).floor());
    for (var i = 0; i < n; i++) {
      final x = r.left + 12 + (r.width - 24) * i / (n - 1);
      for (final y in [r.top - 1.0, r.bottom + 1.0]) {
        final lit = ((i + (t * 6).floor()) % 3 == 0) ? 1.0 : 0.35;
        _p.color = Color.lerp(m.bulbOff, m.bulb, lit)!;
        canvas.drawCircle(Offset(x, y), 3.2, _p);
        if (lit > 0.5) {
          _p.color = m.glow.withValues(alpha: 0.35);
          canvas.drawCircle(Offset(x, y), 7, _p);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ButtonPainter old) => old.down != down || old.primary != primary;
}

/// One paper shader per overlay (null when the program failed: plain fill).
ui.FragmentShader? overlayPaperShader() {
  try {
    return CinemaShaders.program(CinemaShader.paper)?.fragmentShader();
  } catch (e) {
    if (kDebugMode) debugPrint('overlay paper shader: $e');
    return null;
  }
}
