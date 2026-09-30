#version 460 core
precision highp float;
#include <flutter/runtime_effect.glsl>
#include "lib/cinema.glsl"

// ---------------------------------------------------------------------------
// vhs — full-frame post pass for the 1980s VHS-neon era (replaces
// film_grade.frag for Era.vhs). Owner: FX agent (body). Uniform contract:
// architect (shader_uniforms.dart, VhsUniforms).
//
// Pipeline: time-base error (line jitter, tape wobble, rolling tracking
// band, head-switching skew at the bottom, damage tears) → YIQ split: luma
// band-limited with the deck's edge-enhancement ring, chroma low-passed,
// delayed and smeared to the right with streaky chroma noise → grade →
// scanlines and a rolling hum bar → snow and white dropouts → head-switching
// noise → flash / fade.
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
// Output: opaque, premultiplied. Budget: 7 texture fetches/pixel (3 luma +
// 4 chroma), everything else ALU.
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

vec3 toYiq(vec3 c) {
  return vec3(dot(c, vec3(0.299, 0.587, 0.114)), dot(c, vec3(0.596, -0.274, -0.322)), dot(c, vec3(0.211, -0.523, 0.312)));
}

vec3 toRgb(vec3 y) {
  return vec3(y.x + 0.956 * y.y + 0.621 * y.z, y.x - 0.272 * y.y - 0.647 * y.z, y.x - 1.106 * y.y + 1.703 * y.z);
}

void main() {
  vec2 size = max(uRect.zw, vec2(1.0));
  vec2 p = FlutterFragCoord().xy - uRect.xy;
  float t = uClock.x;
  float vf = uClock.y;
  float seed = uClock.w;
  float lineH = 3.0;
  float line = floor(p.y / lineH);

  // --- time-base error ----------------------------------------------------------
  float jitter = (cn_hash11(line * 0.61 + vf * 13.1 + seed) - 0.5) * 0.7;
  float wob = (sin(p.y * 0.017 + t * 1.9) * 0.6 + sin(p.y * 0.0053 - t * 0.7 + seed) * 0.4) * uTape.w;
  float bandY = fract(t * 0.043 + seed * 0.13) * size.y * 1.5 - size.y * 0.25;
  float bd = (p.y - bandY) / (14.0 + 26.0 * uTape.z);
  float band = exp(-bd * bd) * uTape.z;
  float tear = band * (6.0 + cn_hash11(line * 0.37 + vf) * 26.0);
  float headZone = smoothstep(size.y - 16.0, size.y - 4.0, p.y);
  float headSkew = headZone * (10.0 + cn_hash11(line + vf * 0.5) * 12.0);
  float gl = uEvent.w * step(0.55, cn_hash11(floor(p.y / 13.0) + vf * 3.1));
  float glitch = gl * (cn_hash11(vf * 1.3 + floor(p.y / 13.0)) - 0.5) * 70.0;
  float vjump = step(0.965, cn_hash11(vf * 0.71 + seed)) * 2.0;
  vec2 shake = (cn_hash22(vec2(vf, 7.7 + seed)) - 0.5) * uEvent.y * 16.0;
  float dx = jitter + wob + tear + headSkew + glitch;
  vec2 uv = (p - vec2(dx, vjump) - shake) / size;
  vec2 px = vec2(1.0 / size.x, 0.0);

  // --- luma: band-limited, with the deck's sharpening ring -------------------------
  vec3 c0 = sampleFrame(uv);
  float y0 = toYiq(c0).x;
  float yl = toYiq(sampleFrame(uv - px * 1.6)).x;
  float yr = toYiq(sampleFrame(uv + px * 1.6)).x;
  float soft = (yl + y0 + yr) / 3.0;
  float y = mix(y0, soft, 0.45) + (y0 - 0.5 * (yl + yr)) * 0.75;

  // --- chroma: low-passed, delayed and smeared to the right -----------------------
  float bleed = max(uTone.w, 0.5);
  vec2 cuv = uv - px * uTape.y;
  vec2 iq = toYiq(sampleFrame(cuv)).yz * 0.34;
  iq += toYiq(sampleFrame(cuv - px * bleed * 0.8)).yz * 0.28;
  iq += toYiq(sampleFrame(cuv - px * bleed * 1.8)).yz * 0.22;
  iq += toYiq(sampleFrame(cuv - px * bleed * 3.0)).yz * 0.16;
  vec2 cn = vec2(cn_noise(vec2(p.x / 38.0 + vf * 3.1, line * 0.83)), cn_noise(vec2(p.x / 45.0 - vf * 2.3, line * 0.79 + 9.0))) - 0.5;
  iq += cn * (0.045 + band * 0.25 + uEvent.w * 0.1);
  iq *= max(uTone.x, 0.0) * (1.0 - gl * 0.6);
  vec3 c = toRgb(vec3(y, iq));

  // --- grade ------------------------------------------------------------------------
  c = mix(c, c * uTint.rgb * 1.2, uTint.a);
  c = (c - 0.5) * uTone.y + 0.5 + uTone.z;
  // Bright neon clips soft and blooms a touch along the line.
  float hot = smoothstep(0.75, 1.1, max(c.r, max(c.g, c.b)));
  c += hot * 0.08;

  // --- raster -----------------------------------------------------------------------
  float scan = 0.5 + 0.5 * cos(p.y * CN_TAU / lineH);
  c *= 1.0 - uTape.x * 0.32 * scan * (1.0 - cn_luma(cn_sat3(c)) * 0.45);
  float hum = 0.5 + 0.5 * sin((p.y / size.y - t * 0.11) * CN_TAU);
  c *= 1.0 - 0.045 * hum * uTape.x;

  // --- noise ------------------------------------------------------------------------
  float snow = cn_hash12(floor(p / vec2(1.2, 1.0)) + vec2(vf * 11.0, vf * 3.7)) - 0.5;
  c += snow * (0.045 + band * 0.7 + headZone * 0.4);
  // White dropouts: oxide flaking off the tape, a short streak on one line.
  float dl = cn_hash11(line * 1.37 + vf * 7.9 + seed);
  float dropP = 0.004 + uTape.z * 0.01 + band * 0.25 + uEvent.w * 0.05;
  float dx0 = cn_hash11(line * 3.1 + vf) * size.x;
  float dlen = 12.0 + cn_hash11(line + vf * 2.0) * 70.0;
  float streak = step(dl, dropP) * step(dx0, p.x) * (1.0 - smoothstep(dx0, dx0 + dlen, p.x));
  c = mix(c, vec3(0.95), streak * 0.85);

  // Head-switching band: skewed, noisy and slightly dark.
  c = mix(c, c * 0.7 + vec3(cn_hash12(vec2(floor(p.x / 3.0), vf))) * 0.3, headZone * 0.7);

  // Tube edges.
  vec2 q = p / size - 0.5;
  c *= 1.0 - dot(q * vec2(1.1, 0.7), q * vec2(1.1, 0.7)) * 0.45;

  c = mix(c, vec3(1.0), cn_sat(uEvent.x));
  c *= 1.0 - cn_sat(uEvent.z);
  fragColor = vec4(cn_sat3(c), 1.0);
}
