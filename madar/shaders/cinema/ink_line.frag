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
  float seed = uTexture.w + uTexture.z * 0.37;
  // Ink body: slightly uneven density along fibre-like streaks.
  float fibre = cn_noise(vec2(p.x / (s * 6.0), p.y / s) + uTexture.w);
  float density = 0.86 + fibre * 0.14;
  // Dry brush: the paper's tooth shows through where the brush ran dry –
  // clustered pits (a slow patch mask times a fine tooth), never pixel salt.
  float blotch = cn_noise(p / (s * 16.0) + seed * 1.3);
  float tooth = cn_noise(p / (s * 1.1) + seed * 7.1);
  float dryness = uTexture.y;
  float dry = smoothstep(1.0 - dryness * 0.5, 1.0 - dryness * 0.5 + 0.08, tooth * 0.45 + blotch * 0.55 + dryness * 0.12);
  float a = cn_sat(density * (1.0 - dry));
  fragColor = vec4(uInk.rgb, 1.0) * uInk.a * a;
}
