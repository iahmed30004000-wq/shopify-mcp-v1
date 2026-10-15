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

// One pen layer: parallel strokes that wander with the hand (re-inked on
// every boil frame), vary in pressure along their length and break off now
// and then. `width` 0 = no stroke, so a layer fades in instead of starting
// at a hard edge.
float hatch(vec2 p, float angle, float spacing, float width, float wobble, float boil) {
  vec2 q = cn_rotate(p, angle);
  float row = floor(q.y / spacing);
  float n = cn_noise(vec2(q.x * 0.02, boil * 3.1 + angle + row * 0.37)) - 0.5;
  float y = q.y + n * wobble * 2.0;
  float d = abs(fract(y / spacing) - 0.5) * spacing;
  float press = 0.7 + 0.6 * cn_noise(vec2(q.x * 0.035 + row * 1.7, angle * 3.0));
  float gap = smoothstep(0.08, 0.2, cn_noise(vec2(q.x * 0.012 + row * 5.3, angle + boil * 0.5)));
  float w = width * press * 0.5;
  return (1.0 - cn_edge(w, d, 0.6)) * gap * step(0.05, width);
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  float t = mix(uRampMode.y, uRampMode.z, cn_ramp(p, uRamp.xy, uRamp.zw, uRampMode.x));
  float sp = max(uHatch.x, 2.0);
  float boil = uRampMode.w;
  float lw = uHatch.z;
  // Each layer thickens in as the tone darkens.
  float w1 = lw * smoothstep(0.08, 0.3, t);
  float w2 = lw * smoothstep(0.35, 0.55, t);
  float w3 = lw * 0.9 * smoothstep(0.6, 0.78, t);
  float w4 = lw * 0.9 * smoothstep(0.8, 0.95, t);
  float a = hatch(p, uHatch.y, sp, w1, uHatch.w, boil);
  a = max(a, hatch(p, uHatch.y + 1.5708, sp, w2, uHatch.w, boil));
  a = max(a, hatch(p, uHatch.y + 0.7854, sp * 0.8, w3, uHatch.w, boil));
  a = max(a, hatch(p, uHatch.y - 0.7854, sp * 0.8, w4, uHatch.w, boil));
  fragColor = vec4(uInk.rgb, 1.0) * uInk.a * a;
}
