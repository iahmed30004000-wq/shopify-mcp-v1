#version 460 core
#include <flutter/runtime_effect.glsl>
#include "lib/common.glsl"

// FAMILY — "Terracotta": a warm desert homeworld of layered mesas and
// dendritic canyons under a dusty-rose sky.
//   thriving : green oases along canyon floors and sand-sea shores + glinting
//              rivers, warmer & more saturated rock, a denser rosy halo, warm
//              lamplit hearths twinkling on the night side like family homes,
//              soft amber-rose aurora curtains, sun-glint sparkles.
//   neglected: sandstorms, bleached, dimmer, desaturated rock, dry-earth (mud)
//              crack networks with faint embers at night, red distress pulse.
// The family's people orbit as moons (drawn separately), so surface contrast
// is kept moderate for readability behind small bright discs.
//
// FAMILY LOOK (common.glsl): lifeGrade (thriveGrade + neglectGrade) on the lit
// surface, the shared forward-scatter haze/halo (atmoHaze/atmoHalo, density ×
// haloGain), the shared soft aurora curtains (warm amber → rose, half gain),
// the limb shock ring for uPulse, the shared distress rim/halo and
// compositeDiscHalo. Strata are tilted (dipping layers) so the colour bands
// cross the terrace contours instead of tracing them.
//
// uExtra: x = hearth density multiplier (0 → default 1.0; 0.5..2 sensible,
//             e.g. family size / 4)
//         y, z, w unused.
// haloFactor: 1.35 (aurora curtains and the pulse ring stay inside it).
uniform vec2 uSize;
uniform vec2 uCenter;
uniform float uRadius;
uniform float uTime;
uniform vec3 uLight;
uniform float uScore;
uniform float uPulse;
uniform vec3 uSpin;
uniform vec4 uColorA;
uniform vec4 uColorB;
uniform vec4 uColorC;
uniform float uDetail;
uniform float uSeed;
uniform vec4 uExtra;

out vec4 fragColor;

// Cube-sphere face coordinates: uv in [-1,1], face id 0..5.
vec2 tc_cube(vec3 x, out float face) {
  vec3 a = abs(x);
  if (a.x >= a.y && a.x >= a.z) { face = x.x > 0.0 ? 0.0 : 1.0; return x.yz / a.x; }
  if (a.y >= a.z) { face = x.y > 0.0 ? 2.0 : 3.0; return x.xz / a.y; }
  face = x.z > 0.0 ? 4.0 : 5.0;
  return x.xy / a.z;
}

vec3 tc_sat(vec3 c, float s) { return max(mix(vec3(luma(c)), c, s), 0.0); }

// Terrain: stratified sandstone terraces (each terrace a soft step), sand
// seas pooled in the basins, meandering rift canyons.
// Returns height; `tb` terrace coordinate, `sea` sand-sea mask, `canyon` 0..1,
// `cd` distance to the canyon centre line (field units).
float tc_height(vec3 x, float warp, float fine, float aa, out float tb, out float sea, out float canyon, out float cd) {
  vec3 y = x * 1.35 + warp;
  float b = fbm3lo(y);
  if (fine > 0.0) {
    b += ((noise3(y * 6.1 + 5.0) - 0.5) * 0.1 + (noise3(y * 13.7 + 9.0) - 0.5) * 0.05) * fine;
  }
  tb = b * 9.0;
  float fr = fract(tb);
  float w = clamp(aa * 9.0, 0.09, 0.5);          // crisp risers (mesa cliffs, not wax)
  float terr = (floor(tb) + smoothstep(0.5 - w, 0.5 + w, fr)) / 9.0;
  sea = 1.0 - smoothstep(0.395 - aa, 0.395 + aa + 0.01, b);
  float cn = fbm3lo(x * 2.1 + warp * 0.8 + vec3(11.0, 3.0, 7.0));
  float cw = 0.022 * smoothstep(0.3, 0.7, noise3(x * 2.6 + 21.0)) + 0.003;
  cd = abs(cn - 0.5);
  canyon = (1.0 - smoothstep(cw * 0.25, cw + aa * 0.6, cd)) * (1.0 - sea);
  return mix(terr, 0.395, sea) * 0.5 - canyon * 0.007;
}

// One layer of settlement lights on a cube-sphere grid (one hash per pixel).
// Blends toward the layer's average emission when cells shrink below a few
// pixels (no shimmer at overview scale).
float tc_lights(vec2 uv, float face, float cells, float want, float pxUv, float t, float sz, float glowAmt) {
  vec2 g = uv * cells;
  vec2 id = floor(g);
  vec2 f = fract(g);
  vec2 h = hash22(id + face * 31.7 + uSeed * 7.3);
  float key = hash12(id.yx * 1.37 + face * 5.1 + uSeed);
  float on = smoothstep(key, key + 0.1, want);
  vec2 c = 0.2 + 0.6 * h;
  float d = length(f - c) / cells;                 // distance in uv units
  float s0 = sz * (0.55 + 0.9 * h.x * h.x);
  float s = max(s0, pxUv * 0.6);
  float core = exp(-d * d / (s * s)) * (s0 * s0) / (s * s);
  float gs = 0.07 / cells;
  float glow = exp(-d * d / (gs * gs)) * glowAmt;
  float tw = 0.7 + 0.3 * sin(t * (1.1 + 2.3 * h.y) + key * 60.0) * sin(t * (0.6 + h.x) + h.y * 20.0);
  float pt = (core + glow) * tw * on;
  float avg = want * (s0 * s0 * 1.4 + gs * gs * glowAmt) * PI * cells * cells * 0.25;
  float lod = smoothstep(2.0, 6.0, 1.0 / (cells * pxUv));
  return mix(avg, pt, lod);
}

// Dry-earth crack network (two scales of cellular edges).
float tc_cracks(vec3 q, float fine) {
  vec2 v = voronoi3(q * 6.0);
  float c = 1.0 - smoothstep(0.0, 0.035, v.y - v.x);
  if (fine > 0.0) {
    vec2 w = voronoi3(q * 17.0 + 3.0);
    c = max(c, (1.0 - smoothstep(0.0, 0.04, w.y - w.x)) * 0.5 * fine);
  }
  return c;
}

// Conservative screen-space bound of the shared aurora curtains: every sheet
// point X = rho·(±c·A + s·w) (w ⟂ A, rho ∈ [1, 1+AURORA_H], c = ovalY ± 0.03)
// projects inside one of two flat ellipses around the projected ovals, so
// outside them auroraCurtains() returns exactly 0 and the call (1 noise tap +
// the quadratic, up to 7 taps) can be skipped with no visible change.
bool tc_auroraNear(vec2 p, mat3 rot, float ovalY, float px) {
  vec3 A = vec3(0.0, 1.0, 0.0) * rot;              // spin axis in view space (as auroraCurtains)
  float a2l = length(A.xy);
  vec2 e1 = a2l > 1e-4 ? A.xy / a2l : vec2(0.0, 1.0);
  float cLo = ovalY - 0.031;
  float cHi = min(ovalY + 0.031, 1.0);
  float sMax = sqrt(max(1.0 - cLo * cLo, 0.0));
  float R = 1.0 + AURORA_H;
  float m = 3.0 * px + 0.01;
  float S = R * sMax + m;                          // semi-axis across the axis
  float Y = R * sMax * abs(A.z) + m;               // semi-axis along the projected axis
  float u = abs(dot(p, e1));                       // both hemispheres by symmetry
  float v = dot(p, vec2(-e1.y, e1.x));
  float du = u - clamp(u, cLo * a2l, R * cHi * a2l);
  return du * du / (Y * Y) + v * v / (S * S) <= 1.0;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 p = (frag - uCenter) / uRadius;
  p.y = -p.y;
  float r = length(p);
  float px = 1.0 / uRadius;
  vec3 l = normalize(uLight);
  float t = uTime;
  float th = thrive(uScore);
  float ng = neglect(uScore);
  float live = smoothstep(0.1, 1.0, uScore);          // continuous 0..1 vitality

  vec3 cA = toLinear(uColorA.rgb);
  vec3 cB = toLinear(uColorB.rgb);
  vec3 cC = toLinear(uColorC.rgb);
  vec3 rose = toLinear(vec3(0.9, 0.5, 0.5));
  vec3 atmoCol = mix(mix(cB, rose, 0.6), toLinear(vec3(0.62, 0.55, 0.48)), ng * 0.6);
  // aurora: warm amber base → dusty-rose top (never yellow-green: dim yellow reads olive)
  vec3 auBase = mix(cB, vec3(1.0, 0.62, 0.28), 0.8);
  vec3 auTop = mix(cB, toLinear(vec3(0.95, 0.42, 0.5)), 0.75);
  vec3 flareCol = mix(cB, auBase, 0.5);
  float pulseD = distressPulse(t) * ng;

  mat3 rot = rotY(uSpin.x + t * 0.018) * rotX(uSpin.y);
  // shared atmosphere (disc haze + halo use the same parameters)
  float phase = atmoPhase(l);
  float gain = 2.0 * haloGain(th, ng) * (1.0 + 0.5 * uPulse);
  float tau0 = 0.04 * (1.0 + 1.2 * ng);
  float fine = smoothstep(0.2, 0.45, uDetail);

  // shared aurora curtains, evaluated once for disc and halo (half the family gain)
  float auK = (th * 0.9 + uPulse * 0.8) * 0.5 * mix(0.35, 1.0, smoothstep(22.0, 60.0, uRadius));
  vec2 au = (auK > 0.001 && tc_auroraNear(p, rot, 0.915, px)) ? auroraCurtains(p, rot, l, 0.915, t, px) * auK : vec2(0.0);
  vec3 auC = mix(auBase, auTop, saturate(au.y / max(au.x, 1e-4) * 2.0)) * au.x * 0.22;

  float discA = discMask(p, uRadius);
  vec3 col = vec3(0.0);

  if (discA > 0.0) {
    // Clamp to the disc so the anti-aliased rim is shaded (no dark seam).
    vec2 pd = p * min(1.0, 0.9995 / max(r, 1e-4));
    vec3 n = sphereNormal(pd);
    vec3 q = rot * n;
    vec3 ql = rot * l;
    vec3 x = q + uSeed * vec3(0.37, 0.71, 0.53);
    float mu = n.z;
    float ndl = dot(n, l);
    float pxObj = 1.0 / (uRadius * max(mu, 0.05));
    float resolve = smoothstep(1.2, 3.5, 0.03 / pxObj);   // can we resolve ~0.03-unit features?

    // ---- terrain ----
    float warp = fbm3lo(x * 1.1 + vec3(20.0, 4.0, 9.0)) * 1.25;
    float aa = pxObj * 2.0;
    float tb, sea, canyon, cd;
    float h = tc_height(x, warp, fine, aa, tb, sea, canyon, cd);
    vec3 lt = ql - q * dot(ql, q);
    float ltLen = length(lt);
    // relief bump: a second terrain evaluation, skipped below 60 px (invisible there)
    float slope = 0.0;
    float bumpK = smoothstep(60.0, 72.0, uRadius);
    if (bumpK > 0.0) {
      float eps = 0.008;
      float tb2, s2, c2, cd2;
      float h2 = tc_height(x + lt / max(ltLen, 1e-4) * eps, warp, fine, aa, tb2, s2, c2, cd2);
      slope = (h2 - h) / eps * bumpK;                    // rise toward the light
    }
    float lod40 = smoothstep(2.0, 5.0, 1.0 / (40.0 * pxObj));      // fade detail before it aliases
    float lod115 = smoothstep(2.0, 5.0, 1.0 / (115.0 * pxObj));
    float grain = mix(0.5, fine > 0.0 ? noise3(x * 40.0) : 0.5, lod40);
    float region = noise3(x * 2.3 + 13.0);

    // Palette: terracotta strata, cream & rust bands, peach sand seas, umber canyons.
    vec3 sand = tc_sat(mix(cA, cB, 0.24), 1.15) * 0.9;
    vec3 terra = tc_sat(cA, 1.1);
    vec3 red = tc_sat(mix(cA, cC, 0.28), 1.2);
    vec3 rust = tc_sat(mix(cA, cC, 0.5), 1.1);
    vec3 cream = mix(cA, cB, 0.62);
    vec3 umber = mix(cA, cC, 0.7);
    // strata: dipping layers. The colour coordinate is the terrace coordinate
    // plus a low-frequency tilt (a plane through the crust, gently warped), so
    // the bands cut across the terrace contours like eroded cuestas instead of
    // tracing iso-lines of the same fbm (the old "melted wax" marbling).
    float tilt = dot(x, vec3(0.62, 1.55, -0.48)) + (noise3(x * 0.7 + 17.0) - 0.5) * 1.6;
    float sb = tb * 0.9 + tilt * 1.7;
    float band = floor(sb);
    float bw = clamp(aa * 20.0, 0.1, 0.5);
    float bmix = smoothstep(0.5 - bw, 0.5 + bw, fract(sb));
    float bh0 = hash12(vec2(band + 40.0, 3.0 + floor(uSeed)));
    float bh1 = hash12(vec2(band + 41.0, 3.0 + floor(uSeed)));
    vec3 s0 = bh0 < 0.4 ? terra : (bh0 < 0.62 ? red : (bh0 < 0.8 ? rust : (bh0 < 0.92 ? cream : sand)));
    vec3 s1 = bh1 < 0.4 ? terra : (bh1 < 0.62 ? red : (bh1 < 0.8 ? rust : (bh1 < 0.92 ? cream : sand)));
    vec3 strata = mix(s0, s1, bmix);
    // terrace risers: the step faces are a shade darker than the treads
    float riser = smoothstep(0.3, 0.5, fract(tb)) * (1.0 - smoothstep(0.5, 0.7, fract(tb)));
    strata *= 1.0 - 0.18 * riser * lod40;
    strata = mix(strata, umber, smoothstep(0.55, 0.85, warp * 0.75) * 0.4);   // dark iron regions
    // linear dune fields: long parallel crests bent by the wind field
    float duneC = uDetail > 0.6 ? abs(fract(dot(x, vec3(31.0, 67.0, 23.0)) + warp * 6.0 + noise3(x * 9.0) * 2.5) - 0.5) * 2.0 : 0.5;
    vec3 dunes = mix(sand * 0.86, sand * 1.04, smoothstep(0.3, 0.7, region)) * (1.0 + (duneC - 0.5) * 0.04 * lod115);
    dunes = mix(dunes, tc_sat(mix(cA, cC, 0.35), 1.1) * 0.9, smoothstep(0.55, 0.8, noise3(x * 4.2 + warp + 31.0)) * 0.55);   // dark dune fields
    vec3 rock = mix(strata, dunes, sea);
    rock = mix(rock, umber * 0.7, canyon * 0.8);
    rock *= 0.92 + 0.16 * grain;
    if (uDetail > 0.6) rock *= 1.0 + (noise3(x * 115.0 + 3.0) - 0.5) * 0.12 * lod115;
    // Pale pink salt/frost caps near the poles.
    float cap = smoothstep(0.93, 0.985, abs(q.y) + (warp - 0.6) * 0.05);
    rock = mix(rock, mix(sand, vec3(0.86, 0.74, 0.7), 0.35), cap * 0.55);

    // Thriving: wide oases along the canyon floors and the shores of the sand
    // seas (a low-frequency green-olive cue that survives at 22 px), rivers.
    float shore = sea * (1.0 - sea) * 4.0;
    float oasis = th * max(smoothstep(0.15, 0.6, canyon), shore * 0.6) * smoothstep(0.28, 0.55, noise3(x * 7.0 + 2.0)) * (1.0 - cap);
    vec3 green = toLinear(vec3(0.27, 0.48, 0.18));
    vec3 albedo = mix(rock, green * 0.5, oasis * 0.85);
    float river = th * (1.0 - smoothstep(0.0012, 0.0012 + aa * 0.6, cd)) * canyon * (1.0 - cap) * resolve;
    albedo = mix(albedo, toLinear(vec3(0.1, 0.2, 0.22)), river * 0.7);

    // Neglect: bleached (desaturated) rock. No brightener: the shared
    // neglectGrade below makes the neglected world dimmer AND greyer.
    albedo = mix(albedo, mix(vec3(luma(albedo)), albedo, 0.4), ng * 0.8);

    // ---- lighting ----
    float kb = 0.16;
    float ndlB = ndl - kb * slope * ltLen * (1.0 - cap * 0.8);
    float lam = saturate(ndlB);
    float ls = 2.0 * lam / (lam + max(mu, 0.05) + 0.05);      // Lommel-Seeliger (dusty regolith)
    float diff = mix(lam, ls * 0.5, 0.3) * smoothstep(-0.06, 0.08, ndl + 0.02);
    vec3 sunCol = vec3(1.0, 0.93, 0.84) * mix(1.5, 1.25, ng) * (1.0 + uPulse * 0.12);
    vec3 sky = atmoCol * 0.05 * smoothstep(-0.25, 0.4, ndl);
    vec3 lit = albedo * (sunCol * diff + sky);
    vec3 hv = normalize(l + vec3(0.0, 0.0, 1.0));
    float nh = saturate(dot(n, hv));
    lit += vec3(1.0, 0.88, 0.7) * river * pow(nh, 16.0) * 0.5 * smoothstep(0.0, 0.2, ndl);
    float night = 1.0 - smoothstep(-0.18, 0.1, ndl);

    // Sandstorms: ochre fronts that swallow the terrain.
    float dust = 0.0;
    if (ng > 0.001) {
      dust = smoothstep(0.05, 0.7, dustStorm(x * 1.3, t * 1.6)) * smoothstep(0.0, 0.6, ng);
      vec3 dustCol = toLinear(vec3(0.72, 0.56, 0.38));
      vec3 dl = dustCol * (sunCol * saturate(ndl * 0.9 + 0.1) * (0.8 + 0.3 * dust) + sky * 2.0);
      lit = mix(lit, dl, dust * 0.8);
    }

    // Dry-earth cracks (neglect) darken the ground; embers glow in them below.
    float ck = 0.0;
    if (ng > 0.02) {
      // the fine second voronoi is skipped below 120 px (it cannot resolve there)
      ck = tc_cracks(x, fine * smoothstep(0.5, 0.9, ng) * smoothstep(120.0, 140.0, uRadius));
      ck *= smoothstep(0.2, 0.75, ng) * (1.0 - cap * 0.7) * resolve;
      ck *= smoothstep(0.4, 0.7, noise3(x * 2.5 + 40.0));     // patchy, not a uniform net
      lit *= 1.0 - ck * 0.45;
    }

    // Family living-state grade: after surface lighting, before emission.
    lit = lifeGrade(lit, th, ng);

    // ---- night side: family hearths ----
    float face;
    vec2 uv = tc_cube(q, face);
    float pxUv = pxObj * 1.2;
    float fert = smoothstep(0.5, 0.78, noise3(x * 3.4 + 7.0) * 0.7 + noise3(x * 9.0) * 0.3);
    fert *= (1.0 - cap) * (1.0 - canyon * 0.6) * (1.0 - dust) * (1.0 - sea * 0.7);
    float dens = uExtra.x > 0.0 ? uExtra.x : 1.0;
    float want = saturate(fert * mix(0.1, 0.95, live) * dens + uPulse * 0.35 * fert);
    float towns = tc_lights(uv, face, 9.0, want * 0.9, pxUv, t, 0.0045, 0.35);
    float homes = tc_lights(uv + 0.37, face, 26.0, want * 1.1, pxUv, t * 1.3, 0.0022, 0.0);
    float hearth = towns * 2.6 + homes * 1.6 + want * want * 0.05;   // + warm regional glow
    vec3 hearthCol = mix(toLinear(vec3(1.0, 0.6, 0.26)), cB, 0.3);
    float nightVis = smoothstep(0.0, -0.3, ndl);
    // failing, guttering hearths when neglected
    float fail = ng > 0.001 ? mix(1.0, 0.25 + 0.75 * step(0.5, noise3(vec3(uv * 9.0, t * 1.7))), ng) : 1.0;
    vec3 emit = hearthCol * hearth * nightVis * fail * (0.9 + 1.3 * th) * (1.0 + uPulse);

    // Twinkling day-side sparkles (sun on water & glass) when thriving.
    vec2 sgf = uv * 40.0;
    vec2 sg = floor(sgf);
    float sh = hash12(sg + face * 13.0);
    float sph = fract(t * 0.3 + sh * 7.0);
    float sd = length(fract(sgf) - 0.5) / 40.0;
    float ss = max(0.0015, pxUv * 0.6);
    float spk = step(0.985, hash12(sg * 1.3 + face)) * smoothstep(0.0, 0.08, sph) * (1.0 - smoothstep(0.08, 0.3, sph));
    spk *= exp(-sd * sd / (ss * ss)) * (0.0015 * 0.0015) / (ss * ss);
    emit += vec3(1.0, 0.94, 0.82) * spk * (th + uPulse) * smoothstep(0.15, 0.5, ndl) * (1.0 - cap) * 3.0 * (oasis + river + 0.3);

    // faint embers in the cracks, breathing with the distress pulse
    emit += distressColor() * ck * (0.03 + 0.3 * night) * (0.35 + 0.65 * pulseD) * 0.45;

    // ---- shared atmosphere: aerial perspective + in-scatter (dusty extinction) ----
    vec3 T;
    vec3 S = atmoHaze(mu, ndl, atmoCol, tau0, vec3(0.7, 1.0, 1.35), gain, phase, T);
    // warm terminator band (sunset light scattering)
    float term = exp(-ndl * ndl / 0.015) * smoothstep(-0.25, 0.05, ndl);
    S += toLinear(vec3(1.0, 0.5, 0.32)) * term * 0.07 * (1.0 - ng * 0.5);
    col = (lit + emit) * T + S;
    // shared aurora, distress rim, celebration flourish (rim flash)
    col += auC;
    col += distressColor() * distressRim(mu, pulseD);
    col += flareCol * uPulse * pow(1.0 - saturate(mu), 3.0) * 0.45;
  }

  // ---- halo: shared forward-scatter halo + aurora + limb shock + distress ----
  vec3 halo = atmoHalo(p, l, atmoCol, tau0, 0.035, gain, phase, px);
  halo += auC;
  halo += flareCol * limbShock(r, uPulse, px) * 0.6;
  halo += distressColor() * distressHalo(r, pulseD, px);

  fragColor = compositeDiscHalo(col, discA, halo, frag);
}
