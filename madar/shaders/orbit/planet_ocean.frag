#version 460 core
#include <flutter/runtime_effect.glsl>
#include "lib/common.glsl"

// HEALTH — "Ocean": a living water world. Turquoise shallows and reefs around
// jungle archipelagos, deep-blue abyss, swirling cloud decks.
//   thriving : bioluminescent currents — organic, braided streams that follow
//              the ocean's circulation and carry travelling light packets; the
//              whole network pulses with a heartbeat (lub-dub) that spreads
//              over the globe from the planet's "heart"; glowing reef rims,
//              mint aurora, sun-glint sparkle.
//   neglected: murky algae bloom + red-tide patches, desaturation, dimming,
//              dust haze, cracked dry islands, slow faint heartbeat, red
//              distress pulse.
// Heart rate never multiplies uTime by a score-dependent rate (that strobes
// while uScore animates): a resting (~42 bpm) and a lively (~72 bpm) beat are
// cross-faded instead, so every uniform can animate continuously.
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

// Mint aurora ribbon (object space, y = spin axis).
float oc_aurora(vec3 q, float t, float px) {
  vec2 dir = normalize(q.xz + 1e-4);
  float hemi = q.y > 0.0 ? 1.0 : -1.0;
  float wob = (noise3(vec3(dir * 1.7, t * 0.06 + hemi * 4.0)) - 0.5) * 0.06
            + (noise3(vec3(dir * 6.8, t * 0.14 + hemi * 2.0)) - 0.5) * 0.02;
  float d = abs(q.y) - (0.915 + wob);
  float wEq = max(0.004, px);
  float band = (d < 0.0 ? exp(-d * d / (wEq * wEq)) : exp(-d / max(0.005, px * 0.8))) * (0.004 / wEq);
  float rays = noise3(vec3(dir * 30.0, t * 0.3 + hemi * 3.0));
  float drift = smoothstep(0.25, 0.65, noise3(vec3(dir * 2.3 - t * 0.03, hemi * 9.0)));
  return band * (0.6 + 0.4 * rays) * (0.2 + 0.8 * drift);
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
  float live = smoothstep(0.1, 1.0, uScore);

  vec3 cA = toLinear(uColorA.rgb);
  vec3 cB = toLinear(uColorB.rgb);
  vec3 cC = toLinear(uColorC.rgb);
  vec3 atmoCol = mix(mix(cA, vec3(0.5, 0.72, 1.0), 0.45), toLinear(vec3(0.6, 0.58, 0.5)), ng * 0.6);
  vec3 distressCol = toLinear(vec3(1.0, 0.2, 0.14));
  float pulseD = distressPulse(t) * ng;

  mat3 rot = rotY(uSpin.x + t * 0.02) * rotX(uSpin.y);
  float phase = 0.7 + 3.0 * pow(saturate(0.5 - 0.5 * l.z), 5.0);
  float atmoGain = mix(0.65, 1.0, live) * (1.0 + uPulse * 0.5);
  const float tauAtm = 0.035;
  float fine = smoothstep(0.2, 0.45, uDetail);

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

    // ---- islands & sea floor ----
    float warp = fbm3lo(x * 1.5 + vec3(0.0, t * 0.006, 0.0));
    float h = fbm3(x * 2.1 + warp * 1.2);
    float coastW = max(0.004, pxObj * 1.2);
    float land = smoothstep(0.645 - coastW, 0.645 + coastW, h);
    float shallow = smoothstep(0.5, 0.64, h);
    vec3 deep = cC * 0.45;
    vec3 reef = mix(cA, vec3(0.55, 0.95, 0.9), 0.25) * 0.85;
    vec3 water = mix(deep, mix(cA * 0.5, reef, smoothstep(0.58, 0.64, h)), shallow);
    vec3 sand = toLinear(vec3(0.86, 0.8, 0.62));
    vec3 jungle = toLinear(vec3(0.12, 0.36, 0.2));
    vec3 highland = toLinear(vec3(0.3, 0.42, 0.26));
    vec3 ground = mix(sand, jungle, smoothstep(0.655, 0.685, h));
    ground = mix(ground, highland, smoothstep(0.74, 0.8, h));
    if (fine > 0.0) ground *= 1.0 + (noise3(x * 30.0) - 0.5) * 0.3 * smoothstep(2.0, 5.0, 1.0 / (30.0 * pxObj));
    vec3 albedo = mix(water, ground, land);

    // Neglect: murky algae bloom, red-tide patches, dried islands.
    float murk = ng > 0.001 ? smoothstep(0.35, 0.7, warp + (noise3(x * 5.0) - 0.5) * 0.3) * ng : 0.0;
    albedo = mix(albedo, toLinear(vec3(0.3, 0.3, 0.17)) * (1.0 - land * 0.2), murk * 0.7 * (1.0 - land));
    float redTide = ng > 0.4 ? smoothstep(0.6, 0.8, noise3(x * 3.5 + 21.0)) * smoothstep(0.4, 0.9, ng) * (1.0 - land) : 0.0;
    albedo = mix(albedo, toLinear(vec3(0.42, 0.14, 0.1)), redTide * 0.55);
    albedo = mix(albedo, mix(sand, vec3(luma(ground)), 0.5) * 0.9, land * ng * 0.6);

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
    lit = desaturate(lit, ng * 0.5) * (1.0 - ng * 0.3);

    // ---- bioluminescence ----
    float night = smoothstep(0.08, -0.22, ndl);
    vec3 heartDir = normalize(vec3(0.3, 0.25, 0.92));
    float hd = acos(clamp(dot(q, heartDir), -1.0, 1.0));
    float beat = oc_heartbeat(t, hd, live);
    vec3 st = oc_streams(x, q, t, pxObj * 0.7, warp);
    float vivid = mix(0.1, 1.0, live) * (1.0 - ng * 0.6) + uPulse * 0.8;
    float bio = (st.x * (0.7 + 2.0 * st.z) + st.y * 0.05) * (1.0 - land) * (1.0 - cl * 0.85) * (1.0 - murk * 0.8);
    bio *= vivid * (0.45 + 0.9 * beat);
    // reef rims glow along the coasts
    float rimW = max(0.006, pxObj * 1.5);
    float rimD = (0.645 - h) / rimW;
    float rim = exp(-rimD * rimD) * (1.0 - land) * th * (0.4 + 0.6 * beat);
    vec3 bioCol = mix(cB, vec3(0.7, 1.0, 0.95), 0.2);
    vec3 emit = bioCol * (bio * (0.3 + 1.8 * night) + rim * 0.2 * (0.2 + night));
    // firefly glades: twinkling points over the night-side jungle (thriving)
    float face;
    vec2 uv = oc_cube(q, face);
    vec2 fg = uv * 40.0;
    vec2 fid = floor(fg);
    vec2 fh = hash22(fid + face * 7.7 + uSeed);
    float fS = max(0.0016, pxObj * 0.8);
    float fd = length(fract(fg) - 0.25 - 0.5 * fh) / 40.0;
    float tw = 0.5 + 0.5 * sin(t * (1.5 + 2.0 * fh.x) + fh.y * 30.0);
    float glade = (land > 0.0 && night > 0.0) ? smoothstep(0.5, 0.75, noise3(x * 9.0 + 4.0)) : 0.0;
    float fly = exp(-fd * fd / (fS * fS)) * (0.0016 * 0.0016) / (fS * fS) * step(1.0 - glade * 0.9, fh.y) * tw;
    float flyLod = smoothstep(1.5, 4.0, 1.0 / (40.0 * pxObj));
    fly = mix(0.015 * glade, fly, flyLod) * smoothstep(0.66, 0.7, h) * land * night * (th * 0.9 + uPulse);
    emit += mix(cB, vec3(0.75, 1.0, 0.45), 0.6) * (fly * 1.4 + glade * 0.01 * night * land * th);
    // soft ocean glow under the streams on the night side (thriving)
    emit += cB * 0.01 * th * night * (1.0 - land) * (0.6 + 0.4 * beat);
    // red tide glows faintly at night, in time with the distress pulse
    emit += distressCol * redTide * night * 0.015 * (0.3 + 0.7 * pulseD);

    // sparkle: sun glitter on wave crests (thriving)
    vec2 sg = floor(pd * uRadius * 0.5);
    float sph = fract(t * 0.5 + hash12(sg * 0.73) * 9.0);
    float spk = step(0.996, hash12(sg + floor(t * 1.5) * 0.37)) * smoothstep(0.0, 0.1, sph) * (1.0 - smoothstep(0.1, 0.3, sph));
    emit += vec3(1.0, 0.98, 0.9) * spk * (th + uPulse) * pow(nh, 12.0) * (1.0 - land) * (1.0 - cl) * 2.5;

    // cracked, dried islands (neglect)
    if (ng > 0.02) {
      vec2 v = voronoi3(x * 7.0);
      float ck = (1.0 - smoothstep(0.0, max(0.03, pxObj * 3.0), v.y - v.x)) * land * smoothstep(0.3, 0.8, ng);
      lit *= 1.0 - ck * 0.4;
      emit += distressCol * ck * night * 0.2 * (0.4 + 0.6 * pulseD);
    }

    // ---- atmosphere ----
    float airmass = 1.0 / (max(mu, 0.0) + 0.1);
    float tau = tauAtm * airmass * (1.0 + ng * 1.0);
    vec3 T = exp(-tau * vec3(1.3, 1.0, 0.75));
    float sunAtm = smoothstep(-0.3, 0.3, ndl);
    vec3 S = atmoCol * (1.0 - exp(-tau)) * sunAtm * phase * 2.0 * atmoGain;
    float term = exp(-ndl * ndl / 0.02);
    lit *= mix(vec3(1.0), vec3(1.3, 0.85, 0.65), term * 0.5);
    col = (lit + emit) * T + S;
    float auK = th * 0.85 + uPulse * 0.8;
    float au = auK > 0.001 ? oc_aurora(q, t, 1.0 / uRadius) * auK : 0.0;
    col += mix(cB, vec3(0.6, 1.0, 0.9), 0.3) * au * (0.06 + night) / (saturate(mu) + 0.6) * 0.55;
    float fr3 = pow(1.0 - saturate(mu), 3.0);
    col += distressCol * fr3 * pulseD * 0.65;
    col += cB * uPulse * fr3 * fr3 * 1.2;
  }

  // ---- halo (continuous at the limb; composited under the disc) ----
  float hr = max(r - 1.0, 0.0);
  vec3 d3 = vec3(p / max(r, 1e-4), 0.0);
  float ndlL = dot(d3, l);
  float dens = exp(-hr / 0.04);
  float tauH = tauAtm * 11.0 * dens * (1.0 + ng);
  vec3 halo = atmoCol * (1.0 - exp(-tauH)) * smoothstep(-0.3, 0.3, ndlL) * phase * 2.0 * atmoGain;
  float nightL = 1.0 - smoothstep(-0.2, 0.15, ndlL);
  halo += cB * 0.03 * th * dens * nightL;
  float qaK = th * 0.85 + uPulse * 0.8;
  float qa = (qaK > 0.001 && hr < 0.2) ? oc_aurora(rot * d3, t, 1.0 / uRadius) * qaK : 0.0;
  halo += mix(cB, toLinear(vec3(0.5, 0.6, 1.0)), smoothstep(0.0, 0.05, hr)) * qa * exp(-hr / 0.022) * (0.1 + 0.8 * nightL) * 0.55;
  halo += distressCol * pulseD * exp(-hr / 0.035) * 0.4;
  float ringR = 1.0 + (1.0 - uPulse) * 0.26;
  float rdp = (r - ringR) / (0.012 + 0.03 * (1.0 - uPulse));
  halo += cB * uPulse * exp(-rdp * rdp) * 0.6 * smoothstep(1.0, 1.02, r);

  vec3 dC = toGamma(tonemapACES(col));
  vec3 hC = toGamma(tonemapACES(halo));
  float hA = saturate(max(hC.r, max(hC.g, hC.b)));
  vec3 pm = dC * discA + hC * (1.0 - discA);
  float a = discA + hA * (1.0 - discA);
  pm = dither(frag, pm);
  fragColor = vec4(clamp(pm, vec3(0.0), vec3(a)), a);
}
