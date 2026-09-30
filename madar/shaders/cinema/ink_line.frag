#version 460 core
precision highp float;
#include <flutter/runtime_effect.glsl>
#include "lib/cinema.glsl"

// ---------------------------------------------------------------------------
// ink_line — MATERIAL shader for inked strokes and solid ink fills: gives
// flat vector ink the texture of a brush on paper (dry-brush breaks, density
// variation, fibre bleed). Use as Paint.shader on outline strokes / ink
// fills of rigs, props and stage art. Owner: FX agent (body). Uniform
// contract: architect (shader_uniforms.dart, InkLineUniforms).
//
// Uniforms (float indices):
//   0-3   uInk      vec4  ink colour (straight rgba)
//   4-7   uTexture  vec4  x grain scale px, y dryness (0 = solid, 1 = very
//                         dry brush), z boil frame, w seed
// Output: premultiplied ink.
// ---------------------------------------------------------------------------

uniform vec4 uInk;
uniform vec4 uTexture;

out vec4 fragColor;

void main() {
  vec2 p = FlutterFragCoord().xy;
  float s = max(uTexture.x, 0.5);
  float fibre = cn_noise(vec2(p.x / (s * 6.0), p.y / s) + uTexture.w);
  float speck = cn_hash12(floor(p / s) + uTexture.z * 0.37 + uTexture.w);
  float dry = step(1.0 - uTexture.y * 0.55, speck * 0.6 + fibre * 0.4);
  float density = 0.88 + fibre * 0.12;
  float a = cn_sat(density * (1.0 - dry));
  fragColor = vec4(uInk.rgb, 1.0) * uInk.a * a;
}
