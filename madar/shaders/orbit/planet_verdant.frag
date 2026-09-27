#version 460 core
#include <flutter/runtime_effect.glsl>
#include "lib/common.glsl"

// ---------------------------------------------------------------------------
// GROWTH — "The Garden": a verdant world of oceans, continents, mountain
// ranges and rivers whose FORESTS VISIBLY EXPAND WITH PROGRESS. Vegetation
// takes the equator, the lowlands and the river valleys first, then climbs
// outward and upward; the advancing front is fresh lime growth, the old
// forest behind it deep green.
//   thriving : lush layered greens, glinting rivers and seas, soft clouds,
//              settlement lights along coasts and rivers at night,
//              bioluminescent forest shimmer, emerald aurora curtains.
//   neglected: barren tan/brown rock, spreading desert and dunes, seas
//              shrinking into cracked dry basins (drought-crack network),
//              dust storms, desaturation, red distress pulse.
//
// Uniform contract (shared by all planet shaders, exact order):
//   uSize, uCenter, uRadius (px), uTime (s), uLight (unit, view space),
//   uScore 0..1, uPulse 0..1, uSpin (x spin angle, y axial tilt, z unused),
//   uColorA surface (#4CC96B), uColorB glow (#B8F28A), uColorC deep (#0F3D1E),
//   uDetail 0..1 (0 tiny/far … 1 fills the screen), uSeed, uExtra.
// uExtra (archetype specific, pass 0 for defaults):
//   x : explicit growth fraction 0..1 for forest coverage; when > 0 it
//       overrides uScore for the forests only (health effects still follow
//       uScore). Pass e.g. habit-streak progress or goal completion.
//   y, z, w : unused.
// Draw rect: centre ± uRadius × 1.35 (haloFactor 1.35).
//
// FAMILY LOOK (common.glsl): lifeGrade (thriveGrade + neglectGrade) on the lit
// surface BEFORE the night lights / bioluminescence, the shared forward-scatter
// haze/halo (a crescent when back-lit, density × haloGain), the shared soft
// aurora curtains (emerald → teal), the limb shock ring for uPulse (the lime
// bloom at the growth front stays as this world's flourish), the shared
// distress rim/halo and compositeDiscHalo.
// Identity vs Health (ocean): Growth is GREEN LAND – a low sea level so the
// continents dominate, saturated forests, dark blue seas, an emerald sky.
// Thriving cue (22 px, day side): the growth mechanic alone can CANCEL the
// shared grade (at 1.0 most forest is dark old growth, at 0.6 bright young
// lime + rock), so thriving canopies are lifted (× 0.9 → 1.25 with th) and the
// graded surface steps 0.95 → 1.06; the sun is 2.1 (was 2.3) and the clouds
// 1.7 (was 2.15) to keep the exposure band. Stage-3 check: thriving-vs-steady ΔE00 ≥ 4 at seeds 0.5,
// 1.9, 3.7, 6.2 and 9.1 (it was 1.8–2.4 at two of them).
// ---------------------------------------------------------------------------

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

// Distance to the nearest cell border (bisector of the two nearest features):
// the polygon network of sun-baked mud. Full 3×3×3 search.
float vd_mud27(vec3 x) {
  vec3 p = floor(x);
  vec3 f = fract(x);
  float d1 = 9.0, d2 = 9.0;
  vec3 r1 = vec3(0.0), r2 = vec3(1.0);
  for (int k = -1; k <= 1; k++)
  for (int j = -1; j <= 1; j++)
  for (int i = -1; i <= 1; i++) {
    vec3 b = vec3(float(i), float(j), float(k));
    vec3 r = b - f + hash33(p + b);
    float d = dot(r, r);
    if (d < d1) { d2 = d1; r2 = r1; d1 = d; r1 = r; }
    else if (d < d2) { d2 = d; r2 = r; }
  }
  return dot(0.5 * (r1 + r2), normalize(r2 - r1));
}

// Cheap 2×2×2 variant for small / far planets.
float vd_mud8(vec3 x) {
  vec3 p = floor(x - 0.5);
  vec3 f = x - p;
  float d1 = 9.0, d2 = 9.0;
  vec3 r1 = vec3(0.0), r2 = vec3(1.0);
  for (int k = 0; k <= 1; k++)
  for (int j = 0; j <= 1; j++)
  for (int i = 0; i <= 1; i++) {
    vec3 b = vec3(float(i), float(j), float(k));
    vec3 r = b - f + hash33(p + b);
    float d = dot(r, r);
    if (d < d1) { d2 = d1; r2 = r1; d1 = d; r1 = r; }
    else if (d < d2) { d2 = d; r2 = r; }
  }
  return dot(0.5 * (r1 + r2), normalize(r2 - r1));
}

// Conservative screen-space bound of the shared aurora curtains: every sheet
// point X = rho·(±c·A + s·w) (w ⟂ A, rho ∈ [1, 1+AURORA_H], c = ovalY ± 0.03)
// projects inside one of two flat ellipses around the projected ovals, so
// outside them auroraCurtains() returns exactly 0 and the call (1 noise tap +
// the quadratic, up to 7 taps) can be skipped with no visible change.
bool vd_auroraNear(vec2 p, mat3 rot, float ovalY, float px) {
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
  float sc = saturate(uScore);
  float th = thrive(sc);
  float ng = neglect(sc);
  float pls = saturate(uPulse);
  float g = uExtra.x > 0.0 ? saturate(uExtra.x) : sc;          // forest growth
  vec3 cLeaf = toLinear(uColorA.rgb);
  vec3 cGlow = toLinear(uColorB.rgb);
  vec3 cDeep = toLinear(uColorC.rgb);
  float pulseD = distressPulse(t) * ng;
  // emerald sky (Growth), away from the Health ocean's cyan; dusty when neglected
  vec3 atmoCol = mix(mix(cGlow, toLinear(vec3(0.3, 0.85, 0.62)), 0.55), vec3(0.45, 0.62, 0.62), 0.25);
  atmoCol = mix(atmoCol, toLinear(vec3(0.62, 0.56, 0.46)), ng * 0.6);
  mat3 rot = rotY(uSpin.x + t * 0.02) * rotX(uSpin.y);
  vec3 seedOff = vec3(uSeed * 1.3, -uSeed * 0.7, uSeed * 1.9);
  // shared atmosphere (disc haze + halo use the same parameters)
  float phase = atmoPhase(l);
  float gain = 2.0 * haloGain(th, ng) * (1.0 + 0.5 * pls);
  float tau0 = 0.03 * (1.0 + 1.2 * ng);

  // shared aurora curtains (emerald base → teal top), evaluated once for disc
  // and halo; faded at small radii where a 2 px arc would read as an outline
  float auK = (th * 0.9 + pls * 0.8) * mix(0.35, 1.0, smoothstep(22.0, 60.0, uRadius));
  vec2 au = (auK > 0.001 && vd_auroraNear(p, rot, 0.9, px)) ? auroraCurtains(p, rot, l, 0.9, t, px) * auK : vec2(0.0);
  vec3 auBase = mix(cGlow, vec3(0.2, 1.0, 0.55), 0.55);
  vec3 auTop = mix(cGlow, vec3(0.05, 0.75, 0.85), 0.65);
  vec3 auC = mix(auBase, auTop, saturate(au.y / max(au.x, 1e-4) * 2.0)) * au.x * 0.17;

  float discA = discMask(p, uRadius);
  vec3 col = vec3(0.0);
  if (discA > 0.0) {
    // Shade the antialiasing band with the limb colour (no dark seam).
    vec2 pd = p * min(1.0, (1.0 - 0.75 * px) / max(r, 1e-5));
    vec3 n = sphereNormal(pd);
    vec3 q = rot * n;
    vec3 qs = q + seedOff;
    vec3 V = vec3(0.0, 0.0, 1.0);
    float mu = n.z;
    float ndl = dot(n, l);
    float diff = smoothstep(-0.06, 0.35, ndl) * saturate(ndl * 0.85 + 0.2);
    float night = 1.0 - smoothstep(-0.22, 0.06, ndl);
    // Detail tiers fade in (no popping while a planet zooms).
    float hiDet = smoothstep(0.25, 0.35, uDetail);            // canopy, towns, ripples
    float reliefK = smoothstep(0.5, 0.6, uDetail);            // mountain relief
    float shadowK = smoothstep(0.65, 0.75, uDetail);          // cloud shadows

    // --- terrain -------------------------------------------------------------
    float warp = fbm3lo(qs * 1.4);
    float h = fbm3(qs * 1.9 + warp * 1.1);
    float sea = 0.47 - ng * 0.035;                  // low sea: green land dominates; seas shrink in drought
    float cw = 0.002 + px * 2.2;                    // coastline antialias width
    float land = smoothstep(sea - cw, sea + cw, h);
    float e = saturate((h - sea) / 0.26);           // elevation above the sea
    float lat = abs(q.y);
    vec3 lo = rot * l;
    // Land-only lookups are skipped over open ocean (coherent branch).
    float ridge = 0.5, moist = 0.5, rn = 0.0, strata = 0.5, relief = 0.0;
    vec3 rq = qs * 4.3 + warp * 1.5;
    if (h > sea - 0.035) {
      ridge = ridged3(rq);
      moist = noise3(qs * 2.6 + 11.0);
      rn = noise3(qs * 4.2 + warp * 2.4 + 5.0);
      strata = noise3(qs * vec3(9.0, 26.0, 9.0) + warp * 3.0);
      // Relief: slope of the ridge field toward the star.
      if (reliefK > 0.0 && land > 0.0) {
        vec3 tang = lo - q * dot(lo, q);
        float ridge2 = ridged3(rq + tang * 0.05);
        relief = (ridge2 - ridge) * smoothstep(0.05, 0.4, e) * land * reliefK;
      }
    }
    // ridge-driven detail (high rock, snow) is sub-pixel below ~80 px: settle it
    // to its mean there instead of letting it alias into white speckles
    float ridgeL = mix(0.55, ridge, smoothstep(28.0, 80.0, uRadius));
    float mount = smoothstep(0.25, 0.78, e) * smoothstep(0.45, 0.8, ridgeL);

    // Rivers: meandering iso-lines on the lowlands, energy-conserving width.
    float rw0 = 0.009;
    float rw = max(rw0, px * 2.0);
    float rl = abs(rn - 0.5);
    float river = (1.0 - smoothstep(rw * 0.35, rw, rl)) * sqrt(rw0 / rw)
                * smoothstep(sea + cw, sea + 0.02, h) * (1.0 - smoothstep(0.3, 0.6, e));
    float valley = (1.0 - smoothstep(0.0, 0.09, rl)) * land;

    // --- vegetation: potential vs. a threshold that moves with growth --------
    float v = 0.42 * (1.0 - e) + 0.34 * (1.0 - lat) + 0.24 * moist + 0.14 * valley - 0.5 * mount;
    float thr = mix(1.02, 0.2, g) - pls * 0.08;     // celebration: forests surge
    float vegSoft = 0.025 + px * 1.5;
    float veg = smoothstep(thr - vegSoft, thr + vegSoft, v) * land * (1.0 - smoothstep(0.86, 0.92, lat));
    float age = saturate((v - thr) / 0.28);
    float front = veg * (1.0 - smoothstep(0.0, 0.22, age));   // fresh growth fringe

    // --- albedo --------------------------------------------------------------
    // Ocean: dark blue deep → shallow shelves (the luminous cyan belongs to Health).
    float depth = saturate((sea - h) / 0.1);
    vec3 deepSea = vec3(0.003, 0.016, 0.045);
    vec3 shelf = vec3(0.012, 0.07, 0.1);
    vec3 water = mix(shelf, deepSea, pow(depth, 0.5));
    // Barren ground: tan and brown rock with strata, ochre in the dry basins.
    vec3 tanRock = vec3(0.3, 0.21, 0.12);
    vec3 brown = vec3(0.17, 0.11, 0.065);
    vec3 ochre = vec3(0.3, 0.14, 0.06);
    vec3 rock = mix(tanRock, brown, smoothstep(0.3, 0.85, ridge * 0.6 + strata * 0.5));
    rock = mix(rock, ochre, smoothstep(0.5, 0.8, 1.0 - moist) * 0.5);
    rock = mix(rock, vec3(0.24, 0.22, 0.2), mount * 0.6);                // grey high rock
    // Beaches: a thin, dark, patchy strand on only some coasts (no sticker outline).
    vec3 beach = vec3(0.36, 0.31, 0.22);
    float beachK = smoothstep(0.5, 0.7, noise3(qs * 5.0 + 17.0));
    rock = mix(rock, beach, beachK * (1.0 - smoothstep(0.0, 0.004 + px * 0.5, h - sea)));
    // Forest: fresh lime at the front, layered greens behind it; drier land
    // grows olive grassland, wet valleys deep blue-green rainforest.
    vec3 young = mix(cGlow, cLeaf, 0.35) * 0.34;
    vec3 grass = mix(vec3(0.15, 0.19, 0.045), cLeaf * 0.3, 0.3);
    vec3 midG = cLeaf * 0.3;
    vec3 old = mix(cDeep * 1.3, vec3(0.008, 0.06, 0.03), 0.5);
    vec3 mature = mix(grass, midG, smoothstep(0.3, 0.65, moist + valley * 0.3));
    mature = mix(mature, old, smoothstep(0.35, 1.0, age) * smoothstep(0.3, 0.6, moist + valley * 0.4 + (1.0 - e) * 0.2));
    vec3 forest = mix(young, mature, smoothstep(0.0, 0.3, age));
    forest = max(mix(vec3(luma(forest)), forest, 1.3), 0.0);          // lush, saturated greens
    // Canopy clumps + a slow seasonal hue drift between hemispheres.
    float canopy = (hiDet > 0.0 && veg > 0.0) ? mix(0.5, noise3(qs * 38.0), hiDet) : 0.5;
    forest *= (0.75 + 0.5 * canopy) * 1.12 * mix(0.9, 1.25, th);   // thriving canopies are lush and bright
    float season = sin(t * 0.12 + q.y * 3.0 + uSeed);
    forest *= mix(vec3(1.0), vec3(1.2, 1.0, 0.65), 0.1 + 0.08 * season);
    vec3 ground = mix(rock, forest, veg);
    // Snow on the high ridges and the polar caps.
    float snow = smoothstep(0.62, 0.82, ridgeL) * smoothstep(0.45, 0.8, e) * land * (1.0 - ng * 0.9);
    float capN = smoothstep(0.935, 0.965, lat + (warp - 0.5) * 0.1 + (strata - 0.5) * 0.05);
    vec3 ice = vec3(0.6, 0.66, 0.72) * (0.7 + 0.45 * smoothstep(0.2, 0.8, strata * 0.6 + ridge * 0.5));
    ground = mix(ground, ice, max(snow * 0.9, capN));
    water = mix(water, ice * 0.9, capN);
    // Rivers.
    vec3 riverCol = mix(vec3(0.012, 0.045, 0.07), vec3(0.01, 0.04, 0.05), veg);
    ground = mix(ground, riverCol, river);
    vec3 albedo = mix(water, ground, land);
    float wet = max(1.0 - land, river) * (1.0 - capN);

    // --- lighting ------------------------------------------------------------
    vec3 hv = normalize(l + V);
    float nh = saturate(dot(n, hv));
    float fres = pow(1.0 - saturate(mu), 5.0);
    float sunShade = diff * saturate(1.0 + relief * 7.0);
    vec3 c = albedo * sunShade * 2.1;
    float ripple = (hiDet > 0.0 && nh > 0.9) ? mix(0.5, noise3(qs * 22.0 + t * 0.15), hiDet) : 0.5;
    float glint = (pow(nh, 400.0) * 1.6 + pow(nh, 60.0) * 0.2 * (0.7 + 0.6 * ripple)) * smoothstep(0.0, 0.2, ndl);
    c += vec3(1.0, 0.93, 0.8) * glint * wet;
    c += atmoCol * fres * 0.2 * (1.0 - land) * diff;
    // Wind waves over the canopy on thriving worlds.
    float wave = sin(dot(qs, vec3(21.0, 7.0, -13.0)) + warp * 18.0 - t * 1.4);
    c += cGlow * veg * th * diff * smoothstep(0.6, 1.0, wave) * 0.04;

    // Clouds: drifting weather systems, wispy at the edges, thin in drought.
    vec3 cq = qs * 2.7 + vec3(t * 0.012, 0.0, t * 0.005);
    cq += (noise3(cq * 0.45 + 9.0) - 0.5) * 0.9;
    float cn = fbm3lo(cq);
    if (hiDet > 0.0) {                                                  // wisps
      cn += ((noise3(cq * 8.9 + 2.0) - 0.5) * 0.1 + (noise3(cq * 18.3 + 7.0) - 0.5) * 0.055) * hiDet;
    }
    float cThr = 0.565 + ng * 0.1;
    float cloud = smoothstep(cThr, cThr + 0.2, cn);
    if (shadowK > 0.0) {
      float cs = smoothstep(cThr, cThr + 0.2, fbm3lo(cq + lo * 0.2));
      c *= 1.0 - cs * 0.45 * (1.0 - cloud) * shadowK;
    }
    // (1.7, was 2.15: still white after ACES, but cloudy seeds no longer
    // swamp the 22 px thriving cue or the exposure band)
    c = mix(c, vec3(0.9, 0.94, 1.0) * (diff * 1.7 + 0.008), cloud * 0.8);

    // --- neglect: desert, dunes, drought cracks, murk, dust (surface) ----------
    float crackGlow = 0.0;
    if (ng > 0.01) {
      float dryness = saturate(ng * 1.2 - moist * 0.6 + e * 0.15);
      float desert = smoothstep(0.25, 0.6, dryness) * land * (1.0 - veg);
      vec3 sand = mix(vec3(0.34, 0.19, 0.085), vec3(0.4, 0.28, 0.15), moist);
      float dunes = 0.5 + 0.5 * sin(dot(qs, vec3(150.0, 40.0, 95.0)) + warp * 60.0 + strata * 6.0) * reliefK;
      sand *= 0.95 + 0.08 * dunes;
      c = mix(c, sand * sunShade * 0.95, desert * (1.0 - cloud) * 0.8);   // no brightener: the desert is not a lamp
      // Exposed seabed and dry lowlands crack into polygons.
      float bed = smoothstep(sea - 0.03, sea + 0.004, h) * (1.0 - smoothstep(0.0, 0.25, e));
      float shelfDry = smoothstep(sea - 0.03, sea - 0.002, h) * (1.0 - land);
      c = mix(c, vec3(0.34, 0.3, 0.24) * diff * 1.5, shelfDry * ng);
      float mudMask = max(bed, shelfDry) * smoothstep(0.3, 0.8, ng) * (1.0 - veg);
      if (mudMask > 0.01) {
        vec3 mx = qs * 13.0;
        float ed = uDetail < 0.3 ? vd_mud8(mx) : vd_mud27(mx);
        float mw = max(0.03, 13.0 * px * 0.9);
        float crack = (1.0 - smoothstep(mw * 0.4, mw, ed)) * sqrt(0.03 / mw);
        c *= 1.0 - crack * mudMask * 0.65;
        crackGlow = crack * mudMask;
      }
      // Murky, algae-choked seas.
      c = mix(c, vec3(0.05, 0.06, 0.03) * diff * 2.0, (1.0 - land) * ng * 0.45);
      float dust = dustStorm(q, t) * ng;
      c = mix(c, vec3(0.36, 0.23, 0.12) * (diff * 1.5 + 0.02), dust * 0.5);
    }

    // Family living-state grade: after surface lighting, before emission.
    // (plus a small verdant-only exposure step: see the header, thriving cue)
    c = lifeGrade(c, th, ng) * mix(0.95, 1.06, th);

    // --- night side: settlements and bioluminescent forests (emission) ---------
    if (night > 0.0 && land > 0.0) {
      float settle = smoothstep(0.3, 0.95, sc);
      float coast = 1.0 - smoothstep(0.0, 0.03, abs(h - sea));
      float cluster = smoothstep(0.4, 0.75, noise3(qs * 7.0 + 21.0)) * land * max(coast, valley) * (1.0 - snow) * (1.0 - capN);
      float townGlow = cluster * settle * night * (1.0 - cloud * 0.7);
      float town = hiDet > 0.0 ? smoothstep(0.78, 0.95, noise3(qs * 95.0)) : 0.0;
      c += vec3(1.0, 0.66, 0.3) * townGlow * mix(0.14, town * 3.0 + 0.05, hiDet);
      float bioBeat = 0.55 + 0.45 * sin(t * 0.9 + warp * 14.0 + moist * 6.0);
      float bioPat = smoothstep(0.35, 0.8, noise3(qs * 11.0 + vec3(0.0, t * 0.03, 0.0)));
      c += cGlow * veg * night * bioBeat * bioPat * mix(0.004, 0.03, th) * (1.0 - cloud * 0.6);
      c += cGlow * front * night * th * 0.03;
    }
    // drought cracks smoulder with the distress pulse at night
    c += distressColor() * crackGlow * pulseD * night * 0.4;

    // --- shared atmosphere, aurora, distress, celebration ------------------------
    vec3 T;
    vec3 S = atmoHaze(mu, ndl, atmoCol, tau0, vec3(1.2, 1.0, 0.8), gain, phase, T);
    c = c * T + S;
    c += auC;
    c += distressColor() * distressRim(mu, pulseD);
    // celebration flourish: rim flash + forest surge with a lime bloom at the growth front
    c += cGlow * pls * (pow(1.0 - saturate(mu), 6.0) * 1.2 + front * 1.4 * (0.4 + diff) + veg * 0.08);

    col = c;
  }

  // --- halo: shared forward-scatter halo + aurora + limb shock + distress -----
  vec3 halo = atmoHalo(p, l, atmoCol, tau0, 0.035, gain, phase, px);
  halo += auC;
  halo += cGlow * limbShock(r, pls, px) * 0.6;
  halo += distressColor() * distressHalo(r, pulseD, px);

  fragColor = compositeDiscHalo(col, discA, halo, frag);
}
