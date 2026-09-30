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
  float maxR = length(size) * 1.1;
  float r = uBurn.x * maxR;
  float n = cn_fbm(p * 0.018 + uBurn.w * 13.0) - 0.5;
  float d = length(p - uBurn.yz) + n * 90.0 - r;
  float w = max(uEdge.a, 1.0);
  if (uBurn.x <= 0.0) {
    fragColor = vec4(0.0);
    return;
  }
  float hole = 1.0 - cn_edge(0.0, d, 1.5);
  float edge = (1.0 - cn_edge(w, d, w * 0.5)) * (1.0 - hole);
  float scorch = (1.0 - cn_edge(w * 3.0, d, w)) * (1.0 - hole) * (1.0 - edge);
  vec4 col = vec4(uHole.rgb, 1.0) * uHole.a * hole;
  col += vec4(uEdge.rgb, 1.0) * edge;
  col += vec4(0.18, 0.09, 0.03, 1.0) * scorch * 0.75;
  fragColor = col;
}
