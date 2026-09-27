// Madar – living cosmos backdrop for every non-home screen.
//
// Deep-space gradient, two domain-warped nebula clouds, a two-layer
// twinkling starfield with rare diffraction-spiked stars, dust motes and film
// grain. In the light (Pearl) theme the same fields become a soft
// mother-of-pearl haze with iridescent sheen and gold glints.
//
// Every time-dependent term is periodic in PERIOD seconds, so the host wraps
// uTime into [0, PERIOD) and the loop is seamless (and float precision never
// degrades on long sessions).
//
// Uniform layout (float indices, set from Dart – keep in sync with
// CosmosUniforms in lib/core/design/widgets/cosmos_backdrop.dart):
//   0-1  uSize      logical size of the painted rect
//   2    uTime      seconds, wrapped to [0, PERIOD)
//   3-6  uSpace0    deepest background (rgb, a unused)
//   7-10 uSpace1    raised background
//  11-14 uNebulaA   first nebula colour
//  15-18 uNebulaB   second nebula colour
//  19-22 uStar      star tint
//  23-26 uDust      dust tint
//  27-30 uParams    x intensity, y light theme (0/1), z grain, w seed
#version 460 core
precision highp float;

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;
uniform vec4 uSpace0;
uniform vec4 uSpace1;
uniform vec4 uNebulaA;
uniform vec4 uNebulaB;
uniform vec4 uStar;
uniform vec4 uDust;
uniform vec4 uParams;

out vec4 fragColor;

const float TAU = 6.28318530718;
const float PERIOD = 240.0;

// Sine-free hashes (stable on mediump-ish mobile GPUs).
float hash12(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.xx + p3.yz) * p3.zy);
}

float vnoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  float a = hash12(i);
  float b = hash12(i + vec2(1.0, 0.0));
  float c = hash12(i + vec2(0.0, 1.0));
  float d = hash12(i + vec2(1.0, 1.0));
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

const mat2 ROT = mat2(0.80, -0.60, 0.60, 0.80);

float fbm3(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  for (int i = 0; i < 3; i++) {
    v += a * vnoise(p);
    p = ROT * p * 2.02 + 17.3;
    a *= 0.5;
  }
  return v / 0.875;
}

float fbm5(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  for (int i = 0; i < 5; i++) {
    v += a * vnoise(p);
    p = ROT * p * 2.03 + 11.7;
    a *= 0.5;
  }
  return v / 0.96875;
}

// Diagonal Milky-Way band (0..1) at a logical-pixel position.
float milkyBand(vec2 px) {
  float s = min(uSize.x, uSize.y);
  vec2 p = (px - 0.5 * uSize) / s;
  float d = dot(p, vec2(0.78, 0.62)) + 0.08 * sin(p.y * 2.3 + uParams.w);
  return exp(-d * d / 0.09);
}

// One layer of stars on a jittered grid. `px` is in logical pixels so star
// size stays constant across screen sizes. Every contribution fades out
// before the cell border, so no star is ever clipped into a square.
//   jitter   0..1 how far a star may wander from its cell centre
//   bandBias extra density inside the Milky-Way band
vec3 starLayer(vec2 px, float cell, float density, float bandBias, float ph, float seed,
               float sizeMin, float sizeMax, float haloAmt, float spikeAmt, float jitter) {
  vec2 g = px / cell;
  vec2 id = floor(g);
  vec2 f = fract(g);
  float dens = density + bandBias * milkyBand((id + 0.5) * cell);
  if (hash12(id * 1.37 + seed * 3.1) < 1.0 - dens) return vec3(0.0);
  vec2 h = hash22(id + seed);
  vec2 pos = 0.5 + (h - 0.5) * jitter;
  vec2 dv = (f - pos) * cell;
  float d = length(dv);
  float edge = (0.5 - 0.5 * jitter) * cell;
  float fade = smoothstep(edge, edge * 0.5, max(abs(dv.x), abs(dv.y)));
  float r = hash12(id + seed + 7.1);
  float size = mix(sizeMin, sizeMax, r * r * r);
  // Integer frequency multiples of the base phase keep the loop seamless.
  float freq = floor(38.0 + h.x * 90.0);
  float tw = 0.58 + 0.42 * sin(ph * freq + h.y * TAU);
  float core = smoothstep(size, size * 0.1, d);
  float halo = exp(-d * d / (size * size * 7.0)) * haloAmt;
  float big = smoothstep(0.55, 0.95, r);
  float spikes = (exp(-abs(dv.y) * 1.7) * exp(-abs(dv.x) / (size * 5.5)) +
                  exp(-abs(dv.x) * 1.7) * exp(-abs(dv.y) / (size * 5.5))) * big * spikeAmt;
  // x: brightness, y: temperature (0 warm .. 1 cool), z: unused
  return vec3((core + halo + spikes) * tw * fade, h.y, 0.0);
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = frag / uSize;
  float s = min(uSize.x, uSize.y);
  vec2 p = (frag - 0.5 * uSize) / s;
  float aspect = uSize.x / uSize.y;

  float intensity = uParams.x;
  float light = uParams.y;
  float grainAmt = uParams.z;
  float seed = uParams.w;
  float ph = TAU * uTime / PERIOD;

  // ---- Nebula fields (shared by dark and light looks) ----------------------
  vec2 q = p * 1.55 + vec2(seed * 0.37, seed * 0.61);
  vec2 drift1 = vec2(cos(ph), sin(ph)) * 0.32;
  vec2 drift2 = vec2(cos(2.0 * ph + 1.3), sin(ph + 0.7)) * 0.22;
  vec2 w = vec2(fbm3(q + drift1), fbm3(q + vec2(5.2, 1.3) - drift1));
  float nA = fbm5(q + 1.75 * w + drift2);
  float nB = fbm5(q * 1.25 + 1.45 * w.yx + vec2(3.1, 7.7) - drift2);

  // Clouds live in opposite corners so text in the middle stays calm.
  float maskA = smoothstep(1.15, 0.05, length((p - vec2(-0.32, -0.62)) * vec2(1.0, 0.8)));
  float maskB = smoothstep(1.25, 0.05, length((p - vec2(0.38, 0.58)) * vec2(1.0, 0.85)));
  float cA = smoothstep(0.32, 0.9, nA) * maskA;
  float cB = smoothstep(0.34, 0.9, nB) * maskB;
  float lane = smoothstep(0.52, 0.78, vnoise(q * 3.1 + w * 2.0 - drift2));

  vec3 col;
  if (light < 0.5) {
    // ---- Deep space -------------------------------------------------------
    float grad = smoothstep(-0.1, 1.05, uv.y);
    vec3 base = mix(uSpace1.rgb, uSpace0.rgb, grad);
    // A faint bloom behind the upper third – the "sky" feels lit.
    vec2 bp = p - vec2(0.12, -0.72);
    base += uSpace1.rgb * 0.7 * exp(-3.5 * dot(bp, bp));
    col = base;

    // Milky-Way haze.
    float band = milkyBand(frag);
    float bandTex = fbm3(q * 2.2 - w * 1.5);
    col += mix(uNebulaA.rgb, uStar.rgb, 0.35) * band * smoothstep(0.35, 0.85, bandTex) * 0.11 * intensity;

    // Nebulae with dark dust lanes and bright emission cores.
    float rid = 1.0 - abs(2.0 * vnoise(q * 3.6 + w * 2.6 + drift2) - 1.0);
    float fil = pow(rid, 7.0);
    vec3 neb = uNebulaA.rgb * (cA * 0.85 + fil * cA * 0.55) + uNebulaB.rgb * (cB * 0.8 + fil * cB * 0.45);
    neb *= 1.0 - 0.5 * lane * clamp(cA + cB, 0.0, 1.0);
    col += neb * intensity;
    col += mix(uNebulaA.rgb, uStar.rgb, 0.5) * pow(cA, 2.6) * 0.38 * intensity;
    col += mix(uNebulaB.rgb, uStar.rgb, 0.45) * pow(cB, 2.6) * 0.32 * intensity;

    // Starfield: fine dust stars, a mid layer and rare bright stars.
    vec3 s1 = starLayer(frag, 6.0, 0.10, 0.30, ph, seed + 1.0, 0.28, 0.7, 0.0, 0.0, 0.5);
    vec3 s2 = starLayer(frag + 131.0, 21.0, 0.26, 0.20, ph, seed + 5.0, 0.55, 1.3, 0.35, 0.0, 0.6);
    vec3 s3 = starLayer(frag + 977.0, 92.0, 0.30, 0.10, ph, seed + 9.0, 1.0, 2.3, 0.55, 0.9, 0.42);
    vec3 cool = mix(uStar.rgb, clamp(uNebulaA.rgb * 1.6 + 0.45, 0.0, 1.0), 0.45);
    float calm = 1.0 - clamp(cA + cB, 0.0, 1.0) * 0.35;
    col += mix(uStar.rgb, cool, s1.y) * s1.x * 0.45 * calm;
    col += mix(uStar.rgb, cool, s2.y) * s2.x * 0.85 * calm;
    col += mix(uStar.rgb, cool, s3.y) * s3.x * 1.1;

    // Dust motes catching light inside the nebulae.
    float mote = smoothstep(0.86, 1.0, vnoise(frag * 0.42 + seed)) * (cA + cB);
    col += uDust.rgb * mote * 0.08 * intensity;

    // Vignette.
    float vig = smoothstep(1.35, 0.25, length((uv - 0.5) * vec2(aspect, 1.0) * 1.35));
    col *= mix(0.6, 1.0, vig);
  } else {
    // ---- Pearl: soft mother-of-pearl haze ---------------------------------
    float grad = smoothstep(-0.05, 1.1, uv.y);
    col = mix(uSpace0.rgb, uSpace1.rgb, grad);
    col = mix(col, uNebulaA.rgb, cA * 0.75 * intensity);
    col = mix(col, uNebulaB.rgb, cB * 0.85 * intensity);
    // Iridescent thin-film sheen following the warp field.
    vec3 iri = 0.5 + 0.5 * cos(TAU * (nA * 1.6 + w.x * 0.8 + vec3(0.0, 0.33, 0.67)));
    col += (iri - 0.5) * 0.07 * (0.3 + cA + cB) * intensity;
    // Soft light pooling at the top.
    vec2 lp = p - vec2(-0.12, -0.85);
    col += vec3(1.0) * 0.07 * exp(-2.6 * dot(lp, lp));
    // Sparse gold glints instead of stars.
    vec3 g1 = starLayer(frag + 97.0, 44.0, 0.20, 0.10, ph, seed + 4.0, 0.5, 1.5, 0.45, 0.5, 0.55);
    col = mix(col, uStar.rgb, clamp(g1.x * 0.6, 0.0, 0.75));
    float mote = smoothstep(0.9, 1.0, vnoise(frag * 0.35 + seed)) * (cA + cB);
    col = mix(col, uDust.rgb, mote * 0.12 * intensity);
    // Gentle warm vignette.
    float vig = smoothstep(1.4, 0.3, length((uv - 0.5) * vec2(aspect, 1.0) * 1.3));
    col *= mix(0.92, 1.0, vig);
  }

  // Film grain (changes at ~12 Hz) + dithering against gradient banding.
  float gt = floor(uTime * 12.0);
  float grain = hash12(frag + vec2(gt * 13.1, gt * 7.7)) - 0.5;
  col += grain * grainAmt;

  fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
