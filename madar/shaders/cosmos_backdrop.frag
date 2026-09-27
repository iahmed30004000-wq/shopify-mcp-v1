#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;
uniform vec4 uTint;

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  fragColor = vec4(uTint.rgb * uTint.a, uTint.a) * (0.9 + 0.1 * uv.y);
}
