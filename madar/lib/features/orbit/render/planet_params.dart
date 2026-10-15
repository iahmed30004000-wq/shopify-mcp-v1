import 'dart:ui' as ui;

import '../../../core/design/themes.dart';
import '../domain/scene_math.dart';
import 'uniform_writer.dart';

/// Parameters shared by every planet shader. The GLSL declaration order is the
/// **planet uniform contract** (after `#include "lib/common.glsl"`, which owns
/// sampler 0 `uNoise`):
///
/// ```glsl
/// uniform vec2 uSize;     // canvas size (px)
/// uniform vec2 uCenter;   // planet centre (px, local canvas coords)
/// uniform float uRadius;  // planet radius (px)
/// uniform float uTime;    // seconds
/// uniform vec3 uLight;    // unit light dir in view space (x right, y up, z to viewer)
/// uniform float uScore;   // 0 neglected … 1 thriving (spring-animated)
/// uniform float uPulse;   // 0..1 celebration burst after a completion
/// uniform vec3 uSpin;     // x: spin angle, y: axial tilt, z: archetype-specific
/// uniform vec4 uColorA;   // palette surface
/// uniform vec4 uColorB;   // palette glow
/// uniform vec4 uColorC;   // palette deep
/// uniform float uDetail;  // LOD 0 (tiny/far) … 1 (fills the screen)
/// uniform float uSeed;    // per-planet noise offset
/// uniform vec4 uExtra;    // archetype-specific (documented per shader)
/// ```
///
/// Output convention: premultiplied `fragColor = vec4(rgb * a, a)`; the halo
/// may extend to `uRadius * haloFactor`.
class PlanetParams {
  const PlanetParams({
    required this.center,
    required this.radius,
    required this.time,
    required this.light,
    required this.score,
    required this.palette,
    this.pulse = 0,
    this.spin = V3.zero,
    this.detail = 0.5,
    this.seed = 0,
    this.extra = const [0, 0, 0, 0],
    this.haloFactor = 1.35,
  });

  final ui.Offset center;
  final double radius;
  final double time;
  final V3 light;
  final double score;
  final double pulse;
  final V3 spin;
  final PlanetPalette palette;
  final double detail;
  final double seed;
  final List<double> extra;

  /// Draw-rect half extent relative to [radius] (atmosphere / rings).
  final double haloFactor;

  ui.Rect get drawRect => ui.Rect.fromCircle(center: center, radius: radius * haloFactor);

  void write(UniformWriter w, ui.Size canvasSize) {
    w.size(canvasSize);
    w.offset(center);
    w.f(radius);
    w.f(time);
    w.v3(light);
    w.f(score);
    w.f(pulse);
    w.v3(spin);
    w.color(palette.surface);
    w.color(palette.glow);
    w.color(palette.deep);
    w.f(detail);
    w.f(seed);
    for (var i = 0; i < 4; i++) {
      w.f(i < extra.length ? extra[i] : 0);
    }
  }
}
