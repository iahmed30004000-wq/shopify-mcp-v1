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

// Polar aurora: analytic curtain sheets (derivation in planet_volcanic.frag).
// Cone of half-angle colat0 about the axis As, extruded to height H.
vec3 ggCurtain(vec2 p, float r, vec3 As, vec3 B1, vec3 B2, float t, float px, float hemi, vec3 cLow, vec3 cHigh) {
  const float H = 0.09;
  const float Hs = 0.032;
  float R1 = 1.0 + H;
  float zt2 = R1 * R1 - r * r;
  if (zt2 <= 0.0) return vec3(0.0);
  float z1 = sqrt(zt2);
  float z0 = r < 1.0 ? sqrt(1.0 - r * r) : -z1;
  vec3 dref = r < 1.0 ? vec3(p, z0) : vec3(p / r, 0.0);
  float cref = dot(dref, As);
  if (cref < 0.74) return vec3(0.0);
  vec2 dir = normalize(vec2(dot(dref, B1), dot(dref, B2)) + 1e-4);
  float wob = noise3(vec3(dir * 2.3, t * 0.05 + hemi)) - 0.5;
  float fold = noise3(vec3(dir * 10.0, t * 0.18 + hemi)) - 0.5;
  float colat0 = 0.33 + wob * 0.1 + fold * 0.018;
  // Arcs brighten and break along the oval (substorm structure).
  float arcs = smoothstep(0.2, 0.75, noise3(vec3(dir * 3.2, t * 0.07 + hemi + 2.0)));
  float c = cos(colat0);
  float delta = sin(colat0) * max(0.02, px * 1.5);
  float a = dot(p, As.xy);
  float b = As.z;
  vec3 res = vec3(0.0);
  if (r < 1.0) {
    float gd = (cref - c) / delta;
    float rays = 0.45 + 0.55 * noise3(vec3(dir * 24.0, t * 0.4 + hemi));
    res = cLow * exp(-gd * gd) * rays * (0.35 + 0.65 * arcs) * Hs * 0.7;
  }
  float qa = b * b - c * c;
  qa = abs(qa) < 1e-5 ? 1e-5 : qa;
  float qb = 2.0 * a * b;
  float qc = a * a - c * c * r * r;
  float disc = qb * qb - 4.0 * qa * qc;
  if (disc > 0.0) {
    float sq = sqrt(disc);
    for (int k = 0; k < 2; k++) {
      float z = (-qb + (k == 0 ? -sq : sq)) / (2.0 * qa);
      float L2 = r * r + z * z;
      float L = sqrt(L2);
      float h = L - 1.0;
      if (z >= z0 && z <= z1 && (a + b * z) > 0.0 && h > -0.001) {
        float fp = abs(b / L - (a + b * z) * z / (L2 * L));
        float dz = min(delta / max(fp, 1e-4), Hs * 0.8);
        float g = exp(-h / Hs) * (1.0 - smoothstep(H * 0.55, H, h));
        vec3 P = vec3(p, z) / L;
        vec2 hd = normalize(vec2(dot(P, B1), dot(P, B2)) + 1e-4);
        float rays = 0.45 + 0.55 * noise3(vec3(hd * 24.0, t * 0.4 + hemi));
        res = max(res, mix(cLow, cHigh, smoothstep(0.0, H * 0.8, h)) * g * dz * rays * (0.3 + 0.7 * arcs));
      }
    }
  }
  return res;
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
  vec3 distressC = toLinear(vec3(1.0, 0.25, 0.18));

  // --- frame: planet axis = ring normal ------------------------------------
  float tiltE = (uSpin.y < 0.0 ? -1.0 : 1.0) * max(abs(uSpin.y), 0.2);
  float roll = -0.3 + uExtra.y;
  vec3 A = vec3(-sin(roll) * cos(tiltE), cos(roll) * cos(tiltE), sin(tiltE));
  vec3 E1 = normalize(cross(A, vec3(0.0, 0.0, 1.0)));
  vec3 E2 = cross(E1, A);
  float spin = uSpin.x + t * 0.035;
  vec3 S1 = cos(spin) * E1 + sin(spin) * E2;       // spun planet basis
  vec3 S2 = -sin(spin) * E1 + cos(spin) * E2;

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
    // Forward scattering when back-lit (dusty, thinner parts glow).
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
    ringCol *= mix(0.55, 1.0, act) * (1.0 - ng * 0.35);
    // Sparkling ice (thriving).
    float spk = step(0.998, hash12(floor(frag) + floor(t * 6.0) * 3.17));
    ringCol += vec3(1.0, 0.97, 1.0) * spk * th * ringD * shadow * face * 0.9 * smoothstep(40.0, 120.0, uRadius);
    // Celebration: a bright wave rippling outward through the rings.
    float wr = 1.2 + (1.0 - uPulse) * 1.0;
    float wv = (rr - wr) / 0.06;
    ringCol += glow * exp(-wv * wv) * uPulse * 1.5 + glow * uPulse * 0.25 * ringD;
    ringA = 1.0 - exp(-ringD * 0.85 / max(abs(A.z), 0.2));
    // Neglect: dust haze smeared around the ring plane.
    float dustBand = ng * 0.12 * ggBand(rr, 1.15, 2.1, 0.06);
    ringCol = mix(ringCol, dustC * 0.06 * (inc + fwd), dustBand * (1.0 - ringD));
    ringA = max(ringA, dustBand);
  }

  // --- planet disc -------------------------------------------------------------
  vec3 col = vec3(0.0);
  if (r < 1.0 + 2.0 * px) {
    vec2 pc = p / max(r, 1.0) * 0.9999;
    vec3 n = sphereNormal(pc);
    vec3 q = vec3(dot(n, S1), dot(n, A), dot(n, S2));      // planet frame (y = north)
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
    if (detail > 0.35) {
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
    float contrast = mix(0.4, 1.0, act) * (1.0 - ng * 0.5);
    vec3 cream = toLinear(vec3(0.98, 0.93, 0.9));
    vec3 beltC = mix(surf, deep, 0.6);
    vec3 zoneC = mix(glow, cream, 0.35);
    float v = saturate(band * 0.85 + (turb - 0.5) * 0.5 + (st - 0.5) * 0.2);
    vec3 albedo = mix(beltC, surf, smoothstep(0.0, 0.42, v));
    albedo = mix(albedo, glow * 0.9, smoothstep(0.38, 0.7, v));
    albedo = mix(albedo, zoneC, smoothstep(0.68, 0.95, v));
    // A warmer rose tint in some belts for richness.
    albedo = mix(albedo, albedo * vec3(1.2, 0.86, 0.92), smoothstep(0.55, 0.8, b2) * (1.0 - band) * 0.6);
    albedo = mix(mix(surf, glow, 0.45), albedo, contrast);
    // Poles: deep-violet hoods with a faint hexagonal jet in the north.
    float pole = smoothstep(0.72, 0.95, abs(q.y));
    albedo = mix(albedo, mix(deep, surf, 0.4) * (0.8 + 0.4 * turb), pole * 0.75);
    if (q.y > 0.8) {
      float ang = atan(q.z, q.x);
      float hexR = length(q.xz) * cos(PI / 6.0) / cos(mod(ang + t * 0.02, PI / 3.0) - PI / 6.0);
      float hx = (hexR - 0.34) / 0.02;
      albedo = mix(albedo, zoneC * 0.7, exp(-hx * hx) * 0.35 * contrast);
    }
    // Storm colours: rose eye with a pale collar; white oval.
    vec3 stormC = mix(toLinear(vec3(0.93, 0.52, 0.66)), surf, 0.2);
    vec3 stormCol = mix(stormC * 0.75, mix(stormC, cream, 0.35), sArm * smoothstep(0.1, 0.6, srhoOut)) * (0.8 + 0.4 * turb);
    stormCol = mix(stormCol, stormC * 0.55, smoothstep(0.35, 0.0, srhoOut));   // darker eye
    albedo = mix(albedo, stormCol, sIn * mix(0.35, 0.9, act));
    albedo = mix(albedo, zoneC, collar * 0.35);
    albedo = mix(albedo, cream, wIn * 0.7 * mix(0.5, 1.0, act));

    // Neglect: faded, hazy, dusty bands.
    albedo = desaturate(albedo, ng * 0.6);
    albedo = mix(albedo, dustC * 0.6, ng * 0.38);

    // Lighting: soft terminator (thick atmosphere) and gentle limb darkening.
    float ndl = dot(n, l);
    float diff = smoothstep(-0.2, 0.55, ndl) * saturate(ndl * 0.75 + 0.3);
    float limbD = pow(max(n.z, 0.0), 0.38);
    // Ring shadow bands on the clouds.
    float tl = -dot(n, A) / dot(l, A);
    float rShadow = 1.0;
    if (tl > 0.0) {
      vec3 shp = n + l * tl;
      float sr = length(shp);
      if (sr > 1.15 && sr < 2.16) {
        float sd = ggRingDensity(sr, 0.004, ringFine * 0.6);
        rShadow = 1.0 - (1.0 - exp(-sd * 0.85 / max(abs(dot(l, A)), 0.15))) * 0.9;
      }
    }
    float fres = pow(1.0 - saturate(n.z), 4.0);
    float night = 1.0 - smoothstep(-0.25, 0.12, ndl);
    col = albedo * diff * limbD * rShadow * 1.2;

    // Night side: sky-city lights along the bright zones, and lightning.
    vec3 cq = q * 26.0 + seed;
    vec3 cc = floor(cq);
    vec3 ch = hash33(cc);
    float cd = length(cq - cc - (0.3 + 0.4 * ch));
    float cityZone = smoothstep(0.55, 0.8, band) * (1.0 - pole) * step(0.55, ch.z);
    float city = exp(-cd * cd * 70.0) * cityZone * (0.6 + 0.4 * sin(t * (1.0 + ch.x * 2.0) + ch.y * 30.0));
    city *= smoothstep(0.012, 0.005, px / max(n.z, 0.2));
    vec3 lq = q * 7.0 + seed + 3.0;
    vec3 lc = floor(lq);
    vec3 lh = hash33(lc + floor(t * 1.7) * 0.37);
    float ld = length(lq - lc - (0.25 + 0.5 * lh));
    float bolt = exp(-ld * ld * 140.0) * step(0.95, lh.x) * (1.0 - band) * (0.5 + 0.5 * sin(t * 40.0 + lh.y * 20.0));
    col += (toLinear(vec3(1.0, 0.82, 0.55)) * city * 1.4 + mix(glow, vec3(0.75, 0.9, 1.0), 0.5) * bolt * 0.9) * night * th;

    // Aurora (lavender curtains over both poles).
    float aurAmt = smoothstep(0.15, 1.0, th);
    if (aurAmt > 0.001) {
      float lodE = 0.013 / max(0.013, px * 1.5);
      vec3 cLow = glow * vec3(0.85, 0.8, 1.0);
      vec3 cHigh = mix(surf, vec3(1.0, 0.4, 0.75), 0.4);
      vec3 aur = (ggCurtain(p, r, A, S1, S2, t, px, 5.0, cLow, cHigh) + ggCurtain(p, r, -A, S1, S2, t, px, 0.0, cLow, cHigh)) / 0.032;
      col += aur * aurAmt * lodE * lodE * (0.2 + 1.5 * night) * 0.8 * mix(0.4, 1.0, smoothstep(30.0, 90.0, uRadius));
    }

    // Haze and dust storms (neglect).
    if (ng > 0.001) {
      float dust = dustStorm(q * vec3(1.0, 2.2, 1.0), t) * ng;
      col = mix(col, dustC * 0.55 * (diff * 1.3 + 0.01), dust * 0.55);
      col = mix(col, dustC * 0.5 * (diff + 0.02), ng * 0.22);
      float rift = cracks(q * vec3(1.4, 3.6, 1.4) + 2.0) * smoothstep(0.4, 0.9, ng) * smoothstep(0.015, 0.006, px);
      rift *= smoothstep(0.4, 0.65, noise3(q * 2.3 + 5.0));                // rifts open in patches
      col *= 1.0 - rift * 0.22;
      col += distressC * rift * 0.012 * (0.4 + 0.6 * distressPulse(t)) * (0.3 + night);
    }
    col *= 1.0 - ng * 0.5;

    // Atmosphere: lavender limb glow, distress rim, celebration flare.
    float atmoD = mix(0.16, 0.36, act) * (1.0 - ng * 0.45);
    col += atmosphere(pc, n, l, mix(glow, surf, 0.3), atmoD, 0.1);
    col += distressC * fres * ng * distressPulse(t) * 1.1;
    col += glow * uPulse * (0.06 + fres * 1.8);
  }

  // --- halo (skipped where the opaque disc fully covers it) -----------------------
  vec3 halo = vec3(0.0);
  if (r > 1.0 - 2.0 * px && r < 1.35) {
  float rh = max(r, 1.0);
  vec2 pdir = p / max(r, 1e-4);
  // Thin crisp haze line on the limb plus a faint wide glow.
  float ha = rh - 1.0;
  float hr = (0.55 * exp(-ha / 0.012) + 0.45 * exp(-ha / 0.05)) * (1.0 - smoothstep(0.12, 0.3, ha));
  vec2 lpd = normalize(l.xy + 1e-4);
  float dayside = saturate(dot(pdir, lpd) * 0.6 + 0.55);
  float back = pow(saturate(-l.z), 2.0) * saturate(dot(pdir, lpd) * 0.5 + 0.5);
  float atmoH = mix(0.25, 0.55, act) * (1.0 - ng * 0.45);
  halo = mix(glow, surf, 0.3) * atmoH * hr * (dayside * 1.2 + back * 2.2 + 0.08);
  float aurAmtH = smoothstep(0.15, 1.0, th);
  if (aurAmtH > 0.001 && r > 1.0) {
    float lodE = 0.013 / max(0.013, px * 1.5);
    vec3 cLow = glow * vec3(0.85, 0.8, 1.0);
    vec3 cHigh = mix(surf, vec3(1.0, 0.4, 0.75), 0.4);
    vec3 aur = (ggCurtain(p, r, A, S1, S2, t, px, 5.0, cLow, cHigh) + ggCurtain(p, r, -A, S1, S2, t, px, 0.0, cLow, cHigh)) / 0.032;
    halo += aur * aurAmtH * lodE * lodE * 1.5 * mix(0.4, 1.0, smoothstep(30.0, 90.0, uRadius));
  }
  halo += distressC * ng * distressPulse(t) * 0.5 * (1.0 - smoothstep(1.0, 1.1, rh));
  halo += glow * uPulse * 0.35 * hr;
  }

  // --- ships along the ring plane --------------------------------------------------
  vec3 shipCol = vec3(0.0);
  float trips = clamp(uExtra.x, 0.0, 6.0);
  if (trips > 0.001) {
    float sizePx = clamp(uRadius * 0.012, 1.1, 3.2);
    float phiP = atan(dot(PR, E2), dot(PR, E1));
    float zs = sqrt(max(1.0 - r * r, 0.0));
    float trailVis = (r < 1.0 && zr < zs) ? 0.0 : 1.0;
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
        float sr2 = dot(SP.xy, SP.xy);
        float hidden = (sr2 < 1.0 && SP.z < sqrt(max(1.0 - sr2, 0.0))) ? 1.0 : 0.0;
        vec2 dv = (p - SP.xy) / px;
        float d = length(dv);
        float core = exp(-d * d / (sizePx * sizePx * 0.3));
        float bloom = exp(-d / (sizePx * 1.6)) * 0.3 + exp(-d / (sizePx * 4.0)) * 0.12;
        // Four-point glint (twinkles gently).
        vec2 ad = abs(dv);
        float glint = (exp(-ad.y * ad.y / 0.5) * exp(-ad.x / (sizePx * 3.0)) + exp(-ad.x * ad.x / 0.5) * exp(-ad.y / (sizePx * 3.0)));
        glint *= 0.35 * (0.7 + 0.3 * sin(t * 3.0 + fi * 1.7)) * smoothstep(1.2, 2.2, sizePx);
        // Trail: a luminous arc behind the ship on its lane.
        float dth = mod(ang - phiP, TAU);
        float radPx = abs(rr - R) * (r / max(rr, 1e-3)) / px;
        float tw = max(0.55, sizePx * 0.3);
        float trail = exp(-radPx * radPx / (tw * tw)) * exp(-dth / 0.6) * step(dth, 2.8) * trailVis;
        trail *= smoothstep(0.0, 0.04, dth);
        vec3 hue = mix(vec3(1.0, 0.93, 0.8), glow, 0.25 + 0.2 * sin(fi * 2.1));
        float I = (core * 2.4 + bloom + glint) * (1.0 - hidden);
        I *= vis * (1.0 + uPulse * 1.5);
        shipCol += hue * I + mix(glow, hue, exp(-dth / 0.25)) * trail * 1.0 * vis;
      }
    }
  }

  // --- composite (premultiplied, display space) ------------------------------------
  float discA = discMask(p, uRadius);
  float haloA = saturate(max(halo.r, max(halo.g, halo.b)) * 2.5);
  vec3 discCol = toGamma(tonemapACES(col));
  vec3 haloCol = toGamma(tonemapACES(halo));
  vec3 ringC = toGamma(tonemapACES(ringCol));
  float zSurf = sqrt(max(1.0 - r * r, 0.0));
  float ringFront = r < 1.0 ? step(zSurf, zr) : step(0.0, zr);
  vec4 ringL = vec4(ringC * ringA, ringA);
  vec4 acc = ringL * (1.0 - ringFront);
  acc = vec4(haloCol * haloA, haloA) + acc * (1.0 - haloA);
  acc = vec4(discCol * discA, discA) + acc * (1.0 - discA);
  acc = ringL * ringFront + acc * (1.0 - ringA * ringFront);
  // Ships are self-luminous and already occlusion-tested: add on top.
  float shipA = saturate(max(shipCol.r, max(shipCol.g, shipCol.b)));
  vec3 shipG = toGamma(tonemapACES(shipCol));
  acc = vec4(shipG * shipA, shipA) + acc * (1.0 - shipA);
  fragColor = vec4(dither(frag, acc.rgb), acc.a);
}
