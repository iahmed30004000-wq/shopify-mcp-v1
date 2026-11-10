#version 460 core
#include <flutter/runtime_effect.glsl>
#include "lib/common.glsl"

// ---------------------------------------------------------------------------
// TRAVEL — a ringed gas giant. Latitudinal cloud bands (belts and zones)
// sheared by differential jets and turbulence, a great rose storm vortex and
// a white oval, soft limb darkening; broad rings with gaps and fine ringlets
// drawn analytically
// (ray / ring-plane intersection) with correct mutual occlusion, the planet's
// shadow across the rings and the rings' shadow bands on the clouds; tiny
// ships glide along lanes in the ring plane, one per upcoming trip.
//
// Living state (uScore): thriving = vivid bands, sparkling rings, aurora,
// night-side sky-city lights and lightning; neglected = faded bands, haze,
// dusty dim clumpy rings, faint rifts, distress pulse.
//
// uExtra.x  number of upcoming trips (0..6) → that many ships with faint
//           trails (fractional values fade the last ship in).
// uExtra.y  ring roll in the screen plane, radians, added to the built-in
//           -0.3 slant (0 → default look).
// uExtra.zw unused.
// uSpin.x spin angle, uSpin.y axial tilt = ring opening toward the viewer
// (its magnitude is clamped to ≥ 0.2 rad so the rings always read).
// haloFactor: 2.3 (main rings to 2.04 R, F ring 2.10 R, ship lanes to 2.17 R).
// Round 2: the ships are ships – 3–5 px gold arrowhead (chevron) silhouettes
// pointing along their course with a comet wake behind, never sparkles; a
// neglected giant stays a desaturated VIOLET (never a grey ball).
//
// FAMILY LOOK (common.glsl): lifeGrade on the lit clouds (before the night
// lights), the shared forward-scatter haze/halo, ONE aurora evaluation
// (auroraCurtains, shared by disc and halo), the limb shock ring + a gold wave
// through the rings for celebrations, the shared distress rim/halo, and
// compositeDiscHalo for disc + halo (the rings are layered around it: back
// ring under, front ring over, ships on top).
// Ships are warm gold beads (≥ 2.5 px) with a readable wake; below 40 px they
// become bright beads with a lane arc so 0 / 2 / 6 trips stay countable.
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

// Soft band [a, b] with edge half-width w.
float ggBand(float x, float a, float b, float w) {
  return smoothstep(a - w, a + w, x) * (1.0 - smoothstep(b - w, b + w, x));
}

// Ring optical density (0..1) at ring-plane radius rr (planet radii).
// aa: radial pixel footprint, fine: ringlet amount (0..1).
float ggRingDensity(float rr, float aa, float fine) {
  float w = max(aa, 0.003);
  float d = 0.0;
  d += 0.16 * ggBand(rr, 1.20, 1.395, w) * (0.7 + 0.3 * smoothstep(1.2, 1.39, rr));    // C ring
  d += (0.72 + 0.23 * smoothstep(1.42, 1.62, rr)) * ggBand(rr, 1.395, 1.76, w);          // B ring
  d += 0.05 * ggBand(rr, 1.76, 1.83, w);                                                // Cassini
  d += 0.52 * ggBand(rr, 1.83, 2.035, w) * (1.0 - 0.25 * smoothstep(1.9, 2.03, rr));   // A ring
  float enc = abs(rr - 1.985);
  d *= 1.0 - 0.92 * (1.0 - smoothstep(0.004, 0.004 + w * 2.0, enc));                   // Encke gap
  float fw = max(0.005, aa * 1.2);
  float fd = (rr - 2.1) / fw;
  d += 0.45 * exp(-fd * fd) * (0.005 / fw);                                             // F ring
  // Ringlets (band-limited by the pixel footprint).
  float f1 = smoothstep(0.012, 0.004, aa);
  float f2 = smoothstep(0.004, 0.0015, aa);
  float rl = (noise2(vec2(rr * 55.0, 0.5)) - 0.5) * f1 + (noise2(vec2(rr * 160.0, 7.5)) - 0.5) * f2 * 0.8;
  d *= 1.0 + rl * 1.1 * fine;
  return saturate(d);
}


void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 p = (frag - uCenter) / uRadius;
  p.y = -p.y;
  float r = length(p);
  float px = 1.0 / uRadius;
  float t = uTime;
  vec3 l = normalize(uLight);
  float th = thrive(uScore);
  float ng = neglect(uScore);
  float act = smoothstep(0.02, 1.0, uScore);
  float detail = saturate(uDetail);

  vec3 surf = toLinear(uColorA.rgb);
  vec3 glow = toLinear(uColorB.rgb);
  vec3 deep = toLinear(uColorC.rgb);
  vec3 dustC = toLinear(vec3(0.56, 0.5, 0.45));
  vec3 gold = glow * vec3(1.0, 0.85, 0.55);

  // --- frame: planet axis = ring normal ------------------------------------
  float tiltE = (uSpin.y < 0.0 ? -1.0 : 1.0) * max(abs(uSpin.y), 0.2);
  float roll = -0.3 + uExtra.y;
  vec3 A = vec3(-sin(roll) * cos(tiltE), cos(roll) * cos(tiltE), sin(tiltE));
  vec3 E1 = normalize(cross(A, vec3(0.0, 0.0, 1.0)));
  vec3 E2 = cross(E1, A);
  float spin = uSpin.x + t * 0.035;
  vec3 S1 = cos(spin) * E1 + sin(spin) * E2;       // spun planet basis
  vec3 S2 = -sin(spin) * E1 + cos(spin) * E2;
  // view → planet frame (rows S1, A, S2): q = rot * n, object +y = north.
  mat3 rot = mat3(S1.x, A.x, S2.x, S1.y, A.y, S2.y, S1.z, A.z, S2.z);

  // --- shared family parameters (disc and halo use the same ones) -------------
  vec3 atmoCol = mix(glow, surf, 0.3);
  atmoCol = mix(atmoCol, dustC * 0.8, ng * 0.6);
  float phase = atmoPhase(l);
  float gain = 2.0 * haloGain(th, ng) * (1.0 + 0.5 * uPulse);
  float tau0 = 0.032 * (1.0 + 1.2 * ng);
  float pulseD = distressPulse(t) * ng;
  // ONE aurora evaluation for disc and halo (lavender → rose curtains).
  // Cheap conservative pre-test: the view ray through p can only meet the
  // auroral cone |X·A| = c|X| inside the curtain shell if |X·A| can reach
  // ~c there (skips the noise taps over most of the disc).
  float auK = th * 0.9 + uPulse * 0.8;
  float auReach = abs(dot(p, A.xy)) + abs(A.z) * sqrt(max((1.0 + AURORA_H) * (1.0 + AURORA_H) - r * r, 0.0));
  vec2 au = (auK > 0.001 && r < 1.0 + AURORA_H && auReach > 0.92 - 0.04)
          ? auroraCurtains(p, rot, l, 0.92, t, px) * auK : vec2(0.0);
  vec3 auBase = glow * vec3(0.85, 0.8, 1.0);
  vec3 auTop = mix(surf, vec3(1.0, 0.4, 0.75), 0.4);
  vec3 auC = mix(auBase, auTop, saturate(au.y / max(au.x, 1e-4) * 2.0)) * au.x * 0.22;

  // --- ring-plane intersection for this pixel --------------------------------
  float zr = -(p.x * A.x + p.y * A.y) / A.z;
  vec3 PR = vec3(p, zr);
  float rr = length(PR);
  float aaR = px * rr / max(r, 0.15 * rr);          // radial pixel footprint in the ring plane
  float ringFine = mix(1.0, 0.35, ng);
  float ringD = 0.0;
  vec3 ringCol = vec3(0.0);
  float ringA = 0.0;
  float sideL = dot(l, A) * sign(A.z);             // > 0: we see the lit face

  if (rr > 1.15 && rr < 2.16) {
    ringD = ggRingDensity(rr, aaR, ringFine);
    float phi = atan(dot(PR, E2), dot(PR, E1));
    // Neglect: the rings clump and break up into dusty arcs.
    if (ng > 0.001) {
      float clump = noise3(vec3(cos(phi) * 2.2, sin(phi) * 2.2, rr * 3.5 + t * 0.01));
      ringD *= mix(1.0, 0.55 + 0.6 * clump, ng * 0.7);
    }
    // Colour across the radius: darker C ring, bright creamy B, cooler A.
    vec3 ice = mix(glow, toLinear(vec3(0.98, 0.92, 0.86)), 0.4) * 0.8;
    vec3 cCol = mix(surf, deep, 0.5) * 0.7 + ice * 0.1;
    vec3 aCol = mix(ice, surf, 0.35);
    vec3 rc = mix(cCol, ice, smoothstep(1.36, 1.48, rr));
    rc = mix(rc, aCol, smoothstep(1.78, 1.9, rr));
    float tint = noise2(vec2(rr * 23.0, 11.5));
    rc *= 0.85 + 0.3 * tint;
    rc = mix(rc, desaturate(rc, 1.0) * dustC * 1.4, ng * 0.75);

    // Illumination: lit face vs diffuse transmission through the unlit face.
    float inc = pow(abs(sideL), 0.35);
    float face = smoothstep(-0.04, 0.04, sideL);
    float refl = mix(0.55, 1.0, ringD);
    float transmit = ringD * (1.0 - ringD) * 2.2;
    float lum = mix(transmit, refl, face) * inc;
    // Forward scattering at high phase angle: thin, dusty ringlets glow,
    // the dense B ring stays comparatively dark.
    float fwd = pow(saturate(-l.z), 3.0) * (0.1 + ringD * (1.0 - ringD) * (1.0 - ringD) * 9.0) * 1.3;
    // Planet shadow on the rings.
    float tc = -dot(PR, l);
    float dc = sqrt(max(dot(PR, PR) - tc * tc, 0.0));
    float shadow = tc > 0.0 ? smoothstep(0.97, 1.03, dc) : 1.0;
    // Planetshine: faint lift on the rings from the lit planet.
    float pshine = 0.04 * saturate(dot(-normalize(PR), l) * 0.5 + 0.5);
    ringCol = rc * (lum * 1.1 * shadow + pshine) + mix(glow, rc, 0.4) * fwd * shadow;
    // Living state: same grade as the clouds (thriving rings are a touch
    // richer and brighter; neglected ones dim, dusty grey).
    ringCol = lifeGrade(ringCol * mix(0.7, 1.0, act), th, ng);
    // Sparkling ice (thriving).
    float spk = step(0.998, hash12(floor(frag) + floor(t * 6.0) * 3.17));
    ringCol += vec3(1.0, 0.97, 1.0) * spk * th * ringD * shadow * face * 0.9 * smoothstep(40.0, 120.0, uRadius);
    // Celebration: a bright GOLD wave rippling outward through the rings.
    float wr = 1.2 + (1.0 - uPulse) * 1.0;
    float wv = (rr - wr) / 0.06;
    ringCol += gold * (exp(-wv * wv) * uPulse * 3.0 + uPulse * 0.5 * ringD);
    ringA = 1.0 - exp(-ringD * 0.85 / max(abs(A.z), 0.2));
    // Neglect: dust haze smeared around the ring plane.
    float dustBand = ng * 0.12 * ggBand(rr, 1.15, 2.1, 0.06);
    ringCol = mix(ringCol, dustC * 0.06 * (inc + fwd), dustBand * (1.0 - ringD));
    ringA = max(ringA, dustBand);
  }

  // --- planet disc -------------------------------------------------------------
  float discA = discMask(p, uRadius);
  vec3 col = vec3(0.0);
  if (r < 1.0 + 2.0 * px) {
    vec2 pc = p / max(r, 1.0) * 0.9999;
    vec3 n = sphereNormal(pc);
    vec3 q = rot * n;                                    // planet frame (y = north)
    float seed = uSeed * 1.73;

    // Storms: a great rose vortex in the northern tropics and a smaller white
    // oval just south of the equator (opposite longitude) swirl the clouds.
    vec3 qw = q;
    float srhoOut = 9.0;
    float sIn = 0.0;
    float sArm = 0.5;
    float collar = 0.0;
    float wIn = 0.0;
    {
      float latS = 0.4;
      float lonS = 4.9 + uSeed * 2.0 + t * 0.004;
      vec3 sc = vec3(cos(latS) * cos(lonS), sin(latS), cos(latS) * sin(lonS));
      vec3 se = normalize(vec3(-sc.z, 0.0, sc.x));
      vec3 sn = cross(sc, se);
      vec3 dq = q - sc;
      vec2 suv = vec2(dot(dq, se) / 0.26, dot(dq, sn) / 0.14);
      float srho = length(suv);
      srhoOut = srho;
      float sMask = step(0.0, dot(q, sc));
      // Bounded "breathing" swirl (a time-linear twist would wind up forever).
      float swirl = 2.8 * exp(-srho * srho * 1.2) * (1.0 + 0.18 * sin(t * 0.35)) * sMask;
      float cs = cos(swirl);
      float ss = sin(swirl);
      vec2 suv2 = vec2(cs * suv.x - ss * suv.y, ss * suv.x + cs * suv.y);
      qw += se * (suv2.x - suv.x) * 0.26 + sn * (suv2.y - suv.y) * 0.14;
      sIn = smoothstep(1.05, 0.35, srho) * sMask;
      // Two spiral arms winding into the eye (bounded, slowly turning).
      sArm = 0.5 + 0.5 * sin(atan(suv.y, suv.x) * 2.0 + srho * 7.0 - t * 0.25);
      float cl = srho - 1.05;
      collar = exp(-cl * cl / 0.025) * sMask;
    }
    {
      float latW = -0.1;
      float lonW = 4.9 + uSeed * 2.0 + PI + t * 0.006;
      vec3 wc = vec3(cos(latW) * cos(lonW), sin(latW), cos(latW) * sin(lonW));
      vec3 we = normalize(vec3(-wc.z, 0.0, wc.x));
      vec3 wn = cross(wc, we);
      vec3 dq = q - wc;
      vec2 wuv = vec2(dot(dq, we) / 0.1, dot(dq, wn) / 0.065);
      float wrho = length(wuv);
      float wMask = step(0.0, dot(q, wc));
      float swirl = -2.2 * exp(-wrho * wrho * 1.3) * (1.0 + 0.2 * sin(t * 0.5 + 1.0)) * wMask;
      float cs = cos(swirl);
      float ss = sin(swirl);
      vec2 wuv2 = vec2(cs * wuv.x - ss * wuv.y, ss * wuv.x + cs * wuv.y);
      qw += we * (wuv2.x - wuv.x) * 0.1 + wn * (wuv2.y - wuv.y) * 0.065;
      wIn = smoothstep(1.0, 0.5, wrho) * wMask;
    }

    // Differential jets: turbulence advected per latitude with a two-phase
    // flow blend (bounded shear, no pops).
    float jet = 0.05 * sin(qw.y * 9.0 + 0.7) + 0.025 * sin(qw.y * 23.0);
    const float PT = 24.0;
    float ph0 = fract(t / PT);
    float ph1 = fract(t / PT + 0.5);
    float fl = abs(1.0 - 2.0 * ph0);
    float a0 = jet * (ph0 - 0.5) * PT;
    float a1 = jet * (ph1 - 0.5) * PT;
    vec3 k0 = vec3(qw.x * cos(a0) - qw.z * sin(a0), qw.y, qw.x * sin(a0) + qw.z * cos(a0));
    vec3 k1 = vec3(qw.x * cos(a1) - qw.z * sin(a1), qw.y, qw.x * sin(a1) + qw.z * cos(a1));
    vec3 aniso = vec3(2.6, 10.0, 2.6);
    float tb0;
    float tb1;
    float st = 0.5;
    if (detail > 0.55) {
      tb0 = fbm3(k0 * aniso + seed);
      tb1 = fbm3(k1 * aniso + seed + 17.0);
      // Fine streaks drawn out along the jets.
      float fs = smoothstep(0.012, 0.004, px / max(n.z, 0.25));
      st = mix(0.5, mix(noise3(k0 * vec3(9.0, 55.0, 9.0) + seed), noise3(k1 * vec3(9.0, 55.0, 9.0) + seed + 5.0), fl), fs);
    } else {
      tb0 = fbm3lo(k0 * aniso + seed);
      tb1 = fbm3lo(k1 * aniso + seed + 17.0);
    }
    float turb = mix(tb0, tb1, fl);

    // Bands: 1-D noise in warped latitude, sharpened into belts and zones.
    float y = qw.y + (turb - 0.5) * 0.13 + (st - 0.5) * 0.012;
    float b1 = noise2(vec2(y * 5.2 + seed, 0.5));
    float b2 = noise2(vec2(y * 13.0 + seed * 2.0, 5.5));
    float b3 = noise2(vec2(y * 33.0 + seed * 3.0, 9.5)) * smoothstep(0.02, 0.008, px);
    float bandL = b1 * 0.58 + b2 * 0.3 + (b3 - 0.5) * 0.18 + 0.06;
    float band = smoothstep(0.3, 0.7, bandL);
    // Band contrast fades with neglect only (steady keeps its structure; the
    // thriving cue is vividness + brightness, below).
    float contrast = mix(0.55, 1.0, smoothstep(0.02, 0.6, uScore)) * (1.0 - ng * 0.35);
    vec3 cream = toLinear(vec3(0.98, 0.93, 0.9));
    vec3 beltC = mix(surf, deep, 0.6);
    vec3 zoneC = mix(glow, cream, 0.35);
    // close up the jets' fine streaks and eddies carry more contrast (the
    // bands must not read as soft smears at hero scale)
    float v = saturate(band * 0.85 + (turb - 0.5) * mix(0.5, 0.72, smoothstep(0.55, 0.9, detail)) + (st - 0.5) * 0.38);
    vec3 albedo = mix(beltC, surf, smoothstep(0.0, 0.42, v));
    albedo = mix(albedo, glow * 0.9, smoothstep(0.38, 0.7, v));
    albedo = mix(albedo, zoneC, smoothstep(0.68, 0.95, v));
    // A warmer rose tint in some belts for richness.
    albedo = mix(albedo, albedo * vec3(1.2, 0.86, 0.92), smoothstep(0.55, 0.8, b2) * (1.0 - band) * 0.6);
    albedo = mix(mix(surf, glow, 0.45), albedo, contrast);
    // Poles: deep-violet hoods with a faint hexagonal jet in the north,
    // evaluated on the turbulent coordinates so it reads as a cloud jet,
    // not a drawn outline.
    float pole = smoothstep(0.72, 0.95, abs(q.y));
    albedo = mix(albedo, mix(deep, surf, 0.4) * (0.8 + 0.4 * turb), pole * 0.75);
    if (qw.y > 0.78) {
      float ang = atan(qw.z, qw.x);
      float hexR = length(qw.xz) * cos(PI / 6.0) / cos(mod(ang + t * 0.02, PI / 3.0) - PI / 6.0);
      float hx = (hexR - 0.34 + (turb - 0.5) * 0.04) / 0.035;
      albedo = mix(albedo, zoneC * 0.7, exp(-hx * hx) * 0.15 * contrast);
    }
    // Storm colours: rose eye with a pale collar; white oval.
    vec3 stormC = mix(toLinear(vec3(0.93, 0.52, 0.66)), surf, 0.2);
    vec3 stormCol = mix(stormC * 0.75, mix(stormC, cream, 0.35), sArm * smoothstep(0.1, 0.6, srhoOut)) * (0.8 + 0.4 * turb);
    stormCol = mix(stormCol, stormC * 0.55, smoothstep(0.35, 0.0, srhoOut));   // darker eye
    albedo = mix(albedo, stormCol, sIn * mix(0.35, 0.9, act));
    albedo = mix(albedo, zoneC, collar * 0.35);
    albedo = mix(albedo, cream, wIn * 0.7 * mix(0.5, 1.0, act));
    // Thriving: vivid, saturated bands (a low-frequency day-side read at 22 px).
    albedo = max(mix(vec3(luma(albedo)), albedo, 1.0 + 0.5 * th), 0.0);

    // Neglect: faded, hazy, dusty bands – still violet (the shared grade
    // does the dimming; the dust is tinted with the world's own hue).
    albedo = desaturate(albedo, ng * 0.2);
    albedo = mix(albedo, mix(dustC, surf, 0.55) * 0.6, ng * 0.2);

    // Lighting: soft terminator (thick atmosphere) and gentle limb darkening.
    float ndl = dot(n, l);
    float diff = smoothstep(-0.2, 0.55, ndl) * saturate(ndl * 0.75 + 0.3);
    float limbD = pow(max(n.z, 0.0), 0.38);
    // Ring shadow bands on the clouds (only where the sun reaches).
    float rShadow = 1.0;
    if (ndl > -0.2) {
      float tl = -dot(n, A) / dot(l, A);
      if (tl > 0.0) {
        vec3 shp = n + l * tl;
        float sr = length(shp);
        if (sr > 1.15 && sr < 2.16) {
          float sd = ggRingDensity(sr, 0.004, ringFine * 0.6);
          rShadow = 1.0 - (1.0 - exp(-sd * 0.85 / max(abs(dot(l, A)), 0.15))) * 0.9;
        }
      }
    }
    float night = 1.0 - smoothstep(-0.25, 0.12, ndl);
    vec3 lit = albedo * diff * limbD * rShadow;

    // Haze and dust storms (neglect).
    if (ng > 0.001) {
      float dust = dustStorm(q * vec3(1.0, 2.2, 1.0), t) * ng;
      lit = mix(lit, dustC * 0.55 * (diff * 1.3 + 0.01), dust * 0.55);
      lit = mix(lit, dustC * 0.5 * (diff + 0.02), ng * 0.22);
      // Shear streaks: dark, latitude-stretched tears where the jets rip the
      // decks apart (1-D lanes in latitude × longitude-stretched turbulence),
      // the gas-world vocabulary for decay instead of polygon cracks.
      float shearVis = smoothstep(0.4, 0.9, ng) * smoothstep(0.03, 0.012, px);
      if (shearVis > 0.001) {
        float lane = smoothstep(0.52, 0.86, noise2(vec2(y * 24.0 + seed * 1.3, 13.5)));
        float tear = smoothstep(0.4, 0.8, noise3(k0 * vec3(2.2, 30.0, 2.2) + seed + 3.0));
        float shear = lane * tear * shearVis;
        lit *= 1.0 - shear * 0.4;
      }
    }

    // Shared living-state grade on the reflected light (before the lights).
    lit = lifeGrade(lit, th, ng);

    // Night side: sky-city lights clustered along the zone edges (sparse,
    // gated by a clustering noise so they never read as a starfield seen
    // through the planet), and lightning in the belts.
    vec3 emit = vec3(0.0);
    if (night > 0.001 && th > 0.001) {
      vec3 cq = q * 26.0 + seed;
      vec3 cc = floor(cq);
      vec3 ch = hash33(cc);
      float cd = length(cq - cc - (0.3 + 0.4 * ch));
      float zoneEdge = smoothstep(0.35, 0.85, 1.0 - abs(band * 2.0 - 1.0));
      float cluster = smoothstep(0.55, 0.8, noise3(q * 4.0 + seed + 1.3));
      float cityZone = zoneEdge * cluster * (1.0 - pole) * step(0.8, ch.z);
      float city = exp(-cd * cd * 70.0) * cityZone * (0.6 + 0.4 * sin(t * (1.0 + ch.x * 2.0) + ch.y * 30.0));
      city *= smoothstep(0.012, 0.005, px / max(n.z, 0.2));
      vec3 lq = q * 7.0 + seed + 3.0;
      vec3 lc = floor(lq);
      vec3 lh = hash33(lc + floor(t * 1.7) * 0.37);
      float ld = length(lq - lc - (0.25 + 0.5 * lh));
      float bolt = exp(-ld * ld * 140.0) * step(0.95, lh.x) * (1.0 - band) * (0.5 + 0.5 * sin(t * 40.0 + lh.y * 20.0));
      emit = (toLinear(vec3(1.0, 0.82, 0.55)) * city * 1.4 + mix(glow, vec3(0.75, 0.9, 1.0), 0.5) * bolt * 0.9) * night * th;
    }

    // Shared haze (continuous with the halo at the limb).
    vec3 T3;
    vec3 S = atmoHaze(n.z, ndl, atmoCol, tau0, vec3(1.15, 1.0, 0.85), gain, phase, T3);
    col = (lit + emit) * T3 + S;
    col += auC;
    col += distressColor() * distressRim(n.z, pulseD);
    // Celebration flourish: the whole deck flares gold toward the limb.
    col += gold * uPulse * (0.05 + pow(1.0 - saturate(n.z), 4.0) * 1.2);
  }

  // --- halo (shared; skipped far from the limb) ---------------------------------
  vec3 halo = vec3(0.0);
  if (r > 1.0 - 2.0 * px && r < 1.45) {
    halo = atmoHalo(p, l, atmoCol, tau0, 0.035, gain, phase, px);
    halo += auC;
    halo += gold * limbShock(r, uPulse, px) * 0.9;
    halo += distressColor() * distressHalo(r, pulseD, px);
  }

  // --- ships along the ring plane --------------------------------------------------
  vec3 shipCol = vec3(0.0);
  float trips = clamp(uExtra.x, 0.0, 6.0);
  if (trips > 0.001) {
    float sizePx = clamp(uRadius * 0.012, 2.5, 3.6);
    // Small planets: each ship is a bright bead (bigger core, a lane arc)
    // so the number of upcoming trips can still be counted at a glance.
    float small = 1.0 - smoothstep(28.0, 40.0, uRadius);
    float beadPx = mix(sizePx, 2.6, small);
    float phiP = atan(dot(PR, E2), dot(PR, E1));
    float zs = sqrt(max(1.0 - r * r, 0.0));
    float trailVis = (r < 1.0 && zr < zs) ? 0.0 : 1.0;
    vec3 warm = mix(glow, vec3(1.0, 0.72, 0.35), 0.6);
    for (int i = 0; i < 6; i++) {
      float fi = float(i);
      float vis = saturate(trips - fi);
      if (vis > 0.0) {
        float lane = mod(fi, 3.0);
        float R = lane < 0.5 ? 1.795 : (lane < 1.5 ? 2.075 : 2.16);
        R += fi >= 3.0 ? 0.012 : 0.0;
        float w = 0.55 / (R * sqrt(R));
        float ang = fi * 2.39996 + uSeed * 1.3 + w * t;
        vec3 SP = R * (cos(ang) * E1 + sin(ang) * E2);
        // Early-out: most of the 2.3 R rect is far from both this ship's bead
        // (bloom / glint support) and its lane (wake): skip the shading.
        float radPx = abs(rr - R) * (r / max(rr, 1e-3)) / px;
        float tw = max(0.9, sizePx * 0.45);
        vec2 dv0 = (p - SP.xy) / px;
        float reach = max(beadPx * 10.0, sizePx * 18.0);
        if (dot(dv0, dv0) > reach * reach && radPx > tw * 3.5) continue;
        float sr2 = dot(SP.xy, SP.xy);
        float hidden = (sr2 < 1.0 && SP.z < sqrt(max(1.0 - sr2, 0.0))) ? 1.0 : 0.0;
        vec2 dv = (p - SP.xy) / px;
        float d = length(dv);
        // The hull: a chevron pointing along the course (screen-space
        // tangent of the lane at the ship), 3–5 px long.
        vec3 tang = -sin(ang) * E1 + cos(ang) * E2;
        vec2 hd = normalize(tang.xy + vec2(1e-5, 0.0));
        vec2 hp = vec2(-hd.y, hd.x);
        float al = dot(dv, hd), ac = abs(dot(dv, hp));
        float L = mix(max(3.4, sizePx * 1.4), 3.2, small);
        float Wd = L * 0.44;
        float d1 = 0.55 * L - al;                                         // behind the tip
        float d2 = (Wd * (0.55 * L - al) / L - ac) / 1.1;                 // inside the flanks
        float d3 = (al + 0.12 * L + (0.33 * L / Wd) * ac) / 1.3;          // ahead of the notched stern
        float hull = smoothstep(-0.55, 0.55, min(d1, min(d2, d3)));
        float core = hull;
        // (finite support: gamma would lift an exponential tail into a visible box)
        float bloom = (exp(-d / (beadPx * 1.0)) * 0.12) * smoothstep(beadPx * 5.0, beadPx * 2.5, d);
        // engine glow at the stern (behind the hull, into the wake)
        float engine = exp(-dot(dv + hd * L * 0.35, dv + hd * L * 0.35) / (L * L * 0.08)) * 0.5;
        float glint = engine;
        // Wake: a luminous arc behind the ship on its lane, brightest at the head.
        float dth = mod(ang - phiP, TAU);
        float tLen = mix(0.9, 0.45, small);
        float trail = exp(-radPx * radPx / (tw * tw)) * (exp(-dth / tLen) + exp(-dth / 0.12) * 0.8) * smoothstep(2.8, 1.6, dth) * trailVis;
        trail *= step(radPx, tw * 3.5);
        trail *= smoothstep(0.0, 0.03, dth);
        vec3 hue = mix(warm, vec3(1.0, 0.93, 0.8), 0.25 + 0.15 * sin(fi * 2.1));
        float I = (core * mix(1.6, 2.2, small) + bloom + glint) * (1.0 - hidden);
        I *= vis * (1.0 + uPulse * 1.5);
        shipCol += hue * I + mix(warm, hue, exp(-dth / 0.25)) * trail * mix(0.9, 0.45, small) * vis;
      }
    }
  }

  // --- composite (premultiplied, display space) ------------------------------------
  // Disc over halo with the shared convention, the rings layered around it.
  vec4 acc = compositeDiscHalo(col, discA, halo, frag);
  vec3 ringC = toGamma(tonemapACES(ringCol));
  float zSurf = sqrt(max(1.0 - r * r, 0.0));
  float ringFront = r < 1.0 ? step(zSurf, zr) : step(0.0, zr);
  vec4 ringL = vec4(ringC * ringA, ringA);
  acc = acc + ringL * (1.0 - ringFront) * (1.0 - acc.a);          // back ring under disc + halo
  acc = ringL * ringFront + acc * (1.0 - ringA * ringFront);        // front ring over
  // Ships are self-luminous and already occlusion-tested: add on top.
  vec3 shipG = toGamma(tonemapACES(max(shipCol - 0.0015, 0.0)));
  float shipA = saturate(max(shipG.r, max(shipG.g, shipG.b)));
  acc = vec4(shipG, shipA) + acc * (1.0 - shipA);
  fragColor = vec4(min(acc.rgb, vec3(acc.a)), acc.a);
}
