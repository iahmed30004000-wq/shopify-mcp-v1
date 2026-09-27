#version 460 core
#include <flutter/runtime_effect.glsl>
#include "lib/common.glsl"

// ---------------------------------------------------------------------------
// Lens flare — a restrained cinematic flare from the core star, drawn over the
// whole scene. Aperture ghosts are soft regular OCTAGONS (8 aperture blades,
// echoing the 8-fold motif) strung along the source → screen-centre axis,
// each with a faint chromatic fringe; plus a thin anamorphic horizontal
// streak, a gentle chromatic halo ring around the source and a soft glare.
//
// Uniforms (after common.glsl; sampler 0 = uNoise — declared by the shared
// library; this shader only uses the ALU hash, but bind the noise image anyway):
//   uSize       canvas size (px). Draw rect: the full canvas (Offset.zero & size).
//   uSource     flare source in px (the core star centre, same canvas).
//   uIntensity  0..1 overall strength (0 = nothing; ~0.6 is the tasteful default;
//               scale with the star's brightness / uBalance / uPulse).
//   uTint       flare tint (straight sRGB), e.g. #FFD9A0; ghosts drift from it
//               toward teal / violet / rose for a subtle multi-coated look.
// Blend: paint with BlendMode.plus (true additive); with the default srcOver
// the premultiplied output (alpha = max(rgb)) behaves like "screen".
// ---------------------------------------------------------------------------

uniform vec2 uSize;
uniform vec2 uSource;
uniform float uIntensity;
uniform vec4 uTint;

out vec4 fragColor;

float lf_sq(float x) { return x * x; }

// Regular octagon, flat sides on the axes; r = apothem (after iq).
float lf_octagon(vec2 p, float r) {
  const vec3 k = vec3(-0.9238795325, 0.3826834323, 0.4142135623);
  p = abs(p);
  p -= 2.0 * min(dot(vec2(k.x, k.y), p), 0.0) * vec2(k.x, k.y);
  p -= 2.0 * min(dot(vec2(-k.x, k.y), p), 0.0) * vec2(-k.x, k.y);
  p -= vec2(clamp(p.x, -k.z * r, k.z * r), r);
  return length(p) * sign(p.y);
}

// Soft aperture ghost: faint body + brighter rim; d and sizes in px.
float lf_ghost(float d, float r, float ring) {
  float soft = max(r * 0.12, 1.5);
  float body = 1.0 - smoothstep(-soft, soft, d);
  float rim = exp(-lf_sq(d / max(r * 0.06, 1.2)));
  // Coated-glass look: nearly clear centre brightening toward the blades.
  return mix(body * (0.45 + 0.55 * smoothstep(-r * 0.9, 0.0, d)), rim, ring) + rim * 0.25;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  float I = saturate(uIntensity);
  if (I <= 0.001) { fragColor = vec4(0.0); return; }

  vec2 C = uSize * 0.5;
  float sc = min(uSize.x, uSize.y);
  vec2 axis = C - uSource;
  float off = length(axis) / sc;                     // 0 when the star is centred
  // Fade when the source leaves the screen.
  vec2 outside = max(max(-uSource, uSource - uSize), vec2(0.0));
  float vis = 1.0 - smoothstep(0.0, 0.2 * sc, length(outside));
  // Ghosts collapse onto the star when it is centred — keep them quiet there.
  float ghostVis = mix(0.12, 1.0, smoothstep(0.03, 0.3, off));

  vec3 tint = toLinear(uTint.rgb);
  vec3 teal = mix(tint, vec3(0.25, 0.85, 0.95), 0.8);
  vec3 violet = mix(tint, vec3(0.6, 0.42, 1.0), 0.7);
  vec3 rose = mix(tint, vec3(1.0, 0.5, 0.55), 0.5);

  vec3 col = vec3(0.0);

  // ---------------- octagon ghosts ----------------
  // (t along source→centre axis, apothem as fraction of sc, ring-ness, colour, gain)
  for (int i = 0; i < 6; i++) {
    float fi = float(i);
    float tt = fi < 0.5 ? 0.42 : fi < 1.5 ? 0.74 : fi < 2.5 ? 1.12 : fi < 3.5 ? 1.42 : fi < 4.5 ? 1.86 : 2.3;
    float rr = fi < 0.5 ? 0.028 : fi < 1.5 ? 0.058 : fi < 2.5 ? 0.018 : fi < 3.5 ? 0.095 : fi < 4.5 ? 0.042 : 0.14;
    float ring = fi < 0.5 ? 0.0 : fi < 1.5 ? 0.55 : fi < 2.5 ? 0.0 : fi < 3.5 ? 0.8 : fi < 4.5 ? 0.2 : 0.35;
    float gain = fi < 0.5 ? 0.22 : fi < 1.5 ? 0.12 : fi < 2.5 ? 0.3 : fi < 3.5 ? 0.07 : fi < 4.5 ? 0.12 : 0.045;
    vec3 gc = fi < 0.5 ? tint : fi < 1.5 ? teal : fi < 2.5 ? violet : fi < 3.5 ? tint : fi < 4.5 ? rose : teal;
    vec2 gp = uSource + axis * tt;
    float r = rr * sc;
    vec2 d = frag - gp;
    // Cheap reject: most pixels are far from every ghost.
    if (dot(d, d) < lf_sq(r * 1.35 + 3.0)) {
      // Chromatic fringe: R slightly larger, B slightly smaller.
      float gr = lf_ghost(lf_octagon(d, r * 1.035), r * 1.035, ring);
      float gg = lf_ghost(lf_octagon(d, r), r, ring);
      float gb = lf_ghost(lf_octagon(d, r * 0.965), r * 0.965, ring);
      col += gc * vec3(gr, gg, gb) * gain;
    }
  }
  col *= ghostVis;

  // ---------------- anamorphic streak ----------------
  vec2 ds = frag - uSource;
  float thick = max(sc * 0.0022, 1.0);
  float streak = exp(-abs(ds.y) / thick) * (exp(-abs(ds.x) / (sc * 0.22)) * 0.5 + exp(-abs(ds.x) / (sc * 0.75)) * 0.18);
  streak += exp(-abs(ds.y) / (thick * 6.0)) * exp(-abs(ds.x) / (sc * 0.12)) * 0.06;
  vec3 streakC = mix(tint, vec3(0.62, 0.8, 1.0), 0.35 + 0.35 * smoothstep(0.0, sc * 0.5, abs(ds.x)));
  col += streakC * streak * 0.55;

  // ---------------- halo ring around the source ----------------
  float rs = length(ds);
  float hr = sc * 0.3;
  float hw = sc * 0.012;
  vec3 halo = vec3(exp(-lf_sq((rs - hr * 1.02) / hw)), exp(-lf_sq((rs - hr) / hw)), exp(-lf_sq((rs - hr * 0.98) / hw)));
  // Brighter on the side facing the screen centre, like a real halo artefact.
  float facing = dot(ds / max(rs, 1e-3), axis / max(length(axis), 1e-3));
  halo *= 0.55 + 0.45 * mix(1.0, saturate(facing * 0.5 + 0.5), smoothstep(0.03, 0.2, off));
  col += mix(tint, vec3(1.0), 0.3) * halo * 0.05;

  // ---------------- soft glare around the source ----------------
  col += tint * (exp(-rs / (sc * 0.05)) * 0.16 + exp(-rs / (sc * 0.12)) * 0.03);

  col *= I * vis;
  col = max(col - 0.0003, 0.0);                      // no veil over the whole frame
  vec3 g = toGamma(tonemapACES(col));
  float a = saturate(max(g.r, max(g.g, g.b)));
  g = dither(frag, g) * step(0.003, a);
  fragColor = vec4(min(g, vec3(a)), a);
}
