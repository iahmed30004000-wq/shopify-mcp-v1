#version 460 core
#include <flutter/runtime_effect.glsl>
#include "lib/common.glsl"

// Faith — a golden world engraved with glowing geometric patterns like a
// celestial mosque dome: latitude bands of 8-point stars whose count shrinks
// toward the poles, ribs converging on a polar rosette.
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
uniform vec4 uExtra;   // x: pattern density multiplier (0 → default)

out vec4 fragColor;

vec2 rot2(vec2 p, float a) { float c = cos(a), s = sin(a); return vec2(c * p.x - s * p.y, s * p.x + c * p.y); }
float sdBox2(vec2 p, float r) { vec2 d = abs(p) - vec2(r); return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0); }
// 8-point star (Rub el Hizb) = union of two squares.
float sdStar8(vec2 p, float r) { return min(sdBox2(p, r), sdBox2(rot2(p, 0.78539816), r)); }

// Returns engraved line intensity (1 on the groove) and a cell id.
float domePattern(vec3 q, out float cellId, out float starMask) {
  float lat = asin(clamp(q.y, -1.0, 1.0));           // -pi/2..pi/2
  float lon = atan(q.z, q.x);                          // -pi..pi
  float bands = 9.0 * (uExtra.x > 0.0 ? uExtra.x : 1.0);
  float bl = (lat / PI + 0.5) * bands;                 // band coordinate
  float band = floor(bl);
  float fv = fract(bl) - 0.5;
  float latC = ((band + 0.5) / bands - 0.5) * PI;
  float n = max(8.0, floor(bands * 2.0 * cos(latC) / 8.0 + 0.5) * 8.0);
  float lu = (lon / TAU + 0.5) * n + band * 0.5;       // stagger alternate bands
  float cell = floor(lu);
  float fu = fract(lu) - 0.5;
  vec2 p = vec2(fu, fv);
  cellId = hash12(vec2(cell, band));
  float d = sdStar8(p, 0.25);
  float inner = sdStar8(rot2(p, 0.3927), 0.12);
  float grid = min(abs(abs(p.x) - 0.5), abs(abs(p.y) - 0.5));
  float w = 0.035;
  float lines = max(1.0 - smoothstep(0.0, w, abs(d)), 1.0 - smoothstep(0.0, w * 0.8, abs(inner)));
  lines = max(lines, (1.0 - smoothstep(0.0, w * 0.7, grid)) * 0.8);
  starMask = 1.0 - smoothstep(-0.01, 0.01, d);
  // Polar rosette caps.
  float polar = abs(q.y);
  if (polar > 0.94) {
    vec2 pp = q.xz / max(1e-3, 1.0 - polar + 0.06) * 0.25;
    float ang = atan(pp.y, pp.x);
    float rr = length(pp);
    float petals = abs(sin(ang * 8.0)) * 0.12 + 0.3;
    float ros = 1.0 - smoothstep(0.0, 0.03, abs(rr - petals));
    ros = max(ros, 1.0 - smoothstep(0.0, 0.03, abs(sdStar8(pp, 0.14))));
    float k = smoothstep(0.94, 0.97, polar);
    lines = mix(lines, ros, k);
    starMask = mix(starMask, 1.0 - smoothstep(0.1, 0.16, rr), k);
  }
  return lines;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 p = (frag - uCenter) / uRadius;
  p.y = -p.y;
  float r = length(p);
  vec3 l = normalize(uLight);
  float th = thrive(uScore);
  float ng = neglect(uScore);
  vec3 gold = toLinear(uColorA.rgb);
  vec3 glowC = toLinear(uColorB.rgb);
  vec3 deep = toLinear(uColorC.rgb);
  vec3 col = vec3(0.0);

  if (r < 1.0) {
    vec3 n = sphereNormal(p);
    mat3 rot = rotY(uSpin.x + uTime * 0.03) * rotX(uSpin.y + 0.35);
    vec3 q = rot * n;
    float cellId, starMask;
    float lines = domePattern(q, cellId, starMask);
    // Metallic gold with hammered micro-variation.
    float hammer = fbm3lo(q * 18.0 + uSeed);
    vec3 albedo = mix(deep * 1.2, gold * 0.85, 0.5 + 0.3 * hammer);
    albedo = mix(albedo, gold * 1.15, starMask * 0.35);
    // Engraving darkens the groove and bends the normal slightly.
    albedo *= 1.0 - lines * 0.55;
    float ndl = dot(n, l);
    float diff = smoothstep(-0.05, 0.4, ndl) * saturate(ndl * 0.9 + 0.2);
    vec3 hv = normalize(l + vec3(0.0, 0.0, 1.0));
    float gloss = mix(28.0, 90.0, th) * (1.0 - ng * 0.6);
    float spec = pow(saturate(dot(n, hv)), gloss) * (1.0 - lines * 0.7) * mix(0.6, 2.6, 1.0 - ng);
    float fres = pow(1.0 - saturate(n.z), 4.0);
    vec3 env = mix(deep, glowC, 0.4) * fres * 0.6;
    col = albedo * diff * 1.35 + gold * spec * 1.8 + env;
    // Glowing inlay in the grooves: brightest on the night side, breathing.
    float night = 1.0 - smoothstep(-0.25, 0.25, ndl);
    float breathe = 0.75 + 0.25 * sin(uTime * 1.1 + cellId * 6.28);
    float inlay = lines * mix(0.12, 1.0, th) * breathe * (0.35 + 1.6 * night);
    col += glowC * inlay * 1.3;
    // Sparkles on thriving worlds.
    float sp = step(0.9975, hash12(floor(frag * 0.5) + floor(uTime * 3.0))) * th * diff;
    col += vec3(1.0, 0.95, 0.8) * sp * 2.0;
    // Neglect: tarnish, dust, cracks, distress.
    float tarnish = smoothstep(0.35, 0.75, fbm3(q * 3.0 + uSeed)) * ng;
    col = mix(col, desaturate(col, 0.8) * vec3(0.55, 0.6, 0.5), tarnish * 0.8);
    col = desaturate(col, ng * 0.5) * (1.0 - ng * 0.35);
    float dust = dustStorm(q, uTime) * ng;
    col = mix(col, toLinear(vec3(0.5, 0.42, 0.3)) * (diff * 1.6 + 0.03), dust * 0.55);
    col += toLinear(vec3(1.0, 0.3, 0.12)) * cracks(q) * smoothstep(0.45, 0.9, ng) * (0.3 + 0.7 * night) * 0.45;
    col += toLinear(vec3(1.0, 0.25, 0.18)) * fres * ng * distressPulse(uTime) * 1.1;
    col += glowC * uPulse * (0.4 + fres * 2.0);
    col += atmosphere(p, n, l, glowC, mix(0.25, 0.8, th) * (1.0 - ng * 0.5), 0.2);
  }
  float haloD = mix(0.25, 0.8, th) * (1.0 - ng * 0.5);
  vec3 halo = atmosphere(p, vec3(0.0, 0.0, 1.0), l, glowC, haloD, 0.22) * step(1.0, r)
            + glowC * haloD * 1.1 * (1.0 - step(1.0, r));
  halo += toLinear(vec3(1.0, 0.25, 0.18)) * ng * distressPulse(uTime) * 0.5 * (1.0 - smoothstep(1.0, 1.1, r));
  float haloA = saturate(max(halo.r, max(halo.g, halo.b)) * 2.5);
  float discA = discMask(p, uRadius);
  vec3 pm = toGamma(tonemapACES(col)) * discA + toGamma(tonemapACES(halo)) * haloA * (1.0 - discA);
  fragColor = vec4(dither(frag, pm), discA + haloA * (1.0 - discA));
}
