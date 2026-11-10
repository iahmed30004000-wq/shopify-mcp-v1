#version 460 core
#include <flutter/runtime_effect.glsl>
#include "lib/common.glsl"

// FAITH — a deep-gold world built like a mosque: its NORTH pole (tilted
// toward the viewer) is a ribbed golden dome with a crescent finial on a
// drum of arched windows (lit from within at night); below the drum the
// whole world is wrapped in ONE continuous interlaced 8-point girih
// (khatam stars chained tip-to-tip, inner rotated stars, octagon rosettes,
// corner stars) on a conformal grid – square cells that never seam, gently
// shrinking toward the dome – and the south pole carries a 16-fold medallion.
// Raised polished strapwork over hammered fields; enamel gems in the corner
// stars. On the NIGHT SIDE the engraved channels beside the strapwork and the
// gems glow like light through filigree.
//   thriving : bright, saturated polished gold, burnished apex medallions,
//              breathing inlay light, soft gold/amber aurora curtains, glints
//              running along the strap centre-lines.
//   neglected: tarnished bronze (the pattern stays readable), latitude dust
//              streaks, cracks through the gilding, dimming, ember distress.
//   night side: dark gold, the engraving glowing at ≤ 25 % (warm amber, not
//              a second, white material); the drum's windows glow.
//
// FAMILY LOOK (common.glsl): lifeGrade (thriveGrade + neglectGrade) on the lit
// metal, the shared forward-scatter haze/halo (density × haloGain), the shared
// soft aurora curtains (pale gold → amber-rose), the limb shock ring for
// uPulse, the shared distress rim/halo and compositeDiscHalo. Thriving also
// brightens the apex medallions and deepens the inlay breathing.
// Small sizes: ring bands are energy-conserving lines and the beads fade out
// before they alias (no dashed stripes at 22–36 px); unresolved inlay averages
// to a faint glow, never a khaki fill.
//
// Round 2: a real ONION DOME stands on the north pole (a ray-marched surface
// of revolution: drum, swelling bulb, ogee point, spire and crescent
// finial) and rises above the limb in silhouette – the world reads as a
// mosque at every size, not as a jar with a lid. Neglect TARNISHES
// the gold (darker, browner, verdigris in the hollows) instead of turning it
// into brown rock; the dome and the minarets keep their silhouette.
//
// uExtra: x = pattern density multiplier (0 → default 1; 0.7..1.6 sensible;
//             rounded to whole cells round the world)
//         y, z, w unused.
// haloFactor: 1.5 (the dome and its finial rise to ~1.45 R).
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

vec2 fa_rot(vec2 p, float a) { float c = cos(a), s = sin(a); return vec2(c * p.x - s * p.y, s * p.x + c * p.y); }
float fa_box(vec2 p, float r) { vec2 d = abs(p) - vec2(r); return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0); }
// 8-point star (khatam / Rub el Hizb) = union of two squares of half-size r.
float fa_star8(vec2 p, float r) { return min(fa_box(p, r), fa_box(fa_rot(p, 0.78539816), r)); }
// Regular octagon of apothem r.
float fa_oct(vec2 p, float r) {
  vec2 a = abs(p);
  return max(max(a.x, a.y), (a.x + a.y) * 0.70710678) - r;
}
vec3 fa_sat(vec3 c, float s) { return max(mix(vec3(luma(c)), c, s), 0.0); }

// Girih cell (p in [-0.5, 0.5]^2). Returns x = distance to the strapwork
// centre lines, y = region (0 field, 1 inner medallion, 2 corner gem),
// z = distance to the fine engraved lines.
vec3 fa_girih(vec2 p) {
  vec2 a = abs(p);
  // main khatam: rotated square's corners touch the edge midpoints, so the
  // stars chain tip-to-tip across cells into a continuous interlace
  float s1 = fa_star8(p, 0.3536);
  // inner star rotated 22.5° and an octagon rosette
  float s2 = fa_star8(fa_rot(p, 0.39269908), 0.19);
  float o1 = fa_oct(fa_rot(p, 0.39269908), 0.1);
  // corner stars shared by four cells
  float s3 = fa_star8(a - 0.5, 0.115);
  float strap = min(abs(s1), abs(s3));
  float fineL = min(abs(s2), abs(o1));
  // radial spokes joining the rosette to the inner star's re-entrant corners
  float ang = atan(p.y, p.x);
  float sector = (fract(ang / TAU * 8.0 + 0.5) - 0.5) * TAU / 8.0;
  float rr = length(p);
  float spoke = rr * abs(sin(sector));
  float region = s3 < 0.0 ? 2.0 : (s2 < 0.0 ? 1.0 : 0.0);
  return vec3(strap, region, fineL);
}

// 16-fold apex medallion around a pole. pp = polar-plane coords (radians from
// the pole, scaled so the medallion radius ≈ 0.5).
vec3 fa_medallion(vec2 pp) {
  float rr = length(pp);
  float ang = atan(pp.y, pp.x);
  float sector = (fract(ang / TAU * 16.0 + 0.5) - 0.5) * TAU / 16.0;
  vec2 w = vec2(cos(sector), abs(sin(sector))) * rr;       // folded wedge
  // {16/5} star lines: normal at 11.25°·5 from the tip direction
  float star = abs(dot(w, vec2(cos(1.2272), sin(1.2272))) - 0.34 * cos(1.2272));
  float ring1 = abs(rr - 0.46);
  float ring2 = abs(rr - 0.12);
  float petals = abs(rr - (0.2 + 0.07 * cos(sector * 16.0)));
  float strap = min(min(star, ring1), ring2);
  float fineL = min(petals, abs(rr - 0.05));
  float region = rr < 0.12 ? 1.0 : 0.0;
  return vec3(strap, region, fineL);
}

// Zones by latitude (object space, north = +y): girih below FA_GIRIH_TOP,
// a beaded border, the drum of arched windows, the ribbed dome, the finial.
#define FA_GIRIH_TOP 0.93   // ≈ 53°
#define FA_DRUM_TOP 1.14    // ≈ 65°
#define FA_FINIAL 1.49      // ≈ 85°
#define FA_SOUTH_CAP -0.92  // the south medallion below ≈ -53°

// Conformal (Mercator) girih: n square cells round the world in rows that
// chain continuously (no band seams); cells shrink gently with latitude.
// Returns the pattern sample; cell = cell id; `polar` = south medallion.
vec3 fa_pattern(vec3 q, float n, out vec2 cell, out float bandEdge, out float polar) {
  float lat = asin(clamp(q.y, -1.0, 1.0));
  float lon = atan(q.z, q.x);
  float merc = log(tan(PI * 0.25 + clamp(lat, -1.4, 1.4) * 0.5));
  vec2 uv = vec2(lon / TAU, merc / TAU) * n;
  vec2 ci = floor(uv);
  vec2 f = fract(uv) - 0.5;
  cell = ci;
  // distance to the girih zone's northern border (in cell units)
  float mercTop = log(tan(PI * 0.25 + FA_GIRIH_TOP * 0.5)) / TAU * n;
  bandEdge = mercTop - uv.y;
  vec3 g = fa_girih(f);
  // the south pole's 16-fold medallion
  float colat = PI * 0.5 + lat;                  // from the south pole
  float capR = PI * 0.5 + FA_SOUTH_CAP;
  polar = 1.0 - smoothstep(capR * 0.94, capR, colat);
  if (polar > 0.0) {
    vec2 pp = normalize(q.xz + 1e-5) * colat / capR * 0.5;
    g = mix(g, fa_medallion(pp), polar);
    cell = mix(cell, vec2(-99.0, 0.0), polar);
  }
  return g;
}

// The crown above the girih: x = strap (ribs, drum mouldings, finial),
// y = window mask (arched windows of the drum), z = zone (0 drum, 1 dome,
// 2 finial). Only called north of FA_GIRIH_TOP.
vec3 fa_crown(vec3 q, float aa) {
  float lat = asin(clamp(q.y, -1.0, 1.0));
  float lon = atan(q.z, q.x);
  if (lat < FA_DRUM_TOP) {
    // drum: 16 arched windows between two mouldings
    float y = (lat - FA_GIRIH_TOP) / (FA_DRUM_TOP - FA_GIRIH_TOP);   // 0..1 up the drum
    float x = fract(lon / TAU * 16.0) - 0.5;
    vec2 w = vec2(abs(x) * 1.0, y);
    float arch = max(w.x - 0.2, max(0.2 - w.y, w.y - 0.6));             // shaft
    float head = length(vec2(w.x, (w.y - 0.6) * 1.6)) - 0.2;              // round head
    float win = min(arch, head);
    float mask = 1.0 - smoothstep(-aa, aa, win);
    float mould = min(abs(y - 0.06), abs(y - 0.94)) * (FA_DRUM_TOP - FA_GIRIH_TOP) * 16.0 / TAU;
    return vec3(mould, mask, 0.0);
  }
  if (lat < FA_FINIAL) {
    // ribbed dome: 16 raised ribs converging on the finial
    float rib = abs(fract(lon / TAU * 16.0) - 0.5) * cos(lat) * 2.0;
    return vec3(rib, 0.0, 1.0);
  }
  // finial: a crescent on the pole
  float colat = PI * 0.5 - lat;
  vec2 pp = normalize(q.xz + 1e-5) * colat / (PI * 0.5 - FA_FINIAL);
  float crescent = max(length(pp) - 0.62, -(length(pp - vec2(0.22, 0.0)) - 0.5));
  return vec3(abs(crescent), crescent < 0.0 ? 1.0 : 0.0, 2.0);
}

// Conservative screen-space bound of the shared aurora curtains: every sheet
// point X = rho·(±c·A + s·w) (w ⟂ A, rho ∈ [1, 1+AURORA_H], c = ovalY ± 0.03)
// projects inside one of two flat ellipses around the projected ovals, so
// outside them auroraCurtains() returns exactly 0 and the call (1 noise tap +
// the quadratic, up to 7 taps) can be skipped with no visible change.
bool fa_auroraNear(vec2 p, mat3 rot, float ovalY, float px) {
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

// The onion dome standing on the north pole: a real surface of revolution
// (drum, bulb swelling past it, ogee tip, a spire with a crescent finial),
// ray-marched along the orthographic view ray near the pole, so it rises
// above the limb in silhouette whenever the pole nears it. Returns linear
// colour (rgb) and coverage (a) of the dome where it is in front of the
// world (p in planet radii, y up; A = the spin axis in view space).
#define FA_DOME_H 0.5
#define FA_DOME_W 0.33

// Dome radius at height s above the pole (radii); < 0 outside.
float fa_domeR(float s) {
  float u = s / FA_DOME_H;
  if (u < -0.1 || u > 1.3) return -1.0;
  if (u < 0.07) return FA_DOME_W * 0.6;                                   // drum
  if (u < 0.3) return FA_DOME_W * (0.6 + 0.4 * sin((u - 0.07) / 0.23 * 1.5707963));    // swell
  if (u < 1.0) {
    float x = (u - 0.3) / 0.7;
    // the round bulb, then a concave ogee drawn out into a point (an onion)
    float f = x < 0.62 ? sqrt(max(0.0, 1.0 - pow(x / 0.72, 2.0)))
                       : 0.508 * pow(1.0 - (x - 0.62) / 0.38, 2.4);
    return FA_DOME_W * max(f, 0.03);
  }
  return FA_DOME_W * 0.03 * (1.0 - smoothstep(1.2, 1.3, u));             // the spire
}

vec4 fa_dome(vec2 p, vec3 A, vec3 l, float px, vec3 gold, vec3 glowC, float th, float ng, float t) {
  // bounding test around the pole's projection
  vec2 P = A.xy;
  float reach = FA_DOME_H * 1.35 + FA_DOME_W + 0.05;
  if (length(p - P - A.xy * FA_DOME_H * 0.6) > reach) return vec4(0.0);
  float r2 = dot(p, p);
  float zs = r2 < 1.0 ? sqrt(1.0 - r2) : -9.0;              // the sphere's front surface
  // march the view ray (orthographic, toward -z) through the dome's box
  float z0 = A.z * (1.0 + FA_DOME_H * 1.3) + 0.35, z1 = A.z - 0.45;
  const int N = 20;
  float dz = (z0 - z1) / float(N);
  float zHit = -9.0;
  float prevIn = 0.0;
  for (int i = 0; i <= N; i++) {
    float z = z0 - dz * float(i);
    vec3 X = vec3(p, z);
    float h = dot(X, A);
    vec3 R = X - h * A;
    float rho = length(R);
    // height above the sphere under this point (so the drum meets the ground)
    float sGround = sqrt(max(0.0, 1.0 - rho * rho));
    float sHere = h - 1.0 + (1.0 - sGround);
    float dr = fa_domeR(sHere);
    if (dr > 0.0 && rho < dr && h > sGround - 0.02) {
      zHit = z;
      break;
    }
  }
  if (zHit < -8.0 || zHit < zs - 0.002) return vec4(0.0);
  // refine the hit
  float lo = zHit, hi = zHit + dz;
  for (int k = 0; k < 5; k++) {
    float z = 0.5 * (lo + hi);
    vec3 X = vec3(p, z);
    float h = dot(X, A);
    float rho = length(X - h * A);
    float sGround = sqrt(max(0.0, 1.0 - rho * rho));
    float dr = fa_domeR(h - 1.0 + (1.0 - sGround));
    if (dr > 0.0 && rho < dr) lo = z; else hi = z;
  }
  vec3 X = vec3(p, lo);
  float h = dot(X, A);
  vec3 R = X - h * A;
  float rho = max(length(R), 1e-4);
  vec3 e = R / rho;
  float sGround = sqrt(max(0.0, 1.0 - rho * rho));
  float s = h - 1.0 + (1.0 - sGround);
  float eps = 0.01;
  float slope = (fa_domeR(s + eps) - fa_domeR(s - eps)) / (2.0 * eps);
  vec3 n = normalize(e - slope * A);
  float u = s / FA_DOME_H;
  // 16 gilded ribs converging on the tip, a moulding at the drum's top
  vec3 b1 = normalize(cross(A, vec3(0.0, 0.0, 1.0)) + vec3(1e-4, 0.0, 0.0));
  vec3 b2 = cross(A, b1);
  float psi = atan(dot(e, b2), dot(e, b1));
  float ribPx = FA_DOME_W * TAU / 16.0 / max(px, 1e-4);
  float rib = (1.0 - smoothstep(0.03, 0.07, abs(fract(psi / TAU * 16.0) - 0.5))) * smoothstep(3.0, 7.0, ribPx) * step(0.08, u) * step(u, 1.0);
  float mould = (1.0 - smoothstep(0.0, 0.02 + px, abs(u - 0.08))) + (1.0 - smoothstep(0.0, 0.02 + px, abs(u - 0.02)));
  // crescent finial at the spire's top
  float fin = 0.0;
  {
    vec3 F = A * (1.0 + FA_DOME_H * 1.33);
    vec2 fp = (p - F.xy) / 0.06;
    fin = step(length(fp), 1.0) * step(0.78, length(fp - vec2(0.35, 0.2)));
  }
  // polished gold, lit by the core star
  float ndl = dot(n, l);
  vec3 hv = normalize(l + vec3(0.0, 0.0, 1.0));
  float spec = pow(saturate(dot(n, hv)), mix(90.0, 30.0, ng)) * mix(0.9, 0.35, ng);
  float fres = pow(1.0 - saturate(n.z), 3.0);
  vec3 albedo = gold * mix(1.05, 0.8, rib) * (1.0 - mould * 0.3);
  vec3 c = albedo * (saturate(ndl) * 1.25 + 0.06) + vec3(1.0, 0.9, 0.7) * spec * smoothstep(-0.05, 0.2, ndl);
  c += gold * fres * 0.25 * smoothstep(-0.3, 0.3, ndl);
  // the ribs glow faintly at night (a lit mosque), the finial catches light
  c += gold * vec3(1.5, 1.2, 0.8) * rib * 0.05 * smoothstep(0.1, -0.3, ndl) * mix(0.3, 1.0, th) * (1.0 - ng * 0.7);
  c = mix(c, glowC * 1.2, fin * 0.6);
  // antialiased silhouette against the sky (coverage from the depth gap)
  float cov = 1.0;
  if (zs < -1.0) {
    // in the halo: soften the outline by the lateral margin
    float dr = fa_domeR(s);
    cov = saturate((dr - rho) / max(px, 1e-4) + 0.5);
  }
  return vec4(c, max(cov, fin));
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

  vec3 goldIn = toLinear(uColorA.rgb);
  vec3 glowC = toLinear(uColorB.rgb);
  vec3 deep = toLinear(uColorC.rgb);
  // deeper, richer gold (more red/less green than the flat palette colour)
  // (targets ≈ sRGB 200,140,50 in the lit midtones after ACES)
  vec3 gold = goldIn * vec3(0.72, 0.42, 0.3);
  vec3 atmoCol = mix(glowC, goldIn, 0.5) * 0.8;
  atmoCol = mix(atmoCol, toLinear(vec3(0.58, 0.55, 0.48)), ng * 0.6);
  // aurora: pale warm gold base → amber-rose top (kept red-leaning: dim yellow reads olive)
  vec3 auBase = mix(glowC, vec3(1.0, 0.62, 0.32), 0.55);
  vec3 auTop = mix(glowC, toLinear(vec3(1.0, 0.6, 0.4)), 0.7);
  float pulseD = distressPulse(t) * ng;

  // The north pole (the dome) leans toward the viewer, on top.
  mat3 rot = rotY(uSpin.x + t * 0.03) * rotX(-(uSpin.y + 0.35));
  // shared atmosphere (thin warm haze)
  float phase = atmoPhase(l);
  float gain = 1.8 * haloGain(th, ng) * (1.0 + 0.5 * uPulse);
  float tau0 = 0.03 * (1.0 + 1.2 * ng);

  // shared aurora curtains, evaluated once for disc and halo
  // (oval just outside the apex medallion so the curtains never trace its rim;
  // faded at small radii where a 2 px arc would read as a selection ellipse)
  float auK = (th * 0.9 + uPulse * 0.8) * mix(0.35, 1.0, smoothstep(22.0, 60.0, uRadius));
  vec2 au = (auK > 0.001 && fa_auroraNear(p, rot, 0.86, px)) ? auroraCurtains(p, rot, l, 0.86, t, px) * auK : vec2(0.0);
  // only the dome's (northern) curtains: the southern oval would hang
  // under the world as two stray smudges
  vec3 axisV = vec3(0.0, 1.0, 0.0) * rot;
  au *= smoothstep(-0.15, 0.25, dot(p, normalize(axisV.xy + vec2(1e-5, 0.0))));
  vec3 auC = mix(auBase, auTop, saturate(au.y / max(au.x, 1e-4) * 2.0)) * au.x * 0.22;

  float discA = discMask(p, uRadius);
  vec3 col = vec3(0.0);

  if (discA > 0.0) {
    vec2 pd = p * min(1.0, 0.9995 / max(r, 1e-4));
    vec3 n = sphereNormal(pd);
    vec3 q = rot * n;
    vec3 ql = rot * l;
    float mu = n.z;
    float ndl = dot(n, l);

    float nCells = max(8.0, floor(16.0 * (uExtra.x > 0.0 ? uExtra.x : 1.0) + 0.5));
    float bands = nCells * 0.5;                             // (bead / glint frequencies)
    float latQ = asin(clamp(q.y, -1.0, 1.0));
    float cellPx = uRadius * TAU / nCells * cos(latQ) * max(mu, 0.05);   // cell size on screen
    float aa = 1.0 / cellPx;                                // one pixel in cell units
    float resolve = smoothstep(9.0, 22.0, cellPx);          // can we draw the fine lines?
    float ringLod = smoothstep(4.0, 10.0, cellPx);          // ring bands / beads fade before they alias

    vec2 cell;
    float bandEdge, polar;
    vec3 g = fa_pattern(q, nCells, cell, bandEdge, polar);

    // Light direction in the local (east, north) frame → bevel of raised straps.
    vec3 east = normalize(vec3(-q.z, 0.0, q.x) + vec3(1e-4, 0.0, 0.0));
    vec3 north = cross(q, east);
    vec2 ld = vec2(dot(ql, east), dot(ql, north));
    float ldl = length(ld);
    vec2 dcell;
    float be2, pol2;
    vec3 g2 = g;
    if (cellPx > 6.0) {   // bevel only when the straps are resolvable (saves a 2nd pattern evaluation)
      g2 = fa_pattern(normalize(q + (east * ld.x + north * ld.y) / max(ldl, 1e-4) * (TAU / nCells) * cos(latQ) * 0.03), nCells, dcell, be2, pol2);
    }

    // Strap profile: raised flat-topped band with bevelled edges.
    float sw = 0.032;
    float strap = 1.0 - smoothstep(sw - aa, sw + aa, g.x);
    float strap2 = 1.0 - smoothstep(sw - aa, sw + aa, g2.x);
    float groove = (1.0 - smoothstep(0.0, 0.012 + aa, abs(g.x - sw - 0.018))) * resolve;   // engraved channel
    float fineL = (1.0 - smoothstep(0.004, 0.01 + aa, g.z)) * resolve;
    // the beaded moulding between the girih and the drum: an
    // energy-conserving band (never thinner than ~0.8 px, dimmed instead),
    // faded out before it can alias
    const float ringW = 0.09;
    float rw = max(ringW, aa * 0.8);
    float ring = (1.0 - smoothstep(rw * 0.6, rw + aa * 0.5, abs(bandEdge))) * (ringW / rw) * (1.0 - polar) * ringLod;
    // beads: a square wave anti-aliased over the pixel footprint along the
    // ring; below ~5 px per bead they settle to their average (0.5)
    float lonB = atan(q.z, q.x) / TAU * nCells * 4.0;
    float beadPx = cellPx / 4.0;                                        // bead period on screen
    float bw = clamp(0.5 / max(beadPx, 1e-3), 0.02, 0.25);
    float fb = fract(lonB);
    float sq = smoothstep(0.25 - bw, 0.25 + bw, fb) - smoothstep(0.75 - bw, 0.75 + bw, fb);
    float bead = ring * mix(0.5, sq, smoothstep(2.5, 5.0, beadPx));
    strap = max(strap, ring * 0.9);
    float slope = (strap2 - strap) * mix(0.3, 1.0, resolve);   // rising toward the light → lit bevel
    float region = g.y;
    float cellH = hash12(cell + uSeed);

    // ---- the crown: drum of arched windows, ribbed dome, crescent finial ----
    float crown = smoothstep(-0.02, 0.02, -bandEdge - ringW * 1.2);   // 1 above the moulding
    float window = 0.0, dome = 0.0, finial = 0.0;
    if (crown > 0.0) {
      vec3 cr = fa_crown(q, aa * TAU / nCells * 4.0);
      float isDrum = cr.z < 0.5 ? 1.0 : 0.0;
      dome = cr.z > 0.5 && cr.z < 1.5 ? 1.0 : 0.0;
      finial = cr.z > 1.5 ? 1.0 : 0.0;
      window = cr.y * isDrum * crown;
      float crownStrap = isDrum * (1.0 - smoothstep(0.03, 0.03 + aa, cr.x))
          + dome * (1.0 - smoothstep(0.07, 0.07 + aa * 2.0, cr.x)) * ringLod
          + finial * cr.y;
      strap = mix(strap, saturate(crownStrap), crown);
      g.z = mix(g.z, 1.0, crown);
      region = mix(region, 0.0, crown);
      slope *= 1.0 - crown * 0.6;
    }

    // ---- material ----
    float hammer = fbm3lo(q * 22.0 + uSeed);
    vec3 fieldCol = gold * (0.62 + 0.3 * hammer);
    vec3 medCol = gold * 0.85;
    vec3 gemCol = mix(deep, glowC, 0.2) * 0.35;             // dark enamel
    vec3 albedo = region > 1.5 ? gemCol : (region > 0.5 ? medCol : fieldCol);
    // the crown: a burnished dome over a darker drum wall
    albedo = mix(albedo, mix(gold * 0.7, gold * 1.05, dome + finial), crown);
    albedo = mix(albedo, gold * 1.15, strap);                // polished strapwork
    albedo *= 1.0 - groove * 0.8 - fineL * 0.3;
    albedo = mix(albedo, gold * 1.2, bead * 0.3);
    albedo = mix(albedo, deep * 0.18, window);               // the windows' deep recesses
    // apex medallions burnish with thriving (a low-frequency cue at the poles)
    albedo *= mix(1.0, mix(0.8, 1.2, th), polar);
    float gloss = strap > 0.5 ? 140.0 : (region > 0.5 ? 70.0 : 22.0);
    gloss = mix(gloss, 110.0, dome * crown * (1.0 - strap));
    gloss *= mix(1.0, 0.45, ng);

    // ---- lighting (metal) ----
    vec3 v = vec3(0.0, 0.0, 1.0);
    vec3 hv = normalize(l + v);
    float nh = saturate(dot(n, hv) + (hammer - 0.5) * 0.02 * (1.0 - strap));
    float lam = saturate(ndl - slope * 0.9 * ldl);
    float term = smoothstep(-0.06, 0.1, ndl + 0.02);
    vec3 sunCol = vec3(1.0, 0.95, 0.86) * mix(1.3, 1.1, ng) * (1.0 + uPulse * 0.1);
    float specN = (gloss + 2.0) / 8.0;
    float spec = pow(nh, gloss) * specN * 0.22;
    vec3 diffuse = albedo * lam * 0.9;
    vec3 specCol = mix(goldIn, vec3(1.0, 0.9, 0.7), 0.3) * spec * (1.0 - groove);
    // bevel highlight/shadow along the strap edges
    vec3 bevel = gold * max(-slope, 0.0) * 0.35 * saturate(ndl + 0.3);
    vec3 lit = (diffuse + specCol) * sunCol * term + bevel * sunCol * term;
    // environment: warm dome of light around the core star + dark space
    vec3 R = reflect(-v, n);
    float envSun = pow(saturate(dot(R, l) * 0.5 + 0.5), 6.0);
    float fres = pow(1.0 - saturate(mu), 4.0);
    lit += albedo * (glowC * envSun * 0.18 + deep * 0.03) * (0.5 + fres);
    lit += goldIn * fres * 0.1 * smoothstep(-0.3, 0.3, ndl);

    // ---- neglect: tarnish, dust, cracks (surface) ----
    // tarnish: the gold browns to old bronze in blotches; the raised
    // strapwork stays a little brighter, so the pattern still reads
    // tarnish: the gold darkens and browns, with verdigris gathering in the
    // hollows – still unmistakably old GOLD (never brown rock); the raised
    // strapwork stays brighter so the pattern reads
    float tarnish = ng > 0.001 ? smoothstep(0.25, 0.65, fbm3(q * 3.0 + uSeed)) * ng : 0.0;
    vec3 tarnished = lit * vec3(0.86, 0.74, 0.52) * mix(0.8, 1.05, strap);
    float verd = smoothstep(0.55, 0.8, fbm3lo(q * 7.0 + 3.1 + uSeed)) * (1.0 - strap);
    tarnished = mix(tarnished, toLinear(vec3(0.3, 0.46, 0.38)) * luma(lit) * 1.5, verd * 0.55);
    lit = mix(lit, tarnished, 0.3 * ng + tarnish * 0.45);
    float ck = 0.0;
    if (ng > 0.001) {
      // dust drifts OVER the gold (a veil, not a replacement)
      float dust = dustStorm(q, t) * ng;
      lit = mix(lit, lit * 0.55 + toLinear(vec3(0.5, 0.43, 0.32)) * (sunCol * saturate(ndl * 0.9 + 0.1) * 0.35 + 0.01), dust * 0.4);
      vec2 cv = voronoi3(q * 4.5 + uSeed);
      ck = (1.0 - smoothstep(0.0, max(0.03, aa * 0.1), cv.y - cv.x)) * smoothstep(0.35, 0.85, ng);
      ck *= smoothstep(0.35, 0.6, noise3(q * 2.5 + 7.0)) * smoothstep(60.0, 140.0, uRadius * max(mu, 0.2));
      lit *= 1.0 - ck * 0.5;
    }

    // Family living-state grade: after surface lighting, before emission.
    lit = lifeGrade(lit, th, ng);

    // ---- night-side inlay: light glowing through the engraving ----
    float night = smoothstep(0.1, -0.25, ndl);
    // breathing deepens with thriving (steady inlay barely moves)
    float breathe = 1.0 - 0.3 * th + 0.3 * th * sin(t * 1.1 + cellH * TAU * resolve);
    float lines = max(groove, fineL * 0.6) + ring * 0.25;
    float gems = (region > 1.5 ? 1.0 : 0.0) * (1.0 - strap) * resolve;
    // unresolved: a faint average glow (not an olive fill over the night side)
    // (the channels glow at ~0.35 of the old level: light seen THROUGH the
    // engraving, not cream lace; the enamel corner gems stay the brightest points)
    float inlayLod = mix(0.02, lines * 0.22, resolve);
    float inlayK = mix(0.12, 1.0, live) * breathe * (0.06 + 0.8 * night) * (1.0 - ng * 0.75);
    // warm amber light through the engraving (the same gold, never white)
    vec3 amber = gold * vec3(1.6, 1.25, 0.8);
    vec3 emit = amber * inlayLod * inlayK;
    emit += mix(amber, vec3(1.0, 0.55, 0.25), 0.35) * gems * inlayK * 0.4;
    // the dark side stays dark GOLD (a faint warm fill), not black
    emit += albedo * 0.05 * night;
    // the drum's windows: lamplight inside the mosque
    emit += vec3(1.0, 0.62, 0.28) * window * (0.05 + 0.55 * night) * mix(0.35, 1.0, live) * (1.0 - ng * 0.6);
    // medallion glow (thriving): the poles read as lit rose windows
    emit += mix(glowC, goldIn, 0.3) * polar * th * (0.012 + 0.015 * night) * breathe;
    emit *= 1.0 + uPulse * 1.5;

    // glints running along the strap centre-lines (thriving)
    float glintPh = fract(t * 0.3 + cellH * 5.0);
    float gAng = atan(q.z, q.x) * bands * 1.3 + asin(clamp(q.y, -1.0, 1.0)) * bands * 0.7;
    float glintSpot = smoothstep(0.8, 1.0, sin(gAng - glintPh * TAU * 3.0));
    float centre = 1.0 - smoothstep(0.0, sw * 0.6 + aa * 0.5, g.x);
    float glint = centre * step(0.75, cellH) * glintSpot * sin(glintPh * PI);
    emit += vec3(1.0, 0.95, 0.8) * glint * (th + uPulse) * smoothstep(0.0, 0.4, ndl) * 0.3 * resolve;

    // embers in the cracks through the gilding (neglect)
    emit += distressColor() * ck * (0.03 + 0.45 * night) * (0.4 + 0.6 * pulseD) * 0.5;

    // ---- shared atmosphere: thin warm haze ----
    vec3 T;
    vec3 S = atmoHaze(mu, ndl, atmoCol, tau0, vec3(0.8, 1.0, 1.25), gain, phase, T);
    col = (lit + emit) * T + S;
    col += auC;
    col += distressColor() * distressRim(mu, pulseD);
    col += glowC * uPulse * pow(1.0 - saturate(mu), 3.0) * 0.45;     // celebration flourish: rim flash
  }

  // ---- halo: shared forward-scatter halo + aurora + limb shock + distress ----
  vec3 halo = atmoHalo(p, l, atmoCol, tau0, 0.035, gain, phase, px);
  halo += auC;
  halo += glowC * limbShock(r, uPulse, px) * 0.6;
  halo += distressColor() * distressHalo(r, pulseD, px);

  // The onion dome on the pole: solid, in front of the world and the sky.
  vec4 mn = fa_dome(p, axisV, l, px, goldIn * vec3(0.72, 0.42, 0.3) * 1.5, glowC, th, ng, t);
  if (mn.a > 0.0) {
    vec3 mT;
    vec3 mS = atmoHaze(0.4, 0.5, atmoCol, tau0, vec3(0.8, 1.0, 1.25), gain, phase, mT);
    vec3 mc = lifeGrade(mn.rgb, th, ng) * mT + mS * 0.5;
    float aN = mn.a + discA * (1.0 - mn.a);
    col = (mc * mn.a + col * discA * (1.0 - mn.a)) / max(aN, 1e-4);
    discA = aN;
  }

  fragColor = compositeDiscHalo(col, discA, halo, frag);
}
