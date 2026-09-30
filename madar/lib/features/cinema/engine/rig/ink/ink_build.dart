import 'dart:math' as math;
import 'dart:ui';

import '../../core/era_skin.dart';
import '../../core/rig.dart';
import 'boil.dart';
import 'contour.dart';
import 'ink_colors.dart';
import 'ink_list.dart';
import 'ink_pen.dart';

/// Direction toward the shadow side (light comes from the upper left, the
/// way 1930s layouts lit their characters).
const double kShadowX = 0.5547, kShadowY = 0.8321;

/// Everything a drawing needs while it is (re)built: the pen, the retained
/// list, scratch contours, the era's colours and ink metrics, and the boil
/// jitter for this drawing. One per rig / prop; reused every drawing.
final class InkBuild {
  InkBuild({required this.seed, int contours = 4, int contourCapacity = 96})
    : _contours = [for (var i = 0; i < contours; i++) Contour(contourCapacity)];

  final int seed;
  final InkPen pen = InkPen();
  final InkList list = InkList();
  final InkColors colors = InkColors();
  final List<Contour> _contours;

  /// Outline width (local units) for this drawing.
  double lw = 3;

  /// Boil amplitude (local units).
  double amp = 1;

  /// Boil drawing index.
  int frame = 0;

  /// Local units → logical px (camera zoom × any extra scale).
  double pixelScale = 1;

  /// Animation time of the drawing (seconds).
  double time = 0;

  late EraSkin skin;

  Contour contour(int i) => _contours[i];

  /// Starts a drawing. [size] is the drawing's nominal height in local
  /// units (100 = a standard character): the era's line width and boil are
  /// specified for that size and scale gently (√) with it, so big bosses get
  /// bolder lines and small props finer ones, as an inker would.
  void begin(RigPaintContext ctx, {required double size, double lineScale = 1, bool inkTexture = true}) {
    skin = ctx.skin;
    colors.update(skin);
    final ink = skin.ink;
    final k = math.sqrt((size / 100).clamp(0.12, 6.0));
    lw = ink.lineWidth * k * lineScale;
    amp = ink.boilAmplitude * k;
    frame = ink.boilFps > 0 ? ctx.clock.boilFrame : 0;
    pixelScale = ctx.pixelScale;
    final off = lw * (0.12 + ink.taper * 0.42);
    pen.reset();
    list.begin(
      ink: colors.ink,
      glow: colors.glow,
      cel: colors.cel,
      neon: colors.neon,
      offsetX: kShadowX * off,
      offsetY: kShadowY * off,
      glowWidth: colors.neon ? math.max(ink.glow * k, lw * 1.5) : 0,
      shading: ink.shading,
    );
    list.setInkTexture(skin, boilFrame: frame, seed: (seed % 97).toDouble(), enabled: inkTexture);
  }

  /// Sets the shading ramp across the drawing's local [box] (light at the
  /// top-left, dense at the bottom-right).
  void shadeAcross(Rect box, {double toneFrom = 0.45, double toneTo = 1}) {
    list.setShading(
      skin,
      box.topLeft,
      box.bottomRight,
      ink: colors.shadeInk,
      boilFrame: frame,
      pixelScale: pixelScale,
      toneFrom: toneFrom,
      toneTo: toneTo,
    );
  }

  /// Jitter in [-1, 1] for this drawing.
  double j(int salt) => boilNoise(frame, seed, salt);

  /// Jitter scaled to the boil amplitude.
  double ja(int salt, [double k = 1]) => boilNoise(frame, seed, salt) * amp * k;

  // ------------------------------------------------------------ layer API

  void layer() => list.beginLayer();

  void endLayer() => list.endLayer();

  /// A filled, inked shape; the pen now writes into it. [ink] scales the
  /// outline (0 = none).
  Path shape(Color fill, {double ink = 1}) {
    final p = list.shape(fill, lw * 2 * ink);
    pen.target(p);
    return p;
  }

  /// A shading mask (halftone / hatch / cel) of the current layer.
  Path shade() {
    final p = list.shade();
    pen.target(p);
    return p;
  }

  /// Solid ink detail (brush strokes, pupils) drawn after fills.
  Path inkFill([Color? color]) {
    final p = list.detail(InkOp.inkFill, color ?? colors.ink);
    pen.target(p);
    return p;
  }

  /// Plain fill detail drawn after fills and shading.
  Path fill(Color color) {
    final p = list.detail(InkOp.fill, color);
    pen.target(p);
    return p;
  }

  /// Ink line detail (uniform width, round caps).
  Path inkLine(double width) {
    final p = list.detail(InkOp.inkStroke, colors.ink, width);
    pen.target(p);
    return p;
  }

  /// Coloured stroke detail (hose limbs, bands).
  Path stroke(Color color, double width) {
    final p = list.detail(InkOp.stroke, color, width);
    pen.target(p);
    return p;
  }

  /// Fills [c] as a shape of the current layer and (optionally) adds its
  /// shading crescent [depth] deep.
  void blob(Contour c, Color fill, {double depth = 0, double ink = 1, double threshold = 0.05}) {
    c.writeSmooth(shape(fill, ink: ink));
    if (depth > 0) c.writeCrescent(shade(), kShadowX, kShadowY, depth, threshold: threshold);
  }

  /// A thick-to-thin brush stroke along the open contour [c].
  void brush(
    Contour c,
    double width, {
    Color? color,
    double taperIn = 0.35,
    double taperOut = 0.35,
    double minWidth = 0.15,
    double press = 0,
  }) {
    c.writeBrush(inkFill(color), width, taperIn: taperIn, taperOut: taperOut, minWidth: minWidth, press: press);
  }

  /// Convenience: a tapered brush stroke along a design-space quadratic.
  void brushQuad(
    int slot,
    double x0,
    double y0,
    double cx,
    double cy,
    double x1,
    double y1,
    double width, {
    Color? color,
    double taperIn = 0.4,
    double taperOut = 0.4,
    double press = 0,
    int samples = 8,
    double wobble = 0,
    int salt = 0,
  }) {
    final c = contour(slot)..clear(closed: false);
    c.quad(pen, x0, y0, cx, cy, x1, y1, samples: samples);
    if (wobble > 0) c.wobble(wobble, frame, seed, salt);
    brush(c, width, color: color, taperIn: taperIn, taperOut: taperOut, press: press);
  }
}
