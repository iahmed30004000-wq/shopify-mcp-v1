#version 460 core
#include <flutter/runtime_effect.glsl>
#include "lib/common.glsl"

// ---------------------------------------------------------------------------
// Lens flare — a restrained cinematic flare from the core star (or the sun),
// drawn over the whole scene: a soft glare, a gentle chromatic halo ring, a
// SHORT anamorphic streak (≈ 1.2× the home astrolabe's radius, exponential
// fade – never a hairline across the screen) and at most two soft ROUND
// ghosts at ≤ 4 % (no rims, no aperture polygons: nothing that reads as a
// CG shape). The ghosts vanish while the source sits near the screen centre
// and whenever the flare dims (fly-ins drive uIntensity to 0).
//
// Uniforms (after common.glsl; sampler 0 = uNoise — declared by the shared
// library; this shader only uses the ALU hash, but bind the noise image anyway):
//   uSize       canvas size (px). Draw rect: the full canvas (Offset.zero & size).
//   uSource     flare source in px (the core star centre, same canvas).
//   uIntensity  0..1 overall strength (0 = nothing). The flare is permanently
//               on screen on the home screen, so keep the resting value ≤ 0.4
//               (0.35 is a good default) and drive it UP from camera motion
//               (pans) and the core star's uPulse, e.g.
//               0.35 + 0.4 * motion + 0.25 * pulse, clamped to 1.
//   uTint       flare tint (straight sRGB), e.g. #FFD9A0.
// Blend: paint with BlendMode.plus (true additive); with the default srcOver
// the premultiplied output (alpha = max(rgb)) behaves like "screen".
// ---------------------------------------------------------------------------

uniform vec2 uSize;
uniform vec2 uSource;
uniform float uIntensity;
uniform vec4 uTint;

out vec4 fragColor;

float lf_sq(float x) { return x * x; }

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

  vec3 tint = toLinear(uTint.rgb);
  vec3 teal = mix(tint, vec3(0.35, 0.8, 0.95), 0.6);
  vec3 violet = mix(tint, vec3(0.62, 0.5, 1.0), 0.55);

  vec3 col = vec3(0.0);

  // ---------------- two soft round ghosts (≤ 4 %) ----------------
  // Only when the source is well off-centre and the flare is strong enough
  // to justify them; pure gaussians – no rim, no polygon.
  float ghostVis = smoothstep(0.12, 0.35, off) * smoothstep(0.25, 0.6, I);
  if (ghostVis > 0.001) {
    vec2 g1 = uSource + axis * 1.35;
    vec2 g2 = uSource + axis * 1.9;
    float r1 = sc * 0.05, r2 = sc * 0.085;
    col += teal * exp(-dot(frag - g1, frag - g1) / (r1 * r1)) * 0.04 * ghostVis;
    col += violet * exp(-dot(frag - g2, frag - g2) / (r2 * r2)) * 0.03 * ghostVis;
  }

  // ---------------- short anamorphic streak ----------------
  // Exponential fall-off along x (scale ≈ 0.12 sc ≈ half the home dial's
  // radius) with a hard window at ≈ 0.28 sc (≈ 1.2× that radius), and a
  // soft vertical profile a few pixels thick – a streak, not a scanline.
  vec2 ds = frag - uSource;
  float thick = max(sc * 0.004, 1.4);
  float along = exp(-abs(ds.x) / (sc * 0.1));
  float streak = exp(-lf_sq(ds.y / thick)) * along * 0.55 + exp(-abs(ds.y) / (thick * 4.0)) * along * along * 0.08;
  streak *= 1.0 - smoothstep(sc * 0.16, sc * 0.28, abs(ds.x));
  vec3 streakC = mix(tint, vec3(0.7, 0.84, 1.0), 0.3 + 0.3 * smoothstep(0.0, sc * 0.25, abs(ds.x)));
  col += streakC * streak * 0.5;

  // ---------------- halo ring around the source ----------------
  float rs = length(ds);
  float hr = sc * 0.3;
  float hw = sc * 0.014;
  vec3 halo = vec3(exp(-lf_sq((rs - hr * 1.02) / hw)), exp(-lf_sq((rs - hr) / hw)), exp(-lf_sq((rs - hr * 0.98) / hw)));
  // Brighter on the side facing the screen centre, like a real halo artefact.
  float facing = dot(ds / max(rs, 1e-3), axis / max(length(axis), 1e-3));
  halo *= 0.55 + 0.45 * mix(1.0, saturate(facing * 0.5 + 0.5), smoothstep(0.03, 0.2, off));
  col += mix(tint, vec3(1.0), 0.3) * halo * 0.035;

  // ---------------- soft glare around the source ----------------
  col += tint * (exp(-rs / (sc * 0.05)) * 0.16 + exp(-rs / (sc * 0.12)) * 0.03);

  col *= I * vis;
  col = max(col - 0.0003, 0.0);                      // no veil over the whole frame
  vec3 g = toGamma(tonemapACES(col));
  float a = saturate(max(g.r, max(g.g, g.b)));
  g = dither(frag, g) * step(0.003, a);
  fragColor = vec4(min(g, vec3(a)), a);
}
