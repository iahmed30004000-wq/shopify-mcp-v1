#version 460 core
#include <flutter/runtime_effect.glsl>
#include "lib/common.glsl"

// Brushed brass for the astrolabe's metal (limb, hub ring, rete; used as
// Paint.shader for fills and strokes).
//
// * A three-stop ramp uLow → uBase → uHi (umber, amber, pale gold) driven by
//   the circumferential brushing – never one flat saturated yellow.
// * Circumferential brushed streaks at three scales, broken along the
//   circle, plus per-pixel micro-roughness.
// * An anisotropic highlight: concentric grooves light up as a radial
//   "bow-tie" along the light direction uLight (the gyro tilt turns it, so
//   the metal glints as the phone moves), with a slow travelling glint.
// * Tarnish by uWear: dulled and darkened with a verdigris patina.
// Uniforms (contract unchanged): uSize, uCenter, uScale (astrolabe radius
// px), uLight (screen-plane unit direction), uTime, uWear, uBase, uHi, uLow.
uniform vec2 uSize;
uniform vec2 uCenter;
uniform float uScale;   // astrolabe radius px
uniform vec2 uLight;    // light direction in screen plane (unit), from gyro / core star
uniform float uTime;
uniform float uWear;    // 0 polished … 1 tarnished
uniform vec4 uBase;     // brass body
uniform vec4 uHi;       // pale-gold highlight
uniform vec4 uLow;      // umber shadow

out vec4 fragColor;

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 d = (frag - uCenter) / max(uScale, 1.0);
  float r = length(d);
  float a = atan(d.y, d.x);
  vec2 radial = d / max(r, 1e-4);
  float rp = r * uScale;                                   // px from the centre

  // Circumferential brushing: streaks constant along the circle (fine,
  // medium, broad), broken up along it so they read as brushed metal, not
  // as a record's grooves.
  float s1 = hash12(vec2(floor(rp * 1.6), 7.0));
  float s2 = hash12(vec2(floor(rp * 0.42), 3.0));
  float s3 = noise2(vec2(rp * 0.06, 5.0 + a * 0.8));
  float along = noise2(vec2(a * 48.0 + s2 * 23.0, rp * 0.7));
  float brush = (s1 * 0.4 + s2 * 0.35 + s3 * 0.25) * (0.78 + 0.44 * along);
  float micro = hash12(frag * 1.37 + 3.1) - 0.5;

  vec2 L = normalize(uLight + 1e-4);
  float facing = dot(radial, L);
  // Diffuse: the lit side of the disc a little brighter.
  float diffuse = 0.5 + 0.22 * facing;
  // Anisotropic bow-tie highlight along the light axis (both lobes, the
  // near one stronger), modulated by the brushing.
  float aniso = pow(abs(facing), 10.0) * (facing > 0.0 ? 1.0 : 0.45);
  float sheen = pow(abs(facing), 3.0) * (facing > 0.0 ? 0.35 : 0.12);

  vec3 lo = toLinear(uLow.rgb), mid = toLinear(uBase.rgb), hi = toLinear(uHi.rgb);
  float t = saturate(diffuse * 0.62 + (brush - 0.5) * 0.34 + micro * 0.05 + sheen * 0.5);
  vec3 col = t < 0.5 ? mix(lo, mid, t * 2.0) : mix(mid, hi, (t - 0.5) * 2.0);

  // Specular: the bow-tie streaked by the brushing, and a slow glint
  // travelling round the rings.
  float spec = aniso * (0.55 + 0.9 * s1 * (0.6 + 0.4 * along));
  float glint = pow(saturate(1.0 - abs(sin(a * 0.5 - uTime * 0.21 + r * 1.7)) * 3.2), 10.0) * 0.28;
  col = mix(col, hi * 1.12, saturate(spec * 0.7 + glint));

  // Tarnish: dull, darker, with verdigris gathering in blotches.
  float patina = smoothstep(0.42, 0.78, fbm3lo(vec3(d * 7.0, 1.3)));
  vec3 dull = mix(desaturate(col, 0.35) * 0.55, toLinear(vec3(0.22, 0.34, 0.28)) * 0.9, patina * 0.55);
  col = mix(col, dull, saturate(uWear) * 0.85);

  fragColor = vec4(toGamma(saturate3(col)), 1.0);
}
