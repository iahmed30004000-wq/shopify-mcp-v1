#version 460 core
#include <flutter/runtime_effect.glsl>

// Warps a pre-rendered text image onto a circular band (for correctly shaped
// Arabic text engraved along the astrolabe ring) with an engraved-in-brass look.
uniform vec2 uSize;
uniform vec2 uCenter;
uniform float uRInner;
uniform float uROuter;
uniform float uStart;   // angle (radians, 0 = +x, CCW, y up) of the image's LEFT edge
uniform float uSweep;   // angular extent; the image runs clockwise (left→right across the top)
uniform vec2 uTexSize;  // text image size (px)
uniform vec4 uInk;      // engraving shadow colour
uniform vec4 uGlow;     // highlight / glow colour
uniform float uGlowAmt;
uniform sampler2D uText;

out vec4 fragColor;
float clamp01(float x) { return clamp(x, 0.0, 1.0); }

float sampleText(vec2 frag) {
  vec2 d = frag - uCenter;
  d.y = -d.y;
  float r = length(d);
  float a = atan(d.y, d.x);
  // Clockwise distance from the image's left edge, wrapped into [0, 2π) so
  // any sweep up to a full turn reads without a seam (a ±π wrap cut every
  // sweep over 180°).
  float t = mod(uStart - a, 6.28318531);
  float u = t / uSweep;
  float v = (uROuter - r) / (uROuter - uRInner);
  if (u < 0.0 || u > 1.0 || v < 0.0 || v > 1.0) return 0.0;
  return texture(uText, vec2(u, v)).a;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  float c = sampleText(frag);
  // emboss: light from top-left -> engraved (sunken) look
  float sh = sampleText(frag + vec2(-0.9, -0.9));
  float hi = sampleText(frag + vec2(0.9, 0.9));
  
  vec3 col = uInk.rgb * c * 0.85 + uGlow.rgb * clamp01(sh - c) * 0.9 + uGlow.rgb * c * uGlowAmt;
  float a = clamp01(c * 0.95 + clamp01(sh - c) * 0.6);
  fragColor = vec4(col * a, a);
}
