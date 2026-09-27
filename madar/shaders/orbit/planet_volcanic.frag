#version 460 core
#include <flutter/runtime_effect.glsl>
#include "lib/common.glsl"

// ---------------------------------------------------------------------------
// BODY — a volcanic world. Dark cooled basalt crust split by a branching
// network of glowing ENERGY RIVERS (warped ridged noise → emissive lava that
// flows in slow hot pulses), forge-vents along the rivers, heat shimmer and
// rising embers on the limb, golden polar aurora.
//
// Living state (uScore): thriving = incandescent orange-gold rivers, ember
// sparks, aurora; steady = warm orange rivers; neglected = rivers cooled to a
// dull dark red, dusty grey crust, ash clouds, faint cracks, distress pulse.
//
// uExtra.x  fasting in progress (0/1, may be animated 0→1) → a slow golden
//           wave travels through the river network (~4.5 s period).
// uExtra.y  today's training intensity 0..1 → hotter, brighter, faster rivers.
// uExtra.zw unused.
// uSpin.x spin angle, uSpin.y axial tilt (aurora poles follow the axis).
// haloFactor: 1.35 (embers/heat plumes stay inside 1.3 radii).
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

// Blackbody-like ramp through the palette. T: 0 (cold) … ~1.4 (white-hot).
vec3 volHeat(float T, vec3 surf, vec3 glow, vec3 deep) {
  vec3 c = mix(vec3(0.0), deep * 3.0 + vec3(0.05, 0.004, 0.0), smoothstep(0.0, 0.22, T));
  c = mix(c, surf * 0.9, smoothstep(0.18, 0.55, T));
  c = mix(c, glow, smoothstep(0.5, 0.88, T));
  c = mix(c, vec3(1.0, 0.9, 0.7), smoothstep(0.9, 1.4, T));
  return c * (0.35 + T * T * 1.6);
}

// Polar aurora: analytic curtain sheets. Each hemisphere's auroral oval is a
// cone of half-angle colat0 about the pole axis As (view space); the curtain
// is that cone extruded from the ground to height H with an exponential
// emission profile. For the orthographic view ray through p we solve where
// it pierces the cone, f(z) = dot(P, As)/|P| = cos(colat0), P = (p, z)
// (a quadratic), and integrate the emission across the sheet thickness
// (path ∝ 1/|f'(z)|, capped). Curtains therefore lean out over the limb and
// stand up correctly at any tilt; the ground term keeps the footprint visible
// when looking straight down the sheet. Returns rgb emission.
vec3 volCurtain(vec2 p, float r, vec3 As, mat3 rot, float t, float px, float hemi, vec3 cLow, vec3 cHigh) {
  const float H = 0.085;
  const float Hs = 0.03;
  float R1 = 1.0 + H;
  float zt2 = R1 * R1 - r * r;
  if (zt2 <= 0.0) return vec3(0.0);
  float z1 = sqrt(zt2);
  float z0 = r < 1.0 ? sqrt(1.0 - r * r) : -z1;
  // Reference direction (ground point or limb tangent point) for the wobble.
  vec3 dref = r < 1.0 ? vec3(p, z0) : vec3(p / r, 0.0);
  float cref = dot(dref, As);
  if (cref < 0.72) return vec3(0.0);                 // far from this pole
  vec3 qr = rot * dref;
  vec2 dir = normalize(qr.xz + 1e-4);
  float wob = noise3(vec3(dir * 2.5, t * 0.05 + hemi)) - 0.5;
  float fold = noise3(vec3(dir * 11.0, t * 0.2 + hemi)) - 0.5;
  float colat0 = 0.36 + wob * 0.12 + fold * 0.02;
  // Arcs brighten and break along the oval (substorm structure).
  float arcs = smoothstep(0.2, 0.75, noise3(vec3(dir * 3.2, t * 0.07 + hemi + 2.0)));
  float c = cos(colat0);
  float delta = sin(colat0) * max(0.014, px * 1.5);
  float a = dot(p, As.xy);
  float b = As.z;
  vec3 res = vec3(0.0);
  if (r < 1.0) {
    float gd = (cref - c) / delta;
    float rays = 0.35 + 0.65 * noise3(vec3(dir * 37.0, t * 0.45 + hemi));
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
        float dz = min(delta / max(fp, 1e-4), Hs * 1.1);
        float g = exp(-h / Hs) * (1.0 - smoothstep(H * 0.55, H, h));
        vec3 q = rot * (vec3(p, z) / L);
        vec2 hd = normalize(q.xz + 1e-4);
        float rays = 0.3 + 0.7 * noise3(vec3(hd * 37.0, t * 0.45 + hemi));
        res = max(res, mix(cLow, cHigh, smoothstep(0.0, H * 0.8, h)) * g * dz * rays * (0.3 + 0.7 * arcs));
      }
    }
  }
  return res;
}
vec3 volAurora(vec2 p, float r, mat3 rot, float t, float px, vec3 cLow, vec3 cHigh) {
  vec3 A = vec3(0.0, 1.0, 0.0) * rot;                // planet north axis, view space
  float lodE = 0.014 / max(0.014, px * 1.5);         // widened when tiny: keep energy
  lodE *= lodE;
  return (volCurtain(p, r, A, rot, t, px, 5.0, cLow, cHigh) + volCurtain(p, r, -A, rot, t, px, 0.0, cLow, cHigh)) * (lodE / 0.03);
}

// Ember sparks rising off the limb (screen space, polar cells).
float volEmbers(vec2 p, float t, float sizePx, float px) {
  float a = atan(p.y, p.x);
  float e = 0.0;
  for (int k = 0; k < 2; k++) {
    float cells = k == 0 ? 29.0 : 47.0;
    float u = (a / TAU + 0.5) * cells;
    float ci = floor(u);
    vec2 h = hash22(vec2(ci, float(k) * 17.0 + 3.0));
    float life = fract(t * (0.07 + h.x * 0.09) + h.y * 3.7);
    float er = 0.995 + life * life * (0.07 + h.y * 0.12);
    float ea = (ci + 0.3 + 0.4 * h.x + sin(t * 0.6 + h.y * 9.0) * 0.1) / cells;
    ea = (ea - 0.5) * TAU;
    vec2 ed = vec2(cos(ea), sin(ea));
    vec2 dv = (p - ed * er) / px;
    // Radially stretched sparks (motion streaks), flickering as they cool.
    float dpar = dot(dv, ed) / (1.0 + 2.5 * life);
    float dper = dv.x * ed.y - dv.y * ed.x;
    float size = sizePx * (0.7 + h.x * 0.6);
    float fade = smoothstep(0.0, 0.08, life) * (1.0 - life) * (1.0 - life);
    fade *= 0.6 + 0.4 * sin(t * 13.0 + h.x * 40.0);
    e += exp(-(dpar * dpar + dper * dper) / (size * size)) * fade * step(0.55, h.y);
  }
  return e;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 p = (frag - uCenter) / uRadius;
  p.y = -p.y;
  float r0 = length(p);
  float px = 1.0 / uRadius;
  float t = uTime;
  vec3 l = normalize(uLight);
  float th = thrive(uScore);
  float ng = neglect(uScore);
  float act = smoothstep(0.02, 1.0, uScore);
  float fasting = saturate(uExtra.x);
  float train = saturate(uExtra.y);
  float detail = saturate(uDetail);

  vec3 surf = toLinear(uColorA.rgb);
  vec3 glow = toLinear(uColorB.rgb);
  vec3 deep = toLinear(uColorC.rgb);
  vec3 ashC = toLinear(vec3(0.50, 0.48, 0.46));
  vec3 distressC = toLinear(vec3(1.0, 0.25, 0.18));
  float hot = 0.26 + 0.44 * act + 0.4 * th + train * 0.4 + uPulse * 0.25;

  // Heat shimmer: refractive radial wobble concentrated on the limb.
  vec2 pdir = p / max(r0, 1e-4);
  float limbBand = smoothstep(0.9, 1.0, r0) * (1.0 - smoothstep(1.0, 1.1, r0));
  if (limbBand > 0.0 && uRadius > 50.0) {
    float shim = noise3(vec3(p * 19.0 - pdir * t * 0.5, t * 0.9)) - 0.5;
    shim += (noise3(vec3(p * 47.0 - pdir * t * 1.1, t * 1.9)) - 0.5) * 0.5;
    p += pdir * shim * 0.009 * hot * limbBand * smoothstep(50.0, 140.0, uRadius);
  }
  float r = length(p);

  mat3 rot = rotY(uSpin.x + t * 0.03) * rotX(uSpin.y);
  vec3 col = vec3(0.0);

  if (r < 1.0 + 2.0 * px) {
    vec2 pc = p / max(r, 1.0) * 0.9999;
    vec3 n = sphereNormal(pc);
    vec3 q = rot * n;
    vec3 qs = q + vec3(uSeed * 1.37, uSeed * 0.71, -uSeed);
    vec3 lo = rot * l;   // light in planet frame

    // --- river network ---------------------------------------------------------
    // Rivers follow the median contour of a warped fbm (long, winding,
    // connected channels); tributaries are contours of a finer field that
    // only ignite near a main channel; fine cooling cracks web the plates.
    float warp = fbm3lo(qs * 1.25 + vec3(0.0, t * 0.004, t * 0.002));
    vec3 wq = qs * 1.8 + (warp - 0.5) * vec3(2.0, 1.6, 2.0);
    float v1 = fbm3lo(wq);
    float major = 1.0 - abs(v1 * 2.0 - 1.0);
    float wide = smoothstep(0.5, 0.85, noise3(qs * 2.1 + 9.0));
    // Pixel footprint on the surface (planet radii) for band-limiting.
    float pxq = px / max(n.z, 0.2);
    float wM0 = mix(0.045, 0.13, wide);
    float wM = max(wM0, pxq * 6.5);                      // ≥ ~1 px wide channels
    float lodE = sqrt(wM0 / wM);                         // keep energy readable when widened
    float coreM = smoothstep(1.0 - wM, 1.0 - wM * 0.3, major);
    float bank = smoothstep(1.0 - wM * 4.5, 1.0 - wM * 0.5, major);
    float v2 = noise3(wq * 3.4 + 5.1);
    float trib = smoothstep(0.93, 0.985, 1.0 - abs(v2 * 2.0 - 1.0)) * smoothstep(1.0 - wM * 7.0, 1.0 - wM * 1.5, major);
    trib *= smoothstep(0.02, 0.008, pxq);
    float fine = 0.0;
    if (detail > 0.3) {
      vec3 fq = qs * 8.0 + warp * 2.5 + 2.0;
      float v3 = noise3(fq) * 0.62 + noise3(fq * 2.4 + 7.0) * 0.38;   // irregular, few closed loops
      fine = smoothstep(0.91, 0.985, 1.0 - abs(v3 * 2.0 - 1.0)) * (1.0 - bank) * smoothstep(0.009, 0.004, pxq);
    }
    float chan = max(bank, trib);   // channel depression mask

    // Crust texture (cooled basalt) with relief toward the light.
    vec3 cq = qs * 6.0 + warp * 1.5;
    // Ridged transform → ropy pressure ridges of cooled pahoehoe.
    float crust = 1.0 - abs(fbm3lo(cq) * 2.0 - 1.0);
    float crustL = 1.0 - abs(fbm3lo(cq + lo * 0.2) * 2.0 - 1.0);
    float relief = clamp((crust - crustL) * 5.0, -1.0, 1.0);
    float grain = detail > 0.3 ? mix(0.5, noise3(qs * 31.0), smoothstep(0.012, 0.005, pxq)) : 0.5;
    // Crisp micro-relief (hero scale only): fine ropy ridges lit from the star.
    if (detail > 0.55) {
      vec3 mq = qs * 19.0 + warp * 3.0;
      float m0 = 1.0 - abs(noise3(mq) * 2.0 - 1.0);
      float m1 = 1.0 - abs(noise3(mq + lo * 0.35) * 2.0 - 1.0);
      relief = clamp(relief + (m0 - m1) * 2.2 * smoothstep(0.006, 0.0025, pxq), -1.0, 1.0);
    }

    // Flowing hot pulses travelling along the channels.
    float flowSpd = 0.7 + 0.9 * train + 0.4 * th;
    float flow = 0.5 + 0.5 * sin(warp * 52.0 + crust * 4.0 - t * flowSpd);
    flow = mix(flow, 0.5 + 0.5 * sin(warp * 27.0 - crust * 3.0 - t * flowSpd * 0.63 + 1.7), 0.4);

    // Temperature: brightens with the score and today's training.
    // Floating cooled skin on the lava (dark rafts drifting in the channels).
    float skin = detail > 0.3 ? smoothstep(0.55, 0.8, noise3(wq * 9.0 - vec3(t * 0.04, 0.0, t * 0.03))) : 0.0;
    float coreT = coreM * (1.0 - skin * 0.45 * (1.0 - wide * 0.5));
    float bankT = bank * bank;
    float T = (coreT * 1.0 + bankT * 0.16 + trib * (0.45 + 0.25 * th) + fine * (0.24 + 0.1 * th)) * hot * (0.7 + 0.45 * flow);
    T *= mix(0.85, 1.15, wide) * lodE;

    // Fasting: slow golden wave travelling through the network (~4.5 s).
    float wavePh = dot(q, normalize(vec3(0.3, 1.0, 0.2))) * 3.2 + warp * 5.0;
    float fastWave = pow(max(0.5 + 0.5 * sin(t * 1.4 - wavePh), 0.0), 6.0) * fasting;
    float fastBreath = (0.5 + 0.5 * sin(t * 1.4)) * fasting;

    // Forge vents (the world's "city lights"): bright points along rivers.
    vec3 vq = qs * 13.0;
    vec3 vc = floor(vq);
    vec3 vh = hash33(vc + 7.0);
    float vd = length(vq - vc - (0.3 + 0.4 * vh));
    float vent = exp(-vd * vd * 160.0) * step(0.62, vh.z) * smoothstep(0.45, 0.9, bank + trib) * smoothstep(0.012, 0.005, pxq);
    vent *= (0.55 + 0.45 * sin(t * (1.5 + vh.x * 2.0) + vh.y * 20.0)) * th;

    // --- surface shading -------------------------------------------------------
    float plains = smoothstep(0.35, 0.7, warp);
    vec3 basalt = mix(vec3(0.004, 0.0038, 0.004), vec3(0.027, 0.021, 0.018), smoothstep(0.45, 0.95, crust));
    basalt *= 0.6 + 0.8 * grain;
    basalt = mix(basalt, basalt * vec3(1.3, 1.08, 0.95) + deep * 0.25, plains * 0.5);
    basalt = mix(basalt, deep * 0.35, chan * 0.7);       // scorched channel levees
    // Neglect: dusty, grey ash-covered crust.
    basalt = mix(basalt, ashC * (0.045 + 0.08 * crust) * (0.8 + 0.4 * grain), ng * 0.8);

    float ndl = dot(n, l);
    float diff = smoothstep(-0.12, 0.35, ndl) * saturate(ndl * 0.85 + 0.2);
    diff *= saturate(1.0 + relief * 0.9 * smoothstep(-0.1, 0.4, ndl) * (1.0 - chan * 0.7));
    vec3 hv = normalize(l + vec3(0.0, 0.0, 1.0));
    float gloss = pow(saturate(dot(n, hv)), 48.0) * smoothstep(0.0, 0.2, ndl);
    float fres = pow(1.0 - saturate(n.z), 5.0);
    float night = 1.0 - smoothstep(-0.25, 0.15, ndl);

    // Glassy obsidian highlight (dulled by ash).
    vec3 lit = basalt * diff * 2.4;
    lit += vec3(1.0, 0.88, 0.75) * gloss * (0.04 + 0.1 * grain) * saturate(1.0 + relief) * (1.0 - chan) * (1.0 - ng * 0.8);

    // Emission.
    vec3 emit = volHeat(T, surf, glow, deep) * saturate(T * 5.0);
    emit *= 0.8 + 0.55 * night;
    // Warm light spilling from the channels onto the surrounding crust.
    emit += surf * pow(smoothstep(1.0 - wM * 8.0, 1.0, major), 3.0) * hot * 0.03 * (0.5 + night);
    emit += mix(glow, vec3(1.0, 0.72, 0.22), 0.5) * (fastWave * (coreM * 2.0 + trib * 0.8 + bank * 0.35) + fastBreath * coreM * 0.25);
    emit += mix(glow, vec3(1.0, 0.9, 0.7), 0.35) * vent * (1.2 + 1.8 * night);

    // Ash clouds (neglect) veil the rivers.
    if (ng > 0.001) {
      float ash = dustStorm(qs * 0.9, t);
      float ashCl = smoothstep(0.5, 0.85, fbm3lo(qs * 2.4 + vec3(t * 0.01, 0.0, t * 0.006) + warp));
      ash = saturate(ash * 0.8 + ashCl * 0.6) * ng;
      emit *= 1.0 - ash * 0.45;
      lit = mix(lit, ashC * 0.42 * (diff * 1.1 + 0.008), ash * 0.85);
    }

    col = lit + emit;

    // Cracks: faint dull-red fissures in the dying crust.
    if (ng > 0.02) {
      float ck = cracks(qs * 1.7 + 3.0) * smoothstep(0.35, 0.9, ng) * smoothstep(0.015, 0.006, pxq);
      ck *= smoothstep(0.45, 0.7, warp);                 // fissures open in patches
      col += surf * vec3(0.8, 0.25, 0.12) * ck * (0.012 + 0.035 * night) * (0.6 + 0.4 * distressPulse(t));
    }

    // Aurora (gold curtains over the poles, strongest on the night side).
    float aurAmt = smoothstep(0.15, 1.0, th);
    if (aurAmt > 0.001) {
      vec3 aur = volAurora(p, r, rot, t, px, mix(glow, vec3(1.0, 0.85, 0.4), 0.15), surf) * aurAmt;
      col += aur * (0.3 + 1.7 * night) * mix(0.4, 1.0, smoothstep(30.0, 90.0, uRadius));
    }

    // Hot haze atmosphere on the limb.
    vec3 hazeC = mix(mix(surf, glow, 0.35), ashC * 0.5, ng * 0.8);
    float hazeD = mix(0.2, 0.55, act) * (1.0 - ng * 0.3);
    col += atmosphere(pc, n, l, hazeC, hazeD, 0.15);
    col += mix(surf, glow, 0.3) * fres * hot * 0.12 * (1.0 - ng * 0.7);

    // Distress pulse (red rim) and celebration flare.
    col += distressC * fres * ng * distressPulse(t) * 1.2;
    // Celebration: rivers flash, a golden shock ring sweeps outward, rim flares.
    float ringR = (1.0 - uPulse) * 1.25;
    float shD = (r - ringR) / 0.07;
    float shock = exp(-shD * shD) * uPulse;
    col += glow * uPulse * (0.02 + fres * 1.3) + glow * (shock * 0.45 + uPulse * (coreM + trib * 0.6) * 0.5);

    // Sparkles: embers winking on the hottest channels of thriving worlds.
    float sp = step(0.997, hash12(floor(frag * 0.7) + floor(t * 6.0) * 7.31)) * coreM * th * smoothstep(50.0, 120.0, uRadius);
    col += vec3(1.0, 0.9, 0.6) * sp * 2.0;
  }

  // --- halo (continuous across the limb, composited under the disc) ---------
  // Skipped where the opaque disc fully covers it.
  vec3 halo = vec3(0.0);
  if (r > 1.0 - 2.0 * px) {
  float rh = max(r, 1.0);
  vec3 hazeC = mix(mix(surf, glow, 0.35), ashC * 0.5, ng * 0.8);
  float hazeD = mix(0.2, 0.55, act) * (1.0 - ng * 0.3);
  float hr = 1.0 - smoothstep(1.0, 1.15, rh);
  hr *= hr;
  vec2 lpd = normalize(l.xy + 1e-4);
  float dayside = saturate(dot(pdir, lpd) * 0.6 + 0.55);
  float back = pow(saturate(-l.z), 2.0) * saturate(dot(pdir, lpd) * 0.5 + 0.5);
  // Heat plumes: flickering bands rising off the limb.
  halo = hazeC * hazeD * hr * (dayside * 1.2 + back * 2.0 + 0.1);
  float hr2 = 1.0 - smoothstep(1.0, 1.07, rh);
  if (hr2 > 0.0) {
    float plume = noise3(vec3(pdir * 11.0, rh * 7.0 - t * 0.7)) * 0.6 + 0.4 * noise3(vec3(pdir * 29.0, rh * 13.0 - t * 1.3));
    halo += mix(surf, glow, 0.25) * hr2 * hr2 * (0.2 + 0.8 * plume) * hot * 0.22 * (1.0 - ng * 0.7);
  }
  // Aurora rising above the polar limb.
  float aurAmtH = smoothstep(0.15, 1.0, th);
  if (aurAmtH > 0.001 && r > 1.0) {
    halo += volAurora(p, r, rot, t, px, mix(glow, vec3(1.0, 0.85, 0.4), 0.15), surf) * aurAmtH * 1.6 * mix(0.4, 1.0, smoothstep(30.0, 90.0, uRadius));
  }
  // Embers rising off the limb.
  float emberAmt = saturate(th + train * 0.6 + uPulse);
  if (emberAmt > 0.001) {
    float sizePx = clamp(uRadius * 0.008, 0.55, 1.6);
    float em = volEmbers(p, t, sizePx, px);
    halo += mix(glow, vec3(1.0, 0.85, 0.5), 0.4) * em * emberAmt * 1.8 * step(0.99, r) * smoothstep(20.0, 60.0, uRadius);
  }
  halo += distressC * ng * distressPulse(t) * 0.5 * (1.0 - smoothstep(1.0, 1.1, rh));
  halo += glow * uPulse * 0.4 * hr;
  float shH = (rh - 1.0 - (1.0 - uPulse) * 0.25) / 0.03;
  halo += mix(glow, vec3(1.0, 0.9, 0.6), 0.4) * exp(-shH * shH) * uPulse * 0.5 * step(1.0, r);
  }

  float haloA = saturate(max(halo.r, max(halo.g, halo.b)) * 2.5);
  float discA = discMask(p, uRadius);
  vec3 discCol = toGamma(tonemapACES(col));
  vec3 haloCol = toGamma(tonemapACES(halo));
  vec3 pm = discCol * discA + haloCol * haloA * (1.0 - discA);
  float a = discA + haloA * (1.0 - discA);
  fragColor = vec4(dither(frag, pm), a);
}
