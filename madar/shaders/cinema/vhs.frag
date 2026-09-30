#version 460 core
precision highp float;
#include <flutter/runtime_effect.glsl>
#include "lib/cinema.glsl"

// ---------------------------------------------------------------------------
// vhs — full-frame post pass for the 1980s VHS-neon era (replaces
// film_grade.frag for Era.vhs). Owner: FX agent (body). Uniform contract:
// architect (shader_uniforms.dart, VhsUniforms).
//
// Pipeline: tape wobble + tracking band → chroma/luma split with horizontal
// colour bleed → grade → scanlines → noise/snow → head-switching noise at the
// bottom → flash / fade.
//
// Uniforms (float indices for setFloat):
//   0-3   uRect   vec4  destination rect in local px (x, y, w, h)
//   4-7   uClock  vec4  x seconds, y video frame index (30 fps), z boil frame, w seed
//   8-11  uTint   vec4  grade tint (rgb) and strength (a)
//   12-15 uTone   vec4  x saturation, y contrast, z brightness, w chroma bleed px
//   16-19 uTape   vec4  x scanline strength (0..1), y chroma shift px,
//                       z tracking noise (0..1), w wobble px
//   20-23 uEvent  vec4  x flash, y shake, z fade, w glitch (0..1: damage)
//   sampler 0 uFrame     the rendered frame (opaque).
// Output: opaque, premultiplied. Budget: ≤ 5 texture fetches/pixel.
// ---------------------------------------------------------------------------

uniform vec4 uRect;
uniform vec4 uClock;
uniform vec4 uTint;
uniform vec4 uTone;
uniform vec4 uTape;
uniform vec4 uEvent;
uniform sampler2D uFrame;

out vec4 fragColor;

vec3 sampleFrame(vec2 uv) {
  return texture(uFrame, cn_frame_uv(clamp(uv, vec2(0.0), vec2(1.0)))).rgb;
}

void main() {
  vec2 size = max(uRect.zw, vec2(1.0));
  vec2 p = FlutterFragCoord().xy - uRect.xy;
  float t = uClock.x;
  float vf = uClock.y;

  // Tape wobble: a slow horizontal sway plus a rolling tracking band.
  float wob = sin(p.y * 0.021 + t * 2.1) * 0.5 + sin(p.y * 0.0071 - t * 0.9) * 0.5;
  float bandY = fract(t * 0.07 + uClock.w) * (size.y + 160.0) - 80.0;
  float band = exp(-pow((p.y - bandY) / 26.0, 2.0)) * uTape.z;
  float glitch = uEvent.w * step(0.6, cn_hash11(floor(p.y / 9.0) + vf * 3.1));
  float dx = wob * uTape.w + band * 18.0 * (cn_hash11(floor(p.y / 2.0) + vf) - 0.5) +
             glitch * (cn_hash11(vf + floor(p.y / 9.0)) - 0.5) * 40.0;
  vec2 shake = (cn_hash22(vec2(vf, 7.7)) - 0.5) * uEvent.y * 14.0;
  vec2 uv = (p + vec2(dx, 0.0) - shake) / size;

  // Chroma shift + horizontal bleed (colour smears to the right).
  vec2 cs = vec2(uTape.y, 0.0) / size;
  vec2 bl = vec2(uTone.w, 0.0) / size;
  vec3 mid = sampleFrame(uv);
  float r = mix(sampleFrame(uv + cs).r, sampleFrame(uv + cs - bl).r, 0.5);
  float b = mix(sampleFrame(uv - cs).b, mid.b, 0.35);
  vec3 c = vec3(r, mid.g, b);

  float l = cn_luma(c);
  c = mix(vec3(l), c, uTone.x);
  c = mix(c, c * uTint.rgb * 1.25, uTint.a);
  c = (c - 0.5) * uTone.y + 0.5 + uTone.z;

  // Scanlines (every other device-independent 3 px row) and snow.
  float scan = 0.5 + 0.5 * sin(p.y * CN_TAU / 3.0);
  c *= 1.0 - uTape.x * 0.35 * scan;
  float snow = cn_hash12(floor(p / 1.5) + vf * 11.0) - 0.5;
  c += snow * (0.05 + band * 0.6);

  // Head-switching noise along the bottom edge.
  float head = smoothstep(size.y - 14.0, size.y, p.y);
  c = mix(c, vec3(cn_hash12(vec2(floor(p.x / 3.0), vf))), head * 0.5);

  c = mix(c, vec3(1.0), cn_sat(uEvent.x));
  c *= 1.0 - cn_sat(uEvent.z);
  fragColor = vec4(cn_sat3(c), 1.0);
}
