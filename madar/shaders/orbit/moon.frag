#version 460 core
#include <flutter/runtime_effect.glsl>
#include "lib/common.glsl"

// Moon disc with the real phase: uLight is the sun direction in the moon's
// view frame (x right, y up, z toward the viewer).
//
// * Albedo: the near side's real maria (Imbrium, Serenitatis,
//   Tranquillitatis, Crisium, Fecunditatis, Nectaris, Nubium, Humorum and
//   the broad Oceanus Procellarum) as soft basalt patches at their places on
//   the face, broken by noise; bright cratered highlands; Tycho's rays.
// * Limb darkening toward the edge of the lit disc, a sharp terminator
//   softened by the regolith, faint earthshine on the night side.
// * A faint, tight halo of scattered moonlight.
// Uniforms (contract unchanged): uSize, uCenter, uRadius, uLight, uTime, uDay.
// Draw rect: Rect.fromCircle(center: uCenter, radius: uRadius * 2.6).
uniform vec2 uSize;
uniform vec2 uCenter;
uniform float uRadius;
uniform vec3 uLight;
uniform float uTime;
uniform float uDay;   // daylight 0..1 (washes the moon out)

out vec4 fragColor;

// One mare: a soft ellipse on the face (face coords: x east-left of centre
// as seen, y north up), [c] centre, [r] radii.
float mo_mare(vec2 f, vec2 c, vec2 r) {
  vec2 d = (f - c) / r;
  return exp(-dot(d, d) * 1.6);
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 p = (frag - uCenter) / uRadius;
  p.y = -p.y;
  float r = length(p);
  vec3 col = vec3(0.0);
  float a = 0.0;
  vec3 L = normalize(uLight);
  if (r < 1.0) {
    vec3 n = sphereNormal(p);
    vec2 f = n.xy;
    vec3 q = n * 2.2 + 5.0;
    // The near side's maria (dark basalt), where they really are.
    float m = 0.0;
    m = max(m, mo_mare(f, vec2(-0.30, 0.52), vec2(0.30, 0.24)));   // Imbrium
    m = max(m, mo_mare(f, vec2(0.20, 0.42), vec2(0.16, 0.15)));    // Serenitatis
    m = max(m, mo_mare(f, vec2(0.38, 0.14), vec2(0.20, 0.18)));    // Tranquillitatis
    m = max(m, mo_mare(f, vec2(0.74, 0.30), vec2(0.10, 0.12)));    // Crisium
    m = max(m, mo_mare(f, vec2(0.62, -0.12), vec2(0.12, 0.16)));   // Fecunditatis
    m = max(m, mo_mare(f, vec2(0.40, -0.28), vec2(0.10, 0.10)));   // Nectaris
    m = max(m, mo_mare(f, vec2(-0.18, -0.34), vec2(0.18, 0.13)));  // Nubium
    m = max(m, mo_mare(f, vec2(-0.55, -0.40), vec2(0.10, 0.10)));  // Humorum
    m = max(m, mo_mare(f, vec2(-0.62, 0.12), vec2(0.26, 0.42)) * 0.85); // Procellarum
    float edge = fbm3(q * 1.3);
    float maria = smoothstep(0.35, 0.75, m + (edge - 0.5) * 0.45);
    float craters = voronoi3(q * 3.0).x;
    float highland = 0.86 + 0.14 * smoothstep(0.0, 0.3, craters);
    // Tycho (south) and its bright rays.
    vec2 ty = f - vec2(-0.12, -0.74);
    float tycho = exp(-dot(ty, ty) * 900.0);
    float rays = pow(saturate(noise2(vec2(atan(ty.y, ty.x) * 9.0, 1.7))), 6.0) * exp(-length(ty) * 3.5) * 0.35;
    float albedo = mix(0.9, 0.36, maria) * highland + tycho * 0.5 + rays * (1.0 - maria);

    float ndl = dot(n, L);
    // Regolith: a crisp but not razor terminator, and limb darkening across
    // the lit disc.
    float lit = smoothstep(-0.03, 0.09, ndl) * (0.45 + 0.55 * saturate(ndl));
    float limb = mix(0.72, 1.0, pow(saturate(n.z), 0.35));
    float earthshine = 0.03;
    col = vec3(0.98, 0.96, 0.9) * albedo * (lit * limb * 1.12 + earthshine);
    a = discMask(p, uRadius);
  }
  // A faint, tight halo of scattered moonlight (brighter the fuller the
  // moon's lit face).
  float full = saturate(L.z * 0.5 + 0.5);
  float halo = (exp(-max(r - 1.0, 0.0) * 7.0) * 0.12 + exp(-max(r - 1.0, 0.0) * 2.2) * 0.04) * full;
  halo *= 1.0 - smoothstep(2.2, 2.6, r);
  vec3 haloCol = vec3(0.85, 0.9, 1.0) * halo;
  col = toGamma(tonemapACES(col)) * (1.0 - uDay * 0.6);
  vec3 pm = col * a + haloCol * (1.0 - a);
  fragColor = vec4(pm, max(a, halo));
}
