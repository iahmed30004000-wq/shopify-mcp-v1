#version 460 core
#include <flutter/runtime_effect.glsl>
#include "lib/common.glsl"

// ---------------------------------------------------------------------------
// MONEY — "The Treasury": a crystalline world.
//
// A faceted gem crust (one cellular evaluation per pixel; every facet has its
// own tilted normal, so sharp highlights flash from facet to facet as the world
// turns). Looking into a facet refracts the view, so the gold veins and the
// embers buried in the crystal shift per facet like a real cut stone.
//   thriving : vivid mint crystal, prismatic fire along the facet edges, bright
//              flowing gold veins, lantern-lit facets on the night side (the
//              "settlement lights" of this world), golden aurora, sparkles.
//   neglected: milky frosted crystal, dull bronze veins, fractures across the
//              facets, dust storms, red distress pulse.
//
// Uniform contract (shared by all planet shaders, exact order):
//   uSize, uCenter, uRadius (px), uTime (s), uLight (unit, view space),
//   uScore 0..1, uPulse 0..1, uSpin (x spin angle, y axial tilt, z unused),
//   uColorA surface (#7FE3C4), uColorB glow (#F5D06F), uColorC deep (#0E3B35),
//   uDetail 0..1 (0 tiny/far … 1 fills the screen), uSeed, uExtra.
// uExtra (archetype specific, pass 0 for defaults):
//   x : facet density multiplier (0 → 1.0; 0.7 = larger facets, 1.5 = finer)
//   y : gold richness override 0..1 (0 → follows uScore), e.g. savings ratio;
//       drives vein brightness and how many facets are lantern-lit.
//   z, w : unused.
// Draw rect: centre ± uRadius × 1.35 (haloFactor 1.35).
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

// Cellular facets, full 3×3×3 search. Returns the distance to the bisector
// plane between the two nearest features (≈ distance to the facet edge);
// r1/r2 = vectors from x to the nearest/second features, k1/k2 = their cells.
float cr_cells27(vec3 x, out vec3 r1, out vec3 r2, out vec3 k1, out vec3 k2) {
  vec3 p = floor(x);
  vec3 f = fract(x);
  float d1 = 9.0, d2 = 9.0;
  r1 = vec3(0.0); r2 = vec3(1.0); k1 = p; k2 = p;
  for (int k = -1; k <= 1; k++)
  for (int j = -1; j <= 1; j++)
  for (int i = -1; i <= 1; i++) {
    vec3 b = vec3(float(i), float(j), float(k));
    vec3 r = b - f + hash33(p + b);
    float d = dot(r, r);
    if (d < d1) { d2 = d1; r2 = r1; k2 = k1; d1 = d; r1 = r; k1 = p + b; }
    else if (d < d2) { d2 = d; r2 = r; k2 = p + b; }
  }
  return dot(0.5 * (r1 + r2), normalize(r2 - r1));
}

// Cheap 2×2×2 variant for tiny / far planets (8 hashes instead of 27); it can
// miss a feature now and then, which is invisible when facets are < ~15 px.
float cr_cells8(vec3 x, out vec3 r1, out vec3 r2, out vec3 k1, out vec3 k2) {
  vec3 p = floor(x - 0.5);
  vec3 f = x - p;
  float d1 = 9.0, d2 = 9.0;
  r1 = vec3(0.0); r2 = vec3(1.0); k1 = p; k2 = p;
  for (int k = 0; k <= 1; k++)
  for (int j = 0; j <= 1; j++)
  for (int i = 0; i <= 1; i++) {
    vec3 b = vec3(float(i), float(j), float(k));
    vec3 r = b - f + hash33(p + b);
    float d = dot(r, r);
    if (d < d1) { d2 = d1; r2 = r1; k2 = k1; d1 = d; r1 = r; k1 = p + b; }
    else if (d < d2) { d2 = d; r2 = r; k2 = p + b; }
  }
  return dot(0.5 * (r1 + r2), normalize(r2 - r1));
}

// Screen-space twinkle stars (a soft core plus a four-point diffraction
// cross). g = pixel offset from the planet centre, cellPx = grid size in px.
float cr_sparkle(vec2 g, float cellPx, float t, float density) {
  vec2 u = g / cellPx;
  vec2 id = floor(u);
  vec2 h = hash22(id + uSeed * 7.1);
  float rate = 0.45 + 0.55 * h.x;
  float ph = t * rate + h.y;
  float cyc = floor(ph);
  float on = step(1.0 - density, hash12(id * 1.37 + cyc * 7.13 + 3.1));
  float env = sin(fract(ph) * PI);
  env = env * env * env;
  vec2 fu = fract(u) - 0.5;
  vec2 d = (fu - (hash22(id + cyc * 3.7) - 0.5) * 0.3) * cellPx;
  float core = exp(-dot(d, d) * 0.5);
  float arms = exp(-abs(d.x) * 0.38 - d.y * d.y * 2.0) + exp(-abs(d.y) * 0.38 - d.x * d.x * 2.0);
  arms *= 1.0 - smoothstep(0.3, 0.5, max(abs(fu.x), abs(fu.y)));
  return on * env * (core * 1.6 + arms * 0.5 * env);
}

// Auroral footprint on the ground (object-space point q): the thin bright
// lower edge of the curtains; `edge` = half-width in q.y units.
float cr_auroraFoot(vec3 q, float t, float edge, float c0) {
  vec2 dir = normalize(q.xz + 1e-4);
  float hemi = q.y > 0.0 ? 1.0 : -1.0;
  float band = abs(q.y) - c0;
  float rays = noise3(vec3(dir * 34.0, t * 0.5 + hemi * 9.0));
  float folds = noise3(vec3(dir * 3.5, t * 0.15 - hemi * 4.0));
  return exp(-band * band / (edge * edge)) * (0.3 + 0.7 * smoothstep(0.25, 0.8, rays)) * (0.2 + 0.8 * folds);
}

// One crossing of the view ray with an auroral sheet at view-space point X.
// Returns (emission, emission × relative height).
vec2 cr_sheet(vec3 X, vec3 axis, float c, float H, float zs, mat3 rot, float t, float px) {
  float rX = length(X);
  float h = rX - 1.0;
  if (h <= 0.0 || h >= H || X.z < zs) return vec2(0.0);
  vec3 Xo = rot * X;
  vec2 dir = normalize(Xo.xz + 1e-5);
  float hemi = Xo.y > 0.0 ? 1.0 : -1.0;
  float u = h / H;
  float rays = noise3(vec3(dir * mix(34.0, 80.0, saturate(0.004 / px)), t * 0.5 + hemi * 9.0 + u * 0.3));
  float folds = noise3(vec3(dir * 3.5, t * 0.15 - hemi * 4.0));
  float prof = smoothstep(0.0, 0.05, u) * exp(-u * 2.4);
  vec3 nrm = normalize(dot(X, axis) * axis - c * c * X);
  float graze = 1.0 / max(abs(nrm.z), 0.15);
  float vis = smoothstep(0.6, 2.5, H * length(X.xy) / rX / px);   // fade where sub-pixel
  float e = (0.15 + 0.85 * smoothstep(0.3, 0.85, rays)) * (0.2 + 0.8 * folds) * prof * graze * vis;
  return vec2(e, e * u);
}

// Aurora curtains: thin emissive sheets rising H radii above both auroral
// ovals (the cone |X·axis| = c·|X|), intersected analytically with the
// orthographic view ray. The ovals are tied to the star wind, not the crust.
vec2 cr_curtains(vec2 p, vec3 axis, mat3 rot, float c0, float t, float px) {
  float H = 0.09;
  float pp = dot(p, p);
  if (pp > (1.0 + H) * (1.0 + H)) return vec2(0.0);
  float zs = pp < 1.0 ? sqrt(1.0 - pp) : -9.0;
  float c = c0 + (noise3(vec3(p * 2.2, t * 0.08)) - 0.5) * 0.07;
  float k = dot(axis.xy, p);
  float A = axis.z * axis.z - c * c;
  A = A < 0.0 ? min(A, -1e-4) : max(A, 1e-4);
  float B = 2.0 * k * axis.z;
  float C = k * k - c * c * pp;
  float D = B * B - 4.0 * A * C;
  if (D <= 0.0) return vec2(0.0);
  float sD = sqrt(D);
  return cr_sheet(vec3(p, (-B + sD) / (2.0 * A)), axis, c, H, zs, rot, t, px)
       + cr_sheet(vec3(p, (-B - sD) / (2.0 * A)), axis, c, H, zs, rot, t, px);
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
  float rich = uExtra.y > 0.0 ? saturate(uExtra.y) : sc;
  vec3 cSurf = toLinear(uColorA.rgb);
  vec3 cGold = toLinear(uColorB.rgb);
  vec3 cDeep = toLinear(uColorC.rgb);
  vec3 red = vec3(1.0, 0.047, 0.023);
  float distress = ng * distressPulse(t);
  vec3 atmoCol = mix(cSurf, cGold, 0.65);
  float atmoD = mix(0.2, 0.45, th) * (1.0 - ng * 0.4) + pls * 0.4;
  mat3 rot = rotY(uSpin.x + t * 0.025) * rotX(uSpin.y);
  vec3 seedOff = vec3(uSeed * 1.7, uSeed * 0.9, -uSeed * 1.3);
  vec2 ldir = l.xy;
  float mie = pow(saturate(-l.z), 3.0);

  // Aurora curtains (thriving only), shared by the disc and the halo.
  float auC0 = 0.87;
  vec3 auCur = vec3(0.0);
  if (th > 0.01) {
    vec2 cu = cr_curtains(p, vec3(0.0, 1.0, 0.0) * rot, rot, auC0, t, px) * th;
    vec3 auBase = mix(cGold, vec3(1.0, 0.95, 0.8), 0.25) * 1.4;
    auCur = mix(auBase, cSurf * 1.4, saturate(cu.y / max(cu.x, 1e-4) * 2.2)) * cu.x * 0.14;
  }

  float discA = discMask(p, uRadius);
  vec3 col = vec3(0.0);
  if (discA > 0.0) {
    // Shade the antialiasing band with the limb colour (no dark seam).
    vec2 pd = p * min(1.0, (1.0 - 0.75 * px) / max(r, 1e-5));
    vec3 n = sphereNormal(pd);
    vec3 q = rot * n;
    float ndl = dot(n, l);
    float lightMask = smoothstep(-0.28, 0.22, ndl);
    float night = 1.0 - smoothstep(-0.3, 0.15, ndl);
    vec3 V = vec3(0.0, 0.0, 1.0);

    // --- facets ------------------------------------------------------------
    float F = 2.3 * (uExtra.x > 0.0 ? uExtra.x : 1.0);
    vec3 x = q * F + seedOff;
    vec3 r1, r2, k1, k2;
    float e;
    if (uDetail < 0.15) {
      e = cr_cells8(x, r1, r2, k1, k2);
    } else {
      e = cr_cells27(x, r1, r2, k1, k2);
    }
    vec3 h1 = hash33(k1 + 31.7);
    vec3 h2 = hash33(k2 + 31.7);
    vec3 nf1 = normalize(normalize(x + r1 - seedOff) + (h1 - 0.5) * 0.6) * rot;
    vec3 nf2 = normalize(normalize(x + r2 - seedOff) + (h2 - 0.5) * 0.6) * rot;
    // Frost rounds the cut away.
    nf1 = normalize(mix(nf1, n, ng * 0.55));
    nf2 = normalize(mix(nf2, n, ng * 0.55));
    // Bevel: the normal rolls from the facet to the edge bisector.
    float pxV = F * px / mix(1.0, max(n.z, 0.12), 0.5);     // one pixel in cell units
    float facetPx = uRadius / F;                             // facet size on screen
    float bevel = max(0.06, pxV * 1.5);
    float s = saturate(e / bevel);
    vec3 nb = normalize(nf1 + nf2);
    vec3 ns = normalize(mix(nb, nf1, s));
    ns = normalize(ns + vec3(0.0, 0.0, max(0.0, 0.12 - ns.z)));

    // --- interior seen through the facet (refraction parallax) --------------
    vec3 T = refract(-V, ns, 0.66);
    vec3 To = rot * T;
    vec3 qv = q + To * 0.22;
    float fp = 1.0 - smoothstep(12.0, 40.0, facetPx);          // footprint: 1 = tiny planet
    // Gold veins: iso-lines of a domain-warped fbm (ridged profile), so they
    // thread and branch through the stone instead of forming blobs.
    vec3 vq = qv * 1.7 + seedOff * 0.37;
    float warp = fbm3lo(vq * 1.2 + 7.0);
    float vf = fbm3lo(vq + warp * 1.1);
    float vl = abs(vf - 0.5);
    float vw0 = 0.01 * mix(0.4, 1.45, smoothstep(0.3, 0.7, noise3(vq * 2.3 + 3.0)));
    float vw = max(vw0, px * 1.3);
    float veinAmt = sqrt(vw0 / vw);                            // energy kept when blurred
    float vein = (1.0 - smoothstep(vw * 0.5, vw, vl)) * veinAmt;
    float veinCore = 1.0 - smoothstep(0.0, vw * 0.45, vl);
    float veinGlow = exp(-vl * vl * 1400.0);                   // light scattered around the vein
    float incl = warp;

    // Sub-facets: two internal mirror planes split each facet into tones.
    vec3 rv = -r1;
    float aa = pxV * 0.9;
    float zA = smoothstep(-aa, aa, dot(rv, normalize(h1.zxy - 0.5)) + (h1.y - 0.5) * 0.25);
    float zB = smoothstep(-aa, aa, dot(rv, normalize(h1.yzx - 0.5)) - (h1.z - 0.5) * 0.25);
    float tone = mix(mix(h1.x, fract(h1.x * 5.3), zA), mix(fract(h1.y * 3.7), fract(h1.z * 7.9), zA), zB);
    float clarity = 1.0 - ng;
    float grad = dot(rv * rot, l);

    // Body: clear deep mint when healthy, milky when neglected.
    float cloud = mix(0.35, 1.0, ng);
    float dep = saturate(0.5 + (incl - 0.5) * 1.6 * cloud + (h1.x - 0.5) * 0.55 - 0.3 * grad);
    vec3 body = mix(cSurf * 1.1, cDeep * 2.2, dep);
    float brill = mix(0.3, 1.5, h1.y) * (1.0 + (tone - 0.5) * 0.6 * clarity) * (1.0 + 0.7 * grad);
    vec3 nd = normalize(mix(n, ns, 0.8));
    float wrap = saturate((dot(nd, l) + 0.25) / 1.25);
    float tl = lightMask * wrap;
    vec3 inner = body * tl * max(brill, 0.12) * mix(1.5, 1.8, th) + (cDeep * 0.9 + cSurf * 0.012) * (0.35 + 0.65 * lightMask);

    // Gold veins inside the crystal, flowing when prosperous.
    float flow = 0.5 + 0.5 * sin(warp * 40.0 + vf * 12.0 - t * mix(0.4, 2.2, sc));
    vec3 veinMetal = mix(cGold, vec3(0.2, 0.13, 0.06), ng * 0.85);
    float veinE = mix(0.05, 1.0, rich) * (1.0 - ng * 0.8);
    float vprof = saturate(1.0 - vl / vw);                              // 1 at the vein axis
    vec3 veinLit = mix(veinMetal * veinMetal, veinMetal, 0.3 + 0.5 * vprof) * (0.6 + 0.8 * vprof) * 1.25 * (tl * 1.9 + 0.02);
    inner *= 1.0 - (vein - veinCore) * 0.35;                           // dark seam around the vein
    inner = mix(inner, veinLit, vein * 0.9);
    float sheen = pow(saturate(dot(n, normalize(l + V))), 24.0) * lightMask;
    inner += cGold * veinCore * sheen * (1.2 - ng) * 1.6;
    inner += cGold * (veinGlow * 0.1 + vein * 0.25 + veinCore * 0.9) * veinE * (0.12 + 0.3 * th + 1.4 * night) * (0.7 + 0.8 * flow * th);
    // Settlements strung along the veins: tiny lights on the night side.
    if (fp < 0.99) {
      float town = smoothstep(0.78, 0.93, noise3(q * 60.0 + seedOff)) * smoothstep(0.035, 0.008, vl);
      inner += vec3(1.0, 0.8, 0.45) * town * (1.0 - fp) * veinE * night * (0.4 + 0.6 * th) * 2.2;
    }

    // Lantern-lit facets: a light buried under each prosperous facet, on the
    // facet's own radial axis (night-side "settlement lights").
    vec3 cf = x + r1 - seedOff;
    vec3 xs = normalize(cf) * F + seedOff;
    vec3 xv = qv * F + seedOff;
    float de = length(xs - xv);
    float emberOn = smoothstep(h1.z - 0.06, h1.z + 0.06, rich * 1.2 - 0.25);
    float breathe = 0.75 + 0.25 * sin(t * (0.8 + h1.x) + h1.y * 6.3);
    float ember = (exp(-de * de * 400.0) + exp(-de * de * 40.0) * 0.22) * emberOn * breathe;
    inner += mix(cGold, vec3(1.0, 0.62, 0.25), 0.35) * ember * (0.1 + 2.2 * night) * (0.4 + 0.6 * th);

    // --- surface: reflections, star glints, prismatic fire ------------------
    float fres = 0.05 + 0.95 * pow(1.0 - saturate(ns.z), 5.0);
    vec3 R = reflect(-V, ns);
    float rl = saturate(dot(R, l));
    float starVis = smoothstep(-0.12, 0.1, ndl);
    float gloss = mix(1.0, 0.2, ng);
    float spec = (pow(rl, 16.0) * 0.5 + pow(rl, 60.0) * 2.0 + pow(rl, 300.0) * 10.0) * gloss + pow(rl, 5.0) * 0.1;
    vec3 sky = mix(cDeep * 0.6, atmoCol * 0.45, saturate(R.y * 0.5 + 0.5)) * 0.3;
    vec3 c = inner * (1.0 - fres * 0.7) + sky * fres + vec3(1.0, 0.95, 0.85) * spec * starVis * (0.4 + fres);

    // Bevel glints with dispersion (red/blue split across the edge).
    if (e < bevel) {
      vec3 nR = normalize(mix(nb, nf1, saturate(s - 0.25)));
      vec3 nB = normalize(mix(nb, nf1, saturate(s + 0.25)));
      vec3 disp = vec3(pow(saturate(dot(reflect(-V, nR), l)), 45.0),
                       pow(rl, 45.0),
                       pow(saturate(dot(reflect(-V, nB), l)), 45.0));
      c += mix(vec3(luma(disp)), disp, 0.3 + 0.7 * th) * starVis * (1.0 - s) * mix(0.6, 3.5, th) * gloss;
    }
    // Fire: coloured internal flashes in one sub-facet, changing with angle.
    vec3 nI = normalize(ns + (hash33(k1 + 5.1) - 0.5) * 0.9);
    float ri = saturate(dot(reflect(-V, nI), l));
    vec3 spectrum = saturate3(abs(fract(ri * 9.0 + h1.z + vec3(0.0, 0.33, 0.67)) * 6.0 - 3.0) - 1.0);
    vec3 fo = hash33(k1 + 9.7) - 0.5;
    float fspot = exp(-dot(rv - fo * 0.5, rv - fo * 0.5) / max(0.0016, pxV * pxV * 2.5));
    float fireAmt = pow(ri, 16.0) * fspot * starVis * clarity * (0.1 + 2.4 * th);
    vec3 fire = spectrum * fireAmt * 3.0;
    c += fire;
    // Edge hairlines (fade out when facets get small on screen).
    float hair = (1.0 - smoothstep(pxV * 0.3, pxV * 1.2, e)) * smoothstep(10.0, 30.0, facetPx);
    c += mix(cSurf, vec3(1.0), 0.4) * hair * (0.05 + 0.12 * th) * (0.2 + lightMask);

    // Sparkles, favouring the star-facing side.
    float cellPx = max(16.0, uRadius * 0.085);
    float spk = cr_sparkle(frag - uCenter, cellPx, t, mix(0.02, 0.16, th) + pls * 0.45);
    c += vec3(1.0, 0.96, 0.86) * spk * lightMask * (0.4 + 3.0 * pow(saturate(dot(n, normalize(l + V))), 8.0)) * (1.0 - ng) * 1.8;

    // Vividness: a thriving treasury is saturated, a steady one a touch calmer.
    c = max(mix(vec3(luma(c)), c, mix(0.88, 1.12, th)), 0.0);

    // --- neglect: frost, fractures, dust ------------------------------------
    if (ng > 0.01) {
      float frost = fbm3lo(q * 8.0 + seedOff);
      float fr = ng * (0.5 + 0.5 * smoothstep(0.35, 0.7, frost));
      vec3 milk = mix(vec3(0.3, 0.37, 0.36), cSurf * 0.5, 0.3) * (wrap * lightMask * 1.5 + 0.03);
      c = mix(c, milk + spec * 0.12, fr * 0.72);
      // Fractures: straight splits across the facets.
      vec3 hf = hash33(k1 + 71.3);
      float jag = (noise3(x * 7.0) - 0.5) * 0.06;
      float f1 = abs(dot(rv, normalize(hf - 0.5)) - (h1.y - 0.5) * 0.3 + jag);
      float f2 = abs(dot(rv, normalize(hf.zxy - 0.5)) + (h1.x - 0.5) * 0.3 + jag);
      float fw = pxV * 0.4;
      float crack = max(1.0 - smoothstep(fw, fw * 2.2, f1), (1.0 - smoothstep(fw, fw * 2.2, f2)) * step(0.5, hf.y));
      crack *= smoothstep(hf.x - 0.05, hf.x + 0.05, ng * 1.25 - 0.25) * mix(0.35, 1.0, smoothstep(14.0, 45.0, facetPx));
      c = mix(c, vec3(0.8, 0.85, 0.85) * (lightMask * 1.1 + 0.04), crack * 0.65);
      c += red * crack * distress * (0.3 + 0.7 * night) * 0.7;
      c = desaturate(c, ng * 0.5) * (1.0 - ng * 0.3);
      float dust = dustStorm(q, t) * ng;
      c = mix(c, vec3(0.3, 0.22, 0.13) * (lightMask * 1.6 + 0.03), dust * 0.6);
    }

    // Aurora: bright footprint line + the curtains rising above it.
    if (th > 0.01) {
      float foot = cr_auroraFoot(q, t, max(0.01, px * 1.1), auC0) * th;
      c += (cGold * 1.3 * foot * 0.2 + auCur * 1.2) * (0.2 + 1.1 * night);
    }

    // Atmosphere rim (continuous with the halo at the limb).
    vec2 dirN = n.xy / max(length(n.xy), 1e-4);
    float illum = smoothstep(-0.5, 0.45, dot(dirN, ldir) + 0.12);
    float limb = pow(1.0 - saturate(n.z), 3.0);
    c += atmoCol * atmoD * limb * (illum * 1.1 + mie * 0.9);
    // Back-light: light leaks through the thin crystal at the limb.
    c += cSurf * mie * pow(1.0 - saturate(n.z), 2.5) * (0.35 + 0.65 * illum) * 1.3;

    // Distress + celebration.
    float fresR = pow(1.0 - saturate(n.z), 4.0);
    c += red * fresR * distress * 1.1;
    // Celebration: facets catch the light one after another as uPulse moves,
    // veins and lanterns flare, the rim blooms gold.
    float cascade = (1.0 - smoothstep(0.0, 0.12, abs(h1.z - (1.0 - pls)))) * pls;
    vec3 flash = mix(cSurf * 1.3, cGold, 0.45) * (0.45 + 0.9 * saturate(0.5 + grad)) * (1.0 + (1.0 - s) * 1.5);
    c += flash * cascade * (0.6 + 0.6 * lightMask);
    c += cGold * pls * (0.04 + fresR * 1.4 + vein * 1.6 + ember * 1.8) + fire * pls * 3.0;

    col = c;
  }

  // --- halo (evaluated at r >= 1, composited under the disc) ---------------
  float rh = max(r, 1.0);
  vec2 dir = p / max(r, 1e-5);
  float hw = 0.2 + pls * 0.1;
  float fall = 1.0 - smoothstep(1.0, 1.0 + hw, rh);
  fall *= fall;
  float illumH = smoothstep(-0.5, 0.45, dot(dir, ldir) + 0.12);
  vec3 halo = atmoCol * atmoD * fall * (illumH * 1.1 + mie * 0.9);
  halo += red * distress * 0.5 * (1.0 - smoothstep(1.0, 1.1, rh));
  halo += auCur * (0.4 + 0.6 * (1.0 - illumH));
  float haloA = saturate(max(halo.r, max(halo.g, halo.b)) * 2.5);
  vec3 pm = toGamma(tonemapACES(col)) * discA + toGamma(tonemapACES(halo)) * haloA * (1.0 - discA);
  fragColor = vec4(dither(frag, pm), discA + haloA * (1.0 - discA));
}
