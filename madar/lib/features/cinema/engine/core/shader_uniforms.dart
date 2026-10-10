import 'dart:ui' as ui;

import 'cinema_shaders.dart';
import 'era_skin.dart';
import 'film_clock.dart';
import 'film_fx.dart';

// The uniform CONTRACT of every cinema shader, as Dart writers.
//
// Each writer sets the float uniforms in exactly the order the .frag
// declares them (and documents in its header). The FX / stage agents write
// the GLSL bodies against these layouts; everyone else only ever calls these
// writers, never setFloat directly. Changing a layout = changing the shader
// header + this file + CinemaShader.floats together (architect sign-off, see
// ENGINE.md). test/features/cinema/shaders/ verifies the float counts against
// the compiled programs.
//
// Colours are written straight (non-premultiplied) sRGB 0..1; shaders
// output premultiplied. Positions and sizes are in the LOCAL coordinates of
// the canvas the shader is drawn on (FlutterFragCoord), unless noted.

/// Sequential writer shared by all uniform writers (UI isolate only; no
/// allocation per write).
final class UniformCursor {
  UniformCursor._();

  static final UniformCursor _shared = UniformCursor._();

  ui.FragmentShader? _shader;
  int _i = 0;

  static UniformCursor start(ui.FragmentShader shader) => _shared
    .._shader = shader
    .._i = 0;

  int get written => _i;

  void f(double v) => _shader!.setFloat(_i++, v);

  void v4(double x, double y, double z, double w) {
    f(x);
    f(y);
    f(z);
    f(w);
  }

  void rect(ui.Rect r) => v4(r.left, r.top, r.width, r.height);

  /// Straight rgba; [alpha] overrides the colour's own alpha.
  void color(ui.Color c, {double? alpha}) => v4(c.r, c.g, c.b, alpha ?? c.a);

  void end(CinemaShader shader) {
    assert(_i == shader.floats, '${shader.file}: wrote $_i floats, contract says ${shader.floats}');
    _shader = null;
  }
}

/// film_grade.frag – see its header. [grade] should already be scaled by
/// the frame's intensity (FilmGrade.scaled); [frame] is bound to sampler 0.
abstract final class FilmGradeUniforms {
  static const shader = CinemaShader.filmGrade;

  static void write(
    ui.FragmentShader s, {
    required ui.Rect rect,
    required ui.Image image,
    required FilmClock clock,
    required EraPalette palette,
    required FilmGrade grade,
    required FilmFrame frame,
  }) {
    final u = UniformCursor.start(s)
      ..rect(rect)
      ..v4(clock.time, clock.filmFrame.toDouble(), clock.boilFrame.toDouble(), clock.seed)
      ..color(palette.ink, alpha: 1)
      ..color(palette.paper, alpha: 1)
      ..color(grade.tint, alpha: grade.tintStrength)
      ..v4(grade.saturation, grade.contrast, grade.brightness, grade.posterize)
      ..v4(grade.grain, grade.grainSize, frame.reduceFlicker ? 0 : grade.flicker, grade.vignette)
      ..v4(grade.gateWeave, grade.dust, grade.scratches, grade.halation)
      ..v4(frame.safeFlash, frame.shake, frame.fade, frame.reduceFlicker ? frame.damage * 0.5 : frame.damage);
    u.end(shader);
    s.setImageSampler(0, image);
  }
}

/// vhs.frag – see its header.
abstract final class VhsUniforms {
  static const shader = CinemaShader.vhs;

  static void write(
    ui.FragmentShader s, {
    required ui.Rect rect,
    required ui.Image image,
    required FilmClock clock,
    required FilmGrade grade,
    required FilmFrame frame,
  }) {
    final u = UniformCursor.start(s)
      ..rect(rect)
      ..v4(clock.time, clock.filmFrame.toDouble(), clock.boilFrame.toDouble(), clock.seed)
      ..color(grade.tint, alpha: grade.tintStrength)
      ..v4(grade.saturation, grade.contrast, grade.brightness, grade.chromaBleed)
      ..v4(grade.scanlines, grade.chromaShift, grade.tracking, grade.tapeWobble)
      ..v4(frame.safeFlash, frame.shake, frame.fade, frame.reduceFlicker ? frame.damage * 0.5 : frame.damage);
    u.end(shader);
    s.setImageSampler(0, image);
  }
}

/// halftone.frag – dots from [toneFrom] at [from] to [toneTo] at [to]
/// (radial: around [from], radius |to − from|). [pixelScale] = logical px
/// per local unit of the canvas (the camera zoom inside the world) so the
/// dot pitch stays constant on screen.
abstract final class HalftoneUniforms {
  static const shader = CinemaShader.halftone;

  static void write(
    ui.FragmentShader s, {
    required ui.Offset from,
    required ui.Offset to,
    required ui.Color ink,
    required HalftoneStyle style,
    bool radial = false,
    double toneFrom = 0,
    double toneTo = 1,
    int boilFrame = 0,
    double pixelScale = 1,
  }) {
    final k = pixelScale <= 0 ? 1.0 : pixelScale;
    final u = UniformCursor.start(s)
      ..v4(from.dx, from.dy, to.dx, to.dy)
      ..v4(radial ? 1 : 0, toneFrom * style.strength, toneTo * style.strength, boilFrame.toDouble())
      ..color(ink)
      ..v4(style.cellSize / k, style.angle, style.shape.index.toDouble(), style.softness / k);
    u.end(shader);
  }
}

/// crosshatch.frag – same ramp semantics as [HalftoneUniforms].
abstract final class CrosshatchUniforms {
  static const shader = CinemaShader.crosshatch;

  static void write(
    ui.FragmentShader s, {
    required ui.Offset from,
    required ui.Offset to,
    required ui.Color ink,
    required CrosshatchStyle style,
    bool radial = false,
    double toneFrom = 0,
    double toneTo = 1,
    int boilFrame = 0,
    double pixelScale = 1,
  }) {
    final k = pixelScale <= 0 ? 1.0 : pixelScale;
    final u = UniformCursor.start(s)
      ..v4(from.dx, from.dy, to.dx, to.dy)
      ..v4(radial ? 1 : 0, toneFrom * style.strength, toneTo * style.strength, boilFrame.toDouble())
      ..color(ink)
      ..v4(style.spacing / k, style.angle, style.lineWidth / k, style.wobble / k);
    u.end(shader);
  }
}

/// ink_line.frag – textured ink for strokes / ink fills.
abstract final class InkLineUniforms {
  static const shader = CinemaShader.inkLine;

  static void write(
    ui.FragmentShader s, {
    required ui.Color ink,
    required double dryness,
    double grainScale = 1.2,
    int boilFrame = 0,
    double seed = 0,
  }) {
    final u = UniformCursor.start(s)
      ..color(ink)
      ..v4(grainScale, dryness, boilFrame.toDouble(), seed);
    u.end(shader);
  }
}

/// paper.frag – aged card stock.
abstract final class PaperUniforms {
  static const shader = CinemaShader.paper;

  static void write(
    ui.FragmentShader s, {
    required ui.Rect rect,
    required ui.Color paper,
    required ui.Color stain,
    double opacity = 1,
    double stainAmount = 0.4,
    double fibreScale = 1.5,
    double age = 0.5,
    double seed = 0,
    double vignette = 0.5,
  }) {
    final u = UniformCursor.start(s)
      ..rect(rect)
      ..color(paper, alpha: opacity)
      ..color(stain, alpha: stainAmount)
      ..v4(fibreScale, age, seed, vignette);
    u.end(shader);
  }
}

/// iris.frag – mask outside an opening of [radius] around [centre].
abstract final class IrisUniforms {
  static const shader = CinemaShader.iris;

  static void write(
    ui.FragmentShader s, {
    required ui.Rect rect,
    required ui.Offset centre,
    required double radius,
    required ui.Color color,
    IrisShape shape = IrisShape.circle,
    double softness = 1.5,
    double wobble = 2,
    int boilFrame = 0,
    double rim = 0.4,
  }) {
    final u = UniformCursor.start(s)
      ..rect(rect)
      ..v4(centre.dx, centre.dy, radius, softness)
      ..color(color)
      ..v4(shape.index.toDouble(), wobble, boilFrame.toDouble(), rim);
    u.end(shader);
  }
}

/// burn.frag – the film melting in the gate.
abstract final class BurnUniforms {
  static const shader = CinemaShader.burn;

  static void write(
    ui.FragmentShader s, {
    required ui.Rect rect,
    required double progress,
    required ui.Offset origin,
    required ui.Color edgeColor,
    required ui.Color holeColor,
    double edgeWidth = 10,
    double seed = 0,
  }) {
    final u = UniformCursor.start(s)
      ..rect(rect)
      ..v4(progress, origin.dx, origin.dy, seed)
      ..color(edgeColor, alpha: edgeWidth)
      ..color(holeColor);
    u.end(shader);
  }
}

/// Which curtain panel curtain.frag paints.
enum CurtainPanel { left, right, valance }

/// curtain.frag – velvet panels and valance (stage agent's shader).
abstract final class CurtainUniforms {
  static const shader = CinemaShader.curtain;

  static void write(
    ui.FragmentShader s, {
    required ui.Rect rect,
    required EraPalette palette,
    required CurtainPanel panel,
    required FilmClock clock,
    int folds = 7,
    double swayPhase = 0,
    double gather = 0,
    double sheen = 0.5,
    double footlight = 0.6,
    double opacity = 1,
  }) {
    final side = switch (panel) {
      CurtainPanel.left => -1.0,
      CurtainPanel.right => 1.0,
      CurtainPanel.valance => 0.0,
    };
    final u = UniformCursor.start(s)
      ..rect(rect)
      ..color(palette.curtain, alpha: opacity)
      ..color(palette.curtainShade, alpha: sheen)
      ..v4(folds.toDouble(), swayPhase, gather, side)
      ..color(palette.footlight, alpha: footlight)
      ..v4(clock.time, clock.boilFrame.toDouble(), clock.seed, 0);
    u.end(shader);
  }
}

/// spotlight.frag – additive follow-spot (draw with BlendMode.plus/screen).
abstract final class SpotlightUniforms {
  static const shader = CinemaShader.spotlight;

  static void write(
    ui.FragmentShader s, {
    required ui.Rect rect,
    required ui.Offset source,
    required ui.Offset target,
    required ui.Color color,
    required double time,
    double intensity = 0.8,
    double poolRadius = 90,
    double softness = 0.35,
    double motes = 0.5,
  }) {
    final u = UniformCursor.start(s)
      ..rect(rect)
      ..v4(source.dx, source.dy, target.dx, target.dy)
      ..color(color, alpha: intensity)
      ..v4(poolRadius, softness, motes, time);
    u.end(shader);
  }
}
