// Madar – glass surface finish.
//
// Painted over the tinted glass fill of GlassPanel / GlassCard. Produces a
// premultiplied overlay made of:
//   * a soft inner rim light along the top edge (light hitting the glass lip),
//   * a slow diagonal specular sheen that drifts across the surface,
//   * a faint corner bloom at the top-start corner,
//   * static paper-fine grain (lightens and darkens) so large panels never
//     band and feel tactile.
//
// uTime is wrapped by the host to [0, PERIOD) and every time term is periodic
// in PERIOD, so the loop is seamless.
//
// Uniform layout (float indices – keep in sync with GlassSurfacePainter):
//   0-1  uSize       logical size of the panel
//   2    uTime       seconds, wrapped to [0, PERIOD)
//   3-6  uHighlight  glass highlight colour (straight rgba)
//   7-10 uParams     x grain opacity, y light theme (0/1), z seed,
//                    w specular strength (0..1)
//  11    uDir        1 for LTR, -1 for RTL (mirrors the corner bloom)
#version 460 core
precision highp float;

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;
uniform vec4 uHighlight;
uniform vec4 uParams;
uniform float uDir;

out vec4 fragColor;

const float TAU = 6.28318530718;
const float PERIOD = 60.0;

float hash12(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = frag / uSize;
  float grainAmt = uParams.x;
  float light = uParams.y;
  float seed = uParams.z;
  float spec = uParams.w;
  float ph = TAU * uTime / PERIOD + seed * 1.7;

  // Mirror horizontally for RTL so the bloom sits at the reading start.
  float ux = uDir > 0.0 ? uv.x : 1.0 - uv.x;

  // Inner rim light: a few logical pixels under the top edge.
  float rim = exp(-frag.y / 10.0) * 0.20 + exp(-frag.y / 42.0) * 0.07;

  // Top-start corner bloom.
  vec2 c = vec2(ux, uv.y) * vec2(uSize.x / max(uSize.y, 1.0), 1.0);
  float bloom = exp(-dot(c, c) * 2.4) * 0.10;

  // Diagonal sheen band drifting back and forth.
  float diag = ux * 0.82 + uv.y * 0.46;
  float center = 0.45 + 0.55 * sin(ph);
  float band = exp(-pow((diag - center) / 0.22, 2.0)) * 0.075;
  float thin = exp(-pow((diag - center - 0.16) / 0.035, 2.0)) * 0.035;
  float sheen = (band + thin) * spec;

  float hl = rim + bloom + sheen;
  // Light theme: highlights are brighter white, kept subtle.
  hl *= mix(1.0, 1.35, light);
  float a = clamp(hl * uHighlight.a * 1.6, 0.0, 0.6);
  vec4 col = vec4(uHighlight.rgb * a, a);

  // Static grain: +/- luminance so the surface feels physical.
  float g = hash12(floor(frag * 1.5) + seed * 17.0) - 0.5;
  float ga = abs(g) * grainAmt * 1.4;
  vec4 grain = g > 0.0 ? vec4(vec3(ga), ga) : vec4(0.0, 0.0, 0.0, ga);
  col = grain + col * (1.0 - grain.a);

  fragColor = col;
}
