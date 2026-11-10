import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../domain/scene_math.dart';

/// The planet uniform contract (see `PlanetParams`) as one reusable float
/// buffer: fill it with [set], then [applyTo] a shader. One buffer per body,
/// allocated once – nothing is allocated per frame.
///
/// Layout (float index): 0–1 uSize, 2–3 uCenter, 4 uRadius, 5 uTime,
/// 6–8 uLight, 9 uScore, 10 uPulse, 11–13 uSpin, 14–17 uColorA,
/// 18–21 uColorB, 22–25 uColorC, 26 uDetail, 27 uSeed, 28–31 uExtra.
class PlanetUniforms {
  static const length = 32;
  static const iSize = 0, iCenter = 2, iRadius = 4, iTime = 5, iLight = 6, iScore = 9, iPulse = 10;
  static const iSpin = 11, iColorA = 14, iColorB = 18, iColorC = 22, iDetail = 26, iSeed = 27, iExtra = 28;

  final Float32List values = Float32List(length);

  void set({
    required ui.Size canvas,
    required ui.Offset center,
    required double radius,
    required double time,
    required double lightX,
    required double lightY,
    required double lightZ,
    required double score,
    required double pulse,
    required double spin,
    required double tilt,
    double spinZ = 0,
    required ui.Color colorA,
    required ui.Color colorB,
    required ui.Color colorC,
    required double detail,
    required double seed,
    required List<double> extra,
  }) {
    final v = values;
    v[0] = canvas.width;
    v[1] = canvas.height;
    v[2] = center.dx;
    v[3] = center.dy;
    v[4] = radius;
    v[5] = time;
    v[6] = lightX;
    v[7] = lightY;
    v[8] = lightZ;
    v[9] = score;
    v[10] = pulse;
    v[11] = spin;
    v[12] = tilt;
    v[13] = spinZ;
    _color(iColorA, colorA);
    _color(iColorB, colorB);
    _color(iColorC, colorC);
    v[26] = detail;
    v[27] = seed;
    for (var i = 0; i < 4; i++) {
      v[iExtra + i] = i < extra.length ? extra[i] : 0;
    }
  }

  /// Overrides one `uExtra` component (e.g. a moon's selection ring).
  void setExtra(int i, double value) => values[iExtra + i] = value;

  void _color(int at, ui.Color c) {
    values[at] = c.r;
    values[at + 1] = c.g;
    values[at + 2] = c.b;
    values[at + 3] = c.a;
  }

  /// Copies the buffer into [shader]'s float uniforms (in declaration order).
  void applyTo(ui.FragmentShader shader) {
    final v = values;
    for (var i = 0; i < length; i++) {
      shader.setFloat(i, v[i]);
    }
  }
}

/// View-space helpers shared by the planet and moon draws.
abstract final class PlanetViewMath {
  /// Art-directed light depth: the view-space z of the light (toward the
  /// viewer) is compressed to `zBias + zScale · z`. Physically a world
  /// between the camera and the star is lit from behind (a black disc with a
  /// hairline rim) and one behind the star is lit flat from the front; the
  /// compression keeps the order (far worlds brighter, near worlds back-lit)
  /// but every world shows a readable lit crescent – the thriving/neglected
  /// cue must read on the near worlds too – and none looks flat. The
  /// direction in the screen plane always points at the star. (0.15 / 0.75:
  /// near and far worlds show clearly different phases; the sky-tinted
  /// Fresnel rim keeps the back-lit ones readable.)
  static const zBias = 0.15, zScale = 0.75;

  /// Unit light direction for a body at world [body] lit by the core star
  /// at [star], in shader view space (x right, y up, z toward the viewer),
  /// given the camera basis [right], [up], [forward].
  static (double, double, double) lightInView(
    V3 body,
    V3 star,
    V3 right,
    V3 up,
    V3 forward, {
    double bias = zBias,
    double scale = zScale,
  }) {
    var lx = star.x - body.x, ly = star.y - body.y, lz = star.z - body.z;
    final len = math.sqrt(lx * lx + ly * ly + lz * lz);
    if (len < 1e-9) {
      // At the star itself: light from the viewer.
      return (0.0, 0.0, 1.0);
    }
    lx /= len;
    ly /= len;
    lz /= len;
    // View space: x = L·right, y = L·up, z = −L·forward (toward the viewer).
    var x = lx * right.x + ly * right.y + lz * right.z;
    var y = lx * up.x + ly * up.y + lz * up.z;
    final z = -(lx * forward.x + ly * forward.y + lz * forward.z);
    final zc = (bias + scale * z).clamp(-1.0, 1.0);
    final planar = math.sqrt(x * x + y * y);
    if (planar < 1e-6) {
      // Exactly in line with the star: light from above.
      x = 0;
      y = 1;
    } else {
      x /= planar;
      y /= planar;
    }
    final s = math.sqrt(math.max(0.0, 1 - zc * zc));
    return (x * s, y * s, zc);
  }

  /// `uDetail` (level of detail) for an on-screen disc radius in logical
  /// pixels: 0.04 for a speck, 1 once the world is ~220 px (hero scale).
  static double detailFor(double radiusPx) => (radiusPx / 220).clamp(0.04, 1.0);

  /// Whether a draw rect is (partly) inside the viewport (with a margin).
  static bool onScreen(ui.Rect r, ui.Size viewport, {double margin = 2}) =>
      r.right >= -margin &&
      r.bottom >= -margin &&
      r.left <= viewport.width + margin &&
      r.top <= viewport.height + margin;

  /// Hermite smoothstep.
  static double smoothstep(double e0, double e1, double x) {
    final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }
}
