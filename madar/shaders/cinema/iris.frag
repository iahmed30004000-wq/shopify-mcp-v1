#version 460 core
precision highp float;
#include <flutter/runtime_effect.glsl>
#include "lib/cinema.glsl"

// ---------------------------------------------------------------------------
// iris — OVERLAY shader for iris-in / iris-out transitions: covers everything
// outside a (hand-cut, slightly wobbly) opening with uColor. Draw as
// Paint.shader on canvas.drawRect(uRect) above the scene, below the film
// grade (so grain dances on the black too). Owner: FX agent (body); the
// stage agent's CinemaTransitions drives it. Uniform contract: architect
// (shader_uniforms.dart, IrisUniforms).
//
// Uniforms (float indices):
//   0-3   uRect   vec4  covered rect in local px (x, y, w, h)
//   4-7   uIris   vec4  x, y opening centre (local px), z radius px (0 =
//                       fully closed; ≥ the rect's diagonal = fully open),
//                       w edge softness px
//   8-11  uColor  vec4  mask colour (straight rgba; usually the era ink)
//   12-15 uStyle  vec4  x shape (0 circle, 1 heart, 2 eight-point star,
//                       3 keyhole), y edge wobble px, z boil frame,
//                       w rim light (0..1, a soft glow just inside the edge)
// Output: premultiplied mask colour outside the opening, transparent inside.
// ---------------------------------------------------------------------------

uniform vec4 uRect;
uniform vec4 uIris;
uniform vec4 uColor;
uniform vec4 uStyle;

out vec4 fragColor;

float sdBox(vec2 p, vec2 b) {
  vec2 d = abs(p) - b;
  return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
}

float dot2(vec2 v) { return dot(v, v); }

// Unit heart (tip at y = 0, lobes near y = 1, y up), IQ's exact SDF.
float sdHeart(vec2 p) {
  p.x = abs(p.x);
  if (p.y + p.x > 1.0) return sqrt(dot2(p - vec2(0.25, 0.75))) - 0.35355;
  return sqrt(min(dot2(p - vec2(0.0, 1.0)), dot2(p - 0.5 * max(p.x + p.y, 0.0)))) * sign(p.x - p.y);
}

float shapeDistance(vec2 q, float r, float shape) {
  if (shape > 2.5) {
    // keyhole: round head + flared foot
    float head = length(q - vec2(0.0, -0.25 * r)) - 0.55 * r;
    float foot = sdBox(q - vec2(0.0, 0.45 * r), vec2(0.28 * r + max(q.y, 0.0) * 0.25, 0.5 * r));
    return min(head, foot);
  }
  if (shape > 1.5) {
    // eight-point star: union of two squares
    float a = sdBox(q, vec2(0.72 * r));
    float b = sdBox(cn_rotate(q, 0.7854), vec2(0.72 * r));
    return min(a, b);
  }
  if (shape > 0.5) {
    vec2 h = vec2(q.x, -q.y) / (1.25 * r) + vec2(0.0, 0.55);
    return sdHeart(h) * 1.25 * r;
  }
  return length(q) - r;
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  vec2 q = p - uIris.xy;
  float r = max(uIris.z, 0.0);
  float d = shapeDistance(q, r, uStyle.x);
  // Hand-inked edge: the outline re-boils on twos (boil frame).
  float ang = atan(q.y, q.x + 0.0001);
  d += (cn_noise(vec2(ang * 3.0 + 7.0, uStyle.z * 1.7)) - 0.5) * uStyle.y * 2.0;
  float soft = max(uIris.w, 0.75);
  float cover = cn_edge(0.0, d, soft);
  if (r <= 0.0) cover = 1.0;
  float inside = 1.0 - cover;
  // Inside the opening: the lens penumbra darkens toward the blades and a
  // thin rim of light catches the edge.
  float pen = (1.0 - smoothstep(0.0, 22.0 + r * 0.12, -d)) * inside;
  float rim = (1.0 - smoothstep(0.0, soft * 3.0 + 4.0, abs(d + soft * 2.5))) * uStyle.w * inside;
  // Outside: the mask with a faint card texture (never dead flat black).
  vec2 lp = p - uRect.xy;
  float tex = (cn_noise(lp / 2.5 + uStyle.z * 0.37) - 0.5) * 0.08;
  vec4 col = vec4(uColor.rgb * (1.0 + tex), 1.0) * uColor.a * cover;
  col += vec4(uColor.rgb, 1.0) * pen * 0.42 * uColor.a;
  col.rgb += vec3(1.0, 0.95, 0.85) * rim * 0.32;
  fragColor = col;
}
