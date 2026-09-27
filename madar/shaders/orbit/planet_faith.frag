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
//   thriving : bright polished gold, breathing inlay light, golden aurora,
//              glints running along the strapwork.
//   neglected: green-black tarnish, dust, cracks through the gilding, dimming,
//              red distress pulse.
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

// Golden aurora ribbon (object space, y = spin axis).
float fa_aurora(vec3 q, float t, float px) {
  vec2 dir = normalize(q.xz + 1e-4);
  float hemi = q.y > 0.0 ? 1.0 : -1.0;
  float wob = (noise3(vec3(dir * 1.7, t * 0.06 + hemi * 4.0)) - 0.5) * 0.05
            + (noise3(vec3(dir * 6.8, t * 0.14 + hemi * 2.0)) - 0.5) * 0.018;
  float d = abs(q.y) - (0.905 + wob);
  float wEq = max(0.004, px);
  float band = (d < 0.0 ? exp(-d * d / (wEq * wEq)) : exp(-d / max(0.005, px * 0.8))) * (0.004 / wEq);
  float rays = noise3(vec3(dir * 30.0, t * 0.3 + hemi * 3.0));
  float drift = smoothstep(0.25, 0.65, noise3(vec3(dir * 2.3 - t * 0.03, hemi * 9.0)));
  return band * (0.6 + 0.4 * rays) * (0.2 + 0.8 * drift);
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

  vec3 goldIn = toLinear(uColorA.rgb);
  vec3 glowC = toLinear(uColorB.rgb);
  vec3 deep = toLinear(uColorC.rgb);
  // deeper, richer gold (more red/less green than the flat palette colour)
  // (targets ≈ sRGB 200,140,50 in the lit midtones after ACES)
  vec3 gold = goldIn * vec3(0.72, 0.42, 0.3);
  vec3 atmoCol = mix(glowC, goldIn, 0.5) * 0.8;
  atmoCol = mix(atmoCol, toLinear(vec3(0.58, 0.55, 0.48)), ng * 0.6);
  vec3 distressCol = toLinear(vec3(1.0, 0.2, 0.14));
  float pulseD = distressPulse(t) * ng;

  mat3 rot = rotY(uSpin.x + t * 0.03) * rotX(uSpin.y + 0.35);
  float phase = 0.7 + 3.0 * pow(saturate(0.5 - 0.5 * l.z), 5.0);
  float atmoGain = mix(0.6, 1.0, live) * (1.0 + uPulse * 0.5);
  const float tauAtm = 0.03;

  float discA = discMask(p, uRadius);
  vec3 col = vec3(0.0);

  if (discA > 0.0) {
    vec2 pd = p * min(1.0, 0.9995 / max(r, 1e-4));
    vec3 n = sphereNormal(pd);
    vec3 q = rot * n;
    vec3 ql = rot * l;
    float mu = n.z;
    float ndl = dot(n, l);

    float bands = 9.0 * (uExtra.x > 0.0 ? uExtra.x : 1.0);
    float cellPx = uRadius * PI / bands * max(mu, 0.05);    // cell size on screen
    float aa = 1.0 / cellPx;                                // one pixel in cell units
    float resolve = smoothstep(9.0, 22.0, cellPx);          // can we draw the fine lines?

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
    float sw = 0.026;
    float strap = 1.0 - smoothstep(sw - aa, sw + aa, g.x);
    float strap2 = 1.0 - smoothstep(sw - aa, sw + aa, g2.x);
    float groove = (1.0 - smoothstep(0.0, 0.012 + aa, abs(g.x - sw - 0.018))) * resolve;   // engraved channel
    float fineL = (1.0 - smoothstep(0.004, 0.01 + aa, g.z)) * resolve;
    float ring = (1.0 - smoothstep(0.03, 0.04 + aa, bandEdge)) * (1.0 - polar);          // ring band between courses
    float bead = ring * step(0.5, fract(atan(q.z, q.x) / TAU * bands * 24.0));
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
    float gloss = strap > 0.5 ? 140.0 : (region > 0.5 ? 70.0 : 22.0);
    gloss *= mix(1.0, 0.45, ng);

    // ---- lighting (metal) ----
    vec3 v = vec3(0.0, 0.0, 1.0);
    vec3 hv = normalize(l + v);
    float nh = saturate(dot(n, hv) + (hammer - 0.5) * 0.02 * (1.0 - strap));
    float lam = saturate(ndl - slope * 0.9 * ldl);
    float term = smoothstep(-0.06, 0.1, ndl + 0.02);
    vec3 sunCol = vec3(1.0, 0.95, 0.86) * mix(1.6, 1.3, ng) * (1.0 + uPulse * 0.1);
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
    lit += goldIn * fres * 0.12 * smoothstep(-0.3, 0.3, ndl);

    // ---- night-side inlay: light through the filigree ----
    float night = smoothstep(0.1, -0.25, ndl);
    float breathe = 0.7 + 0.3 * sin(t * 1.1 + cellH * TAU * resolve);
    float inlayLines = max(groove, fineL * 0.6) + ring * 0.25 + (region > 1.5 ? 0.9 : 0.0) * (1.0 - strap);
    float inlayLod = mix(0.1, inlayLines, resolve);         // average when too small to draw
    float inlay = inlayLod * mix(0.12, 1.0, live) * breathe * (0.08 + 0.85 * night) * (1.0 - ng * 0.75);
    vec3 emit = mix(glowC, goldIn, 0.45) * inlay * 1.1;
    emit *= 1.0 + uPulse * 1.5;

    // glints racing along the strapwork (thriving)
    float glintPh = fract(t * 0.3 + cellH * 5.0);
    float gAng = atan(q.z, q.x) * bands * 1.3 + asin(clamp(q.y, -1.0, 1.0)) * bands * 0.7;
    float glintSpot = smoothstep(0.93, 1.0, sin(gAng - glintPh * TAU * 3.0));
    float glint = strap * step(0.75, cellH) * glintSpot * sin(glintPh * PI);
    emit += vec3(1.0, 0.95, 0.8) * glint * (th + uPulse) * smoothstep(0.0, 0.4, ndl) * 0.6 * resolve;

    // ---- neglect: tarnish, dust, cracks ----
    float tarnish = ng > 0.001 ? smoothstep(0.38, 0.72, fbm3(q * 3.0 + uSeed)) * ng : 0.0;
    vec3 patina = toLinear(vec3(0.24, 0.27, 0.2));
    lit = mix(lit, desaturate(lit, 0.8) * patina * 2.2, tarnish * 0.85);
    lit = desaturate(lit, ng * 0.45) * (1.0 - ng * 0.3);
    float dust = 0.0;
    if (ng > 0.001) {
      dust = dustStorm(q, t) * ng;
      lit = mix(lit, toLinear(vec3(0.5, 0.43, 0.32)) * (sunCol * saturate(ndl * 0.9 + 0.1) * 0.8 + 0.02), dust * 0.55);
      vec2 cv = voronoi3(q * 4.5 + uSeed);
      float ck = (1.0 - smoothstep(0.0, max(0.03, aa * 0.1), cv.y - cv.x)) * smoothstep(0.35, 0.85, ng);
      ck *= smoothstep(0.35, 0.6, noise3(q * 2.5 + 7.0)) * smoothstep(60.0, 140.0, uRadius * max(mu, 0.2));
      lit *= 1.0 - ck * 0.5;
      emit += distressCol * ck * (0.03 + 0.45 * night) * (0.4 + 0.6 * pulseD) * 0.5;
    }

    // ---- atmosphere: thin warm haze ----
    float airmass = 1.0 / (max(mu, 0.0) + 0.1);
    float tau = tauAtm * airmass * (1.0 + ng);
    vec3 T = exp(-tau * vec3(0.8, 1.0, 1.25));
    vec3 S = atmoCol * (1.0 - exp(-tau)) * smoothstep(-0.3, 0.3, ndl) * phase * 1.8 * atmoGain;
    col = (lit + emit) * T + S;
    float auK = th * 0.85 + uPulse * 0.8;
    float au = auK > 0.001 ? fa_aurora(q, t, 1.0 / uRadius) * auK : 0.0;
    col += mix(glowC, gold, 0.3) * au * (0.06 + night) / (saturate(mu) + 0.6) * 0.55;
    float fr3 = pow(1.0 - saturate(mu), 3.0);
    col += distressCol * fr3 * pulseD * 0.65;
    col += glowC * uPulse * fr3 * fr3 * 1.2;
  }

  // ---- halo ----
  float hr = max(r - 1.0, 0.0);
  vec3 d3 = vec3(p / max(r, 1e-4), 0.0);
  float ndlL = dot(d3, l);
  float dens = exp(-hr / 0.04);
  float tauH = tauAtm * 11.0 * dens * (1.0 + ng);
  vec3 halo = atmoCol * (1.0 - exp(-tauH)) * smoothstep(-0.3, 0.3, ndlL) * phase * 1.8 * atmoGain;
  float nightL = 1.0 - smoothstep(-0.2, 0.15, ndlL);
  halo += glowC * 0.03 * th * dens * nightL;
  float qaK = th * 0.85 + uPulse * 0.8;
  float qa = (qaK > 0.001 && hr < 0.2) ? fa_aurora(rot * d3, t, 1.0 / uRadius) * qaK : 0.0;
  halo += mix(glowC, toLinear(vec3(1.0, 0.6, 0.35)), smoothstep(0.0, 0.05, hr)) * qa * exp(-hr / 0.022) * (0.1 + 0.8 * nightL) * 0.55;
  halo += distressCol * pulseD * exp(-hr / 0.035) * 0.4;
  float ringR = 1.0 + (1.0 - uPulse) * 0.26;
  float rdp = (r - ringR) / (0.012 + 0.03 * (1.0 - uPulse));
  halo += glowC * uPulse * exp(-rdp * rdp) * 0.6 * smoothstep(1.0, 1.02, r);

  vec3 dC = toGamma(tonemapACES(col));
  vec3 hC = toGamma(tonemapACES(halo));
  float hA = saturate(max(hC.r, max(hC.g, hC.b)));
  vec3 pm = dC * discA + hC * (1.0 - discA);
  float a = discA + hA * (1.0 - discA);
  pm = dither(frag, pm);
  fragColor = vec4(clamp(pm, vec3(0.0), vec3(a)), a);
}
