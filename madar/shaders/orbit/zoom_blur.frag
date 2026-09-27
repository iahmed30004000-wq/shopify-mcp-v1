#version 460 core
#include <flutter/runtime_effect.glsl>

// ---------------------------------------------------------------------------
// Zoom blur — post-process for planet fly-ins. Use with
//   ImageFilter.shader(program.fragmentShader()
//       ..setFloat(2, cx)..setFloat(3, cy)..setFloat(4, strength)
//       ..setFloat(5, frame))
// (Impeller only; check ui.ImageFilter.isShaderFilterSupported).
//
// Radial zoom / motion blur streaking toward uCenter: every pixel averages
// taps along the line to the focus point, so the blur length grows with the
// distance from the focus (the target planet stays sharp, the periphery
// streaks). 12 taps up to uStrength 0.6, 16 taps above (a compile-time
// 16-tap loop; the extra 4 taps are skipped below 0.6).
// Taps are jittered per pixel (interleaved-gradient noise) AND the jitter is
// rotated every frame by uFrame, so the residual sampling pattern becomes
// temporal grain that the eye integrates instead of the static diagonal
// hatching / stepped ghost copies a fixed pattern leaves on long streaks.
// A slight chromatic aberration is folded into the SAME taps via spectral
// weighting (red favours the outer end of the streak, blue the inner end) and
// grows toward the screen edges — no extra texture fetches.
//
// Deliberately does NOT include lib/common.glsl: that library declares the
// noise sampler as sampler 0, but an ImageFilter shader's sampler 0 must be
// the filter input.
//
// Uniforms (float indices for setFloat):
//   0,1  uSize      vec2  — set by the ENGINE for ImageFilter.shader; do not
//                          set it yourself (start at float index 2).
//   2,3  uCenter    vec2  — zoom focus in px, in the filtered layer's space
//                          (usually the target planet's centre).
//   4    uStrength  float — 0..1. 0 = identity (single tap, exact passthrough);
//                          1 = streaks ~20 % of the distance to the focus.
//   5    uFrame     float — NEW trailing uniform (cohesion pass): a frame
//                          counter, +1 every frame the filter is drawn (any
//                          integer; it is wrapped mod 64 here). Leaving it at
//                          0 reproduces the previous static jitter exactly.
//   sampler 0 uInput      — the filter input (bound by the engine).
// Output: premultiplied, like the input.
// Cost: 12 texture fetches + light ALU per pixel while 0 < uStrength <= 0.6,
// 16 above 0.6, 1 fetch when uStrength == 0 (still prefer removing the filter
// entirely when idle).
// ---------------------------------------------------------------------------

uniform vec2 uSize;
uniform vec2 uCenter;
uniform float uStrength;
uniform float uFrame;
uniform sampler2D uInput;

out vec4 fragColor;

const int ZB_MAX_TAPS = 16;

vec4 zb_sample(vec2 px) {
  vec2 uv = clamp(px / uSize, vec2(0.0), vec2(1.0));
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  return texture(uInput, uv);
}

float zb_win(float u, float a, float b, float e) {
  return smoothstep(a - e, a + e, u) * (1.0 - smoothstep(b - e, b + e, u));
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  float s = clamp(uStrength, 0.0, 1.0);
  if (s <= 0.0005) {
    fragColor = zb_sample(frag);
    return;
  }

  vec2 d = frag - uCenter;
  // Normalised distance from the focus (0 at the focus, ~1 at a far corner).
  float dist = length(d) / max(length(uSize) * 0.5, 1.0);
  // Ease-in so small strengths stay subtle; blur = fraction of the distance.
  float blur = 0.2 * s * s * (3.0 - 2.0 * s);
  // Chromatic spread (fraction of the distance), strongest toward the edges.
  float ca = 0.012 * s * smoothstep(0.15, 0.9, dist);
  float span = blur + 2.0 * ca;
  // Channel windows over the streak coordinate u in [0,1]
  // (u = 0 at the pixel, pushed outward by ca; u = 1 nearest the focus).
  float cf = clamp(2.0 * ca / max(span, 1e-5), 0.0, 0.9);
  float e = max(cf * 0.5, 0.02);
  float useCa = step(0.001, cf);
  // 12 taps up to strength 0.6, 16 above (long streaks need the density).
  float taps = s > 0.6 ? 16.0 : 12.0;

  // Per-pixel jitter (interleaved gradient noise) hides tap banding. The
  // per-frame offset (5.588238 px/frame, the standard temporal IGN step) plus
  // a golden-ratio phase step moves the pattern every frame, so what used to
  // be static hatching becomes fine temporal grain.
  float fr = floor(mod(uFrame, 64.0));
  vec2 jp = frag + 5.588238 * fr;
  float jit = fract(52.9829189 * fract(dot(jp, vec2(0.06711056, 0.00583715))) + fr * 0.61803399);

  vec3 accC = vec3(0.0);
  vec3 wsum = vec3(0.0);
  float accA = 0.0;
  float wa = 0.0;
  for (int i = 0; i < ZB_MAX_TAPS; i++) {
    float fi = float(i);
    if (fi < taps) {                              // uniform branch: 12 or 16 taps
      float u = (fi + jit) / taps;
      // Scale toward the focus: 1 + ca at u = 0 … 1 - blur - ca at u = 1.
      float k = 1.0 + ca - span * u;
      vec4 c = zb_sample(uCenter + d * k);
      // A touch heavier near the pixel itself so silhouettes stay legible.
      float w = 1.0 - 0.45 * u;
      // Spectral windows: R over [0, 1-cf], G over [cf/2, 1-cf/2], B over [cf, 1].
      vec3 wc = w * vec3(zb_win(u, -1.0, 1.0 - cf, e),
                         zb_win(u, cf * 0.5, 1.0 - cf * 0.5, e),
                         zb_win(u, cf, 2.0, e));
      wc = mix(vec3(w), wc, useCa);
      accC += c.rgb * wc;
      wsum += wc;
      accA += c.a * w;
      wa += w;
    }
  }
  vec3 rgb = accC / max(wsum, vec3(1e-4));
  float a = accA / max(wa, 1e-4);
  // Keep the premultiplied invariant (channel spread can nudge rgb above a).
  fragColor = vec4(min(rgb, vec3(a)), a);
}
