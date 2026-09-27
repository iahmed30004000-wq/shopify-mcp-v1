// ---------------------------------------------------------------------------
// Madar orbit shader library (included by every orbit shader).
//
// Noise comes from uNoise: a 256×256 RGBA texture generated in Dart
// (lib/features/orbit/render/noise_texture.dart). Its content is periodic with
// period 255 (row/column 255 duplicate 0) so linear filtering never shows a
// seam even though Flutter samplers clamp to edge. Channel layout follows the
// classic "two-slice" trick: G(x, y) = R(x - 37, y - 17), so one bilinear
// fetch yields the two z-slices needed for 3D value noise.
//
// SkSL compatibility (required for widget-test screenshots and Skia fallback):
// samplers can NOT be passed as function parameters, so the library owns the
// single global noise sampler below. Declare shader float uniforms AFTER the
// include; the noise sampler is always sampler index 0.
// ---------------------------------------------------------------------------

uniform sampler2D uNoise;

#define PI 3.14159265359
#define TAU 6.28318530718

float saturate(float x) { return clamp(x, 0.0, 1.0); }
vec3 saturate3(vec3 x) { return clamp(x, 0.0, 1.0); }

// --- hashes (ALU) ----------------------------------------------------------
float hash12(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}
vec2 hash22(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.xx + p3.yz) * p3.zy);
}
vec3 hash33(vec3 p3) {
  p3 = fract(p3 * vec3(0.1031, 0.1030, 0.0973));
  p3 += dot(p3, p3.yxz + 33.33);
  return fract((p3.xxy + p3.yxx) * p3.zyx);
}

// --- texture value noise ---------------------------------------------------
vec2 _noiseUv(vec2 cell) { return (mod(cell, 255.0) + 0.5) / 256.0; }

// 3D value noise in [0, 1].
float noise3(vec3 x) {
  vec3 p = floor(x);
  vec3 f = fract(x);
  f = f * f * (3.0 - 2.0 * f);
  vec2 cell = p.xy + vec2(37.0, 17.0) * p.z;
  vec2 rg = texture(uNoise, _noiseUv(cell) + f.xy / 256.0).yx;
  return mix(rg.x, rg.y, f.z);
}

// 2D value noise in [0, 1].
float noise2(vec2 x) {
  vec2 p = floor(x);
  vec2 f = fract(x);
  f = f * f * (3.0 - 2.0 * f);
  return texture(uNoise, _noiseUv(p) + f / 256.0).x;
}

// Fractal Brownian motion (octaves are compile-time constants for unrolling).
float fbm3(vec3 p) {
  float a = 0.5, s = 0.0;
  for (int i = 0; i < 5; i++) {
    s += a * noise3(p);
    p = p * 2.03 + vec3(1.7, 9.2, 3.1);
    a *= 0.5;
  }
  return s / 0.96875;
}
float fbm3lo(vec3 p) {
  float a = 0.5, s = 0.0;
  for (int i = 0; i < 3; i++) {
    s += a * noise3(p);
    p = p * 2.07 + vec3(4.3, 1.1, 7.7);
    a *= 0.5;
  }
  return s / 0.875;
}
// Ridged multifractal (mountain ridges, lava rivers, veins) in [0, 1].
float ridged3(vec3 p) {
  float a = 0.5, s = 0.0, w = 1.0;
  for (int i = 0; i < 4; i++) {
    float n = 1.0 - abs(noise3(p) * 2.0 - 1.0);
    n *= n * w;
    w = saturate(n * 2.0);
    s += n * a;
    p = p * 2.11 + vec3(2.9, 5.3, 1.3);
    a *= 0.5;
  }
  return saturate(s / 0.9375);
}

// 3D cellular noise: x = distance to nearest feature, y = to second nearest.
vec2 voronoi3(vec3 x) {
  vec3 p = floor(x);
  vec3 f = fract(x);
  float d1 = 8.0, d2 = 8.0;
  for (int k = -1; k <= 1; k++)
  for (int j = -1; j <= 1; j++)
  for (int i = -1; i <= 1; i++) {
    vec3 b = vec3(float(i), float(j), float(k));
    vec3 r = b - f + hash33(p + b);
    float d = dot(r, r);
    if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
  }
  return sqrt(vec2(d1, d2));
}

// --- rotations -------------------------------------------------------------
mat3 rotY(float a) { float c = cos(a), s = sin(a); return mat3(c, 0.0, -s, 0.0, 1.0, 0.0, s, 0.0, c); }
mat3 rotX(float a) { float c = cos(a), s = sin(a); return mat3(1.0, 0.0, 0.0, 0.0, c, s, 0.0, -s, c); }
mat3 rotZ(float a) { float c = cos(a), s = sin(a); return mat3(c, s, 0.0, -s, c, 0.0, 0.0, 0.0, 1.0); }

// --- colour ------------------------------------------------------------------
float luma(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 desaturate(vec3 c, float amount) { return mix(c, vec3(luma(c)), amount); }

// Narkowicz ACES filmic approximation (input linear, output display-ready).
vec3 tonemapACES(vec3 x) {
  const float a = 2.51, b = 0.03, c = 2.43, d = 0.59, e = 0.14;
  return saturate3((x * (a * x + b)) / (x * (c * x + d) + e));
}
vec3 toLinear(vec3 c) { return pow(c, vec3(2.2)); }
vec3 toGamma(vec3 c) { return pow(max(c, 0.0), vec3(1.0 / 2.2)); }

// Tiny ordered dither to kill gradient banding on 8-bit targets.
vec3 dither(vec2 fragCoord, vec3 c) {
  float n = hash12(fragCoord) - 0.5;
  return c + n / 255.0;
}

// --- sphere impostor ---------------------------------------------------------
// Given the fragment position relative to the planet centre in units of the
// planet's screen radius (p, |p| <= 1 on the disc), returns the view-space
// normal of an orthographic sphere (z towards the viewer).
vec3 sphereNormal(vec2 p) {
  float z = sqrt(max(0.0, 1.0 - dot(p, p)));
  return vec3(p.x, p.y, z);
}

// Soft disc coverage with ~1.5px antialiasing; pxPerUnit = planet radius in px.
float discMask(vec2 p, float pxPerUnit) {
  float r = length(p);
  return saturate((1.0 - r) * pxPerUnit / 1.5 + 0.5);
}

// Rim-lit atmosphere: thickness grows toward the limb, brighter on the day side.
// p: position in planet radii (may exceed 1 for the halo), l: light dir (view space).
vec3 atmosphere(vec2 p, vec3 n, vec3 l, vec3 color, float density, float haloWidth) {
  float r = length(p);
  float inside = step(r, 1.0);
  float limb = pow(1.0 - saturate(n.z), 3.0) * inside;
  float halo = (1.0 - smoothstep(1.0, 1.0 + haloWidth, r)) * step(1.0, r);
  halo *= halo;
  vec2 lp = normalize(l.xy + 1e-4);
  float dayside = saturate(dot(normalize(p + 1e-4), lp) * 0.6 + 0.55);
  float sunward = saturate(dot(n, l) * 0.5 + 0.5);
  return color * density * (limb * sunward * 1.6 + halo * dayside * 1.2);
}

// --- living state -----------------------------------------------------------
// uScore in [0,1]: 0 neglected … 1 thriving.
float thrive(float score) { return smoothstep(0.55, 0.95, score); }
float neglect(float score) { return 1.0 - smoothstep(0.15, 0.55, score); }

// Swirling dust storm density over a surface point (object space).
float dustStorm(vec3 q, float t) {
  vec3 w = q * 2.2 + vec3(t * 0.05, 0.0, -t * 0.03);
  float d = fbm3lo(w + fbm3lo(w * 1.7 + t * 0.02) * 1.3);
  return smoothstep(0.35, 0.8, d);
}

// Faint crack network (cellular edges) – returns 0..1 crack intensity.
float cracks(vec3 q) {
  vec2 v = voronoi3(q * 4.0);
  return 1.0 - smoothstep(0.0, 0.05, v.y - v.x);
}

// Slow "distress" pulse for neglected worlds (period ~3.2 s).
float distressPulse(float t) { return 0.5 + 0.5 * sin(t * 1.96); }

// ===========================================================================
// FAMILY LOOK (shared by the eight life-area planets; opt-in, additive).
// Everything above this line keeps its original behaviour. The functions
// below give every world ONE living-state grade, ONE atmosphere/halo model,
// ONE aurora, ONE celebration ring, ONE distress rim and ONE compositor.
//
// Pipeline order inside a planet shader (linear light throughout):
//   lit   = surface lighting (albedo × sun, sky, speculars)
//   lit   = lifeGrade(lit, th, ng)            // thriveGrade then neglectGrade
//   col   = (lit + emit) * T + S              // S = atmoHaze(..., T)
//   col  += aurora / airglow / rims           // emissive, after the haze
//   halo  = atmoHalo(...) + aurora + limbShock + distress
//   fragColor = compositeDiscHalo(col, discA, halo, frag)
// with th = thrive(uScore), ng = neglect(uScore).
// ===========================================================================

// --- living-state grade -------------------------------------------------------
// Neglect: dimmer AND greyer. At ng = 1 luminance × 0.55 and 45 % desaturated
// (luma-preserving desaturate, then a flat exposure cut). Apply AFTER surface
// lighting and BEFORE emission (night lights, embers, aurora stay untouched so
// they can still flicker / fail on their own terms). Target: neglected /
// thriving mean lit-disc luminance ≤ 0.6 — do not add per-world brighteners.
vec3 neglectGrade(vec3 col, float ng) {
  float k = 0.45 * saturate(ng);
  return desaturate(col, k) * (1.0 - k);
}

// Thriving: a day-side, low-frequency cue that survives at 22 px. Saturation
// goes 0.85 (steady / neglected) → 1.1 (thriving), a tiny warm shift (+4 % R,
// −5 % B at th = 1, luminance-neutral) and a small exposure step 0.94 → 1.04
// (steady is ~10 % dimmer than thriving: saturation alone is too weak a read
// on grey/gold worlds at 22 px).
vec3 thriveGrade(vec3 col, float th) {
  float t = saturate(th);
  vec3 c = max(mix(vec3(luma(col)), col, mix(0.85, 1.1, t)), 0.0);
  vec3 warm = vec3(1.0 + 0.04 * t, 1.0 + 0.005 * t, 1.0 - 0.05 * t);
  return c * (warm / luma(warm)) * mix(0.94, 1.04, t);
}

// Both grades in the canonical order (thrive first, then neglect).
vec3 lifeGrade(vec3 col, float th, float ng) {
  return neglectGrade(thriveGrade(col, th), ng);
}

// Atmosphere / halo density multiplier: 0.7 steady → 1.2 thriving, halved when
// fully neglected. Fold it into the `gain` of atmoHaze/atmoHalo, e.g.
//   float gain = 2.0 * haloGain(th, ng) * (1.0 + 0.5 * uPulse);
float haloGain(float th, float ng) {
  return mix(0.7, 1.2, saturate(th)) * (1.0 - 0.5 * saturate(ng));
}

// --- atmosphere (family-work physically based haze, lifted) -------------------
// Single scattering in an exponential atmosphere seen from outside.
// Forward-scattering phase: 0.7 when front-lit → 3.7 when the star is straight
// behind the planet (l.z = −1). This is what turns the back-lit halo into a
// bright crescent on the star's side instead of a symmetric ring.
float atmoPhase(vec3 l) {
  return 0.7 + 3.0 * pow(saturate(0.5 - 0.5 * l.z), 5.0);
}

// Aerial perspective over the disc.
//   mu      = n.z (view cosine), ndl = dot(n, l)
//   atmoCol = scatter colour (linear)
//   tau0    = vertical optical depth: 0.013 thin/clear … 0.04 dusty. Thicken
//             for neglect in the caller, e.g. tau0 * (1.0 + 1.2 * ng) (smog).
//   ext     = per-channel extinction tint: vec3(1.3, 1.0, 0.75) blue-sky
//             (reds the limb less), vec3(0.7, 1.0, 1.35) dusty (reddens).
//   gain    = 2.0 * haloGain(th, ng) * (1.0 + 0.5 * uPulse) typically.
//   phase   = atmoPhase(l)
// Returns the in-scattered light S; writes the transmittance T:
//   col = (lit + emit) * T + S;
// At the limb (mu → 0) the airmass is ≈ 11, matching atmoHalo at r = 1 so the
// disc rim and the halo are continuous (no seam, no dark ring).
vec3 atmoHaze(float mu, float ndl, vec3 atmoCol, float tau0, vec3 ext, float gain, float phase, out vec3 T) {
  float airmass = 1.0 / (max(mu, 0.0) + 0.09);
  float tau = tau0 * airmass;
  T = exp(-tau * ext);
  float sunAtm = smoothstep(-0.3, 0.3, ndl);
  return atmoCol * (1.0 - exp(-tau)) * sunAtm * phase * gain;
}

// The halo outside the disc (evaluate for every fragment; it is ~0 inside
// because compositeDiscHalo puts the disc over it).
//   p      = fragment position in planet radii (y up), |p| ≥ 1 in the halo
//   scaleH = density scale height in radii (0.035 family default)
//   px     = 1 / uRadius. The scale height is floored at 1.2 px so small
//            planets (22 px) keep a readable 1–2 px glow instead of a
//            sub-pixel halo that the disc's antialiasing would swallow.
// Same tau0 / gain / phase as atmoHaze (continuous at the limb). Back-lit it
// becomes a forward-scatter crescent on the star's side (lit through the
// terminator), full ring only when the star is exactly behind.
vec3 atmoHalo(vec2 p, vec3 l, vec3 atmoCol, float tau0, float scaleH, float gain, float phase, float px) {
  float r = length(p);
  float hr = max(r - 1.0, 0.0);
  float dens = exp(-hr / max(scaleH, 1.2 * px));
  float tauH = tau0 * 11.0 * dens;
  float ndlL = dot(vec3(p / max(r, 1e-4), 0.0), l);
  return atmoCol * (1.0 - exp(-tauH)) * smoothstep(-0.3, 0.3, ndlL) * phase * gain;
}

// --- aurora: one soft curtain model for every world -------------------------
// Emissive sheets rising AURORA_H radii above both auroral ovals (the double
// cone |X·axis| = c·|X|), intersected analytically with the orthographic view
// ray, so the SAME call serves the disc (curtains in front of the surface)
// and the halo (curtains standing above the limb). Fixes relative to the old
// per-world curtains/ribbons:
//   * grazing boost capped at 1 / max(|n.z|, 0.4) (≤ 2.5×): no fur past the limb
//   * soft base smoothstep(0, 0.3, u) and a long faded top (broad hump over
//     the curtain height, not a bright line at the foot): no hard ellipse
//   * rays never finer than ~6 px (frequency follows uRadius)
//   * low-frequency arcs break the oval into patches (never a closed ring)
//   * day-side factor 0.2 + 1.1 * night, evaluated at the curtain point
//   * edge-on silhouette softened (finite sheet thickness)
#define AURORA_H 0.12

vec2 _auroraSheet(vec3 X, float dz, vec3 axis, float c, float zs, mat3 rot, vec3 l, float t, float px, float rayF) {
  float rX = length(X);
  float h = rX - 1.0;
  if (h <= 0.0 || h >= AURORA_H || X.z < zs) return vec2(0.0);
  vec3 Xo = rot * X;
  vec2 dir = normalize(Xo.xz + 1e-5);
  float hemi = Xo.y > 0.0 ? 1.0 : -1.0;
  float u = h / AURORA_H;
  float rays = noise3(vec3(dir * rayF, t * 0.35 + hemi * 9.0 + u * 0.4));
  float folds = noise3(vec3(dir * 3.2, t * 0.12 - hemi * 4.0));
  float arcs = smoothstep(0.45, 0.72, noise3(vec3(dir * 1.3 + t * 0.02, hemi * 7.0 + 3.0)));
  // broad soft hump: soft base (0 → 0.3), long soft top (0.35 → 1): no thin bright line
  float prof = smoothstep(0.0, 0.3, u) * (1.0 - smoothstep(0.35, 1.0, u));
  vec3 nrm = normalize(dot(X, axis) * axis - c * c * X);
  float graze = 1.0 / max(abs(nrm.z), 0.4);
  float vis = smoothstep(0.6, 2.5, AURORA_H * length(X.xy) / rX / px);
  float night = 1.0 - smoothstep(-0.25, 0.15, dot(X / rX, l));
  float e = (0.5 + 0.5 * rays) * (0.35 + 0.65 * folds) * (0.03 + 0.97 * arcs)
          * prof * graze * vis * (0.2 + 1.1 * night) * smoothstep(0.0, 0.15, dz);
  return vec2(e, e * u);
}

// p    = fragment position in planet radii (y up; disc AND halo fragments)
// rot  = the planet's view→object rotation (q = rot * n); the spin axis is
//        object +y, so any rotY(spin) * rotX(tilt) works
// l    = light direction (view space, normalised)
// ovalY = cosine of the oval's colatitude: 0.86 (wide) … 0.92 (tight polar)
// t    = uTime, px = 1 / uRadius
// Returns x = emission (≈ 0.3–0.6 typical at night, ≤ ~0.35 by day, peaks
// ~1.5 where a sheet is seen edge-on), y = emission × relative height (0 base
// … 1 top) — use y / x to grade base → top colour. Caller supplies colour and
// gain; gate the call with the thrive/pulse gain (it costs 7 noise taps where
// curtains exist, nothing elsewhere). Evaluate ONCE per fragment, above the
// disc/halo branches, and add the same value to both:
//   vec2 au = (auK > 0.001) ? auroraCurtains(p, rot, l, 0.9, t, px) * auK : vec2(0.0);
//   vec3 auC = mix(auroraBase, auroraTop, saturate(au.y / max(au.x, 1e-4) * 2.0)) * au.x * 0.3;
//   col += auC; halo += auC;
float _auroraRayFreq(float px) { return clamp(0.08 / max(px, 1e-4), 4.0, 30.0); }

vec2 auroraCurtains(vec2 p, mat3 rot, vec3 l, float ovalY, float t, float px) {
  float pp = dot(p, p);
  if (pp > (1.0 + AURORA_H) * (1.0 + AURORA_H)) return vec2(0.0);
  vec3 axis = vec3(0.0, 1.0, 0.0) * rot;          // object +y in view space
  float zs = pp < 1.0 ? sqrt(1.0 - pp) : -9.0;    // occluding surface depth
  float c = ovalY + (noise3(vec3(p * 2.2, t * 0.08)) - 0.5) * 0.06;
  float k = dot(axis.xy, p);
  float A = axis.z * axis.z - c * c;
  A = A < 0.0 ? min(A, -1e-4) : max(A, 1e-4);
  float B = 2.0 * k * axis.z;
  float C = k * k - c * c * pp;
  float D = B * B - 4.0 * A * C;
  if (D <= 0.0) return vec2(0.0);
  float sD = sqrt(D);
  float dz = sD / abs(A);                          // depth gap between the two crossings
  float rayF = _auroraRayFreq(px);
  return _auroraSheet(vec3(p, (-B + sD) / (2.0 * A)), dz, axis, c, zs, rot, l, t, px, rayF)
       + _auroraSheet(vec3(p, (-B - sD) / (2.0 * A)), dz, axis, c, zs, rot, l, t, px, rayF);
}

// --- celebration: limb shock ring -----------------------------------------------
// The one celebration language: a ring is born at the limb and expands to
// r = 1.26 as uPulse decays 1 → 0 (drive uPulse as a 1 → 0 burst over ~1–1.5 s;
// animating 0 → 1 → 0 makes it travel out and back). Thin and bright at
// birth, wider and fainter as it travels. Antialiased: the width is floored at
// 0.7 px with energy kept constant. Zero over the disc (r ≤ 1). Add to the
// HALO with the world's glow colour; keep per-world flourishes on the disc:
//   halo += glowCol * limbShock(r, uPulse, 1.0 / uRadius) * 0.6;
float limbShock(float r, float pulse, float px) {
  float pl = saturate(pulse);
  float ringR = 1.0 + (1.0 - pl) * 0.26;
  float w0 = 0.012 + 0.03 * (1.0 - pl);
  float w = max(w0, 0.7 * px);
  float rd = (r - ringR) / w;
  return pl * exp(-rd * rd) * (w0 / w) * smoothstep(1.0, 1.0 + max(0.02, px), r);
}

// --- distress (neglect) -----------------------------------------------------------
// One colour, one phase, one strength for every world and its moons. Use
// pulseD = distressPulse(uTime) * ng — never offset the phase (moons included)
// so a neglected planet and its satellites breathe together. Strengths are a
// little lower than the old per-world 0.65 / 0.4 (the peak read as an alarm).
vec3 distressColor() { return vec3(1.0, 0.035, 0.015); }                 // linear
float distressRim(float mu, float pulseD) { return pow(1.0 - saturate(mu), 3.0) * pulseD * 0.5; }
float distressHalo(float r, float pulseD, float px) {
  return exp(-max(r - 1.0, 0.0) / max(0.035, 1.2 * px)) * pulseD * 0.3;
}

// --- the ONE compositing convention -----------------------------------------------
// Disc over halo, premultiplied, for srcOver onto the brass/sky behind:
//   disc: tonemapACES → toGamma, coverage discA (opaque inside the limb)
//   halo: tonemapACES → toGamma, alpha = max channel (screen-like: it only
//         ever ADDS light, it never occludes what is behind it)
//   rgb dithered here (fragCoord) then clamped ≤ alpha, so fully transparent
//   fragments are exactly (0,0,0,0).
// Replaces the old "alpha = 2.5 × max(linear halo), colour × alpha" variant.
// Anything that must sit in front of the disc (rings, ships) goes into
// discLinear with discA raised accordingly, or into haloLinear if additive.
vec4 compositeDiscHalo(vec3 discLinear, float discA, vec3 haloLinear, vec2 fragCoord) {
  vec3 dC = toGamma(tonemapACES(discLinear));
  vec3 hC = toGamma(tonemapACES(haloLinear));
  float hA = saturate(max(hC.r, max(hC.g, hC.b)));
  float a = discA + hA * (1.0 - discA);
  vec3 pm = dither(fragCoord, dC * discA + hC * (1.0 - discA));
  return vec4(clamp(pm, vec3(0.0), vec3(a)), a);
}
