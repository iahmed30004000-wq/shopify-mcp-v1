#version 460 core
#include <flutter/runtime_effect.glsl>
#include "lib/common.glsl"

// ---------------------------------------------------------------------------
// Prayer fire — a crown of golden fire around a prayer's star-point once the
// prayer is prayed: a ring of thin flame filaments (gold at the root, orange
// toward their flickering tips) radiating from the star, bending in a heat
// shimmer, tallest on the side they rise toward, with embers drifting off
// and a soft glow pooling on the brass. Never a candle – a jewel on fire.
//
// Uniforms (after common.glsl; sampler 0 = uNoise, the shared noise texture;
// the contract is unchanged, the meaning of two of them refined):
//   uSize       canvas size (px) — unused, kept for API symmetry.
//   uBase       centre of the star-point (px, local canvas coords).
//   uAngle      direction the fire leans / rises (radians, Flutter canvas
//               space: 0 = +x, -pi/2 = up on screen).
//   uHeight     crown size (px): filaments start at 0.3 H and reach up to
//               ~0.85 H. The painter sizes it by the dial's detail level.
//   uTime       seconds.
//   uIntensity  0 = unlit (fully transparent), 0..1 = igniting (a spark ring
//               kindles, the filaments grow), 1 = full.
//   uColorA     outer / tip colour (straight sRGB), e.g. #F28A3A.
//   uColorB     root / heart colour (straight sRGB), e.g. #FFE7A3.
// Draw rect: Rect.fromCircle(center: uBase, radius: uHeight).
// Output: premultiplied, alpha = max(rgb) → composites like "screen".
// ---------------------------------------------------------------------------

uniform vec2 uSize;
uniform vec2 uBase;
uniform float uAngle;
uniform float uHeight;
uniform float uTime;
uniform float uIntensity;
uniform vec4 uColorA;
uniform vec4 uColorB;

out vec4 fragColor;

const float PF_N = 12.0;       // filaments round the crown

float pf_sq(float x) { return x * x; }

void main() {
  vec2 frag = FlutterFragCoord().xy;
  float ign = saturate(uIntensity);
  if (ign <= 0.001) { fragColor = vec4(0.0); return; }

  float t = uTime;
  float H = max(uHeight, 1.0);
  vec2 p = frag - uBase;                          // px
  float r = length(p);
  vec2 n = p / max(r, 1e-4);
  vec2 rise = vec2(cos(uAngle), sin(uAngle));
  float up = dot(n, rise);                        // 1 toward where the fire rises
  float a = atan(p.y, p.x);

  vec3 tipC = toLinear(uColorA.rgb);
  vec3 rootC = toLinear(uColorB.rgb);
  float grow = smoothstep(0.1, 0.9, ign);

  float r0 = 0.3 * H;                             // the star-point's rim
  // A crown: tall filaments on the side the fire rises toward, short
  // licks below (never a symmetric sunburst).
  float reach = 0.62 * H * mix(0.35, 1.0, grow) * (0.22 + 0.78 * smoothstep(-0.45, 0.85, up));
  float along = (r - r0) / reach;                 // 0 at the root … 1 at full length

  // --- filaments ---
  // Heat shimmer: the angular coordinate wavers, more toward the tips.
  float sh = (noise3(vec3(along * 2.4 - t * 3.1, a * 1.7, t * 0.7)) - 0.5) * 0.9 * saturate(along);
  float fa = a * PF_N / TAU + sh * 0.5;
  float cell = floor(fa + 0.5);
  float da = fa - cell;                           // -0.5 … 0.5 across a filament's sector
  vec3 hc = hash33(vec3(cell, 3.7, 1.1));
  // Each filament curls a little to one side and flickers in length.
  da -= (hc.x - 0.5) * 0.5 * pf_sq(saturate(along));
  float flick = 0.55 + 0.45 * noise2(vec2(t * (2.3 + hc.y * 2.0), cell * 7.1));
  float len = mix(0.45, 1.0, hc.z) * flick;
  float lateral = abs(da) * TAU / PF_N * max(r, r0);        // px from the filament's axis
  float width = max(0.55, H * 0.028) * (1.0 - 0.75 * saturate(along / max(len, 0.05)));
  float fil = exp(-pf_sq(lateral / width))
            * smoothstep(-0.05, 0.08, along)
            * (1.0 - smoothstep(len * 0.55, len, along));
  vec3 filC = mix(rootC * 1.3, tipC, smoothstep(0.05, 0.85, along / max(len, 0.05)));

  // --- the ring of fire hugging the star-point ---
  float ring = exp(-abs(r - r0) / max(0.8, H * 0.035)) * (0.55 + 0.25 * noise2(vec2(a * 5.0, t * 2.2)));
  // --- glow pooling on the brass ---
  float glow = exp(-max(r - r0 * 0.6, 0.0) / (H * 0.2)) * 0.28;

  // --- embers drifting off the crown ---
  vec3 emb = vec3(0.0);
  float emberAmt = smoothstep(0.5, 1.0, ign);
  float nEmb = H < 20.0 ? 3.0 : 5.0;
  for (int i = 0; i < 5; i++) {
    float fi = float(i);
    vec3 h = hash33(vec3(fi * 7.3 + 1.7, fi * 3.1 + 0.4, 5.9));
    float per = 1.3 + h.x * 1.2;
    float ph = fract(t / per + h.y);
    float cyc = floor(t / per + h.y);
    vec3 h2 = hash33(vec3(cyc, fi, 2.3));
    // leave the crown toward the rising side, spread around it
    float ea = uAngle + (h2.x - 0.5) * 2.4;
    vec2 ed = vec2(cos(ea), sin(ea));
    vec2 epos = ed * (r0 + ph * H * (0.55 + 0.35 * h2.y)) + rise * ph * H * 0.12;
    vec2 e = p - epos;
    float sz = max(0.7, H * 0.022);
    float b = exp(-dot(e, e) / (sz * sz)) * pf_sq(1.0 - ph) * smoothstep(0.0, 0.1, ph);
    b *= 0.6 + 0.4 * sin(t * 17.0 + fi * 3.0);
    b *= step(fi, nEmb - 0.5);
    emb += mix(rootC * 1.2, tipC, ph) * b * 2.0;
  }

  // --- ignition: a spark ring kindling ---
  float spark = exp(-pf_sq((ign - 0.2) / 0.12));
  float sparkRing = exp(-pf_sq((r - r0 * (0.8 + ign * 1.2)) / max(0.8, H * 0.04))) * spark;

  float breathe = 1.0 + (noise2(vec2(t * 4.1, 2.3)) - 0.5) * 0.25;
  vec3 col = filC * fil * 1.25 * grow
           + mix(rootC, tipC, 0.35) * ring * (0.4 + 0.6 * grow)
           + mix(tipC, rootC, 0.3) * glow * grow
           + emb * emberAmt
           + rootC * sparkRing * 1.2;
  col *= breathe * smoothstep(0.0, 0.1, ign);
  // Nothing inside the star-point itself (the brass star shows), nothing at
  // the draw rect's edge.
  col *= smoothstep(r0 * 0.55, r0 * 0.9, r) * (1.0 - smoothstep(0.82 * H, 0.98 * H, r));

  vec3 g = toGamma(tonemapACES(col));
  float alpha = saturate(max(g.r, max(g.g, g.b)));
  g = dither(frag, g) * step(0.002, alpha);
  fragColor = vec4(min(g, vec3(alpha)), alpha);
}
