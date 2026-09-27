#version 460 core
#include <flutter/runtime_effect.glsl>
#include "lib/common.glsl"

// ---------------------------------------------------------------------------
// MONEY — "The Treasury": a crystalline world.
//
// A faceted gem crust (one cellular evaluation per pixel; every facet has its
// own tilted normal, so sharp highlights flash from facet to facet as the world
// turns). Looking into a facet refracts the view, so the gold veins and the
// lanterns buried in the crystal shift per facet like a real cut stone.
//   thriving : deep jewel-green crystal, prismatic fire along the facet
//              edges, bright flowing gold veins, per-facet star sparkles that
//              turn with the stone, lantern-lit facets on the night side (the
//              "settlement lights" of this world), golden aurora.
//   neglected: milky frosted crystal, dull bronze veins, fractures across the
//              facets, dust storms, dim and grey (shared neglectGrade), red
//              distress pulse (shared, in phase with every other world).
//
// Family pipeline (common.glsl): lit → lifeGrade → (lit+emit)·T + S (atmoHaze)
// → aurora / rims → halo = atmoHalo + aurora + limbShock + distress →
// compositeDiscHalo. The star side has a real terminator: the crystal is only
// lit where the star reaches it; the night side keeps the veins and lanterns.
//
// Cost notes: the 8-cell facet search is used below uDetail 0.15 or when a
// facet is under 25 px (the 22–87 px orbit views); the sharp lobes are powers
// by repeated squaring instead of pow(); the shared curtain call is skipped
// where no auroral oval can project; sparkle work runs only on the few
// facets that are twinkling.
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
// r1/r2/r3 = vectors from x to the nearest/second/third features, k1/k2 =
// the cells of the first two.
float cr_cells27(vec3 x, out vec3 r1, out vec3 r2, out vec3 r3, out vec3 k1, out vec3 k2) {
  vec3 p = floor(x);
  vec3 f = fract(x);
  float d1 = 9.0, d2 = 9.0, d3 = 9.0;
  r1 = vec3(0.0); r2 = vec3(1.0); r3 = vec3(2.0); k1 = p; k2 = p;
  for (int k = -1; k <= 1; k++)
  for (int j = -1; j <= 1; j++)
  for (int i = -1; i <= 1; i++) {
    vec3 b = vec3(float(i), float(j), float(k));
    vec3 r = b - f + hash33(p + b);
    float d = dot(r, r);
    if (d < d1) { d3 = d2; r3 = r2; d2 = d1; r2 = r1; k2 = k1; d1 = d; r1 = r; k1 = p + b; }
    else if (d < d2) { d3 = d2; r3 = r2; d2 = d; r2 = r; k2 = p + b; }
    else if (d < d3) { d3 = d; r3 = r; }
  }
  return dot(0.5 * (r1 + r2), normalize(r2 - r1));
}

// Cheap 2×2×2 variant for small / far planets (8 hashes instead of 27); it can
// miss a feature now and then (a facet edge lands slightly differently), which
// does not read while facets are under ~25 px.
float cr_cells8(vec3 x, out vec3 r1, out vec3 r2, out vec3 r3, out vec3 k1, out vec3 k2) {
  vec3 p = floor(x - 0.5);
  vec3 f = x - p;
  float d1 = 9.0, d2 = 9.0, d3 = 9.0;
  r1 = vec3(0.0); r2 = vec3(1.0); r3 = vec3(2.0); k1 = p; k2 = p;
  for (int k = 0; k <= 1; k++)
  for (int j = 0; j <= 1; j++)
  for (int i = 0; i <= 1; i++) {
    vec3 b = vec3(float(i), float(j), float(k));
    vec3 r = b - f + hash33(p + b);
    float d = dot(r, r);
    if (d < d1) { d3 = d2; r3 = r2; d2 = d1; r2 = r1; k2 = k1; d1 = d; r1 = r; k1 = p + b; }
    else if (d < d2) { d3 = d2; r3 = r2; d2 = d; r2 = r; k2 = p + b; }
    else if (d < d3) { d3 = d; r3 = r; }
  }
  return dot(0.5 * (r1 + r2), normalize(r2 - r1));
}

// x^n by repeated squaring (the gem needs many sharp lobes; pow() is exp/log).
float cr_p8(float x) { float a = x * x; a *= a; return a * a; }

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
  float pulseD = distressPulse(t) * ng;
  mat3 rot = rotY(uSpin.x + t * 0.025) * rotX(uSpin.y);
  vec3 seedOff = vec3(uSeed * 1.7, uSeed * 0.9, -uSeed * 1.3);
  vec3 V = vec3(0.0, 0.0, 1.0);
  vec3 hv = normalize(l + V);

  // shared family atmosphere: a clear mint haze (frosted grey when neglected)
  vec3 atmoCol = mix(cSurf, vec3(0.8, 1.0, 0.95), 0.3) * 0.9;
  atmoCol = mix(atmoCol, vec3(0.55, 0.6, 0.58), ng * 0.5);
  float phase = atmoPhase(l);
  float gain = 2.0 * haloGain(th, ng) * (1.0 + 0.5 * pls);
  float tau0 = 0.013 * (1.0 + 1.2 * ng);

  // shared family aurora (gold base → mint top), once for disc and halo
  // Cheap conservative pre-test before the shared curtain call (saves its
  // noise taps on the ~half of the disc that no oval can project onto):
  // |X·axis| = c|X| needs |k| + |axis.z|·(1+H) ≥ c with k = axis.xy·p.
  float auK = th * 0.9 + pls * 0.8;
  vec3 axisV = vec3(0.0, 1.0, 0.0) * rot;
  bool auNear = abs(dot(axisV.xy, p)) + abs(axisV.z) * (1.0 + AURORA_H) > 0.88 - 0.04;
  vec2 au = (auK > 0.001 && auNear) ? auroraCurtains(p, rot, l, 0.88, t, px) * auK : vec2(0.0);
  vec3 auBase = mix(cGold, vec3(1.0, 0.95, 0.8), 0.25);
  vec3 auC = mix(auBase, mix(cSurf, cGold, 0.35), saturate(au.y / max(au.x, 1e-4) * 2.0)) * au.x * 0.13;

  float discA = discMask(p, uRadius);
  vec3 col = vec3(0.0);
  if (discA > 0.0) {
    // Shade the antialiasing band with the limb colour (no dark seam).
    vec2 pd = p * min(1.0, (1.0 - 0.75 * px) / max(r, 1e-5));
    vec3 n = sphereNormal(pd);
    vec3 q = rot * n;
    float ndl = dot(n, l);
    float mu = n.z;
    float lightMask = smoothstep(-0.12, 0.18, ndl);          // a real terminator
    float night = 1.0 - smoothstep(-0.3, 0.15, ndl);

    // --- facets ------------------------------------------------------------
    float F = 3.5 * (uExtra.x > 0.0 ? uExtra.x : 1.0);
    float facetPx = uRadius / F;                             // facet size on screen
    vec3 x = q * F + seedOff;
    vec3 r1, r2, r3, k1, k2;
    float e;
    if (uDetail < 0.15 || facetPx < 25.0) {
      e = cr_cells8(x, r1, r2, r3, k1, k2);
    } else {
      e = cr_cells27(x, r1, r2, r3, k1, k2);
    }
    // distance to the bisector with the THIRD feature: small near triple
    // junctions and where the second / third features swap
    float e3 = dot(0.5 * (r1 + r3), normalize(r3 - r1));
    vec3 h1 = hash33(k1 + 31.7);
    vec3 h2 = hash33(k2 + 31.7);
    vec3 nf1 = normalize(normalize(x + r1 - seedOff) + (h1 - 0.5) * 0.35) * rot;
    vec3 nf2 = normalize(normalize(x + r2 - seedOff) + (h2 - 0.5) * 0.35) * rot;
    // Frost rounds the cut away.
    nf1 = normalize(mix(nf1, n, ng * 0.55));
    nf2 = normalize(mix(nf2, n, ng * 0.55));
    // Bevel: the normal rolls from the facet to the edge bisector.
    float pxV = F * px / mix(1.0, max(n.z, 0.12), 0.5);     // one pixel in cell units
    float bevel = max(0.06, pxV * 1.5);
    float s = saturate(e / bevel);
    vec3 nb = normalize(nf1 + nf2);
    vec3 ns = normalize(mix(nb, nf1, s));
    ns = normalize(ns + vec3(0.0, 0.0, max(0.0, 0.12 - ns.z)));

    // --- interior seen through the facet (refraction parallax) --------------
    vec3 Tr = refract(-V, ns, 0.66);
    vec3 To = rot * Tr;
    vec3 qv = q + To * 0.22;
    float fp = 1.0 - smoothstep(12.0, 40.0, facetPx);          // footprint: 1 = tiny planet
    // Gold veins: iso-lines of a domain-warped fbm (ridged profile), so they
    // thread and branch through the stone instead of forming blobs.
    vec3 vq = qv * 1.7 + seedOff * 0.37;
    float warp = fbm3lo(vq * 1.2 + 7.0);
    float vf = fbm3lo(vq + warp * 1.1);
    float vl = abs(vf - 0.5);
    float nW = noise3(vq * 2.3 + 3.0);                          // vein width AND strength along its length
    float vw0 = 0.006 * mix(0.4, 1.45, smoothstep(0.3, 0.7, nW));
    float vw = max(vw0, px * 1.3);
    float veinAmt = sqrt(vw0 / vw);                            // energy kept when blurred
    float vein = (1.0 - smoothstep(vw * 0.5, vw, vl)) * veinAmt;
    float veinCore = 1.0 - smoothstep(0.0, vw * 0.45, vl);
    float veinGlow = exp(-vl * vl * 3000.0);                   // light scattered around the vein
    float incl = warp;

    // Sub-facets: internal mirror planes split each facet into tones. The
    // second split only once facets are big enough to hold it (below ~40 px
    // it produced dark 'coin-slot' slivers).
    vec3 rv = -r1;
    float aa = pxV * 0.9;
    float zA = smoothstep(-aa, aa, dot(rv, normalize(h1.zxy - 0.5)) + (h1.y - 0.5) * 0.25);
    float zB = smoothstep(-aa, aa, dot(rv, normalize(h1.yzx - 0.5)) - (h1.z - 0.5) * 0.25) * smoothstep(32.0, 48.0, facetPx);
    float tone = mix(mix(h1.x, fract(h1.x * 5.3), zA), mix(fract(h1.y * 3.7), fract(h1.z * 7.9), zA), zB);
    float clarity = 1.0 - ng;
    float grad = dot(rv * rot, l);

    // Body: deep jewel green when healthy (treasure crystal, not pastel jade),
    // milky when neglected.
    float cloud = mix(0.35, 1.0, ng);
    float dep = saturate(0.65 + (incl - 0.5) * 1.6 * cloud + (h1.x - 0.5) * 0.55 - 0.3 * grad);
    vec3 body = mix(cSurf * 0.9, cDeep * 3.2, dep);
    float brill = min(mix(0.3, 1.5, h1.y) * (1.0 + (tone - 0.5) * 0.6 * clarity) * (1.0 + 0.7 * grad), 1.3);
    vec3 nd = normalize(mix(n, ns, 0.8));
    float wrap = saturate((dot(nd, l) + 0.1) / 1.1);
    float tl = lightMask * wrap;
    vec3 inner = body * tl * max(brill, 0.45) * mix(1.5, 1.8, th) * 0.48
               + (cDeep * 0.5 + cSurf * 0.006) * (0.3 + 0.7 * lightMask);

    // Gold veins inside the crystal (lit metal; their glow is emission below).
    float flow = 0.5 + 0.5 * sin(warp * 40.0 + vf * 12.0 - t * mix(0.4, 2.2, sc));
    vec3 veinMetal = mix(cGold, vec3(0.2, 0.13, 0.06), ng * 0.85);
    float veinE = mix(0.05, 1.0, rich) * (1.0 - ng * 0.8) * (0.3 + 0.7 * smoothstep(0.25, 0.6, nW));   // veins swell and fade along their length
    float vprof = saturate(1.0 - vl / vw);                              // 1 at the vein axis
    vec3 veinLit = mix(veinMetal * veinMetal, veinMetal, 0.3 + 0.5 * vprof) * (0.6 + 0.8 * vprof) * (tl * 1.4 + 0.02);
    inner *= 1.0 - (vein - veinCore) * 0.35;                           // dark seam around the vein
    inner = mix(inner, veinLit, vein * 0.9);
    float nhS = saturate(dot(n, hv));
    float nh8 = cr_p8(nhS);
    float sheen = nh8 * nh8 * nh8 * lightMask;                          // ≈ pow(n·h, 24)
    inner += cGold * veinCore * sheen * (1.2 - ng) * 1.2;

    // --- surface: reflections, star glints, prismatic fire ------------------
    float fres = 0.05 + 0.95 * pow(1.0 - saturate(ns.z), 5.0);
    vec3 R = reflect(-V, ns);
    float rl = saturate(dot(R, l));
    float starVis = smoothstep(-0.12, 0.1, ndl);
    float gloss = mix(1.0, 0.2, ng);
    float rl8 = cr_p8(rl), rl16 = rl8 * rl8, rl64 = rl16 * rl16 * rl16 * rl16;
    float rl256 = rl64 * rl64 * rl64 * rl64;
    float spec = (rl16 * 0.5 + rl64 * 2.0 + rl256 * 10.0) * gloss + rl * rl * rl * rl * rl * 0.1;
    // reflected sky: the atmosphere is only bright where the star lights it
    // (an unlit sky reflection drew a full mint ring round the night limb)
    vec3 sky = mix(cDeep * 0.6, atmoCol * 0.45, saturate(R.y * 0.5 + 0.5)) * 0.3 * (0.08 + 0.92 * smoothstep(-0.3, 0.3, ndl));
    vec3 c = inner * (1.0 - fres * 0.7) + sky * fres + vec3(1.0, 0.95, 0.85) * spec * starVis * (0.4 + fres);

    // Bevel glints with dispersion (red/blue split across the edge), faded
    // where a third facet takes over (no hard diagonal cut at junctions).
    if (e < bevel) {
      vec3 nR = normalize(mix(nb, nf1, saturate(s - 0.25)));
      vec3 nB = normalize(mix(nb, nf1, saturate(s + 0.25)));
      float dR = saturate(dot(reflect(-V, nR), l)), dB = saturate(dot(reflect(-V, nB), l));
      float dR8 = cr_p8(dR), dG8 = rl8, dB8 = cr_p8(dB);
      vec3 disp = vec3(dR8 * dR8 * dR8 * dR8 * dR8 * dR8, dG8 * dG8 * dG8 * dG8 * dG8 * dG8, dB8 * dB8 * dB8 * dB8 * dB8 * dB8);  // ≈ pow 48
      float junction = smoothstep(0.0, bevel, e3 - e);
      c += mix(vec3(luma(disp)), disp, 0.3 + 0.7 * th) * starVis * (1.0 - s) * mix(0.4, 1.4, th) * gloss * junction;
    }
    // Fire: coloured internal flashes in one sub-facet, changing with angle.
    vec3 nI = normalize(ns + (hash33(k1 + 5.1) - 0.5) * 0.9);
    float ri = saturate(dot(reflect(-V, nI), l));
    vec3 fo = hash33(k1 + 9.7) - 0.5;
    // the hue also sweeps ACROSS the flash (a prismatic streak, not a flat dot)
    float sweep = dot(rv - fo * 0.5, normalize(fo + 1e-3)) * 18.0;
    vec3 spectrum = saturate3(abs(fract(ri * 9.0 + h1.z + sweep + vec3(0.0, 0.33, 0.67)) * 6.0 - 3.0) - 1.0);
    float fW2 = max(0.0016, pxV * pxV * 2.5);
    float fspot = exp(-dot(rv - fo * 0.5, rv - fo * 0.5) / fW2) * (0.0016 / fW2);   // energy kept when blurred (no blotch at 22 px)
    float ri8 = cr_p8(ri);
    float fireAmt = ri8 * ri8 * fspot * starVis * clarity * (0.1 + 2.0 * th);
    vec3 fire = spectrum * fireAmt * 2.2;
    c += fire;
    // Edge hairlines (fade out when facets get small on screen).
    float hair = (1.0 - smoothstep(pxV * 0.3, pxV * 1.2, e)) * smoothstep(10.0, 30.0, facetPx);
    c += mix(cSurf, vec3(1.0), 0.4) * hair * (0.04 + 0.1 * th) * (0.1 + lightMask);

    // Sparkles keyed PER FACET: a star point on the facet's table that turns
    // with the stone, only on facets inside the specular lobe.
    float sDen = mix(0.0, 0.05, th) + pls * 0.3;
    if (sDen > 0.001) {
      vec3 hs = hash33(k1 + 13.7);
      float ph = t * (0.45 + 0.55 * hs.x) + hs.y;
      float cyc = floor(ph);
      if (hash12(k1.xy * 1.37 + k1.z * 3.1 + cyc * 7.13) > 1.0 - sDen) {   // this facet twinkles now
        float env = sin(fract(ph) * PI);
        env = env * env * env;
        vec2 d = (r1 * rot).xy / F * uRadius;                          // px from the facet's star point
        float core = exp(-dot(d, d) * 0.5);
        float arms = exp(-abs(d.x) * 0.38 - d.y * d.y * 2.0) + exp(-abs(d.y) * 0.38 - d.x * d.x * 2.0);
        float lobe = cr_p8(saturate(dot(nf1, hv)));
        c += vec3(1.0, 0.96, 0.86) * env * (core * 1.6 + arms * 0.5 * env) * lobe * s * lightMask * (1.0 - ng) * 1.8;
      }
    }

    // --- neglect: frost, fractures, dust (surface) --------------------------
    float crack = 0.0;
    if (ng > 0.01) {
      float frost = fbm3lo(q * 8.0 + seedOff);
      float fr = ng * (0.5 + 0.5 * smoothstep(0.35, 0.7, frost));
      vec3 milk = mix(vec3(0.3, 0.37, 0.36), cSurf * 0.5, 0.3) * (wrap * lightMask * 1.1 + 0.02);
      c = mix(c, milk + spec * 0.1, fr * 0.72);
      // Fractures: straight splits across the facets.
      vec3 hf = hash33(k1 + 71.3);
      float jag = (noise3(x * 7.0) - 0.5) * 0.06;
      float f1 = abs(dot(rv, normalize(hf - 0.5)) - (h1.y - 0.5) * 0.3 + jag);
      float f2 = abs(dot(rv, normalize(hf.zxy - 0.5)) + (h1.x - 0.5) * 0.3 + jag);
      float fw = pxV * 0.4;
      crack = max(1.0 - smoothstep(fw, fw * 2.2, f1), (1.0 - smoothstep(fw, fw * 2.2, f2)) * step(0.5, hf.y));
      crack *= smoothstep(hf.x - 0.05, hf.x + 0.05, ng * 1.25 - 0.25) * mix(0.35, 1.0, smoothstep(14.0, 45.0, facetPx));
      c = mix(c, vec3(0.72, 0.78, 0.78) * (lightMask * 0.75 + 0.03), crack * 0.5);
      float dust = dustStorm(q, t) * ng;
      c = mix(c, vec3(0.3, 0.22, 0.13) * (lightMask * 1.3 + 0.02), dust * 0.6);
    }

    // shared living-state grade (thriving richer, neglected dim & grey)
    vec3 lit = lifeGrade(c, th, ng);

    // --- emission (after the grade) ------------------------------------------
    vec3 emit = cGold * (veinGlow * 0.1 + vein * 0.25 + veinCore * 0.9) * veinE
              * (0.08 + 0.3 * th + 1.1 * night) * (0.7 + 0.8 * flow * th);
    // Settlements strung along the veins: tiny lights on the night side.
    if (fp < 0.99) {
      float town = smoothstep(0.78, 0.93, noise3(q * 60.0 + seedOff)) * smoothstep(0.035, 0.008, vl);
      emit += vec3(1.0, 0.8, 0.45) * town * (1.0 - fp) * veinE * night * (0.4 + 0.6 * th) * 2.0;
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
    emit += mix(cGold, vec3(1.0, 0.62, 0.25), 0.35) * ember * (0.05 + 1.8 * night) * (0.4 + 0.6 * th);
    // fracture glow (distress, shared colour and phase)
    emit += distressColor() * crack * pulseD * (0.3 + 0.7 * night) * 0.6;

    // --- atmosphere (shared family haze) ------------------------------------
    vec3 T;
    vec3 S = atmoHaze(mu, ndl, atmoCol, tau0, vec3(1.0, 0.9, 1.05), gain, phase, T);
    col = (lit + emit) * T + S;
    col += auC;
    // Back-light: star light leaks through the thin crystal at the limb, on
    // the star's side only (a crescent, like the family's forward scatter).
    vec2 dirN = n.xy / max(length(n.xy), 1e-4);
    float leak = smoothstep(-0.2, 0.6, dot(dirN, normalize(l.xy + 1e-4)));
    float mie = pow(saturate(-l.z), 3.0);
    col += cSurf * mie * pow(1.0 - saturate(mu), 2.5) * leak * 0.8;
    col += distressColor() * distressRim(mu, pulseD);
    // Celebration flourish: facets catch the light one after another as uPulse
    // moves, veins and lanterns flare (the limb shock ring is in the halo).
    float cascade = (1.0 - smoothstep(0.0, 0.12, abs(h1.z - (1.0 - pls)))) * pls;
    vec3 flash = mix(cSurf * 1.3, cGold, 0.45) * (0.45 + 0.9 * saturate(0.5 + grad)) * (1.0 + (1.0 - s) * 1.5);
    col += flash * cascade * (0.4 + 0.5 * lightMask);
    col += cGold * pls * (0.03 + pow(1.0 - saturate(mu), 4.0) * 1.0 + vein * 1.4 + ember * 1.6) + fire * pls * 2.0;
  }

  // --- halo (shared family model) -------------------------------------------
  vec3 halo = atmoHalo(p, l, atmoCol, tau0, 0.035, gain, phase, px);
  halo += auC;
  halo += cGold * limbShock(r, pls, px) * 0.6;
  halo += distressColor() * distressHalo(r, pulseD, px);

  fragColor = compositeDiscHalo(col, discA, halo, frag);
}
