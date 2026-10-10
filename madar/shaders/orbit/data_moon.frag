#version 460 core
#include <flutter/runtime_effect.glsl>
#include "lib/common.glsl"

// ---------------------------------------------------------------------------
// Data moon — the small satellites orbiting a life-area planet (people around
// Family, wallets around Money, boards around Work, trips around Travel).
// Designed for 6–40 px radius: every look is carried by LOW-frequency cues
// (hue, material response, silhouette, rim, halo, glint) so it still reads at
// 8 px; finer surface detail fades in with the on-screen radius.
//
// Follows the PLANET UNIFORM CONTRACT exactly.
//   uColorA  item colour (straight sRGB) — tints the whole moon.
//   uColorB  rim / glow colour. If uColorB.a < 0.5 it is derived from uColorA.
//   uColorC  deep / shadow colour. If uColorC.a < 0.5 it is derived from uColorA.
//   uScore   item state: 1 fresh (bright, clean rim light, twinkling 8-point
//            glint, tiny aurora, settlement lights / glowing fissures) … 0.6
//            steady … 0 overdue (dim, cold, desaturated, dusty, faint cracks,
//            slow red distress rim ~3.2 s).
//   uPulse   0..1 celebration burst (flare + ring racing outward + glint).
//   uSpin    x spin angle, y axial tilt (z unused).
//   uDetail  0..1; combined with uRadius to pick the level of detail.
//   uSeed    any float; changes crater layout / facet sparkle / phases.
//   uExtra.x look: 0 rocky/cratered, 1 icy (blue fresnel), 2 faceted gem
//            (ray-traced 26-facet cut, two internal bounces, mild
//            perspective — octagonal silhouette), 3 warm
//            lava-veined.
//   uExtra.y selection highlight 0..1 (thin breathing ring just outside the
//            limb, in the glow colour) — for the focused / tapped moon.
//   uExtra.z,w unused (pass 0).
// Draw rect: centre ± uRadius × 1.6 (haloFactor 1.6).
//
// FAMILY LOOK (common.glsl): lifeGrade on the reflected light (emission —
// settlement lights, cryo-fissures, lava — cools on its own terms), the shared
// aurora curtains (thriving, lod > 0.2, not on gems), the shared limb shock
// ring for celebrations, and compositeDiscHalo. Distress uses the family
// colour and the PARENT's phase — distressPulse(uTime), no seed offset — so a
// neglected planet and its moons breathe together; it is softer than the
// planets' (rim 0.35 / halo 0.2) so a neglected cluster never reads as an
// alarm panel. Integration note: derive the wallet gem tint from the Money
// palette (uColorA #7FE3C4 deepened) so gem moons match their planet.
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

const float DM_HALO = 1.6;
const float DM_GEM_H = 0.886;   // facet plane distance → circumradius ≈ 1.0

// Crater profile slope (size independent): bowl -D(1-x²)², raised rim.
// x = distance / crater radius. Returns (slope, albedo offset).
vec2 dm_crater(float x) {
  float inside = step(x, 1.0);
  float x2 = x * x;
  float bowl = 4.0 * 0.34 * x * (1.0 - x2) * inside;
  float xr = (x - 1.0) / 0.26;
  float rimG = exp(-xr * xr);
  float rim = 0.1 * rimG * (-2.0 * xr / 0.26);
  return vec2(bowl + rim, -0.2 * (1.0 - x2) * inside + 0.16 * rimG);
}

// Big analytic craters from the seed. Returns gradient (xyz, object space) + albedo.
vec4 dm_bigCraters(vec3 q, float seed) {
  vec3 g = vec3(0.0);
  float alb = 0.0;
  for (int i = 0; i < 5; i++) {
    float fi = float(i);
    vec3 h = hash33(vec3(fi * 17.13 + seed * 3.7, fi * 5.71 + 1.3, seed * 11.1 + fi * 2.9));
    vec3 c = normalize(h * 2.0 - 1.0 + vec3(1e-3));
    float rc = mix(0.12, 0.3, h.x);
    vec3 dv = q - c;
    float d = length(dv);
    vec2 cr = dm_crater(d / rc);
    g += dv / max(d, 1e-4) * cr.x;
    alb += cr.y;
  }
  return vec4(g, alb);
}

// Small crater field: one crater per unit cell, jittered inside [0.25,0.75]³
// with radius ≤ 0.25, so only the 2×2×2 nearest cells can touch a point
// (8 taps instead of a 27-tap voronoi).
vec4 dm_cellCraters(vec3 x) {
  vec3 b0 = floor(x - 0.5);
  vec3 g = vec3(0.0);
  float alb = 0.0;
  for (int k = 0; k < 2; k++)
  for (int j = 0; j < 2; j++)
  for (int i = 0; i < 2; i++) {
    vec3 cell = b0 + vec3(float(i), float(j), float(k));
    vec3 h = hash33(cell);
    vec3 dv = x - (cell + 0.25 + 0.5 * h);
    float d = length(dv);
    float rc = mix(0.09, 0.25, fract(h.x * 13.7 + h.y * 3.1));
    float exists = step(0.3, fract(h.z * 7.3 + h.x));
    vec2 cr = dm_crater(d / rc) * exists;
    g += dv / max(d, 1e-4) * cr.x;
    alb += cr.y;
  }
  return vec4(g, alb);
}

// Temperature ramp for lava (t 0..1) — black-body-ish, linear light.
vec3 dm_lava(float t) {
  vec3 c = mix(vec3(0.0), vec3(0.5, 0.03, 0.004), smoothstep(0.0, 0.3, t));
  c = mix(c, vec3(1.0, 0.3, 0.035), smoothstep(0.25, 0.65, t));
  c = mix(c, vec3(1.0, 0.78, 0.4), smoothstep(0.65, 1.0, t));
  return c;
}

// 8-point star glint in pixel units (d = offset from the glint centre).
float dm_sq(float x) { return x * x; }

float dm_glint(vec2 d, float armLen, float w) {
  vec2 a = abs(d);
  float fx = saturate(1.0 - a.x / armLen), fy = saturate(1.0 - a.y / armLen);
  float cross = exp(-a.y / w) * fx * fx * fx + exp(-a.x / w) * fy * fy * fy;
  vec2 dr = abs(vec2(d.x + d.y, d.x - d.y)) * 0.70710678;
  float gx = saturate(1.0 - dr.x / (armLen * 0.55)), gy = saturate(1.0 - dr.y / (armLen * 0.55));
  float diag = exp(-dr.y / w) * gx * gx * gx + exp(-dr.x / w) * gy * gy * gy;
  float core = exp(-dot(d, d) / (w * w * 5.0));
  return cross + diag * 0.5 + core * 1.2;
}

// Exit point of a ray travelling INSIDE the convex 26-facet gem (the planes
// of the 3x3x3 neighbourhood directions at distance DM_GEM_H). Returns the
// distance, outputs the outward normal of the exit facet.
float dm_gemExit(vec3 P, vec3 rd, out vec3 nX) {
  float tX = 1e4;
  nX = vec3(0.0, 0.0, 1.0);
  for (int k = -1; k <= 1; k++)
  for (int j = -1; j <= 1; j++)
  for (int i = -1; i <= 1; i++) {
    vec3 v = vec3(float(i), float(j), float(k));
    float len2 = dot(v, v);
    vec3 d = v * inversesqrt(max(len2, 0.5));
    float den = dot(rd, d);
    float t = (DM_GEM_H - dot(P, d)) / max(den, 1e-5);
    if (len2 > 0.5 && den > 1e-4 && t < tX) { tX = t; nX = d; }
  }
  return tX;
}

// Studio environment for the gem (object space). V points toward the camera,
// up = world up, key = the core star. Lights sit around the camera like a
// jeweller's photo booth, so rays that bounce BACK toward the viewer pick up
// light (sparkle) while rays that pass straight through see dark space —
// the bright/dark facet mosaic of a real cut stone.
vec3 dm_env(vec3 dir, vec3 V, vec3 up, vec3 key, vec3 lo, vec3 hi) {
  float front = dot(dir, V);
  vec3 side = normalize(cross(up, V) + vec3(1e-4));
  vec3 c = lo;
  c += hi * (0.25 * smoothstep(-0.2, 0.9, front) + 0.3 * smoothstep(0.2, 1.0, dot(dir, up)));
  // The camera and lens block the studio right around the view axis, so a
  // facet facing the viewer reflects a dark centre ringed by the lights (as
  // in a real gem photograph), never a flat pale panel.
  c *= mix(0.22, 1.0, smoothstep(0.985, 0.88, front));
  float k = saturate(dot(dir, key));
  // Broad key sheen: a facet that faces the camera sweeps a soft gradient
  // (bright toward the star) instead of reflecting a flat pale panel.
  c += vec3(1.0, 0.94, 0.84) * (pow(k, 3.0) * 0.35 + pow(k, 10.0) * 0.7 + pow(k, 140.0) * 9.0);
  // Strip softboxes flanking the camera and a warm bounce card below.
  c += hi * 1.3 * smoothstep(0.86, 0.95, dot(dir, normalize(V * 0.7 + up * 0.7 - side * 0.3)));
  c += vec3(1.0) * 0.9 * smoothstep(0.9, 0.975, dot(dir, normalize(V * 0.6 + side * 0.8 - up * 0.2)));
  c += hi * 0.6 * smoothstep(0.8, 0.95, dot(dir, normalize(V * 0.5 - side * 0.7 - up * 0.6)));
  // Behind the stone: deep space.
  return c * mix(0.12, 1.0, smoothstep(-0.7, 0.15, front));
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 p = (frag - uCenter) / uRadius;
  p.y = -p.y;
  float r = length(p);
  vec3 l = normalize(uLight);
  float kind = floor(uExtra.x + 0.5);
  float th = thrive(uScore);
  float ng = neglect(uScore);
  float fresh = smoothstep(0.4, 0.97, uScore);
  // Level of detail from the on-screen size (moons are 6–40 px).
  float lod = saturate(max(uDetail * 0.5, (uRadius - 7.0) / 30.0));
  float aa = 1.0 / uRadius;                  // one pixel in moon radii

  vec3 tint = toLinear(uColorA.rgb);
  vec3 glowC = uColorB.a > 0.5 ? toLinear(uColorB.rgb)
                               : mix(tint, vec3(1.0), 0.4);
  vec3 deepC = uColorC.a > 0.5 ? toLinear(uColorC.rgb) : tint * 0.1;
  vec3 sunC = vec3(1.0, 0.93, 0.82);         // the core star's light
  // Distress in the PARENT's phase (no seed offset) and the family colour.
  float pulseD = distressPulse(uTime) * ng;

  vec3 col = vec3(0.0);
  float discA = discMask(p, uRadius);
  float spinRate = kind > 1.5 && kind < 2.5 ? 0.22 : 0.035;
  mat3 rot = rotY(uSpin.x + uTime * spinRate + uSeed) * rotX(uSpin.y);
  float px = aa;

  // Shared aurora (thriving; disc AND halo), not on gems, only when the moon
  // is big enough for curtains to resolve.
  float auK = (th * 0.6 + uPulse * 0.5) * step(0.2, lod) * (kind > 1.5 && kind < 2.5 ? 0.0 : 1.0);
  vec2 au = auK > 0.001 ? auroraCurtains(p, rot, l, 0.88, uTime, px) * auK : vec2(0.0);
  vec3 auC = mix(glowC, mix(glowC, vec3(0.8, 0.6, 1.0), 0.4), saturate(au.y / max(au.x, 1e-4) * 2.0)) * au.x * 0.22;

  // Disc shading is evaluated a pixel past the limb with a clamped normal so the
  // antialiased edge never blends against black (no dark limb line).
  if (r < 1.0 + 2.0 * aa) {
    vec2 pd = p * min(1.0, 0.9995 / max(r, 1e-4));
    vec3 n = sphereNormal(pd);
    vec3 q = rot * n;
    float fres = 1.0 - saturate(n.z);
    float rimPow = mix(1.8, 3.4, lod);
    float ndlG = dot(n, l);
    float night = 1.0 - smoothstep(-0.2, 0.15, ndlG);

    vec3 albedo = tint;
    vec3 nrm = n;
    vec3 emis = vec3(0.0);     // true emission (lights, fissures, lava)
    vec3 reflE = vec3(0.0);    // extra REFLECTED light (graded with the surface)
    vec3 rimTint = glowC;
    float wrap = 0.06;
    float specAmt = 0.25;
    float specPow = 24.0;
    float rimScale = 1.0;

    if (kind < 0.5) {
      // ---------------- rocky / cratered ----------------
      float m = fbm3lo(q * 1.4 + uSeed);
      float grain = fbm3lo(q * 7.0 + uSeed * 2.0);
      vec3 regolith = vec3(0.4, 0.38, 0.36);
      albedo = mix(regolith, tint, 0.55) * (0.82 + 0.36 * grain * (0.4 + 0.6 * lod));
      float mare = smoothstep(0.44, 0.64, m);
      albedo *= mix(1.0, 0.6, mare);
      vec4 cr = dm_bigCraters(q, uSeed);
      if (lod > 0.15) {
        vec4 c2 = dm_cellCraters(q * 3.2 + uSeed * 1.7);
        cr += c2 * smoothstep(0.15, 0.45, lod) * (1.0 - mare * 0.5);
      }
      if (lod > 0.5) {
        vec4 c3 = dm_cellCraters(q * 7.0 + uSeed * 2.3 + 17.0);
        cr += c3 * 0.8 * smoothstep(0.5, 0.9, lod);
      }
      vec3 g = cr.xyz - q * dot(cr.xyz, q);   // tangent part of the gradient
      nrm = normalize(n - (g * rot) * mix(0.3, 0.7, lod));
      albedo *= 1.0 + cr.w * mix(0.4, 0.9, lod);
      specAmt = 0.06;
      specPow = 10.0;
      rimTint = mix(glowC, vec3(1.0), 0.3);
      rimScale = 0.7;
      // Thriving: warm settlement lights twinkle on the night side.
      if (lod > 0.25) {
        float cityN = noise3(q * 13.0 + uSeed * 5.0);
        float lights = smoothstep(0.84, 0.94, cityN) * smoothstep(0.3, 0.55, m);
        float tw = 0.7 + 0.3 * sin(uTime * 2.3 + cityN * 40.0);
        emis += vec3(1.0, 0.7, 0.36) * lights * tw * th * night * 2.0 * lod;
      }
    } else if (kind < 1.5) {
      // ---------------- icy (blue fresnel) ----------------
      float region = fbm3lo(q * 1.3 + uSeed);
      // Lineae: thin iso-contours of warped noise (Europa-like cracks).
      float n1 = fbm3lo(q * 1.7 + uSeed + region * 0.6);
      float n2 = fbm3lo(q.zxy * 3.3 + uSeed * 1.9 + 5.0);
      float lw = mix(0.05, 0.022, lod);
      float ln = 1.0 - smoothstep(0.0, lw, abs(n1 - 0.5));
      float ln2 = 1.0 - smoothstep(0.0, lw * 0.8, abs(n2 - 0.5));
      float lines = saturate(ln + ln2 * 0.7 * lod) * mix(0.5, 1.0, lod);
      vec3 ice = vec3(0.5, 0.58, 0.68);
      albedo = mix(ice, tint * 0.75, 0.4);
      albedo = mix(albedo, mix(tint, vec3(0.5, 0.42, 0.4), 0.3) * 0.55, smoothstep(0.5, 0.8, region) * 0.45);
      albedo = mix(albedo, mix(tint * 0.35, vec3(0.34, 0.15, 0.08), 0.5), lines * 0.8);
      albedo *= 0.9 + 0.16 * noise3(q * 9.0);
      wrap = 0.4;                            // soft sub-surface terminator
      specAmt = 0.9;
      specPow = 60.0;
      rimTint = mix(vec3(0.38, 0.7, 1.0), glowC, 0.25) * 1.3;
      rimScale = 1.35;
      // Cryo-fissures glow softly on thriving moons (most visible in shadow).
      float fissure = ln;
      emis += glowC * fissure * th * (0.1 + 0.9 * night) * 0.7 * (0.5 + 0.5 * lod);
      // Blue translucency just inside the terminator.
      float term = exp(-dm_sq((ndlG + 0.05) / 0.22));
      reflE += vec3(0.08, 0.3, 0.75) * term * 0.16;
    } else if (kind < 2.5) {
      // ---------------- faceted gem (ray-traced) ----------------
      // The cut's own pose: spin about a face axis with the tilt pinned to
      // 0.31–0.39 rad. The view direction then sweeps a cone that stays
      // ≥ ~12° from all 26 facet normals (at tilt 0 an equatorial facet
      // would face the camera exactly — the flat 'UI window' table).
      float gTilt = (uSpin.y < 0.0 ? -1.0 : 1.0) * (0.31 + 0.08 * saturate(abs(uSpin.y) / 0.5));
      mat3 grot = rotY(uSpin.x + uTime * spinRate + uSeed + 0.47) * rotX(gTilt);
      // Camera ray in object space.
      vec3 ex = grot * vec3(1.0, 0.0, 0.0);
      vec3 ey = grot * vec3(0.0, 1.0, 0.0);
      // Mild pinhole perspective (camera ~5.5 radii away): rays diverge a
      // little, so each flat facet sweeps a gradient of the environment
      // instead of reading as a flat low-poly tile.
      vec3 lateral = ex * p.x + ey * p.y;
      vec3 dir = normalize(grot * vec3(0.0, 0.0, -1.0) + lateral * 0.26);
      vec3 o = lateral - dir * 2.0;
      float tIn = -1e4, tOut = 1e4;
      vec3 dIn = vec3(0.0, 0.0, 1.0), dOut = vec3(0.0, 0.0, 1.0);
      float idIn = 0.0;
      for (int k = -1; k <= 1; k++)
      for (int j = -1; j <= 1; j++)
      for (int i = -1; i <= 1; i++) {
        vec3 v = vec3(float(i), float(j), float(k));
        float len2 = dot(v, v);
        vec3 d = v * inversesqrt(max(len2, 0.5));
        float den = dot(dir, d);
        float t = (DM_GEM_H - dot(o, d)) / (abs(den) > 1e-5 ? den : 1e-5);
        bool valid = len2 > 0.5;
        if (valid && den < 0.0 && t > tIn) { tIn = t; dIn = d; idIn = dot(v, vec3(1.0, 3.0, 9.0)); }
        if (valid && den > 0.0 && t < tOut) { tOut = t; dOut = d; }
      }
      // Exact antialiased polygonal silhouette: thickness / |∇thickness|.
      float thick = tOut - tIn;
      float dinI = dot(dir, dIn), dinO = dot(dir, dOut);
      vec2 gT = vec2(dot(ex, dIn) / dinI - dot(ex, dOut) / dinO,
                     dot(ey, dIn) / dinI - dot(ey, dOut) / dinO);
      float sd = thick / max(length(gT), 1e-3);
      discA = saturate(sd * uRadius + 0.5);
      nrm = dIn * grot;                      // flat facet normal, view space
      vec3 P = o + dir * tIn;
      // Two-bounce interior: refract in, hit the back facets, split into the
      // transmitted ray (Fresnel) and the internally reflected one (total
      // internal reflection past the critical angle), bounce once more, out.
      const float IOR = 2.0;
      vec3 Vo = -dir;
      vec3 upO = ey;
      vec3 keyO = grot * l;
      vec3 lo = deepC * 0.04 + tint * 0.012 + vec3(0.001, 0.0015, 0.003);
      // Studio fill follows the scene: a back-lit stone is lit mostly by the
      // core star shining THROUGH it (the key term in dm_env).
      vec3 hi = (tint * 1.2 + glowC * 0.3) * mix(0.4, 1.0, saturate(l.z * 0.6 + 0.6));
      vec3 rd1 = refract(dir, dIn, 1.0 / IOR);
      vec3 n1;
      float t1 = dm_gemExit(P, rd1, n1);
      vec3 P1 = P + rd1 * t1;
      vec3 ro1 = refract(rd1, -n1, IOR);
      float tir1 = step(dot(ro1, ro1), 1e-4);
      float c1 = saturate(dot(rd1, n1));
      float F1 = mix(0.1 + 0.9 * pow(1.0 - c1, 5.0), 1.0, tir1);
      vec3 rd2 = reflect(rd1, n1);
      vec3 n2;
      float t2 = dm_gemExit(P1, rd2, n2);
      vec3 ro2 = refract(rd2, -n2, IOR);
      float tir2 = step(dot(ro2, ro2), 1e-4);
      ro2 = mix(ro2, reflect(rd2, n2), tir2);
      vec3 tc = max(tint, vec3(0.02));
      vec3 ab1 = pow(tc, vec3(0.3 + t1 * 0.45));
      vec3 ab2 = pow(tc, vec3(0.3 + (t1 + t2) * 0.45));
      float fid = hash12(vec2(idIn + 13.0, uSeed * 7.0));
      float fidX = hash12(vec2(dot(n2, vec3(1.0, 3.0, 9.0)) + 29.0, uSeed));
      // Spectral "fire": each internal path gets a faint hue of its own.
      vec3 fire = 0.5 + 0.5 * cos(6.2832 * (fidX + vec3(0.0, 0.33, 0.67)));
      vec3 inner = dm_env(ro1, Vo, upO, keyO, lo, hi) * ab1 * (1.0 - F1)
                 + dm_env(ro2, Vo, upO, keyO, lo, hi) * mix(ab2, fire * 0.9, 0.1) * F1 * (1.0 - tir2 * 0.5);
      reflE += inner * (1.1 + 0.4 * th) * mix(0.8, 1.1, smoothstep(-0.9, 0.9, dot(p, normalize(l.xy + 1e-4))));
      // Surface reflection (Schlick) — dielectric, uncoloured.
      vec3 R = reflect(dir, dIn);
      float cosi = saturate(-dinI);
      float F = 0.1 + 0.9 * pow(1.0 - cosi, 5.0);
      // Key-light reflection gradient: every facet (the camera-facing table
      // included) brightens toward the star and falls off away from it.
      float keyGrad = mix(0.45, 1.3, smoothstep(-0.9, 0.9, dot(p, normalize(l.xy + 1e-4))));
      reflE += dm_env(R, Vo, upO, keyO, lo * 0.0, mix(hi, vec3(0.8), 0.35)) * F * keyGrad;
      // Bright facet edges (antialiased by the facet-plane distance gap).
      float gap = 1e4;
      for (int k = -1; k <= 1; k++)
      for (int j = -1; j <= 1; j++)
      for (int i = -1; i <= 1; i++) {
        vec3 v = vec3(float(i), float(j), float(k));
        float len2 = dot(v, v);
        vec3 d = v * inversesqrt(max(len2, 0.5));
        float den = dot(dir, d);
        float t = (DM_GEM_H - dot(o, d)) / (abs(den) > 1e-5 ? den : 1e-5);
        float dt = (tIn - t) * -den;         // plane distance of the entry point
        bool other = len2 > 0.5 && den < 0.0 && abs(dot(d, dIn) - 1.0) > 1e-3;
        gap = other ? min(gap, dt) : gap;
      }
      float edge = 1.0 - smoothstep(0.0, 1.5 * aa, gap);
      float edgeKey = pow(saturate(dot(reflect(vec3(0.0, 0.0, -1.0), nrm), l) * 0.5 + 0.5), 6.0);
      reflE += mix(tint, vec3(1.0), 0.6) * edge * (0.03 + 0.8 * edgeKey) * mix(0.3, 0.7, lod);
      // Facet glints: whole facets flash as the gem turns.
      // (Per-pixel mirror direction, so the flash sweeps across the facet.)
      float fl = saturate(dot(R * grot, l));
      reflE += mix(tint * 0.7, sunC * 3.0, smoothstep(0.975, 0.997, fl)) * smoothstep(0.93, 0.997, fl) * (0.4 + 0.8 * fid);
      // Inner fire for thriving items: a slow glow that breathes through the stone.
      emis += tint * glowC * (0.02 + 0.1 * th) * (0.6 + 0.4 * sin(uTime * 1.7 + fid * 6.28));
      albedo = tint * 0.04;
      specAmt = 0.0;
      rimTint = mix(glowC, tint, 0.3);
      rimScale = 0.5;
      fres = 1.0 - saturate(nrm.z);
    } else {
      // ---------------- warm lava-veined ----------------
      vec3 w = q * 1.6 + vec3(0.0, uTime * 0.012, uTime * 0.008);
      float warp = fbm3lo(w + uSeed);
      float rv = ridged3(q * 1.9 + warp * 0.8 + uSeed * 1.7);
      float vein = smoothstep(0.56, 0.82, rv);
      float glowBank = smoothstep(0.42, 0.82, rv);
      float plates = fbm3lo(q * 5.0 + uSeed);
      // Crust bump: finite difference toward the light.
      float plates2 = fbm3lo(q * 5.0 + uSeed + (rot * l) * 0.05);
      vec3 basalt = vec3(0.07, 0.06, 0.058);
      albedo = mix(basalt, tint * 0.14, 0.3) * (0.6 + 0.8 * plates);
      albedo *= 1.0 - glowBank * 0.5;
      float bump = (plates - plates2) * 7.0 * lod;
      float flow = 0.7 + 0.3 * sin(uTime * 1.1 - warp * 11.0 + uSeed);
      float heat = (vein * flow + glowBank * 0.14) * mix(0.6, 1.0, th) * (1.0 - ng * 0.6);
      vec3 hot = dm_lava(heat);
      hot = mix(hot, hot * (0.5 + tint * 1.5), 0.3);
      emis += hot * mix(1.4, 2.4, lod) * (0.65 + 0.35 * night) * (1.0 - ng * 0.5);
      reflE += albedo * bump * saturate(ndlG) * 2.0;
      // Heat haze at the limb.
      emis += vec3(1.0, 0.35, 0.08) * pow(fres, 3.0) * 0.14 * (1.0 - ng * 0.7);
      specAmt = 0.12;
      specPow = 30.0;
      rimTint = mix(vec3(1.0, 0.55, 0.2), glowC, 0.35);
      rimScale = 0.6;
    }

    // ---------------- lighting ----------------
    float ndl = dot(nrm, l);
    float diff = saturate((ndl + wrap) / (1.0 + wrap));
    diff *= smoothstep(-0.1 - wrap * 0.5, 0.2, ndlG);
    vec3 hv = normalize(l + vec3(0.0, 0.0, 1.0));
    float spec = pow(saturate(dot(nrm, hv)), specPow) * specAmt * smoothstep(0.0, 0.2, ndlG);
    vec3 ambient = (deepC * 0.4 + tint * 0.06) * 0.2 + vec3(0.004, 0.006, 0.012);
    vec3 lit = albedo * (diff * 1.75 * sunC + ambient) + sunC * spec + reflE;

    // Clean rim light (fresh) — strong toward the core star, a hint on the
    // whole limb so the silhouette always reads on the night side.
    float rim = pow(fres, rimPow);
    float sunward = saturate(dot(normalize(pd), normalize(l.xy + 1e-4)) * 0.5 + 0.5);
    float backlit = saturate(-l.z);
    float rimAmt = mix(0.12, 1.0, fresh) * (0.12 + 0.88 * sunward * sunward + backlit * 0.9 * sunward) * rimScale;
    lit += rimTint * rim * rimAmt;

    // ---------------- living state ----------------
    if (ng > 0.001) {                        // skip 6 texture taps on healthy moons
      vec3 dq = q * 2.2 + vec3(uTime * 0.05, 0.0, -uTime * 0.03);
      float dust = smoothstep(0.38, 0.8, fbm3lo(dq + fbm3lo(q * 3.0 + uTime * 0.02) * 1.2));
      vec3 dustC = vec3(0.36, 0.33, 0.3) * (diff * 1.4 + 0.03);
      lit = mix(lit, dustC, dust * ng * 0.5);
    }
    // Shared grade (thriving: richer and a touch brighter; neglected: dimmer
    // and greyer), then the moons' cold cast (luminance-neutral).
    lit = lifeGrade(lit, th, ng);
    lit *= mix(vec3(1.0), vec3(0.82, 0.95, 1.2), ng * 0.6);
    // Emission cools with neglect on its own terms (lights fail, lava dulls).
    col = lit + emis * (1.0 - ng * 0.45);
    col += auC;
    if (ng > 0.3 && lod > 0.35) {
      float ck = cracks(q * 0.8 + uSeed) * smoothstep(0.45, 0.7, noise3(q * 2.0 + uSeed));
      col += vec3(1.0, 0.28, 0.1) * ck * smoothstep(0.45, 0.95, ng) * (0.15 + 0.85 * night) * 0.22 * lod;
    }
    // Distress: family colour, parent's phase, softer than the planets (0.35).
    col += distressColor() * pow(fres, mix(1.8, 3.0, lod)) * pulseD * 0.35;

    // ---------------- celebration ----------------
    // Exposure lift keeps the surface legible; the flare lives on the rim.
    col *= 1.0 + uPulse * 0.55;
    col += glowC * uPulse * (0.025 + pow(fres, 2.2) * 1.3);
    // Selection highlight on the limb.
    col += glowC * uExtra.y * pow(fres, 3.0) * 0.5;
  }

  // ---------------- halo (continuous across the limb) ----------------
  float rr = max(r, 1.0);
  float dpx = (rr - 1.0) * uRadius;                               // px past the limb
  float tightPx = max(uRadius * 0.08, 1.3);
  float widePx = max(uRadius * 0.3, 2.6);
  vec2 lp = normalize(l.xy + 1e-4);
  float dayside = saturate(dot(p / max(r, 1e-4), lp) * 0.55 + 0.55);
  float edgeFade = 1.0 - smoothstep(DM_HALO - 0.4, DM_HALO - 0.02, r);
  vec3 halo = glowC * (exp(-dpx / tightPx) * 0.45 + exp(-dpx / widePx) * 0.2)
            * mix(0.12, 1.0, fresh) * (1.0 - ng * 0.55) * dayside;
  halo += auC;
  // Distress halo: shared shape, softer (0.2).
  halo += distressColor() * distressHalo(r, pulseD, px) * (0.2 / 0.3);
  // Celebration: bright flare plus the family limb shock ring.
  halo += glowC * uPulse * exp(-dpx / widePx) * 0.9;
  halo += mix(glowC, vec3(1.0), 0.3) * limbShock(r, uPulse, px) * 0.8;
  // Selection ring: thin, breathing.
  float selR = 1.0 + max(3.0 / uRadius, 0.16);
  float sel = exp(-dm_sq((r - selR) * uRadius / 0.8));
  halo += glowC * sel * uExtra.y * (0.75 + 0.25 * sin(uTime * 2.4)) * 0.9;
  halo *= edgeFade;

  // ---------------- 8-point glint (fresh items twinkle) ----------------
  vec3 hvec = normalize(l + vec3(0.0, 0.0, 1.0));
  vec2 gpos = uCenter + vec2(hvec.x, -hvec.y) * uRadius * mix(0.95, 0.7, lod);
  float tw = pow(saturate(sin(uTime * 1.25 + uSeed * 5.3)), 4.0);
  float gAmt = (th * (0.35 + 0.65 * tw) * smoothstep(0.0, 0.3, hvec.z) + uPulse * 1.2) * 0.8;
  if (gAmt > 0.001) {
    float arm = clamp(uRadius * 0.45, 6.0, 14.0) * (1.0 + uPulse * 0.7);
    float g = dm_glint(frag - gpos, arm, 0.55);
    vec3 gl = mix(vec3(1.0, 0.97, 0.9), glowC, 0.3) * g * gAmt * edgeFade;
    col += gl;
    halo += gl;
  }

  fragColor = compositeDiscHalo(col, discA, halo, frag);
}
