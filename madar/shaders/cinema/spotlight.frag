#version 460 core
precision highp float;
#include <flutter/runtime_effect.glsl>
#include "lib/cinema.glsl"

// ---------------------------------------------------------------------------
// spotlight — OVERLAY shader: a follow-spot cone from above the proscenium
// with a soft pool of light and dust motes drifting in the beam. Draw as
// Paint.shader (BlendMode.plus or screen) on canvas.drawRect(uRect).
// Owner: STAGE agent (body). Uniform contract: architect
// (shader_uniforms.dart, SpotlightUniforms).
//
// Uniforms (float indices):
//   0-3   uRect    vec4  covered rect in local px (x, y, w, h)
//   4-7   uSpot    vec4  source x, y (local px, may be off-screen), target x, y
//   8-11  uColor   vec4  light colour (straight rgb), a = intensity (0..1)
//   12-15 uParams  vec4  x pool radius px at the target, y edge softness
//                        (0..1), z dust motes (0..1), w seconds
// Output: premultiplied light (additive use).
// ---------------------------------------------------------------------------

uniform vec4 uRect;
uniform vec4 uSpot;
uniform vec4 uColor;
uniform vec4 uParams;

out vec4 fragColor;

void main() {
  vec2 p = FlutterFragCoord().xy;
  vec2 src = uSpot.xy;
  vec2 dst = uSpot.zw;
  vec2 axis = dst - src;
  float len = max(length(axis), 1.0);
  vec2 dir = axis / len;
  float along = dot(p - src, dir);
  float perp = abs(dot(p - src, vec2(-dir.y, dir.x)));
  float radius = max(uParams.x, 1.0) * cn_sat(along / len) + 2.0;
  float soft = clamp(uParams.y, 0.02, 1.0);
  float cone = 1.0 - smoothstep(1.0 - soft, 1.0, perp / radius);
  cone *= step(0.0, along) * (0.35 + 0.65 * cn_sat(along / len));
  vec2 e = (p - dst) / vec2(uParams.x, uParams.x * 0.35);
  float pool = 1.0 - smoothstep(0.6, 1.0, length(e));
  float motes = 0.0;
  if (uParams.z > 0.001) {
    vec2 cell = floor((p + vec2(0.0, uParams.w * 12.0)) / 18.0);
    vec2 r = cn_hash22(cell);
    vec2 c = (cell + r) * 18.0 - vec2(0.0, uParams.w * 12.0);
    float tw = 0.5 + 0.5 * sin(uParams.w * 3.0 + r.x * 20.0);
    motes = (1.0 - smoothstep(0.4, 1.4, length(p - c))) * step(0.85, r.y) * tw * uParams.z;
  }
  float i = cn_sat((cone * 0.28 + pool * 0.45 + motes * cone) * uColor.a);
  fragColor = vec4(uColor.rgb * i, i);
}
