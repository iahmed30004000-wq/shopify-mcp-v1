#version 460 core
#include <flutter/runtime_effect.glsl>
#include "lib/common.glsl"

// WORK — "Industrial": a megastructure world of steel/basalt continents plated
// with grid districts, and dark oily seas. The NIGHT SIDE is the hero: one
// bright metropolis per country board, each radiating highway filaments into
// a sodium-amber street grid.
//   thriving : dense, bright lights; an equatorial ring-light with moving
//              traffic, two inclined traffic arcs, amber aurora, glints.
//   neglected: brown smog/haze, flickering & failing lights, rust bloom on the
//              steel, faint cracks, red distress pulse.
//
// uExtra: x = number of country boards (0..8) → that many metropolises
//         y = activity 0..1 → light density/brightness (0.6 is a good default)
//         z, w unused.
// haloFactor: 1.35 is enough (ring/arcs stay within r ≤ 1.31); 1.4 gives the
//             arcs' soft glow a little more room.
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

vec2 ind_cube(vec3 x, out float face) {
  vec3 a = abs(x);
  if (a.x >= a.y && a.x >= a.z) { face = x.x > 0.0 ? 0.0 : 1.0; return x.yz / a.x; }
  if (a.y >= a.z) { face = x.y > 0.0 ? 2.0 : 3.0; return x.xz / a.y; }
  face = x.z > 0.0 ? 4.0 : 5.0;
  return x.xy / a.z;
}

// City i of 8: Fibonacci latitudes visited in bit-reversed order so that any
// prefix (1..8 boards) is spread evenly over the globe.
vec3 ind_city(float i) {
  float br = i == 0.0 ? 0.0 : i == 1.0 ? 4.0 : i == 2.0 ? 2.0 : i == 3.0 ? 6.0 : i == 4.0 ? 1.0 : i == 5.0 ? 5.0 : i == 6.0 ? 3.0 : 7.0;
  float y = (1.0 - (br + 0.5) / 4.0) * 0.72;
  float rr = sqrt(1.0 - y * y);
  float phi = br * 2.39996 + uSeed * 1.9 + i * 0.37;
  return vec3(cos(phi) * rr, y, sin(phi) * rr);
}

// Road grid on a cube face: returns line coverage, energy-conserving when
// the lines get thinner than a pixel (px = pixel size in uv units).
float ind_grid(vec2 uv, float cells, float width, float px, out vec2 id) {
  vec2 g = uv * cells;
  id = floor(g);
  vec2 dd = 0.5 - abs(fract(g) - 0.5);
  float d = min(dd.x, dd.y) / cells;
  float w = max(width, px * 0.7);
  return (1.0 - smoothstep(0.0, w, d)) * (width / w);
}

// Amber aurora ribbon on the auroral ovals (object space, y = spin axis).
float ind_aurora(vec3 q, float t, float px) {
  vec2 dir = normalize(q.xz + 1e-4);
  float hemi = q.y > 0.0 ? 1.0 : -1.0;
  float wob = (noise3(vec3(dir * 1.7, t * 0.06 + hemi * 4.0)) - 0.5) * 0.06
            + (noise3(vec3(dir * 7.0, t * 0.15 + hemi * 2.0)) - 0.5) * 0.02;
  float d = abs(q.y) - (0.91 + wob);
  float wEq = max(0.004, px);
  float band = (d < 0.0 ? exp(-d * d / (wEq * wEq)) : exp(-d / max(0.005, px * 0.8))) * (0.004 / wEq);
  float rays = noise3(vec3(dir * 34.0, t * 0.3 + hemi * 3.0));
  float drift = smoothstep(0.25, 0.65, noise3(vec3(dir * 2.2 - t * 0.03, hemi * 9.0)));
  return band * (0.6 + 0.4 * rays) * (0.2 + 0.8 * drift);
}

// Orbital ring / traffic arc in a plane with unit normal nr (view space),
// radius R. Returns x = emission (traffic + ring light), y = sunlit sheen,
// z = 1 if the ring point is in front of the planet (or outside the disc).
vec3 ind_ring(vec2 p, vec3 nr, float R, float w0, float px, float t, float speed, float lanes, vec3 l) {
  float w = max(w0, px);
  float nz = abs(nr.z) < 0.02 ? (nr.z < 0.0 ? -0.02 : 0.02) : nr.z;
  float z = -(p.x * nr.x + p.y * nr.y) / nz;
  vec3 X = vec3(p, z);
  float rho = length(X);
  // screen-space width: the plane is foreshortened by |nz|
  float dr = (rho - R) * abs(nz) / max(abs(nz), 0.25);
  float band = exp(-dr * dr / (w * w));
  if (band < 0.002) return vec3(0.0);
  vec3 e1 = normalize(cross(nr, vec3(0.0, 0.0, 1.0)) + vec3(1e-4, 0.0, 0.0));
  vec3 e2 = cross(nr, e1);
  float ang = atan(dot(X, e2), dot(X, e1));
  float lane = fract(ang / TAU * lanes - t * speed);
  float lane2 = fract(ang / TAU * lanes * 0.61 + t * speed * 0.7 + 0.3);
  float packets = smoothstep(0.0, 0.02, lane) * (1.0 - smoothstep(0.02, 0.16, lane))
                + 0.6 * smoothstep(0.0, 0.015, lane2) * (1.0 - smoothstep(0.015, 0.1, lane2));
  // traffic arcs are partial: a lit segment sweeps around the orbit
  float seg = lanes < 8.0 ? smoothstep(0.1, 0.9, 0.5 + 0.5 * sin(ang + t * speed * 6.0 + lanes)) : 1.0;
  packets *= seg;
  // planet shadow on the ring
  float xl = dot(X, l);
  float shadow = (xl < 0.0 && length(X - l * xl) < 1.0) ? 0.0 : 1.0;
  float front = (length(p) > 1.0 || z > 0.0) ? 1.0 : 0.0;
  band *= w0 / w;
  return vec3(band * (0.3 * seg + packets * 1.6), band * shadow * (0.4 + 0.6 * seg), front);
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
  float fine = smoothstep(0.2, 0.45, uDetail);
  float boards = clamp(floor(uExtra.x + 0.5), 0.0, 8.0);
  float act = clamp(uExtra.y, 0.0, 1.0);

  vec3 cA = toLinear(uColorA.rgb);
  vec3 cB = toLinear(uColorB.rgb);
  vec3 cC = toLinear(uColorC.rgb);
  vec3 atmoCol = mix(toLinear(vec3(0.58, 0.7, 0.92)), cB, 0.18);
  atmoCol = mix(atmoCol, toLinear(vec3(0.55, 0.47, 0.36)), ng * 0.7);     // smoggy
  vec3 distressCol = toLinear(vec3(1.0, 0.2, 0.12));
  vec3 whiteHot = mix(cB, vec3(1.0, 0.95, 0.85), 0.6);
  float pulseD = distressPulse(t) * ng;

  float tilt = uSpin.y;
  mat3 rot = rotY(uSpin.x + t * 0.02) * rotX(tilt);
  float phase = 0.7 + 3.0 * pow(saturate(0.5 - 0.5 * l.z), 5.0);
  float atmoGain = mix(0.7, 1.0, live) * (1.0 + uPulse * 0.5);
  const float tauAtm = 0.013;

  // Orbital traffic: equatorial ring-light + two inclined arcs (thriving).
  float ringVis = smoothstep(0.5, 0.9, uScore) + uPulse * 0.6;
  vec3 axis = vec3(0.0, cos(tilt), -sin(tilt));          // planet spin axis in view space (q.y = dot(n, axis))
  vec3 ringE = vec3(0.0), ringS = vec3(0.0);
  vec3 ringFront = vec3(1.0);
  if (ringVis > 0.001 && r < 1.34) {
    float px = 0.9 / uRadius;
    vec3 n1 = axis;
    vec3 n2 = normalize(rotZ(0.5) * rotX(0.45) * axis);
    vec3 n3 = normalize(rotZ(-0.8) * rotX(-0.3) * axis);
    float arcs = smoothstep(30.0, 60.0, uRadius);        // inclined arcs only when there is room
    vec3 r1 = ind_ring(p, n1, 1.24, 0.008, px, t, 0.05, 9.0, l);
    vec3 r2 = arcs > 0.0 ? ind_ring(p, n2, 1.12, 0.006, px, t, -0.08, 6.0, l) * vec3(arcs, arcs, 1.0) : vec3(0.0, 0.0, 1.0);
    vec3 r3 = arcs > 0.0 ? ind_ring(p, n3, 1.31, 0.005, px, t, 0.035, 5.0, l) * vec3(arcs, arcs, 1.0) : vec3(0.0, 0.0, 1.0);
    ringFront = vec3(r1.z, r2.z, r3.z);
    ringE = vec3(r1.x * 1.1, r2.x * 0.6, r3.x * 0.45) * ringVis;
    ringS = vec3(r1.y, r2.y * 0.5, r3.y * 0.4) * ringVis;
  }
  vec3 ringCol = mix(cB, whiteHot, 0.3);
  vec3 sheenCol = mix(cA, vec3(1.0), 0.4) * 0.35;

  float discA = discMask(p, uRadius);
  vec3 col = vec3(0.0);

  if (discA > 0.0) {
    vec2 pd = p * min(1.0, 0.9995 / max(r, 1e-4));
    vec3 n = sphereNormal(pd);
    vec3 q = rot * n;
    vec3 x = q + uSeed * vec3(0.53, 0.29, 0.71);
    float mu = n.z;
    float ndl = dot(n, l);
    float pxObj = 1.0 / (uRadius * max(mu, 0.05));

    // ---- metropolises (up to 8) + highways linking them ----
    float cityCore = 0.0, citySprawl = 0.0, filaments = 0.0, highways = 0.0;
    float fw = max(0.0016, pxObj * 0.7);
    for (int i = 0; i < 8; i++) {
      float fi = float(i);
      if (fi < boards) {
        vec3 c = ind_city(fi);
        float cs = dot(q, c);
        float hsh = hash12(vec2(fi, 7.0 + uSeed));
        if (cs > 0.55) {
          float a2 = 2.0 * (1.0 - cs);                   // ≈ angle²
          float ang = sqrt(a2);
          cityCore += exp(-a2 / 0.0010) * (0.8 + 0.4 * hsh);
          citySprawl += exp(-a2 / 0.02) + 0.4 * exp(-a2 / 0.07);
          // radiating arterial filaments (constant width, curving, varied length)
          vec3 e1 = normalize(cross(c, vec3(0.0, 1.0, 0.0)) + vec3(0.0, 0.0, 1e-3));
          vec3 e2 = cross(c, e1);
          float th0 = atan(dot(q, e2), dot(q, e1));
          float k = 9.0 + floor(hsh * 5.0);
          float bend = (noise3(vec3(ang * 7.0, th0 * 2.0, fi * 3.0)) - 0.5) * 0.9 * smoothstep(0.0, 0.2, ang);
          float sid = floor((th0 + bend) * k / TAU + hsh);
          float rel = (fract((th0 + bend) * k / TAU + hsh) - 0.5) * TAU / k;
          float dist = ang * abs(sin(rel));
          float len = 0.1 + 0.25 * hash12(vec2(sid, fi));
          float str = 0.4 + 0.6 * hash12(vec2(fi, sid + 5.0));
          filaments += exp(-dist * dist / (fw * fw)) * (0.0016 / fw) * str * (1.0 - smoothstep(len * 0.2, len, ang)) * smoothstep(0.01, 0.04, ang);
        }
        // great-circle highway to the next metropolis
        if (fi + 1.0 < boards) {
          vec3 c2 = ind_city(fi + 1.0);
          vec3 gn = normalize(cross(c, c2));
          float gd = dot(q, gn);                          // distance to the great circle
          float inside = step(0.0, dot(cross(c, q), gn)) * step(0.0, dot(cross(q, c2), gn));
          highways += exp(-gd * gd / (fw * fw)) * (0.0016 / fw) * inside * step(0.0, dot(q, c + c2));
        }
      }
    }

    // ---- continents & seas ----
    float warp = fbm3lo(x * 1.2 + vec3(7.0, 1.0, 3.0));
    float hgt = fbm3(x * 1.35 + warp * 0.9) + citySprawl * 0.35 + cityCore * 0.2;
    float coastW = max(0.006, pxObj * 1.5);
    float land = smoothstep(0.46 - coastW, 0.46 + coastW, hgt);

    float face;
    vec2 uv = ind_cube(q, face);
    float pxUv = pxObj * 1.3;
    vec2 idA, idB;
    float roadA = ind_grid(uv, 14.0, 0.0028, pxUv, idA);
    float roadB = ind_grid(uv + 0.013, 56.0, 0.0011, pxUv, idB);
    float blk = hash12(idB + face * 17.0);
    float blkA = hash12(idA + face * 5.0 + 3.0);

    float resolveB = smoothstep(1.0, 3.5, 1.0 / (56.0 * pxUv));   // minor blocks resolvable?
    float resolveA = smoothstep(1.0, 3.5, 1.0 / (14.0 * pxUv));
    // Megastructure zones. Zone noise is sampled at the centre of the fine
    // block so zone borders follow the street grid (planned districts).
    vec2 cB0 = (idB + 0.5) / 56.0 - 0.013;
    vec3 cellP = normalize(face < 2.0 ? vec3(face < 1.0 ? 1.0 : -1.0, cB0) :
                           face < 4.0 ? vec3(cB0.x, face < 3.0 ? 1.0 : -1.0, cB0.y) :
                                        vec3(cB0, face < 5.0 ? 1.0 : -1.0));
    vec3 zq = mix(q, cellP, resolveB) + uSeed * vec3(0.53, 0.29, 0.71);
    float zoneN = noise3(zq * 3.0 + 11.0) * 0.75 + noise3(zq * 9.0 + 5.0) * 0.25;
    float distr = smoothstep(0.44, 0.56, zoneN + citySprawl * 0.3) * land;
    float heavy = smoothstep(0.52, 0.56, noise3(zq * 4.5 + 29.0));             // heavy-industry zones (dark)

    // ---- albedo ----
    vec3 basalt = mix(cC, cA, 0.14) * (0.75 + 0.45 * noise3(x * 6.0)) * (1.0 + (noise3(x * 23.0) - 0.5) * 0.3 * smoothstep(2.0, 5.0, 1.0 / (23.0 * pxObj)));
    float roof = mix(0.5, blk, resolveB);
    vec3 steel = cA * mix(0.78, 0.4, heavy) * (0.88 + 0.24 * roof);
    steel = mix(steel, cC * 1.5, step(0.9, roof) * resolveB * 0.4);           // dark rooftops / vents
    vec3 landCol = mix(basalt, steel, distr);
    landCol *= 1.0 - roadB * 0.55 * distr;
    landCol = mix(landCol, cA * 1.1, roadA * 0.6 * distr);                     // bright concrete arterials
    vec3 sea = cC * 0.22;
    vec3 albedo = mix(sea, landCol, land);
    // polar ice shelves, steel-tinted

    // rust bloom on the steel (neglect)
    float rustM = ng > 0.001 ? smoothstep(0.4, 0.75, noise3(x * 5.0 + 3.0) * 0.8 + noise3(x * 19.0) * 0.2) * land : 0.0;
    vec3 rust = toLinear(vec3(0.42, 0.22, 0.12)) * (0.8 + 0.3 * roof);
    albedo = mix(albedo, rust, rustM * ng * 0.85);

    // ---- lighting ----
    float lam = saturate(ndl);
    float diff = lam * smoothstep(-0.05, 0.1, ndl + 0.03);
    vec3 sunCol = vec3(1.0, 0.95, 0.88) * mix(1.75, 1.4, ng);
    vec3 sky = atmoCol * 0.05 * smoothstep(-0.25, 0.4, ndl);
    vec3 lit = albedo * (sunCol * diff + sky);
    vec3 hv = normalize(l + vec3(0.0, 0.0, 1.0));
    float nh = saturate(dot(n, hv));
    float fres = pow(1.0 - saturate(mu), 5.0);
    // dark glossy seas: sharp sun glint + sky sheen; steel plates: broad metallic sheen
    float waves = mix(0.5, fine > 0.0 ? noise3(x * 70.0 + vec3(t * 0.2, 0.0, 0.0)) : 0.5, smoothstep(2.0, 5.0, 1.0 / (70.0 * pxObj)));
    float seaSpec = pow(nh, 400.0) * 0.8 * (0.5 + waves) + pow(nh, 60.0) * 0.04;
    lit += sunCol * seaSpec * (1.0 - land) * smoothstep(0.0, 0.15, ndl) * (1.0 - ng * 0.6);
    lit += atmoCol * fres * 0.06 * (1.0 - land) * smoothstep(-0.1, 0.3, ndl);
    float plateSpec = pow(nh, 22.0) * mix(0.1, 0.45, blk * resolveB) * distr * (1.0 - rustM * ng);
    lit += sunCol * cA * plateSpec * smoothstep(0.0, 0.2, ndl);

    // thin cloud decks / smog
    vec3 cq = x * vec3(2.4, 4.5, 2.4) + vec3(t * 0.012, 0.0, -t * 0.009) + warp;
    float cloudN = fbm3lo(cq);
    float cl = 0.0;
    float smog = ng * smoothstep(0.4, 0.8, cloudN * 0.8 + warp * 0.35) * 0.8;
    vec3 smogCol = toLinear(vec3(0.42, 0.38, 0.32));
    lit = mix(lit, smogCol * (sunCol * saturate(ndl * 0.9 + 0.12) + sky * 2.0), smog);
    lit = desaturate(lit, ng * 0.3) * (1.0 - ng * 0.2);

    // ---- night lights ----
    float nightVis = smoothstep(0.05, -0.25, ndl);
    float density = (0.15 + 0.85 * act) * mix(0.3, 1.0, live);
    float towns = smoothstep(0.45, 0.8, noise3(x * 6.0 + 3.0) * 0.7 + noise3(x * 17.0) * 0.3);
    float urban = land * (distr * (0.15 + 0.5 * towns) + citySprawl * (0.6 + 0.5 * noise3(x * 11.0)));
    float U = saturate(urban * density);
    float frag1 = smoothstep(0.35, 0.65, noise3(x * 26.0 + 8.0));               // streets lit in fragments
    float streets = roadA * smoothstep(0.2, 0.7, U) * (0.3 + 0.7 * frag1) * 1.1
                  + roadB * smoothstep(0.45, 0.95, U) * (0.4 + 0.6 * frag1) * 0.9;
    float blockOn = smoothstep(blk, blk + 0.05, U * 1.2);
    vec2 cellF = fract((uv + 0.013) * 56.0) - 0.5;
    float dotS = max(0.0014, pxUv * 0.6);
    float bd = length(cellF - (hash22(idB + face) - 0.5) * 0.5) / 56.0;
    float blockLight = exp(-bd * bd / (dotS * dotS)) * (0.0014 * 0.0014) / (dotS * dotS) * blockOn * (0.4 + hash12(idB * 1.7));
    // towns: a coarser layer of bright points that stays resolvable at mid scale
    vec2 tg = uv * 18.0 + 0.37;
    vec2 tid = floor(tg);
    vec2 th2 = hash22(tid + face * 3.3 + uSeed);
    float tOn = smoothstep(th2.x * 0.9, th2.x * 0.9 + 0.08, U);
    float tS = max(0.0022, pxUv * 0.7);
    float td = length(fract(tg) - 0.25 - 0.5 * th2) / 18.0;
    float resolveT = smoothstep(1.0, 3.0, 1.0 / (18.0 * pxUv));
    float townPt = exp(-td * td / (tS * tS)) * (0.0022 * 0.0022) / (tS * tS) * tOn * (0.5 + th2.y);
    townPt = mix(U * 0.12, townPt, resolveT);
    float haze = U * U * 0.18;                                                  // light pollution
    float lodPts = U * 0.14 * (0.6 + 0.8 * frag1);                              // average of the block points
    float grid = haze + townPt * 1.4 + mix(lodPts, blockLight * 1.4, resolveB) + mix(U * 0.06, streets, resolveA);
    // failing lights: whole districts drop out / flicker (neglect)
    float failKey = hash12(idA + face * 9.0 + floor(t * 5.0 + blkA * 7.0) * 0.01);
    float alive = 1.0 - ng * 0.85 * step(blkA, 0.75) * (0.6 + 0.4 * step(0.5, hash12(idA + floor(t * 7.0 + blkA * 13.0))));
    float cityLum = cityCore * 2.4 + filaments * 1.0 + highways * 0.8 * (0.35 + 0.65 * land);
    cityLum *= mix(0.3, 1.0, live) * (0.5 + 0.5 * act) * (1.0 - ng * 0.5 * step(0.5, failKey));
    vec3 lightsCol = cB * (grid * alive * 1.5 + cityLum) + whiteHot * cityCore * cityCore * 1.6 * mix(0.3, 1.0, live);
    lightsCol *= 1.0 + uPulse * 1.2;
    vec3 emit = lightsCol * nightVis * (1.0 - smog * 0.55);
    // day side: metropolis cores and furnace sparks still read (a working world)
    emit += cB * (cityCore * 0.1 + filaments * 0.03 + (townPt * 0.25 + blockLight * 0.12 * resolveB) * U) * (1.0 - nightVis) * live;

    // glints of glass towers on the day side (thriving)
    vec2 sg = floor(uv * 90.0);
    float sph = fract(t * 0.4 + hash12(sg + 3.0) * 9.0);
    float spk = step(0.993, hash12(sg + face * 7.0)) * smoothstep(0.0, 0.06, sph) * (1.0 - smoothstep(0.06, 0.25, sph));
    vec2 sf = fract(uv * 90.0) - 0.5;
    float ss = max(0.0012, pxUv * 0.6);
    spk *= exp(-dot(sf, sf) / (8100.0 * ss * ss)) * (0.0012 * 0.0012) / (ss * ss);
    emit += vec3(1.0, 0.96, 0.9) * spk * distr * (th + uPulse) * smoothstep(0.1, 0.5, ndl) * 3.0 * resolveB;

    // cracks (neglect): faint red fault lines, embers on the night side
    if (ng > 0.02) {
      vec2 v = voronoi3(x * 4.2 + noise3(x * 6.0) * 0.4);
      float ck = (1.0 - smoothstep(0.0, max(0.018, pxObj * 2.0), v.y - v.x)) * smoothstep(0.3, 0.8, ng);
      ck *= smoothstep(0.45, 0.7, noise3(x * 2.0 + 17.0)) * smoothstep(0.02, 0.008, pxObj);
      lit *= 1.0 - ck * 0.3;
      emit += distressCol * ck * (0.03 + 0.35 * (1.0 - smoothstep(-0.2, 0.1, ndl))) * (0.4 + 0.6 * pulseD) * 0.5;
    }

    // ---- ring shadow on the surface (ring-light casts a thin dark band) ----
    if (ringVis > 0.001) {
      float s = -dot(n, axis) / dot(l, axis);
      vec3 P = n + l * s;
      float rs = (length(P) - 1.24) / 0.012;
      lit *= 1.0 - 0.55 * exp(-rs * rs) * step(0.0, s) * smoothstep(0.0, 0.3, ndl) * min(ringVis, 1.0);
    }

    // ---- atmosphere ----
    float airmass = 1.0 / (max(mu, 0.0) + 0.1);
    float tau = tauAtm * airmass * (1.0 + ng * 1.5);
    vec3 T = exp(-tau * vec3(1.25, 1.0, 0.8));
    float sunAtm = smoothstep(-0.3, 0.3, ndl);
    vec3 S = atmoCol * (1.0 - exp(-tau)) * sunAtm * phase * 1.8 * atmoGain;
    float term = exp(-ndl * ndl / 0.02);
    lit *= mix(vec3(1.0), vec3(1.35, 0.85, 0.6), term * 0.6);
    col = (lit + emit) * T + S;
    // city light pollution glow at the night limb + amber aurora
    col += cB * (0.02 + 0.05 * act) * live * pow(1.0 - saturate(mu), 3.0) * nightVis;
    float auK = th * 0.8 + uPulse * 0.8;
    float au = auK > 0.001 ? ind_aurora(q, t, 1.0 / uRadius) * auK : 0.0;
    col += mix(cB, whiteHot, 0.2) * au * (0.06 + nightVis) / (saturate(mu) + 0.6) * 0.5;
    float fr3 = pow(1.0 - saturate(mu), 3.0);
    col += distressCol * fr3 * pulseD * 0.65;
    col += cB * uPulse * fr3 * fr3 * 1.1;
  }

  // ---- halo ----
  float hr = max(r - 1.0, 0.0);
  vec3 d3 = vec3(p / max(r, 1e-4), 0.0);
  float ndlL = dot(d3, l);
  float dens = exp(-hr / 0.035);
  float tauH = tauAtm * 11.0 * dens * (1.0 + ng * 1.5);
  vec3 halo = atmoCol * (1.0 - exp(-tauH)) * smoothstep(-0.3, 0.3, ndlL) * phase * 2.2 * atmoGain;
  float nightL = 1.0 - smoothstep(-0.2, 0.15, ndlL);
  halo += cB * (0.02 + 0.04 * act) * live * dens * nightL;
  float qaK = th * 0.8 + uPulse * 0.8;
  float qa = (qaK > 0.001 && hr < 0.2) ? ind_aurora(rot * d3, t, 1.0 / uRadius) * qaK : 0.0;
  halo += mix(cB, toLinear(vec3(1.0, 0.5, 0.3)), smoothstep(0.0, 0.05, hr)) * qa * exp(-hr / 0.022) * (0.1 + 0.8 * nightL) * 0.55;
  halo += distressCol * pulseD * exp(-hr / 0.035) * 0.4;
  float ringR = 1.0 + (1.0 - uPulse) * 0.26;
  float rdp = (r - ringR) / (0.012 + 0.03 * (1.0 - uPulse));
  halo += cB * uPulse * exp(-rdp * rdp) * 0.6 * smoothstep(1.0, 1.02, r);

  // ---- orbital rings: front parts over the disc; everything outside the disc in the halo ----
  float fE = dot(ringE, ringFront);
  float fS = dot(ringS, ringFront);
  col += ringCol * fE + sheenCol * fS;
  halo += (ringCol * (ringE.x + ringE.y + ringE.z) + sheenCol * (ringS.x + ringS.y + ringS.z)) * step(1.0, r);

  vec3 dC = toGamma(tonemapACES(col));
  vec3 hC = toGamma(tonemapACES(halo));
  float hA = saturate(max(hC.r, max(hC.g, hC.b)));
  vec3 pm = dC * discA + hC * (1.0 - discA);
  float a = discA + hA * (1.0 - discA);
  pm = dither(frag, pm);
  fragColor = vec4(clamp(pm, vec3(0.0), vec3(a)), a);
}
