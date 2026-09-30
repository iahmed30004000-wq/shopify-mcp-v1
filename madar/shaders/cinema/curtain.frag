#version 460 core
precision highp float;
#include <flutter/runtime_effect.glsl>
#include "lib/cinema.glsl"

// ---------------------------------------------------------------------------
// curtain — MATERIAL shader for the stage curtains (velvet folds, sheen,
// footlight bounce, sway) and the scalloped valance. Draw as Paint.shader on
// canvas.drawRect(uRect) of each panel. Owner: STAGE agent (body). Uniform
// contract: architect (shader_uniforms.dart, CurtainUniforms).
//
// Uniforms (float indices):
//   0-3   uRect   vec4  panel rect in local px (x, y, w, h)
//   4-7   uColor  vec4  velvet base colour (straight rgb), a = opacity
//   8-11  uShade  vec4  fold shadow colour (rgb), a = sheen strength (0..1)
//   12-15 uFolds  vec4  x fold count, y sway phase rad, z gather (0 = hanging
//                       straight, 1 = fully tied back toward the outer edge),
//                       w panel side (-1 left, +1 right, 0 valance)
//   16-19 uLight  vec4  footlight colour (rgb), a = intensity (0..1)
//   20-23 uClock  vec4  x seconds, y boil frame, z seed, w unused (0)
// Output: premultiplied velvet; the valance's scallops cut to transparent.
// ---------------------------------------------------------------------------

uniform vec4 uRect;
uniform vec4 uColor;
uniform vec4 uShade;
uniform vec4 uFolds;
uniform vec4 uLight;
uniform vec4 uClock;

out vec4 fragColor;

void main() {
  vec2 p = FlutterFragCoord().xy - uRect.xy;
  vec2 size = max(uRect.zw, vec2(1.0));
  vec2 uv = p / size;
  float side = uFolds.w;
  float folds = max(uFolds.x, 1.0);

  if (abs(side) < 0.5) {
    // Valance: horizontal swags with scalloped bottom edge.
    float sw = fract(uv.x * folds);
    float scallop = 1.0 - 0.22 * (1.0 - pow(2.0 * sw - 1.0, 2.0));
    float a = 1.0 - cn_edge(scallop, uv.y, 1.5 / size.y);
    float drape = sin(sw * CN_PI);
    vec3 c = mix(uShade.rgb, uColor.rgb, 0.45 + 0.55 * drape * (1.0 - uv.y * 0.5));
    c += uShade.a * 0.25 * pow(drape, 8.0);
    fragColor = vec4(cn_sat3(c), 1.0) * uColor.a * a;
    return;
  }

  // Outer edge = 0, inner (stage-facing) edge = 1.
  float x = side < 0.0 ? uv.x : 1.0 - uv.x;
  // Gathering compresses the folds toward the outer edge near the tie-back.
  float tie = exp(-pow((uv.y - 0.62) / 0.28, 2.0)) * uFolds.z;
  float gx = pow(x, 1.0 + tie * 1.5);
  float sway = sin(uv.y * 3.0 + uFolds.y) * 0.02 * (1.0 - tie);
  float ph = (gx + sway) * folds * CN_TAU + cn_noise(vec2(uv.y * 3.0, uClock.z)) * 0.8;
  float s = 0.5 + 0.5 * sin(ph);
  vec3 c = mix(uShade.rgb, uColor.rgb, pow(s, 0.8));
  c += uShade.a * 0.35 * pow(s, 14.0) * vec3(1.0, 0.9, 0.85);
  // Inner edge falls into shadow; footlights warm the hem.
  c *= 0.75 + 0.25 * smoothstep(1.0, 0.8, x);
  float glow = exp(-(1.0 - uv.y) * 5.0) * uLight.a;
  c += uLight.rgb * glow * (0.4 + 0.6 * s);
  fragColor = vec4(cn_sat3(c), 1.0) * uColor.a;
}
