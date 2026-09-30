#version 460 core
precision highp float;
#include <flutter/runtime_effect.glsl>
#include "lib/cinema.glsl"

// ---------------------------------------------------------------------------
// halftone — MATERIAL shader: printed-dot shading for shapes (use as
// Paint.shader when filling the shadow/light region of a limb, body, prop or
// backdrop). Owner: FX agent (body). Uniform contract: architect
// (shader_uniforms.dart, HalftoneUniforms).
//
// Tone t (0 = no ink, 1 = solid ink) follows a ramp in the canvas' LOCAL
// px (the coordinates you draw in, before the canvas transform):
// linear from uRamp.xy (tone uRampMode.y) to uRamp.zw (tone uRampMode.z), or
// radial around uRamp.xy with radius |zw - xy|.
//
// Uniforms (float indices):
//   0-3   uRamp     vec4  from.xy, to.xy (local px)
//   4-7   uRampMode vec4  x mode (0 linear, 1 radial), y tone at `from`,
//                         z tone at `to`, w boil frame (dots jitter on twos)
//   8-11  uInk      vec4  ink colour (straight rgba)
//   12-15 uDots     vec4  x cell size px, y screen angle rad, z dot shape
//                         (0 round, 1 line screen), w edge softness px
// Output: premultiplied ink where the dots are, transparent elsewhere.
// ---------------------------------------------------------------------------

uniform vec4 uRamp;
uniform vec4 uRampMode;
uniform vec4 uInk;
uniform vec4 uDots;

out vec4 fragColor;

void main() {
  vec2 p = FlutterFragCoord().xy;
  float t = mix(uRampMode.y, uRampMode.z, cn_ramp(p, uRamp.xy, uRamp.zw, uRampMode.x));
  float cell = max(uDots.x, 1.5);
  vec2 jitter = (cn_hash22(vec2(uRampMode.w, 2.7)) - 0.5) * 0.35 * cell;
  vec2 q = cn_rotate(p + jitter, uDots.y) / cell;
  vec2 f = fract(q) - 0.5;
  float a;
  if (uDots.z > 0.5) {
    float w = t * 0.5;
    a = 1.0 - cn_edge(w, abs(f.y), uDots.w / cell + 0.02);
  } else {
    float r = sqrt(cn_sat(t)) * 0.7071;
    a = 1.0 - cn_edge(r, length(f), uDots.w / cell + 0.02);
  }
  a *= step(0.001, t);
  fragColor = vec4(uInk.rgb, 1.0) * uInk.a * a;
}
