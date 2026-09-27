#version 460 core
#include <flutter/runtime_effect.glsl>
#include "lib/common.glsl"

// FAITH — a deep-gold world worked like the inside of a mosque dome: rings of
// interlaced 8-point girih (khatam stars chained tip-to-tip, inner rotated
// stars, octagon rosettes, corner stars) whose cell count shrinks toward the
// poles, framed by beaded ring bands and crowned by a 16-fold apex medallion.
// Raised polished strapwork over hammered fields; enamel gems in the corner
// stars. On the NIGHT SIDE the engraved channels beside the strapwork and the
// gems glow like light through filigree.
//   thriving : bright, saturated polished gold, burnished apex medallions,
//              breathing inlay light, soft gold/amber aurora curtains, glints
//              running along the strap centre-lines.
//   neglected: green-black tarnish, dust, cracks through the gilding, dimming,
//              red distress pulse.
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
// uExtra: x = pattern density multiplier (0 → default 1; 0.7..1.6 sensible)
//         y, z, w unused.
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

// Dome parameterisation: rings of cells whose count shrinks toward the poles.
// Returns the pattern sample; cell = (band, cell index) id; `cellH` = cell
// height in radians; `polar` = medallion blend.
vec3 fa_pattern(vec3 q, float bands, out vec2 cell, out float bandEdge, out float polar) {
  float lat = asin(clamp(q.y, -1.0, 1.0));
  float lon = atan(q.z, q.x);
  float bl = (lat / PI + 0.5) * bands;
  float band = floor(bl);
  float fv = fract(bl) - 0.5;
  float latC = ((band + 0.5) / bands - 0.5) * PI;
  float n = max(8.0, floor(bands * 2.0 * cos(latC) / 8.0 + 0.5) * 8.0);
  float lu = (lon / TAU + 0.5) * n + band * 0.5;
  float ci = floor(lu);
  float fu = fract(lu) - 0.5;
  cell = vec2(band, ci);
  bandEdge = 0.5 - abs(fv);
  vec3 g = fa_girih(vec2(fu, fv));
  // apex medallions over both poles
  float colat = acos(clamp(abs(q.y), 0.0, 1.0));
  float capR = PI / bands * 1.02;
  polar = 1.0 - smoothstep(capR * 0.92, capR, colat);
  if (polar > 0.0) {
    vec2 pp = normalize(q.xz + 1e-5) * colat / capR * 0.5;
    vec3 m = fa_medallion(pp);
    g = mix(g, m, polar);
    bandEdge = mix(bandEdge, 1.0, polar);
    cell = mix(cell, vec2(q.y > 0.0 ? 99.0 : -99.0, 0.0), polar);
  }
  return g;
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

  mat3 rot = rotY(uSpin.x + t * 0.03) * rotX(uSpin.y + 0.35);
  // shared atmosphere (thin warm haze)
  float phase = atmoPhase(l);
  float gain = 1.8 * haloGain(th, ng) * (1.0 + 0.5 * uPulse);
  float tau0 = 0.03 * (1.0 + 1.2 * ng);

  // shared aurora curtains, evaluated once for disc and halo
  // (oval just outside the apex medallion so the curtains never trace its rim;
  // faded at small radii where a 2 px arc would read as a selection ellipse)
  float auK = (th * 0.9 + uPulse * 0.8) * mix(0.35, 1.0, smoothstep(22.0, 60.0, uRadius));
  vec2 au = (auK > 0.001 && fa_auroraNear(p, rot, 0.86, px)) ? auroraCurtains(p, rot, l, 0.86, t, px) * auK : vec2(0.0);
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

    float bands = 7.0 * (uExtra.x > 0.0 ? uExtra.x : 1.0);
    float cellPx = uRadius * PI / bands * max(mu, 0.05);    // cell size on screen
    float aa = 1.0 / cellPx;                                // one pixel in cell units
    float resolve = smoothstep(9.0, 22.0, cellPx);          // can we draw the fine lines?
    float ringLod = smoothstep(4.0, 10.0, cellPx);          // ring bands / beads fade before they alias

    vec2 cell;
    float bandEdge, polar;
    vec3 g = fa_pattern(q, bands, cell, bandEdge, polar);

    // Light direction in the local (east, north) frame → bevel of raised straps.
    vec3 east = normalize(vec3(-q.z, 0.0, q.x) + vec3(1e-4, 0.0, 0.0));
    vec3 north = cross(q, east);
    vec2 ld = vec2(dot(ql, east), dot(ql, north));
    float ldl = length(ld);
    vec2 dcell;
    float be2, pol2;
    vec3 g2 = g;
    if (cellPx > 6.0) {   // bevel only when the straps are resolvable (saves a 2nd pattern evaluation)
      g2 = fa_pattern(normalize(q + (east * ld.x + north * ld.y) / max(ldl, 1e-4) * (PI / bands) * 0.03), bands, dcell, be2, pol2);
    }

    // Strap profile: raised flat-topped band with bevelled edges.
    float sw = 0.032;
    float strap = 1.0 - smoothstep(sw - aa, sw + aa, g.x);
    float strap2 = 1.0 - smoothstep(sw - aa, sw + aa, g2.x);
    float groove = (1.0 - smoothstep(0.0, 0.012 + aa, abs(g.x - sw - 0.018))) * resolve;   // engraved channel
    float fineL = (1.0 - smoothstep(0.004, 0.01 + aa, g.z)) * resolve;
    // ring band between courses: an energy-conserving line (never thinner
    // than ~0.8 px, dimmed instead), faded out before it can alias
    const float ringW = 0.035;
    float rw = max(ringW, aa * 0.8);
    float ring = (1.0 - smoothstep(rw * 0.6, rw + aa * 0.5, bandEdge)) * (ringW / rw) * (1.0 - polar) * ringLod;
    // beads: a square wave anti-aliased over the pixel footprint along the
    // ring; below ~5 px per bead they settle to their average (0.5)
    float lonB = atan(q.z, q.x) / TAU * bands * 24.0;
    float beadPx = cellPx / 12.0 * max(sqrt(1.0 - q.y * q.y), 0.05);   // bead period on screen
    float bw = clamp(0.5 / max(beadPx, 1e-3), 0.02, 0.25);
    float fb = fract(lonB);
    float sq = smoothstep(0.25 - bw, 0.25 + bw, fb) - smoothstep(0.75 - bw, 0.75 + bw, fb);
    float bead = ring * mix(0.5, sq, smoothstep(2.5, 5.0, beadPx));
    strap = max(strap, ring * 0.9);
    float slope = (strap2 - strap) * mix(0.3, 1.0, resolve);   // rising toward the light → lit bevel
    float region = g.y;
    float cellH = hash12(cell + uSeed);

    // ---- material ----
    float hammer = fbm3lo(q * 22.0 + uSeed);
    vec3 fieldCol = gold * (0.62 + 0.3 * hammer);
    vec3 medCol = gold * 0.85;
    vec3 gemCol = mix(deep, glowC, 0.2) * 0.35;             // dark enamel
    vec3 albedo = region > 1.5 ? gemCol : (region > 0.5 ? medCol : fieldCol);
    albedo = mix(albedo, gold * 1.15, strap);                // polished strapwork
    albedo *= 1.0 - groove * 0.8 - fineL * 0.3;
    albedo = mix(albedo, gold * 1.2, bead * 0.3);
    // apex medallions burnish with thriving (a low-frequency cue at the poles)
    albedo *= mix(1.0, mix(0.8, 1.2, th), polar);
    float gloss = strap > 0.5 ? 140.0 : (region > 0.5 ? 70.0 : 22.0);
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
    float tarnish = ng > 0.001 ? smoothstep(0.38, 0.72, fbm3(q * 3.0 + uSeed)) * ng : 0.0;
    vec3 patina = toLinear(vec3(0.24, 0.27, 0.2));
    lit = mix(lit, desaturate(lit, 0.8) * patina * 2.2, tarnish * 0.85);
    float ck = 0.0;
    if (ng > 0.001) {
      float dust = dustStorm(q, t) * ng;
      lit = mix(lit, toLinear(vec3(0.5, 0.43, 0.32)) * (sunCol * saturate(ndl * 0.9 + 0.1) * 0.8 + 0.02), dust * 0.55);
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
    float inlayLod = mix(0.025, lines * 0.35, resolve);
    float inlayK = mix(0.12, 1.0, live) * breathe * (0.08 + 0.85 * night) * (1.0 - ng * 0.75);
    vec3 emit = mix(glowC, goldIn, 0.45) * inlayLod * inlayK * 1.1;
    emit += mix(glowC, vec3(1.0, 0.55, 0.25), 0.35) * gems * inlayK * 1.3;
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
    col += glowC * uPulse * pow(1.0 - saturate(mu), 6.0) * 1.2;     // celebration flourish: rim flash
  }

  // ---- halo: shared forward-scatter halo + aurora + limb shock + distress ----
  vec3 halo = atmoHalo(p, l, atmoCol, tau0, 0.035, gain, phase, px);
  halo += auC;
  halo += glowC * limbShock(r, uPulse, px) * 0.6;
  halo += distressColor() * distressHalo(r, pulseD, px);

  fragColor = compositeDiscHalo(col, discA, halo, frag);
}
