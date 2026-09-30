#version 460 core
precision highp float;
#include <flutter/runtime_effect.glsl>
#include "lib/cinema.glsl"

// ---------------------------------------------------------------------------
// paper — MATERIAL shader: aged paper / card stock for intertitle cards,
// painted backdrops, posters in the Hall and HUD plaques. Draw as
// Paint.shader on the card's rect. Owner: FX agent (body). Uniform contract:
// architect (shader_uniforms.dart, PaperUniforms).
//
// Uniforms (float indices):
//   0-3   uRect    vec4  card rect in local px (x, y, w, h)
//   4-7   uPaper   vec4  paper colour (straight rgb), a = opacity
//   8-11  uStain   vec4  foxing / stain colour (rgb), a = amount (0..1)
//   12-15 uParams  vec4  x fibre scale px, y age (edge darkening, 0..1),
//                        z seed, w inner vignette (0..1)
// Output: premultiplied paper.
// ---------------------------------------------------------------------------

uniform vec4 uRect;
uniform vec4 uPaper;
uniform vec4 uStain;
uniform vec4 uParams;

out vec4 fragColor;

void main() {
  vec2 p = FlutterFragCoord().xy - uRect.xy;
  vec2 size = max(uRect.zw, vec2(1.0));
  vec2 uv = p / size;
  float fs = max(uParams.x, 0.5);
  float fibres = cn_noise(vec2(p.x / (fs * 8.0), p.y / fs) + uParams.z) - 0.5;
  float mottling = cn_fbm(p / 90.0 + uParams.z * 3.0) - 0.5;
  vec3 c = uPaper.rgb * (1.0 + fibres * 0.06 + mottling * 0.08);
  float fox = smoothstep(0.62, 0.8, cn_fbm(p / 40.0 + uParams.z * 7.0));
  c = mix(c, uStain.rgb, fox * uStain.a * 0.6);
  vec2 e = min(uv, 1.0 - uv) * size;
  float edge = 1.0 - smoothstep(0.0, 26.0, min(e.x, e.y) + mottling * 10.0);
  c *= 1.0 - edge * uParams.y * 0.45;
  float vig = smoothstep(0.3, 0.8, length(uv - 0.5));
  c *= 1.0 - vig * uParams.w * 0.35;
  fragColor = vec4(cn_sat3(c), 1.0) * uPaper.a;
}
