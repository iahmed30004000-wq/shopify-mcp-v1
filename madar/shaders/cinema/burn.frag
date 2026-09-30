#version 460 core
precision highp float;
#include <flutter/runtime_effect.glsl>
#include "lib/cinema.glsl"

// ---------------------------------------------------------------------------
// burn — OVERLAY shader: the film melts in the projector gate (a transition,
// grindhouse "missing reel" gag, or a boss-defeat flourish). Draw as
// Paint.shader on canvas.drawRect(uRect) above the scene. Owner: FX agent.
// Uniform contract: architect (shader_uniforms.dart, BurnUniforms).
//
// Uniforms (float indices):
//   0-3   uRect  vec4  covered rect in local px (x, y, w, h)
//   4-7   uBurn  vec4  x progress (0 = intact, 1 = frame fully burnt through),
//                      y, z burn origin (local px), w seed
//   8-11  uEdge  vec4  hot edge colour (straight rgb), a = edge width px
//   12-15 uHole  vec4  colour shown through the hole (straight rgba; the
//                      projector's white light, or ink black)
// Output: premultiplied; transparent where the film is still intact.
// ---------------------------------------------------------------------------

uniform vec4 uRect;
uniform vec4 uBurn;
uniform vec4 uEdge;
uniform vec4 uHole;

out vec4 fragColor;

void main() {
  vec2 p = FlutterFragCoord().xy;
  vec2 size = max(uRect.zw, vec2(1.0));
  if (uBurn.x <= 0.0) {
    fragColor = vec4(0.0);
    return;
  }
  // The melt starts as a slow blister and then runs away.
  float prog = uBurn.x;
  float r = prog * prog * (length(size) * 1.2);
  vec2 o = p - uBurn.yz;
  float n = cn_fbm(p * 0.018 + uBurn.w * 13.0) - 0.5;
  float d = length(o) + n * (36.0 + r * 0.4) - r;
  // Bubbles pop open just ahead of the front: small holes with a hot rim,
  // kept inside their cell (centre in the middle third, radius + rim < 8 px).
  vec2 cell = floor((p - uRect.xy) / 24.0);
  vec2 rnd = cn_hash22(cell + uBurn.w * 7.0);
  vec2 bc = uRect.xy + (cell + 0.35 + 0.3 * rnd) * 24.0;
  float grow = (1.0 - smoothstep(4.0, 50.0, d)) * step(0.4, rnd.y) * step(0.0, d);
  float br = (1.5 + rnd.x * 3.5) * grow;
  float bdist = length(p - bc) - br;
  float bhole = (1.0 - cn_edge(0.0, bdist, 0.8)) * step(0.3, br);
  float brim = (1.0 - smoothstep(0.0, 2.6, bdist)) * step(0.3, br) * (1.0 - bhole);

  float w = max(uEdge.a, 1.0);
  float hole = max(1.0 - cn_edge(0.0, d, 1.2), bhole);
  float out1 = 1.0 - hole;
  float white = max((1.0 - smoothstep(0.0, w * 0.45, d)), brim) * out1;
  float glow = max((1.0 - smoothstep(w * 0.2, w * 1.3, d)), brim) * out1;
  float scorch = (1.0 - smoothstep(w * 0.8, w * 4.5, d)) * out1;
  float blister = (1.0 - smoothstep(0.0, 3.0, abs(d - w * 2.2))) * out1 * 0.35;
  vec4 col = vec4(uHole.rgb, 1.0) * uHole.a * hole;
  vec3 ring = mix(uEdge.rgb, vec3(1.0, 0.97, 0.82), white);
  float ringA = max(glow, white);
  vec4 scorchC = vec4(0.16, 0.08, 0.03, 1.0) * scorch * 0.85;
  col += vec4(ring, 1.0) * ringA + scorchC * (1.0 - ringA);
  col.rgb += vec3(1.0, 0.75, 0.4) * blister * (1.0 - ringA);
  fragColor = col;
}
