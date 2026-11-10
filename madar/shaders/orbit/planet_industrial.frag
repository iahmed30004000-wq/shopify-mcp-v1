#version 460 core
#include <flutter/runtime_effect.glsl>
#include "lib/common.glsl"

// WORK — "Industrial": a working megastructure world. Continents are plated
// with a steel-blue city fabric (mottled blocks of blue steel, concrete and a
// few bronze roofs, darker street canyons, polished-steel arterial traces),
// soot-dark heavy-industry quarters with furnaces, steam plumes drifting from
// the metropolises, basalt bedrock with dusty flats, and dark slate seas. The
// NIGHT SIDE is the hero: one bright metropolis per country board, each
// radiating highway filaments into a sodium-amber street grid. A sparse chain
// of orbital stations circles the equator (station lights + traffic packets,
// never a continuous hoop: the ring SILHOUETTE belongs to Travel).
//   thriving : the plating gleams (broad metallic sheen), furnaces glow and
//              steam rises, a faint sodium warmth over the districts, denser
//              halo (together with the shared thriveGrade: the 22 px day-side
//              cue), dense bright lights by night, station chain lit with
//              moving traffic, glass glints, amber aurora (shared curtains).
//   neglected: brown smog, flickering & failing lights, rust bloom on the
//              steel, faint cracks, dim and grey (shared neglectGrade), red
//              distress pulse (shared, in phase with every other world).
//
// Family pipeline (common.glsl): lit → lifeGrade → (lit+emit)·T + S (atmoHaze)
// → aurora / rims → halo = atmoHalo + aurora + limbShock + distress →
// compositeDiscHalo.
//
// Cost notes: the land block is skipped over the seas, the night-light block
// on the day side, the curtain call where no auroral oval can project, the
// city work outside 37° of each metropolis (filaments outside 0.36 rad,
// highways off their great circle); the next city is carried between loop
// iterations (one cos/sin pair per board); no inclined traffic arcs.
//
// Round 2 identity: never "blue camo" – the plating is DARK GUNMETAL with a
// visible panel grid (dark seams between plates at two scales, per-panel
// tone), the arterial traces are glowing TRENCH LINES (amber, lit by day
// too), the seas are dark oil-slate, and the orbital station chain shows
// from a steady world up (brighter stations).
//
// uExtra: x = number of country boards (0..8) → that many metropolises
//         y = activity 0..1 → light density/brightness (0.6 is a good default)
//         z, w unused.
// haloFactor: 1.35 is enough (station chain at r 1.24, aurora ≤ 1.12,
//             limb shock ring ≤ 1.30); 1.4 is fine too.
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
// prefix (1..8 boards) is spread evenly over the globe. Also returns the
// city's east tangent (analytic: normalize(cross(c, +y)) = (-sinφ, 0, cosφ)),
// so the per-pixel loop needs no cross/normalize for the local frame.
vec3 ind_city(float i, out vec3 east) {
  float br = i == 0.0 ? 0.0 : i == 1.0 ? 4.0 : i == 2.0 ? 2.0 : i == 3.0 ? 6.0 : i == 4.0 ? 1.0 : i == 5.0 ? 5.0 : i == 6.0 ? 3.0 : 7.0;
  float y = (1.0 - (br + 0.5) / 4.0) * 0.72;
  float rr = sqrt(1.0 - y * y);
  float phi = br * 2.39996 + uSeed * 1.9 + i * 0.37;
  float cp = cos(phi), sp = sin(phi);
  east = vec3(-sp, 0.0, cp);
  return vec3(cp * rr, y, sp * rr);
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

// 4-octave fbm for the continents (the 5th octave of fbm3 is below the
// coastline antialiasing even at the 220 px hero size; saves a tap).
float ind_fbm4(vec3 p) {
  float a = 0.5, s = 0.0;
  for (int i = 0; i < 4; i++) {
    s += a * noise3(p);
    p = p * 2.03 + vec3(1.7, 9.2, 3.1);
    a *= 0.5;
  }
  return s / 0.9375;
}

// Zone noise for the district plan. `cell` = centre of an arterial block in
// cube-face uv, blended toward the continuous surface point q by (1 - snap)
// so tiny planets keep smooth zones. x = district field (its fine octave is
// added by the caller from a shared tap), y = heavy industry.
vec2 ind_zone(vec2 cell, float face, vec3 q, float snap) {
  vec3 P = normalize(face < 2.0 ? vec3(face < 1.0 ? 1.0 : -1.0, cell) :
                     face < 4.0 ? vec3(cell.x, face < 3.0 ? 1.0 : -1.0, cell.y) :
                                  vec3(cell, face < 5.0 ? 1.0 : -1.0));
  vec3 zq = mix(q, P, snap) + uSeed * vec3(0.53, 0.29, 0.71);
  return vec2(noise3(zq * 3.2 + 11.0) * 0.55 + noise3(zq * 8.0 + 5.0) * 0.3 + 0.075,
              noise3(zq * 6.5 + 29.0));
}

// Equatorial station chain in the plane with unit normal nr (view space),
// radius R, in-plane basis e1/e2 (hoisted: computed once per fragment).
// Returns x = emission (station lights + moving traffic packets, a faint
// 0.05 thread between them), y = sunlit sheen of the station hulls, z = 1 if
// the point is in front of the planet (or outside the disc).
vec3 ind_ring(vec2 p, float r, vec3 nr, vec3 e1, vec3 e2, float R, float w0, float px, float t, vec3 l) {
  float w = max(w0, px);
  float anz = max(abs(nr.z), 0.02);
  // cheap reject before any per-point work: the projected ellipse spans |p| in [R|nz|, R]
  if (r > R + 4.0 * w || r < R * anz - 4.0 * w) return vec3(0.0, 0.0, 1.0);
  float nz = nr.z < 0.0 ? -anz : anz;
  float z = -(p.x * nr.x + p.y * nr.y) / nz;
  vec3 X = vec3(p, z);
  float rho = length(X);
  // screen-space width: the plane is foreshortened by |nz|
  float dr = (rho - R) * anz / max(anz, 0.25);
  float band = exp(-dr * dr / (w * w));
  if (band < 0.002) return vec3(0.0, 0.0, 1.0);
  float ang = atan(dot(X, e2), dot(X, e1));
  float a01 = ang / TAU + 0.5;
  // stations: 14 fixed slots, ~60 % occupied, each a small point light
  float sg = a01 * 14.0 + t * 0.004;
  float sid = floor(sg);
  float sh = hash12(vec2(sid, 11.0 + uSeed));
  float sOn = step(0.4, sh);
  float sd = (fract(sg) - 0.5) * TAU * R / 14.0;              // arc distance to the slot centre (radii)
  float sw = max(0.012, px * 1.1);
  float station = exp(-sd * sd / (sw * sw)) * (0.012 * 0.012) / (sw * sw) * sOn * (0.7 + 0.6 * fract(sh * 7.3));
  // traffic packets: short moving beads between the stations
  float lane = fract(a01 * 9.0 - t * 0.05);
  float lane2 = fract(a01 * 5.5 + t * 0.035 + 0.3);
  float packets = smoothstep(0.0, 0.01, lane) * (1.0 - smoothstep(0.01, 0.05, lane))
                + 0.6 * smoothstep(0.0, 0.01, lane2) * (1.0 - smoothstep(0.01, 0.04, lane2));
  // planet shadow on the chain
  float xl = dot(X, l);
  float shadow = (xl < 0.0 && length(X - l * xl) < 1.0) ? 0.0 : 1.0;
  float front = (r > 1.0 || z > 0.0) ? 1.0 : 0.0;
  band *= w0 / w;
  return vec3(band * (0.05 + packets * 0.8) + station * 1.6, station * shadow * 0.35, front);
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
  float fine = smoothstep(0.2, 0.45, uDetail);
  float boards = clamp(floor(uExtra.x + 0.5), 0.0, 8.0);
  float act = clamp(uExtra.y, 0.0, 1.0);

  vec3 cA = toLinear(uColorA.rgb);
  vec3 cB = toLinear(uColorB.rgb);
  vec3 cC = toLinear(uColorC.rgb);
  vec3 atmoCol = mix(toLinear(vec3(0.58, 0.7, 0.92)), cB, 0.18);
  atmoCol = mix(atmoCol, toLinear(vec3(0.55, 0.47, 0.36)), ng * 0.7);     // smoggy
  vec3 whiteHot = mix(cB, vec3(1.0, 0.95, 0.85), 0.6);
  float pulseD = distressPulse(t) * ng;

  float tilt = uSpin.y;
  mat3 rot = rotY(uSpin.x + t * 0.02) * rotX(tilt);
  // shared family atmosphere (same parameters for disc haze and halo)
  float phase = atmoPhase(l);
  float gain = 2.0 * haloGain(th, ng) * (1.0 + 0.5 * uPulse);
  float tau0 = 0.016 * (1.0 + 1.5 * ng);

  // shared family aurora (amber), evaluated once for disc and halo
  // Cheap conservative pre-test before the shared curtain call (skips its
  // noise taps where no oval can project): |X·axis| = c|X| needs
  // |axis.xy·p| + |axis.z|·(1+H) ≥ c.
  float auK = th * 0.9 + uPulse * 0.8;
  vec3 axisV = vec3(0.0, 1.0, 0.0) * rot;
  bool auNear = abs(dot(axisV.xy, p)) + abs(axisV.z) * (1.0 + AURORA_H) > 0.9 - 0.04;
  vec2 au = (auK > 0.001 && auNear) ? auroraCurtains(p, rot, l, 0.9, t, px) * auK : vec2(0.0);
  vec3 auBase = mix(cB, whiteHot, 0.2);
  vec3 auTop = toLinear(vec3(1.0, 0.62, 0.34));
  vec3 auC = mix(auBase, auTop, saturate(au.y / max(au.x, 1e-4) * 2.0)) * au.x * 0.13;

  // Orbital station chain (equatorial), lit when working.
  float ringVis = smoothstep(0.3, 0.8, uScore) + uPulse * 0.6;
  vec3 axis = vec3(0.0, cos(tilt), -sin(tilt));          // spin axis in view space (q.y = dot(n, axis))
  vec3 ring = vec3(0.0, 0.0, 1.0);
  if (ringVis > 0.001 && r < 1.34) {
    vec3 e1 = normalize(cross(axis, vec3(0.0, 0.0, 1.0)) + vec3(1e-4, 0.0, 0.0));
    vec3 e2 = cross(axis, e1);
    ring = ind_ring(p, r, axis, e1, e2, 1.24, 0.006, 0.9 * px, t, l);
    ring.xy *= ringVis;
  }
  vec3 ringCol = mix(cB, whiteHot, 0.35);
  vec3 sheenCol = mix(cA, vec3(1.0), 0.4);

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

    // ---- metropolises (up to 8) + highways linking them + steam plumes ----
    float cityCore = 0.0, citySprawl = 0.0, filaments = 0.0, highways = 0.0, plume = 0.0;
    float fw = max(0.0016, pxObj * 0.7);
    if (boards > 0.5) {
      vec3 east;
      vec3 c = ind_city(0.0, east);
      for (int i = 0; i < 8; i++) {
        float fi = float(i);
        if (fi < boards) {
          // next city computed once and carried to the next iteration (halves the trig)
          vec3 eastN = east;
          vec3 c2 = fi + 1.0 < boards ? ind_city(fi + 1.0, eastN) : c;
          float cs = dot(q, c);
          // tight early-outs: sprawl < 0.2 % beyond 37°, filaments end by 0.35 rad
          if (cs > 0.8) {
            float hsh = hash12(vec2(fi, 7.0 + uSeed));
            float a2 = 2.0 * (1.0 - cs);                   // ≈ angle²
            float ang = sqrt(a2);
            cityCore += exp(-a2 / 0.0010) * (0.8 + 0.4 * hsh);
            citySprawl += exp(-a2 / 0.02) + 0.4 * exp(-a2 / 0.07);
            // local frame (analytic east tangent; north = c × east)
            vec3 north = cross(c, east);
            float lu = dot(q, east), lv = dot(q, north);
            // radiating arterial filaments (constant width, curving, varied length)
            if (ang < 0.36) {
              float th0 = atan(lv, lu);
              float k = 9.0 + floor(hsh * 5.0);
              float bend = (noise3(vec3(ang * 7.0, th0 * 2.0, fi * 3.0)) - 0.5) * 0.9 * smoothstep(0.0, 0.2, ang);
              float sid = floor((th0 + bend) * k / TAU + hsh);
              float rel = (fract((th0 + bend) * k / TAU + hsh) - 0.5) * TAU / k;
              float dist = ang * abs(sin(rel));
              float len = 0.1 + 0.25 * hash12(vec2(sid, fi));
              float str = 0.4 + 0.6 * hash12(vec2(fi, sid + 5.0));
              filaments += exp(-dist * dist / (fw * fw)) * (0.0016 / fw) * str * (1.0 - smoothstep(len * 0.2, len, ang)) * smoothstep(0.01, 0.04, ang);
            }
            // steam / smoke plume drifting east from the metropolis core
            if (lu > -0.015) {
              float pu = lu + 0.015;
              float pw = 0.012 + 0.16 * pu;
              float pv = lv + sin(pu * 38.0 + fi * 2.7 + t * 0.4) * 0.012 * smoothstep(0.0, 0.1, pu);
              plume += exp(-pv * pv / (pw * pw)) * smoothstep(0.0, 0.03, pu) * (1.0 - smoothstep(0.06, 0.3, pu)) * (0.5 + 0.6 * hsh);
            }
          }
          // great-circle highway to the next metropolis
          if (fi + 1.0 < boards) {
            vec3 gn = normalize(cross(c, c2));
            float gd = dot(q, gn);                          // distance to the great circle
            if (abs(gd) < 4.0 * fw) {
              float inside = step(0.0, dot(cross(c, q), gn)) * step(0.0, dot(cross(q, c2), gn));
              highways += exp(-gd * gd / (fw * fw)) * (0.0016 / fw) * inside * step(0.0, dot(q, c + c2));
            }
          }
          c = c2;
          east = eastN;
        }
      }
    }

    // ---- continents & seas (land ≥ 55 %) ----
    float warp = fbm3lo(x * 1.2 + vec3(7.0, 1.0, 3.0));
    float hgt = (uDetail > 0.3 ? ind_fbm4(x * 1.35 + warp * 0.9) : fbm3lo(x * 1.35 + warp * 0.9))
              + citySprawl * 0.35 + cityCore * 0.2;
    float coastW = max(0.006, pxObj * 1.5);
    float land = smoothstep(0.40 - coastW, 0.40 + coastW, hgt);

    float face;
    vec2 uv = ind_cube(q, face);
    float pxUv = pxObj * 1.3;
    vec2 idA, idB;
    float roadA = ind_grid(uv, 14.0, 0.0028, pxUv, idA);
    float roadB = ind_grid(uv + 0.013, 56.0, 0.0011, pxUv, idB);
    float blk = hash12(idB + face * 17.0);
    float blkA = hash12(idA + face * 5.0 + 3.0);
    float resolveB = smoothstep(1.0, 3.5, 1.0 / (56.0 * pxUv));   // minor blocks resolvable? (lights)
    float resolveA = smoothstep(1.0, 3.5, 1.0 / (14.0 * pxUv));
    float blockPx = 1.0 / (14.0 * pxUv);                          // arterial block size in px
    float roofRes = smoothstep(2.5, 6.0, 1.0 / (56.0 * pxUv));    // fine blocks resolvable (albedo)
    // The road grid lives on cube faces: it fades out toward the face edges
    // (no seam where two grids meet) and only shows on the day side at a
    // high level of detail – at overview size it read as tiles.
    float faceEdge = max(abs(uv.x), abs(uv.y));
    float seamFade = 1.0 - smoothstep(0.82, 0.99, faceEdge);
    float gridLod = smoothstep(5.0, 12.0, blockPx) * seamFade;
    roofRes *= seamFade;
    float roof = mix(0.5, blk, roofRes);
    float nT6 = noise3(x * 6.0 + 3.0);                            // shared: bedrock tone + night towns
    float n11 = noise3(x * 11.0);                                 // shared: dust tone + urban lights

    // dark gunmetal plating (a cool metal, not a blue fabric)
    vec3 steel = mix(cA * vec3(0.34, 0.42, 0.52), vec3(0.075, 0.08, 0.09), 0.3);
    vec3 sea = mix(cC, cA, 0.18) * 0.42;
    vec3 albedo = sea;
    float distr = 0.0, heavy = 0.0, trace = 0.0;
    if (land > 0.001) {
      // Planned districts. Zone borders are ORGANIC (smooth noise, antialiased
      // by its own smoothstep) until an arterial block is a real on-screen
      // city block (≥ ~14 px, beyond the 220 px hero); only then is the zone
      // snapped to the arterial (14-cell) grid so districts end at a road,
      // antialiased by blending with the neighbouring block across the
      // nearest edge within one pixel. (Snapping at smaller blocks is what
      // read as a pixel mosaic.)
      float snap = smoothstep(14.0, 22.0, blockPx);
      float n24 = noise3(x * 24.0 + 7.0);                         // shared: zone fine octave + block-scale mottling
      vec2 zone = ind_zone((idA + 0.5) / 14.0, face, q, snap);
      if (snap > 0.001) {
        vec2 fA = fract(uv * 14.0) - 0.5;
        vec2 ddA = 0.5 - abs(fA);
        float nbW = snap * 0.5 * (1.0 - smoothstep(0.0, pxUv * 14.0, min(ddA.x, ddA.y)));
        if (nbW > 0.002) {
          vec2 stepA = ddA.x < ddA.y ? vec2(sign(fA.x), 0.0) : vec2(0.0, sign(fA.y));
          zone = mix(zone, ind_zone((idA + stepA + 0.5) / 14.0, face, q, snap), nbW);
        }
      }
      // sprawl edges fray block by block once the fine blocks are resolvable
      float builtK = zone.x + (n24 - 0.5) * 0.15 * (1.0 - snap) + citySprawl * 0.3 + (blk - 0.5) * 0.08 * roofRes;
      distr = smoothstep(0.34, 0.54, builtK) * land;
      heavy = smoothstep(0.6, 0.7, zone.y) * distr * mix(0.75, step(0.3, blk), roofRes);  // heavy industry (compact, speckled)

      // ---- albedo: Work is a STEEL-BLUE plated world. Districts are a
      //      mottled city fabric of blue steel plating with neutral concrete
      //      and a few bronze roofs (warm accents only at the block scale,
      //      so the 22 px average stays steel-blue, never pink or tan),
      //      darker street canyons, soot-dark heavy industry; basalt bedrock
      //      with dusty flats; deep slate seas. ----
      float plan = smoothstep(2.5, 6.0, blockPx) * seamFade;      // per-block tone once blocks are resolvable
      // mottling (city fabric and bedrock) from the district scale down to
      // the block scale; each octave fades out before it would alias
      float n9 = noise3(x * 9.0 + 2.0);
      float m1 = (n9 - 0.5) * smoothstep(2.0, 5.0, 1.0 / (9.0 * pxObj)) * 0.4;   // no large camo blotches
      float m2 = (n24 - 0.5) * smoothstep(2.5, 6.0, 1.0 / (24.0 * pxObj));
      vec3 basalt = mix(cC, cA, 0.4) * vec3(0.6, 0.85, 1.12) * (0.72 + 0.5 * nT6) * (1.0 + m1 * 0.4 + m2 * 0.45);
      vec3 dust = toLinear(vec3(0.46, 0.43, 0.39)) * (0.8 + 0.35 * n11) * (1.0 + m2 * 0.3);
      vec3 ground = mix(basalt, dust, smoothstep(0.52, 0.72, warp) * 0.4);
      float plateK = mix(0.5, blkA, plan);                        // per-block tone (city mottling)
      float mott = 1.0 + m1 * 0.5 + m2 * 0.45;
      vec3 concrete = toLinear(vec3(0.3, 0.32, 0.34));
      vec3 copper = toLinear(vec3(0.6, 0.44, 0.34));              // weathered copper / bronze roofs
      vec3 tar = cC * 3.0;
      // roof mix per fine block when resolved (steel 64 %, concrete 22 %,
      // bronze 4 %, tar 10 %), the same average when not
      float rS = step(roof, 0.64), rC = step(0.64, roof) * step(roof, 0.86), rO = step(0.86, roof) * step(roof, 0.9);
      vec3 avgRoof = steel * 0.64 + concrete * 0.22 + copper * 0.04 + tar * 0.1;
      vec3 roofCol = mix(avgRoof, steel * rS + concrete * rC + copper * rO + tar * (1.0 - rS - rC - rO), roofRes * 0.75);
      vec3 dcol = roofCol * (0.84 + 0.32 * plateK) * mott;
      vec3 soot = mix(toLinear(vec3(0.16, 0.17, 0.18)), toLinear(vec3(0.27, 0.23, 0.2)), saturate(0.2 + m1)) * (0.75 + 0.5 * roof);
      dcol = mix(dcol, soot, heavy * 0.85);
      vec3 landCol = mix(ground, dcol, distr);
      // minor streets are dark canyons; the arterials are bright polished-
      // steel TRACES broken into fragments (a circuit, not a graph-paper
      // lattice); they carry the amber light at night
      float frag0 = smoothstep(0.4, 0.62, n9);
      trace = roadA * frag0 * distr * (1.0 - heavy) * gridLod;
      landCol *= 1.0 - (mix(0.12, roadB, roofRes) * 0.45 * gridLod + roadA * (1.0 - frag0) * 0.3 * gridLod) * distr;
      // the panel grid: dark seams between the plates, over land and districts
      float seams = (roadA * 0.55 * resolveA + roadB * 0.3 * roofRes) * seamFade;
      landCol *= 1.0 - seams;
      landCol = mix(landCol, steel * 1.6, trace * 0.4);
      albedo = mix(sea, landCol, land);
    }

    // rust bloom on the steel (neglect)
    float rustM = ng > 0.001 ? smoothstep(0.4, 0.75, noise3(x * 5.0 + 3.0) * 0.8 + noise3(x * 19.0) * 0.2) * land : 0.0;
    vec3 rust = toLinear(vec3(0.42, 0.22, 0.12)) * (0.8 + 0.3 * roof);
    albedo = mix(albedo, rust, rustM * ng * 0.85);

    // ---- lighting ----
    float lam = saturate(ndl);
    float diff = lam * smoothstep(-0.05, 0.1, ndl + 0.03);
    vec3 sunCol = vec3(1.0, 0.95, 0.88) * 1.75;
    vec3 sky = atmoCol * 0.05 * smoothstep(-0.25, 0.4, ndl);
    vec3 lit = albedo * (sunCol * diff + sky);
    vec3 hv = normalize(l + vec3(0.0, 0.0, 1.0));
    float nh = saturate(dot(n, hv));
    float fres = pow(1.0 - saturate(mu), 5.0);
    // glossy seas: sharp sun glint + sky sheen; steel plates: broad metallic sheen
    float wavesK = smoothstep(2.0, 5.0, 1.0 / (70.0 * pxObj)) * step(0.001, fine) * (1.0 - land);
    float waves = wavesK > 0.001 ? mix(0.5, noise3(x * 70.0 + vec3(t * 0.2, 0.0, 0.0)), wavesK) : 0.5;
    float nh2 = nh * nh, nh4 = nh2 * nh2, nh8 = nh4 * nh4, nh16 = nh8 * nh8, nh64 = nh16 * nh16 * nh16 * nh16;
    float nh256 = nh64 * nh64 * nh64 * nh64;
    float seaSpec = nh256 * nh64 * 0.8 * (0.8 + 0.4 * waves) + nh64 * 0.04;
    lit += sunCol * seaSpec * (1.0 - land) * smoothstep(0.0, 0.15, ndl) * (1.0 - ng * 0.6);
    lit += atmoCol * fres * 0.06 * (1.0 - land) * smoothstep(-0.1, 0.3, ndl);
    // steel plating sheen: maintained plating gleams when the world is working
    // (broad, low-frequency: part of the 22 px thriving cue), dull when steady
    float plateSpec = (nh8 * nh4 * mix(0.06, 0.2, th) + nh16 * nh4 * mix(0.1, 0.45, blk * resolveB))
                    * distr * (1.0 - heavy * 0.6) * (1.0 - rustM * ng);
    lit += sunCol * cA * plateSpec * smoothstep(0.0, 0.2, ndl);

    // steam plumes (white when working) / smog (brown, neglect)
    vec3 cq = x * vec3(2.4, 4.5, 2.4) + vec3(t * 0.012, 0.0, -t * 0.009) + warp;
    float cloudN = (plume > 0.001 || ng > 0.001) ? fbm3lo(cq) : 0.5;
    float steam = saturate(plume * (0.55 + 0.6 * cloudN)) * (0.35 + 0.65 * act) * mix(0.35, 1.0, live);
    vec3 steamCol = mix(vec3(0.72, 0.72, 0.74), vec3(0.42, 0.36, 0.3), ng);
    float smog = ng * smoothstep(0.4, 0.8, cloudN * 0.8 + warp * 0.35) * 0.8;
    vec3 smogCol = toLinear(vec3(0.42, 0.38, 0.32));
    vec3 cloudLight = sunCol * saturate(ndl * 0.9 + 0.12) + sky * 2.0;
    lit = mix(lit, steamCol * cloudLight, steam * 0.75);
    lit = mix(lit, smogCol * cloudLight, smog);

    // cracks (neglect) darken the crust
    float ck = 0.0;
    if (ng > 0.02) {
      vec2 v = voronoi3(x * 4.2 + noise3(x * 6.0) * 0.4);
      ck = (1.0 - smoothstep(0.0, max(0.018, pxObj * 2.0), v.y - v.x)) * smoothstep(0.3, 0.8, ng);
      ck *= smoothstep(0.45, 0.7, noise3(x * 2.0 + 17.0)) * smoothstep(0.02, 0.008, pxObj);
      lit *= 1.0 - ck * 0.3;
    }

    float term = exp(-ndl * ndl / 0.02);
    lit *= mix(vec3(1.0), vec3(1.35, 0.85, 0.6), term * 0.6);
    // shared living-state grade: thriving richer/warmer, neglected dim & grey
    lit = lifeGrade(lit, th, ng);

    // ---- night lights (evaluated only where they can show) ----
    float nightVis = smoothstep(0.05, -0.25, ndl);
    float cityLum = cityCore * 2.4 + filaments * 1.0 + highways * 0.8 * (0.35 + 0.65 * land);
    cityLum *= mix(0.3, 1.0, live) * (0.5 + 0.5 * act);
    vec3 emit = vec3(0.0);
    if (nightVis > 0.001) {
      float density = (0.15 + 0.85 * act) * mix(0.3, 1.0, live);
      float towns = smoothstep(0.45, 0.8, nT6 * 0.7 + noise3(x * 17.0) * 0.3);
      float urban = land * (distr * (0.15 + 0.5 * towns) + citySprawl * (0.6 + 0.5 * n11));
      float U = saturate(urban * density);
      float frag1 = smoothstep(0.35, 0.65, noise3(x * 26.0 + 8.0));             // streets lit in fragments
      float streets = (roadA * smoothstep(0.2, 0.7, U) * (0.3 + 0.7 * frag1) * 1.1
                    + roadB * smoothstep(0.45, 0.95, U) * (0.4 + 0.6 * frag1) * 0.9) * seamFade;
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
      // clusters: a coarse layer of sharp light points (≥ ~1 px) that reads
      // as city lights even on a 25 px world – never a smeared amber glow
      vec3 cg = q * 9.0 + uSeed * 3.1;
      vec3 cid = floor(cg);
      vec3 ch = hash33(cid + 11.0);
      float cOn = smoothstep(ch.x * 0.75, ch.x * 0.75 + 0.1, U) * step(0.25, ch.y);
      float cS = max(0.012, pxObj * 0.6);
      float cd = length(fract(cg) - 0.2 - 0.6 * ch) / 9.0;
      float clusterPt = exp(-cd * cd / (cS * cS)) * min(1.0, (0.02 * 0.02) / (cS * cS) * 3.0) * cOn * (0.6 + 0.8 * ch.z);
      float haze = U * U * 0.08;                                                // light pollution
      float lodPts = U * 0.05 * (0.6 + 0.8 * frag1);                            // average of the block points
      float grid = haze + clusterPt * 1.3 + townPt * 1.2 * seamFade + mix(lodPts, blockLight * 1.4 * seamFade, resolveB) + mix(U * 0.03, streets, resolveA);
      // failing lights: whole districts drop out / flicker (neglect)
      float failKey = hash12(idA + face * 9.0 + floor(t * 5.0 + blkA * 7.0) * 0.01);
      float alive = 1.0 - ng * 0.85 * step(blkA, 0.75) * (0.6 + 0.4 * step(0.5, hash12(idA + floor(t * 7.0 + blkA * 13.0))));
      vec3 lightsCol = cB * (grid * alive * 1.5 + cityLum * (1.0 - ng * 0.5 * step(0.5, failKey)))
                     + whiteHot * cityCore * cityCore * 1.6 * mix(0.3, 1.0, live);
      emit = lightsCol * (1.0 + uPulse * 1.2) * nightVis * (1.0 - smog * 0.55) * (1.0 - steam * 0.4);
    }
    // day side: metropolis cores and arterial filaments still read (a working world)
    emit += cB * (cityCore * 0.03 + filaments * 0.01) * (1.0 - nightVis) * live;
    // glowing trench lines: the arterial traces and the highways burn amber
    // by day too (brighter at night), dim and flicker when neglected
    float trench = trace * 1.0 + highways * 0.35 * (0.35 + 0.65 * land);
    emit += cB * trench * mix(0.02, 0.09, live) * (1.0 + 2.5 * nightVis) * (1.0 - ng * 0.7);
    // furnaces in the heavy-industry quarters: a warm glow that reads by day
    // when the world is working (the low-frequency thriving cue), embers by night
    float hot = mix(0.3, smoothstep(0.62, 0.9, blk) * 2.0, roofRes);          // furnace blocks, averaged when tiny
    float furn = heavy > 0.001 ? heavy * hot * (0.55 + 0.45 * noise3(x * 14.0 + vec3(0.0, t * 0.15, 0.0))) * (0.3 + 0.7 * act) : 0.0;
    emit += toLinear(vec3(1.0, 0.52, 0.2)) * furn * mix(0.004, 0.03, th) * (1.0 + 5.0 * nightVis) * (1.0 - ng);
    // a working world: a faint sodium / glass warmth over the districts by day
    emit += cB * distr * (1.0 - heavy) * 0.006 * th * (0.4 + 0.6 * act) * (1.0 - nightVis);

    // glints of glass towers on the day side (thriving)
    float glintK = distr * (th + uPulse) * smoothstep(0.1, 0.5, ndl) * resolveB;
    if (glintK > 0.001) {
      vec2 sg = floor(uv * 90.0);
      float sph = fract(t * 0.4 + hash12(sg + 3.0) * 9.0);
      float spk = step(0.993, hash12(sg + face * 7.0)) * smoothstep(0.0, 0.06, sph) * (1.0 - smoothstep(0.06, 0.25, sph));
      vec2 sf = fract(uv * 90.0) - 0.5;
      float ss = max(0.0012, pxUv * 0.6);
      spk *= exp(-dot(sf, sf) / (8100.0 * ss * ss)) * (0.0012 * 0.0012) / (ss * ss);
      emit += vec3(1.0, 0.96, 0.9) * spk * glintK * 3.0;
    }

    // cracks (neglect): faint red fault lines, embers on the night side
    emit += distressColor() * ck * (0.03 + 0.35 * (1.0 - smoothstep(-0.2, 0.1, ndl))) * (0.4 + 0.6 * pulseD) * 0.5;

    // ---- atmosphere (shared family haze) ----
    vec3 T;
    vec3 S = atmoHaze(mu, ndl, atmoCol, tau0, vec3(1.25, 1.0, 0.8), gain, phase, T);
    col = (lit + emit) * T + S;
    // city light pollution glow at the night limb
    float fr3 = pow(1.0 - saturate(mu), 3.0);
    col += cB * (0.02 + 0.05 * act) * live * fr3 * nightVis;
    col += auC;
    col += distressColor() * distressRim(mu, pulseD);
    // celebration flourish: the whole limb flares amber
    col += cB * uPulse * fr3 * 0.45;
  }

  // ---- halo (shared family model) ----
  vec3 halo = atmoHalo(p, l, atmoCol, tau0, 0.035, gain, phase, px);
  float hr = max(r - 1.0, 0.0);
  float ndlL = dot(vec3(p / max(r, 1e-4), 0.0), l);
  float nightL = 1.0 - smoothstep(-0.2, 0.15, ndlL);
  halo += cB * (0.02 + 0.04 * act) * live * exp(-hr / max(0.035, 1.2 * px)) * nightL;   // city glow above the night limb
  halo += auC;
  halo += cB * limbShock(r, uPulse, px) * 0.6;
  halo += distressColor() * distressHalo(r, pulseD, px);

  // ---- station chain: front part over the disc, everything outside the disc in the halo ----
  vec3 ringL = ringCol * ring.x + sheenCol * ring.y;
  col += ringL * ring.z;
  halo += ringL * step(1.0, r);

  fragColor = compositeDiscHalo(col, discA, halo, frag);
}
