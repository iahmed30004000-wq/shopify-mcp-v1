#version 460 core
#include <flutter/runtime_effect.glsl>
#include "lib/common.glsl"

// HEALTH — "Ocean": a living water world. Turquoise shallows and reefs around
// jungle archipelagos, deep-blue abyss, swirling cloud decks.
//   thriving : bioluminescent currents — organic, braided streams that follow
//              the ocean's circulation and carry travelling light packets; the
//              whole network pulses with a heartbeat (lub-dub) that spreads
//              over the globe from the planet's "heart" (and makes the halo
//              breathe); the currents glow and tint the water by day too;
//              glowing reef rims, mint aurora curtains, sun-glint sparkle.
//   neglected: murky algae bloom + red-tide patches, desaturation, dimming,
//              dust haze, cracked dry islands, slow faint heartbeat, red
//              distress pulse.
// Heart rate never multiplies uTime by a score-dependent rate (that strobes
// while uScore animates): a resting (~42 bpm) and a lively (~72 bpm) beat are
// cross-faded instead, so every uniform can animate continuously.
// Identity vs Growth (verdant): Health is GLOWING WATER – small archipelagos,
// luminous cyan-teal seas, currents that glow by day too; Growth is green land.
//
// FAMILY LOOK (common.glsl): lifeGrade (thriveGrade + neglectGrade) on the lit
// surface, the shared forward-scatter haze/halo (density × haloGain, and ×
// the heartbeat so the pulse reads at 22 px), the shared soft aurora curtains
// (mint → blue-violet), the limb shock ring for uPulse, the shared distress
// rim/halo and compositeDiscHalo.
//
// uExtra: unused (reserved).
// haloFactor: 1.35.
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

// Lub-dub envelope for a beat phase in [0,1).
float oc_lubdub(float ph) {
  float a = (ph - 0.04) / 0.035;
  float b = (ph - 0.2) / 0.045;
  return exp(-a * a) + 0.55 * exp(-b * b);
}

// Heartbeat wave: phase delayed by the distance from the heart so the beat
// travels across the globe. Returns 0..~1.
float oc_heartbeat(float t, float dist, float live) {
  float slow = oc_lubdub(fract(t * 0.7 - dist * 0.22));     // ~42 bpm
  float fast = oc_lubdub(fract(t * 1.2 - dist * 0.3));      // ~72 bpm
  return mix(slow, fast, live);
}

float oc_psi(vec3 x, float warp, float t) {
  vec3 w = x * vec3(1.1, 2.3, 1.1) + vec3(warp * 1.7, warp * 0.4, -warp * 1.3) + vec3(t * 0.004, 0.0, 0.0);
  return noise3(w) * 0.68 + noise3(w * 2.1 + 3.7) * 0.32;     // smooth: long, graceful streamlines
}

// Bioluminescent streams. Streams are *selected* streamlines (level sets) of a
// warped, anisotropic stream function (zonal currents with eddies): each band
// keeps at most one line with its own brightness and width; line width is
// measured in true surface distance (|psi - level| / |grad psi|) so lines stay
// thin everywhere and small loops around extrema fade out; lines fade in and
// out along their length and carry travelling packets, so they read as flowing
// organic streams rather than evenly spaced contours.
// Returns x = core line, y = soft glow, z = packet brightness along the line.
vec3 oc_streams(vec3 x, vec3 q, float t, float aa, float warp) {
  float psi = oc_psi(x, warp, t);
  vec3 e1 = normalize(cross(q, vec3(0.0, 1.0, 0.0)) + vec3(1e-4, 0.0, 0.0));
  vec3 e2 = cross(q, e1);
  const float h = 0.01;
  vec2 g = vec2(oc_psi(x + e1 * h, warp, t) - psi, oc_psi(x + e2 * h, warp, t) - psi) / h;
  float gl = max(length(g), 1e-3);
  float bands = 5.0;
  float s = psi * bands;
  float id = floor(s + 0.5);                          // nearest level
  float hsh = hash12(vec2(id, 11.0 + uSeed));
  float d = abs(s - id) / bands / gl;                 // surface distance to the streamline
  float keep = step(0.35, hsh) * smoothstep(0.25, 0.6, gl);   // no eyes around extrema
  float wid = mix(0.0022, 0.0055, fract(hsh * 7.3));
  float fade = smoothstep(0.42, 0.68, noise3(x * 2.6 + id * 1.7));
  float ww = wid + aa;
  float core = exp(-d * d / (ww * ww)) * (wid / ww) * keep * fade;
  float glow = exp(-d * d / (ww * ww * 16.0)) * keep * fade;
  // travelling packets: along-stream coordinate ≈ longitude (currents are zonal)
  float lon = atan(q.z, q.x);
  float dir = hsh > 0.65 ? 1.0 : -1.0;
  float pk = fract(lon * (2.0 + floor(hsh * 3.0)) / TAU + psi * 2.0 - t * 0.05 * dir + hsh);
  float packets = smoothstep(0.0, 0.05, pk) * (1.0 - smoothstep(0.05, 0.4, pk));
  return vec3(core * (0.45 + 0.55 * fract(hsh * 3.1)), glow, packets);
}

vec2 oc_cube(vec3 x, out float face) {
  vec3 a = abs(x);
  if (a.x >= a.y && a.x >= a.z) { face = x.x > 0.0 ? 0.0 : 1.0; return x.yz / a.x; }
  if (a.y >= a.z) { face = x.y > 0.0 ? 2.0 : 3.0; return x.xz / a.y; }
  face = x.z > 0.0 ? 4.0 : 5.0;
  return x.xy / a.z;
}

// Conservative screen-space bound of the shared aurora curtains: every sheet
// point X = rho·(±c·A + s·w) (w ⟂ A, rho ∈ [1, 1+AURORA_H], c = ovalY ± 0.03)
// projects inside one of two flat ellipses around the projected ovals, so
// outside them auroraCurtains() returns exactly 0 and the call (1 noise tap +
// the quadratic, up to 7 taps) can be skipped with no visible change.
bool oc_auroraNear(vec2 p, mat3 rot, float ovalY, float px) {
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
  float live = smoothstep(0.1, 1.0, uScore);

  vec3 cA = toLinear(uColorA.rgb);
  vec3 cB = toLinear(uColorB.rgb);
  vec3 cC = toLinear(uColorC.rgb);
  vec3 atmoCol = mix(mix(cA, vec3(0.5, 0.72, 1.0), 0.45), toLinear(vec3(0.6, 0.58, 0.5)), ng * 0.6);
  vec3 auBase = mix(cB, vec3(0.6, 1.0, 0.9), 0.3);
  vec3 auTop = mix(cB, toLinear(vec3(0.5, 0.6, 1.0)), 0.7);
  float pulseD = distressPulse(t) * ng;

  mat3 rot = rotY(uSpin.x + t * 0.02) * rotX(uSpin.y);
  vec3 heartDir = normalize(vec3(0.3, 0.25, 0.92));
  // shared atmosphere; its density also breathes with the heartbeat (thriving)
  float phase = atmoPhase(l);
  float gain = 2.0 * haloGain(th, ng) * (1.0 + 0.5 * uPulse);
  float tau0 = 0.035 * (1.0 + 1.2 * ng);
  float fine = smoothstep(0.2, 0.45, uDetail);

  // shared aurora curtains, evaluated once for disc and halo
  float auK = (th * 0.9 + uPulse * 0.8) * mix(0.35, 1.0, smoothstep(22.0, 60.0, uRadius));   // faded at small radii
  vec2 au = (auK > 0.001 && oc_auroraNear(p, rot, 0.91, px)) ? auroraCurtains(p, rot, l, 0.91, t, px) * auK : vec2(0.0);
  vec3 auC = mix(auBase, auTop, saturate(au.y / max(au.x, 1e-4) * 2.0)) * au.x * 0.22;

  float discA = discMask(p, uRadius);
  vec3 col = vec3(0.0);

  if (discA > 0.0) {
    // Clamp to the disc so the anti-aliased rim is shaded (no dark seam).
    vec2 pd = p * min(1.0, 0.9995 / max(r, 1e-4));
    vec3 n = sphereNormal(pd);
    vec3 q = rot * n;
    vec3 ql = rot * l;
    vec3 x = q + uSeed;
    float mu = n.z;
    float ndl = dot(n, l);
    float pxObj = 1.0 / (uRadius * max(mu, 0.05));
    float night = smoothstep(0.08, -0.22, ndl);

    // ---- islands & sea floor: small archipelagos in luminous cyan-teal seas ----
    float warp = fbm3lo(x * 1.5 + vec3(0.0, t * 0.006, 0.0));
    float h = fbm3(x * 2.1 + warp * 1.2);
    const float coast = 0.67;
    float coastW = max(0.004, pxObj * 1.2);
    float land = smoothstep(coast - coastW, coast + coastW, h);
    float shallow = smoothstep(0.52, 0.665, h);
    vec3 deep = mix(cC, cA, 0.22) * 0.6;
    vec3 reef = mix(cA, vec3(0.55, 0.95, 0.9), 0.25) * 0.85;
    vec3 water = mix(deep, mix(cA * 0.55, reef, smoothstep(0.605, 0.665, h)), shallow);
    vec3 sand = toLinear(vec3(0.86, 0.8, 0.62));
    // muted, blue-leaning jungle (Growth owns saturated green land)
    vec3 jungle = toLinear(vec3(0.2, 0.31, 0.27));
    vec3 highland = toLinear(vec3(0.34, 0.38, 0.33));
    vec3 ground = mix(sand, jungle, smoothstep(0.68, 0.705, h));
    ground = mix(ground, highland, smoothstep(0.76, 0.82, h));
    if (fine > 0.0) ground *= 1.0 + (noise3(x * 30.0) - 0.5) * 0.3 * smoothstep(2.0, 5.0, 1.0 / (30.0 * pxObj));
    vec3 albedo = mix(water, ground, land);

    // ---- bioluminescent currents (computed first: they also tint the day-side water) ----
    float hd = acos(clamp(dot(q, heartDir), -1.0, 1.0));
    float beat = oc_heartbeat(t, hd, live);
    vec3 st = oc_streams(x, q, t, pxObj * 0.7, warp);
    albedo = mix(albedo, cB * 0.6, st.y * 0.15 * live * (1.0 - land));

    // Neglect: murky algae bloom, red-tide patches, dried islands.
    float murk = ng > 0.001 ? smoothstep(0.35, 0.7, warp + (noise3(x * 5.0) - 0.5) * 0.3) * ng : 0.0;
    albedo = mix(albedo, toLinear(vec3(0.3, 0.3, 0.17)) * (1.0 - land * 0.2), murk * 0.7 * (1.0 - land));
    float redTide = ng > 0.4 ? smoothstep(0.6, 0.8, noise3(x * 3.5 + 21.0)) * smoothstep(0.4, 0.9, ng) * (1.0 - land) : 0.0;
    albedo = mix(albedo, toLinear(vec3(0.42, 0.14, 0.1)), redTide * 0.55);
    albedo = mix(albedo, mix(sand, vec3(luma(ground)), 0.5) * 0.6, land * ng * 0.6);

    // ---- lighting ----
    float lam = saturate(ndl);
    float diff = lam * smoothstep(-0.05, 0.1, ndl + 0.03);
    vec3 sunCol = vec3(1.0, 0.96, 0.9) * mix(2.0, 1.55, ng);
    vec3 sky = atmoCol * 0.06 * smoothstep(-0.25, 0.4, ndl);
    vec3 lit = albedo * (sunCol * diff + sky);
    vec3 hv = normalize(l + vec3(0.0, 0.0, 1.0));
    float nh = saturate(dot(n, hv));
    float fres = pow(1.0 - saturate(mu), 5.0);
    float waves = mix(0.5, fine > 0.0 ? noise3(x * 60.0 + vec3(t * 0.15, 0.0, 0.0)) : 0.5, smoothstep(2.0, 5.0, 1.0 / (60.0 * pxObj)));
    float spec = (pow(nh, 300.0) * 2.2 * (0.4 + 1.2 * waves) + pow(nh, 45.0) * 0.08) * (1.0 - land) * (1.0 - murk * 0.7);
    lit += sunCol * spec * smoothstep(0.0, 0.15, ndl);
    lit += atmoCol * fres * 0.12 * (1.0 - land) * smoothstep(-0.1, 0.3, ndl);

    // ---- clouds: warped decks with soft self-shadow ----
    vec3 cq = x * 2.6 + vec3(t * 0.01, 0.0, -t * 0.006) + warp * 1.4;
    float cn = fine > 0.0 ? fbm3(cq) : fbm3lo(cq);
    float cl = smoothstep(0.56, 0.78, cn) * (1.0 - ng * 0.4);
    float clSh = smoothstep(0.56, 0.78, fbm3lo(cq + ql * 0.09));
    lit *= 1.0 - clSh * 0.4 * smoothstep(0.0, 0.2, ndl);
    vec3 cloudCol = vec3(0.96, 0.98, 1.0) * (sunCol * saturate(ndl * 1.1 + 0.08) * (0.8 + 0.3 * (cn - 0.5)) + sky * 1.5);
    lit = mix(lit, cloudCol, cl * 0.92);

    // dust haze (neglect)
    float dust = 0.0;
    if (ng > 0.001) {
      dust = dustStorm(x, t) * ng;
      lit = mix(lit, toLinear(vec3(0.62, 0.54, 0.4)) * (sunCol * saturate(ndl * 0.9 + 0.1) + sky), dust * 0.55);
    }
    // cracked, dried islands (neglect) darken the ground
    float ck = 0.0;
    if (ng > 0.02) {
      vec2 v = voronoi3(x * 7.0);
      ck = (1.0 - smoothstep(0.0, max(0.03, pxObj * 3.0), v.y - v.x)) * land * smoothstep(0.3, 0.8, ng);
      lit *= 1.0 - ck * 0.4;
    }
    float term = exp(-ndl * ndl / 0.02);
    lit *= mix(vec3(1.0), vec3(1.3, 0.85, 0.65), term * 0.5);

    // Family living-state grade: after surface lighting, before emission.
    lit = lifeGrade(lit, th, ng);

    // ---- bioluminescence: visible by day, vivid at night ----
    float vivid = mix(0.1, 1.0, live) * (1.0 - ng * 0.6) + uPulse * 0.8;
    float bio = (st.x * (0.7 + 2.0 * st.z) + st.y * 0.05) * (1.0 - land) * (1.0 - cl * 0.85) * (1.0 - murk * 0.8);
    bio *= vivid * (0.45 + 0.9 * beat);
    // reef rims glow along the coasts
    float rimW = max(0.006, pxObj * 1.5);
    float rimD = (coast - h) / rimW;
    float rim = exp(-rimD * rimD) * (1.0 - land) * th * (0.4 + 0.6 * beat);
    vec3 bioCol = mix(cB, vec3(0.7, 1.0, 0.95), 0.2);
    vec3 emit = bioCol * (bio * (0.7 + 1.6 * night) + rim * 0.2 * (0.2 + night));
    // firefly glades: sparse, clustered twinkles over the night-side jungle (thriving)
    float face;
    vec2 uv = oc_cube(q, face);
    float glade = 0.0;
    if (land > 0.0 && night > 0.0) {
      glade = smoothstep(0.5, 0.75, noise3(x * 9.0 + 4.0)) * smoothstep(0.45, 0.75, noise3(x * 3.3 + 31.0));
    }
    vec2 fg = uv * 40.0;
    vec2 fid = floor(fg);
    vec2 fh = hash22(fid + face * 7.7 + uSeed);
    float fS = max(0.0016, pxObj * 0.8);
    float fd = length(fract(fg) - 0.25 - 0.5 * fh) / 40.0;
    float tw = 0.5 + 0.5 * sin(t * (1.5 + 2.0 * fh.x) + fh.y * 30.0);
    float fly = exp(-fd * fd / (fS * fS)) * (0.0016 * 0.0016) / (fS * fS) * step(1.0 - glade * 0.3, fh.y) * tw;
    float flyLod = smoothstep(1.5, 4.0, 1.0 / (40.0 * pxObj));
    fly = mix(0.005 * glade, fly, flyLod) * smoothstep(0.685, 0.715, h) * land * night * (th * 0.9 + uPulse);
    emit += mix(cB, vec3(0.75, 1.0, 0.45), 0.6) * (fly * 1.4 + glade * 0.01 * night * land * th);
    // night land is never a black hole: faint airglow albedo floor
    emit += cB * 0.004 * land * night;
    // soft ocean glow under the streams on the night side (thriving)
    emit += cB * 0.01 * th * night * (1.0 - land) * (0.6 + 0.4 * beat);
    // red tide glows faintly at night, in time with the distress pulse
    emit += distressColor() * redTide * night * 0.015 * (0.3 + 0.7 * pulseD);
    // cracked islands: embers in the cracks at night
    emit += distressColor() * ck * night * 0.2 * (0.4 + 0.6 * pulseD);

    // sparkle: sun glitter on wave crests, keyed on the cube-sphere grid (turns
    // with the ocean) and confined to the tight specular lobe (thriving)
    vec2 sgf = uv * 55.0;
    vec2 sg = floor(sgf);
    float sph = fract(t * 0.5 + hash12(sg * 0.73 + face * 3.1) * 9.0);
    float sd = length(fract(sgf) - 0.5) / 55.0;
    float ss = max(0.0012, pxObj * 0.7);
    float spk = step(0.93, hash12(sg + face * 11.0 + floor(t * 1.5) * 0.37)) * smoothstep(0.0, 0.1, sph) * (1.0 - smoothstep(0.1, 0.3, sph));
    spk *= exp(-sd * sd / (ss * ss)) * (0.0012 * 0.0012) / (ss * ss);
    emit += vec3(1.0, 0.98, 0.9) * spk * (th + uPulse) * pow(nh, 80.0) * (1.0 - land) * (1.0 - cl) * 6.0;

    // ---- shared atmosphere (the haze breathes with the heartbeat) ----
    vec3 T;
    vec3 S = atmoHaze(mu, ndl, atmoCol, tau0, vec3(1.3, 1.0, 0.75), gain * (1.0 + 0.25 * beat * live), phase, T);
    col = (lit + emit) * T + S;
    col += auC;
    col += distressColor() * distressRim(mu, pulseD);
    col += cB * uPulse * pow(1.0 - saturate(mu), 6.0) * 1.2;       // celebration flourish: rim flash
  }

  // ---- halo: shared forward-scatter halo (heartbeat-breathing) + aurora + shock + distress ----
  vec3 qL = rot * vec3(p / max(r, 1e-4), 0.0);
  float beatL = oc_heartbeat(t, acos(clamp(dot(qL, heartDir), -1.0, 1.0)), live);
  vec3 halo = atmoHalo(p, l, atmoCol, tau0, 0.035, gain * (1.0 + 0.25 * beatL * live), phase, px);
  halo += auC;
  halo += cB * limbShock(r, uPulse, px) * 0.6;
  halo += distressColor() * distressHalo(r, pulseD, px);

  fragColor = compositeDiscHalo(col, discA, halo, frag);
}
