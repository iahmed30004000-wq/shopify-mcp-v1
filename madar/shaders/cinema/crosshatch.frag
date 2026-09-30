#version 460 core
precision highp float;
#include <flutter/runtime_effect.glsl>
#include "lib/cinema.glsl"

// ---------------------------------------------------------------------------
// crosshatch — MATERIAL shader: pen hatching for shadows (noir, silent-era
// engravings, 1930s backgrounds). Use as Paint.shader on the region to
// shade. Owner: FX agent (body). Uniform contract: architect
// (shader_uniforms.dart, CrosshatchUniforms).
//
// Tone t follows the same ramp as halftone.frag. Hatch layers appear as t
// passes 0.15 / 0.4 / 0.65 / 0.85 (each layer rotated), lines wobble like a
// hand-held pen and re-draw on every boil frame.
//
// Uniforms (float indices):
//   0-3   uRamp     vec4  from.xy, to.xy (local px)
//   4-7   uRampMode vec4  x mode (0 linear, 1 radial), y tone at `from`,
//                         z tone at `to`, w boil frame
//   8-11  uInk      vec4  ink colour (straight rgba)
//   12-15 uHatch    vec4  x line spacing px, y base angle rad, z line width
//                         px, w wobble px
// Output: premultiplied ink lines, transparent elsewhere.
// ---------------------------------------------------------------------------

uniform vec4 uRamp;
uniform vec4 uRampMode;
uniform vec4 uInk;
uniform vec4 uHatch;

out vec4 fragColor;

float hatch(vec2 p, float angle, float spacing, float width, float wobble, float boil) {
  vec2 q = cn_rotate(p, angle);
  float n = cn_noise(vec2(q.x * 0.02, boil * 3.1 + angle)) - 0.5;
  float y = q.y + n * wobble * 2.0;
  float d = abs(fract(y / spacing) - 0.5) * spacing;
  return 1.0 - cn_edge(width * 0.5, d, 0.6);
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  float t = mix(uRampMode.y, uRampMode.z, cn_ramp(p, uRamp.xy, uRamp.zw, uRampMode.x));
  float sp = max(uHatch.x, 2.0);
  float boil = uRampMode.w;
  float a = 0.0;
  a = max(a, hatch(p, uHatch.y, sp, uHatch.z, uHatch.w, boil) * step(0.15, t));
  a = max(a, hatch(p, uHatch.y + 1.5708, sp, uHatch.z, uHatch.w, boil) * step(0.4, t));
  a = max(a, hatch(p, uHatch.y + 0.7854, sp * 0.8, uHatch.z, uHatch.w, boil) * step(0.65, t));
  a = max(a, hatch(p, uHatch.y - 0.7854, sp * 0.8, uHatch.z, uHatch.w, boil) * step(0.85, t));
  fragColor = vec4(uInk.rgb, 1.0) * uInk.a * a;
}
