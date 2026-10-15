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
//
// FAMILY LOOK (common.glsl): lifeGrade on the lit crust (before emission), the
// shared forward-scatter haze/halo (hot sulphur haze), the shared aurora as a
// faint white-gold plasma arc (50 %, only above 60 px so the pole never reads
// as an olive ring), the limb shock ring for celebrations (the rivers still
// flash), the shared distress rim/halo and compositeDiscHalo. The limb glow is
// day-side weighted so a small volcanic world never reads as a second sun.
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
  // Small worlds keep more of their structure (thin veins, cooling
  // cracks) instead of melting into a glowing blob.
  float detail = saturate(max(uDetail, sqrt(max(uDetail, 0.0)) * 0.9));

  vec3 surf = toLinear(uColorA.rgb);
  vec3 glow = toLinear(uColorB.rgb);
  vec3 deep = toLinear(uColorC.rgb);
  vec3 ashC = toLinear(vec3(0.50, 0.48, 0.46));
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

  // --- shared family parameters (disc and halo use the same ones) -------------
  // Hot sulphur haze: thin and warm when thriving, grey ash smog when neglected.
  vec3 atmoCol = mix(mix(surf, glow, 0.45), vec3(1.0, 0.78, 0.5), 0.25);
  atmoCol = mix(atmoCol, ashC * 0.6, ng * 0.8);
  float phase = atmoPhase(l);
  float gain = 2.0 * haloGain(th, ng) * (1.0 + 0.5 * uPulse);
  float tau0 = 0.03 * (1.0 + 1.2 * ng);
  float pulseD = distressPulse(t) * ng;
  // Aurora: Body's is a CELEBRATION plasma — white-gold arcs over the poles
  // while uPulse is high (at most 50 % of the family strength),
  // only a whisper when merely thriving (a dim gold curtain over the dark sky
  // read as an olive/grey plate), and only on planets > ~60 px.
  float auK = (th * 0.2 + uPulse * 1.1) * 0.5 * smoothstep(55.0, 75.0, uRadius);
  // Cheap conservative pre-test (ray through p cannot reach the auroral cone
  // |X·axis| = c|X| inside the curtain shell) skips most of the disc.
  vec3 auAxis = vec3(0.0, 1.0, 0.0) * rot;
  float auReach = abs(dot(p, auAxis.xy)) + abs(auAxis.z) * sqrt(max((1.0 + AURORA_H) * (1.0 + AURORA_H) - r * r, 0.0));
  vec2 au = (auK > 0.001 && auReach > 0.9 - 0.04) ? auroraCurtains(p, rot, l, 0.9, t, px) * auK : vec2(0.0);
  vec3 auBase = mix(glow, vec3(1.0, 0.78, 0.4), 0.6);      // white-gold plasma foot
  vec3 auTop = mix(glow, vec3(1.0, 0.55, 0.15), 0.5);       // deeper amber top
  vec3 auC = mix(auBase, auTop, saturate(au.y / max(au.x, 1e-4) * 2.0)) * au.x * 0.22;

  float discA = discMask(p, uRadius);
  vec3 col = vec3(0.0);

  if (r < 1.0 + 2.0 * px) {
    vec2 pc = p / max(r, 1.0) * 0.9999;
    vec3 n = sphereNormal(pc);
    vec3 q = rot * n;
    vec3 qs = q + vec3(uSeed * 1.37, uSeed * 0.71, -uSeed);
    vec3 lo = rot * l;   // light in planet frame

    // --- river network ---------------------------------------------------------
    // Rivers follow the median contour of a warped fbm (long, winding,
    // connected channels); tributaries are distance-estimated contours of a
    // finer field that only ignite near a main channel; fine cooling cracks
    // are cellular (voronoi) plate edges that open in patches.
    float warp = fbm3lo(qs * 1.25 + vec3(0.0, t * 0.004, t * 0.002));
    vec3 wq = qs * 1.8 + (warp - 0.5) * vec3(2.0, 1.6, 2.0);
    float v1 = fbm3lo(wq);
    float major = 1.0 - abs(v1 * 2.0 - 1.0);
    float wide = smoothstep(0.5, 0.85, noise3(qs * 2.1 + 9.0));
    // Pixel footprint on the surface (planet radii) for band-limiting.
    float pxq = px / max(n.z, 0.2);
    float wM0 = mix(0.045, 0.13, wide) * mix(0.9, 1.3, th);   // thriving rivers swell
    // ≥ ~1 px wide channels, but never wider than 0.1 in contour space: the
    // lava keeps to ≈ 30 % of the surface at any size (a small world shows
    // thin glowing veins on near-black crust, not a molten yellow ball).
    float wMpx = max(wM0, pxq * 6.5);
    float wM = min(wMpx, 0.085);
    // Widened channels keep most of their energy but not all of it.
    float lodE = pow(wM0 / wMpx, 0.7);
    float coreM = smoothstep(1.0 - wM, 1.0 - wM * 0.3, major);
    float bank = smoothstep(1.0 - wM * 2.6, 1.0 - wM * 0.5, major);
    // Tributaries: |v2 - 0.5| / |grad v2| is the distance to the contour, so the
    // line has a constant width, and the tiny closed loops that value noise
    // draws around its extrema (where the gradient vanishes) fade out instead
    // of reading as procedural 'O' rings.
    float tribBand = smoothstep(1.0 - wM * 6.0, 1.0 - wM * 1.5, major) * smoothstep(0.03, 0.012, pxq);
    float trib = 0.0;
    if (tribBand > 0.001) {
      vec3 tq = wq * 3.4 + 5.1;
      float v2 = noise3(tq);
      vec3 e1 = normalize(cross(q, vec3(0.31, 0.93, 0.19)));
      vec3 e2 = cross(q, e1);
      const float EPS = 0.06;
      vec2 g2 = vec2(noise3(tq + e1 * EPS), noise3(tq + e2 * EPS)) - v2;
      float gl = length(g2) / EPS * 3.4 * 1.8;            // |grad| per planet radius
      float dT = abs(v2 - 0.5) / max(gl, 1e-3);           // planet radii to the contour
      float tw = max(0.0045, pxq * 0.9);
      trib = (1.0 - smoothstep(tw * 0.35, tw, dT)) * smoothstep(3.0, 7.0, gl) * tribBand;
    }
    float fine = 0.0;
    if (detail > 0.3 && ng < 0.7) {
      // Hot cooling cracks (thriving/steady crust; a neglected world shows the
      // dull-red dying fissures below instead — never both voronoi passes).
      // Cracks open in patches: the patch mask is evaluated first so the
      // 27-cell voronoi only runs where a crack can show
      float fineVis = smoothstep(0.009, 0.004, pxq) * (1.0 - bank) * smoothstep(0.5, 0.78, noise3(qs * 3.1 + 11.0))
                    * (1.0 - smoothstep(0.3, 0.7, ng));
      if (fineVis > 0.001) {
        const float FF = 7.0;
        vec2 vv = voronoi3(qs * FF + (warp - 0.5) * 1.5);
        float ed = (vv.y - vv.x) * 0.5 / FF;              // ≈ planet radii to the plate edge
        float cw = max(0.0022, pxq * 0.7);
        fine = (1.0 - smoothstep(cw * 0.3, cw, ed)) * fineVis * (0.55 + 0.45 * hash12(floor(vv.xy * 97.0)));
      }
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
    // Cooled basalt: dark, warm-brown iron-oxide plains, scorched levees.
    float plains = smoothstep(0.35, 0.7, warp);
    vec3 basalt = mix(vec3(0.014, 0.012, 0.0115), vec3(0.07, 0.054, 0.045), smoothstep(0.4, 0.95, crust));
    basalt *= 0.6 + 0.8 * grain;
    basalt = mix(basalt, basalt * vec3(1.35, 1.05, 0.9) + deep * 0.3, plains * 0.6);
    basalt = mix(basalt, deep * 0.4, chan * 0.7);       // scorched channel levees
    // Neglect: dusty, grey ash-covered crust.
    basalt = mix(basalt, ashC * (0.11 + 0.12 * crust) * (0.8 + 0.4 * grain), ng * 0.85);

    float ndl = dot(n, l);
    float diff = smoothstep(-0.12, 0.35, ndl) * saturate(ndl * 0.85 + 0.2);
    diff *= saturate(1.0 + relief * 0.9 * smoothstep(-0.1, 0.4, ndl) * (1.0 - chan * 0.7));
    vec3 hv = normalize(l + vec3(0.0, 0.0, 1.0));
    float gloss = pow(saturate(dot(n, hv)), 48.0) * smoothstep(0.0, 0.2, ndl);
    float fres = pow(1.0 - saturate(n.z), 5.0);
    float night = 1.0 - smoothstep(-0.25, 0.15, ndl);
    float dayside = smoothstep(-0.3, 0.4, ndl);

    // Glassy obsidian highlight (dulled by ash).
    // near-black crust: the light is in the rivers
    vec3 lit = basalt * diff * 1.5;
    lit += vec3(1.0, 0.88, 0.75) * gloss * (0.04 + 0.1 * grain) * saturate(1.0 + relief) * (1.0 - chan) * (1.0 - ng * 0.8);

    // Emission.
    vec3 emit = volHeat(T, surf, glow, deep) * saturate(T * 5.0);
    emit *= 0.8 + 0.55 * night;
    // Warm light spilling from the channels onto the surrounding crust.
    emit += surf * pow(smoothstep(1.0 - wM * 6.0, 1.0, major), 3.0) * hot * mix(0.02, 0.045, th) * (0.5 + night);
    emit += mix(glow, vec3(1.0, 0.72, 0.22), 0.5) * (fastWave * (coreM * 2.0 + trib * 0.8 + bank * 0.35) + fastBreath * coreM * 0.25);
    emit += mix(glow, vec3(1.0, 0.9, 0.7), 0.35) * vent * (1.2 + 1.8 * night);

    // Ash clouds (neglect) veil the rivers.
    if (ng > 0.001) {
      float ash = dustStorm(qs * 0.9, t);
      float ashCl = smoothstep(0.5, 0.85, fbm3lo(qs * 2.4 + vec3(t * 0.01, 0.0, t * 0.006) + warp));
      ash = saturate(ash * 0.8 + ashCl * 0.6) * ng;
      emit *= 1.0 - ash * 0.45;
      lit = mix(lit, ashC * 0.75 * (diff * 1.1 + 0.01), ash * 0.85);
    }

    // Shared living-state grade on the reflected light only (the rivers cool
    // on their own terms through `hot`).
    lit = lifeGrade(lit, th, ng);

    // Cracks: faint dull-red fissures in the dying crust.
    if (ng > 0.02) {
      float ck = cracks(qs * 1.7 + 3.0) * smoothstep(0.35, 0.9, ng) * smoothstep(0.015, 0.006, pxq);
      ck *= smoothstep(0.45, 0.7, warp);                 // fissures open in patches
      emit += surf * vec3(0.8, 0.25, 0.12) * ck * (0.012 + 0.035 * night) * (0.6 + 0.4 * distressPulse(t));
    }

    // Shared hot-haze atmosphere (continuous with the halo at the limb).
    vec3 T3;
    vec3 S = atmoHaze(n.z, ndl, atmoCol, tau0, vec3(0.8, 1.0, 1.25), gain, phase, T3);
    col = (lit + emit) * T3 + S;
    col += auC;

    // Warm limb glow from the incandescent crust: day-side weighted (the old
    // all-round rim made a 22–40 px world read as a small sun).
    col += mix(surf, glow, 0.3) * fres * hot * 0.06 * (0.25 + 0.75 * dayside) * (1.0 - ng * 0.7);

    // Distress (shared rim).
    col += distressColor() * distressRim(n.z, pulseD);
    // Celebration flourish: the river network flashes and the limb flares
    // (the shock ring itself is the shared limbShock in the halo).
    col += glow * uPulse * (pow(1.0 - saturate(n.z), 6.0) * 1.0 + (coreM + trib * 0.6) * 0.5);

    // Sparkles: embers winking on the hottest channels of thriving worlds.
    float sp = step(0.997, hash12(floor(frag * 0.7) + floor(t * 6.0) * 7.31)) * coreM * th * smoothstep(50.0, 120.0, uRadius);
    col += vec3(1.0, 0.9, 0.6) * sp * 2.0;
  }

  // --- halo (continuous across the limb, composited under the disc) ---------
  vec3 halo = atmoHalo(p, l, atmoCol, tau0, 0.035, gain, phase, px);
  float rh = max(r, 1.0);
  vec2 lpd = normalize(l.xy + 1e-4);
  float dayH = smoothstep(-0.4, 0.5, dot(pdir, lpd));
  // Heat plumes: flickering bands rising off the limb (mostly on the day side).
  float hr2 = 1.0 - smoothstep(1.0, 1.07, rh);
  if (hr2 > 0.0 && r > 1.0 - 2.0 * px) {
    float plume = noise3(vec3(pdir * 11.0, rh * 7.0 - t * 0.7)) * 0.6 + 0.4 * noise3(vec3(pdir * 29.0, rh * 13.0 - t * 1.3));
    halo += mix(surf, glow, 0.25) * hr2 * hr2 * (0.2 + 0.8 * plume) * hot * 0.12 * (0.25 + 0.75 * dayH) * (1.0 - ng * 0.7);
  }
  halo += auC;
  // Embers rising off the limb.
  float emberAmt = saturate(th + train * 0.6 + uPulse);
  if (emberAmt > 0.001 && r > 0.98) {
    float sizePx = clamp(uRadius * 0.008, 0.55, 1.6);
    float em = volEmbers(p, t, sizePx, px);
    halo += mix(glow, vec3(1.0, 0.85, 0.5), 0.4) * em * emberAmt * 1.8 * step(0.99, r) * smoothstep(20.0, 60.0, uRadius);
  }
  // Celebration: the shared limb shock ring (gold-white).
  halo += mix(glow, vec3(1.0, 0.9, 0.6), 0.4) * limbShock(r, uPulse, px) * 0.6;
  // Distress (shared halo).
  halo += distressColor() * distressHalo(r, pulseD, px);

  fragColor = compositeDiscHalo(col, discA, halo, frag);
}
