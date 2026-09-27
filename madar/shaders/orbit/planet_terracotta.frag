#version 460 core
#include <flutter/runtime_effect.glsl>
#include "lib/common.glsl"

// FAMILY — "Terracotta": a warm desert homeworld of layered mesas and
// dendritic canyons under a dusty-rose sky.
//   thriving : green oases + glinting rivers in the canyons, warm lamplit
//              hearths twinkling on the night side like family homes, a soft
//              golden aurora, gentle warm airglow, sun-glint sparkles.
//   neglected: sandstorms, bleached desaturated rock, dry-earth (mud) crack
//              networks with faint embers at night, red distress pulse.
// The family's people orbit as moons (drawn separately), so surface contrast
// is kept moderate for readability behind small bright discs.
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
  tb = b * 15.0;
  float fr = fract(tb);
  float w = clamp(aa * 15.0, 0.16, 0.5);
  float terr = (floor(tb) + smoothstep(0.5 - w, 0.5 + w, fr)) / 15.0;
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

// Golden aurora: a thin folded ribbon on the auroral oval of both poles
// (object space, y = spin axis). Bright equatorward edge, short poleward fade.
float tc_aurora(vec3 q, float t, float px) {
  vec2 dir = normalize(q.xz + 1e-4);
  float hemi = q.y > 0.0 ? 1.0 : -1.0;
  float ay = abs(q.y);
  float wob = (noise3(vec3(dir * 1.6, t * 0.05 + hemi * 5.0)) - 0.5) * 0.06
            + (noise3(vec3(dir * 6.5, t * 0.12 + hemi * 2.0)) - 0.5) * 0.018;   // curtain folds
  float d = ay - (0.915 + wob);
  // ribbon widens (and dims) when it would be thinner than ~1.5 px: no aliasing at overview scale
  float wEq = max(0.0045, px);
  float wPo = max(0.005, px * 0.8);
  float k = 0.0045 / wEq;
  float band = (d < 0.0 ? exp(-d * d / (wEq * wEq)) : exp(-d / wPo)) * k;
  float rays = noise3(vec3(dir * 30.0, t * 0.25 + hemi * 3.0));
  float drift = smoothstep(0.25, 0.65, noise3(vec3(dir * 2.4 + t * 0.03, hemi * 9.0)));
  return band * (0.65 + 0.35 * rays) * (0.2 + 0.8 * drift);
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

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 p = (frag - uCenter) / uRadius;
  p.y = -p.y;
  float r = length(p);
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
  vec3 auroraCol = mix(cB, toLinear(vec3(1.0, 0.78, 0.3)), 0.7);
  vec3 distressCol = toLinear(vec3(1.0, 0.2, 0.12));
  float pulseD = distressPulse(t) * ng;

  mat3 rot = rotY(uSpin.x + t * 0.018) * rotX(uSpin.y);
  float phase = 0.7 + 3.0 * pow(saturate(0.5 - 0.5 * l.z), 5.0);   // forward scattering
  float atmoGain = mix(0.6, 1.0, live) * (1.0 + uPulse * 0.5);
  const float tauAtm = 0.04;
  float fine = smoothstep(0.2, 0.45, uDetail);

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
    float eps = 0.008;
    float tb2, s2, c2, cd2;
    float h2 = tc_height(x + lt / max(ltLen, 1e-4) * eps, warp, fine, aa, tb2, s2, c2, cd2);
    float slope = (h2 - h) / eps;                       // rise toward the light
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
    // strata: colour switches exactly at the terrace step (anti-aliased blend)
    float band = floor(tb);
    float bw = clamp(aa * 15.0, 0.16, 0.5);
    float bmix = smoothstep(0.5 - bw, 0.5 + bw, fract(tb));
    float bh0 = hash12(vec2(band + 40.0, 3.0 + floor(uSeed)));
    float bh1 = hash12(vec2(band + 41.0, 3.0 + floor(uSeed)));
    vec3 s0 = bh0 < 0.4 ? terra : (bh0 < 0.62 ? red : (bh0 < 0.8 ? rust : (bh0 < 0.92 ? cream : sand)));
    vec3 s1 = bh1 < 0.4 ? terra : (bh1 < 0.62 ? red : (bh1 < 0.8 ? rust : (bh1 < 0.92 ? cream : sand)));
    vec3 strata = mix(s0, s1, bmix);
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

    // Thriving: oases along canyon floors and the shores of the sand seas, glinting rivers.
    float shore = sea * (1.0 - sea) * 4.0;
    float oasis = th * max(smoothstep(0.15, 0.6, canyon), shore * 0.35) * smoothstep(0.4, 0.65, noise3(x * 7.0 + 2.0)) * (1.0 - cap);
    vec3 green = toLinear(vec3(0.3, 0.44, 0.16));
    vec3 albedo = mix(rock, green * 0.42, oasis * 0.85);
    float river = th * (1.0 - smoothstep(0.0012, 0.0012 + aa * 0.6, cd)) * canyon * (1.0 - cap) * resolve;
    albedo = mix(albedo, toLinear(vec3(0.1, 0.2, 0.22)), river * 0.7);

    // Neglect: bleached, desaturated, pale.
    vec3 bleach = mix(vec3(luma(albedo)), albedo, 0.4) * 1.2 + vec3(0.02, 0.016, 0.012);
    albedo = mix(albedo, bleach, ng * 0.8);

    // ---- lighting ----
    float kb = 0.22;
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
      vec3 dustCol = toLinear(vec3(0.78, 0.6, 0.38));
      vec3 dl = dustCol * (sunCol * saturate(ndl * 0.9 + 0.1) * (0.8 + 0.3 * dust) + sky * 2.0);
      lit = mix(lit, dl, dust * 0.8);
    }

    // Dim & desaturate overall when neglected.
    lit = desaturate(lit, ng * 0.3) * (1.0 - ng * 0.22);

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

    // Dry-earth cracks with faint embers (neglect).
    if (ng > 0.02) {
      float ck = tc_cracks(x, fine * smoothstep(0.5, 0.9, ng));
      ck *= smoothstep(0.2, 0.75, ng) * (1.0 - cap * 0.7) * resolve;
      ck *= smoothstep(0.4, 0.7, noise3(x * 2.5 + 40.0));     // patchy, not a uniform net
      lit *= 1.0 - ck * 0.45;
      emit += distressCol * ck * (0.03 + 0.3 * night) * (0.35 + 0.65 * pulseD) * 0.45;
    }

    // ---- atmosphere: aerial perspective + in-scatter ----
    float airmass = 1.0 / (max(mu, 0.0) + 0.09);
    float tau = tauAtm * airmass * (1.0 + ng * 1.2);
    vec3 T = exp(-tau * vec3(0.7, 1.0, 1.35));
    float sunAtm = smoothstep(-0.3, 0.3, ndl);
    vec3 S = atmoCol * (1.0 - exp(-tau)) * sunAtm * phase * 2.0 * atmoGain;
    // warm terminator band (sunset light scattering)
    float term = exp(-ndl * ndl / 0.015) * smoothstep(-0.25, 0.05, ndl);
    S += toLinear(vec3(1.0, 0.5, 0.32)) * term * 0.07 * (1.0 - ng * 0.5);
    col = (lit + emit) * T + S;
    // gentle warm airglow + golden aurora
    col += cB * th * 0.03 * pow(1.0 - saturate(mu), 2.0);
    float auK = th * 0.85 + uPulse * 0.8;
    float au = auK > 0.001 ? tc_aurora(q, t, 1.0 / uRadius) * auK : 0.0;
    col += auroraCol * au * (0.06 + 1.0 * night) / (saturate(mu) + 0.6) * 0.55;
    // distress rim and celebration flare
    float fres = pow(1.0 - saturate(mu), 3.0);
    col += distressCol * fres * pulseD * 0.65;
    col += mix(cB, auroraCol, 0.5) * uPulse * fres * fres * 1.2;
  }

  // ---- halo (continuous at the limb; composited under the disc) ----
  float hr = max(r - 1.0, 0.0);
  vec3 d3 = vec3(p / max(r, 1e-4), 0.0);
  float ndlL = dot(d3, l);
  float dens = exp(-hr / 0.035);
  float tauH = tauAtm * 11.0 * dens * (1.0 + ng * 1.2);
  vec3 halo = atmoCol * (1.0 - exp(-tauH)) * smoothstep(-0.3, 0.3, ndlL) * phase * 2.0 * atmoGain;
  halo += cB * th * 0.025 * dens;
  float qaK = th * 0.85 + uPulse * 0.8;
  float qa = (qaK > 0.001 && hr < 0.2) ? tc_aurora(rot * d3, t, 1.0 / uRadius) * qaK : 0.0;
  float night2 = 1.0 - smoothstep(-0.2, 0.15, ndlL);
  halo += mix(auroraCol, rose, smoothstep(0.0, 0.05, hr)) * qa * exp(-hr / 0.022) * (0.1 + 0.8 * night2) * 0.55;
  halo += distressCol * pulseD * exp(-hr / 0.035) * 0.4;
  // celebration: a golden shock ring expands from the limb as uPulse decays 1 → 0
  float ringR = 1.0 + (1.0 - uPulse) * 0.26;
  float rd = (r - ringR) / (0.012 + 0.03 * (1.0 - uPulse));
  halo += mix(cB, auroraCol, 0.5) * uPulse * exp(-rd * rd) * 0.7 * smoothstep(1.0, 1.02, r);
  halo += auroraCol * uPulse * uPulse * dens * 0.35;

  vec3 dC = toGamma(tonemapACES(col));
  vec3 hC = toGamma(tonemapACES(halo));
  float hA = saturate(max(hC.r, max(hC.g, hC.b)));
  vec3 pm = dC * discA + hC * (1.0 - discA);
  float a = discA + hA * (1.0 - discA);
  pm = dither(frag, pm);
  fragColor = vec4(clamp(pm, vec3(0.0), vec3(a)), a);
}
