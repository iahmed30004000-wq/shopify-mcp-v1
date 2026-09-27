#version 460 core
#include <flutter/runtime_effect.glsl>
#include "lib/common.glsl"

// ---------------------------------------------------------------------------
// Prayer fire — a small golden oil-lamp flame burning on the tip of a prayer
// pointer once that prayer is prayed. Teardrop body with a white-gold heart,
// a faint blue root, swaying/flickering tip, detached tongues that lick
// upward, rising embers and a warm glow that spills onto the brass below.
// Tuned for 20–60 px tall flames.
//
// Uniforms (after common.glsl; sampler 0 = uNoise, the shared noise texture):
//   uSize       canvas size (px) — unused, kept for API symmetry.
//   uBase       flame root in px (the pointer tip), local canvas coords.
//   uAngle      direction the flame grows, radians in Flutter canvas space
//               (same convention as Offset.fromDirection: 0 = +x/right,
//               -pi/2 = up on screen).
//   uHeight     full flame height in px (at uIntensity = 1).
//   uTime       seconds.
//   uIntensity  0 = unlit (fully transparent), 0..1 = igniting (a blue bead
//               with a spark flash grows into the golden flame), 1 = full.
//   uColorA     outer flame colour (straight sRGB), e.g. #FFA43A.
//   uColorB     inner heart colour (straight sRGB), e.g. #FFF1C4.
// Draw rect: Rect.fromCircle(center: uBase + dir * uHeight * 0.4,
//                            radius: uHeight * 0.95).
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

float pf_sq(float x) { return x * x; }

// Teardrop distance (units of flame height). q: x across, y along, measured
// from the bulb centre; w = bulb radius, h = tip height above the bulb centre.
float pf_flame(vec2 q, float w, float h) {
  if (q.y <= 0.0) return length(q) - w;
  float k = saturate(q.y / h);
  float hw = w * pow(1.0 - k, 0.85) * (1.0 + 0.35 * k);
  float slope = w / h;
  float d = (abs(q.x) - hw) * inversesqrt(1.0 + slope * slope);
  return q.y > h ? length(vec2(q.x, q.y - h)) : d;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  float ign = saturate(uIntensity);
  if (ign <= 0.001) { fragColor = vec4(0.0); return; }

  float t = uTime;
  float H = max(uHeight, 1.0);
  vec2 dir = vec2(cos(uAngle), sin(uAngle));
  vec2 dp = frag - uBase;
  float u = dot(dp, dir) / H;                        // along the flame, 0 at the root
  float v = (dp.x * dir.y - dp.y * dir.x) / H;       // across
  float px = 1.0 / H;

  vec3 outer = toLinear(uColorA.rgb);
  vec3 inner = toLinear(uColorB.rgb);

  // --- growth & flicker ---
  float grow = smoothstep(0.0, 0.85, ign);
  float unsteady = 1.0 + (1.0 - grow) * 2.0;        // a young flame is restless
  float fl1 = noise2(vec2(t * 5.3, 1.1)) - 0.5;
  float fl2 = noise2(vec2(t * 11.7, 9.3)) - 0.5;
  float hF = mix(0.22, 0.86, grow) * (1.0 + (fl1 * 0.14 + fl2 * 0.06) * unsteady);
  float w = mix(0.075, 0.165, grow);
  float bulbC = w + 0.035;
  float sway = ((noise2(vec2(t * 1.3, 3.1)) - 0.5) * 0.16 + fl2 * 0.05) * unsteady;
  float kk = saturate((u - bulbC) / max(hF - bulbC, 0.05));
  // Ripples travelling up the body make the silhouette breathe.
  float rip = (noise3(vec3(v * 3.0, u * 5.0 - t * 7.0, t * 0.6)) - 0.5) * 0.05 * kk;
  vec2 q = vec2(v - sway * kk * kk - rip, u - bulbC);
  float d = pf_flame(q, w, hF - bulbC);

  // Heart: smaller, lower, steadier.
  vec2 qc = vec2(v - sway * kk * kk * 0.6, u - bulbC * 0.95);
  float dc = pf_flame(qc, w * 0.52, (hF - bulbC) * 0.5);

  // Two detached tongues licking upward off the tip.
  float tongue = 0.0;
  for (int i = 0; i < 2; i++) {
    float fi = float(i);
    float per = 0.55 + fi * 0.23;
    float ph = fract(t / per + fi * 0.5);
    // Elongated slivers that tear off the tip, stretch and thin as they rise.
    vec2 tq = vec2(v - sway * 1.2 - (fi - 0.5) * 0.06 * ph, u - (hF * (0.66 + 0.4 * ph)));
    float td = pf_flame(tq, w * 0.22 * (1.0 - ph * 0.55), 0.2 + 0.12 * ph);
    tongue += (1.0 - smoothstep(-0.012, 0.018, td)) * pf_sq(1.0 - ph) * smoothstep(0.0, 0.2, ph);
  }
  tongue *= grow;

  // --- colour ---
  float aa = max(px * 1.2, 0.012);
  // Soft envelope: crisp low on the body, feathered toward the tip.
  float feather = mix(aa, 0.05, kk);
  float body = 1.0 - smoothstep(-feather - 0.01, feather, d);
  float soft = 1.0 - smoothstep(-0.07, 0.0, d);
  float heart = 1.0 - smoothstep(-0.04, 0.035, dc);
  // Along the body: luminous gold low, deep orange-red at the flickering tip.
  vec3 tipC = outer * vec3(1.0, 0.42, 0.18);
  vec3 bodyC = mix(outer * vec3(1.0, 0.86, 0.62), tipC, smoothstep(0.2, 1.0, kk));
  // Edge envelope is thinner and redder than the core of the body.
  vec3 edgeC = outer * vec3(1.0, 0.5, 0.25);
  vec3 col = mix(edgeC * 0.8, bodyC * 1.25, soft) * body;
  col += inner * heart * mix(2.4, 1.2, kk);
  // Faint blue root (hot, oxygen-rich base of a real flame).
  float root = (1.0 - smoothstep(-0.02, 0.03, d)) * smoothstep(0.02, -0.05, q.y + w * 0.25)
             * smoothstep(-0.05, 0.0, -dc);
  col += vec3(0.15, 0.35, 1.0) * root * 0.9 * (0.4 + 0.6 * grow);
  col += mix(bodyC, tipC, 0.75) * tongue * (1.0 - body * 0.7) * 0.9;

  // Ignition: begins as a small blue bead, warming to gold.
  float blueStage = 1.0 - smoothstep(0.08, 0.55, ign);
  col = mix(col, vec3(0.2, 0.45, 1.0) * luma(col) * 1.6 + inner * heart * 0.35, blueStage * 0.85);

  // --- glow ---
  float dd = max(d, 0.0);
  vec3 glowC = mix(outer, inner, 0.25);
  vec3 glow = glowC * (exp(-dd / 0.045) * 0.45 + exp(-dd / 0.13) * 0.16) * (0.4 + 0.6 * grow);
  // Warm light pooling on the pointer tip.
  float rb = length(vec2(v, u + 0.02));
  glow += outer * exp(-rb / 0.1) * 0.3 * grow;
  // Breathing brightness.
  float breathe = 1.0 + fl1 * 0.18 + fl2 * 0.08;

  // Ignition spark: a brief 4+4 point glint at the wick while igniting.
  float spark = exp(-pf_sq((ign - 0.14) / 0.09));
  if (spark > 0.01) {
    vec2 sp = vec2(v, u - 0.05) * H;               // px from the spark
    vec2 a = abs(sp);
    float armL = H * 0.35;
    float g = exp(-a.y / 0.7) * saturate(1.0 - a.x / armL) + exp(-a.x / 0.7) * saturate(1.0 - a.y / armL)
            + exp(-dot(sp, sp) / (H * H * 0.004));
    glow += vec3(1.0, 0.92, 0.75) * g * spark * 1.6;
  }

  // --- embers ---
  vec3 emb = vec3(0.0);
  float emberAmt = smoothstep(0.45, 1.0, ign);
  if (emberAmt > 0.0) {
    for (int i = 0; i < 6; i++) {
      float fi = float(i);
      vec3 h = hash33(vec3(fi * 7.3 + 1.7, fi * 3.1 + 0.4, 5.9));
      float per = 1.4 + h.x * 1.3;
      float ph = fract(t / per + h.y);
      float cyc = floor(t / per + h.y);
      vec3 h2 = hash33(vec3(cyc, fi, 2.3));          // fresh path every cycle
      float eu = hF * 1.02 + ph * (0.4 + 0.35 * h2.x);
      float ev = (h2.y - 0.5) * 0.14 * ph + sin(t * (2.0 + h.z * 2.0) + fi) * 0.025 * ph + sway * 0.8;
      vec2 e = (vec2(v, u) - vec2(ev, eu)) * H;      // px
      float sz = max(0.9, H * 0.018);
      float b = exp(-dot(e, e) / (sz * sz)) * pf_sq(1.0 - ph) * smoothstep(0.0, 0.08, ph);
      b *= 0.6 + 0.4 * sin(t * 17.0 + fi * 3.0);    // twinkle
      emb += mix(inner * 1.2, outer * vec3(1.0, 0.45, 0.2), ph) * b * 2.2;
    }
  }

  vec3 total = (col + glow) * breathe + emb * emberAmt * (1.0 - body);
  total *= smoothstep(0.0, 0.12, ign);
  // Fade out before the draw rect edge (rect = centre ± 0.95 H).
  float rc = length(vec2(v, u - 0.4));
  total *= 1.0 - smoothstep(0.72, 0.93, rc);

  vec3 g = toGamma(tonemapACES(total));
  float a = saturate(max(g.r, max(g.g, g.b)));
  g = dither(frag, g) * step(0.002, a);
  fragColor = vec4(min(g, vec3(a)), a);
}
