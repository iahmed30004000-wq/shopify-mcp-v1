import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter/painting.dart' show EdgeInsets;

import '../core/cinema_env.dart';
import '../core/cinema_shaders.dart';
import '../core/era.dart';
import '../core/era_skin.dart';
import '../core/film_clock.dart';
import '../core/shader_uniforms.dart';
import '../core/stage.dart';
import 'bulb_atlas.dart';
import 'curtain_motion.dart';
import 'proscenium.dart';
import 'stage_layout.dart';
import 'stage_materials.dart';
import 'stage_ornaments.dart';

/// Ticks once per game-loop update (also while paused), so Flutter overlays
/// (the projector booth, the results marquee) can repaint on the game's own
/// clock instead of running a second ticker: `CustomPaint(repaint: beat)`.
class StageBeat extends ChangeNotifier {
  FilmClock? _clock;

  /// The game's film clock (null until the first update).
  FilmClock? get clock => _clock;

  void tick(FilmClock clock) {
    _clock = clock;
    notifyListeners();
  }
}

/// The Film Reel Engine's theatre: velvet house curtains that open with
/// physics (a hauled rope, a lagging spring edge, a swinging hem, a tie-back
/// that gathers the drape), a festoon valance with gold fringe, the era's
/// proscenium arch with marquee bulbs, a footlight lip and a follow-spot.
///
/// Draw calls per frame: 3 curtain shader draws, 1 spotlight draw, one
/// cached proscenium picture, 2 atlas draws for every bulb and halo, plus a
/// few small paths (tie-backs, neon). Nothing is allocated per frame.
class ReelStage implements StageFrame {
  ReelStage(this.env)
    : materials = StageMaterials.of(env.skin),
      _proscenium = ProsceniumPainter(skin: env.skin, materials: StageMaterials.of(env.skin), reducedMotion: env.reducedMotion);

  final CinemaEnv env;
  final StageMaterials materials;
  final ProsceniumPainter _proscenium;
  final CurtainMotion motion = CurtainMotion();

  /// Repaint signal for Flutter overlays (see [StageBeat]).
  final StageBeat beat = StageBeat();

  EraSkin get skin => env.skin;
  StageStyle get style => skin.stage;

  StageLayout? _layout;

  /// The current measurements (null before the first [layout]).
  StageLayout? get measurements => _layout;

  FilmClock? _clock;
  double _pulse = 0;
  Offset? _spotTarget;
  Offset _spot = Offset.zero;
  double _spotAlpha = 0;

  final ShaderPool _curtains = ShaderPool(CinemaShader.curtain, maxInstances: 4);
  final ShaderPool _spots = ShaderPool(CinemaShader.spotlight, maxInstances: 1);
  final BulbAtlas _atlas = BulbAtlas(capacity: 160);
  final Paint _paint = Paint();
  final Path _fallback = Path();
  final Path _rope = Path();
  final Path _tassel = Path();
  Shader? _backShader;
  Shader? _washShader;

  @override
  Rect get playRect => _layout?.play ?? Rect.zero;

  @override
  Rect get hudRect => _layout?.hud ?? Rect.zero;

  @override
  double get curtainOpen => motion.openClamped;

  @override
  void layout(Size screen, EdgeInsets safe) {
    if (screen.isEmpty) return;
    final l = _layout = StageLayout.compute(screen, safe, style);
    _proscenium.layout(l);
    final pal = skin.palette;
    _backShader = Gradient.linear(Offset.zero, Offset(0, screen.height), [
      Color.lerp(pal.curtainShade, pal.ink, 0.35)!,
      Color.lerp(pal.curtainShade, pal.ink, 0.75)!,
    ]);
    _washShader = Gradient.linear(Offset(0, l.footTop), Offset(0, l.footTop - screen.height * 0.24), [
      pal.footlight.withValues(alpha: 0.26),
      pal.footlight.withValues(alpha: 0),
    ]);
    if (_spot == Offset.zero) _spot = l.play.center;
  }

  @override
  Future<void> openCurtains({Duration? duration}) => motion.haul(1, duration ?? const Duration(milliseconds: 1500));

  @override
  Future<void> closeCurtains({Duration? duration}) => motion.haul(0, duration ?? const Duration(milliseconds: 1250));

  @override
  void spotlight(Offset? target) {
    if (!style.spotlight) return;
    if (target != null && _spotTarget == null && _spotAlpha < 0.05) _spot = target;
    _spotTarget = target;
  }

  @override
  void pulse(double amount) => _pulse = math.max(_pulse, amount.clamp(0.0, 1.0));

  @override
  void update(double dt, FilmClock clock) {
    _clock = clock;
    motion.update(dt);
    _pulse *= math.exp(-dt * 3.5);
    final target = _spotTarget;
    if (target != null) {
      // A follow-spot operator lags a little behind the action.
      final k = 1 - math.exp(-dt * 7);
      _spot = Offset.lerp(_spot, target, k)!;
      _spotAlpha = math.min(1, _spotAlpha + dt * 3);
    } else {
      _spotAlpha = math.max(0, _spotAlpha - dt * 2.5);
    }
    beat.tick(clock);
  }

  @override
  void paintBack(Canvas canvas) {
    final l = _layout;
    if (l == null) return;
    _paint
      ..shader = _backShader
      ..color = const Color(0xFFFFFFFF);
    canvas.drawRect(Offset.zero & l.screen, _paint);
    _paint.shader = null;
  }

  @override
  void paintFront(Canvas canvas) {
    final l = _layout;
    final clock = _clock;
    if (l == null || clock == null) return;
    final w = l.width;
    // Footlight wash on the stage floor.
    _paint
      ..shader = _washShader
      ..color = Color.fromRGBO(255, 255, 255, (0.7 + 0.3 * _pulse).clamp(0.0, 1.0));
    canvas.drawRect(Rect.fromLTRB(l.play.left, l.footTop - l.height * 0.24, l.play.right, l.footTop), _paint);
    _paint.shader = null;
    _paintSpot(canvas, l, clock);

    // House curtains.
    final open = motion.open;
    final panel = l.curtainClosedWidth + (l.curtainOpenWidth - l.curtainClosedWidth) * open;
    final g = motion.gather;
    final lag = math.tan(motion.swing) * 0.3 * (1 - 0.75 * g);
    final maxShift = l.pil * 0.85 / (l.curtainBottom - l.curtainTop);
    final skew = lag.clamp(-maxShift, maxShift);
    final folds = math.max(3, style.curtainFolds);
    _panel(canvas, clock, l, Rect.fromLTRB(0, l.curtainTop, panel, l.curtainBottom), CurtainPanel.left, folds, g, skew);
    _panel(canvas, clock, l, Rect.fromLTRB(w - panel, l.curtainTop, w, l.curtainBottom), CurtainPanel.right, folds, g, -skew);

    // Festoon valance.
    final swags = math.max(3, (w / 86).round());
    final vr = Rect.fromLTRB(0, l.hdr - l.valDepth * 0.3, w, l.hdr + l.valDepth);
    _shade(canvas, clock, vr, CurtainPanel.valance, swags, 0, 0);

    // Proscenium, bulbs, footlights.
    _proscenium.paintStatic(canvas);
    _proscenium.paintLive(canvas, clock, _atlas, pulse: _pulse);
  }

  void _paintSpot(Canvas canvas, StageLayout l, FilmClock clock) {
    if (_spotAlpha <= 0.01) return;
    final s = _spots.next(clock);
    if (s == null) return;
    SpotlightUniforms.write(
      s,
      rect: l.play,
      source: Offset(l.width * 0.5, -l.height * 0.12),
      target: _spot,
      color: skin.palette.footlight,
      time: clock.time,
      intensity: 0.75 * _spotAlpha,
      poolRadius: l.width * 0.2,
      motes: env.reducedMotion ? 0 : 0.6,
    );
    _paint
      ..shader = s
      ..color = const Color(0xFFFFFFFF)
      ..blendMode = BlendMode.plus;
    canvas.drawRect(l.play, _paint);
    _paint
      ..shader = null
      ..blendMode = BlendMode.srcOver;
  }

  void _panel(Canvas canvas, FilmClock clock, StageLayout l, Rect rect, CurtainPanel side, int folds, double g, double skew) {
    canvas.save();
    if (skew != 0) {
      // The hem swings about the curtain rod (the outer edge stays behind
      // the pilaster: the skew is capped by the stage).
      final pivotX = side == CurtainPanel.left ? rect.left : rect.right;
      canvas
        ..translate(pivotX, rect.top)
        ..skew(skew, 0)
        ..translate(-pivotX, -rect.top);
    }
    _shade(canvas, clock, rect, side, folds, g, motion.ripplePhase);
    if (g > 0.04) _tieBack(canvas, l, rect, side, g);
    canvas.restore();
  }

  void _shade(Canvas canvas, FilmClock clock, Rect rect, CurtainPanel side, int folds, double g, double phase) {
    final s = _curtains.next(clock);
    if (s != null) {
      CurtainUniforms.write(
        s,
        rect: rect,
        palette: skin.palette,
        panel: side,
        clock: clock,
        folds: folds,
        swayPhase: phase,
        gather: g,
        sheen: switch (skin.era) {
          Era.noir => 0.95,
          Era.silent || Era.rubberHose => 0.6,
          _ => 0.62,
        },
        footlight: 0.42 + 0.45 * _pulse,
      );
      _paint
        ..shader = s
        ..color = const Color(0xFFFFFFFF);
      canvas.drawRect(rect, _paint);
      _paint.shader = null;
      return;
    }
    // Plain-canvas fallback: a flat velvet silhouette.
    _paint.color = skin.palette.curtain;
    if (side == CurtainPanel.valance) {
      canvas.drawRect(Rect.fromLTRB(rect.left, rect.top, rect.right, rect.top + rect.height * 0.75), _paint);
      return;
    }
    _fallback.reset();
    final left = side == CurtainPanel.left;
    double edgeAt(double y) {
      const tie = StageLayout.tieY;
      final pull = y < tie ? 0.54 * math.pow(y / tie, 1.6) : 0.54 - 0.3 * math.sin((y - tie) / (1 - tie) * math.pi / 2);
      return rect.width * (1 - g * pull);
    }

    final outer = left ? rect.left : rect.right;
    _fallback.moveTo(outer, rect.top);
    for (var i = 0; i <= 12; i++) {
      final y = i / 12;
      final e = edgeAt(y);
      _fallback.lineTo(left ? rect.left + e : rect.right - e, rect.top + rect.height * y);
    }
    _fallback
      ..lineTo(outer, rect.bottom)
      ..close();
    canvas.drawPath(_fallback, _paint);
  }

  /// The gilt rope and tassel that hold a gathered curtain.
  void _tieBack(Canvas canvas, StageLayout l, Rect rect, CurtainPanel side, double g) {
    final m = materials;
    final u = l.width / 412;
    final left = side == CurtainPanel.left;
    final y = rect.top + rect.height * StageLayout.tieY;
    final edge = rect.width * (1 - g * 0.54);
    final xe = left ? rect.left + edge : rect.right - edge;
    final xo = left ? rect.left + l.pil * 0.6 : rect.right - l.pil * 0.6;
    final dir = left ? 1.0 : -1.0;
    // Rope band round the drape.
    _rope
      ..reset()
      ..moveTo(xo, y - 2 * u)
      ..quadraticBezierTo((xo + xe) / 2, y + 5 * u, xe + dir * 2 * u, y - 1 * u);
    final a = ((g - 0.04) / 0.4).clamp(0.0, 1.0);
    Ornaments.line(canvas, _rope, m.ink.withValues(alpha: a), 5.4 * u);
    Ornaments.line(canvas, _rope, m.gilt.withValues(alpha: a), 3 * u);
    Ornaments.line(canvas, _rope, m.giltLight.withValues(alpha: 0.7 * a), 1 * u);
    // Tassel: knot, cap, skirt of threads.
    final k = Offset(xe + dir * 1.5 * u, y + 1 * u);
    final len = 18 * u * (0.6 + 0.4 * g);
    _tassel
      ..reset()
      ..addOval(Rect.fromCircle(center: k, radius: 3.2 * u))
      ..moveTo(k.dx - 2.4 * u, k.dy + 3 * u)
      ..quadraticBezierTo(k.dx - 6 * u, k.dy + len * 0.75, k.dx - 5 * u, k.dy + len)
      ..lineTo(k.dx + 5 * u, k.dy + len)
      ..quadraticBezierTo(k.dx + 6 * u, k.dy + len * 0.75, k.dx + 2.4 * u, k.dy + 3 * u)
      ..close();
    Ornaments.inked(canvas, _tassel, m.gilt.withValues(alpha: a), m.ink.withValues(alpha: a), 1.1 * u);
    _rope
      ..reset()
      ..moveTo(k.dx - 3 * u, k.dy + len * 0.45)
      ..lineTo(k.dx + 3 * u, k.dy + len * 0.45);
    for (var i = -2; i <= 2; i++) {
      _rope
        ..moveTo(k.dx + i * 1.6 * u, k.dy + len * 0.55)
        ..lineTo(k.dx + i * 1.9 * u, k.dy + len - 1 * u);
    }
    Ornaments.line(canvas, _rope, m.giltDark.withValues(alpha: a), 0.9 * u);
  }

  @override
  void dispose() {
    motion.cancel();
    _curtains.dispose();
    _spots.dispose();
    _atlas.dispose();
    _proscenium.dispose();
    beat.dispose();
  }
}
