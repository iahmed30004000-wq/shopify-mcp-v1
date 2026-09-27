#version 460 core
#include <flutter/runtime_effect.glsl>
#include "lib/common.glsl"

// Real-time sky backdrop. Frame: ENU (x = east, y = north, z = up).
uniform vec2 uSize;
uniform vec2 uPrincipal;   // px
uniform float uFocal;      // px
uniform vec3 uCamRight;    // ENU
uniform vec3 uCamUp;       // ENU
uniform vec3 uCamFwd;      // ENU
uniform vec3 uSunDir;      // ENU unit
uniform vec3 uGalPole;     // ENU unit (north galactic pole)
uniform vec3 uGalCenter;   // ENU unit
uniform float uTime;
uniform float uNight;      // 0 day … 1 full night (from sun altitude)
uniform vec4 uZenith;      // palette keyed on sun altitude (computed on CPU)
uniform vec4 uHorizon;
uniform vec4 uSunGlow;
uniform vec4 uNebula;      // theme tint for the Milky Way

out vec4 fragColor;

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 s = (frag - uPrincipal) / uFocal;
  vec3 ray = normalize(uCamFwd + uCamRight * s.x - uCamUp * s.y);
  float alt = ray.z; // sin(altitude)

  // Base gradient: horizon → zenith (below horizon: darker ground haze).
  float h = saturate(alt);
  vec3 zen = toLinear(uZenith.rgb);
  vec3 hor = toLinear(uHorizon.rgb);
  vec3 col = mix(hor, zen, pow(h, 0.45));
  if (alt < 0.0) col = mix(hor, hor * 0.25, saturate(-alt * 4.0));

  // Sun glow (Mie-ish forward scattering), visible even when the sun is below
  // the horizon (twilight arch).
  float cosSun = dot(ray, uSunDir);
  float mie = pow(saturate(cosSun), 24.0) * 0.35 + pow(saturate(cosSun), 400.0) * 1.5;
  float arch = exp(-abs(alt - max(uSunDir.z, -0.1)) * 6.0) * pow(saturate(cosSun * 0.5 + 0.5), 3.0);
  col += toLinear(uSunGlow.rgb) * (mie + arch * 0.9) * uSunGlow.a;
  // Sun disc when above horizon.
  col += vec3(1.0, 0.95, 0.85) * smoothstep(0.9996, 0.99985, cosSun) * 4.0 * step(-0.02, uSunDir.z);

  // Milky Way: band around the galactic equator, brightest toward the centre,
  // with dust lanes; fades with daylight.
  float b = dot(ray, uGalPole);
  float lc = dot(ray, uGalCenter) * 0.5 + 0.5;
  float band = exp(-b * b * 18.0);
  float core = pow(lc, 3.0);
  vec3 g = ray * 3.0;
  float clouds = fbm3(g * 2.5 + vec3(3.0, 1.0, 7.0));
  float lanes = smoothstep(0.45, 0.75, fbm3(g * 4.0 + 11.0)) * exp(-b * b * 60.0);
  float mw = band * (0.35 + 0.65 * core) * (0.55 + 0.9 * clouds) * (1.0 - lanes * 0.75);
  vec3 mwCol = mix(toLinear(vec3(0.72, 0.78, 1.0)), toLinear(vec3(1.0, 0.86, 0.68)), core);
  mwCol = mix(mwCol, toLinear(uNebula.rgb), 0.25);
  col += mwCol * mw * 0.55 * uNight * smoothstep(-0.05, 0.15, alt);

  // Unresolved faint star haze.
  float grain = hash12(floor(frag * 0.5));
  col += vec3(0.8, 0.85, 1.0) * step(0.9975, grain) * 0.15 * uNight;

  col = toGamma(tonemapACES(col));
  col = dither(frag, col);
  fragColor = vec4(col, 1.0);
}
