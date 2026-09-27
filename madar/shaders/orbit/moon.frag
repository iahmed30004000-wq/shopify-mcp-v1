#version 460 core
#include <flutter/runtime_effect.glsl>
#include "lib/common.glsl"

// Moon disc with the real phase: uLight is the sun direction in the moon's
// view frame (x right, y up, z toward the viewer).
uniform vec2 uSize;
uniform vec2 uCenter;
uniform float uRadius;
uniform vec3 uLight;
uniform float uTime;
uniform float uDay;   // daylight 0..1 (washes the moon out)

out vec4 fragColor;

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 p = (frag - uCenter) / uRadius;
  p.y = -p.y;
  float r = length(p);
  vec3 col = vec3(0.0);
  float a = 0.0;
  if (r < 1.0) {
    vec3 n = sphereNormal(p);
    vec3 q = n * 2.2 + 5.0;
    float maria = smoothstep(0.45, 0.7, fbm3(q * 0.9));
    float craters = voronoi3(q * 3.0).x;
    float albedo = mix(0.78, 0.42, maria) * (0.9 + 0.1 * smoothstep(0.0, 0.3, craters));
    float ndl = dot(n, normalize(uLight));
    float lit = smoothstep(-0.02, 0.08, ndl) * (0.35 + 0.65 * saturate(ndl));
    float earthshine = 0.035;
    col = vec3(0.98, 0.96, 0.9) * albedo * (lit * 1.6 + earthshine);
    a = discMask(p, uRadius);
  }
  float halo = exp(-max(r - 1.0, 0.0) * 5.0) * 0.18 * saturate(dot(vec3(0.0, 0.0, 1.0), normalize(uLight)) * 0.5 + 0.5);
  vec3 haloCol = vec3(0.85, 0.9, 1.0) * halo;
  col = toGamma(tonemapACES(col)) * (1.0 - uDay * 0.6);
  vec3 pm = col * a + haloCol * (1.0 - a);
  fragColor = vec4(pm, max(a, halo));
}
