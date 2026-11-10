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
  float seed = uParams.z;
  // Laid paper: long fibres along x, a faint tooth, very soft mottling.
  float fibres = cn_noise(vec2(p.x / (fs * 9.0), p.y / fs) + seed) - 0.5;
  float tooth = cn_hash12(floor(p / 1.5) + seed) - 0.5;
  float mottle = cn_noise(p / 120.0 + seed * 3.0) - 0.5;
  vec3 c = uPaper.rgb * (1.0 + fibres * 0.05 + tooth * 0.025 + mottle * 0.05);
  // Foxing: small rust spots with soft halos, and a faint tide mark or two.
  vec2 cell = floor(p / 38.0);
  vec2 r = cn_hash22(cell + seed * 5.1);
  float spot = step(0.86, cn_hash12(cell * 1.7 + seed));
  float d = length(p - (cell + 0.2 + 0.6 * r) * 38.0);
  float rad = 1.2 + r.x * 3.5;
  float fox = (1.0 - smoothstep(rad * 0.6, rad, d)) * 0.8 + (1.0 - smoothstep(rad, rad * 3.0, d)) * 0.25;
  fox *= spot;
  float tide = cn_noise(p / 70.0 + seed * 11.0);
  float ring = (1.0 - smoothstep(0.0, 0.025, abs(tide - 0.62))) * smoothstep(0.35, 0.65, cn_noise(p / 200.0 + seed));
  vec3 stain = mix(uPaper.rgb, uStain.rgb, 0.55) * vec3(1.02, 0.95, 0.85);
  c = mix(c, stain, cn_sat(fox + ring * 0.35) * uStain.a);
  // Age: the edges yellow and darken unevenly; a soft vignette.
  vec2 e = min(uv, 1.0 - uv) * size;
  float edge = 1.0 - smoothstep(0.0, 22.0, min(e.x, e.y) + mottle * 14.0);
  c = mix(c, c * vec3(0.9, 0.82, 0.68), edge * uParams.y);
  float vig = smoothstep(0.35, 0.85, length(uv - 0.5));
  c *= 1.0 - vig * uParams.w * 0.25;
  fragColor = vec4(cn_sat3(c), 1.0) * uPaper.a;
}
