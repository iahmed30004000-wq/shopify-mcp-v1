#version 460 core
#include <flutter/runtime_effect.glsl>
#include "lib/common.glsl"

// Brushed brass / gold material for astrolabe rings (used as Paint.shader for
// fills and strokes). Concentric brushing + anisotropic specular that follows
// the light (gyro tilt) + engraving-friendly mid tones + tarnish by uWear.
uniform vec2 uSize;
uniform vec2 uCenter;
uniform float uScale;   // astrolabe radius px
uniform vec2 uLight;    // light direction in screen plane (unit), from gyro / core star
uniform float uTime;
uniform float uWear;    // 0 polished … 1 tarnished
uniform vec4 uBase;     // brass
uniform vec4 uHi;       // gold highlight
uniform vec4 uLow;      // dark brass

out vec4 fragColor;

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 d = (frag - uCenter) / uScale;
  float r = length(d);
  float a = atan(d.y, d.x);
  vec2 tangent = vec2(-sin(a), cos(a));
  // concentric brushing: fine radial noise that is constant along the circle
  float brush = hash12(vec2(floor(r * uScale * 1.3), 7.0)) * 0.6 + hash12(vec2(floor(r * uScale * 0.35), 3.0)) * 0.4;
  float micro = noise2(vec2(a * 40.0, r * 300.0)) * 0.3;
  // anisotropic highlight: brightest where the tangent is perpendicular to the light
  float aniso = pow(abs(dot(tangent, normalize(uLight + 1e-4))), 6.0);
  float band = aniso * (0.55 + 0.45 * brush);
  vec3 base = mix(toLinear(uLow.rgb), toLinear(uBase.rgb), 0.55 + 0.35 * brush + micro * 0.2);
  vec3 col = base + toLinear(uHi.rgb) * band * 1.4;
  // sweeping glint
  float glint = pow(saturate(1.0 - abs(sin(a * 0.5 - uTime * 0.25 + r * 2.0)) * 3.0), 8.0) * 0.35;
  col += toLinear(uHi.rgb) * glint;
  // tarnish: patina + dulling
  float patina = smoothstep(0.45, 0.8, fbm3lo(vec3(d * 6.0, 1.3)));
  col = mix(col, mix(col * 0.45, toLinear(vec3(0.24, 0.36, 0.30)), patina * 0.6), uWear * 0.8);
  col = toGamma(tonemapACES(col * 1.2));
  fragColor = vec4(col, 1.0);
}
