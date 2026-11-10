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
uniform float uNight;      // Milky Way strength (night, moonlight and theme folded in)
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

  // How far into the day the sun is (the uniforms carry no separate day
  // factor; the sun's altitude is enough).
  float sunZ = uSunDir.z;
  float day = smoothstep(-0.05, 0.2, sunZ);
  // Azimuthal closeness to the sun (1 toward it, 0 away), for haze & glare.
  vec2 rh = ray.xy / max(length(ray.xy), 1e-4);
  vec2 sh = uSunDir.xy / max(length(uSunDir.xy), 1e-4);
  float toward = dot(rh, sh) * 0.5 + 0.5;

  // Sun glow (Mie-ish forward scattering), visible even when the sun is below
  // the horizon (twilight arch).
  float cosSun = dot(ray, uSunDir);
  float mie = pow(saturate(cosSun), 24.0) * 0.35 + pow(saturate(cosSun), 400.0) * 1.5;
  float arch = exp(-abs(alt - max(sunZ, -0.1)) * 6.0) * pow(saturate(cosSun * 0.5 + 0.5), 3.0);
  col += toLinear(uSunGlow.rgb) * (mie + arch * 0.9) * uSunGlow.a;

  // Daytime: the sky is deeper away from the sun, a broad glare lifts the
  // side of the screen nearest the sun (on screen or not), and a pale haze
  // thickens toward the horizon – brightest under the sun. Noon and
  // mid-afternoon no longer look identical.
  vec3 hazeCol = mix(hor, vec3(0.92, 0.94, 0.96), 0.45);
  float hz = exp(-max(alt, 0.0) * 8.0) * (0.16 + 0.22 * toward);
  col *= mix(1.0, mix(0.88, 1.0, toward), day);
  col = mix(col, hazeCol, hz * day * step(0.0, alt));
  float glare = pow(saturate(cosSun), 6.0) * 0.12 + pow(saturate(cosSun), 60.0) * 0.3;
  col += mix(vec3(1.0, 0.94, 0.84), toLinear(uSunGlow.rgb), 0.35) * glare * day;
  // Sun disc when above horizon.
  col += vec3(1.0, 0.95, 0.85) * smoothstep(0.9996, 0.99985, cosSun) * 4.0 * step(-0.02, sunZ);

  // Civil twilight: the Earth's shadow rises opposite the sun, crowned by
  // the rose Belt of Venus (sun between ~0° and -8°).
  float civil = smoothstep(0.03, -0.01, sunZ) * smoothstep(-0.16, -0.06, sunZ);
  float anti = pow(saturate(1.0 - toward), 2.0);
  float belt = exp(-pow((alt - 0.1) / 0.05, 2.0)) * anti * civil;
  float shadow = (1.0 - smoothstep(0.0, 0.07, alt)) * step(0.0, alt) * anti * civil;
  col = mix(col, col * vec3(0.72, 0.76, 0.9), shadow * 0.55);
  col += vec3(0.62, 0.34, 0.42) * belt * 0.22;

  // Milky Way: a cool, neutral band of star clouds around the galactic
  // equator, brightest toward the centre, laced with thin dark dust lanes
  // running along the band and split by the Great Rift; faded by daylight
  // and moonlight (uNight carries its strength). Never a warm smoke.
  vec3 gx = uGalCenter;
  vec3 gy = normalize(cross(uGalPole, uGalCenter));
  float b = dot(ray, uGalPole);                          // sin(galactic latitude)
  float lon = atan(dot(ray, gy), dot(ray, gx));          // galactic longitude
  float lc = cos(lon) * 0.5 + 0.5;                       // 1 toward the centre
  float band = exp(-b * b * 26.0);
  float core = pow(lc, 3.0) * exp(-b * b * 40.0);
  // Structure stretched along the band (longitude), fine across it.
  vec3 gq = vec3(cos(lon) * 1.6, sin(lon) * 1.6, b * 9.0);
  float clouds = fbm3(gq * 1.4 + vec3(3.0, 1.0, 7.0));
  float mottle = noise3(vec3(lon * 26.0, b * 60.0, 1.7));
  float starClouds = (0.45 + 0.75 * smoothstep(0.3, 0.75, clouds)) * (0.8 + 0.4 * mottle);
  float lanes = smoothstep(0.56, 0.7, fbm3(gq * 2.6 + 11.0)) * exp(-b * b * 140.0);
  float riftSpan = smoothstep(-1.1, -0.2, lon) * (1.0 - smoothstep(0.35, 0.8, lon));
  float riftEdge = (fbm3(gq * 3.4 + 23.0) - 0.5) * 0.03;
  float rift = exp(-pow((b - 0.02 + riftEdge) / 0.03, 2.0)) * riftSpan * (0.3 + 0.25 * clouds);
  float mw = band * (0.28 + 0.72 * core + 0.25 * lc) * starClouds * (1.0 - saturate(lanes * 0.5 + rift));
  vec3 mwCol = mix(vec3(0.66, 0.74, 0.92), vec3(0.9, 0.88, 0.84), saturate(core * 0.8));
  mwCol = mix(mwCol, toLinear(uNebula.rgb), 0.08);
  col += mwCol * mw * 0.8 * uNight * smoothstep(-0.05, 0.15, alt);
  // Unresolved stars crowding the band.
  float crowd = step(1.0 - 0.035 * band * (0.4 + core), hash12(floor(frag * 0.7) + 3.0));
  col += vec3(0.85, 0.88, 1.0) * crowd * 0.35 * uNight * smoothstep(-0.05, 0.15, alt);

  // Unresolved faint star haze.
  float grain = hash12(floor(frag * 0.5));
  col += vec3(0.8, 0.85, 1.0) * step(0.9975, grain) * 0.15 * uNight;

  col = toGamma(tonemapACES(col));
  col = dither(frag, col);
  fragColor = vec4(col, 1.0);
}
